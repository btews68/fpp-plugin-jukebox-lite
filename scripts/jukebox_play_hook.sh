#!/bin/bash
set -euo pipefail

MEDIA_TYPE="${1:-}"
MEDIA_REF="${2:-}"
REQUEST_ID="${3:-}"
TITLE="${4:-}"

FPP_API_BASE="${FPP_API_BASE:-http://127.0.0.1}"

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

play_sequence() {
	local seq_ref="$1"
	local seq_path="$seq_ref"

	if [[ "$seq_ref" != /* ]]; then
		seq_path="/home/fpp/media/${seq_ref}"
	fi

	if [[ ! -f "$seq_path" ]]; then
		log "sequence file not found: ${seq_path}"
	fi

	if [[ -x /opt/fpp/scripts/play_sequence.sh ]]; then
		/opt/fpp/scripts/play_sequence.sh "$seq_ref"
		return 0
	fi

	local encoded
	encoded="$(urlencode "$seq_ref")"

	# Try both variants to support API differences across FPP versions.
	call_fpp_api "/api/command/Start%20Sequence/${encoded}" || \
	call_fpp_api "/api/command/StartSequence/${encoded}"
}

play_playlist() {
	local playlist_name="$1"
	local encoded
	encoded="$(urlencode "$playlist_name")"

	call_fpp_api "/api/command/Playlist/Start/${encoded}"
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
