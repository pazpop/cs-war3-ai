# Le guide des joueurs

English (official), the page the game shows: [stats/guide.html](../../stats/guide.html), online at
[cs.pazpop.net/guide.html](https://cs.pazpop.net/guide.html).

Counter-Strike 1.6, avec les races et les sorts de Warcraft 3 : Frozen Throne (le mod War3FT).

- Tu choisis une **race** : 3 compétences et un **ultime** (certaines ont aussi une compétence passive).
- Tu gagnes de l'**XP**, surtout en tuant. Chaque niveau donne un point pour une compétence (`/selectskill`) ;
  l'ultime se débloque au niveau 6.
- **Ton XP est gardée**, race par race, sous ton SteamID : tu la retrouves la fois suivante.
- Avec ton argent de CS, tu achètes des **objets** dans deux boutiques.

## Le règlement

- **13 ans ou plus**, comme sur Steam.
- **Le respect** : chambrer sur le jeu, oui. Insultes, menaces et harcèlement, non.
- **Pas de haine** : ni racisme, ni sexisme, ni homophobie, ni insulte de ce genre, dans aucune langue, ni dans le
  chat ni dans ton pseudo.
- **Rien de sexuel ni d'illégal**, et aucune information personnelle, ni la tienne ni celle d'un autre.
- **Pas de triche** : ni hack, ni script, ni bug utilisé exprès.
- **Pas de spam**, ni de pub pour d'autres serveurs. Changer de pseudo 10 fois en 10 minutes te fait expulser pour
  une heure.
- Absent **60 secondes** (aucune touche, souris immobile) : tu passes en spectateur. Un ping au-dessus de
  **300 ms** pendant 50 secondes te fait expulser.

Les mêmes règles valent dans le chat d'équipe. Si tu les enfreins, les joueurs peuvent t'expulser 10 minutes
(`/votekick`), ou un admin peut t'expulser ou te bannir.

## Pour commencer

Choisis une race dans le premier menu. Puis, dans le chat :

| Commande | Rôle |
|---|---|
| `/help` | Ce guide à nouveau (ou `help` dans la console) |
| `/changerace` | Changer de race (à ta prochaine réapparition) |
| `/war3menu` | Le menu principal |
| `/selectskill` | Choisir tes compétences |
| `/skillsinfo` | Ce que font les compétences de ta race |
| `/level` | Ta race, ton niveau, tes compétences |
| `/playerskills` | Les compétences des autres joueurs |
| `/shopmenu`, `/shopmenu2` | Acheter des objets |
| `/itemsinfo`, `/itemsinfo2` | Ce que font les objets |
| `/war3help` | L'aide de War3FT |
| `/rtv` | Demander une nouvelle carte (vote à 60 % des humains) |
| `/votekick` | Voter pour exclure un joueur 10 minutes : à 60 % des autres humains (3 humains au moins) |
| `/rank`, `/top15` | Ton rang au combat, le top 15 (le top 10 affiche sa place dans le chat) |
| `/ach` | Tes succès : 14 objectifs, de ton premier kill jusqu'à 10 000 |
| `/mystats` | Le lien vers ta page sur le site de stats |
| `/coach` | Un conseil du coach IA, tiré de tes chiffres sur cette carte, en privé ; ou pose-lui une question : `/coach what is my best weapon?` `/coach on` : un conseil toutes les 5 minutes (`/coach off` pour arrêter). |
| `/goal` | L'objectif de la semaine, le même pour tous, et ton compte |
| `/statsme`, `/rankstats` | Tes stats sur cette carte, tes stats au total |
| `/nextmap`, `/timeleft` | La carte suivante, le temps restant |

## Les touches à lier

Dans la console :

```
bind "mouse3" "ultimate"
bind "alt" "ability"
bind "-" "shopmenu"
bind "=" "shopmenu2"
bind "F3" "war3menu"
```

L'ultime, la compétence active (le Serpent Ward du Shadow Hunter), les deux boutiques et le menu de War3FT (race,
compétences, boutiques, aide). Pour les garder à chaque lancement : [client.md](client.md).

