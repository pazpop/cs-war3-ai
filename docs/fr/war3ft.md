# War3FT : comment ça marche

English (official): [../war3ft.md](../war3ft.md)

Counter-Strike 1.6, avec les races et les sorts de Warcraft 3 : Frozen Throne. Un plugin AMX Mod X
([wc3mods/war3ft](https://github.com/wc3mods/war3ft)).

En jeu, le guide s'affiche à la connexion (le MOTD) : [cs.pazpop.net/guide.html](https://cs.pazpop.net/guide.html).

## Le principe

- Tu choisis une **race**. Chacune a 3 compétences et un **ultime** (certaines ont aussi une compétence passive).
- Tu gagnes de l'**XP**, surtout en tuant. L'XP fait monter ton **niveau**.
- Chaque niveau donne un point à placer dans une compétence (`/selectskill`). L'ultime se débloque plus tard.
- L'XP est gardée **par race** et **par SteamID** : tu la retrouves à ta prochaine connexion.
- Avec ton argent de CS, tu achètes aussi des **objets** dans deux boutiques.

## Les commandes (dans le chat)

Toutes les commandes marchent avec un `/` devant.

| Commande | Rôle |
|---|---|
| `/help` | Rouvre ce guide (ou `help` dans la console) |
| `/changerace` | Changer de race (à ta prochaine réapparition) |
| `/war3menu` | Le menu principal |
| `/selectskill` | Placer tes points de compétence |
| `/skillsinfo` | Ce que font les compétences de ta race |
| `/level` | Ta race, ton niveau, tes compétences |
| `/playerskills` | Les compétences des autres joueurs |
| `/shopmenu`, `/shopmenu2` | Les boutiques d'objets |
| `/itemsinfo`, `/itemsinfo2` | Ce que font les objets |
| `/war3help` | L'aide |
| `/rtv` | Demander une nouvelle carte (vote à 60 % des humains) |
| `/votekick` | Voter pour exclure un joueur 10 minutes : à 60 % des autres humains (3 humains au moins) |
| `/rank`, `/top15` | Ton rang au combat, le top 15 (le top 10 affiche sa place dans le chat) |
| `/ach` | Tes succès : 14 objectifs, de ton premier kill jusqu'à 10 000 |
| `/mystats` | Le lien vers ta page sur le site de stats |
| `/coach` | Un conseil du coach IA, tiré de tes chiffres sur cette carte, en privé |
| `/statsme`, `/rankstats` | Tes stats sur cette carte, tes stats au total |
| `/nextmap`, `/timeleft` | La carte suivante, le temps restant |

## Les touches à lier (dans la console)

```
bind "mouse3" "ultimate"
bind "alt" "ability"
bind "-" "shopmenu"
bind "=" "shopmenu2"
```

`ability` sert au Serpent Ward du Shadow Hunter.

## Les races

| Race | Compétences | Ultime |
|---|---|---|
| Undead Scourge | Vol de vie, vitesse, saut plus haut | Explose à sa mort |
| Human Alliance | Invisibilité, plus de vie, étourdit | Téléportation |
| Orcish Horde | Coups critiques, grenades puissantes, garde son équipement | Éclair en chaîne |
| Night Elf | Esquive, renvoie les dégâts, plus de dégâts | Immobilise un ennemi |
| Blood Mage | Ranime un coéquipier, bannit, vole de l'argent | Enflamme un ennemi |
| Shadow Hunter | Soins de groupe, transforme en animal, totem qui tire | Invincible 2 secondes |
| Warden | Peut apparaître en taupe chez l'ennemi, bloque les ultimes ennemis, dague empoisonnée | Revient une fois |
| Crypt Lord | Empale, carapace à épines, scarabées | Nuée de criquets |

Le détail exact (pourcentages, durées) : `/skillsinfo` en jeu.

## Les objets

- **Boutique 1** : ankh de réincarnation, bottes de vitesse, griffes d'attaque, cape d'ombre, masque de mort,
  collier d'immunité, orbe de givre, périapte de vie, tome d'expérience.
- **Boutique 2** : parchemin de réapparition, protection anti-taupe, heaume d'excellence, amulette du chat,
  chaussette de plume, gants enflammés, anneau de régénération, caméléon, taupe.

Ce que fait chacun : `/itemsinfo` et `/itemsinfo2` en jeu.

## Sur ce serveur

- **Respawn** : tu réapparais tout de suite dans ta base. Pas de manches, pas de bombe. **G** ouvre le menu des armes.
  3 secondes de protection à chaque réapparition, perdues dès que tu tires.
- **L'argent** : 800 $ au départ, et plus à chaque kill, pour les objets des boutiques.
- **Des niveaux plus rapides** : moitié moins d'XP par niveau, l'ultime (niveau 6) arrive deux fois plus vite.
  Une race jamais jouée commence au niveau 3.
- Des **bots** (YaPB) remplissent le serveur jusqu'à 10 joueurs. Un bot sort quand un humain arrive. Leur adresse
  est variée, de moyenne à bonne, comme de vrais joueurs. Chaque bot a sa propre race de War3FT, et un niveau War3FT
  de 1 à 5, nouveau à chaque carte.
- **L'IA** : les bots (`[AI] Zed`…) répondent quand tu écris leur nom dans le chat, répondent à toute question avec un
  `?`, chacun avec son caractère, et se souviennent de toi : tue-en un souvent, et il te garde rancune. Un maître du jeu lance des primes, des duels et d'autres surprises.
- Le premier humain qui arrive sur un serveur de bots seuls relance la partie : tout le monde repart de zéro.
- Toutes les 30 minutes, un vote choisit la carte suivante.
- Un annonceur pour le premier kill, les multi-kills et les séries, jusqu'à GODLIKE.
- Absent **60 secondes** (aucune touche, souris immobile) : tu passes en spectateur. Un ping au-dessus de
  **300 ms** pendant 50 secondes te fait expulser.
- Les classements (du mois, XP et combat) et une page par joueur : [cs.pazpop.net](https://cs.pazpop.net).
- Bien régler son jeu : [client.md](client.md).
