# cs-war3-ai

Shared method: `../methode/METHODE.md` (the owner's private repository). This file holds only what differs from it
and what is specific to the project.

Type: game (JEUX.md), servers (SERVEURS.md). Status: PROD.

A Counter-Strike 1.6 server with War3FT and YaPB bots. Goals: have fun building it, leave a repository useful to
anyone who wants to run their own server, and get players to come back and bring friends.

## Decisions

The design choices and why: `docs/decisions.md`. Read it before changing one.

## Rules

- Divergence: the repository (public, MIT), its docs and what players see are in English; every doc has a French
  copy in `docs/fr/`. Answers stay in French.
- Personal values go in `ansible/personal.yml` (ignored).
- Read the VPS over SSH only with the owner's consent
  (`ssh -p 2222 -i ~/.ssh/deploy deploy@cs.pazpop.net`), and mask IPs and SteamIDs in what you show.

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
- `deploy.yml` deletes `server/plugins/` first: a forgotten .sma would be compiled.
- War3FT's zip bundles AMX Mod X build 5467: the Dockerfile lays a later 1.10 build's `dlls/`, `modules/` and
  `data/gamedata/` over it (5487 has the fix for a crash on a dropped connection). Renovate does not see it: check by hand.
- With `csdm_active 1`, War3FT turns off everything that respawns a player or keeps their gear (`_SHARED_Spawn`,
  `SHARED_CS_Reincarnation`): the Orc's Reincarnation, the Blood Mage's Phoenix, the Warden's Vengeance, the ankh,
  the scroll. The guides say so; War3FT has no setting to hide them.
- After a start, AMX Mod X's `nextmap` does not find the start map and picks the cycle's first one: `de_dust2` (the
  start map, `entrypoint.sh`) is the last line of `mapcycle.txt`, so the cycle goes on in order.
- The game's log is echoed to the console by `mp_logecho` (off: the IPs would land in Docker's logs). The chat
  reaches the console anyway (the game prints it): hlds's Docker log is kept small (compose.yml).
  `sv_logecho` does not exist here.
- `client_disconnected(id, drop)`: `drop` is false at a map's end, true when a player leaves or is kicked.
- The relay's prompts quote players' words with `quoted()` (`ensure_ascii=False`): with escape codes, the moderator
  would read codes instead of words in other alphabets.
- PHP-FPM's image logs every request with the visitor's IP: `compose.yml` turns its access log off. A `configs`
  `content` cannot go into a read-only container: `stats` is not read-only.
