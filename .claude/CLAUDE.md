# cs-war3-ai

A Counter-Strike 1.6 server with War3FT and YaPB bots. Goals: have fun building it, leave a repository useful to
anyone who wants to run their own server, and get players to come back and bring friends.

## Decisions

- No OpenTofu: the VPS was ordered by hand, Ansible does everything else.
- The VPS: `cs.pazpop.net` (`domain` in `ansible/inventory.yml`), Debian 13. Never write its IP in the repository.
- One VPS for everything, in Docker: HLDS, Caddy (stats and guide over HTTP and HTTPS), a second Caddy for FastDL,
  PHP.
- `stats/status.php`: the live state in JSON (A2S_INFO, cached 15 s, CORS open), read by pazpop.net's `servers.js`.
- One game server only, on the whole VPS: quality over quantity.
- Our own "LinuxGSM": `server/` (image + entrypoint) downloads CS 1.6 and the mods on the server.
- XP in SQLite, not MySQL: in MySQL mode, War3FT escapes names badly (SQL injection). Our stats page (`stats/`)
  reads the database read-only; War3FT's own page is not used (XSS, no license).
- Our AMX Mod X plugins are in `server/plugins/`, compiled at build time; what several share is in `common.inc`
  and `database.inc`.
- Respawn mode (the most played War3 variant): ReDeathmatch in teams, with
  $800 to start (War3 shops) and base spawns (its spawn points cover only 3 of our maps). `csdm_active.sma` turns on
  War3FT's own deathmatch mode.
- The ranking of the month (`server/plugins/monthly.sma`, table `cs_war3_ai_monthly`): one row per month and player,
  so it starts from zero on the 1st without any reset job.
- The AI (bots that talk back, a Game Master, a coach with `/coach`): `server/plugins/ai.sma` sends the game's news to `ai/relay.py` (its
  own container, Python's standard library only, raw HTTP to the Messages API), which asks Claude Haiku 5.5 and
  answers with actions the plugin checks and runs itself (a fixed list of events, never free commands). A second
  request (the moderator) checks every line before it is shown; on any doubt or error, nothing is shown. The relay
  has a fixed address on the internal `ai` network (no name lookup: it can block the game) and a daily budget
  (`AI_DAILY_USD`, 1/8 of it at most per hour). No SteamID or IP goes to the API. No key: silent. The relay's image
  also holds docs/war3ft.md (the bots answer questions from it); the stats page reads its database read-only (the
  bots' latest lines, the journal it writes each night from the Game Master's announcements and the bots' lines).
  In the game the AI shows as `[AI] <bot>`, `[AI Game Master]`, `[AI Coach]` (Anthropic requires the disclosure).
  Each human's name is checked on arrival and on each change (`NAME_CHECK`; the answer kept 30 days in the relay's
  `names` table; not held back by the hourly share): an offensive one makes the plugin rename the player "Player", so
  the chat, the announcements and the stats site never show it. A player whose messages get 3 lines held back within
  an hour is ignored for an hour (`REFUSALS`, `MUTE`).
- The goal of the week (`server/plugins/weekly.sma`): a week is known by its Monday's date; the goal, by the weeks
  since a fixed day; written to the database for the stats page by the week's first map; no prize.
- Kills: War3FT kills with its spells through a death notice other plugins never see, and reports them through its
  forward `wc3_reportkill`. `server/plugins/kills.inc` gives our plugins one `on_kill()` for both, each kill once.
- A daily chat report (humans, bots, Game Master, coach) goes to `/srv/collect/chat/` (ansible/files/chat_report.py,
  from the game's logs; ai.sma logs the bots' lines as chat lines).
- The containers drop every capability (`x-hardening` in `compose.yml`). The vault is ignored by git.
- Checks run on every push (`.github/workflows/check.yml`); Renovate proposes mod updates (SHA-256 by hand).
- Every night: Docker cleanup at 3:30 (config.yml), updates at 4:00, backup at 4:32 (`ansible/files/backup.sh`,
  15 days kept), reboot at 5:00 if needed.
- Two firewalls: ufw on the VPS, and OVHcloud's Edge Network Firewall (rules in docs/installation.md).
- Optional Healthchecks.io pings (backup, and `ansible/files/heartbeat.py` every 5 minutes); URLs in the vault.
- The repository is public (MIT). English is the main language; every doc has a French copy in `docs/fr/`.
  What players see is in English.

## Rules

- Answer in French, in short sentences. Shell commands in docs: Bash for Ubuntu.
- Simplest option first; state the cost of a fancier one.
- Nothing personal in the repository: no name, email, IP, PC path. Only "pazpop". Personal values go in
  `ansible/personal.yml` (ignored).
- No software installed or removed without the owner's "yes".
- Commits on main; the owner pushes.
- The VPS is in production: prepare, the owner runs the playbooks. Read it over SSH only with the owner's consent
  (`ssh -p 2222 -i ~/.ssh/cs_pazpop_net deploy@cs.pazpop.net`), and mask IPs and SteamIDs in what you show.
