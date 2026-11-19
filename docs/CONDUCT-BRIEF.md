# Common rules for every CONDUCT agent (read fully)

Project: Dreams, a Godot 4.5.1 phone game (GDScript, portrait 270x480). Owner Tom plays on his phone only.
Read CLAUDE.md in your worktree first (project conventions, tools, generators — edit generators, not generated JSON).

YOUR WORKTREE: /home/claude/wt/<your id> (given in your task). Work ONLY there. Never touch /home/claude/dreams or other worktrees.
Your branch is checked out there. Commit your work on that branch (several commits fine). DO NOT push. DO NOT merge.
Commit message footer (exactly):
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013g54oquy7KhPYLKKRq36dZ

ART FILES ARE HARDLINKED to the main repo: never modify an existing file under art/ (or audio/) in place. To replace one, `rm` it first, then write the new file. Adding new files is fine.

Godot: `export PATH=$PATH:/home/claude/tools` (godot binary). The machine has 2 CPUs shared by 20 agents, so wrap EVERY godot invocation (including tools/check.sh) in `flock /tmp/godot.lock ...` and use a fresh `XDG_DATA_HOME=$(mktemp -d)`.
Before finishing: `flock /tmp/godot.lock bash tools/check.sh` must pass (rc 0). Fix what you broke. If you add gameplay, add or extend a headless test (tools/*_test.gd) and wire it into tools/check.sh when it is fast.
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

## CONDUCT runs (Tom's standing order)
Each CONDUCT agent both AUDITS and FIXES its scope:
1. Audit: read the relevant code/data, play it headlessly (write small scripted test/shot tools as needed), take screenshots and LOOK at them, and run focused bots if useful (`tools/bots.sh` takes days as first arg; use 2-3).
2. Fix everything you find that you can fix alone, at Stardew/Sun Haven polish. Add/extend tests for what you fixed.
3. Art/audio the fixes need: make and integrate it (rules above). Nothing outstanding.
4. Anything only Tom can do (decisions, accounts, taste calls) goes in your final report under "NEEDS TOM" — keep it short and concrete.
Time: 20 agents share 2 CPUs. During work run only targeted tests (and `godot --headless --path . --check-only -s <script>` / tools/compile_all.gd if present); run the full `flock /tmp/godot.lock bash tools/check.sh` ONCE at the end and fix until rc 0.
Final report: bullets of findings, fixes, files touched, tests + results, NEEDS TOM.
Recent changes to know (Round 13 + CONDUCT 1, merged: GoalLine, ToolHint, Money.amount/num, SleepReport, Faint grace + first visit free, TownHours, Intros, Mail.story_due, ArcIntro, symbol font (never use 🔒⏱⌛〰 glyphs), TriBatch, Dialogue.is_way_out; also): rec center + bowling (RecCenter, Bowling, Tickets), arcade (ArcadeHub, ArcadeGame, 5 cabinets), community farm (Commons), campaign gating/drill/briefings (CampaignGate, BattleDrill, BattleBrief), mega regions (MegaRegion, MegaMap, MegaTravel), gangster cash (Money, MoneyHook), pup in mines (PupMine), Faint (10pm wake), BuildingAccess, PlaceNames. Tom 2026-11-18: default move speed stays as is; speed boosts come from gear/potions/foods/mounts/skills. Fishing only with the rod held.
