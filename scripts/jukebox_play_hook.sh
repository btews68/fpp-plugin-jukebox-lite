#!/bin/bash
set -euo pipefail

MEDIA_TYPE="${1:-}"
MEDIA_REF="${2:-}"
REQUEST_ID="${3:-}"
TITLE="${4:-}"

# Replace this hook with your preferred playback command.
# Return non-zero to trigger /fpp/failed in the API.
# Examples you can adapt:
# - /opt/fpp/scripts/play_sequence.sh "$MEDIA_REF"
# - curl -s "http://127.0.0.1/api/command/Playlist/Start/${MEDIA_REF}"

echo "play-hook request=${REQUEST_ID} type=${MEDIA_TYPE} ref=${MEDIA_REF} title=${TITLE}"
exit 0
