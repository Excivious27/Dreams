# Dreams: Status

**Play:** https://excivious27.github.io/Dreams/

## Done
- Repo, reference files, art unpacked to `art/characters/`
- Godot 4.5.1 project: portrait 270×480, pixel-perfect, web export, auto-deploy on push
- Touch controls: 8-way D-pad, A, B, MENU (multi-touch); keyboard works too
- **Title screen** → New game → choose arc (Penguins / Gangster's Paradise) → choose
  character (pack characters have art; penguins, Big Jim, Light Crystal are placeholders)
  → name character, town, pet → Start. Continue button when a run is saved.
- **Farm map**: house, tilled rows, sell box, pond with animated water, trees, path to
  town (all placeholder drawings until art arrives). Pet follows you.
- **Movement**: eases in/out, walk/run animation speed follows real speed, dust puffs
  when running, drop shadow under the player.
- **Living sky**: drifting cloud shadows, flocks of birds crossing overhead
- `GameState` (arc, character, names, skills, crystals) saved to `user://`
- Data files: `data/arcs.json`, `data/playable.json`, `data/skills.json`
- Design captured in `docs/DESIGN.md`; Tom's raw notes in `reference/DESIGN-NOTES-01.txt`
- `docs/guides/GUIDE-01.md` (questions for Tom, incl. music) and `docs/ART-PROMPTS.md`
- Character test map still reachable from the title screen
- `tools/check.sh`: import + smoke test of every scene; runs before every push and in CI

## Next
- Tom answers Guide #1 → town map, NPCs, day/energy loop, first tools and crops
- Slice and wire in art from `art/incoming/` as it arrives

## Known issues / art gaps
- No walk-toward / walk-away frames: up/down uses front/back view with a small bob
- Woman's last attack frame is missing part of the pink magic crescent
- Penguins, Big Jim, Light Crystal have no art (simple placeholder figure)
- Typing names on the web build uses the browser's on-screen keyboard (Godot's
  experimental virtual keyboard); if it misbehaves on your phone, tell me
- Multiplayer not started (see Guide #1, G)

## Controls (keyboard)
Arrows/WASD move · Z/Space/Enter = A · X/Shift = B · Esc/Tab/M = MENU
