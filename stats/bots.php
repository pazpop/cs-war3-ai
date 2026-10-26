<?php
// The bots: their names, races and characters, from server/bots.txt (the same list the AI relay reads), with a
// portrait each (img/bots/<name>.png).
require __DIR__ . '/common.php';

$bots = [];
foreach (file('/srv/server/bots.txt', FILE_IGNORE_NEW_LINES) ?: [] as $line) {
    [$name, $race, $character] = array_map('trim', explode('|', $line, 3)) + [1 => '', 2 => ''];
    if ($name !== '' && $line[0] !== ';') {
        $bots[$name] = ['race' => $race, 'character' => $character];
    }
}

// The bots' latest lines, from the AI relay's database (already checked by its moderator). None yet: no section.
$quotes = [];
try {
    $quotes = db('/ai/ai.sq3')->query('SELECT time, bot, line FROM quotes ORDER BY time DESC LIMIT 15')->fetchAll();
} catch (PDOException $exception) {
    error_log('bots: ' . $exception->getMessage());
}

// The great rivalries: the AI relay counts the kills between each bot and each human. The names and pages come from
// the game's database: the relay keeps only SteamIDs, never shown here.
const RIVAL = 5;  // ai/relay.py's RIVAL: killed this many times by a player, and more than it killed them
$rivalries = [];
try {
    $rivalries = db('/ai/ai.sq3')->query(
        'SELECT bot, steamid, human_wins, bot_wins FROM rivals ORDER BY human_wins + bot_wins DESC LIMIT 10'
    )->fetchAll();
    $names = [];
    if ($rivalries) {
        $ids = array_column($rivalries, 'steamid');
        $query = db()->prepare(
            'SELECT n.steamid, n.name, p.player_id FROM cs_war3_ai_names n
             LEFT JOIN wc3_player p ON p.player_steamid = n.steamid
             WHERE n.steamid IN (' . implode(', ', array_fill(0, count($ids), '?')) . ')'
        );
        $query->execute($ids);
        foreach ($query->fetchAll() as $row) {
            $names[$row['steamid']] = $row;
        }
    }
    foreach ($rivalries as $i => $rivalry) {
        $rivalries[$i]['name'] = $names[$rivalry['steamid']]['name'] ?? '?';
        $rivalries[$i]['player_id'] = $names[$rivalry['steamid']]['player_id'] ?? null;
    }
} catch (PDOException $exception) {
    error_log('rivalries: ' . $exception->getMessage());
}

page_start('War3FT: the bots');
?>
<h1>The bots</h1>
<p>When few people play, bots fill the server, <code>[AI]</code> in their name. They talk back: write a bot's name in
the chat, like <code>zed, nice shot</code>, or ask any question about the game with a <code>?</code>. Each one has its
own character, greets you when you arrive, and remembers you from one game to the next: kill one often, and it calls
you its rival. They never make fun of you.</p>

<?php if ($quotes): ?>
<h2>Overheard in the game</h2>
<table class="quotes">
<?php foreach ($quotes as $quote): ?>
<tr>
<td><img class="icon" src="/img/bots/<?= e(strtolower((string) $quote['bot'])) ?>.png" alt="" width="24" height="24"><b><?= e((string) $quote['bot']) ?></b></td>
<td><?= e((string) $quote['line']) ?></td>
<td><?= date('M j, H:i T', (int) $quote['time']) ?></td>
</tr>
<?php endforeach; ?>
</table>
<?php endif; ?>

<?php if ($rivalries): ?>
<h2>The great rivalries</h2>
<p>Each bot keeps the score against each human. Kill one <?= RIVAL ?> times, more than it killed you, and you are its
rival: it greets you first.</p>
<table class="ranking">
<thead><tr><th>Bot</th><th>Player</th><th>Bot's kills</th><th>Player's kills</th></tr></thead>
<tbody>
<?php foreach ($rivalries as $rivalry): ?>
<tr>
<td><img class="icon" src="/img/bots/<?= e(strtolower((string) $rivalry['bot'])) ?>.png" alt="" width="24" height="24"><b><?= e((string) $rivalry['bot']) ?></b></td>
<td><?= player_link($rivalry) ?><?= (int) $rivalry['human_wins'] >= RIVAL && $rivalry['human_wins'] > $rivalry['bot_wins'] ? ' (rival)' : '' ?></td>
<td><?= (int) $rivalry['bot_wins'] ?></td>
<td><?= (int) $rivalry['human_wins'] ?></td>
</tr>
<?php endforeach; ?>
</tbody>
</table>
<?php endif; ?>

<h2>Meet them</h2>
<div class="bots">
<?php foreach ($bots as $name => $bot): ?>
<div class="bot">
<img src="/img/bots/<?= e(strtolower($name)) ?>.png" alt="" width="96" height="96">
<h3><?= e($name) ?></h3>
<?php $race = array_search($bot['race'], RACES, true); ?>
<p class="race"><?= $race ? race_icon($race) : '' ?><?= e($bot['race']) ?></p>
<p><?= e(ucfirst($bot['character'])) ?>.</p>
</div>
<?php endforeach; ?>
</div>
<p class="note">The bots' lines come from Claude, Anthropic's AI. Before a line is shown, in the game and here, a second
AI check holds back what it finds offensive.</p>
<?php page_end(); ?>
