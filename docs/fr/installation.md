# Installation

English (official): [../installation.md](../installation.md)

Un VPS Debian 13 (écrit pour OVHcloud : son premier compte est `debian`, son mot de passe arrive par courriel),
installé avec Ansible depuis Ubuntu (WSL sous Windows convient). Le serveur tourne dans Docker.

## Composants

| Brique | Rôle | Licence |
|---|---|---|
| [ReHLDS](https://github.com/rehlds/ReHLDS) | Remplace le moteur du serveur dédié (plus sûr, plus rapide) | MIT |
| [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS) | Remplace le code du jeu CS (bugs corrigés, plus de réglages) | MIT |
| [Metamod-R](https://github.com/rehlds/Metamod-R) | Charge les plugins (AMX Mod X, YaPB) | GPL-3.0 |
| [ReAPI](https://github.com/rehlds/ReAPI) | Donne aux plugins d'AMX Mod X l'accès à ReHLDS et ReGameDLL | GPL-3.0 |
| [War3FT](https://github.com/wc3mods/war3ft) | Le mod, en paquet tout-en-un avec AMX Mod X 1.10 | aucune indiquée (AMX Mod X : GPL-3.0) |
| [AMX Mod X](https://www.amxmodx.org) | La plateforme des plugins : le cœur et les modules d'un build 1.10 plus récent, par-dessus ceux de War3FT | GPL-3.0 |
| [ReDeathmatch](https://github.com/ReDeathmatch/ReDeathmatch_AMXX) | Le Respawn : réapparition immédiate, menu des armes, protection à l'apparition | MIT |
| [YaPB](https://github.com/yapb/yapb) | Les bots | Unlicense |
| Voix de l'annonceur (Antti Saari, TripleSnail) | Premier kill, multi-kills, séries : dans `server/sound/announcer/` | CC-BY 3.0 |
| [Caddy](https://caddyserver.com) | Le FastDL, le guide et les pages de stats (HTTP et HTTPS) | Apache-2.0 |
| [PHP](https://www.php.net) | Fait tourner les pages de stats | PHP License |
| [Python](https://www.python.org) | Le relais de l'IA (`ai/relay.py`), bibliothèque standard seulement | PSF |
| [Claude](https://www.anthropic.com/api) (l'API d'Anthropic, optionnel) | Les répliques des bots et le maître du jeu | service payant |
| [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) | Télécharge CS 1.6 au premier démarrage | conditions de Valve |

L'image du jeu télécharge les huit premières au build ; versions et empreintes SHA-256 dans
[server/Dockerfile](../../server/Dockerfile). Caddy, PHP et Python sont leurs propres images Docker
officielles.
CS 1.6 lui-même (la branche `steam_legacy`, la seule que ReHLDS remplace) est téléchargé au premier démarrage, dans
le volume `hlds`. Aucun fichier du jeu de Valve dans le dépôt ni dans l'image (seulement SteamCMD) ; rien de
War3FT dans le dépôt.
Les voix de l'annonceur ([CREDITS.txt](../../server/sound/announcer/CREDITS.txt)) et les images du site de stats
([stats/img/CREDITS.txt](../../stats/img/CREDITS.txt)) sont les seuls fichiers de tiers qu'il contient.

## Tes réglages

Sur ton PC, dans Ubuntu : git et Ansible, puis ce dépôt.

```bash
sudo apt update && sudo apt install git pipx && pipx install --include-deps ansible && pipx ensurepath
git clone https://github.com/pazpop/cs-war3-ai.git
```

Puis ouvre un nouveau terminal (pour les commandes d'Ansible), et `cd cs-war3-ai`.

1. Un nom DNS qui pointe vers le VPS : c'est `domain` dans [ansible/inventory.yml](../../ansible/inventory.yml),
   avec le fuseau horaire du serveur `timezone` (les logs, les classements et le journal le suivent). Les messages
   du chat : [server/messages.txt](../../server/messages.txt). Commite tes changements : `deploy.yml` ne copie que
   les fichiers commités.
2. Une clé SSH pour Ansible (indique-la dans `ansible_ssh_private_key_file`, dans l'inventaire), copiée sur le compte
   de l'hébergeur :
   `ssh-keygen -t ed25519 -f ~/.ssh/<ta clé>`, puis `ssh-copy-id -i ~/.ssh/<ta clé>.pub debian@<domaine>`
3. Copie [ansible/personal.example.yml](../../ansible/personal.example.yml) en `ansible/personal.yml` (ignoré par git)
   et remplis-le : le compte de l'hébergeur, ton compte et sa clé publique (un autre `ssh-keygen`), le dossier des
   sauvegardes, les SteamID des admins.
4. Les collections d'Ansible : `ansible-galaxy collection install -r ansible/requirements.yml`
5. Le coffre, pour les secrets : chiffré, et ignoré par git (il ne quitte jamais ton PC). Garde une copie du
   fichier et de son mot de passe.
   ```bash
   source vault.sh                       # le mot de passe du coffre, gardé 2 h dans ce terminal
   EDITOR=nano ansible-vault create ansible/vault.yml
   ```
   Dedans, optionnel : `vault_anthropic_key: sk-ant-...`, pour l'IA (voir [L'IA](#lia-optionnel)). Un coffre vide
   convient : `{}`.

## Installer le VPS

Depuis la racine du dépôt, après `source vault.sh` :

`init.yml` se connecte sur le port 22 : si l'[Edge Network Firewall](#ledge-network-firewall-dovhcloud-optionnel)
est actif, ajoute d'abord une règle temporaire (priorité 9, Autoriser, TCP, port de destination 22), et supprime-la
après `config.yml`.

```bash
ansible-playbook -i ansible/inventory.yml ansible/init.yml    # une fois : comptes, SSH sur 2222
ansible-playbook -i ansible/inventory.yml ansible/config.yml  # le système : pare-feu, Docker, mises à jour
ansible-playbook -i ansible/inventory.yml ansible/deploy.yml  # le serveur de jeu et la page de stats
```

Le premier démarrage télécharge CS 1.6 : quelques minutes avant que le serveur réponde (`sudo docker logs -f
cs-war3-ai-hlds-1` sur le VPS le montre). `config.yml` et `deploy.yml` se relancent autant qu'on veut (voir [Les mises à jour](#les-mises-à-jour)). `config.yml`
redémarre le VPS quand une mise à jour le demande : lance-le quand personne ne joue.

## Le serveur de jeu

| Action | Commande, sur le VPS (dans `/srv/cs-war3-ai`) |
|---|---|
| Sortie de la console | `sudo docker logs -f cs-war3-ai-hlds-1` (le log du jeu, avec les IP et le chat d'équipe, reste dans `cstrike/logs/` du volume, 14 jours) |
| Console | `sudo docker attach cs-war3-ai-hlds-1` (en sortir : `Ctrl+P` puis `Ctrl+Q` ; `Ctrl+C` redémarre le serveur) |
| Mettre à jour CS 1.6 | `sudo UPDATE=1 docker compose up -d`, puis `sudo docker compose up -d` une fois lancé (sinon chaque redémarrage refait la mise à jour) |
| Revenir aux FPS par défaut de Valve | `sudo TICRATE=100 docker compose up -d` (jusqu'au prochain `deploy.yml`) |

Dans la console : `meta list` (AMX Mod X et YaPB en `RUN`), `amxx plugins` (`war3ft.amxx` en `running`), `stats`.

Réglages : [server/Dockerfile](../../server/Dockerfile) (War3FT, ReDeathmatch, YaPB, AMX Mod X) et
[server/server.cfg](../../server/server.cfg). À chaque démarrage, le script d'entrée ajoute le nom du serveur,
l'adresse du FastDL et le MOTD, à partir de `DOMAIN`. Les cartes : [server/mapcycle.txt](../../server/mapcycle.txt),
reprise en `maps.ini` : les cartes de CS 1.6 les plus aimées que les bots connaissent.

## Nos plugins

Dans [server/plugins/](../../server/plugins/), compilés au build (`common.inc`, `database.inc` et `kills.inc` : le
code que plusieurs partagent ; `kills.inc` reçoit aussi les kills des sorts de War3FT, que le message de mort du jeu
rate) :

- `achievements.sma` : 14 succès (`/ach`), gardés dans la base de War3FT ; les pages des joueurs les affichent. Un
  succès débloqué s'affiche pour tous (`[STATS]`). Le temps de jeu (« Regular ») ne compte qu'en équipe, pas en
  spectateur.
- `afk.sma` : 60 secondes sans toucher une touche ni bouger la souris, et un joueur passe en spectateur.
- `ai.sma` : envoie le chat, les kills entre bots et humains, l'état de la partie à la moitié de chaque carte, les
  arrivées, changements de pseudo et chiffres d'un joueur pour le coach, et les annonces du maître du jeu au relais
  de l'IA, et fait ce qu'il répond (voir [L'IA](#lia-optionnel)). À la fin de chaque carte, une ligne `[STATS]` nomme
  le MVP : le premier du tableau des scores.
- `announcer.sma` : les voix et les messages du premier kill, des multi-kills et des séries. Les joueurs téléchargent
  les voix en HTTP (FastDL).
- `block_debug.sma` : bloque les commandes de débogage `test` et `test2` de War3FT, ouvertes à tous les joueurs
  (elles remplissent les logs).
- `bots.sma` : chaque bot de [server/bots.txt](../../server/bots.txt) joue le plus souvent sa propre race de War3FT,
  porte son propre skin dans chaque équipe, et a un niveau de 1 à 5 à chaque carte (son XP ne s'additionne jamais :
  pas plus fort que les humains). Le nom d'un humain perd les tags que seuls l'IA et les classements donnent
  (`[AI]`, `Game Master`, `[Champion]`, `[#3]`…), et `<` et `>`.
- `csdm_active.sma` : active le mode deathmatch de War3FT (une nouvelle session à chaque réapparition) ;
  ReDeathmatch fait réapparaître les joueurs. Sauvegarde aussi l'XP de tous toutes les 5 minutes : War3FT
  sauvegarde en fin de manche, qui n'arrive jamais ici.
- `damage.sma` : les dégâts que le joueur inflige, sous le viseur, à chaque coup.
- `fresh_start.sma` : quand le premier humain arrive sur un serveur de bots seuls, la partie redémarre
  (`sv_restart`) : tous les scores à zéro, un départ équitable (une fois par carte, pas dans ses 10 dernières minutes).
  L'XP, le classement du mois et les succès restent.
- `help.sma` : `/help` ou `help` dans le chat, ou `help` dans la console, rouvre le guide.
- `high_ping.sma` : un ping au-dessus de 300 ms pendant 50 secondes, et un joueur est expulsé.
- `messages.sma` : un message dans le chat toutes les 5 minutes, à tour de rôle, tiré de
  [server/messages.txt](../../server/messages.txt) : `[HELP]` pour une commande, `[INFO]` pour le reste (ajouter le
  serveur aux favoris). Une minute avant la fin de la carte : la carte suivante.
- `monthly.sma` : le classement du mois (kills - morts, repart de zéro le 1er), sur la page de stats. À chaque
  carte, le top 5 et la place du joueur, sur une ligne ; à sa fin, la carte du joueur (kills, morts, meilleure
  série, headshots) et sa place avant et après (pas après un rtv : la carte change aussitôt). Compte aussi les MVP du mois de chaque humain (premier du
  tableau des scores en fin de carte, bots compris, quand au moins deux humains ont marqué).
- `name_spam.sma` : un humain qui change de pseudo 10 fois en 10 minutes, sur une même carte, est expulsé pour une heure.
- `no_spray.sma` : pas de sprays (la touche T) ; `sv_allowupload 0` cache déjà les images perso ; les bots :
  `yb_spraypaints 0`.
- `rank_tag.sma` : le top 10 affiche sa place dans le chat, `[#3] nom : message` ; le top 3 du mois passé,
  `[Champion]`.
- `rtv.sma` : `rtv` dans le chat ; à 60 % des humains qui jouent (dans une équipe), le vote d'adminvote sur 4 cartes au hasard
  (pas dans les 2 dernières minutes de la carte, quand mapchooser vote).
- `slash_commands.sma` : `/nextmap`, `/currentmap`, `/timeleft`, `/thetime` (AMX Mod X ne les connaît que sans le
  `/`) : toutes les commandes marchent alors avec un `/`.
- `votekick.sma` : un joueur est expulsé quand 60 % des autres humains qui jouent l'ont choisi (3 humains au moins ; les admins
  ne sont pas dans le menu). De nouveau dans la journée : banni 5 minutes, puis 30 (compté par SteamID).
- `web_stats.sma` : pour la page de stats, garde le nom de chaque humain (en SQLite, War3FT ne garde que le SteamID),
  et recopie le top 100 du classement de combat de CS (`/rank`, `/top15`) à chaque début de carte. `/mystats` : le
  lien vers la page du joueur.
- `weekly.sma` : l'objectif de la semaine, le même pour tous, un nouveau chaque lundi (`/goal`) ; son tableau est sur
  la page de stats. Pas de prix.

ReDeathmatch : par équipes, réapparition immédiate dans sa base, pas de manches, les armes avec **G**, 800 $ au
départ (les boutiques de War3 se paient). 3 secondes de protection à la réapparition, perdues au premier tir
(`mp_respawn_immunity*` de ReGameDLL). Dans ce mode, War3FT coupe ce qui fait revenir un joueur ou garde son
équipement : l'équipement gardé de l'Orcish Horde, la résurrection du Blood Mage, l'ultime du Warden, l'ankh et le
scroll. Mapchooser lance un vote en fin de carte (toutes les 20 minutes).
Le plugin `antiflood` d'AMX Mod X bloque le flood dans le chat (un message toutes les 0,75 s au plus :
`amx_flood_time`).

## Les données et la sauvegarde

L'XP est en SQLite, dans le volume : `cstrike/addons/amxmodx/data/sqlite3/war3ft.sq3`. Pas MySQL : le mode MySQL de
War3FT échappe mal les noms des joueurs (injection SQL).

Chaque nuit à 4 h 32 (entre les mises à jour de 4 h et le redémarrage de 5 h), le VPS sauvegarde l'XP, les
classements, les succès et la mémoire de l'IA dans `/srv/backups/cs-war3-ai`, et garde 15 jours (quelques Mo par
archive au plus). Le jeu continue : la sauvegarde propre à SQLite copie les bases pendant qu'elles servent. Le
script :
[ansible/files/backup.sh](../../ansible/files/backup.sh), lancé par la tâche planifiée systemd `cs-war3-ai-backup.timer`.

Pour en faire une tout de suite et la rapatrier sur ton PC (dans `backup_dir`, `ansible/personal.yml`) :

```bash
ansible-playbook -i ansible/inventory.yml ansible/backup.yml
```

Pour restaurer une archive, sur le VPS (le jeu et l'IA s'arrêtent pendant ce temps) : d'abord les journaux SQLite laissés par un
plantage (SQLite les rejouerait sur la base restaurée), puis les données du jeu et la mémoire de l'IA.

```bash
cd /srv/cs-war3-ai
sudo docker compose stop hlds ai
sudo docker run --rm --user 0 --entrypoint sh -v cs-war3-ai_hlds:/data -v cs-war3-ai_ai:/ai cs-war3-ai-hlds -c 'rm -f /data/cstrike/addons/amxmodx/data/sqlite3/*.sq3-* /ai/*.sq3-*'
sudo docker run --rm --user 0 --entrypoint tar -v cs-war3-ai_hlds:/data -v /srv/backups/cs-war3-ai:/in:ro cs-war3-ai-hlds -xzf /in/<archive>.tgz -C /data/cstrike/addons/amxmodx data
sudo docker run --rm --user 0 --entrypoint tar -v cs-war3-ai_ai:/ai -v /srv/backups/cs-war3-ai:/in:ro cs-war3-ai-hlds -xzf /in/<archive>.tgz --no-overwrite-dir -C / ai
sudo docker compose start hlds ai
```

## Le web

- `https://<domaine>` (et `http://`) : le journal du maître du jeu, les classements (du mois et ses MVP, de
  l'objectif de la semaine, XP et combat), le nombre de joueurs (depuis le lancement, 30 et 90 derniers jours)
  ([stats/index.php](../../stats/index.php)),
  et une page par joueur ([stats/player.php](../../stats/player.php)) : XP et niveaux des compétences par race,
  succès, stats de combat. PHP lit la base en lecture seule.
- `https://<domaine>/status.php` : l'état du serveur en ce moment, en JSON (humains, bots, carte, places), pour
  d'autres sites : [pazpop.net](https://pazpop.net) l'affiche. Le jeu est interrogé au plus toutes les 15 secondes.
- `https://<domaine>/bots.php` : les bots, leur race, leur caractère et leur portrait (tirés de
  [server/bots.txt](../../server/bots.txt)). Aussi les dernières répliques des bots et les grandes
  rivalités (le score de chaque bot contre chaque humain), tirées de la base du relais de l'IA (son volume, en lecture
  seule), avec les noms tirés de celle du jeu.
- `http://<domaine>/guide.html` : le guide, affiché à la connexion. Le navigateur du jeu (MOTD) est trop vieux pour
  le HTTPS d'aujourd'hui : en jeu, seules les pages `http://` s'ouvrent.
- `http://<domaine>/cstrike/…` : le FastDL. Le téléchargement par le jeu (UDP) fait planter le client sur les
  fichiers de War3FT. Un Caddy à part le sert, sans aucun certificat, et seulement les fichiers de War3FT et les
  voix de l'annonceur : jamais les configs ni l'XP ([caddy/fastdl.Caddyfile](../../caddy/fastdl.Caddyfile)). La
  façade lui passe `/cstrike/`.

## Les mises à jour

- **Le système** se met à jour tout seul chaque nuit à 4 h, et redémarre à 5 h si une mise à jour le demande.
- **CS 1.6** : voir [Le serveur de jeu](#le-serveur-de-jeu).
- **Caddy, PHP, Python et la base Debian** : lance `deploy.yml` environ une fois par mois : il reconstruit les
  deux images sur des bases à jour, et prend les derniers correctifs de Caddy et PHP.
- **AMX Mod X** : un build 1.10 plus récent que celui de War3FT, vérifié à la main (voir
  [server/Dockerfile](../../server/Dockerfile)).
- **Les mods et les images** (ReHLDS, ReGameDLL, Metamod-R, ReAPI, War3FT, ReDeathmatch, YaPB, Caddy, PHP, Python) :
  [Renovate](https://docs.renovatebot.com) ouvre une « pull request » quand une nouvelle version sort (active
  l'application gratuite Renovate sur le dépôt). Dans cette
  pull request, remplace l'empreinte SHA-256 de la version dans [server/Dockerfile](../../server/Dockerfile) :
  `curl -sL <adresse de l'archive> | sha256sum`. D'ici là, la vérification ci-dessous échoue, exprès.
- **Depuis le PC** (le script du propriétaire : il attend ce dossier nommé `cs-war3-ai`, avec `pazpop.net` à
  côté) : `./deploy-all.sh` pousse ce dépôt et `../pazpop.net` quand ils ont de nouveaux commits, puis
  lance `deploy.yml` (`--all` : tout, même sans nouveau commit).
- **Les vérifications** : chaque push lance [.github/workflows/check.yml](../../.github/workflows/check.yml) :
  `ansible-lint`, `shellcheck`, la syntaxe Python et PHP, les tests Python, et le build des deux images (celle du jeu
  vérifie les SHA-256 et compile nos plugins).

## Le nombre de joueurs

Toutes les 5 minutes, [ansible/files/collect.py](../../ansible/files/collect.py) ajoute une ligne dans
`/srv/collect/players.csv` : heure (celle du VPS, avec son décalage sur UTC), serveur, en ligne, humains, bots,
places, carte. Seulement des nombres et la carte, rien sur les joueurs (environ 15 Ko par jour). Pour le
télécharger :

```bash
scp -P 2222 -i ~/.ssh/<ta clé> deploy@<domaine>:/srv/collect/players.csv .
```

## Les rapports du chat

Chaque nuit à 0 h 30, [ansible/files/chat_report.py](../../ansible/files/chat_report.py) écrit le chat de la
veille (à l'heure du VPS, comme les logs du jeu) dans `/srv/collect/chat/<date>.txt`, à partir des logs du jeu (gardés 14 jours) : les humains (le chat
d'équipe signalé), les bots, le maître du jeu et le coach, avec les arrivées et les départs. Seulement les noms, ni
SteamID ni IP ; lisible par root seulement, gardé 90 jours. Un jour sans rien de tout ça n'écrit rien. Pour un autre
jour :
`sudo cs-war3-ai-chat-report 2026-10-26`.

## L'IA (optionnel)

Des bots qui répondent, et un maître du jeu. `ai.sma` envoie les nouvelles de la partie au relais
([ai/relay.py](../../ai/relay.py), son propre conteneur), qui demande à Claude (Claude Haiku 5.5) et répond par
des actions :

- **Les bots parlent** : un bot répond quand un joueur le nomme dans le chat (parfois même sans ça), et de temps
  en temps après un kill entre un bot et un humain ; l'un d'eux salue chaque humain qui arrive. Jamais de bot à
  bot. Chaque bot de [server/bots.txt](../../server/bots.txt) a sa race et son caractère, les mêmes pour YaPB,
  le jeu, le relais et la page de stats, et s'affiche `[AI] Zed` dans le tableau des scores. Les bots se souviennent
  de chaque humain (par SteamID, dans le volume du relais) : depuis quand il joue, la dernière carte jouée ensemble,
  comment il s'en sort contre eux, et le score de chaque bot contre lui ; aussi l'entrée du journal d'hier, pour en
  parler. Un bot tué 5 fois par un joueur, plus qu'il ne l'a tué, le voit comme son rival, et le salue en
  premier. Les bots ne se moquent jamais des joueurs : leur prompt l'interdit, et le modérateur refuse une telle
  réplique.
- **Les questions** : un message avec un `?` reçoit en général la réponse d'un bot, qui a le guide des joueurs
  ([stats/guide.html](../../stats/guide.html), en texte, environ 2 000 tokens) sous les yeux ; un nouveau reçoit un conseil tiré du guide
  avec le bonjour.
- **Le coach** : `/coach` envoie les chiffres du joueur sur cette carte (CSX : kills, morts, headshots, touches et
  où, précision de chaque arme, morts d'affilée, l'arme qui l'a le plus tué) et reçoit un conseil, en privé, un par
  minute au plus. `/coach <question>` : la réponse à une question sur ces chiffres, jamais affichée dans le chat.
  `/coach on` : un conseil toutes les 5 minutes, gardé par SteamID dans le relais jusqu'à `/coach off`. 60 secondes
  avant la fin de la carte, chaque humain qui a joué reçoit un bilan : un point fort, une chose à travailler (et,
  sans `/coach on`, un mot pour le dire).
- **Le maître du jeu** : à la moitié de chaque carte (10 minutes), il lit le score et peut lancer un événement : une prime sur un
  joueur très en avance, un duel entre deux joueurs, un défi (kills, headshots ou kills au couteau,
  en 2 minutes), un boss (un bot à 500 points de vie, entouré d'un halo rouge), 30 secondes de gravité basse, de
  l'argent pour tous, 100 XP de War3FT pour chaque humain (`changexp`), un objet des boutiques de War3FT pour tous
  (`wc3_giveitem`). Le prix d'une prime, d'un duel, d'un défi ou d'un boss vaut 3000 $ et 200 XP, et personne
  n'est obligé de participer. Il ne choisit que dans
  cette liste, et jamais deux fois de suite le même événement ; le plugin vérifie chaque événement et le lance
  lui-même.
- **Le journal** : chaque nuit, le relais écrit l'entrée de la veille (3 à 5 phrases) à partir des annonces du
  maître du jeu et des répliques des bots, jamais de ce qu'écrivent les joueurs ; la page d'accueil montre les 3
  derniers jours.

Ce que l'IA peut dire : un prompt système strict, puis un modérateur (une seconde requête) vérifie chaque ligne
avant qu'elle s'affiche : pas d'injure, de haine, de contenu sexuel, de menace, d'activité illégale, de
politique ni d'information personnelle, dans aucune langue, ni un pseudo injurieux répété. Le pseudo de chaque
humain est vérifié aussi, à l'arrivée et à chaque changement : un pseudo injurieux est renommé « Player » (sans
réponse, faute de clé ou de budget, un pseudo passe et sera revérifié plus tard ; au-delà de 5 nouveaux pseudos
en une heure, les suivants d'un joueur sont refusés sans demander). Au moindre doute ou à la moindre erreur, aucune
réplique ne s'affiche. Un bot répond au même joueur au plus toutes les 10 secondes et 30 fois par heure, et parle de
la mort d'un même joueur au plus toutes les 2 minutes ; un joueur dont les messages font refuser 3 répliques en une
heure est ignoré pendant une heure. Le maître du jeu ne met une prime que sur le meneur, et ne reprend pas un humain
de ses derniers événements. En jeu, l'IA s'affiche `[AI] Zed`, `[AI Game Master]` et
`[AI Coach]` : les joueurs savent qu'ils parlent à une IA (Anthropic l'exige).

Mise en place : une clé API de [console.anthropic.com](https://console.anthropic.com) dans le coffre
(`vault_anthropic_key: sk-ant-...`), puis `deploy.yml`. Sans clé, le relais se tait et le jeu ne change pas. Il
dépense au plus `AI_DAILY_USD` par jour (1 $ par défaut, dans `compose.yml` ; `0` coupe l'IA), et au plus 1/8 de
cette somme en une heure, puis se tait ; mets aussi une limite mensuelle dans la console d'Anthropic.

Ce qui sort du VPS : les messages du chat public (jamais le chat d'équipe), les noms, le score, l'historique de
chaque humain contre les bots (depuis quand et quand il a joué la dernière fois, sa dernière carte, ses kills et ses
morts contre eux), les chiffres et les questions de chaque joueur pour le coach, et pour le journal les annonces et
les répliques des bots du jour. Jamais les SteamID ni les IP. La mémoire des bots oublie un joueur qu'elle n'a pas vu
depuis 180 jours ; l'histoire du jour part 2 jours après ; le journal garde ses 30 dernières entrées, la page de stats
les 200 dernières répliques des bots (30 jours au plus), la vérification des pseudos ses réponses 30 jours. Le guide le dit aux
joueurs.

Ses logs, sur le VPS : `cd /srv/cs-war3-ai && sudo docker compose logs ai`.

## Le monitoring (optionnel)

[Healthchecks.io](https://healthchecks.io) (gratuit, libre) te prévient quand un ping n'arrive pas à temps, même
si le VPS est tombé.

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
pendant une attaque DDoS. Espace client : Network > Public IP Addresses > `⁝` à
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
| 7 | Autoriser | UDP | 123 | | | Les réponses NTP (l'heure) |
| 8 | Autoriser | ICMP | | | | Le ping et le traceroute |
| 19 | Refuser | IPv4 | | | | Tout le reste |

Règles 1 à 4 : ports de destination ; 5 à 7 : ports source (des réponses). Il ne remplace pas le pare-feu du VPS : il
ne filtre que ce qui vient de l'extérieur d'OVHcloud, et seulement en IPv4.

## Les admins

SteamID dans `ansible/personal.yml`. Dans la console du jeu : `amxmodmenu` (le menu admin), `amx_who`.
Pas de rcon (son mot de passe traverserait Internet en clair) : la console du serveur, c'est `docker attach` (voir
plus haut).

Pour retirer le pseudo d'un joueur du site de stats (sur demande, avec son SteamID), sur le VPS :

```bash
sudo docker run --rm -v cs-war3-ai_hlds:/h python:3.13-alpine python -c "import sqlite3, sys; db = sqlite3.connect('/h/cstrike/addons/amxmodx/data/sqlite3/war3ft.sq3'); db.execute(\"UPDATE cs_war3_ai_names SET name = 'Player' WHERE steamid = ?\", (sys.argv[1],)); db.commit()" STEAM_0:1:123456
```

Ses stats restent, sous « Player » ; s'il revient, son nouveau pseudo s'affiche. Les répliques des bots et les
entrées du journal qui le nomment restent jusqu'à ce que de plus récentes les poussent dehors (les 200 dernières
répliques, 30 jours au plus ; les 30 dernières entrées).

## Sur le PC

`DOMAIN=localhost docker compose up -d --build` lance tout, mais Docker Desktop (Windows) transmet mal l'UDP : le
client du jeu ne s'y connecte pas. Les essais de jeu se font sur le VPS.
