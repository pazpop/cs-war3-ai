#!/bin/sh
# Installs CS 1.6 into /hlds on first start (or with UPDATE=1), puts the mods on top, then starts HLDS.
set -eu

case "${DOMAIN:-}" in
  '' | *[!a-z0-9.-]*) echo "DOMAIN: \"${DOMAIN:-}\" is not a domain name (game.example.com)." >&2; exit 1 ;;
esac

# App 90 often stops before the end: run it again until the success message.
# steam_legacy: the pre-2023 version (build 8684), the only one ReHLDS replaces.
if [ ! -x /hlds/hlds_linux ] || [ "${UPDATE:-0}" = 1 ]; then
  for attempt in 1 2 3 4 5; do
    ~/steamcmd/steamcmd.sh +force_install_dir /hlds +login anonymous \
      +app_set_config 90 mod cstrike +app_update 90 -beta steam_legacy validate +quit | tee /tmp/steamcmd.log
    grep -qE "Success! App '90' (fully installed|already up to date)" /tmp/steamcmd.log && break
    if [ "$attempt" = 5 ]; then
      echo "SteamCMD: CS 1.6 not installed after 5 attempts." >&2
      exit 1
    fi
  done
fi

# At every start: a Valve update puts its own engine back, and our settings win.
# The data (XP, stats, what the bots learned) is not in /opt/mods: it stays.
# AMX Mod X's plugins folder starts from the image's: a plugin removed from the image does not stay behind.
rm -rf /hlds/cstrike/addons/amxmodx/plugins
cp -R /opt/mods/. /hlds/
# cp does not change the permissions of a folder that already exists: set them, so the mods can write.
chmod -R u+rwX /hlds/cstrike/addons

cd /hlds/cstrike

# The settings that depend on the domain: server name, FastDL, and the MOTD (the guide, served by Caddy).
# http://: the in-game browser (MOTD) is too old for today's HTTPS.
cat >> server.cfg <<EOF
hostname "War3FT AI | Bots talk back | Respawn | SaveXP | $DOMAIN"
sv_downloadurl "http://$DOMAIN/cstrike/"
EOF
echo "http://$DOMAIN/guide.html" > motd.txt

# The chat messages (server/plugins/messages.sma), with the server's address.
sed -i "s/{domain}/$DOMAIN/g" addons/amxmodx/configs/messages.txt

# The AMX Mod X admins (SteamIDs separated by spaces): every right, recognized by SteamID.
# users.ini has just been copied over: add them at every start. A malformed SteamID stops everything.
for id in ${ADMINS:-}; do
  # STEAM_X:Y: then digits, and nothing else.
  case "$id" in
    STEAM_[0-5]:[01]:*) number=${id#STEAM_?:?:} ;;
    *) number= ;;
  esac
  case "$number" in
    '' | *[!0-9]*) echo "ADMINS: \"$id\" is not a SteamID (STEAM_0:1:123456)." >&2; exit 1 ;;
  esac
  printf '"%s" "" "abcdefghijklmnopqrstuv" "ce"\n' "$id" >> addons/amxmodx/configs/users.ini
done

# Now and every day while the server runs: HLDS, AMX Mod X and YaPB write log files, kept two weeks; War3FT's log
# of admin commands (bots.sma sets each bot's level through one at every spawn) is never trimmed by War3FT: emptied.
(
  while :; do
    find logs addons/amxmodx/logs addons/yapb -name '*.log' -mtime +14 -delete 2>/dev/null || true
    rm -f addons/amxmodx/configs/war3ft/wc3_admin.log
    sleep 86400
  done
) &

# stats_domain: the stats site, for /mystats (server/plugins/web_stats.sma); set before the plugins load. The domain
# only: on this line, the game would read the // of https:// as the start of a comment.
# The port must match compose.yml. sys_ticrate: game updates per second (the server's "FPS"; Valve's default is 100).
# de_dust2 is the last map of mapcycle.txt: after a start, AMX Mod X's nextmap picks the cycle's first map (de_inferno),
# the one after it, instead of playing de_dust2 twice.
set -- -game cstrike -console +ip 0.0.0.0 +port 27015 +maxplayers 16 \
  +sys_ticrate "${TICRATE:-1000}" +localinfo stats_domain "$DOMAIN" +map de_dust2 +sv_lan 0
# Without a password, the remote console (rcon) stays closed.
if [ -n "${RCON:-}" ]; then
  set -- "$@" +rcon_password "$RCON"
fi

cd /hlds
export LD_LIBRARY_PATH="/hlds:${LD_LIBRARY_PATH:-}"
# Docker stops a container with SIGTERM, and HLDS crashes on it before saving anything (XP, ranking, achievements
# since the last map change). So HLDS reads its console from a pipe: what is typed in "docker attach" goes into it,
# and so does "quit" when Docker stops the container. A clean quit saves everything.
rm -f /tmp/console
mkfifo /tmp/console
# Kept open by this script: HLDS never reads an end of file (it would spin).
exec 3<> /tmp/console
# A command run in the background gets an empty input: cat gets the container's input through descriptor 4.
exec 4<&0
cat <&4 > /tmp/console &
trap 'echo quit > /tmp/console' TERM INT
# In its own process group (setsid): Ctrl+C in "docker attach" reaches only this script, not HLDS (it would crash).
setsid -w ./hlds_linux "$@" < /tmp/console &
hlds=$!
status=0
# wait stops when the signal arrives: wait again until HLDS has quit. The container exits with HLDS's code.
while kill -0 "$hlds" 2>/dev/null; do
  status=0
  wait "$hlds" || status=$?
done
exit "$status"
