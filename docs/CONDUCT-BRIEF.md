# Common rules for every CONDUCT agent (read fully)

## Usage rules (Tom 2026-11-19 22:49)
Start from the code map /home/claude/wt/cN_map.md (tools/conduct/code_map.py), grep, read line ranges; never a whole big file. Screenshot only what you need and view each once. Auditors finish with one line ("done, N findings in <file>"); fix agents with "done, report in <path>". Briefs: /home/claude/wt/AUDIT_BRIEF.md, /home/claude/wt/FIX_BRIEF.md (copied below).

## Auditors (read and play only)
- Do not change game code, data or art; small probes go under tools/probe_<id>_*.gd or /tmp/<id>/.
- Append each finding AS SOON AS YOU FIND IT to /home/claude/wt/cN_reports/<id>.jsonl (create the dir if needed), one JSON object per line:
  {"id":"c5_07","area":"...","severity":"blocker|major|minor|polish","title":"...","files":["scripts/x.gd","data/y.json"],"repro":"...","fix":"...","art_needed":"","audio_needed":"","needs_tom":""}
  Name the real files the fix touches (generators, not generated JSON) so tools/conduct/cluster.py can build file-disjoint packages.
- When finished, write /home/claude/wt/cN_reports/<id>.done and end with a short summary (the .jsonl is the report).
- If you were restarted, read your existing .jsonl first and CONTINUE: never repeat or re-check findings already written.
- Read-only auditors don't run Godot at all. Playing auditors use short scripts (area_shot, probes) under flock; never bots.sh or check.sh.


Project: Dreams, a Godot 4.5.1 phone game (GDScript, portrait 270x480). Owner Tom plays on his phone only.
Read CLAUDE.md in your worktree first (project conventions, tools, generators — edit generators, not generated JSON).

YOUR WORKTREE: /home/claude/wt/<your id> (given in your task). Work ONLY there. Never touch /home/claude/dreams or other worktrees.
Your branch is checked out there. Commit your work on that branch (several commits fine). DO NOT push. DO NOT merge.
Commit message footer (exactly):
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: <the session link from the main chat's attribution>

ART FILES ARE HARDLINKED to the main repo: never modify an existing file under art/ (or audio/) in place. To replace one, `rm` it first, then write the new file. Adding new files is fine.

