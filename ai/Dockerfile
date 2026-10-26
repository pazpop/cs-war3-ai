# The AI relay (relay.py): only Python's standard library, nothing installed.
# Built from the repository's root (compose.yml), for the bots' list and the mod's guide: .dockerignore sends only
# these files.
FROM python:3.13-alpine

# Its memory (the players' history, the day's spending) is in /data: the folder exists, owned by the relay's user, so
# Docker copies it into the new volume with that owner.
RUN adduser -D -u 1000 ai && mkdir /data && chown ai:ai /data
COPY ai/relay.py /app/relay.py
COPY server/bots.txt /app/bots.txt
COPY docs/war3ft.md /app/war3ft.md
USER ai
VOLUME /data
EXPOSE 27100
CMD ["python3", "-u", "/app/relay.py"]
