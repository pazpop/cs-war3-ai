# Decisions

Français : [fr/decisions.md](fr/decisions.md)

The choices behind this repository, and why. Change one only for a new fact.

- No OpenTofu: the VPS was ordered by hand, Ansible does everything else.
- The VPS: `cs.pazpop.net` (`domain` in `ansible/inventory.yml`), Debian 13.
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
  also holds stats/guide.html, the players' guide (the bots answer questions from it); the stats page reads its database read-only (the
  bots' latest lines, the journal it writes each night from the Game Master's announcements and the bots' lines).
  In the game the AI shows as `[AI] <bot>`, `[AI Game Master]`, `[AI Coach]` (Anthropic requires the disclosure).
  Each human's name is checked on arrival and on each change (`NAME_CHECK`; the answer kept 30 days in the relay's
  `names` table; the day's last tenth of the budget kept for it): an offensive one makes the plugin rename the player
  "Player", a second after arrival or change. Without an answer (no key, the API down), a name passes until the next
  check. A player whose messages get 3 lines held back within
  an hour is ignored for an hour (`REFUSALS`, `MUTE`). `/coach on` is kept by SteamID in the relay (`coach_on`).
- The chat's tags: `[HELP]` a command and `[INFO]` the server (messages.sma), `[STATS]` numbers (top 5, MVP,
  achievements, goal reached); the AI's lines keep "AI" in their tag.
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
