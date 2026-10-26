# cs-war3-ai

![cs-war3-ai](docs/banner.svg)

[![Check](https://github.com/pazpop/cs-war3-ai/actions/workflows/check.yml/badge.svg)](https://github.com/pazpop/cs-war3-ai/actions/workflows/check.yml)

Français : [docs/fr/README.md](docs/fr/README.md)

A public Counter-Strike 1.6 server with War3FT (Warcraft 3 races and spells) and an AI: bots that talk back, and a
Game Master. And the code to run your own.

## The game

- Respawn: you come back at once, no rounds, no waiting. Choose your weapons with **G**. 3 seconds of protection
  after each respawn, lost when you shoot.
- Pick one of 8 races (Undead, Human, Orc, Night Elf...). Each has 3 skills and an ultimate.
- Earn XP, level up, unlock skills. Your XP is saved, race by race: you get it back next time.
- Levels come twice as fast as usual, and a race you have never played starts at level 3: your ultimate
  (level 6) comes quickly.
- Bots fill the server when few people play. One leaves for each human who joins. They talk back: name one in the
  chat, or ask a question with a `?`. Kill one often, and it holds a grudge. And a Game Master (an AI) starts bounties, duels and other surprises.
- An announcer for first blood, multi-kills and kill streaks, up to GODLIKE. Your damage shows under the crosshair.
- 14 achievements to unlock (`/ach`, the closest one is shown at each map), and the top 10's place shown in the
  chat. Last month's top 3 get a `[Champion]` tag and a place in the hall of fame.
- 10 classic maps (de_dust2, de_inferno, cs_office...); a vote picks the next one, and `rtv` asks for a vote now.
- Rankings at [cs.pazpop.net](https://cs.pazpop.net): the month's (from zero on the 1st), XP per race,
  combat, and a page per player (`/mystats` gives yours).
- Join a server of bots only, and the game restarts: everyone starts from zero.
- 1000 FPS server, North America (east).

How the mod works: [docs/war3ft.md](docs/war3ft.md).

## Join the server

You need Counter-Strike 1.6 on Steam. Then any of these:

- On [cs.pazpop.net](https://cs.pazpop.net), click **Join the server**.
- In the game console (the key under Esc), type `connect cs.pazpop.net:27015`.

In game: `/help` shows the guide, `rtv` asks for a new map, `votekick` starts a vote to kick a player.
Away for 60 seconds, you become a spectator; a ping over 300 ms for 50 seconds gets you kicked.
For a smooth game: [docs/client.md](docs/client.md).

## Run your own server

The server runs in Docker on a VPS, deployed with Ansible: [docs/installation.md](docs/installation.md).

## License

Our code is under the [MIT license](LICENSE). The components it downloads keep their own licenses (see the
installation guide). The announcer's voices are by Antti Saari and TripleSnail, under CC-BY 3.0
([server/sound/announcer/CREDITS.txt](server/sound/announcer/CREDITS.txt)). The stats site's images were made with
PixelLab ([stats/img/CREDITS.txt](stats/img/CREDITS.txt)).
