<?php
// The home page: the Game Master's journal (ai/relay.py), the rankings: the month's and its MVPs
// (server/plugins/monthly.sma), the goal of the week's (server/plugins/weekly.sma), War3FT's XP (per race), CS's
// combat (/rank, /top15), and the latest achievements (server/plugins/achievements.sma).
require __DIR__ . '/common.php';

// The AI relay's journal, the last 3 days. None yet: no section.
$journal = [];
try {
    $journal = db('/ai/ai.sq3')->query('SELECT day, text FROM journal ORDER BY day DESC LIMIT 3')->fetchAll();
} catch (PDOException $exception) {
    error_log('journal: ' . $exception->getMessage());
}

$race = filter_input(INPUT_GET, 'race', FILTER_VALIDATE_INT, ['options' => ['min_range' => 1, 'max_range' => 8]]);
$race = is_int($race) ? $race : null;

$players = ['total' => 0, 'month' => 0, 'quarter' => 0];
$monthly = [];
$mvps = [];
$goal = false;
$weekly = [];
$hall = [];
$xp = [];
$combat = [];
$achievements = 0;
$latest = [];
$failed = false;
try {
    $db = db();
    // War3FT records every human on connect, with the day of their last visit (a Julian day number).
    $players = $db->query(
        "SELECT COUNT(*) AS total,
                COALESCE(SUM(time > julianday('now') - 30), 0) AS month,
                COALESCE(SUM(time > julianday('now') - 90), 0) AS quarter
         FROM wc3_player WHERE player_steamid GLOB 'STEAM_[0-5]:[01]:[0-9]*'"
    )->fetch();

    // The current month (the VPS's time): kills minus deaths.
    $monthly = $db->query(
        "SELECT m.kills, m.deaths, m.headshots, p.player_id, COALESCE(n.name, '?') AS name
         FROM cs_war3_ai_monthly m
         LEFT JOIN wc3_player p ON p.player_steamid = m.steamid
         LEFT JOIN cs_war3_ai_names n ON n.steamid = m.steamid
         WHERE m.month = strftime('%Y-%m', 'now', 'localtime') ORDER BY m.kills - m.deaths DESC, m.kills DESC LIMIT 15"
    )->fetchAll();

    // The month's map MVPs: who was most often on top of the scoreboard at a map's end (server/plugins/monthly.sma).
    $mvps = $db->query(
        "SELECT v.count, p.player_id, COALESCE(n.name, '?') AS name
         FROM cs_war3_ai_mvp v
         LEFT JOIN wc3_player p ON p.player_steamid = v.steamid
         LEFT JOIN cs_war3_ai_names n ON n.steamid = v.steamid
         WHERE v.month = strftime('%Y-%m', 'now', 'localtime') ORDER BY v.count DESC LIMIT 5"
    )->fetchAll();

    // The top 3 of each past month, the same order as the [Champion] tag (server/plugins/rank_tag.sma).
    $champions = $db->query(
        "SELECT month, player_id, name FROM (
             SELECT m.month, p.player_id, COALESCE(n.name, '?') AS name,
                    ROW_NUMBER() OVER (PARTITION BY m.month ORDER BY m.kills - m.deaths DESC, m.kills DESC) AS place
             FROM cs_war3_ai_monthly m
             LEFT JOIN wc3_player p ON p.player_steamid = m.steamid
             LEFT JOIN cs_war3_ai_names n ON n.steamid = m.steamid
             WHERE m.month < strftime('%Y-%m', 'now', 'localtime'))
         WHERE place <= 3 ORDER BY month DESC, place"
    )->fetchAll();

    // One row per month: its podium, in order.
    foreach ($champions as $row) {
        $hall[$row['month']][] = $row;
    }

    // This week's goal (written by the week's first map) and the 10 closest to it. The week as the plugin counts it.
    $week = "date('now', 'localtime', 'weekday 0', '-6 days')";  // its Monday
    $goal = $db->query("SELECT goal, target FROM cs_war3_ai_weekly_goal WHERE week = $week")->fetch();
    $weekly = $db->query(
        "SELECT w.count, p.player_id, COALESCE(n.name, '?') AS name
         FROM cs_war3_ai_weekly w
         LEFT JOIN wc3_player p ON p.player_steamid = w.steamid
         LEFT JOIN cs_war3_ai_names n ON n.steamid = w.steamid
         WHERE w.week = $week ORDER BY w.count DESC LIMIT 10"
    )->fetchAll();

    // Only real SteamIDs count (STEAM_X:Y:digits): not the bots ("BOT"), nor STEAM_ID_PENDING or STEAM_ID_LAN, which
    // many players share.
    $sql = "SELECT p.player_id, COALESCE(n.name, '?') AS name, r.race_id, r.race_xp
            FROM wc3_player_race r
            JOIN wc3_player p ON p.player_id = r.player_id
            LEFT JOIN cs_war3_ai_names n ON n.steamid = p.player_steamid
            WHERE p.player_steamid GLOB 'STEAM_[0-5]:[01]:[0-9]*' AND r.race_xp > 0 AND r.race_id BETWEEN 1 AND 8"
        . ($race ? ' AND r.race_id = :race' : '')
        . ' ORDER BY r.race_xp DESC LIMIT 50';
    $query = $db->prepare($sql);
    $query->execute($race ? [':race' => $race] : []);
    $xp = $query->fetchAll();

    $combat = $db->query(
        // The name the stats page knows (it follows a renaming), rather than the one CS's ranking kept.
        "SELECT c.position, c.kills, c.deaths, c.headshots, c.shots, c.hits, p.player_id,
                COALESCE(n.name, c.name) AS name
         FROM cs_war3_ai_combat c
         LEFT JOIN wc3_player p ON p.player_steamid = c.steamid
         LEFT JOIN cs_war3_ai_names n ON n.steamid = c.steamid
         ORDER BY c.position LIMIT 15"
    )->fetchAll();

    $achievements = (int) $db->query('SELECT COUNT(*) FROM ach_list')->fetchColumn();

    $latest = $db->query(
        "SELECT u.unlocked, l.name AS achievement, l.description, p.player_id, COALESCE(n.name, '?') AS name
         FROM ach_unlocked u JOIN ach_list l ON l.id = u.achievement
         LEFT JOIN wc3_player p ON p.player_steamid = u.steamid
         LEFT JOIN cs_war3_ai_names n ON n.steamid = u.steamid
         ORDER BY u.unlocked DESC LIMIT 10"
    )->fetchAll();
} catch (PDOException $exception) {
    $failed = failed($exception);
}

