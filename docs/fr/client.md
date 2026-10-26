# Bien régler son jeu

English (official): [../client.md](../client.md)

Pour jouer sur `cs.pazpop.net` sans lag ni saccade, avec les touches de War3FT sous la main.

## La config

Crée le fichier `Half-Life/cstrike/userconfig.cfg` avec ceci :

```
// Réseau : le serveur accepte 100000 de débit et 100 mises à jour par seconde.
rate 100000
cl_updaterate 101
cl_cmdrate 101
ex_interp 0.1
cl_dlmax 1024
// Affichage et souris.
gl_vsync 0
fps_max 100
m_rawinput 1
m_filter 0
// War3FT : ton ultime, le Serpent Ward (Shadow Hunter), les deux boutiques, le menu War3FT.
bind "mouse3" "ultimate"
bind "alt" "ability"
bind "-" "shopmenu"
bind "=" "shopmenu2"
bind "F3" "war3menu"
```

Le jeu le lit à chaque lancement, après `config.cfg`. Pour revenir en arrière : supprime le fichier. Une touche que
tu utilises déjà pour autre chose : change-la dans le fichier. Sur un serveur sans War3FT, ces touches ne font rien.

Joue en **plein écran** (Options → Vidéo). En fenêtré, Windows ajoute sa propre synchronisation et le jeu saccade.

## Pourquoi

| Réglage | Valeur | Pourquoi |
|---|---|---|
| `rate` | 100000 | Le débit maximal. Le serveur le permet : le débit retenu est le plus petit des deux. |
| `cl_updaterate` | 101 | Tu reçois les 100 mises à jour par seconde du serveur. |
| `cl_cmdrate` | 101 | Tu envoies 100 commandes par seconde. |
| `ex_interp` | 0.1 | Le lissage des mouvements. Les guides disent 0.01, mais ici les bots saccadent. Les tirs n'en souffrent pas : le serveur compense ce délai. |
| `cl_dlmax` | 1024 | De plus gros paquets pour les téléchargements. |
| `gl_vsync` | 0 | Sans synchronisation verticale : une image en retard n'attend pas la suivante (micro-freezes). |
| `fps_max` | 100 | Le moteur a été pensé pour 100 FPS. Au-dessus, les déplacements changent un peu. |
| `m_rawinput` | 1 | La souris ignore l'accélération de Windows. |
| `m_filter` | 0 | Pas de lissage de la souris. |
| `bind` | War3FT | Les mêmes touches que dans le [guide des joueurs](guide.md). Le menu War3FT change aussi ta race et tes compétences. |

Avec une connexion faible (ping élevé, pertes) : `cl_updaterate 60`.

## Vérifier

- Dans la console : `rate` doit répondre `100000`. Sinon, tape `exec userconfig.cfg`.
- En jeu : `net_graph 3`. Environ 100 FPS, et ni `loss` ni `choke`.
- Sans vsync, l'image peut se couper en deux (« tearing »). Si ça gêne : `gl_vsync 1`.

## Sources

- [cs-16.org : meilleurs réglages](https://cs-16.org/best-cs-1-6-settings/)
- [counter-strike-boost : rate, updaterate et cmdrate](https://counter-strike-boost.com/tutorials/cs16-best-client-rates)
- [csdownload.net : ex_interp](https://csdownload.net/cs-16-ex-interp-settings/)
- [Steam Community : configuration de CS 1.6](https://steamcommunity.com/sharedfiles/filedetails/?id=1170350530)
