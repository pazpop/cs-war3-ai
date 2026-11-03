# Décisions

English (official): [../decisions.md](../decisions.md)

Les choix derrière ce dépôt, et pourquoi. On n'en change que sur un fait nouveau.

- Pas d'OpenTofu : le VPS a été commandé à la main, Ansible fait tout le reste.
- Le VPS : `cs.pazpop.net` (`domain` dans `ansible/inventory.yml`), Debian 13.
- Un seul VPS pour tout, dans Docker : HLDS, Caddy (stats et guide en HTTP et HTTPS), un second Caddy pour FastDL,
  PHP.
- `stats/status.php` : l'état en direct en JSON (A2S_INFO, cache de 15 s, CORS ouvert), lu par `servers.js` de
  pazpop.net.
- Un seul serveur de jeu, sur tout le VPS : la qualité plutôt que la quantité.
- Notre propre « LinuxGSM » : `server/` (image + entrypoint) télécharge CS 1.6 et les mods sur le serveur.
- L'XP en SQLite, pas en MySQL : en mode MySQL, War3FT échappe mal les noms (injection SQL). Notre page de stats
  (`stats/`) lit la base en lecture seule ; la page de War3FT n'est pas utilisée (XSS, pas de licence).
- Nos plugins AMX Mod X sont dans `server/plugins/`, compilés à la construction ; ce que plusieurs partagent est dans
  `common.inc` et `database.inc`.
- Le mode Respawn (la variante de War3 la plus jouée) : ReDeathmatch par équipes, avec 800 $ au départ (boutiques de
  War3) et les points d'apparition des bases (les siens ne couvrent que 3 de nos cartes). `csdm_active.sma` active le
  mode deathmatch de War3FT.
- Le classement du mois (`server/plugins/monthly.sma`, table `cs_war3_ai_monthly`) : une ligne par mois et par joueur,
  donc il repart de zéro le 1er sans aucune tâche de remise à zéro.
- L'IA (des bots qui répondent, un maître du jeu, un coach avec `/coach`) : `server/plugins/ai.sma` envoie les
  nouvelles de la partie à `ai/relay.py` (son propre conteneur, la bibliothèque standard de Python seulement, du HTTP
  brut vers l'API Messages), qui interroge Claude Haiku 5.5 et répond par des actions que le plugin vérifie et lance
  lui-même (une liste fixe d'événements, jamais de commande libre). Une seconde requête (le modérateur) vérifie chaque
  ligne avant affichage ; au moindre doute ou à la moindre erreur, rien n'est affiché. Le relais a une adresse fixe
  sur le réseau interne `ai` (pas de résolution de nom : elle peut bloquer le jeu) et un budget par jour
  (`AI_DAILY_USD`, au plus 1/8 par heure). Aucun SteamID ni aucune IP ne part vers l'API. Sans clé : silence. L'image
  du relais contient aussi stats/guide.html, le guide des joueurs (les bots répondent aux questions à partir de lui) ;
  la page de stats lit sa base en lecture seule (les dernières lignes des bots, le journal qu'il écrit chaque nuit à
  partir des annonces du maître du jeu et des lignes des bots). En jeu, l'IA s'affiche `[AI] <bot>`,
  `[AI Game Master]`, `[AI Coach]` (Anthropic exige de le signaler). Le nom de chaque humain est vérifié à l'arrivée
  et à chaque changement (`NAME_CHECK` ; la réponse est gardée 30 jours dans la table `names` du relais ; le dernier
  dixième du budget du jour lui est réservé) : un nom injurieux fait renommer le joueur « Player » par le plugin, une
  seconde après l'arrivée ou le changement. Sans réponse (pas de clé, API en panne), un nom passe jusqu'à la
  vérification suivante. Un joueur dont 3 messages sont retenus en une heure est ignoré pendant une heure
  (`REFUSALS`, `MUTE`). `/coach on` est gardé par SteamID dans le relais (`coach_on`).
- Les étiquettes du chat : `[HELP]` une commande et `[INFO]` le serveur (messages.sma), `[STATS]` les chiffres
  (top 5, MVP, succès, objectif atteint) ; les lignes de l'IA gardent « AI » dans leur étiquette.
- L'objectif de la semaine (`server/plugins/weekly.sma`) : une semaine se reconnaît à la date de son lundi ; l'objectif,
  au nombre de semaines depuis un jour fixe ; écrit dans la base pour la page de stats par la première carte de la
  semaine ; pas de prix.
- Les kills : War3FT tue avec ses sorts par un avis de mort que les autres plugins ne voient jamais, et les signale par
  son forward `wc3_reportkill`. `server/plugins/kills.inc` donne à nos plugins un seul `on_kill()` pour les deux, chaque
  kill une seule fois.
- Un rapport quotidien du chat (humains, bots, maître du jeu, coach) va dans `/srv/collect/chat/`
  (ansible/files/chat_report.py, à partir des journaux du jeu ; ai.sma journalise les lignes des bots comme des lignes
  de chat).
- Les conteneurs abandonnent toutes leurs capacités (`x-hardening` dans `compose.yml`). Le coffre est ignoré par git.
- Des vérifications tournent à chaque push (`.github/workflows/check.yml`) ; Renovate propose les mises à jour des mods
  (SHA-256 à la main).
- Chaque nuit : nettoyage de Docker à 3 h 30 (config.yml), mises à jour à 4 h, sauvegarde à 4 h 32
  (`ansible/files/backup.sh`, 15 jours gardés), redémarrage à 5 h si besoin.
- Deux pare-feu : ufw sur le VPS, et l'Edge Network Firewall d'OVHcloud (règles dans docs/installation.md).
- Des pings Healthchecks.io facultatifs (sauvegarde, et `ansible/files/heartbeat.py` toutes les 5 minutes) ; les
  adresses sont dans le coffre.
