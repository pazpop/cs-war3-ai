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
| [ReDeathmatch](https://github.com/ReDeathmatch/ReDeathmatch_AMXX) | Respawn: instant respawn, weapon menu, spawn protection | MIT |
| [YaPB](https://github.com/yapb/yapb) | The bots | Unlicense |
| Announcer voices (Antti Saari, TripleSnail) | First blood, multi-kills, streaks: in `server/sound/announcer/` | CC-BY 3.0 |
| [Caddy](https://caddyserver.com) | FastDL, the guide and the stats pages (HTTP and HTTPS) | Apache-2.0 |
| [PHP](https://www.php.net) | Runs the stats pages | PHP License |
| [Python](https://www.python.org) | The AI relay (`ai/relay.py`), standard library only | PSF |
| [Claude](https://www.anthropic.com/api) (Anthropic's API, optional) | The bots' chat lines and the Game Master | paid service |

The game image downloads the first seven at build time; versions and SHA-256 checksums are in
[server/Dockerfile](../server/Dockerfile). Caddy, PHP and Python are their own official Docker images.
CS 1.6 itself (the `steam_legacy` branch, the only one ReHLDS replaces) is downloaded on first start, into the
`hlds` volume. No game file from Valve is in the repository or the image (only SteamCMD); nothing from War3FT is in the
repository.
The announcer's voices are the only third-party files in it ([CREDITS.txt](../server/sound/announcer/CREDITS.txt)).

## Your settings

1. A DNS name pointing to the VPS: set it as `domain` in [ansible/inventory.yml](../ansible/inventory.yml), with
   your own servers in `collect_domains`. The chat messages: [server/messages.txt](../server/messages.txt).
2. An SSH key for Ansible (`ansible_ssh_private_key_file` in the inventory), copied to the provider's account:
   `ssh-copy-id -i ~/.ssh/cs_pazpop_net.pub debian@cs.pazpop.net`
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
| Log | `sudo docker logs -f cs-war3-ai-hlds-1` |
| Console | `sudo docker attach cs-war3-ai-hlds-1` (leave with `Ctrl+P` then `Ctrl+Q`; `Ctrl+C` restarts the server) |
| Update CS 1.6 | `sudo UPDATE=1 docker compose up -d`, then `sudo docker compose up -d` once it runs (otherwise every restart updates again) |
| Server FPS back to Valve's default | `sudo TICRATE=100 docker compose up -d` (until the next `deploy.yml`) |

In the console: `meta list` (AMX Mod X and YaPB `RUN`), `amxx plugins` (`war3ft.amxx` `running`), `stats`.

Settings: [server/Dockerfile](../server/Dockerfile) (War3FT, ReDeathmatch, YaPB, AMX Mod X) and
[server/server.cfg](../server/server.cfg). At each start, the entrypoint adds the server name, the FastDL address
and the MOTD from `DOMAIN`. Maps: [server/mapcycle.txt](../server/mapcycle.txt), also used as `maps.ini`: the most
liked CS 1.6 maps that the bots know.

## Our plugins

In [server/plugins/](../server/plugins/), compiled at build time:

- `achievements.sma`: 14 achievements (`/ach`), saved in War3FT's database; the player pages show them. At each map, the
  closest one; a word to the player when 10 % is left.
- `afk.sma`: 60 seconds without a key or a mouse move, and a player goes to spectator.
- `ai.sma`: sends the chat, the kills between bots and humans, and every 4 minutes the state of the game to the AI
  relay, and does what it answers (see [The AI](#the-ai-optional)).
- `announcer.sma`: the voices and messages for first blood, multi-kills and kill streaks. Players download the voices
  over HTTP (FastDL).
- `block_test.sma`: blocks War3FT's debug commands `test` and `test2`, open to every player (they fill the logs).
- `csdm_active.sma`: turns on War3FT's deathmatch mode (a new session at every respawn); ReDeathmatch does the
  respawns.
- `damage.sma`: the damage the player deals, under the crosshair, at each hit.
- `help.sma`: `/help` in chat, or `help` in the console, opens the guide again.
- `high_ping.sma`: a ping over 300 ms for 50 seconds, and a player is kicked.
- `messages.sma`: a message in the chat every 2 minutes, in turn, from [server/messages.txt](../server/messages.txt):
  add the server to your favorites, the stats page, the commands.
- `monthly.sma`: the ranking of the month (kills - deaths, from zero on the 1st), on the stats page. At each map, the
  player's place this month.
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

ReDeathmatch: teams, instant respawn in the team's base, no rounds, weapons with **G**, $800 to start (the War3
shops cost money). 3 seconds of spawn protection, lost at the first shot (ReGameDLL's `mp_respawn_immunity*`). Mapchooser runs a map vote at the end of each map (every 30 minutes).
AMX Mod X's `antiflood` blocks chat floods (one message every 0.75 s at most: `amx_flood_time`).

## Data and backup

XP is in SQLite, in the volume: `cstrike/addons/amxmodx/data/sqlite3/war3ft.sq3`. Not MySQL: in MySQL mode,
War3FT escapes player names badly (SQL injection possible); in SQLite mode it escapes them correctly.

Every night at 4:32 (between the 4:00 updates and the 5:00 reboot), the VPS backs up the XP, the rankings and the
achievements into `/srv/backups/cs-war3-ai`, and keeps 15 days (about 1.5 MB per archive). The game stops for about 30 seconds.
The script:
[ansible/files/backup.sh](../ansible/files/backup.sh), run by the `cs-war3-ai-backup.timer` systemd timer.

To make one now and download it to your PC (into `backup_dir`, `ansible/personal.yml`):

```bash
ansible-playbook -i ansible/inventory.yml ansible/backup.yml
```

To restore an archive, on the VPS (the game stops meanwhile):

```bash
cd /srv/cs-war3-ai
sudo docker compose stop hlds
sudo docker run --rm --user 0 --entrypoint tar -v cs-war3-ai_hlds:/data -v /srv/backups/cs-war3-ai:/in:ro cs-war3-ai-hlds -xzf /in/<archive>.tgz -C /data/cstrike/addons/amxmodx
sudo docker compose start hlds
```

## Web

- `https://<domain>` (and `http://`, for the in-game browser): the rankings (of the month, XP and combat),
  the number of players (since launch, last 30 and 90 days) ([stats/index.php](../stats/index.php)), and a page per
  player ([stats/player.php](../stats/player.php)): XP and skill levels per race, combat stats, achievements. PHP
  reads the database read-only.
- `https://<domain>/status.php`: the server's state right now in JSON (humans, bots, map, slots), for other sites:
  [pazpop.net](https://pazpop.net) shows it. Asked to the game at most every 15 seconds.
- `http://<domain>/guide.html`: the guide, shown on connect. The in-game browser (MOTD) is too old for today's
  HTTPS: in game, only `http://` pages open.
- `http://<domain>/cstrike/…`: FastDL. The game's own download (UDP) crashes the client on War3FT's files.
  A Caddy of its own serves it, without any certificate, and only War3FT's files and the announcer's voices: never
  the configs or the XP ([caddy/fastdl.Caddyfile](../caddy/fastdl.Caddyfile)). The front passes `/cstrike/` on to it.

## Updating

- **The system** updates itself every night at 4:00, and reboots at 5:00 if an update needs it.
- **CS 1.6**: see [The game server](#the-game-server).
- **Caddy, PHP and the Debian base**: run `deploy.yml` about once a month: it rebuilds the image on a fresh Debian
  base and pulls the latest Caddy and PHP patches.
- **The mods** (ReHLDS, ReGameDLL, Metamod-R, ReAPI, War3FT, ReDeathmatch, YaPB):
  [Renovate](https://docs.renovatebot.com) opens a pull request when a new version is out (enable the free Renovate
  app on the repository). In that pull request,
  replace the version's SHA-256 in [server/Dockerfile](../server/Dockerfile): `curl -sL <archive URL> | sha256sum`.
  Until then, the check below fails, on purpose.
- **Checks**: every push runs [.github/workflows/check.yml](../.github/workflows/check.yml): `ansible-lint`,
  `shellcheck`, the Python and PHP syntax, and the game image build (which checks the SHA-256 and compiles our plugins).

## Player counts

Every 5 minutes, [ansible/files/collect.py](../ansible/files/collect.py) adds one line per server to
`/srv/collect/players.csv`: time (UTC), server, online, humans, bots, slots, map. Only numbers, nothing about the
players (about 60 KB a day). The servers: `collect_domains` in [ansible/inventory.yml](../ansible/inventory.yml).
To download it:

```bash
scp -P 2222 deploy@<domain>:/srv/collect/players.csv .
```

## The AI (optional)

Bots that talk back, and a Game Master. `ai.sma` sends the game's news to the relay
([ai/relay.py](../ai/relay.py), its own container), which asks Claude (Claude Haiku 5.5) and answers with actions:

- **The bots talk**: a bot answers when a player names it in the chat (sometimes even when no one does), and
  after a kill between a bot and a human, now and then; one of them greets each human who arrives. Never bot to
  bot. Each name of [server/bot_names.txt](../server/bot_names.txt) has its own character (`PERSONAS` in the
  relay), and shows as `[AI] Zed` in the scoreboard. The bots remember each human (by SteamID, in the relay's
  volume): since when they play, how they fare against bots.
- **The Game Master**: every 4 minutes, it reads the score and may start an event: a bounty on a player far ahead,
  a duel between two players, 30 seconds of low gravity, money for everyone. It can only pick from this list: the
  plugin checks each event and runs it itself.

Setup: an API key from [console.anthropic.com](https://console.anthropic.com) in the vault
(`vault_anthropic_key: sk-ant-...`), then `deploy.yml`. Without a key, the relay stays silent and the game is
unchanged. It spends at most `AI_DAILY_USD` a day (1 $ by default, in `compose.yml`), then stays silent until
midnight UTC; set a monthly limit in the Anthropic console too.

What leaves the VPS: the chat messages, the names, the score. Never the SteamIDs or the IPs. The guide tells the
players.

Its logs: `docker compose logs ai`.

## Monitoring (optional)

[Healthchecks.io](https://healthchecks.io) (free up to 20 checks, open source) warns you by email, Discord,
Telegram… when a ping does not arrive in time. It also catches a VPS that is completely down.

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
DDoS attack, so its rules should be right. Control panel: Network > Public IP Addresses > `⁝` next to the IPv4 >
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

## On the PC

`DOMAIN=localhost docker compose up -d --build` starts everything, but Docker Desktop (Windows) forwards UDP badly:
the game client cannot connect. Game tests happen on the VPS.
