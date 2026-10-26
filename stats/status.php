<?php
// The server's state right now, in JSON, for other sites (pazpop.net shows it): humans, bots, map, slots.
require __DIR__ . '/common.php';

header('Content-Type: application/json');
// Public data: any site may read it.
header('Access-Control-Allow-Origin: *');
echo json_encode(server_status(), JSON_INVALID_UTF8_SUBSTITUTE);
