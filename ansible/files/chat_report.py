#!/usr/bin/env python3
# Installed by deploy.yml as /usr/local/sbin/cs-war3-ai-chat-report, run every night by cs-war3-ai-chat-report.timer.
# Writes a day's chat into /srv/collect/chat/<date>.txt, from the game's logs (the game deletes them after 14 days; the VPS's time): the
# humans, the bots, the Game Master and the coach, with arrivals and departures. Names only: no SteamID, no IP.
# Readable by root, kept KEEP_DAYS.
#   cs-war3-ai-chat-report              yesterday
#   cs-war3-ai-chat-report 2026-10-26   that day
import datetime
import glob
import os
import re
import subprocess
import sys

OUT = "/srv/collect/chat"
KEEP_DAYS = 90
# L 10/26/2026 - 08:06:35: "Ann<42><STEAM_0:1:123456><TERRORIST>" say "1v1 me"
LINE = re.compile(r'^L (\d\d)/(\d\d)/(\d{4}) - (\d\d:\d\d:\d\d): "(.*?)" (say_team|say|entered the game|disconnected)'
                  r'(?: "(.*)")?$')
# A player's name is followed by <userid><SteamID><team>: kept out of the report.
IDS = re.compile(r"<-?\d*><[^>]*><[^>]*>$")


def report(lines, day):
    """The report's lines for that day (YYYY-MM-DD) from the game's log lines."""
    out = []
    for line in lines:
        match = LINE.match(line.rstrip("\r\n"))
        if not match:
            continue
        month, date, year, clock, who, what, text = match.groups()
        if f"{year}-{month}-{date}" != day:
            continue
        name = IDS.sub("", who)
        if what in ("say", "say_team"):
            out.append(f"{clock} {name}{' (team)' if what == 'say_team' else ''}: {text}")
        elif "<BOT>" not in who:
            out.append(f"{clock} -- {name} {what}")
    return out


def main():
    day = sys.argv[1] if len(sys.argv) > 1 else str(datetime.date.today() - datetime.timedelta(days=1))
    volume = subprocess.run(["docker", "volume", "inspect", "-f", "{{.Mountpoint}}", "cs-war3-ai_hlds"],
                            capture_output=True, text=True, check=True).stdout.strip()
    volume = os.path.realpath(volume)
    lines = []
    # Only the game's real log files: a link (the file or a folder above it) or a pipe it left would make this
    # script (root) read anything, or hang.
    logs = [path for path in glob.glob(f"{volume}/cstrike/logs/L*.log")
            if os.path.realpath(path) == path and os.path.isfile(path)]
    for path in sorted(logs, key=os.path.getmtime):
        with open(path, encoding="utf-8", errors="replace") as file:
            lines += file
    # The reports' names are dates: older than KEEP_DAYS, they go.
    oldest = str(datetime.date.today() - datetime.timedelta(days=KEEP_DAYS))
    for path in glob.glob(f"{OUT}/????-??-??.txt"):
        if os.path.basename(path) < oldest:
            os.remove(path)
    out = report(lines, day)
    if not out:
        return
    os.makedirs(OUT, mode=0o700, exist_ok=True)
    with open(f"{OUT}/{day}.txt", "w", encoding="utf-8") as file:
        file.write(f"Chat on {day}\n" + "\n".join(out) + "\n")


if __name__ == "__main__":
    main()
