# Client settings

Français : [fr/client.md](fr/client.md)

How to play on `cs.pazpop.net` without lag or stutter, with War3FT's keys at hand.

## The config

Create `Half-Life/cstrike/userconfig.cfg` with:

```
// Network: the server allows a rate of 100000 and 100 updates per second.
rate 100000
cl_updaterate 101
cl_cmdrate 101
ex_interp 0.1
cl_dlmax 1024
// Display and mouse.
gl_vsync 0
fps_max 100
m_rawinput 1
m_filter 0
// War3FT: your ultimate, the Serpent Ward (Shadow Hunter), the two shops, the War3FT menu.
bind "mouse3" "ultimate"
bind "alt" "ability"
bind "-" "shopmenu"
bind "=" "shopmenu2"
bind "F3" "war3menu"
```

The game reads it at every launch, after `config.cfg`. To undo: delete the file. A key you already use for
something else: change it in the file. On a server without War3FT, these keys do nothing.

Play in **fullscreen** (Options → Video). In windowed mode, Windows adds its own sync and the game stutters.

## Why

| Setting | Value | Why |
|---|---|---|
| `rate` | 100000 | Maximum bandwidth. The server allows it: the lower of the two values is used. |
| `cl_updaterate` | 101 | You receive the server's 100 updates per second. |
| `cl_cmdrate` | 101 | You send 100 commands per second. |
| `ex_interp` | 0.1 | Movement smoothing. Guides say 0.01, but bots stutter here. Hit registration is fine: the server compensates for it. |
| `cl_dlmax` | 1024 | Bigger download packets. |
| `gl_vsync` | 0 | No vertical sync: a late frame doesn't wait for the next one (micro-freezes). |
| `fps_max` | 100 | The engine was built around 100 FPS. Above that, movement changes slightly. |
| `m_rawinput` | 1 | The mouse ignores Windows acceleration. |
| `m_filter` | 0 | No mouse smoothing. |
| `bind` | War3FT | The same keys as in the [mod's guide](war3ft.md). The War3FT menu also changes your race and skills. |

On a weak connection (high ping, packet loss): `cl_updaterate 60`.

## Check

- In the console: `rate` should answer `100000`. If not, type `exec userconfig.cfg`.
- In game: `net_graph 3`. About 100 FPS, with no `loss` or `choke`.
- Without vsync, the image may split in two ("tearing"). If it bothers you: `gl_vsync 1`.

## Sources

- [cs-16.org: best settings](https://cs-16.org/best-cs-1-6-settings/)
- [counter-strike-boost: rate, updaterate and cmdrate](https://counter-strike-boost.com/tutorials/cs16-best-client-rates)
- [csdownload.net: ex_interp](https://csdownload.net/cs-16-ex-interp-settings/)
- [Steam Community: CS 1.6 configuration](https://steamcommunity.com/sharedfiles/filedetails/?id=1170350530)
