# Common rules for every CONDUCT agent (read fully)

Dreams: Tom's Godot 4.5.1 phone game (GDScript, portrait 270x480); Tom plays on his phone only. Core rules: CLAUDE.md in your worktree. Tools and systems: `grep -n -i <word> docs/TOOLS.md` (never read it whole). The full CONDUCT process lives in docs/HANDOFF.md "CONDUCT operating rules"; this file is only what agents need.

## Everyone
- Do not re-learn the project: start from the code map /home/claude/wt/cN_map.md (tools/conduct/code_map.py), grep, read line ranges; never a whole big file (game_map.gd, game_state.gd, ...). Screenshot only what you need and view each once.
- Worktree /home/claude/wt/<id> (given in your task). Work ONLY there; never touch /home/claude/dreams or other worktrees. Never push or merge.
- Godot: `export PATH=$PATH:/home/claude/tools`; wrap EVERY godot run in `flock /tmp/godot.lock`, with a fresh `XDG_DATA_HOME=$(mktemp -d)` and `timeout 600` (2 CPUs shared by many agents).
- NEVER run tools/check.sh or tools/bots.sh locally: the main chat runs them on GitHub Actions (tools/conduct/ci_run.sh) after the merge.
- ART FILES ARE HARDLINKED to the main repo: never modify an existing file under art/ or audio/ in place; `rm` it first, then write. New files are fine.
- Content: all ages. Gangster arc: guns OK, no blood/graphic violence, no drugs or mature content; wine and ales are trade goods, never drunk; no animal dies. Original characters and art only. No names of Tom's family or staff. Never delete Tom's uploads (reference/, art/incoming/). Edit generators, never generated JSON. New symbols need a glyph in fonts/symbols.ttf (`python3 tools/make_symbol_font.py`); never use 🔒⏱⌛〰. Default move speed stays as is (boosts come from gear/potions/foods/mounts/skills); fishing only with the rod held.

## Auditors (step 1: read and play only, about 35 minutes)
- No changes to game code, data or art; commit nothing. Probes only as tools/probe_<id>_*.gd or /tmp/<id>/. Read-only auditors don't run Godot; playing auditors use short scripts (area_shot, probes) under flock.
- Stay inside your scope line; other auditors cover the rest.
- Append each finding AS SOON AS YOU FIND IT to /home/claude/wt/cN_reports/<id>.jsonl (create the dir if needed), one JSON object per line:
  {"id":"c5_07","area":"...","severity":"blocker|major|minor|polish","title":"...","files":["scripts/x.gd","tools/gen_y.py"],"repro":"...","fix":"...","art_needed":"","audio_needed":"","needs_tom":""}
  Name the real files the fix touches (generators, not generated JSON) so tools/conduct/cluster.py can build file-disjoint packages.
- If restarted: read your existing .jsonl first and CONTINUE; never repeat findings already written.
- At the end write /home/claude/wt/cN_reports/<id>.done. Final message is ONE line: "done, N findings in /home/claude/wt/cN_reports/<id>.jsonl".

## Fix agents (step 4: one package of file-disjoint fixes)
- Fix exactly the findings in your package plus anything directly broken by your change; do not re-audit. Stay inside your owned files; a hook in another package's file is one or two lines and reported. Keep edits to big shared files (game_map.gd, game_state.gd, hud.gd, region.gd) small and surgical; prefer new scripts with small hooks.
- Window: 60-75 minutes of real clock time (`TZ=America/Los_Angeles date`). Do not stop early. If you must stop (tool limit), write what is left in your report; the main chat resumes you.
- Tests: only the targeted tests your package names, plus `--check-only` on changed scripts. Add a focused headless test per fix (deterministic: game time, `--fixed-fps 60`, `seed(n)`); wire it into check.sh as its own block (blank line before and after) only if it runs in < 60 s.
- Commit small on your branch as you go. Commit footer (exactly):
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: <the session link from the main chat's attribution>
- Docs: one short docs/STATUS.md entry; one docs/TOOLS.md line (in its area) per new tool, system or convention.
- Report to /home/claude/wt/cNf_reports/pK.md as you go (item -> fixed: how + test / not fixed: why + suggested fix; art/audio made; NEEDS TOM), touch pK.done at the end. Final message: one line, "done, report in <path>".

## Art: nothing left outstanding
- Any art the package needs is generated AND integrated by you; no placeholders. Tools: mcp__dreams-image__generate_image / edit_image (load with ToolSearch). They commit a PNG to art/incoming/<path> on origin main; pull it: `git -C <wt> fetch -q origin main && git -C <wt> checkout origin/main -- art/incoming/<file>`.
- Prompt style: "1536x1024, 16-bit pixel art, top-down 3/4 view like Stardew Valley / Sun Haven, light from top-left, clean 1px dark outlines, flat pure #FF00FF magenta background, NO text/numbers, no watermark, never #FF00FF inside the art, wide magenta gaps between pieces". Use edit_image with art/gen sources when it must match existing art. A handful of pieces per image; slice by components.
- Slice with tools/slice_comp.py helpers in a small step script; save into art/gen + manifest; then art_audit --fix <ids>, make_seamless --check if seamless, flock godot --import. Budget: as the package says (default at most 4 images). Look at each render once before slicing.

## Audio: nothing left outstanding
- Every sound or song must exist and be wired in (tools/sfx_audit.py passes, 0 missing). Effects: reuse audio/sfx names or import CC0 with tools/cc0_import.py, then tools/sfx_soften.py; never write hardlinked files in place. Songs: ACE Music MCP (read get_skill "lyrics" first) + tools/ace_batch.py / ace_import.py, then add to the music map and run tools/music_stream.py; at most 1 new song per agent, only where reuse would feel wrong. No synthetic beeps from tools/make_audio.py.
