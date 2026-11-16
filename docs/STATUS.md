# Dreams: Status

**Play:** https://excivious27.github.io/Dreams/

## Done
- Repo, reference files (`reference/BRIEF.md`, `reference/character_pack.zip`), art unpacked to `art/characters/`
- Godot 4.5.1 project: portrait 270×480, pixel-perfect (nearest filter, `canvas_items`, `keep`)
- Touch controls: 8-way D-pad, A, B, MENU (multi-touch); keyboard works too
- Character test map: all 5 characters idle in a line-up; you walk one around
  - D-pad move · hold B run · A attack · tap B (dog) play · MENU next character
  - Last character picked is saved to `user://save.json`
- Web export (single-threaded) + auto-deploy to GitHub Pages on every push to `main`
- `tools/check.sh`: import + smoke test (loads every scene, presses every button); runs before every push and in CI

## Next
- Tom describes the game

## Known issues / art gaps
- No walk-toward / walk-away frames: up/down uses the front/back view with a small bob
- Woman's last attack frame is missing part of the pink magic crescent
- Full-res `frames/` aren't in the web build yet (strips are used); added when needed

## Controls (keyboard)
Arrows/WASD move · Z/Space/Enter = A · X/Shift = B · Esc/Tab/M = MENU
