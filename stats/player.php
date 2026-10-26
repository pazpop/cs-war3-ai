<?php
// A player: XP and skills per race (War3FT), combat stats (CS, when in the top 100), and achievements.
require __DIR__ . '/common.php';

// An achievement's progress, "12 / 100"; the time is counted in seconds, shown in hours.
function progress_text(int $done, int $goal, string $counter): string
{
    $unit = $counter === 'seconds' ? 3600 : 1;
    return number_format(intdiv(min($done, $goal), $unit)) . ' / ' . number_format(intdiv($goal, $unit));
}

$id = filter_input(INPUT_GET, 'id', FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
$player = null;
$races = [];
$levels = [];
$combat = null;
$achievements = [];
$progress = [];
$failed = false;

if (is_int($id)) {
    try {
        $db = db();
        $query = $db->prepare(
            "SELECT p.player_id, p.player_steamid, COALESCE(n.name, '?') AS name
             FROM wc3_player p LEFT JOIN cs_war3_ai_names n ON n.steamid = p.player_steamid
             WHERE p.player_id = ? AND p.player_steamid GLOB 'STEAM_[0-5]:[01]:[0-9]*'"
        );
        $query->execute([$id]);
        $player = $query->fetch() ?: null;

        if ($player) {
            $query = $db->prepare(
                'SELECT race_id, race_xp FROM wc3_player_race
                 WHERE player_id = ? AND race_xp > 0 AND race_id BETWEEN 1 AND 8 ORDER BY race_xp DESC'
            );
            $query->execute([$id]);
            $races = $query->fetchAll();

            $query = $db->prepare('SELECT skill_id, skill_level FROM wc3_player_skill WHERE player_id = ?');
            $query->execute([$id]);
            foreach ($query->fetchAll() as $row) {
                $levels[(int) $row['skill_id']] = (int) $row['skill_level'];
            }

            $query = $db->prepare('SELECT * FROM cs_war3_ai_combat WHERE steamid = ?');
            $query->execute([$player['player_steamid']]);
            $combat = $query->fetch() ?: null;

            // The list comes from the plugin (server/plugins/achievements.sma), with this player's unlock dates.
            $query = $db->prepare(
                'SELECT l.name, l.description, l.counter, l.goal, u.unlocked FROM ach_list l
                 LEFT JOIN ach_unlocked u ON u.achievement = l.id AND u.steamid = ? ORDER BY l.position'
            );
            $query->execute([$player['player_steamid']]);
            $achievements = $query->fetchAll();

            $query = $db->prepare('SELECT * FROM ach_progress WHERE steamid = ?');
            $query->execute([$player['player_steamid']]);
            $progress = $query->fetch() ?: [];
        }
    } catch (PDOException $exception) {
        $failed = failed($exception);
    }
}

page_start($player ? 'War3FT: ' . $player['name'] : 'War3FT: player');
?>
<?php if ($failed): ?>
<h1>War3FT</h1>
<p>Stats are not available right now. Try again in a minute.</p>
<?php elseif (!$player): ?>
<h1>War3FT</h1>
<p>Unknown player.</p>
<?php else: ?>
<h1><?= e((string) $player['name']) ?></h1>

<?php if ($combat): ?>
<h2>Combat</h2>
<table class="ranking">
<thead><tr>
<th>Rank</th><th>Kills</th><th>Deaths</th><th>K/D</th><th>Headshot %</th><th>Accuracy</th><th>Damage</th>
</tr></thead>
<tbody><tr>
<td><?= (int) $combat['position'] ?></td>
<td><?= (int) $combat['kills'] ?></td>
<td><?= (int) $combat['deaths'] ?></td>
<td><?= (int) $combat['deaths'] > 0 ? number_format((int) $combat['kills'] / (int) $combat['deaths'], 2) : '-' ?></td>
<td><?= percent((int) $combat['headshots'], (int) $combat['kills']) ?></td>
<td><?= percent((int) $combat['hits'], (int) $combat['shots']) ?></td>
<td><?= number_format((int) $combat['damage']) ?></td>
</tr></tbody>
</table>
<?php endif; ?>

<h2>Races</h2>
<?php if (!$races): ?>
<p>No XP yet.</p>
<?php endif; ?>
<?php foreach ($races as $row):
    $race_id = (int) $row['race_id'];
    $skills = SKILLS[$race_id] ?? [];
    // One skill point per level: the points spent (a player may keep some unspent).
    $points = array_sum(array_map(fn ($skill) => $levels[$skill] ?? 0, array_keys($skills)));
?>
<h3><?= race_icon($race_id) ?><?= e(RACES[$race_id] ?? '?') ?> · <?= $points ?> skill points spent · <?= number_format((int) $row['race_xp']) ?> XP</h3>
<?php if ($skills): ?>
<table>
<?php foreach ($skills as $skill => $name): ?>
<tr>
<td><?= e($name) ?><?= $skill === array_key_last($skills) ? ' (ultimate)' : '' ?></td>
<td><?= $levels[$skill] ?? 0 ?></td>
</tr>
<?php endforeach; ?>
</table>
<?php endif; ?>
<?php endforeach; ?>

<h2>Achievements: <?= count(array_filter($achievements, fn ($row) => $row['unlocked'] !== null)) ?> of
<?= count($achievements) ?></h2>
<p>Updated when the player leaves, and at each map change. In game: <code>/ach</code>.</p>
<table>
<thead><tr><th>Achievement</th><th>Goal</th><th>Unlocked</th></tr></thead>
<tbody>
<?php foreach ($achievements as $row): ?>
<tr<?= $row['unlocked'] === null ? ' class="locked"' : '' ?>>
<td><?= e((string) $row['name']) ?></td>
<td><?= e((string) $row['description']) ?></td>
<td><?= $row['unlocked'] !== null
    ? date('Y-m-d', (int) $row['unlocked'])
    : progress_text((int) ($progress[$row['counter']] ?? 0), (int) $row['goal'], $row['counter']) ?></td>
</tr>
<?php endforeach; ?>
</tbody>
</table>
<?php endif; ?>
<?php page_end(); ?>
