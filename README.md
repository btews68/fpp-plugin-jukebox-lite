# fpp-plugin-jukebox-lite

Lightweight Falcon Player plugin for a simple Hostinger-backed jukebox queue.

## What it does

- Polls queue API for the next request
- Marks request started/completed/failed
- Calls a local play hook script for actual playback execution

## Key files

- `commands/jukebox_client.py` -> main queue client
- `commands/jukebox_once.sh` -> one cycle
- `commands/jukebox_poll.sh` -> loop mode
- `scripts/jukebox_play_hook.sh` -> media playback hook
- `scripts/fpp_install.sh` -> link scripts and write default config

## Install

1. Place plugin folder under `/home/fpp/media/plugins/fpp-plugin-jukebox-lite`.
2. Run:

```bash
bash /home/fpp/media/plugins/fpp-plugin-jukebox-lite/scripts/fpp_install.sh
```

3. Edit plugin config in FPP UI or manually:

`/home/fpp/media/config/plugin.fpp-plugin-jukebox-lite`

4. Update `JUKEBOX_API_BASE` and `JUKEBOX_API_KEY`.

## Run

One cycle test:

```bash
/home/fpp/media/scripts/jukebox_once.sh
```

Loop mode:

```bash
/home/fpp/media/scripts/jukebox_poll.sh
```

## Important

`jukebox_play_hook.sh` is a safe placeholder. Replace it with your real FPP playback command(s).
