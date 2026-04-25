#!/bin/bash
set -euo pipefail

MEDIA_TYPE="${1:-}"
MEDIA_REF="${2:-}"
REQUEST_ID="${3:-}"
TITLE="${4:-}"

FPP_API_BASE="${FPP_API_BASE:-http://127.0.0.1}"
VERIFY_START="${JUKEBOX_VERIFY_START:-1}"

log() {
	echo "[jukebox_play_hook] $*"
}

urlencode() {
	python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

call_fpp_api() {
	local path="$1"
	curl -fsS --max-time 10 "${FPP_API_BASE}${path}" >/dev/null
}

try_post_command() {
	local payload="$1"
	local code
	code="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 -X POST \
		-H "Content-Type: application/json" \
		-d "$payload" \
		"${FPP_API_BASE}/api/command" || true)"
	if [[ "$code" =~ ^2 ]]; then
		return 0
	fi
	ATTEMPTS+="POST /api/command payload=${payload} -> ${code}; "
	return 1
}

try_get_command() {
	local path="$1"
	local code
	code="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "${FPP_API_BASE}${path}" || true)"
	if [[ "$code" =~ ^2 ]]; then
		return 0
	fi
	ATTEMPTS+="GET ${path} -> ${code}; "
	return 1
}

sequence_is_active() {
	local seq_name="$1"
	local body

	body="$(curl -sS --max-time 6 "${FPP_API_BASE}/api/fppd/status" || true)"
	if [[ -n "$body" ]] && echo "$body" | grep -Fq "$seq_name"; then
		return 0
	fi

	body="$(curl -sS --max-time 6 "${FPP_API_BASE}/api/status" || true)"
	if [[ -n "$body" ]] && echo "$body" | grep -Fq "$seq_name"; then
		return 0
	fi

	return 1
}

confirm_sequence_started() {
	local seq_name="$1"

	if [[ "$VERIFY_START" != "1" ]]; then
		return 0
	fi

	local i
	for i in 1 2 3 4 5; do
		if sequence_is_active "$seq_name"; then
			return 0
		fi
		sleep 1
	done

	ATTEMPTS+="trigger accepted but ${seq_name} not seen active in status; "
	return 1
}

play_sequence() {
	local seq_ref="$1"
  ATTEMPTS=""

	# FPP command API wants just the bare filename, not the Sequences/ prefix.
	local seq_name
	seq_name="$(basename "$seq_ref")"

	# Prefer local FPP helper script when present for maximum version compatibility.
	if [[ -x /opt/fpp/scripts/play_sequence.sh ]]; then
		if /opt/fpp/scripts/play_sequence.sh "$seq_name" >/dev/null 2>&1 && confirm_sequence_started "$seq_name"; then
			return 0
		fi

		if /opt/fpp/scripts/play_sequence.sh "$seq_ref" >/dev/null 2>&1 && confirm_sequence_started "$seq_name"; then
			return 0
		fi

		if [[ -f "/home/fpp/media/Sequences/${seq_name}" ]] && /opt/fpp/scripts/play_sequence.sh "/home/fpp/media/Sequences/${seq_name}" >/dev/null 2>&1 && confirm_sequence_started "$seq_name"; then
			return 0
		fi
	fi

	local encoded
	encoded="$(urlencode "$seq_name")"

	if try_post_command "{\"command\":\"Start Sequence\",\"args\":[\"${seq_name}\"]}" && confirm_sequence_started "$seq_name"; then
		return 0
	fi
	if try_post_command "{\"command\":\"StartSequence\",\"args\":[\"${seq_name}\"]}" && confirm_sequence_started "$seq_name"; then
		return 0
	fi
	if try_post_command "{\"command\":\"Start Sequence\",\"args\":[\"${seq_ref}\"]}" && confirm_sequence_started "$seq_name"; then
		return 0
	fi

	if try_get_command "/api/command/Start%20Sequence/${encoded}" && confirm_sequence_started "$seq_name"; then
		return 0
	fi
	if try_get_command "/api/command/StartSequence/${encoded}" && confirm_sequence_started "$seq_name"; then
		return 0
	fi
	if try_get_command "/api/command/Sequence/Start/${encoded}" && confirm_sequence_started "$seq_name"; then
		return 0
	fi
	if try_get_command "/api/sequence/${encoded}/start" && confirm_sequence_started "$seq_name"; then
		return 0
	fi

	log "sequence start failed. attempted: ${ATTEMPTS}"
	return 1
}

play_playlist() {
	local playlist_name="$1"
	local encoded
	encoded="$(urlencode "$playlist_name")"
  ATTEMPTS=""

	if try_post_command "{\"command\":\"Start Playlist\",\"args\":[\"${playlist_name}\"]}"; then
		return 0
	fi
	if try_post_command "{\"command\":\"Playlist Start\",\"args\":[\"${playlist_name}\"]}"; then
		return 0
	fi

	if try_get_command "/api/command/Playlist/Start/${encoded}"; then
		return 0
	fi
	if try_get_command "/api/playlist/${encoded}/start"; then
		return 0
	fi

	log "playlist start failed. attempted: ${ATTEMPTS}"
	return 1
}

if [[ -z "$MEDIA_TYPE" || -z "$MEDIA_REF" ]]; then
	log "missing required args: type='${MEDIA_TYPE}' ref='${MEDIA_REF}' request='${REQUEST_ID}'"
	exit 2
fi

log "request=${REQUEST_ID} type=${MEDIA_TYPE} ref=${MEDIA_REF} title=${TITLE}"

case "$MEDIA_TYPE" in
	sequence)
		play_sequence "$MEDIA_REF"
		;;
	playlist)
		play_playlist "$MEDIA_REF"
		;;
	*)
		log "unsupported media type: ${MEDIA_TYPE}"
		exit 2
		;;
esac

log "playback start triggered"
exit 0
