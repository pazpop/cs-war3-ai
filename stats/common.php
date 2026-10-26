<?php
// What the pages share: the database, escaping, the races and their skills.
// Everything that comes from the database goes through e(): players choose their own name.
declare(strict_types=1);
ini_set('display_errors', '0');

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

// Read-only: the pages cannot write anything into the game's database.
function db(): PDO
{
    return new PDO('sqlite:/data/war3ft.sq3', null, null, [
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

function page_start(string $title): void
{
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
<main>
<p><?= join_link() ?></p>
<?php
}

function page_end(): void
{
    ?>
<footer>
<a href="/index.php">Rankings</a> ·
<a href="/guide.html">The mod guide</a> ·
<a href="https://github.com/pazpop/cs-war3-ai/blob/main/docs/client.md">Optimized client config</a> ·
<a href="https://github.com/pazpop/cs-war3-ai">Server source code</a>
</footer>
</main>
</body>
</html>
<?php
}