page_start('War3FT: rankings');
?>
<img class="banner" src="/img/banner.png" alt="" width="400" height="160">
<h1>War3FT: rankings</h1>
<p>A Counter-Strike 1.6 server with Warcraft 3 races and spells, and <a href="/bots.php">bots that talk back</a>.</p>

<?php if ($journal): ?>
<h2>The Game Master's journal</h2>
<?php foreach ($journal as $entry): ?>
<p><b><?= e(date('l, F j', (int) strtotime((string) $entry['day']))) ?>:</b> <?= e((string) $entry['text']) ?></p>
<?php endforeach; ?>
<p class="note">Written each night by the AI Game Master (Claude, by Anthropic), from the day's announcements and bot
lines.</p>
<?php endif; ?>

<?php if ($failed): ?>
<p>Rankings are not available right now. Try again in a minute.</p>
<?php else: ?>
<p><?= (int) $players['total'] ?> players have joined since launch: <?= (int) $players['month'] ?> in the last 30 days,
<?= (int) $players['quarter'] ?> in the last 90 days.</p>

<h2>This month: <?= date('F Y') ?></h2>
<p>Everyone starts from zero on the 1st (server time).
Kills minus deaths, updated when a player leaves and at each map change.</p>
<?php if (!$monthly): ?>
<p>Nobody on the board yet this month: be the first.</p>
<?php else: ?>
<table class="ranking">
<thead><tr><th>#</th><th>Player</th><th>Kills</th><th>Deaths</th><th>Headshot %</th></tr></thead>
<tbody>
<?php foreach ($monthly as $position => $row): ?>
<tr>
<td><?= $position + 1 ?></td>
<td><?= player_link($row) ?></td>
<td><?= (int) $row['kills'] ?></td>
<td><?= (int) $row['deaths'] ?></td>
<td><?= percent((int) $row['headshots'], (int) $row['kills']) ?></td>
</tr>
<?php endforeach; ?>
</tbody>
</table>
<?php endif; ?>

<?php if ($mvps): ?>
<h3>MVPs of the month</h3>
<p>At each map's end, the Game Master names the top of the scoreboard, bots included.</p>
<table class="ranking">
<thead><tr><th>#</th><th>Player</th><th>Maps won</th></tr></thead>
<tbody>
<?php foreach ($mvps as $position => $row): ?>
<tr>
<td><?= $position + 1 ?></td>
<td><?= player_link($row) ?></td>
<td><?= (int) $row['count'] ?></td>
</tr>
<?php endforeach; ?>
</tbody>
</table>
<?php endif; ?>

