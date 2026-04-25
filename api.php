<?php

function getEndpointsfpppluginjukeboxlite() {
    $result = array();

    $result[] = array(
        'method' => 'POST',
        'endpoint' => 'test-next',
        'callback' => 'fpppluginjukeboxliteTestNext'
    );

    return $result;
}

function fpppluginjukeboxliteTestNext() {
    global $settings;

    $plugin = 'fpp-plugin-jukebox-lite';
    $script = $settings['pluginDirectory'] . '/' . $plugin . '/commands/jukebox_once.sh';
    $cmd = escapeshellarg($script) . ' 2>&1';

    $output = array();
    $rc = 0;
    exec($cmd, $output, $rc);

    return json(array(
        'ok' => $rc === 0,
        'rc' => $rc,
        'output' => implode("\n", $output)
    ));
}

?>
