#!/bin/sh
# Backs up the game's data (AMX Mod X's data folder: XP, rankings, achievements) and the AI relay's memory (its
# database: the players' history, grudges, the bots' lines) into /srv/backups/cs-war3-ai, and keeps 15 days.
# Installed by deploy.yml as /usr/local/sbin/cs-war3-ai-backup. Run every night by cs-war3-ai-backup.timer, and on
# demand by backup.yml. Prints the archive's path.
# The game keeps running: SQLite's own backup makes a consistent copy of a database in use, and the other files only
# change at a map change.
set -eu

backups=/srv/backups/cs-war3-ai
archive=war3-$(date +%Y%m%d-%H%M%S).tgz
mkdir -p "$backups"
chmod 700 "$backups"
work=$(mktemp -d)

# Healthchecks.io (optional, written by deploy.yml): a ping on success, /fail on failure.
ping_url=$(sed -n 's/^HC_BACKUP=//p' /etc/cs-war3-ai/healthchecks.env 2>/dev/null || true)
healthchecks() {
  [ -z "$ping_url" ] || curl -fsS -m 10 --retry 3 -o /dev/null "$ping_url$1" || true
}

# On exit, even if the archive fails: delete a failed archive (a half-written one would look like a good backup) and
# the working copy, then report the result.
finish() {
  status=$?
  rm -rf "$work"
  [ "$status" = 0 ] || rm -f "$backups/$archive"
  if [ "$status" = 0 ]; then
    healthchecks ""
  else
    healthchecks /fail
  fi
  exit "$status"
}
trap finish EXIT
trap 'exit 1' TERM INT

# The volumes' folders on the VPS (this script runs as root).
game=$(docker volume inspect -f '{{.Mountpoint}}' cs-war3-ai_hlds)/cstrike/addons/amxmodx/data
relay=$(docker volume inspect -f '{{.Mountpoint}}' cs-war3-ai_ai)
cp -a "$game" "$work/data"
# A journal copied during a write would be replayed onto the clean copy below, at restore: never kept.
rm -f "$work"/data/sqlite3/*-journal "$work"/data/sqlite3/*-wal "$work"/data/sqlite3/*-shm
mkdir "$work/ai"

# The two databases again, with SQLite's backup (a plain copy made during a write could be broken), owned as before.
python3 - "$game/sqlite3/war3ft.sq3" "$work/data/sqlite3/war3ft.sq3" "$relay/ai.sq3" "$work/ai/ai.sq3" <<'EOF'
import os
import sqlite3
import sys

for source, copy in zip(sys.argv[1::2], sys.argv[2::2]):
    if not os.path.exists(source):
        continue
    # lexists: a link the game left in its folder is removed too, never followed (this runs as root).
    if os.path.lexists(copy):
        os.remove(copy)
    reader = sqlite3.connect(f"file:{source}?mode=ro", uri=True)
    writer = sqlite3.connect(copy)
    reader.backup(writer)
    reader.close()
    writer.close()
    owner = os.stat(source)
    os.chown(copy, owner.st_uid, owner.st_gid)
EOF

tar --numeric-owner -czf "$backups/$archive" -C "$work" data ai
find "$backups" -name 'war3-*.tgz' -mtime +14 -delete
echo "$backups/$archive"
