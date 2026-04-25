<?php
$pluginName = 'fpp-plugin-jukebox-lite';
?>

<h2>Jukebox Lite Configuration</h2>
<p>Set your Hostinger API endpoint and API key for queue polling.</p>

<div class='container-fluid' style='max-width: 980px; margin-left: 0;'>
  <div class='row mb-2'>
    <div class='col-md-4'><label for='apiBase'><b>API Base URL</b></label></div>
    <div class='col-md-8'><input id='apiBase' class='form-control' type='text' placeholder='https://your-domain.com/api.php/api/v1'></div>
  </div>

  <div class='row mb-2'>
    <div class='col-md-4'><label for='apiKey'><b>API Key</b></label></div>
    <div class='col-md-8'><input id='apiKey' class='form-control' type='password'></div>
  </div>

  <div class='row mb-2'>
    <div class='col-md-4'><label for='playerId'><b>Player ID</b></label></div>
    <div class='col-md-8'><input id='playerId' class='form-control' type='text' placeholder='fpp-main'></div>
  </div>

  <div class='row mb-2'>
    <div class='col-md-4'><label for='pollSec'><b>Poll Seconds</b></label></div>
    <div class='col-md-8'><input id='pollSec' class='form-control' type='number' min='1' max='30' value='3'></div>
  </div>

  <div class='row mb-2'>
    <div class='col-md-4'><label for='httpTimeoutSec'><b>HTTP Timeout Seconds</b></label></div>
    <div class='col-md-8'><input id='httpTimeoutSec' class='form-control' type='number' min='1' max='20' value='4'></div>
  </div>

  <div class='row mb-2'>
    <div class='col-md-4'><label for='playCmd'><b>Play Hook Script</b></label></div>
    <div class='col-md-8'><input id='playCmd' class='form-control' type='text' placeholder='/home/fpp/media/scripts/jukebox_play_hook.sh'></div>
  </div>

  <div class='row mb-2'>
    <div class='col-md-4'><label for='idlePlaylist'><b>Idle Playlist (optional)</b></label></div>
    <div class='col-md-8'><input id='idlePlaylist' class='form-control' type='text' placeholder='Fallback playlist name'></div>
  </div>

  <div class='row mb-2'>
    <div class='col-md-4'><label for='failOpen'><b>Fail Open</b></label></div>
    <div class='col-md-8'>
      <select id='failOpen' class='form-control'>
        <option value='1'>Enabled</option>
        <option value='0'>Disabled</option>
      </select>
    </div>
  </div>

  <div class='row mb-3'>
    <div class='col-md-12'>
      <button id='saveBtn' class='buttons btn-success'>Save Settings</button>
      <button id='testNextBtn' class='buttons btn-outline-primary'>Test Claim + Play Once</button>
    </div>
  </div>

  <h3>Status</h3>
  <pre id='statusOutput' style='min-height: 120px; background: #111; color: #ddd; padding: 12px; border-radius: 6px;'>Ready.</pre>
</div>

<script>
(function () {
  const plugin = '<?php echo $pluginName; ?>';
  const map = {
    JUKEBOX_API_BASE: 'apiBase',
    JUKEBOX_API_KEY: 'apiKey',
    JUKEBOX_PLAYER_ID: 'playerId',
    JUKEBOX_POLL_SEC: 'pollSec',
    JUKEBOX_HTTP_TIMEOUT_SEC: 'httpTimeoutSec',
    JUKEBOX_PLAY_CMD: 'playCmd',
    JUKEBOX_IDLE_PLAYLIST: 'idlePlaylist',
    JUKEBOX_FAIL_OPEN: 'failOpen'
  };

  function showStatus(data) {
    document.getElementById('statusOutput').textContent =
      typeof data === 'string' ? data : JSON.stringify(data, null, 2);
  }

  async function getSetting(key) {
    const resp = await fetch(`api/plugin/${plugin}/settings/${encodeURIComponent(key)}`);
    const json = await resp.json();
    return json[key] || '';
  }

  async function setSetting(key, value) {
    const resp = await fetch(`api/plugin/${plugin}/settings/${encodeURIComponent(key)}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'text/plain' },
      body: value
    });
    return await resp.json();
  }

  async function loadSettings() {
    for (const [key, id] of Object.entries(map)) {
      try {
        const value = await getSetting(key);
        const el = document.getElementById(id);
        if (value !== '') {
          el.value = value;
        }
      } catch (err) {
        showStatus(`Failed to load ${key}: ${err}`);
      }
    }

    if (!document.getElementById('apiBase').value) {
      document.getElementById('apiBase').value = 'https://your-domain.com/api.php/api/v1';
    }
    if (!document.getElementById('playerId').value) {
      document.getElementById('playerId').value = 'fpp-main';
    }
    if (!document.getElementById('playCmd').value) {
      document.getElementById('playCmd').value = '/home/fpp/media/scripts/jukebox_play_hook.sh';
    }
  }

  async function saveSettings() {
    const results = {};
    for (const [key, id] of Object.entries(map)) {
      const value = document.getElementById(id).value;
      results[key] = await setSetting(key, value);
    }
    showStatus({ ok: true, message: 'Settings saved', results });
  }

  async function testNext() {
    const resp = await fetch(`api/plugin/${plugin}/test-next`, { method: 'POST' });
    const json = await resp.json();
    showStatus(json);
  }

  document.getElementById('saveBtn').addEventListener('click', () => {
    saveSettings().catch(err => showStatus(String(err)));
  });

  document.getElementById('testNextBtn').addEventListener('click', () => {
    testNext().catch(err => showStatus(String(err)));
  });

  loadSettings().then(() => showStatus('Ready.')).catch(err => showStatus(String(err)));
})();
</script>
