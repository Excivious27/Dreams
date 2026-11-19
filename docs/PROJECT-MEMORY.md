# Dreams: project memory (critical context for either Claude account)

This file is the long-term memory of the whole project. `docs/HANDOFF.md` holds the short Baton (what is happening right now); this file holds everything a fresh chat must know to work at full speed. **Every handoff keeps both current** (rules in CLAUDE.md). Last full rewrite: 2026-11-19 by the Team account.

Read order for a new chat: CLAUDE.md → docs/HANDOFF.md (Baton) → this file → top of docs/STATUS.md → newest docs/guides/GUIDE-NN.md → docs/INVENTORY.md.

---

## 1. What Dreams is

- A 2D top-down farming/life/adventure game in **Godot 4.5.1** (GDScript), portrait **270×480**, touch D-pad + A/B/MENU. Tom plays only on his **phone**, through the web build: https://excivious27.github.io/Dreams/ (every push to `main` deploys via GitHub Actions; the repo is public `Excivious27/Dreams`).
- Feel targets: **Stardew Valley** for controls/inventory/combat/menus/farm start; **Sun Haven** for big open regions with organic edges.
- Goal: a polished, Stardew-grade commercial release (Steam later). "100%" means polish, not just features.
- **Two story arcs**, chosen at new game (each save slot keeps its own):
  - **Penguins — "The Two Too Powerful Penguins"**: the Star Crystal lands on your farm; partners Pip-Pip (crown) and Nova (wizard hat); Catkins teaches the Meow Pow Wow; Merkitties at the lake; Cat-topia; Sanctuary system (pool, burrow, shrine). Money: crystals (◆).
  - **Gangsters**: you hide out on a farm under a fake name; M. writes letters; Sal (bearded man, bench by the town gate) is the mentor; the President and his collectors; Hideout town; crew recruits (Deuce, Mama Rosa…); Racket system (heat, bills, press, laundromat, training); the Marked (people with Gifts who never die, are befriended/recruited). Money: **cash ($)** everywhere. All-ages: guns OK, **no blood, gore, drugs, alcohol focus, prostitution or anything mature**. Characters look serious/cool/dark underworld-cyberpunk, ages ~15–30 (family members Grandma June and Dad stay older).
- Player family/heroes come from Tom's own pixel pack (man, woman, son, girl, dog) plus many generated heroes. The dog/pup is your companion (follows, fights, fetches, enters mines).

## 2. Scale today (docs/INVENTORY.md has the full table)

~1,134 items, 134 crops, 92 enemies, 26 villagers, 19 main + 99 side quests, 56 regions, 10 mega regions, ~19,000 art pieces, 69 real songs (ACE Music), ~840 sound files. 37 systems tracked: 27 done, 5 rough (both arc stories, festivals, pet, co-op), 5 missing (side stories, dating/marriage, collections, haptics, Steam build). Overall ~73–77%.

## 3. How the work happens (process)