<?php if ($goal): ?>
<h2>Goal of the week: <?= e((string) $goal['goal']) ?></h2>
<p>The same for everyone, a new one every Monday. <code>/goal</code> in game shows your count. Updated when a player
leaves and at each map change.</p>
<?php if (!$weekly): ?>
<p>Nobody has started it yet: be the first.</p>
<?php else: ?>
<table class="ranking">
<thead><tr><th>#</th><th>Player</th><th>Progress</th></tr></thead>
<tbody>
<?php foreach ($weekly as $position => $row): ?>
<tr>
<td><?= $position + 1 ?></td>
<td><?= player_link($row) ?></td>
<td><?= min((int) $row['count'], (int) $goal['target']) ?> / <?= (int) $goal['target'] ?><?= (int) $row['count'] >= (int) $goal['target'] ? ' <b>done!</b>' : '' ?></td>
</tr>
<?php endforeach; ?>
</tbody>
</table>
<?php endif; ?>
<?php endif; ?>

<h2>Hall of fame</h2>
<p>The top 3 of each month. Last month's show a <code>[Champion]</code> tag in the chat, all month long.</p>
<?php if (!$hall): ?>
<p>The first champions are crowned on the 1st of next month.</p>
<?php else: ?>
<table>
<thead><tr><th>Month</th><th>1st</th><th>2nd</th><th>3rd</th></tr></thead>
<tbody>
<?php foreach ($hall as $month => $podium): ?>
<tr>
<td><?= e(date('F Y', (int) strtotime($month . '-01'))) ?></td>
<?php for ($i = 0; $i < 3; $i++): ?>
<td><?= isset($podium[$i]) ? player_link($podium[$i]) : '' ?></td>
<?php endfor; ?>
</tr>
<?php endforeach; ?>
</tbody>
</table>
<?php endif; ?>

<h2>XP</h2>
<nav class="races">
<a href="/index.php"<?= $race === null ? ' class="active"' : '' ?>>All</a>
<?php foreach (RACES as $id => $name): ?>
<a href="/index.php?race=<?= $id ?>"<?= $race === $id ? ' class="active"' : '' ?>><?= race_icon($id) ?><?= e($name) ?></a>
<?php endforeach; ?>
</nav>
<?php if (!$xp): ?>
<p>Nobody has any XP yet<?= $race ? ' with this race' : '' ?>.</p>
<?php else: ?>
<table class="ranking">
<thead><tr><th>#</th><th>Player</th><th>Race</th><th>XP</th></tr></thead>
<tbody>
<?php foreach ($xp as $position => $row): ?>
<tr>
<td><?= $position + 1 ?></td>
<td><?= player_link($row) ?></td>
<td><?= race_icon((int) $row['race_id']) ?><?= e(RACES[(int) $row['race_id']] ?? '?') ?></td>
<td><?= number_format((int) $row['race_xp']) ?></td>
</tr>
<?php endforeach; ?>
</tbody>
</table>
<?php endif; ?>

<h2>Combat (top 15)</h2>
<p>Same as <code>/top15</code> in game. Updated at each map change.</p>
<?php if (!$combat): ?>
<p>No combat stats yet: they show up after the first map change.</p>
<?php else: ?>
<table class="ranking">
<thead><tr><th>#</th><th>Player</th><th>Kills</th><th>Deaths</th><th>Headshot %</th><th>Accuracy</th></tr></thead>
<tbody>
<?php foreach ($combat as $row): ?>
<tr>
<td><?= (int) $row['position'] ?></td>
<td><?= player_link($row) ?></td>
<td><?= (int) $row['kills'] ?></td>
<td><?= (int) $row['deaths'] ?></td>
<td><?= percent((int) $row['headshots'], (int) $row['kills']) ?></td>
<td><?= percent((int) $row['hits'], (int) $row['shots']) ?></td>
</tr>
<?php endforeach; ?>
</tbody>
</table>
<?php endif; ?>

<h2>Latest achievements</h2>
<p><?= $achievements ?> goals to reach, from your first kill to 10,000. <code>/ach</code> in game shows yours.</p>
<?php if (!$latest): ?>
<p>Nobody has unlocked one yet.</p>
<?php else: ?>
<table>
<thead><tr><th>Player</th><th>Achievement</th><th>Date</th></tr></thead>
<tbody>
<?php foreach ($latest as $row): ?>
<tr>
<td><?= player_link($row) ?></td>
<td><?= e((string) $row['achievement']) ?>: <?= e((string) $row['description']) ?></td>
<td><?= date('Y-m-d', (int) $row['unlocked']) ?></td>
</tr>
<?php endforeach; ?>
</tbody>
</table>
<?php endif; ?>

<?php endif; ?>
<?php page_end(); ?>
