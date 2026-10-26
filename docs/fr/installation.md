# Installation

English (official): [../installation.md](../installation.md)

Un VPS Debian 13, installé avec Ansible depuis Ubuntu (WSL sous Windows convient). Le serveur tourne dans Docker.

## Composants

| Brique | Rôle | Licence |
|---|---|---|
| [ReHLDS](https://github.com/rehlds/ReHLDS) | Remplace le moteur du serveur dédié (plus sûr, plus rapide) | MIT |
| [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS) | Remplace le code du jeu CS (bugs corrigés, plus de réglages) | MIT |
| [Metamod-R](https://github.com/rehlds/Metamod-R) | Charge les plugins (AMX Mod X, YaPB) | GPL-3.0 |
| [ReAPI](https://github.com/rehlds/ReAPI) | Donne aux plugins d'AMX Mod X l'accès à ReHLDS et ReGameDLL | GPL-3.0 |
| [War3FT](https://github.com/wc3mods/war3ft) | Le mod, en paquet tout-en-un avec AMX Mod X 1.10 | aucune indiquée (AMX Mod X : GPL-3.0) |
| [ReDeathmatch](https://github.com/ReDeathmatch/ReDeathmatch_AMXX) | Le Respawn : réapparition immédiate, menu des armes, protection à l'apparition | MIT |
| [YaPB](https://github.com/yapb/yapb) | Les bots | Unlicense |
| Voix de l'annonceur (Antti Saari, TripleSnail) | Premier kill, multi-kills, séries : dans `server/sound/announcer/` | CC-BY 3.0 |
| [Caddy](https://caddyserver.com) | Le FastDL, le guide et les pages de stats (HTTP et HTTPS) | Apache-2.0 |
| [PHP](https://www.php.net) | Fait tourner les pages de stats | PHP License |
| [Python](https://www.python.org) | Le relais de l'IA (`ai/relay.py`), bibliothèque standard seulement | PSF |
| [Claude](https://www.anthropic.com/api) (l'API d'Anthropic, optionnel) | Les répliques des bots et le maître du jeu | service payant |

L'image du jeu télécharge les sept premières au build ; versions et empreintes SHA-256 dans
[server/Dockerfile](../../server/Dockerfile). Caddy, PHP et Python sont leurs propres images Docker
officielles.
CS 1.6 lui-même (la branche `steam_legacy`, la seule que ReHLDS remplace) est téléchargé au premier démarrage, dans
le volume `hlds`. Aucun fichier du jeu de Valve dans le dépôt ni dans l'image (seulement SteamCMD) ; rien de
War3FT dans le dépôt.
Les voix de l'annonceur sont les seuls fichiers de tiers qu'il contient
([CREDITS.txt](../../server/sound/announcer/CREDITS.txt)).

## Tes réglages

1. Un nom DNS qui pointe vers le VPS : c'est `domain` dans [ansible/inventory.yml](../../ansible/inventory.yml),
   avec tes propres serveurs dans `collect_domains`. Les messages du chat :
   [server/messages.txt](../../server/messages.txt).
2. Une clé SSH pour Ansible (`ansible_ssh_private_key_file` dans l'inventaire), copiée sur le compte de l'hébergeur :
   `ssh-copy-id -i ~/.ssh/cs_pazpop_net.pub debian@cs.pazpop.net`
3. Copie [ansible/personal.example.yml](../../ansible/personal.example.yml) en `ansible/personal.yml` (ignoré par git)
   et remplis-le : le compte de l'hébergeur, ton compte, le dossier des sauvegardes, les SteamID des admins.
4. Les collections d'Ansible : `ansible-galaxy collection install -r ansible/requirements.yml`
5. Le coffre, pour les secrets : chiffré, et ignoré par git (il ne quitte jamais ton PC). Garde une copie du
   fichier et de son mot de passe.
   ```bash
   source vault.sh                       # le mot de passe du coffre, gardé 2 h dans ce terminal
   ansible-vault create ansible/vault.yml
   ```
   Dedans, optionnel : `vault_rcon: <16 caractères ou plus : lettres, chiffres, _ et ->`. Sans lui, le rcon reste
   fermé ; les admins marchent toujours par SteamID. Optionnel aussi : `vault_anthropic_key: sk-ant-...`, pour
   l'IA (voir [L'IA](#lia-optionnel)). Un coffre vide convient : `{}`.

## Installer le VPS

Depuis la racine du dépôt, après `source vault.sh` :

```bash
ansible-playbook -i ansible/inventory.yml ansible/init.yml    # une fois : comptes, SSH sur 2222
ansible-playbook -i ansible/inventory.yml ansible/config.yml  # le système : pare-feu, Docker, mises à jour
ansible-playbook -i ansible/inventory.yml ansible/deploy.yml  # le serveur de jeu et la page de stats
```

`config.yml` et `deploy.yml` se relancent autant qu'on veut (voir [Les mises à jour](#les-mises-à-jour)). `config.yml`
redémarre le VPS quand une mise à jour le demande : lance-le quand personne ne joue.

## Le serveur de jeu

| Action | Commande, sur le VPS (dans `/srv/cs-war3-ai`) |
|---|---|
| Journal | `sudo docker logs -f cs-war3-ai-hlds-1` |
| Console | `sudo docker attach cs-war3-ai-hlds-1` (en sortir : `Ctrl+P` puis `Ctrl+Q` ; `Ctrl+C` redémarre le serveur) |
| Mettre à jour CS 1.6 | `sudo UPDATE=1 docker compose up -d`, puis `sudo docker compose up -d` une fois lancé (sinon chaque redémarrage refait la mise à jour) |
| Revenir aux FPS par défaut de Valve | `sudo TICRATE=100 docker compose up -d` (jusqu'au prochain `deploy.yml`) |

Dans la console : `meta list` (AMX Mod X et YaPB en `RUN`), `amxx plugins` (`war3ft.amxx` en `running`), `stats`.

Réglages : [server/Dockerfile](../../server/Dockerfile) (War3FT, ReDeathmatch, YaPB, AMX Mod X) et
[server/server.cfg](../../server/server.cfg). À chaque démarrage, le script d'entrée ajoute le nom du serveur,
l'adresse du FastDL et le MOTD, à partir de `DOMAIN`. Les cartes : [server/mapcycle.txt](../../server/mapcycle.txt),
reprise en `maps.ini` : les cartes de CS 1.6 les plus aimées que les bots connaissent.

## Nos plugins

Dans [server/plugins/](../../server/plugins/), compilés au build :

- `achievements.sma` : 14 succès (`/ach`), gardés dans la base de War3FT ; les pages des joueurs les affichent. À
  chaque carte, le plus proche ; un mot au joueur quand il en reste 10 %.
- `afk.sma` : 60 secondes sans toucher une touche ni bouger la souris, et un joueur passe en spectateur.
- `ai.sma` : envoie le chat, les kills entre bots et humains, et toutes les 4 minutes l'état de la partie au
  relais de l'IA, et fait ce qu'il répond (voir [L'IA](#lia-optionnel)).
- `announcer.sma` : les voix et les messages du premier kill, des multi-kills et des séries. Les joueurs téléchargent
  les voix en HTTP (FastDL).
- `block_test.sma` : bloque les commandes de débogage `test` et `test2` de War3FT, ouvertes à tous les joueurs
  (elles remplissent les logs).
- `csdm_active.sma` : active le mode deathmatch de War3FT (une nouvelle session à chaque réapparition) ;
  ReDeathmatch fait réapparaître les joueurs.
- `damage.sma` : les dégâts que le joueur inflige, sous le viseur, à chaque coup.
- `help.sma` : `/help` dans le chat, ou `help` dans la console, rouvre le guide.
- `high_ping.sma` : un ping au-dessus de 300 ms pendant 50 secondes, et un joueur est expulsé.
- `messages.sma` : un message dans le chat toutes les 2 minutes, à tour de rôle, tiré de
  [server/messages.txt](../../server/messages.txt) : ajouter le serveur aux favoris, la page de stats, les commandes.
- `monthly.sma` : le classement du mois (kills - morts, repart de zéro le 1er), sur la page de stats. À chaque
  carte, la place du joueur ce mois-ci.
- `rank_tag.sma` : le top 10 affiche sa place dans le chat, `[#3] nom : message` ; le top 3 du mois passé,
  `[Champion]`.
- `rtv.sma` : `rtv` dans le chat ; à 60 % de tous les humains du serveur, le vote d'adminvote sur 4 cartes au hasard
  (pas dans les 2 dernières minutes de la carte, quand mapchooser vote).
- `slash_commands.sma` : `/nextmap`, `/currentmap`, `/timeleft`, `/thetime` (AMX Mod X ne les connaît que sans le
  `/`) : toutes les commandes marchent alors avec un `/`.
- `votekick.sma` : un joueur est exclu 10 minutes quand 60 % des autres humains l'ont choisi (3 humains au moins ;
  les admins ne sont pas dans le menu).
- `web_stats.sma` : pour la page de stats, garde le nom de chaque humain (en SQLite, War3FT ne garde que le SteamID),
  et recopie le top 100 du classement de combat de CS (`/rank`, `/top15`) à chaque début de carte. `/mystats` : le
  lien vers la page du joueur.

ReDeathmatch : par équipes, réapparition immédiate dans sa base, pas de manches, les armes avec **G**, 800 $ au
départ (les boutiques de War3 se paient). 3 secondes de protection à la réapparition, perdues au premier tir
(`mp_respawn_immunity*` de ReGameDLL). Mapchooser lance un vote en fin de carte (toutes les 30 minutes).
Le plugin `antiflood` d'AMX Mod X bloque le flood dans le chat (un message toutes les 0,75 s au plus :
`amx_flood_time`).

## Les données et la sauvegarde

L'XP est en SQLite, dans le volume : `cstrike/addons/amxmodx/data/sqlite3/war3ft.sq3`. Pas MySQL : en mode MySQL,
War3FT échappe mal les noms des joueurs (injection SQL possible) ; en mode SQLite, il les échappe bien.

Chaque nuit à 4 h 32 (entre les mises à jour de 4 h et le redémarrage de 5 h), le VPS sauvegarde l'XP, les
classements et les succès dans `/srv/backups/cs-war3-ai`, et garde 15 jours (environ 1,5 Mo par archive). Le jeu est coupé une
trentaine de secondes. Le script :
[ansible/files/backup.sh](../../ansible/files/backup.sh), lancé par la tâche planifiée systemd `cs-war3-ai-backup.timer`.

Pour en faire une tout de suite et la rapatrier sur ton PC (dans `backup_dir`, `ansible/personal.yml`) :

```bash
ansible-playbook -i ansible/inventory.yml ansible/backup.yml
```

Pour restaurer une archive, sur le VPS (le jeu s'arrête pendant ce temps) :

```bash
cd /srv/cs-war3-ai
sudo docker compose stop hlds
sudo docker run --rm --user 0 --entrypoint tar -v cs-war3-ai_hlds:/data -v /srv/backups/cs-war3-ai:/in:ro cs-war3-ai-hlds -xzf /in/<archive>.tgz -C /data/cstrike/addons/amxmodx
sudo docker compose start hlds
```

## Le web

- `https://<domaine>` (et `http://`, pour le navigateur du jeu) : les classements (du mois, XP et combat),
  le nombre de joueurs (depuis le lancement, 30 et 90 derniers jours) ([stats/index.php](../../stats/index.php)),
  et une page par joueur ([stats/player.php](../../stats/player.php)) : XP et niveaux des compétences par race,
  succès, stats de combat. PHP lit la base en lecture seule.
- `https://<domaine>/status.php` : l'état du serveur en ce moment, en JSON (humains, bots, carte, places), pour
  d'autres sites : [pazpop.net](https://pazpop.net) l'affiche. Le jeu est interrogé au plus toutes les 15 secondes.
- `http://<domaine>/guide.html` : le guide, affiché à la connexion. Le navigateur du jeu (MOTD) est trop vieux pour
  le HTTPS d'aujourd'hui : en jeu, seules les pages `http://` s'ouvrent.
- `http://<domaine>/cstrike/…` : le FastDL. Le téléchargement par le jeu (UDP) fait planter le client sur les
  fichiers de War3FT. Un Caddy à part le sert, sans aucun certificat, et seulement les fichiers de War3FT et les
  voix de l'annonceur : jamais les configs ni l'XP ([caddy/fastdl.Caddyfile](../../caddy/fastdl.Caddyfile)). La
  façade lui passe `/cstrike/`.

## Les mises à jour

- **Le système** se met à jour tout seul chaque nuit à 4 h, et redémarre à 5 h si une mise à jour le demande.
- **CS 1.6** : voir [Le serveur de jeu](#le-serveur-de-jeu).
- **Caddy, PHP et la base Debian** : lance `deploy.yml` environ une fois par mois : il reconstruit l'image sur une
  base Debian à jour, et prend les derniers correctifs de Caddy et PHP.
- **Les mods** (ReHLDS, ReGameDLL, Metamod-R, ReAPI, War3FT, ReDeathmatch, YaPB) :
  [Renovate](https://docs.renovatebot.com) ouvre une « pull request » quand une nouvelle version sort (active
  l'application gratuite Renovate sur le dépôt). Dans cette
  pull request, remplace l'empreinte SHA-256 de la version dans [server/Dockerfile](../../server/Dockerfile) :
  `curl -sL <adresse de l'archive> | sha256sum`. D'ici là, la vérification ci-dessous échoue, exprès.
- **Les vérifications** : chaque push lance [.github/workflows/check.yml](../../.github/workflows/check.yml) :
  `ansible-lint`, `shellcheck`, la syntaxe Python et PHP, et le build de l'image du jeu (qui vérifie les SHA-256 et
  compile nos plugins).

## Le nombre de joueurs

Toutes les 5 minutes, [ansible/files/collect.py](../../ansible/files/collect.py) ajoute une ligne par serveur dans
`/srv/collect/players.csv` : heure (UTC), serveur, en ligne, humains, bots, places, carte. Seulement des nombres, rien
sur les joueurs (environ 60 Ko par jour). Les serveurs : `collect_domains` dans
[ansible/inventory.yml](../../ansible/inventory.yml). Pour le télécharger :

```bash
scp -P 2222 deploy@<domaine>:/srv/collect/players.csv .
```

## L'IA (optionnel)

Des bots qui répondent, et un maître du jeu. `ai.sma` envoie les nouvelles de la partie au relais
([ai/relay.py](../../ai/relay.py), son propre conteneur), qui demande à Claude (Claude Haiku 5.5) et répond par
des actions :

- **Les bots parlent** : un bot répond quand un joueur le nomme dans le chat (parfois même sans ça), et de temps
  en temps après un kill entre un bot et un humain. Chaque nom de bot a son caractère. Les bots se souviennent de
  chaque humain (par SteamID, dans le volume du relais) : depuis quand il joue, comment il s'en sort contre eux.
- **Le maître du jeu** : toutes les 4 minutes, il lit le score et peut lancer un événement : une prime sur un
  joueur très en avance, un duel entre deux joueurs, 30 secondes de gravité basse, de l'argent pour tous. Il ne
  choisit que dans cette liste : le plugin vérifie chaque événement et le lance lui-même.

Mise en place : une clé API de [console.anthropic.com](https://console.anthropic.com) dans le vault
(`vault_anthropic_key: sk-ant-...`), puis `deploy.yml`. Sans clé, le relais se tait et le jeu ne change pas. Il
dépense au plus `AI_DAILY_USD` par jour (1 $ par défaut, dans `compose.yml`), puis se tait jusqu'à minuit UTC ;
mets aussi une limite mensuelle dans la console d'Anthropic.

Ce qui sort du VPS : les messages du chat, les noms, le score. Jamais les SteamID ni les IP. Le guide le dit aux
joueurs.

Ses logs : `docker compose logs ai`.

## Le monitoring (optionnel)

[Healthchecks.io](https://healthchecks.io) (gratuit jusqu'à 20 vérifications, libre) te prévient par courriel,
Discord, Telegram… quand un ping n'arrive pas à temps. Il repère aussi un VPS complètement tombé.

1. Crée deux vérifications : **backup** (période 1 jour, délai de grâce 1 heure) et **server** (période 5 minutes,
   délai de grâce 10 minutes).
2. Mets leurs adresses de ping dans le coffre : `ansible-vault edit ansible/vault.yml`, puis
   `vault_hc_backup: https://hc-ping.com/<uuid>` et `vault_hc_server: https://hc-ping.com/<uuid>`.
3. Lance `deploy.yml`.

- **backup** : [ansible/files/backup.sh](../../ansible/files/backup.sh) pingue quand il réussit, `/fail` quand il rate.
- **server** : toutes les 5 minutes, [ansible/files/heartbeat.py](../../ansible/files/heartbeat.py) vérifie que le jeu
  répond et que la page de stats s'affiche, puis pingue (`/fail` avec la raison si quelque chose ne va pas).

Sans ces adresses, rien n'est envoyé.

## L'Edge Network Firewall d'OVHcloud (optionnel)

Chez OVHcloud, l'Edge Network Firewall filtre le trafic avant qu'il atteigne le VPS. Il s'active aussi tout seul
pendant une attaque DDoS : ses règles doivent donc être justes. Espace client : Network > Public IP Addresses > `⁝` à
côté de l'IPv4 > Configure Edge Network Firewall, puis l'activer.

| Priorité | Action | Protocole | Port source | Port destination | Option | Pourquoi |
|---|---|---|---|---|---|---|
| 0 | Autoriser | TCP | | | established | Les réponses aux connexions du VPS (mises à jour, certificat, téléchargements) |
| 1 | Autoriser | TCP | | 2222 | | SSH |
| 2 | Autoriser | TCP | | 80 | | FastDL, guide et stats pour le jeu, certificat |
| 3 | Autoriser | TCP | | 443 | | Les pages de stats |
| 4 | Autoriser | UDP | | 27015 | | Les joueurs |
| 5 | Autoriser | UDP | 27000-27100 | | | Les réponses de Steam : validation des joueurs, VAC, liste des serveurs |
| 6 | Autoriser | UDP | 53 | | | Les réponses DNS |
| 7 | Autoriser | UDP | 123 | | | Les réponses de l'heure (NTP) |
| 8 | Autoriser | ICMP | | | | Le ping et le traceroute |
| 19 | Refuser | IPv4 | | | | Tout le reste |

Règles 1 à 4 : ports de destination ; 5 à 7 : ports source (des réponses). Il ne remplace pas le pare-feu du VPS : il
ne filtre que ce qui vient de l'extérieur d'OVHcloud, et seulement en IPv4.

## Les admins

SteamID dans `ansible/personal.yml`. Dans la console du jeu : `amxmodmenu` (le menu admin), `amx_who`.
Le rcon (si `vault_rcon` est défini) : `rcon_password <vault_rcon>`, puis `rcon status`.

## Sur le PC

`DOMAIN=localhost docker compose up -d --build` lance tout, mais Docker Desktop (Windows) transmet mal l'UDP : le
client du jeu ne s'y connecte pas. Les essais de jeu se font sur le VPS.
