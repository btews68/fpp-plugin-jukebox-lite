#!/usr/bin/env python3
import argparse
import configparser
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

PLUGIN_NAME = "fpp-plugin-jukebox-lite"
CONFIG_PATH = f"/home/fpp/media/config/plugin.{PLUGIN_NAME}"
DEFAULT_PLAY_CMD = "/home/fpp/media/scripts/jukebox_play_hook.sh"


def _clean_setting(value, default=""):
    raw = str(value if value is not None else default).strip()
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in ('"', "'"):
        return raw[1:-1].strip()
    return raw


def _int_setting(cfg, key, default):
    raw = _clean_setting(cfg.get(key, str(default)), str(default))
    try:
        return int(raw)
    except ValueError as exc:
        raise RuntimeError(f"{key} must be an integer, got: {raw}") from exc


def load_config():
    cp = configparser.ConfigParser()
    cp.read(CONFIG_PATH)
    if "plugin" not in cp:
        cp["plugin"] = {}
    cfg = cp["plugin"]

    base = _clean_setting(cfg.get("JUKEBOX_API_BASE", "")).rstrip("/")
    if not base:
        raise RuntimeError("JUKEBOX_API_BASE missing in plugin config")

    return {
        "api_base": base,
        "api_key": _clean_setting(cfg.get("JUKEBOX_API_KEY", "")),
        "player_id": _clean_setting(cfg.get("JUKEBOX_PLAYER_ID", "fpp-main")) or "fpp-main",
        "poll_sec": _int_setting(cfg, "JUKEBOX_POLL_SEC", 3),
        "http_timeout": _int_setting(cfg, "JUKEBOX_HTTP_TIMEOUT_SEC", 4),
        "play_cmd": _clean_setting(cfg.get("JUKEBOX_PLAY_CMD", DEFAULT_PLAY_CMD)) or DEFAULT_PLAY_CMD,
        "idle_playlist": _clean_setting(cfg.get("JUKEBOX_IDLE_PLAYLIST", "")),
        "fail_open": _clean_setting(cfg.get("JUKEBOX_FAIL_OPEN", "1")) == "1",
    }


def api_call(cfg, path, payload):
    url = cfg["api_base"] + path
    req = urllib.request.Request(url, method="POST")
    req.add_header("Content-Type", "application/json")
    if cfg["api_key"]:
        req.add_header("X-Api-Key", cfg["api_key"])
    data = json.dumps(payload).encode("utf-8")
    try:
        with urllib.request.urlopen(req, data=data, timeout=cfg["http_timeout"]) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} {path}: {body}")
    except urllib.error.URLError as exc:
        raise RuntimeError(f"Network error for {path}: {exc}")


def run_play_hook(cfg, request_item):
    cmd = [
        cfg["play_cmd"],
        request_item.get("mediaType", ""),
        request_item.get("mediaRef", ""),
        request_item.get("id", ""),
        request_item.get("title", ""),
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except Exception as exc:
        return False, f"play hook launch failed: {exc}"

    if proc.returncode != 0:
        stderr_txt = (proc.stderr or "").strip()
        stdout_txt = (proc.stdout or "").strip()
        if stderr_txt and stdout_txt:
            err = f"{stderr_txt} | {stdout_txt}"
        elif stderr_txt:
            err = stderr_txt
        elif stdout_txt:
            err = stdout_txt
        else:
            err = "play hook failed"
        return False, err

    return True, proc.stdout.strip()


def notify(cfg, path, request_id, reason=""):
    payload = {
        "playerId": cfg["player_id"],
        "requestId": request_id,
    }
    if reason:
        payload["reason"] = reason
    return api_call(cfg, path, payload)


def run_once(cfg):
    claimed = api_call(cfg, "/fpp/next", {"playerId": cfg["player_id"], "supports": ["sequence", "playlist"]})
    if not claimed.get("ok", False):
        raise RuntimeError("Claim endpoint returned failure")

    req = claimed.get("data", {}).get("request")
    if not req:
        print(json.dumps({"ok": True, "message": "queue empty"}))
        return 0

    request_id = req.get("id")
    if not request_id:
        raise RuntimeError("Claim response missing request id")

    notify(cfg, "/fpp/started", request_id)

    ok, detail = run_play_hook(cfg, req)
    if ok:
        notify(cfg, "/fpp/completed", request_id)
        print(json.dumps({"ok": True, "played": request_id, "detail": detail}))
        return 0

    notify(cfg, "/fpp/failed", request_id, detail[:240])
    print(json.dumps({"ok": False, "failed": request_id, "error": detail}))
    return 1


def run_loop(cfg):
    while True:
        try:
            run_once(cfg)
        except Exception as exc:
            print(json.dumps({"ok": False, "error": str(exc)}))
        time.sleep(max(1, cfg["poll_sec"]))


def main():
    parser = argparse.ArgumentParser(description="Jukebox Lite FPP client")
    parser.add_argument("--once", action="store_true", help="Run one poll cycle")
    parser.add_argument("--loop", action="store_true", help="Run forever")
    args = parser.parse_args()

    if not args.once and not args.loop:
        parser.error("choose --once or --loop")

    try:
        cfg = load_config()
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 2

    if args.once:
        return run_once(cfg)

    run_loop(cfg)
    return 0


if __name__ == "__main__":
    sys.exit(main())