## Les races

| Race | Compétences | Ultime |
|---|---|---|
| Undead Scourge | Vol de vie, vitesse, saut plus haut | Explose à sa mort |
| Human Alliance | Invisibilité, plus de vie, étourdit | Téléportation |
| Orcish Horde | Coups critiques, grenades puissantes, garde son équipement | Éclair en chaîne |
| Night Elves | Esquive, renvoie les dégâts, plus de dégâts | Immobilise un ennemi |
| Blood Mage | Ranime un coéquipier, bannit, vole de l'argent | Enflamme un ennemi |
| Shadow Hunter | Soins de groupe, transforme en animal, totem qui tire | Invincible 2 secondes |
| Warden | Peut apparaître en taupe chez l'ennemi, bloque les ultimes ennemis, dague empoisonnée | Revient une fois |
| Crypt Lord | Empale, carapace à épines, scarabées | Nuée de criquets |

Le détail exact (pourcentages, durées) : `/skillsinfo` en jeu.

Ici, tout le monde revient aussitôt. Ce qui fait revenir ou garde l'équipement ne sert donc à rien : l'équipement
gardé de l'Orcish Horde, la résurrection du Blood Mage, l'ultime du Warden, l'ankh et le scroll.

## Les objets

- **Boutique 1** : ankh de réincarnation, bottes de vitesse, griffes d'attaque, cape d'ombre, masque de mort,
  collier d'immunité, orbe de givre, périapte de vie, tome d'expérience.
- **Boutique 2** : parchemin de réapparition, protection anti-taupe, heaume d'excellence, amulette du chat,
  chaussette de plume, gants enflammés, anneau de régénération, caméléon, taupe.

Ce que fait chacun : `/itemsinfo` et `/itemsinfo2`.

## Sur ce serveur

**Le jeu**
- **Respawn** : tu réapparais tout de suite dans ta base. Pas de manches, pas de bombe.
- **G** : le menu des armes.
- **3 secondes de protection** à chaque réapparition, jusqu'à ce que tu tires.
- **800 $** au départ, et plus à chaque kill, pour les boutiques.
- Toutes les 20 minutes, un **vote** choisit la carte suivante.

