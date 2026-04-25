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

try_get_paths() {
	local -n _paths_ref=$1
	local code
	local diagnostics=""

	for path in "${_paths_ref[@]}"; do
		code="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "${FPP_API_BASE}${path}" || true)"
		if [[ "$code" =~ ^2 ]]; then
			return 0
		fi
		diagnostics+="GET ${path} -> ${code}; "
	done

	echo "$diagnostics"
	return 1
}

try_post_payloads() {
	local -n _payloads_ref=$1
	local code
	local diagnostics=""

	for payload in "${_payloads_ref[@]}"; do
		code="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 -X POST \
			-H "Content-Type: application/json" \
			-d "$payload" \
			"${FPP_API_BASE}/api/command" || true)"
		if [[ "$code" =~ ^2 ]]; then
			return 0
		fi
		diagnostics+="POST /api/command payload=${payload} -> ${code}; "
	done

	echo "$diagnostics"
	return 1
}

play_sequence() {
	local seq_ref="$1"

	# FPP command API wants just the bare filename, not the Sequences/ prefix.
	local seq_name
	seq_name="$(basename "$seq_ref")"

	# Prefer local FPP helper script when present for maximum version compatibility.
	if [[ -x /opt/fpp/scripts/play_sequence.sh ]]; then
		if /opt/fpp/scripts/play_sequence.sh "$seq_name" >/dev/null 2>&1; then
			return 0
		fi

		if /opt/fpp/scripts/play_sequence.sh "$seq_ref" >/dev/null 2>&1; then
			return 0
		fi

		if [[ -f "/home/fpp/media/Sequences/${seq_name}" ]] && /opt/fpp/scripts/play_sequence.sh "/home/fpp/media/Sequences/${seq_name}" >/dev/null 2>&1; then
			return 0
		fi
	fi

	local encoded
	encoded="$(urlencode "$seq_name")"

	# Try multiple POST payload variants used by different FPP builds.
	local post_payloads=(
		"{\"command\":\"Start Sequence\",\"args\":[\"${seq_name}\"]}"
		"{\"command\":\"StartSequence\",\"args\":[\"${seq_name}\"]}"
		"{\"command\":\"Start Sequence\",\"args\":[\"${seq_ref}\"]}"
	)
	if try_post_payloads post_payloads >/dev/null; then
		return 0
	fi

	# Fallback: GET-style endpoints seen across FPP versions.
	local get_paths=(
		"/api/command/Start%20Sequence/${encoded}"
		"/api/command/StartSequence/${encoded}"
		"/api/command/Sequence/Start/${encoded}"
		"/api/sequence/${encoded}/start"
	)

	local details
	details="$(try_get_paths get_paths)"
	log "sequence start failed. attempted: ${details}"
	return 1
}

play_playlist() {
	local playlist_name="$1"
	local encoded
	encoded="$(urlencode "$playlist_name")"

	local post_payloads=(
		"{\"command\":\"Start Playlist\",\"args\":[\"${playlist_name}\"]}"
		"{\"command\":\"Playlist Start\",\"args\":[\"${playlist_name}\"]}"
	)
	if try_post_payloads post_payloads >/dev/null; then
		return 0
	fi

	local get_paths=(
		"/api/command/Playlist/Start/${encoded}"
		"/api/playlist/${encoded}/start"
	)

	local details
	details="$(try_get_paths get_paths)"
	log "playlist start failed. attempted: ${details}"
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
