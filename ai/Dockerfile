# The AI relay (relay.py): only Python's standard library, nothing installed.
FROM python:3.13-alpine

# Its memory (the players' history, the day's spending) is in /data: the folder exists, owned by the relay's user, so
# Docker copies it into the new volume with that owner.
RUN adduser -D -u 1000 ai && mkdir /data && chown ai:ai /data
COPY relay.py /app/relay.py
USER ai
VOLUME /data
EXPOSE 27100
CMD ["python3", "-u", "/app/relay.py"]
