<?php
// The bots: their names and characters, from server/bots.txt (the same list the AI relay reads), with a portrait each
// (img/bots/<name>.png).
require __DIR__ . '/common.php';

$bots = [];
foreach (file('/srv/server/bots.txt', FILE_IGNORE_NEW_LINES) ?: [] as $line) {
    [$name, $character] = array_map('trim', explode('|', $line, 2)) + [1 => ''];
    if ($name !== '' && $line[0] !== ';') {
        $bots[$name] = $character;
    }
}

page_start('War3FT: the bots');
?>
<h1>The bots</h1>
<p>When few people play, bots fill the server, <code>[AI]</code> in their name. They talk back: write a bot's name in
the chat, like <code>zed, nice shot</code>. Each one has its own character, greets you when you arrive, and remembers
you from one game to the next.</p>
<div class="bots">
<?php foreach ($bots as $name => $character): ?>
<div class="bot">
<img src="/img/bots/<?= e(strtolower($name)) ?>.png" alt="" width="96" height="96">
<h3><?= e($name) ?></h3>
<p><?= e(ucfirst($character)) ?>.</p>
</div>
<?php endforeach; ?>
</div>
<p class="note">The bots' lines come from Claude, Anthropic's AI, and a second check refuses anything offensive before
it is shown.</p>
<?php page_end(); ?>
