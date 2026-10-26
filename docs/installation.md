# Installation

Français : [fr/installation.md](fr/installation.md)

A Debian 13 VPS, set up with Ansible from Ubuntu (WSL on Windows works). The server runs in Docker.

## Components

| Component | Role | License |
|---|---|---|
| [ReHLDS](https://github.com/rehlds/ReHLDS) | Replaces the dedicated server engine (safer, faster) | MIT |
| [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS) | Replaces Counter-Strike's game code (bug fixes, more settings) | MIT |
| [Metamod-R](https://github.com/rehlds/Metamod-R) | Loads the plugins (AMX Mod X, YaPB) | GPL-3.0 |
| [ReAPI](https://github.com/rehlds/ReAPI) | Gives AMX Mod X plugins access to ReHLDS and ReGameDLL | GPL-3.0 |
| [War3FT](https://github.com/wc3mods/war3ft) | The mod, in an all-in-one package with AMX Mod X 1.10 | none stated (AMX Mod X: GPL-3.0) |
| [AMX Mod X](https://www.amxmodx.org) | The plugins' platform: a later 1.10 build's core and modules, over War3FT's | GPL-3.0 |
| [ReDeathmatch](https://github.com/ReDeathmatch/ReDeathmatch_AMXX) | Respawn: instant respawn, weapon menu, spawn protection | MIT |
| [YaPB](https://github.com/yapb/yapb) | The bots | Unlicense |
| Announcer voices (Antti Saari, TripleSnail) | First blood, multi-kills, streaks: in `server/sound/announcer/` | CC-BY 3.0 |
| [Caddy](https://caddyserver.com) | FastDL, the guide and the stats pages (HTTP and HTTPS) | Apache-2.0 |
| [PHP](https://www.php.net) | Runs the stats pages | PHP License |
| [Python](https://www.python.org) | The AI relay (`ai/relay.py`), standard library only | PSF |
| [Claude](https://www.anthropic.com/api) (Anthropic's API, optional) | The bots' chat lines and the Game Master | paid service |

The game image downloads the first eight at build time; versions and SHA-256 checksums are in
[server/Dockerfile](../server/Dockerfile). Caddy, PHP and Python are their own official Docker images.
CS 1.6 itself (the `steam_legacy` branch, the only one ReHLDS replaces) is downloaded on first start, into the
`hlds` volume. No game file from Valve is in the repository or the image (only SteamCMD); nothing from War3FT is in the
repository.
The announcer's voices are the only third-party files in it ([CREDITS.txt](../server/sound/announcer/CREDITS.txt)).

## Your settings

1. A DNS name pointing to the VPS: set it as `domain` in [ansible/inventory.yml](../ansible/inventory.yml), with
   your own servers in `collect_domains`, and the server's `timezone` (the logs, the rankings and the journal follow it).
   The chat messages: [server/messages.txt](../server/messages.txt).
2. An SSH key for Ansible (`ansible_ssh_private_key_file` in the inventory), copied to the provider's account:
   `ssh-copy-id -i ~/.ssh/<your key>.pub debian@<domain>`
3. Copy [ansible/personal.example.yml](../ansible/personal.example.yml) to `ansible/personal.yml` (ignored by git)
   and fill it in: the provider's account, your account, the backup folder, the admins' SteamIDs.
4. The Ansible collections: `ansible-galaxy collection install -r ansible/requirements.yml`
5. The vault, for the secrets: encrypted, and ignored by git (it never leaves your PC). Keep a copy of it, and of
   its password.
   ```bash
   source vault.sh                       # the vault password, kept 2 h in this terminal
   ansible-vault create ansible/vault.yml
   ```
   Inside, optional: `vault_rcon: <16 characters or more: letters, digits, _ and ->`. Without it, rcon stays
   closed; the admins still work by SteamID. Optional too: `vault_anthropic_key: sk-ant-...`, for the AI (see
   [The AI](#the-ai-optional)). An empty vault is fine: `{}`.

## Setting up the VPS

From the repository root, after `source vault.sh`:

`init.yml` connects on port 22: if the [Edge Network Firewall](#ovhcloud-edge-network-firewall-optional) is on,
add a temporary rule first (priority 9, Accept, TCP, destination port 22), and delete it after `config.yml`.

```bash
ansible-playbook -i ansible/inventory.yml ansible/init.yml    # once: accounts, SSH on 2222
ansible-playbook -i ansible/inventory.yml ansible/config.yml  # the system: firewall, Docker, updates
ansible-playbook -i ansible/inventory.yml ansible/deploy.yml  # the game server and the stats page
```

`config.yml` and `deploy.yml` can be run again (see [Updating](#updating)). `config.yml` reboots the VPS when an update
needs it: run it when nobody plays.

## The game server

| Action | Command, on the VPS (in `/srv/cs-war3-ai`) |
|---|---|
| Console output | `sudo docker logs -f cs-war3-ai-hlds-1` (the game's log, with the IPs and the team chat, stays in the volume's `cstrike/logs/`, 14 days) |
| Console | `sudo docker attach cs-war3-ai-hlds-1` (leave with `Ctrl+P` then `Ctrl+Q`; `Ctrl+C` restarts the server) |
| Update CS 1.6 | `sudo UPDATE=1 docker compose up -d`, then `sudo docker compose up -d` once it runs (otherwise every restart updates again) |
| Server FPS back to Valve's default | `sudo TICRATE=100 docker compose up -d` (until the next `deploy.yml`) |

In the console: `meta list` (AMX Mod X and YaPB `RUN`), `amxx plugins` (`war3ft.amxx` `running`), `stats`.

Settings: [server/Dockerfile](../server/Dockerfile) (War3FT, ReDeathmatch, YaPB, AMX Mod X) and
[server/server.cfg](../server/server.cfg). At each start, the entrypoint adds the server name, the FastDL address
and the MOTD from `DOMAIN`. Maps: [server/mapcycle.txt](../server/mapcycle.txt), also used as `maps.ini`: the most
liked CS 1.6 maps that the bots know.

## Our plugins

In [server/plugins/](../server/plugins/), compiled at build time (`common.inc`, `database.inc` and `kills.inc`: the
code several share; `kills.inc` also gets the kills of War3FT's spells, which the game's death notice misses):

- `achievements.sma`: 14 achievements (`/ach`), saved in War3FT's database; the player pages show them. An unlock
  shows to everyone (`[STATS]`).
- `afk.sma`: 60 seconds without a key or a mouse move, and a player goes to spectator.
- `ai.sma`: sends the chat, the kills between bots and humans, the state of the game halfway through each map, a player's
  arrivals, name changes and numbers for the coach, and the Game Master's announcements to the AI relay, and does
  what it answers (see [The AI](#the-ai-optional)). At each map's end, a `[STATS]` line names the MVP: the top of the
  scoreboard.
- `announcer.sma`: the voices and messages for first blood, multi-kills and kill streaks. Players download the voices
  over HTTP (FastDL).
- `block_test.sma`: blocks War3FT's debug commands `test` and `test2`, open to every player (they fill the logs).
- `bots.sma`: each bot of [server/bots.txt](../server/bots.txt) most often plays its own War3FT race, wears its own
  skin on each team, and has a level of 1 to 5 at each map (its XP never adds up: no stronger than the humans).
  A human's name loses the tags only the AI and the rankings give (`[AI]`, `Game Master`, `[Champion]`, `[#3]`...),
  and `<` and `>`.
- `csdm_active.sma`: turns on War3FT's deathmatch mode (a new session at every respawn); ReDeathmatch does the
  respawns. Saves everyone's XP every 5 minutes too: War3FT saves at a round's end, which never comes here.
- `damage.sma`: the damage the player deals, under the crosshair, at each hit.
- `fresh_start.sma`: when the first human joins a server of bots only, the game restarts (`sv_restart`): every
  score back to zero, a fair start. XP, the ranking of the month and the achievements stay.
- `help.sma`: `/help` in chat, or `help` in the console, opens the guide again.
- `high_ping.sma`: a ping over 300 ms for 50 seconds, and a player is kicked.
- `messages.sma`: a message in the chat every 5 minutes, in turn, from [server/messages.txt](../server/messages.txt):
  `[HELP]` for a command, `[INFO]` for the rest (add the server to your favorites). One minute before the map's end:
  the next map.
- `monthly.sma`: the ranking of the month (kills - deaths, from zero on the 1st), on the stats page. At each map, the
  top 5 and the player's place, in one line. Also each human's map MVPs of the month (on top of the scoreboard at a
  map's end, bots included, when two humans or more scored).
- `name_spam.sma`: a human who changes their name 10 times within 10 minutes is kicked for an hour.
- `no_spray.sma`: no sprays (the T key): `sv_allowupload 0` already hides custom images; the bots: `yb_spraypaints 0`.
- `rank_tag.sma`: the top 10 show their place in the chat, `[#3] name: message`; last month's top 3, `[Champion]`.
- `rtv.sma`: `rtv` in chat; at 60 % of all the humans on the server, adminvote's vote on 4 random maps (not in the
  map's last 2 minutes, when mapchooser votes).
- `slash_commands.sma`: `/nextmap`, `/currentmap`, `/timeleft`, `/thetime` (AMX Mod X only knows them without the
  slash): every command then works with a `/`.
- `votekick.sma`: a player is kicked for 10 minutes once 60 % of the other humans chose them (at least 3 humans;
  admins are not in the menu).
- `web_stats.sma`: for the stats page, stores each human's name (in SQLite, War3FT only keeps the SteamID), and
  copies the top 100 of CS's combat ranking (`/rank`, `/top15`) at each map start. `/mystats`: the link to the
  player's page.
- `weekly.sma`: the goal of the week, the same for everyone, a new one every Monday (`/goal`); its board is on the
  stats page. No prize.

ReDeathmatch: teams, instant respawn in the team's base, no rounds, weapons with **G**, $800 to start (the War3
shops cost money). 3 seconds of spawn protection, lost at the first shot (ReGameDLL's `mp_respawn_immunity*`).
In this mode, War3FT turns off what brings a player back or keeps their gear: the Orcish Horde's equipment, the
Blood Mage's revive, the Warden's ultimate, the ankh and the scroll.
Mapchooser runs a map vote at the end of each map (every 20 minutes).
AMX Mod X's `antiflood` blocks chat floods (one message every 0.75 s at most: `amx_flood_time`).

## Data and backup

XP is in SQLite, in the volume: `cstrike/addons/amxmodx/data/sqlite3/war3ft.sq3`. Not MySQL: War3FT's MySQL mode
escapes player names badly (SQL injection).

Every night at 4:32 (between the 4:00 updates and the 5:00 reboot), the VPS backs up the XP, the rankings, the
achievements and the AI's memory into `/srv/backups/cs-war3-ai`, and keeps 15 days (a few MB per archive at most).
The game keeps running: SQLite's own backup copies the databases while they are in use. The script:
[ansible/files/backup.sh](../ansible/files/backup.sh), run by the `cs-war3-ai-backup.timer` systemd timer.

To make one now and download it to your PC (into `backup_dir`, `ansible/personal.yml`):

```bash
ansible-playbook -i ansible/inventory.yml ansible/backup.yml
```

To restore an archive, on the VPS (the game and the AI stop meanwhile): first any SQLite journal left by a crash
(SQLite would replay it onto the restored database), then the game's data and the AI's memory.

```bash
cd /srv/cs-war3-ai
sudo docker compose stop hlds ai
sudo docker run --rm --user 0 --entrypoint sh -v cs-war3-ai_hlds:/data -v cs-war3-ai_ai:/ai cs-war3-ai-hlds -c 'rm -f /data/cstrike/addons/amxmodx/data/sqlite3/*.sq3-* /ai/*.sq3-*'
sudo docker run --rm --user 0 --entrypoint tar -v cs-war3-ai_hlds:/data -v /srv/backups/cs-war3-ai:/in:ro cs-war3-ai-hlds -xzf /in/<archive>.tgz -C /data/cstrike/addons/amxmodx data
sudo docker run --rm --user 0 --entrypoint tar -v cs-war3-ai_ai:/ai -v /srv/backups/cs-war3-ai:/in:ro cs-war3-ai-hlds -xzf /in/<archive>.tgz -C / ai
sudo docker compose start hlds ai
```

## Web

- `https://<domain>` (and `http://`): the Game Master's journal, the rankings (of the month and its MVPs, the goal
  of the week, XP and combat), the number of players (since launch, last 30 and 90 days)
  ([stats/index.php](../stats/index.php)), and a page per player ([stats/player.php](../stats/player.php)): XP and
  skill levels per race, combat stats, achievements. PHP reads the database read-only.
- `https://<domain>/status.php`: the server's state right now in JSON (humans, bots, map, slots), for other sites:
  [pazpop.net](https://pazpop.net) shows it. Asked to the game at most every 15 seconds.
- `https://<domain>/bots.php`: the bots, their race, character and portrait (from
  [server/bots.txt](../server/bots.txt)). Also the bots' latest lines and the great rivalries (each bot's score
  against each human), from the AI relay's database (its volume, read-only), with the names from the game's.
- `http://<domain>/guide.html`: the guide, shown on connect. The in-game browser (MOTD) is too old for today's
  HTTPS: in game, only `http://` pages open.
- `http://<domain>/cstrike/…`: FastDL. The game's own download (UDP) crashes the client on War3FT's files.
  A Caddy of its own serves it, without any certificate, and only War3FT's files and the announcer's voices: never
  the configs or the XP ([caddy/fastdl.Caddyfile](../caddy/fastdl.Caddyfile)). The front passes `/cstrike/` on to it.

## Updating

- **The system** updates itself every night at 4:00, and reboots at 5:00 if an update needs it.
- **CS 1.6**: see [The game server](#the-game-server).
- **Caddy, PHP, Python and the Debian base**: run `deploy.yml` about once a month: it rebuilds both images on fresh
  bases and pulls the latest Caddy and PHP patches.
- **AMX Mod X**: a later 1.10 build than War3FT's, checked by hand (see [server/Dockerfile](../server/Dockerfile)).
- **The mods and the images** (ReHLDS, ReGameDLL, Metamod-R, ReAPI, War3FT, ReDeathmatch, YaPB, Caddy, PHP, Python):
  [Renovate](https://docs.renovatebot.com) opens a pull request when a new version is out (enable the free Renovate
  app on the repository). In that pull request,
  replace the version's SHA-256 in [server/Dockerfile](../server/Dockerfile): `curl -sL <archive URL> | sha256sum`.
  Until then, the check below fails, on purpose.
- **From the PC** (the owner's script: it expects this folder named `cs-war3-ai`, with `pazpop.net` next to it):
  `./deploy-all.sh` pushes this repository and `../pazpop.net` when they have new commits, then
  runs `deploy.yml` (`--all`: everything, even without new commits).
- **Checks**: every push runs [.github/workflows/check.yml](../.github/workflows/check.yml): `ansible-lint`,
  `shellcheck`, the Python and PHP syntax, the Python tests, and both image builds (the game's checks the SHA-256 and
  compiles our plugins).

## Player counts

Every 5 minutes, [ansible/files/collect.py](../ansible/files/collect.py) adds one line per server to
`/srv/collect/players.csv`: time (the VPS's, with its offset from UTC), server, online, humans, bots, slots, map.
Only numbers and the map, nothing about the players (about 15 KB a day per server). The servers: `collect_domains`
in [ansible/inventory.yml](../ansible/inventory.yml). To download it:

```bash
scp -P 2222 -i ~/.ssh/<your key> deploy@<domain>:/srv/collect/players.csv .
```

## Chat reports

Every night at 0:30, [ansible/files/chat_report.py](../ansible/files/chat_report.py) writes the day before's
chat (the VPS's time, like the game's logs) into `/srv/collect/chat/<date>.txt`, from the game's logs (kept 14
days): the humans (team chat marked), the bots, the Game Master and the coach, with arrivals and departures. Names
only, no SteamID or IP; readable by root only, kept 90 days. A day without any of these writes nothing. Another
day, at once: `sudo cs-war3-ai-chat-report 2026-10-26`.

## The AI (optional)

Bots that talk back, and a Game Master. `ai.sma` sends the game's news to the relay
([ai/relay.py](../ai/relay.py), its own container), which asks Claude (Claude Haiku 5.5) and answers with actions:

- **The bots talk**: a bot answers when a player names it in the chat (sometimes even when no one does), and
  after a kill between a bot and a human, now and then; one of them greets each human who arrives. Never bot to
  bot. Each bot of [server/bots.txt](../server/bots.txt) has its own race and character, the same for
  YaPB, the game, the relay and the stats page, and shows as `[AI] Zed` in the scoreboard. The bots remember each
  human (by SteamID, in the relay's volume): since when they play, the last map played together, how they fare
  against bots, and each bot's score against them. A bot
  killed 5 times by a player, more than it killed them, holds a grudge: it teases them, and greets them first.
- **Questions**: a message with a `?` usually gets an answer from a bot, which has the mod's guide
  ([docs/war3ft.md](war3ft.md), about 1,500 tokens) at hand; a newcomer gets a tip from it with the hello.
- **The coach**: `/coach` sends the player's numbers on this map (CSX: kills, deaths, headshots, hits and where,
  each weapon's accuracy, deaths in a row, the weapon that killed them most) and gets one tip back, in private, one a
  minute at most. `/coach <question>`: the answer to a question about these numbers, never shown in the chat.
  `/coach on`: a tip every 5 minutes, kept by SteamID in the relay until `/coach off`. 60 seconds before the map's
  end, each human who played gets a summary: one strength, one thing to work on (and, without `/coach on`, a word
  about it).
- **The Game Master**: halfway through each map (10 minutes), it reads the score and may start an event: a bounty on a player far ahead,
  a duel between two players, a challenge (kills, headshots or knife kills, in 2 minutes), a boss (a bot
  with 500 health and a red glow), 30 seconds of low gravity, money for everyone, 100 War3FT XP for every human
  (`changexp`), a War3FT shop item for everyone (`wc3_giveitem`). Each prize is $3000 and 200 XP, and nobody has to
  take part. It can only pick from this list, never the same event twice in a row; the plugin checks each event
  and runs it itself.
- **The journal**: each night, the relay writes the day before's entry (3 to 5 sentences) from the Game Master's
  announcements and the bots' lines, never from what players write; the home page shows the last 3 days.

What the AI may say: a strict system prompt, then a moderator (a second request) checks every line before it is
shown: no slurs, hate, sexual content, threats, illegal activity, politics or personal information, in any
language, nor an offensive player name repeated. Each human's name is checked too, on arrival and on each change:
an offensive one is renamed "Player" (without an answer, no key or no budget left, a name passes and is checked
again later). On any doubt or error, no line is shown. A bot answers the same player at most
every 10 seconds, and 30 times an hour; a player whose messages get 3 lines held back within an hour is ignored for an hour. In the game,
the AI shows as `[AI] Zed`, `[AI Game Master]` and `[AI Coach]`: players know they talk to an AI (Anthropic requires
it).

Setup: an API key from [console.anthropic.com](https://console.anthropic.com) in the vault
(`vault_anthropic_key: sk-ant-...`), then `deploy.yml`. Without a key, the relay stays silent and the game is
unchanged. It spends at most `AI_DAILY_USD` a day (1 $ by default, in `compose.yml`; `0` turns the AI off), and at
most 1/8 of it in an hour, then stays silent; set a monthly limit in the Anthropic console too.

What leaves the VPS: the public chat messages (never the team chat), the names, the score, each human's history
against the bots (since when and when last they played, the last map, kills and deaths against them), each player's
numbers and questions for the coach, and for the journal the day's announcements and bot lines. Never the SteamIDs or
the IPs. The bots' memory forgets a player not seen for 180 days; the day's story goes 2 days later; the journal keeps
its last 30 entries, the stats page the bots' last 200 lines (30 days at most), the name check its answers 30 days. The guide tells the
players.

Its logs, on the VPS: `cd /srv/cs-war3-ai && sudo docker compose logs ai`.

## Monitoring (optional)

[Healthchecks.io](https://healthchecks.io) (free, open source) warns you when a ping does not arrive in time, even
if the VPS is down.

1. Create two checks: **backup** (period 1 day, grace 1 hour) and **server** (period 5 minutes, grace 10 minutes).
2. Put their ping URLs in the vault: `ansible-vault edit ansible/vault.yml`, then
   `vault_hc_backup: https://hc-ping.com/<uuid>` and `vault_hc_server: https://hc-ping.com/<uuid>`.
3. Run `deploy.yml`.

- **backup**: [ansible/files/backup.sh](../ansible/files/backup.sh) pings on success, `/fail` on failure.
- **server**: every 5 minutes, [ansible/files/heartbeat.py](../ansible/files/heartbeat.py) checks that the game
  answers and that the stats page loads, then pings (`/fail` with the reason if something is wrong).

Without these URLs, nothing is sent.

## OVHcloud Edge Network Firewall (optional)

At OVHcloud, the Edge Network Firewall filters traffic before it reaches the VPS. It also turns itself on during a
DDoS attack. Control panel: Network > Public IP Addresses > `⁝` next to the IPv4 >
Configure Edge Network Firewall, then turn it on.

| Priority | Action | Protocol | Source port | Destination port | Option | Why |
|---|---|---|---|---|---|---|
| 0 | Accept | TCP | | | established | Replies to the VPS's own connections (updates, certificate, downloads) |
| 1 | Accept | TCP | | 2222 | | SSH |
| 2 | Accept | TCP | | 80 | | FastDL, the guide and stats for the game, the certificate |
| 3 | Accept | TCP | | 443 | | The stats pages |
| 4 | Accept | UDP | | 27015 | | The players |
| 5 | Accept | UDP | 27000-27100 | | | Steam's replies: player checks, VAC, the server list |
| 6 | Accept | UDP | 53 | | | DNS replies |
| 7 | Accept | UDP | 123 | | | Time (NTP) replies |
| 8 | Accept | ICMP | | | | Ping and traceroute |
| 19 | Deny | IPv4 | | | | Everything else |

Rules 1 to 4: destination ports; 5 to 7: source ports (replies). It does not replace the firewall on the VPS:
it only filters what comes from outside OVHcloud, and only IPv4.

## Admins

SteamIDs in `ansible/personal.yml`. In the game console: `amxmodmenu` (the admin menu), `amx_who`.
Rcon (if `vault_rcon` is set): `rcon_password <vault_rcon>`, then `rcon status`.

To take a player's name off the stats site (on request, with their SteamID), on the VPS:

```bash
sudo docker run --rm -v cs-war3-ai_hlds:/h python:3.13-alpine python -c "import sqlite3, sys; db = sqlite3.connect('/h/cstrike/addons/amxmodx/data/sqlite3/war3ft.sq3'); db.execute(\"UPDATE cs_war3_ai_names SET name = 'Player' WHERE steamid = ?\", (sys.argv[1],)); db.commit()" STEAM_0:1:123456
```

Their stats stay, under "Player"; if they come back, their new name shows. The bots' lines and the journal
entries that name them stay until newer ones push them out (the last 200 lines, 30 days at most; the last 30 entries).

## On the PC

`DOMAIN=localhost docker compose up -d --build` starts everything, but Docker Desktop (Windows) forwards UDP badly:
the game client cannot connect. Game tests happen on the VPS.
