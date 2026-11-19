# Dreams: Design (living document)

Source: Tom's notes in `reference/DESIGN-NOTES-01.txt`. This file restates them as the
current plan and fills in nothing Tom hasn't said. Anything marked **TBD** is a question
for Tom (see the guides in `docs/guides/`).

## One line
An open-world, mystical farming RPG in the Stardew Valley mold, with far more
consequential choices, more combat, two story arcs that secretly connect, and co-op
multiplayer. Phone-first, played in portrait.

## Core loop (shared by both arcs)
- Start in a town with your own plot of land: build, farm, forage, mine, fish, craft.
- Make friends in town (Stardew-style friendship).
- Skills that level up and unlock abilities: **combat, farming, mining, bartering,
  building, foraging, fishing** (more TBD).
- Unlock new towns/regions over time; each has its own mines. Later: space.
- Combat: Stardew-style action combat but more of it; bosses that can be beaten by
  force or by clever alternative paths.
- Economy: currency is **crystals**; anything can be traded for anything by trade value;
  a sell box on the farm; a general store plus weapon/potion/etc. shops in town.
- You name your **character, town and pet**. The pet (the puppy from the character pack)
  is a key helper in both arcs.
- Decisions branch the game: which arc you pick, which character, and good/bad choices
  during play all change what unfolds.

## Arc 1: The Two Too Powerful Penguins (wholesome)
- A Light Crystal from a far-off galaxy granted penguins a power, the **Meow Pow Wow**.
- The Light Crystal sensed the penguins are the chosen ones: the universe's last hope
  against the **Dark Crystal**, a corrupted crystal that corrupted others into the
  **Grumps Army** to drain all joy from the universe and rule it.
- Goal: find all the missing abilities to complete the full Meow Pow Wow, then defeat
  the Dark Crystal. Craft, explore, unlock areas, go to space, do complex quests, build
  up the community.
- Playable: **Big Jim**, **male Too Powerful Penguin**, **female Too Powerful Penguin**,
  **Light Crystal**, or any pack character (**Mom, Dad, Pax, Kairi**).

## Arc 2: Gangster's Paradise (serious)
- Tone: the "Joja Cola" side of Stardew meets One Piece-style gangs. (Tone reference
  only. All characters and art are original.)
- You are hiding out in this community after a gangster ruined your life. You farm and
  build begrudgingly to gain access to new regions, each run by gangsters with
  different abilities (cyber implants, superpowers, raw strength, ...).
- Goal: build strength and money, recruit your own gang, and one day take on the
  **president of the biggest gangster nation**, the one who ruined your life.
- Playable: **Dad** or **Paxten** (the pack's man or son).

## The two arcs connect
On the surface unrelated; over time it comes to light that the paths interconnect.
**How** is TBD (Guide #1).

## Multiplayer
Co-op like Stardew. Plan: build everything single-player first but keep the world
state in one data model (`GameState`) so it can be synced later. Web builds on GitHub
Pages are single-threaded and have no server, so real co-op will need either a relay
server or a native (Android) build. Decision deferred; see Guide #1.

## Character pack mapping (current)
| Pack folder | Name Tom uses |
|---|---|
| `man` | Dad |
| `woman` | Mom |
| `son` | Pax / Paxten |
| `girl` | Kairi |
| `dog` | the pet (player names it) |

## Not yet designed (needs Tom)
Town name/layout, NPC roster, the penguins' and Light Crystal's look, the Meow Pow Wow
ability list, the gangster regions, bosses, the exact skill list, how the arcs connect,
music direction, art style details. Each guide in `docs/guides/` asks for the next most
important batch.
