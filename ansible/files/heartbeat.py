#!/usr/bin/env python3
# Installed by deploy.yml as /usr/local/sbin/cs-war3-ai-heartbeat, run every 5 minutes by cs-war3-ai-heartbeat.timer.
# Checks that the game answers and that the stats page loads, then tells Healthchecks.io: a ping when all is well,
# a /fail ping with the reason otherwise (after a second look 30 seconds later). No ping at all (the VPS is down)
# also raises an alert there.
import http.client
import socket
import time
import urllib.request

SETTINGS = "/etc/cs-war3-ai/healthchecks.env"


def read_settings():
    settings = {}
    with open(SETTINGS) as file:
        for line in file:
            key, _, value = line.strip().partition("=")
            settings[key] = value
    return settings


# The same query as the server browser (A2S_INFO). The server may first answer with a challenge to send back.
def game_answers():
    query = b"\xff\xff\xff\xffTSource Engine Query\x00"
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
        udp.settimeout(5)
        udp.sendto(query, ("127.0.0.1", 27015))
        reply, _ = udp.recvfrom(1400)
        if reply[4:5] == b"A":
            udp.sendto(query + reply[5:9], ("127.0.0.1", 27015))
            reply, _ = udp.recvfrom(1400)
    return reply[4:5] == b"I"


def page_loads(domain):
    request = urllib.request.Request("http://127.0.0.1/index.php", headers={"Host": domain})
    with urllib.request.urlopen(request, timeout=10) as response:
        return response.status == 200


def problems_now(domain):
    problems = []
    try:
        if not game_answers():
            problems.append("the game sent a wrong answer")
    except OSError:
        problems.append("the game does not answer")
    try:
        if not page_loads(domain):
            problems.append("the stats page does not load")
    # HTTPException (a broken answer) is not an OSError.
    except (OSError, http.client.HTTPException):
        problems.append("the stats page does not load")
    return problems


def main():
    settings = read_settings()
    ping_url = settings.get("HC_SERVER", "")
    if not ping_url:
        return

    problems = problems_now(settings["DOMAIN"])
    # A restart (the nightly backup, an update, a reboot) stops the game for a few seconds: look again before alerting.
    if problems:
        time.sleep(30)
        problems = problems_now(settings["DOMAIN"])

    report = ", ".join(problems) or "ok"
    urllib.request.urlopen(ping_url + ("/fail" if problems else ""), data=report.encode(), timeout=10)


if __name__ == "__main__":
    main()