- sshd keeps the first value of each setting: our drop-in is `00-pazpop.conf`, read before cloud-init's
  `50-cloud-init.conf` (which turns password auth back on).

## Licenses

- No game file from Valve in the repository or the image (only SteamCMD); nothing from War3FT in the repository
  (no license).
- The announcer's voices are CC-BY 3.0, credited in `server/sound/announcer/CREDITS.txt` and the README.
- `vendor/` (ignored) holds local copies of the downloaded archives, for tests only.

## Known traps

- Docker stops a container with SIGTERM, and HLDS crashes on it (exit 139) before saving anything. So the
  entrypoint does not `exec` HLDS: it reads its console from a pipe, where `docker attach` and the stop signal
  (`quit`) both write. Background commands get an empty input in `sh`: cat reads the container's through fd 4.
- FastDL comes from its own Caddy (`fastdl`, caddy/fastdl.Caddyfile). The front, which holds every site's
  certificate, never mounts the game's volume: Caddy follows links, and the game can write there.
- The game shares its networks (`game`, `ai`) only with the AI relay, so it cannot reach PHP-FPM (`stats:9000`, no
  authentication).
  `status.php` asks it through the port the host publishes (`host.docker.internal`, `host-gateway`).
- ReHLDS only replaces the `steam_legacy` branch of app 90.
- The game's own download (UDP) crashes the client on War3FT's files: FastDL over HTTP is required. It serves only
  the paths listed in `caddy/fastdl.Caddyfile` (War3FT precaches `wc3.css` too): a new client file needs its path.
- The in-game browser (MOTD) cannot open today's HTTPS (error -113): the stats pages are also served over HTTP.
- Docker Desktop on Windows forwards UDP badly: play tests happen on the VPS.
- Caddy does not reread its Caddyfile: `deploy.yml` restarts it when it changes (`caddy reload` can leave the old
  settings running).
- YaPB's `yb_difficulty_auto` balances each bot against the others and pushes them up to Expert: keep it off,
  use `yb_difficulty_min`/`max`.
- YaPB's English bot names include a racial slur: our own list replaces it. `server/bots.txt` is the one list of
  the bots (name | race | character): YaPB's names (Dockerfile), bots.sma's races, the relay's races and characters (its image is built from the
  repository's root, `.dockerignore` lets only its files through), the stats page (`stats/bots.php`).
- YaPB's avatars are real Steam accounts' (`avatars.cfg`): off (`yb_show_avatars 0`).
- The site's images (`stats/img/`) come from PixelLab, outside the MIT license (`stats/img/CREDITS.txt`).
- `yb_name_prefix "[AI] "` is checked with `grep -F` in the Dockerfile: in a regular expression, `[AI]` is a set of
  letters.
- PHP runs as uid 1000: without capabilities, php-fpm could not switch to its own user. Caddy needs
  `cap_add: [NET_BIND_SERVICE]` (set on its program file), or it does not even start.
- A player's SteamID can be STEAM_ID_PENDING (or STEAM_ID_LAN) on arrival, shared by many players: the plugins
  wait for `client_authorized` and accept only IDs that start with `STEAM_<digit>:`.
- No ReChecker: its cheat list dates from 2020 and modern cheats inject in memory, so it would catch almost nothing.
- Ansible's `copy` never deletes: a file removed from the repository stays on the VPS. `deploy.yml` deletes
  `server/plugins/` first (a forgotten .sma would be compiled); anywhere else (a page in `stats/`), remove it by hand.
- War3FT's zip bundles AMX Mod X build 5467: the Dockerfile lays a later 1.10 build's `dlls/`, `modules/` and
  `data/gamedata/` over it (a crash on a dropped connection, fixed in 5482). Renovate does not see it: check by hand.
- With `csdm_active 1`, War3FT turns off everything that respawns a player or keeps their gear (`_SHARED_Spawn`,
  `SHARED_CS_Reincarnation`): the Orc's Reincarnation, the Blood Mage's Phoenix, the Warden's Vengeance, the ankh,
  the scroll. The guides say so; War3FT has no setting to hide them.
- After a start, AMX Mod X's `nextmap` does not find the start map and picks the cycle's first one: `de_dust2` (the
  start map, `entrypoint.sh`) is the last line of `mapcycle.txt`, so the cycle goes on in order.
- The game's log is echoed to the console by `mp_logecho` (off: IPs and team chat would land in Docker's logs).
  `sv_logecho` does not exist here.
- `client_disconnected(id, drop)`: `drop` is false at a map's end, true when a player leaves or is kicked.
- The relay's prompts quote players' words with `quoted()` (`ensure_ascii=False`): with escape codes, the moderator
  would read codes instead of words in other alphabets.
- PHP-FPM's image logs every request with the visitor's IP: `compose.yml` turns its access log off. A `configs`
  `content` cannot go into a read-only container: `stats` is not read-only.
