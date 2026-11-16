# Dreams: notes for Claude

- Project brief: `reference/BRIEF.md` (Tom works only from his phone; short replies ending with play link, what changed, what to test; one question max, last).
- Godot 4.5.1, GDScript, portrait 270×480, `canvas_items` / `keep`, nearest filter. Character strips are 2x detail, drawn at 0.5 scale (`CharacterLibrary`).
- Input goes through actions `up/down/left/right/a/b/menu` (`InputSetup`); `TouchControls` presses the same actions.
- Saves go to `user://` (`SaveGame`).
- Before every push: `bash tools/check.sh` (needs `godot` on PATH or `GODOT=...`). Never push if it fails. CI runs it too.
- `tools/screenshot.gd` renders PNGs for a visual check (needs a display, e.g. `xvfb-run ... --rendering-driver opengl3`).
- Never delete Tom's uploads (`reference/`, `art/incoming/`). Original characters and art only.
- Keep `docs/STATUS.md` current.