- **Rounds** of work, each ending with: check.sh green → push → bots/playtest → the **package** (see 6).
- Big rounds use **sub-agents in git worktrees**: `/home/claude/wt/<id>` on branch `<round>/<id>`, heavy dirs (art/, audio/, reference/, build/, .godot) hardlinked from the main checkout (`/home/claude/wt/mkwt.sh <id> <branch>` in the Team sandbox; recreate if missing). Agents commit locally, never push; the main chat merges, runs check.sh, pushes. Rules every agent gets: never write a hardlinked file in place (rm then write), wrap every godot run in `flock /tmp/godot.lock`, fresh `XDG_DATA_HOME`, run full check.sh once at the end.
- Merge lessons: JSON conflicts → union merge (keep both sides' keys/list items); never auto-resolve shell/code files with a "keep both lines" script (it dropped `fi` lines in check.sh once); new `class_name` scripts need `godot --headless --import` before tests see them; `.godot` class cache is shared through the hardlinks.
- The machine has 2 CPUs; 20 agents queue on the godot lock. Expect a full check.sh to take 10–30 min under load.
- `tools/gang_play_test.gd` has wall-clock waits that can flake under load (pup dig); re-run before assuming a real failure.

## 4. Tools and services

| What | Where / how |
|---|---|
| Image generation | **dreams-image** MCP connector (Tom's server `Excivious27/dreams-image-mcp` on Render, `https://dreams-image-mcp.onrender.com/mcp`). `generate_image` / `edit_image` commit PNGs to `art/incoming/...` on **main** (so always `git pull` before pushing). Default quality high. Limit 300/day until 2026-11-25, then 60/day. Prompt style: 16-bit pixel art, top-down 3/4 like Stardew/Sun Haven, flat #FF00FF magenta background, no text, wide gaps; use `edit_image` with existing art as reference to match style. |
| Slicing | `tools/slice_comp.py` (magenta blobs → pieces) + step scripts (`slice_world5.py`, `slice_r13_*.py`); then `make_seamless.py`, `art_audit.py --fix`, `set_import_lossy.py`, `godot --import`. Never edit art/gen files in place. |
| Music | **ace-music** MCP connector (acemusic.ai, Creator plan). Read `get_skill lyrics` first; songs render in 1–3 min, two versions; download → `/home/claude/work/ace_raw` → `tools/ace_batch.py` (picks better take, imports to `audio/music`, logs `audio/ACE_LOG.json`). Then `tools/music_stream.py` (web streams music). Tom approves song prompts for big themes; can say "swap <name>". |
| Sound effects | CC0 packs from OpenGameArt via `tools/cc0_import.py` (licences in `tools/cc0_sources.json`, credits `docs/AUDIO-CREDITS.md`), then `tools/sfx_soften.py`. `tools/sfx_audit.py` must report 0 missing. |
| Godot | `bash tools/setup_sandbox.sh` installs Godot 4.5.1 to `/home/claude/tools`; `export PATH=$PATH:/home/claude/tools`. |
| Tests | `bash tools/check.sh` (40+ headless tests; must be rc 0 before any push). `tools/playtest.gd` (scripted playthrough + screenshots, under xvfb). `bash tools/bots.sh 3 DIR` (20 random bots × 3 days, both arcs). Many focused tests (see CLAUDE.md). |
| Artifact page | The progress page artifact `67cf3116-3dba-4920-801d-e0ebd5f7c947` (Team account's artifact; the personal account can't edit it — make a new one there and note its id here). Built by a page script from the guide + spreadsheet. |

## 5. What has been built (rounds, newest first)

- **CONDUCT 1 (2026-11-19, first 3 hours, both arcs)** — 20 agents. Merged locally (pushed when check.sh passes): progress inventory (docs/INVENTORY.md, inventory.csv); farm first week (growth text on every tap, morning dry/ripe/rain lines); early gating (rec day 7, commons day 4, campaigns/mega locked with reasons, `Builds.STORY_WORDS`); early combat (fair first boss, strike telegraph icon, `PupIntro`, first clinic visit free); rec/arcade regressions (jukebox, visitors step aside, prize resale fixed at half ticket cost, claw per-day grip); gangster money words (`Money.amount/num`); softlocks (B leaves menus, `Dialogue.is_way_out`, empty dialogues); energy/pacing (`SleepReport` keeps the morning summary after a collapse, week-1 no fees `Faint.GRACE_DAYS`, bedtime warnings); saves (opening Skip button, 131-check save_test, old-save migration); Marked reslice (`tools/reslice_marked.py`, power poses play); community farm/world (farm invisible wall, Hazel on day-1 visit, place names); goal line (`GoalLine`, edge arrow to the goal, quest log "Now:"); mega/campaign regressions (fairy ring art, solid vehicles, gangster gate test); penguin intro (crystal sprite, partner scene on day 2, mailbox marker, `Mail.waiting`); gangster intro (M.'s day-2 letter with seeds, Sal is a man, Hideout order: arrival → recruit crew → drill invite → docks); town first visits (`TownHours` shops lock at night, `Intros` for all 19 villagers, rain walkers, `Mail.story_due`, board pay); arc intros (path cards on the arc picker, `ArcIntro` for 9 arc buildings); phone UI (bundled `fonts/symbols.ttf` "Dreams Symbols" so ◆♥★ etc. render on web — never use 🔒⏱⌛〰, they have no glyph; 20–22 px buttons; `tools/phone_ui_test.gd`); performance (`TriBatch` batching cut baked-chunk draw calls 2,000–7,000 → 50–200; texture cache eviction). Still open from C1: held-tool rules agent (c1/04) and a goal-line fix after the gangster flow changed.
- **Round 13 (2026-11-18)** — 10 agents: Rec Center (multilevel, playable bowling, tickets, tiered prizes, NPC hub), arcade (Block Jumper 8 levels + endless, Crystal Stack, Whack-a-Grump, Claw, Duck Pond), community farm (`Commons`, stages, volunteers), campaign overhaul (`CampaignGate`: chapter 2 + training drill + team + provisions + muster; `BattleBrief` briefing cards; shorter tiered campaigns), mega regions framework (`MegaRegion`, `MegaMap` tabs hidden until unlocked) + five new regions (Gloamwood, Sunscorch Expanse, Frostpeak Reach, Windward Isles, Gilt City) + Ironline rail frontier, audio fixes (softer SFX, footsteps by ground, music on every map incl. gangster arc), animation fixes (penguin walks/rest, deer and wildlife, props steadied), world fixes (lake→forest entry side, `BuildingAccess` messages for every building, proportions, `PlaceNames` region label, invisible walls, 10pm faint wake `Faint`, sunrise glow), gangster arc (cash, 29 underworld redraws, mining poses, held sword swing, pup in mines `PupMine`). Axe-fishing bug fixed (rod must be held).
- **Round 12 (2026-11-18)** — "complete art 100%": 179 image-tool renders + 16 redraws sliced and wired; docs/MISSING-ART.md at zero.
- **Earlier rounds (Nov 2026)** — the whole base game: farm/crops/animals, town and 26 villagers with hearts/perks/birthdays, mines (26 layouts), skills trees, crafting stations (generated), both arcs' stories, battles/campaigns, colonies, projects, co-op (relay not deployed), audio rounds, art prompt rounds 1–30, guides 1–24. See docs/STATUS.md.

## 6. The package (after every completed piece of work)

Tom wants, every time, sent as **files in the chat** (not only repo links) and on the artifact page:
1. the all-in-one guide (`docs/guides/GUIDE-NN.md`, newest = what Claude needs from Tom);
2. every art prompt file still needed (only what the image tool couldn't make; max 2–3 images per prompt; currently none);
3. the progress spreadsheet (.xlsx; Tom likes results as spreadsheets);
4. the updated artifact page.

## 7. Current big plan (Tom, 2026-11-18)

After Round 13: **CONDUCT ×3 → wait 5 h → CONDUCT ×3 → wait 5 h → CONDUCT ×3**, each run aimed at specific aspects (docs/CONDUCT-PLAN.md):
- Wave 1: C1 first 3 hours (done except merge/push), C2 rec center/arcade/community farm, C3 battle campaigns.
- Wave 2: C4 mega regions, C5 home-world look and feel, C6 audio and music.
- Wave 3: C7 story/quests/writing, C8 economy/progression/balance (incl. speed boosts from gear/potions/foods/mounts/skills), C9 release readiness → full package + artifact.
Use the session's scheduled-message tool for the 5 h waits. If the other account picks this up mid-way, continue from the Baton.

## 8. Open questions waiting on Tom

- Keep the softened first meadow boss? (~half HP lost if you never dodge.)
- Hide arc stations (gangster operation, penguin sanctuary) on the Plans board until the arc intro?
- Shops lock at night (current) vs walk-in with closed counter; homes open late at 4+ hearts?
- Week-1 grace (no faint fees for 7 days) length OK?
- Claw machine odds (~15% with a perfect grab)?
- Goal arrow on all game, or first week only?
- Opening Skip button on a very first game too?
- Bigger items: co-op relay host account (Render second Starter service or Fly.io); 31 story questions in Guide 11 (or "write the defaults"); dating/marriage vs friendship only; Steamworks account when ready.

## 9. Things never to do

- Never push if check.sh fails. Never push without pulling first (dreams-image commits to main).
- Never handle the image server's secrets (OPENAI_API_KEY, GITHUB_TOKEN, MCP_AUTH_TOKEN) or any password/token/key.
- Never delete Tom's uploads (`reference/`, `art/incoming/`). Original characters and art only — no copyrighted characters or brands.
- Never ask Tom to run commands; he has only a phone.
- Never leave work only in the chat or the sandbox: push, or a `wip/<topic>` branch named in the Baton.
