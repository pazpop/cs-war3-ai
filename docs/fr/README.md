# cs-war3-ai

![cs-war3-ai](../banner.svg)

[![Check](https://github.com/pazpop/cs-war3-ai/actions/workflows/check.yml/badge.svg)](https://github.com/pazpop/cs-war3-ai/actions/workflows/check.yml)

English (official): [../../README.md](../../README.md)

Un serveur public Counter-Strike 1.6 avec War3FT (les races et les sorts de Warcraft 3) et une IA : des bots qui
répondent, et un maître du jeu. Et le code pour monter le tien.

## Le jeu

- Respawn, par équipes : tu reviens tout de suite. 8 races de Warcraft 3 avec leurs compétences et un ultime ; ton XP
  est gardée, race par race, et les niveaux viennent deux fois plus vite.
- Des bots remplissent le serveur quand il y a peu de monde, et répondent : nomme-en un dans le chat, ou pose une
  question avec un `?`. Ils se souviennent de toi, te voient comme un rival si tu les bats souvent, et ne se moquent
  jamais de toi.
- Un maître du jeu IA : primes, duels, un boss, des défis ; un journal chaque nuit sur le site.
- `/coach` : un conseil d'un coach IA, ou la réponse à ta question, tiré de tes chiffres sur la carte, en privé ;
  `/coach on` : un toutes les 5 minutes.
- Un objectif de la semaine, des succès, et des classements avec un tableau d'honneur sur
  [cs.pazpop.net](https://cs.pazpop.net).
- Serveur à 1000 FPS, Amérique du Nord (est).

Tout le reste (commandes, races, règlement) : [guide.md](guide.md).

## Rejoindre le serveur

Il faut Counter-Strike 1.6 sur Steam. Puis, au choix :

- Sur [cs.pazpop.net](https://cs.pazpop.net), clique sur **Join the server**.
- Dans la console du jeu (la touche sous Échap), tape `connect cs.pazpop.net:27015`.

Pour un jeu fluide : [client.md](client.md).

## Monter ton propre serveur

Le serveur tourne dans Docker sur un VPS, déployé avec Ansible : [installation.md](installation.md).

## Licence

Notre code est sous [licence MIT](../../LICENSE). Les briques qu'il télécharge gardent leurs propres licences (voir
le guide d'installation). Les voix de l'annonceur sont d'Antti Saari et TripleSnail, sous CC-BY 3.0
([server/sound/announcer/CREDITS.txt](../../server/sound/announcer/CREDITS.txt)). Les images du site de stats ont
été faites avec PixelLab ([stats/img/CREDITS.txt](../../stats/img/CREDITS.txt)).
