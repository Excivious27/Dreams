# Dreams: notes for Claude

- Project brief: `reference/BRIEF.md` (Tom works only from his phone; short replies ending with play link, what changed, what to test; one question max, last).
- Godot 4.5.1, GDScript, portrait 270×480, `canvas_items` / `keep`, nearest filter. Character strips are 2x detail, drawn at 0.5 scale (`CharacterLibrary`).
- Input goes through actions `up/down/left/right/a/b/menu` (`InputSetup`); `TouchControls` presses the same actions.
- Saves go to `user://` (`SaveGame`).
- Before every push: `bash tools/check.sh` (needs `godot` on PATH or `GODOT=...`). Never push if it fails. CI runs it too.
- `tools/playtest.gd` is a scripted playthrough with asserts and screenshots: `xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/playtest.gd -- /tmp/shots`. Run it after gameplay changes and look at the PNGs. Delete `~/.local/share/godot/app_userdata/Dreams/save.json` first.
- Touch buttons press input *actions* (no InputEvents), so UI that reacts to A/B/MENU must poll `Input.is_action_just_pressed` in `_process` (see Dialogue, GameMenu), never rely on `_unhandled_input`.
- After a dialogue/menu closes, `Dialogue.input_blocked()` is true for a moment; gameplay A/B checks respect it.
- Art pipeline: Tom uploads ChatGPT sheets to `art/incoming/`; `python3 tools/slice_art.py` keys out magenta, slices, scales to 2x and writes `art/gen/` + `manifest.json`. `Art` (scripts/art.gd) loads from there; `GameMap.prop()` places y-sorted sprites; `Art.draw_tile()` draws 32px tiles into 16px cells. Maps use LINEAR filtering because the art is 2x detail.
- `tools/slice_art2.py` handles batch-2 sheets (tool anims, portraits, villagers, enemies, interiors, seasons...). Both slicers merge into one `manifest.json`; run slice_art.py then slice_art2.py after `rm -rf art/gen`. The keyer treats dark purples as foreground (outlines) and tiles use `cover=True`.
- Characters only in art/gen are listed in `CharacterLibrary.GEN_ONLY` with their strips; missing anims get aliases so every character can idle/walk.
- Player tool anims: `player.play_tool("hoe"|"water"|"axe"|"pickaxe"|"cast"|"reel"|"hold"|"eat")`. `GameMap.fx(name, pos)` plays a one-shot effect from art/gen/fx.
- World: `WorldGen` (scripts/world_gen.gd) densifies maps (ground detail, tree borders/clumps, scatter props, critters, parallax Backdrop). Maps declare exits with `add_exit(rect, scene, spawn, facing, label)`; `GameMap.check_exits()` and `draw_exits()` handle them. Shared interactions for tree/rock/log/stump/bush/forage live in `GameMap.interact_common`.
- Area graph: farm ↔ town ↔ beach/mountain; farm ↔ forest ↔ lake ↔ farm; farm ↔ meadow ↔ crystal_meadow (penguins) / outskirts (gangsters, same scene); meadow → mine; mountain pad → moon.
- Audio placeholders: `python3 tools/make_audio.py` regenerates `audio/music/*.ogg` and `audio/sfx/*.wav`.
- Never delete Tom's uploads (`reference/`, `art/incoming/`). Original characters and art only.
- After slicing art: `python3 tools/art_audit.py --fix` then `godot --headless --path . --import`.
- Keep `docs/STATUS.md` current.
