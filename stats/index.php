<?php
// The rankings: the month's (server/plugins/monthly.sma), War3FT's XP (per race), CS's combat (/rank, /top15), and
// the latest achievements (server/plugins/achievements.sma).
require __DIR__ . '/common.php';

$race = filter_input(INPUT_GET, 'race', FILTER_VALIDATE_INT, ['options' => ['min_range' => 1, 'max_range' => 8]]);
$race = is_int($race) ? $race : null;

$players = ['total' => 0, 'month' => 0, 'quarter' => 0];
$monthly = [];
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

    // The current month (UTC): kills minus deaths.
    $monthly = $db->query(
        "SELECT m.kills, m.deaths, m.headshots, p.player_id, COALESCE(n.name, '?') AS name
         FROM cs_war3_ai_monthly m
         LEFT JOIN wc3_player p ON p.player_steamid = m.steamid
         LEFT JOIN cs_war3_ai_names n ON n.steamid = m.steamid
         WHERE m.month = strftime('%Y-%m', 'now') ORDER BY m.kills - m.deaths DESC, m.kills DESC LIMIT 15"
    )->fetchAll();

    // The top 3 of each past month, the same order as the [Champion] tag (server/plugins/rank_tag.sma).
    $champions = $db->query(
        "SELECT month, player_id, name FROM (
             SELECT m.month, p.player_id, COALESCE(n.name, '?') AS name,
                    ROW_NUMBER() OVER (PARTITION BY m.month ORDER BY m.kills - m.deaths DESC, m.kills DESC) AS place
             FROM cs_war3_ai_monthly m
             LEFT JOIN wc3_player p ON p.player_steamid = m.steamid
             LEFT JOIN cs_war3_ai_names n ON n.steamid = m.steamid
             WHERE m.month < strftime('%Y-%m', 'now'))
         WHERE place <= 3 ORDER BY month DESC, place"
    )->fetchAll();

    // One row per month: its podium, in order.
    foreach ($champions as $row) {
        $hall[$row['month']][] = $row;
    }

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
        "SELECT c.*, p.player_id FROM cs_war3_ai_combat c
         LEFT JOIN wc3_player p ON p.player_steamid = c.steamid
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

// The name, with a link to the player's page when War3FT knows the player.
function player_link(array $row): string
{
    $name = e((string) $row['name']);
    return $row['player_id'] ? '<a href="/player.php?id=' . (int) $row['player_id'] . '">' . $name . '</a>' : $name;
}

page_start('War3FT: rankings');
?>
<img class="banner" src="/img/banner.png" alt="" width="400" height="160">
<h1>War3FT: rankings</h1>
<p>A Counter-Strike 1.6 server with Warcraft 3 races and spells, and <a href="/bots.php">bots that talk back</a>.</p>

<?php if ($failed): ?>
<p>Rankings are not available right now. Try again in a minute.</p>
<?php else: ?>
<p><?= (int) $players['total'] ?> players have joined since launch: <?= (int) $players['month'] ?> in the last 30 days,
<?= (int) $players['quarter'] ?> in the last 90 days.</p>

<h2>This month: <?= gmdate('F Y') ?></h2>
<p>Everyone starts from zero on the 1st (UTC).
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
<td><?= e(gmdate('F Y', (int) strtotime($month . '-01 UTC'))) ?></td>
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
<td><?= gmdate('Y-m-d', (int) $row['unlocked']) ?></td>
</tr>
<?php endforeach; ?>
</tbody>
</table>
<?php endif; ?>

<?php endif; ?>
<?php page_end(); ?>