Godot: `export PATH=$PATH:/home/claude/tools` (godot binary). The machine has 2 CPUs shared by many agents, so wrap EVERY godot invocation in `flock /tmp/godot.lock ...` with a fresh `XDG_DATA_HOME=$(mktemp -d)` and `timeout 600`.
NEVER run tools/check.sh or tools/bots.sh locally (the main chat runs them on GitHub Actions with tools/conduct/ci_run.sh). Fix agents run only the targeted tests for the files they touch. If you add gameplay, add or extend a headless test (tools/*_test.gd) and wire it into tools/check.sh as its own block (a blank line before and after; it becomes a CI shard step automatically).
Screenshots: tools/area_shot.gd (see CLAUDE.md) — look at them (Read tool on the PNG) to verify visuals.

Content rules: all ages. Gangster arc: guns OK, no blood/graphic violence, no drugs/alcohol-centred/mature content. Original characters and art only. Never delete Tom's uploads (reference/, art/incoming/).
Keep edits to big shared files (scripts/game_map.gd, game_state.gd, hud.gd, region.gd) small and surgical — other agents edit them too and I merge afterwards; prefer new scripts with small hooks.
Update docs/STATUS.md with a short entry for your work (a new " at the top) and CLAUDE.md with any new tool/convention (one line).

Quality bar: Stardew Valley / Sun Haven polish. Finish what you start; no stubs. When done, reply with: what you built/fixed (bullets), files touched, tests run + results, anything left undone and why.

## ART (added by Tom's request): nothing may be left outstanding
Any art your feature needs must be generated AND integrated by you — no placeholders, no "art needed later" notes.
- Tools: mcp__dreams-image__generate_image / mcp__dreams-image__edit_image (load with ToolSearch "select:mcp__dreams-image__generate_image,mcp__dreams-image__edit_image"). They commit a PNG to art/incoming/<path> on origin main. Pull it into your worktree: `git -C <wt> fetch -q origin main && git -C <wt> checkout origin/main -- art/incoming/<file>`.
- Prompt style that works: "1536x1024, 16-bit pixel art, top-down 3/4 view like Stardew Valley / Sun Haven, light from top-left, clean 1px dark outlines, flat pure #FF00FF magenta background, NO text/numbers, no watermark, never #FF00FF inside the art, wide magenta gaps between pieces". Use edit_image with existing art/gen files as sources whenever the new art must match existing characters/style. At most a handful of pieces per image; pieces are placed only roughly, so slice by components.
- Slice with tools/slice_comp.py helpers (blobs, rows_of, row_n, bands, save_strip) — add a step function to tools/slice_world5.py (add it to STEPS) or your own small step in a new tools/slice_r13_<you>.py; save via slice_art.save/strip into art/gen and the manifest (load the manifest first like slice_world5's __main__). Then run python3 tools/make_seamless.py (if seamless), tools/art_audit.py --fix, and flock godot --import.
- Budget: the image server allows ~300/day shared by everyone; use at most 4 images unless your brief gives a number. Check each render visually (Read the PNG) before slicing; regenerate if it's wrong.
- Remember: never modify existing art/gen files in place (rm first).

## AUDIO (added by Tom's request): nothing may be left outstanding either
Every sound or song your feature needs must exist and be wired in (tools/sfx_audit.py must pass with 0 missing).
- Effects/ambience: reuse existing names in audio/sfx (see audio/sfx/ACE.txt, REAL.txt, CC0_USED.json) or import CC0 packs with tools/cc0_import.py (licences in tools/cc0_sources.json; credits in docs/AUDIO-CREDITS.md). Then soften new files with tools/sfx_soften.py. Never write hardlinked files in place (temp file, rm, move).
- Songs: the ACE Music MCP (mcp__ace-music__create_song / get_song / download_song; read get_skill "lyrics" first; instrumental via style only) and tools/ace_batch.py / ace_import.py (see CLAUDE.md ACE lines). New songs: add to GameMap.AREA_MUSIC etc., then python3 tools/music_stream.py. Use at most 1 new song per agent, and only where reuse of an existing track would feel wrong (e.g. arcade music, bowling alley, a new mega region theme).
- No synthetic beeps from tools/make_audio.py for new sounds.

## CONDUCT runs (Tom's standing order; process changed 2026-11-19)

AUDITORS (step 1): read, play by script, screenshot, write a small reproducing test if useful; do NOT edit game code and do NOT run tools/check.sh. Return findings: what, where, how to reproduce, suggested fix, art/audio needed, NEEDS TOM.
FIX AGENTS (step 4): one package of file-disjoint fixes, 60-75 min cap, targeted tests only (flock /tmp/godot.lock), make/wire any art or audio the package needs, commit, report. Never run the full check.sh; the main chat runs it once after merging.

(The old text below is kept for reference; where it conflicts, the two paragraphs above win.)
Each CONDUCT agent both AUDITS and FIXES its scope:
1. Audit: read the relevant code/data, play it headlessly (write small scripted test/shot tools as needed), take screenshots and LOOK at them, and run focused bots if useful (`tools/bots.sh` takes days as first arg; use 2-3).
2. Fix everything you find that you can fix alone, at Stardew/Sun Haven polish. Add/extend tests for what you fixed.
3. Art/audio the fixes need: make and integrate it (rules above). Nothing outstanding.
4. Anything only Tom can do (decisions, accounts, taste calls) goes in your final report under "NEEDS TOM" — keep it short and concrete.
Time: 20 agents share 2 CPUs. During work run only targeted tests (and `godot --headless --path . --check-only -s <script>` / tools/compile_all.gd if present); run the full `flock /tmp/godot.lock bash tools/check.sh` ONCE at the end and fix until rc 0.
Final report: bullets of findings, fixes, files touched, tests + results, NEEDS TOM.
Recent changes to know (Round 13 + CONDUCT 1, merged: GoalLine, ToolHint, Money.amount/num, SleepReport, Faint grace + first visit free, TownHours, Intros, Mail.story_due, ArcIntro, symbol font (never use 🔒⏱⌛〰 glyphs), TriBatch, Dialogue.is_way_out; also): rec center + bowling (RecCenter, Bowling, Tickets), arcade (ArcadeHub, ArcadeGame, 5 cabinets), community farm (Commons), campaign gating/drill/briefings (CampaignGate, BattleDrill, BattleBrief), mega regions (MegaRegion, MegaMap, MegaTravel), gangster cash (Money, MoneyHook), pup in mines (PupMine), Faint (10pm wake), BuildingAccess, PlaceNames. Tom 2026-11-18: default move speed stays as is; speed boosts come from gear/potions/foods/mounts/skills. Fishing only with the rod held.

## AUDIT_BRIEF (copy)

# CONDUCT auditor brief (usage-optimised, Tom 2026-11-19 22:49)

You audit Tom's Godot 4.5.1 phone game Dreams (270x480). Common rules: docs/CONDUCT-BRIEF.md "Auditors". Do not re-learn the project: start from the code map /home/claude/wt/cN_map.md (N = your CONDUCT), grep for what you need, read line ranges only. Never read a whole big file (game_map.gd, game_state.gd, ...).
- Worktree /home/claude/wt/<id>; no changes to game code, data or art. Probes only as tools/probe_<id>_*.gd or /tmp/<id>/.
- Findings: append each AS YOU FIND IT to /home/claude/wt/cN_reports/<id>.jsonl, one JSON per line: {"id","area","severity" (blocker|major|minor|polish),"title","files" [real files the fix touches; generators, not generated JSON],"repro","fix","art_needed","audio_needed","needs_tom"}. Write <id>.done at the end. If restarted: read your .jsonl, continue, never redo.
- Stay inside your scope line; other auditors cover the rest (no overlap).
- Screenshots: only what you need to check, and view each one once.
- Godot runs: short scripts only, each under `flock /tmp/godot.lock`, `XDG_DATA_HOME=$(mktemp -d)`, `timeout 600`, `export PATH=$PATH:/home/claude/tools`. Never tools/check.sh or tools/bots.sh.
- About 35 minutes. All ages; gangster guns OK (no blood/drugs/mature); wine and ales are trade goods, never drunk.
- Your final message is ONE line: "done, N findings in /home/claude/wt/cN_reports/<id>.jsonl". No summary. Commit nothing.

## FIX_BRIEF (copy)

# CONDUCT fix agent brief (usage-optimised, Tom 2026-11-19 22:49)

You fix ONE package for Tom's Godot game Dreams. Common rules (worktree, hardlinked art, flock, commit footer, content rules, art/audio pipeline): docs/CONDUCT-BRIEF.md. Do not re-learn the project: start from the code map /home/claude/wt/cN_map.md, grep, read line ranges only; never read a whole big file.
- Fix exactly the findings in your package (they name files/functions) plus anything directly broken by your change. Do not re-audit.
- Window: 60-75 minutes of real clock time (`TZ=America/Los_Angeles date`). Do not stop early or call it "time cap" before then. If you must stop (tool limit), write what is left in your report; the main chat resumes you.
- NEVER run tools/check.sh or tools/bots.sh (CI runs them). Run only the targeted tests your package names, each under `flock /tmp/godot.lock`, fresh XDG_DATA_HOME, `timeout 600`; `--check-only` on changed scripts. Add a focused test per fix; wire it into check.sh only if it runs in < 60 s.
- Stay inside your owned files; a hook in another package's file is one or two lines and reported.
- Commit small on your branch as you go. Never push or merge.
- Art: dreams-image generate/edit (budget in the package), slice, wire, look at each result once. Audio: ACE / CC0 (budget in the package). Nothing left outstanding that the package lists.
- Docs: one STATUS.md entry, CLAUDE.md lines for new conventions.
- Report to /home/claude/wt/cNf_reports/pK.md as you go (item -> fixed: how + test / not fixed: why + suggested fix; art/audio made; NEEDS TOM), touch pK.done at the end. Final message: one line, "done, report in <path>".
