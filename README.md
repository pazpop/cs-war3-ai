# cs-war3-ai

![cs-war3-ai](docs/banner.svg)

[![Check](https://github.com/pazpop/cs-war3-ai/actions/workflows/check.yml/badge.svg)](https://github.com/pazpop/cs-war3-ai/actions/workflows/check.yml)

Français : [docs/fr/README.md](docs/fr/README.md)

A public Counter-Strike 1.6 server with War3FT (Warcraft 3 races and spells) and an AI: bots that talk back, and a
Game Master. And the code to run your own.

## The game

- Respawn, in teams: you come back at once. 8 Warcraft 3 races with skills and an ultimate; your XP is saved, race
  by race, and levels come twice as fast.
- Bots fill the server when few people play, and talk back: name one in the chat, or ask a question with a `?`.
  They remember you, see you as a rival if you beat them often, and never make fun of you.
- An AI Game Master: bounties, duels, a boss, challenges; a journal each night on the site.
- `/coach`: a tip from an AI coach, or the answer to your question, from your numbers on the map, in private;
  `/coach on`: one every 5 minutes.
- A goal of the week, achievements, and rankings with a hall of fame on [cs.pazpop.net](https://cs.pazpop.net).
- 1000 FPS server, North America (east).

Everything else (commands, races, rules): the guide, [cs.pazpop.net/guide.html](https://cs.pazpop.net/guide.html)
([stats/guide.html](stats/guide.html)).

## Join the server

You need Counter-Strike 1.6 on Steam. Then any of these:

- On [cs.pazpop.net](https://cs.pazpop.net), click **Join the server**.
- In the game console (the key under Esc), type `connect cs.pazpop.net:27015`.

For a smooth game: [docs/client.md](docs/client.md).

## Run your own server

The server runs in Docker on a VPS, deployed with Ansible: [docs/installation.md](docs/installation.md).

## License

Our code is under the [MIT license](LICENSE). The components it downloads keep their own licenses (see the
installation guide). The announcer's voices are by Antti Saari and TripleSnail, under CC-BY 3.0
([server/sound/announcer/CREDITS.txt](server/sound/announcer/CREDITS.txt)). The stats site's images were made with
PixelLab ([stats/img/CREDITS.txt](stats/img/CREDITS.txt)).
