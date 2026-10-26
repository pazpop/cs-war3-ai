#!/bin/sh
# Backs up AMX Mod X's data folder (XP, rankings, achievements) into /srv/backups/cs-war3-ai, and keeps 15 days.
# Installed by deploy.yml as /usr/local/sbin/cs-war3-ai-backup. Run every night by cs-war3-ai-backup.timer, and on
# demand by backup.yml. Prints the archive's path.
# The game stops for about 30 seconds: the database does not change during the archive.
set -eu

backups=/srv/backups/cs-war3-ai
archive=war3-$(date +%Y%m%d-%H%M%S).tgz
mkdir -p "$backups"
chmod 700 "$backups"

# Healthchecks.io (optional, written by deploy.yml): a ping on success, /fail on failure.
ping_url=$(sed -n 's/^HC_BACKUP=//p' /etc/cs-war3-ai/healthchecks.env 2>/dev/null || true)
healthchecks() {
  [ -z "$ping_url" ] || curl -fsS -m 10 --retry 3 -o /dev/null "$ping_url$1" || true
}

# On exit, even if the archive fails: delete a failed archive (a half-written one would look like a good backup),
# start the game again, then report the result. A game that does not start again is a failure too.
finish() {
  status=$?
  [ "$status" = 0 ] || rm -f "$backups/$archive"
  docker compose start hlds >&2 || status=1
  if [ "$status" = 0 ]; then
    healthchecks ""
  else
    healthchecks /fail
  fi
  exit "$status"
}

trap finish EXIT
# A signal (systemd stopping the unit) would end the script without its EXIT trap: the game would stay off.
trap 'exit 1' TERM INT
cd /srv/cs-war3-ai
docker compose stop hlds >&2

# With the game image, as root: the volume belongs to steam.
docker run --rm --user 0 --entrypoint tar -v cs-war3-ai_hlds:/hlds:ro -v "$backups":/out cs-war3-ai-hlds \
  --numeric-owner -czf "/out/$archive" -C /hlds/cstrike/addons/amxmodx data

find "$backups" -name 'war3-*.tgz' -mtime +14 -delete
echo "$backups/$archive"
