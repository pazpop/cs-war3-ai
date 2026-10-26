<?php
// The server's state right now, in JSON, for other sites (pazpop.net shows it): humans, bots, map, slots.
// Asked to the game like the server browser does (A2S_INFO), at most every 15 seconds: the answer is kept in a file,
// so that nobody can flood the game through this page.
declare(strict_types=1);
ini_set('display_errors', '0');

const CACHE = '/tmp/status.json';

header('Content-Type: application/json');
// Public data: any site may read it.
header('Access-Control-Allow-Origin: *');

if (is_file(CACHE) && filemtime(CACHE) > time() - 15) {
    readfile(CACHE);
    exit;
}
// While this request asks the game (up to 4 seconds if it is down), the others get the last answer.
if (is_file(CACHE)) {
    touch(CACHE);
}

// Reads a text field (ended by a zero byte) at $at, and moves $at past it.
function text(string $reply, int &$at): string
{
    $end = strpos($reply, "\0", $at);
    if ($end === false) {
        $end = strlen($reply);
    }
    $value = substr($reply, $at, $end - $at);
    $at = $end + 1;
    return $value;
}

$status = ['online' => false];
// Through the host's published port: the game is on its own network (compose.yml).
$udp = @fsockopen('udp://host.docker.internal', 27015, $errno, $error, 2);
if ($udp) {
    stream_set_timeout($udp, 2);
    $query = "\xff\xff\xff\xffTSource Engine Query\0";
    fwrite($udp, $query);
    $reply = (string) fread($udp, 1400);
    // The server may first answer with a challenge ("A" and 4 bytes) to send back.
    if (substr($reply, 4, 1) === 'A') {
        fwrite($udp, $query . substr($reply, 5, 4));
        $reply = (string) fread($udp, 1400);
    }
    fclose($udp);

    // "I", the protocol, 4 texts (name, map, folder, game), the game's number (2 bytes), then players, slots, bots.
    if (substr($reply, 4, 1) === 'I') {
        $at = 6;
        text($reply, $at);
        $map = text($reply, $at);
        text($reply, $at);
        text($reply, $at);
        $at += 2;
        if (strlen($reply) >= $at + 3) {
            $players = ord($reply[$at]);
            $bots = ord($reply[$at + 2]);
            $status = [
                'online' => true,
                'humans' => max(0, $players - $bots),
                'bots' => $bots,
                'slots' => ord($reply[$at + 1]),
                'map' => $map,
            ];
        }
    }
}

// A map name that is not UTF-8 would make json_encode fail: its bad bytes are replaced.
$json = json_encode($status, JSON_INVALID_UTF8_SUBSTITUTE);
// Written next to it, then renamed: a request at the same moment never reads a half-written file.
file_put_contents(CACHE . '.tmp', $json);
rename(CACHE . '.tmp', CACHE);
echo $json;
