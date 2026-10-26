# War3FT: how it works

Français : [fr/war3ft.md](fr/war3ft.md)

Counter-Strike 1.6 with the races and spells of Warcraft 3: Frozen Throne. An AMX Mod X plugin
([wc3mods/war3ft](https://github.com/wc3mods/war3ft)).

In game, the same guide shows up when you connect (the MOTD): [cs.pazpop.net/guide.html](https://cs.pazpop.net/guide.html).

## The basics

- Pick a **race**. Each one has 3 skills and an **ultimate** (some also have a passive skill).
- Earn **XP**, mostly by killing. XP raises your **level**.
- Each level gives a point to put into a skill (`/selectskill`). The ultimate unlocks later.
- XP is saved **per race** and **per SteamID**: you get it back next time you connect.
- With your CS money, you can also buy **items** in two shops.

## Commands (in chat)

Every command works with a `/` in front.

| Command | What it does |
|---|---|
| `/help` | This guide again (or `help` in the console) |
| `/changerace` | Change race (at your next respawn) |
| `/war3menu` | The main menu |
| `/selectskill` | Spend your skill points |
| `/skillsinfo` | What your race's skills do |
| `/level` | Your race, level and skills |
| `/playerskills` | Other players' skills |
| `/shopmenu`, `/shopmenu2` | The item shops |
| `/itemsinfo`, `/itemsinfo2` | What the items do |
| `/war3help` | Help |
| `/rtv` | Ask for a new map (vote at 60 % of humans) |
| `/votekick` | Vote to kick a player for 10 minutes: at 60 % of the other humans (at least 3 humans) |
| `/rank`, `/top15` | Your combat rank, the top 15 (the top 10 show their place in the chat) |
| `/ach` | Your achievements: 14 goals, from your first kill to 10,000 |
| `/mystats` | The link to your page on the stats site |
| `/coach` | A tip from the AI coach, from your numbers on this map, in private |
| `/statsme`, `/rankstats` | Your stats on this map, your overall stats |
| `/nextmap`, `/timeleft` | The next map, time left on this one |

## Keys to bind (in the console)

```
bind "mouse3" "ultimate"
bind "alt" "ability"
bind "-" "shopmenu"
bind "=" "shopmenu2"
```

`ability` is for the Shadow Hunter's Serpent Ward.

## Races

| Race | Skills | Ultimate |
|---|---|---|
| Undead Scourge | Life steal, speed, higher jumps | Explodes on death |
| Human Alliance | Invisibility, more health, stuns | Teleport |
| Orcish Horde | Critical hits, strong grenades, keeps equipment | Chain lightning |
| Night Elf | Evasion, reflects damage, more damage | Roots an enemy |
| Blood Mage | Revives a teammate, banishes, steals money | Sets an enemy on fire |
| Shadow Hunter | Group healing, turns enemies into critters, shooting ward | Invincible for 2 seconds |
| Warden | Can spawn as a mole in the enemy base, blocks enemy ultimates, poisoned dagger | Comes back once |
| Crypt Lord | Impale, spiked carapace, beetles | Locust swarm |

Exact numbers (percentages, durations): `/skillsinfo` in game.

## Items

- **Shop 1**: ankh of reincarnation, boots of speed, claws of attack, cloak of shadows, mask of death,
  necklace of immunity, orb of frost, periapt of health, tome of experience.
- **Shop 2**: scroll of respawning, mole protectant, helm of excellence, amulet of the cat, sock of the feather,
  flaming gloves of warmth, ring of regeneration, chameleon, mole.

What each one does: `/itemsinfo` and `/itemsinfo2` in game.

## On this server

- **Respawn**: you come back at once in your team's base. No rounds, no bomb. **G** opens the weapon menu.
  3 seconds of protection after each respawn, lost when you shoot.
- **Money**: $800 to start, and more with each kill, for the shops' items.
- **Faster levels**: half the usual XP per level, so your ultimate (level 6) comes twice as fast. A race you have
  never played starts at level 3.
- **Bots** (YaPB) fill the server up to 10 players. A bot leaves when a human joins. Their level is a mix, from
  beginner to good, like real players.
- **The AI**: the bots (`[AI] Zed`...) talk back when you write their name in the chat, answer any question with a
  `?`, each with its own character, and remember you: kill one often, and it holds a grudge. A Game Master starts bounties, duels and other surprises.
- The first human to join a server of bots only restarts the game: everyone starts from zero.
- Every 30 minutes, a vote picks the next map.
- An announcer for first blood, multi-kills and kill streaks, up to GODLIKE.
- Away for **60 seconds** (no key, no mouse move): you become a spectator. A ping over **300 ms** for 50 seconds
  gets you kicked.
- Rankings (of the month, XP and combat) and a page per player: [cs.pazpop.net](https://cs.pazpop.net).
- Client settings: [client.md](client.md).
