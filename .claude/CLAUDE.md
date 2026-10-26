# cs-war3-ai

A Counter-Strike 1.6 server with War3FT and YaPB bots. Goals: have fun building it, leave a repository useful to
anyone who wants to run their own server, and get players to come back and bring friends.

## Decisions

- No OpenTofu: the VPS was ordered by hand, Ansible does everything else.
- The VPS: `cs.pazpop.net` (`domain` in `ansible/inventory.yml`), Debian 13. Never write its IP in the repository.
- One VPS for everything, in Docker: HLDS, Caddy (stats and guide over HTTP and HTTPS), a second Caddy for FastDL,
  PHP.
- `stats/status.php`: the live state in JSON (A2S_INFO, cached 15 s, CORS open), read by pazpop.net's `servers.js`.
- One game server only (2026-10-26): the VPS's other ones were retired
  and their repositories archived on GitHub. Quality over quantity. Then renamed from cs-war3FT (war3.pazpop.net)
  to cs-war3-ai (cs.pazpop.net), and the VPS reinstalled from scratch with docs/installation.md, to test it.
- Our own "LinuxGSM": `server/` (image + entrypoint) downloads CS 1.6 and the mods on the server.
- XP in SQLite, not MySQL: in MySQL mode, War3FT escapes names badly (SQL injection). Our stats page (`stats/`)
  reads the database read-only; War3FT's own page is not used (XSS, no license).
- Our AMX Mod X plugins are in `server/plugins/`, compiled at build time. Many came from an archived repository; they
  are ours now, no copy to keep in step.
- Respawn mode (the most played War3 variant): ReDeathmatch in teams, with
  $800 to start (War3 shops) and base spawns (its spawn points cover only 3 of our maps). `csdm_active.sma` turns on
  War3FT's own deathmatch mode.
- The ranking of the month (`server/plugins/monthly.sma`, table `cs_war3_ai_monthly`): one row per month and player,
  so it starts from zero on the 1st without any reset job.
- The AI (bots that talk back, a Game Master): `server/plugins/ai.sma` sends the game's news to `ai/relay.py` (its
  own container, Python's standard library only, raw HTTP to the Messages API), which asks Claude Haiku 5.5 and
  answers with actions the plugin checks and runs itself (a fixed list of events, never free commands). The relay
  has a fixed address on the internal `ai` network (no name lookup: it can block the game) and a daily budget
  (`AI_DAILY_USD`). No SteamID or IP goes to the API. No key: silent.
- The containers drop every capability (`x-hardening` in `compose.yml`). The vault is ignored by git.
- Checks run on every push (`.github/workflows/check.yml`); Renovate proposes mod updates (SHA-256 by hand).
- Every night: Docker cleanup at 3:30 (config.yml), updates at 4:00, backup at 4:32 (`ansible/files/backup.sh`, 15 days kept), reboot at 5:00 if needed.
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
- The game is alone on the `game` network, so it cannot reach PHP-FPM (`stats:9000`, no authentication).
  `status.php` asks it through the port the host publishes (`host.docker.internal`, `host-gateway`).
- ReHLDS only replaces the `steam_legacy` branch of app 90.
- The game's own download (UDP) crashes the client on War3FT's files: FastDL over HTTP is required. It serves only
  the paths listed in `caddy/fastdl.Caddyfile` (War3FT precaches `wc3.css` too): a new client file needs its path.
- The in-game browser (MOTD) cannot open today's HTTPS (error -113): the stats pages are also served over HTTP.
- Docker Desktop on Windows forwards UDP badly: play tests happen on the VPS.
- Caddy does not reread its Caddyfile: `deploy.yml` reloads it when it changes.
- YaPB's `yb_difficulty_auto` balances each bot against the others and pushes them up to Expert: keep it off,
  use `yb_difficulty_min`/`max`.
- One of YaPB's English bot names is a racial slur: the Dockerfile removes it.
- PHP runs as uid 1000: without capabilities, php-fpm could not switch to its own user. Caddy needs
  `cap_add: [NET_BIND_SERVICE]` (set on its program file), or it does not even start.
- A player's SteamID can be STEAM_ID_PENDING (or STEAM_ID_LAN) on arrival, shared by many players: the plugins
  wait for `client_authorized` and accept only IDs that start with `STEAM_<digit>:`.
- No ReChecker: its cheat list dates from 2020 and modern cheats inject in memory, so it would catch almost nothing.
- Ansible's `copy` never deletes: a file removed from the repository stays on the VPS. `deploy.yml` deletes
  `server/plugins/` first (a forgotten .sma would be compiled); anywhere else (a page in `stats/`), remove it by hand.
