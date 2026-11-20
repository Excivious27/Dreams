# CONDUCT auditor brief (round 3, Tom 2026-11-20 13:00)

You audit Tom's Godot 4.5.1 phone game Dreams (270x480). Do not re-learn the project: start from the code map named in your prompt, look things up with `grep -n -i <word> docs/TOOLS.md` (never read it whole), grep code and read line ranges only. Never read a whole big file (game_map.gd, game_state.gd, farm.gd, ...).
- Worktree as named in your prompt; no changes to game code, data or art. Probes only as tools/probe_<id>_*.gd or /tmp/<id>/.
- Findings: append each AS YOU FIND IT to your .jsonl, one JSON per line: {"id","area","severity" (blocker|major|minor|polish),"title","files" [real files the fix touches; generators, not generated JSON],"repro","fix","art_needed","audio_needed","needs_tom"}. If restarted: read your .jsonl, continue, never redo.
- DEPTH FLOOR (required): (a) play each flow in your scope by script and view the screenshots; (b) check both arcs where they apply; (c) end your .jsonl with one line {"id":"<id>-clean","verified_clean":[...what you checked and found fine...]}. A missing or thin list means you get sent back.
- Stay inside your scope line; other auditors cover the rest.
- Godot runs: short scripts only, each as `nice -n 15 flock /tmp/godot_audit.lock timeout 600 godot ...` with `XDG_DATA_HOME=$(mktemp -d)` and `export PATH=$PATH:/home/claude/tools` (low priority: fix agents' tests come first). Never tools/check.sh or tools/bots.sh.
- About 35 minutes of real clock time (`date`). Don't finish early: when your list runs out, go deeper. All ages; gangster guns OK (no blood, drugs or mature content); wine and ales are trade goods, never drunk.
- Write <id>.done at the end. Final message is ONE line: "done, N findings". Commit nothing.