**Ta progression**
- Les niveaux viennent **deux fois plus vite** (moitié moins d'XP par niveau). Une race jamais jouée commence au
  niveau 3.
- Tes **dégâts** s'affichent sous le viseur. Un annonceur pour le premier kill et les séries.
- À chaque carte : le **top 5** du mois et ta place. Tes succès : `/ach`.
- L'**objectif de la semaine**, le même pour tous, un nouveau chaque lundi : `/goal`, et son tableau sur le site de
  stats.
- **/coach** : un conseil du coach IA, en privé. `/coach on` : un toutes les 5 minutes (`/coach off` pour arrêter).
  Vers la fin de chaque carte, tu reçois un bilan.
- Le top 10 affiche sa place dans le chat ; le top 3 du mois passé, l'étiquette **[Champion]**.
- Dans le chat : **[HELP]** une commande, **[INFO]** le serveur, **[STATS]** le top 5 du mois à chaque début de
  carte, le MVP de la carte à sa fin, un succès débloqué, l'objectif de la semaine atteint.

**Les bots**
- Ils remplissent le serveur jusqu'à 10 joueurs ; un bot sort quand un humain arrive. Leur niveau : de moyen à
  normal.
- **Ils répondent** (**[AI]** dans leur nom) : écris le nom d'un bot dans le chat, comme *zed, nice shot*. Chacun
  a son caractère et sa race de War3FT. Ils se souviennent de toi, de la dernière carte jouée ensemble et de ce qui
  s'est passé hier sur le serveur : tue-en un souvent, et il te voit comme son rival. Ils ne se moquent jamais de
  toi. Les grandes rivalités sont sur la page des bots.
- Les bots sont de niveau 1 à 5, nouveau à chaque carte : ton XP est à toi, la leur ne s'accumule jamais.
- **Pose-leur une question** sur le jeu : un message avec un **?** reçoit en général une réponse, comme
  *which race is good for a beginner?*
- Arrive sur un serveur de bots seuls, et la partie **redémarre** : les scores de la carte repartent de zéro (l'XP
  et les classements restent).

## Le maître du jeu

Une IA suit le score. À la moitié de chaque carte, elle peut lancer un de ces événements, annoncé dans le chat et à
l'écran. Rien n'est obligatoire : joue comme tu veux, les prix sont un bonus. Elle ne choisit jamais deux fois de
suite le même joueur.

| Événement | Ce qui se passe |
|---|---|
| Prime | Le joueur en tête a sa tête mise à prix : le prix pour qui le tue, pendant 3 minutes. |
| Duel | Deux joueurs d'équipes opposées : le premier qui tue l'autre gagne le prix, en 3 minutes. |
| Défi | Un objectif pour chaque humain, en 2 minutes : des kills, des headshots ou des kills au couteau. Le premier qui l'atteint gagne le prix. Ton compte s'affiche dans le chat. |
| Boss | Un bot brille en rouge, avec 500 points de vie : qui l'abat gagne le prix. Après 3 minutes, il redevient un bot normal. |
| Gravité basse | 30 secondes de sauts immenses pour tout le monde. |
| Pluie d'or | **1500 $** pour chaque joueur. |
| Pluie d'XP | **100 XP** pour chaque humain, pour la race jouée. |
| Cadeau | Un objet des boutiques de War3FT pour tous : bottes, griffes, cape, anneau… |

Le prix : **3000 $ et 200 XP**, gardés avec ta race comme le reste de ton XP. Chaque nuit, le maître du jeu écrit le
journal du serveur sur le site de stats. À la fin de chaque carte, une ligne **[STATS]** nomme le **MVP** de la carte
(compté sur le site de stats quand au moins deux humains ont marqué).

## Ce qui est public, et l'IA

Public sur le site, tant que le serveur tourne : ton pseudo, ton XP, tes compétences, tes stats, tes succès (avec
leur date) et tes classements, gardés sous ton SteamID (c'est ainsi que ta progression est sauvée) ; tes rivalités
avec les bots, jusqu'à ce qu'ils t'oublient ; une réplique de bot (avec son heure, 30 jours au plus) ou le journal
peuvent aussi te nommer. Pour faire retirer ton pseudo : demande à un admin en jeu, ou ouvre une issue sur
github.com/pazpop/cs-war3-ai. Les logs du serveur (avec ton IP) partent après 14 jours, le journal du chat (chat
d'équipe et conseils du coach compris) après 3 mois.

Les bots, le coach et le maître du jeu sont une IA : Claude, d'Anthropic, qui garde ce qu'il reçoit selon sa propre
politique. Ce qui lui est envoyé : tes messages publics, ton pseudo, ton score et comment tu t'en sors contre les bots
(depuis quand et quand tu as joué ici pour la dernière fois, ta dernière carte, tes kills et tes morts contre eux), et
pour le coach tes chiffres sur la carte et ta question. Jamais ton SteamID ni ton IP. La mémoire que les bots ont de
toi reste sur ce serveur et part après 6 mois sans visite (les sauvegardes la gardent un peu plus). Avant qu'une
réplique s'affiche, un second contrôle par l'IA retient ce qu'il trouve offensant ; il vérifie aussi les pseudos, et
un pseudo offensant devient « Player ».

## Plus

- Les classements et les stats des joueurs : [cs.pazpop.net](https://cs.pazpop.net) ; les bots :
  [cs.pazpop.net/bots.php](https://cs.pazpop.net/bots.php).
- La configuration optimisée du jeu : [client.md](client.md).
- Le code du serveur : [github.com/pazpop/cs-war3-ai](https://github.com/pazpop/cs-war3-ai).
