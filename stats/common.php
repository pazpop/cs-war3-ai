<?php
// What the pages share: the database, escaping, the races and their skills.
// Everything that comes from the database goes through e(): players choose their own name.
declare(strict_types=1);
ini_set('display_errors', '0');
// The VPS's time zone (.env, written by Ansible), like the rest of the server.
date_default_timezone_set(getenv('TIMEZONE') ?: 'UTC');

// The 8 War3FT races (the 9th, Chameleon, is off: wc3_races 8).
const RACES = [
    1 => 'Undead Scourge',
    2 => 'Human Alliance',
    3 => 'Orcish Horde',
    4 => 'Night Elves',
    5 => 'Blood Mage',
    6 => 'Shadow Hunter',
    7 => 'Warden',
    8 => 'Crypt Lord',
];

// War3FT's skill numbers, per race; the last one is the ultimate.
const SKILLS = [
    1 => [0 => 'Vampiric Aura', 1 => 'Unholy Aura', 2 => 'Levitation', 3 => 'Suicide Bomber'],
    2 => [4 => 'Invisibility', 5 => 'Devotion Aura', 6 => 'Bash', 7 => 'Teleport'],
    3 => [8 => 'Critical Strike', 9 => 'Critical Grenade', 10 => 'Equipment Reincarnation', 11 => 'Chain Lightning'],
    4 => [12 => 'Evasion', 13 => 'Thorns Aura', 14 => 'Trueshot Aura', 15 => 'Entangle Roots'],
    5 => [16 => 'Phoenix', 17 => 'Banish', 18 => 'Siphon Mana', 19 => 'Immolate'],
    6 => [21 => 'Healing Wave', 22 => 'Hex', 23 => 'Serpent Ward', 24 => 'Big Bad Voodoo'],
    7 => [26 => 'Fan of Knives', 27 => 'Blink', 28 => 'Shadow Strike', 29 => 'Vengeance'],
    8 => [31 => 'Impale', 32 => 'Spiked Carapace', 33 => 'Carrion Beetles', 34 => 'Locust Swarm'],
];

function e(string $text): string
{
    return htmlspecialchars($text, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

// Read-only: the pages cannot write anything into the game's database (or the AI relay's, /ai/ai.sq3).
function db(string $path = '/data/war3ft.sq3'): PDO
{
    return new PDO('sqlite:' . $path, null, null, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        Pdo\Sqlite::ATTR_OPEN_FLAGS => Pdo\Sqlite::OPEN_READONLY,
        PDO::ATTR_TIMEOUT => 2,
    ]);
}

// A database error: logged, and a 503 so that the heartbeat (ansible/files/heartbeat.py) sees it too.
function failed(PDOException $exception): bool
{
    error_log('stats: ' . $exception->getMessage());
    http_response_code(503);
    return true;
}

// The game's state right now, asked like the server browser does (A2S_INFO), at most every 15 seconds: the answer is
// kept in a file, so that nobody can flood the game through the pages. ['online' => false] when it does not answer.
const STATUS_CACHE = '/tmp/status.json';

function server_status(): array
{
    if (is_file(STATUS_CACHE) && filemtime(STATUS_CACHE) > time() - 15) {
        return json_decode((string) file_get_contents(STATUS_CACHE), true) ?: ['online' => false];
    }
    // While this request asks the game (up to 4 seconds if it is down), the others get the last answer.
    if (is_file(STATUS_CACHE)) {
        touch(STATUS_CACHE);
    }
    $status = ask_game();
    // Written next to it, then renamed: a request at the same moment never reads a half-written file.
    file_put_contents(STATUS_CACHE . '.tmp', json_encode($status, JSON_INVALID_UTF8_SUBSTITUTE));
    rename(STATUS_CACHE . '.tmp', STATUS_CACHE);
    return $status;
}

function ask_game(): array
{
    // Through the host's published port: the game is on its own network (compose.yml).
    $udp = @fsockopen('udp://host.docker.internal', 27015, $errno, $error, 2);
    if (!$udp) {
        return ['online' => false];
    }
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

    // "I", the protocol, 4 texts ended by a zero byte (name, map, folder, game), the game's number (2 bytes), then
    // players, slots, bots.
    if (substr($reply, 4, 1) !== 'I') {
        return ['online' => false];
    }
    $texts = explode("\0", substr($reply, 6), 5);
    if (count($texts) < 5 || strlen($texts[4]) < 5) {
        return ['online' => false];
    }
    [$players, $slots, $bots] = [ord($texts[4][2]), ord($texts[4][3]), ord($texts[4][4])];
    return [
        'online' => true,
        'humans' => max(0, $players - $bots),
        'bots' => $bots,
        'slots' => $slots,
        'map' => $texts[1],
    ];
}

// steam://connect: one click starts the game and joins the server (the address comes from the request's host).
function join_link(): string
{
    $server = e(($_SERVER['SERVER_NAME'] ?? '') . ':27015');
    return '<a class="join" href="steam://connect/' . $server . '">Join the server</a>'
        . ' <code>connect ' . $server . '</code>';
}

// A readable percentage, without dividing by zero.
function percent(int $part, int $total): string
{
    return $total > 0 ? number_format(100 * $part / $total, 1) . ' %' : '-';
}

// A race's icon (img/races/<id>.png), before its name.
function race_icon(int $race): string
{
    return '<img class="icon" src="/img/races/' . $race . '.png" alt="" width="24" height="24">';
}

// The top of every page: the menu, then who plays right now and the join button.
function page_start(string $title): void
{
    $status = server_status();
    ?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= e($title) ?></title>
<link rel="stylesheet" href="/style.css">
</head>
<body>
<header class="top">
<a class="brand" href="/index.php"><img src="/img/logo.png" alt="" width="40" height="40">War3FT <span>AI</span></a>
<nav class="menu"><a href="/index.php">Rankings</a> <a href="/bots.php">The bots</a> <a href="/guide.html">Guide</a></nav>
</header>
<div class="live">
<?php if ($status['online']): ?>
<span class="dot on"></span> <?= (int) $status['humans'] ?> <?= $status['humans'] == 1 ? 'player' : 'players' ?> and
<?= (int) $status['bots'] ?> bots on
<b><?= e((string) $status['map']) ?></b>
<?php else: ?>
<span class="dot"></span> The server does not answer right now.
<?php endif; ?>
<span class="join-box"><?= join_link() ?></span>
</div>
<main>
<?php
}

function page_end(): void
{
    ?>
<footer>
<a href="/index.php">Rankings</a> ·
<a href="/bots.php">The bots</a> ·
<a href="/guide.html">The mod guide</a> ·
<a href="https://github.com/pazpop/cs-war3-ai/blob/main/docs/client.md">Optimized client config</a> ·
<a href="https://github.com/pazpop/cs-war3-ai">Server source code</a>
</footer>
</main>
</body>
</html>
<?php
}
