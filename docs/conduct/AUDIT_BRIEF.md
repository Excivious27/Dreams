# CONDUCT auditor brief (R4, 2026-11-20)
Audit Dreams (Godot 4.5.1, 270x480) inside your scope line only. Start from the code map in your prompt; `grep -n -i <word> docs/TOOLS.md` (never read it whole); grep code, read line ranges, never a whole big file.
- Read-only: no game code/data/art changes, no commits. Probes only as tools/probe_<id>_*.gd or /tmp/<id>/.
- SHOTS FIRST: view the shared sweep (/home/claude/wt/shots_<N>/index.md; PNGs via Read). DEPTH FLOOR: view >= 8 sweep shots in scope, both arcs. At most 1 targeted godot run, only for a state the sweep lacks: `bash tools/conduct/glock.sh -n 15 -x -- godot ...`. Never check.sh/bots.sh.
- Append each finding AS FOUND to <id>.jsonl: {"id","area","severity" blocker|major|minor|polish,"title","files" (real files; generators not JSON),"repro","fix","art_needed","audio_needed","needs_tom"}. Restarted: read your .jsonl, continue.
- End with {"id":"<id>-clean","verified_clean":[...checked and fine, incl. shot names...]}; thin = sent back.
- 30 min real clock (`date`); don't finish early, go deeper. All ages; gang guns OK (no blood/drugs/mature); alcohol trade-only.
- Touch <id>.done. Final message ONE line: "done, N findings".
