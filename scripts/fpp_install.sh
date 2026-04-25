#!/bin/bash
set -euo pipefail

PLUGIN_DIR="/home/fpp/media/plugins/fpp-plugin-jukebox-lite"
SCRIPTS_DIR="/home/fpp/media/scripts"
CONFIG_FILE="/home/fpp/media/config/plugin.fpp-plugin-jukebox-lite"

mkdir -p "${SCRIPTS_DIR}"

ln -sf "${PLUGIN_DIR}/commands/jukebox_once.sh" "${SCRIPTS_DIR}/jukebox_once.sh"
ln -sf "${PLUGIN_DIR}/commands/jukebox_poll.sh" "${SCRIPTS_DIR}/jukebox_poll.sh"
ln -sf "${PLUGIN_DIR}/scripts/jukebox_play_hook.sh" "${SCRIPTS_DIR}/jukebox_play_hook.sh"

chmod +x "${PLUGIN_DIR}/commands/jukebox_once.sh"
chmod +x "${PLUGIN_DIR}/commands/jukebox_poll.sh"
chmod +x "${PLUGIN_DIR}/commands/jukebox_client.py"
chmod +x "${PLUGIN_DIR}/scripts/jukebox_play_hook.sh"

if [[ ! -f "${CONFIG_FILE}" ]]; then
cat > "${CONFIG_FILE}" <<'EOF'
[plugin]
JUKEBOX_API_BASE = https://your-domain.com/api.php/api/v1
JUKEBOX_API_KEY = replace-with-api-key
JUKEBOX_PLAYER_ID = fpp-main
JUKEBOX_POLL_SEC = 3
JUKEBOX_HTTP_TIMEOUT_SEC = 4
JUKEBOX_FAIL_OPEN = 1
JUKEBOX_IDLE_PLAYLIST =
JUKEBOX_PLAY_CMD = /home/fpp/media/scripts/jukebox_play_hook.sh
EOF
fi

echo "Install complete for fpp-plugin-jukebox-lite"
