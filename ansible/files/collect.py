#!/usr/bin/env python3
# Installed by deploy.yml as /usr/local/sbin/cs-war3-ai-collect, run every 5 minutes by cs-war3-ai-collect.timer.
# Adds one line per server to /srv/collect/players.csv: the time (the VPS's, with its offset from UTC), the server and its status.php (online,
# humans, bots, slots, map). Only numbers and map names, nothing about the players: to see when people play, and where.
#   cs-war3-ai-collect cs.pazpop.net
import csv
import http.client
import json
import os
import sys
import time
import urllib.request

CSV = "/srv/collect/players.csv"
COLUMNS = ["time", "server", "online", "humans", "bots", "slots", "map"]


def status(domain):
    try:
        with urllib.request.urlopen(f"https://{domain}/status.php", timeout=10) as response:
            data = json.load(response)
    # HTTPException (a broken answer) is not an OSError.
    except (OSError, ValueError, http.client.HTTPException):
        return {"online": False}
    # Anything else than a JSON object: the server did not answer as expected.
    return data if isinstance(data, dict) else {"online": False}


def main():
    now = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    new = not os.path.exists(CSV)
    with open(CSV, "a", newline="") as file:
        writer = csv.DictWriter(file, COLUMNS, extrasaction="ignore")
        if new:
            writer.writeheader()
        for domain in sys.argv[1:]:
            row = status(domain)
            row.update(time=now, server=domain, online=int(bool(row.get("online"))))
            writer.writerow(row)


if __name__ == "__main__":
    main()
