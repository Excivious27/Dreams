# Dreams: notes for Claude (core)

This file is the core: rules and the conventions every change follows. The full tool and system catalog (every script, generator, test, slicer and API) is `docs/TOOLS.md`, one line per entry, tagged by area ([core] [test] [data] [art] [world] [farm] [player] [money] [story] [battle] [mega] [rec] [commons] [decor] [audio] [save]).
**Look things up with `grep -n -i <word> docs/TOOLS.md`; never read TOOLS.md whole.** Grep it before touching any system; add one line there (in its area) for every new tool, system or convention.

## Project

- Tom's game Dreams: Godot 4.5.1, GDScript, portrait 270×480 (`canvas_items` / `keep`, nearest filter; maps use LINEAR filtering because the art is 2x detail). Character strips are 2x detail, drawn at 0.5 scale (`CharacterLibrary`). Repo `Excivious27/Dreams`, branch `main`; play link https://excivious27.github.io/Dreams/ (every push auto-deploys).
- Two arcs, picked per save: the penguin arc (*The Two Too Powerful Penguins*: Pip-Pip, crowned, and Nova, wizard hat; a pair, not a male/female variant; crystals ◆ money, Grumps, Sanctuary) and the gangster arc (cash $, crew and Hideout, `Racket`, cyber stations; serious dark underworld/cyberpunk look). Each arc has its own stations, buildings, items, armour and weapons. Quality bar: Stardew Valley / Sun Haven polish ("100% done" = a Stardew-grade commercial release).
- Project brief: `reference/BRIEF.md`. Whole-project context: `docs/PROJECT-MEMORY.md`. Status: `docs/STATUS.md`. Systems inventory: `docs/inventory.csv` → `docs/INVENTORY.md`.

## Rules: the two accounts, handoff and Baton

- **Two Claude accounts take turns on this repo, automatically** (Tom's Team and personal; he switches when one hits a usage limit, without warning and without telling either chat). Chat history and memory are NOT shared; `docs/HANDOFF.md` is the only shared memory. Tom never writes handoffs: keeping it current is your job, every session, unasked.
- **On start, before anything else:** `git pull`, read `docs/HANDOFF.md` (Tom's rules, the Baton, the log), then `docs/PROJECT-MEMORY.md` (arcs, systems, tools, process, open questions). New sandbox: `bash tools/setup_sandbox.sh` (Godot 4.5.1 + deps). If the Baton's last update is under 30 minutes old and says a step is in progress, the other account may still be working: say so in one line and ask before pushing. Otherwise carry on from the Baton's next step, unless Tom asked for something else.
- **Sync your memory once per session:** anything your own memory holds about Dreams (rules, preferences, decisions) that `HANDOFF.md` lacks goes into it.
- **Every handoff carries the critical data, not just the Baton:** whenever something important changes (a system built or redesigned, a convention, a tool, a decision, an open question, a plan), update `docs/PROJECT-MEMORY.md` in the same push so the other account could continue with no chat history at all.
- **Every push updates the Baton in the same commit** (time, what's done, what's in progress, exact next step, open questions). Assume any message could be your last: a usage limit can end the chat mid-task.
- Push small and often: every finished step, and at least every ~30 minutes of work. Nothing may live only in the chat or the sandbox (`/home/claude/work` is lost on a switch). Work that fails check.sh goes to a `wip/<topic>` branch, named in the Baton.
- Record what the other account would need to know, in the same push: any rule, preference, decision, answer or idea Tom gives in chat (→ Tom's working rules or Decisions), jobs still running elsewhere (ACE song ids not yet imported, images not yet sliced, deploys), plans agreed but not started, and anything Tom is waiting on.
- When a piece of work ends, add one line to the HANDOFF log (newest first; keep 30 lines, roll older ones into STATUS.md). Keep `docs/STATUS.md` current; update `docs/inventory.csv` (then `python3 tools/inventory_md.py`) when a system changes state.
- Tom may still send **HANDOFF**: then also reply with a 3-line summary. He doesn't have to.

## Rules: CONDUCT and Tom's deliverables

- **CONDUCT** (Tom's command): run the full cycle in `docs/HANDOFF.md` → Tom's commands → CONDUCT (operating rules there; agent rules in `docs/CONDUCT-BRIEF.md`). Standing process: 20 read/play-only auditors (no code changes, no check.sh) + the 20-bot playtest → synthesize into 5-6 file-disjoint fix packages (plus all open work: art, audio, anything needed) → 5-6 fix agents in parallel, targeted tests only, 60-75 min cap → one merge, one full check.sh, bots and playtest again → the full package as files in the chat. Target about 2-2.5 h. Never a lighter version. While agents or bots run, check on all of them every 30 minutes (scheduled message) and restart anything stopped or stuck (the Watchdog rule in HANDOFF.md).
- Heavy runs never run locally: full check.sh, bots and playtest go to CI with `bash tools/conduct/ci_run.sh <label> [days]` (exit 0 pass, 1 fail, 3 = no results: fall back to local); subset runs `--shards a,b` (from `python3 tools/conduct/check_shard.py --for-files <files>`), `--no-bots`, `--playtest-only`, `--branch <b>`; a bot/playtest passing on its one retry is FLAKY, counted green.
- A new Python import or system tool goes into tools/ci-requirements.txt / the apt line in the same commit (tools/ci_deps_check.py).
- **Tom's deliverables** (HANDOFF.md section of that name) are mandatory for both accounts: a play link every reply; check-ins at least hourly on long jobs; after every completed piece of work the full package as files in the chat (100%-complete guide, progress xlsx with % done/% remaining, report, art prompts or "none", updated artifact page). Builders in `tools/package/`.
- Tom works only from his phone: never ask him to use a computer, run a command, paste a key or token, or write a handoff. Replies are short and end with the play link, what changed and what to test; at most one question, placed last. He likes results details as a spreadsheet in the chat.
- All art and audio a piece of work needs is generated (dreams-image, ACE Music, CC0) and integrated by Claude, with nothing left outstanding; keep `docs/MISSING-ART.md` at zero. Music: Claude sends song prompts after Tom approves, fetches the songs and places them.

## Rules: content

- All ages, everywhere. Gangster arc: guns are fine (ranged weapons that use `rounds`), but no blood or graphic violence, no drugs, prostitution or other mature content. The Marked never die.
- Wine, ales and any alcohol are trade goods only (craft, sell, gift): nobody drinks them, no status effects, never food (tools/drink_rule_test.py). Casino betting is allowed in an all-ages tone.
- No animal ever dies, is slaughtered or sold for meat (ranching rehomes instead). Romance: no gender checks, one partner, no divorce, no kids.
- No names of Tom's family or staff anywhere in the game; real third-party brands are replaced by invented names (Maple's shop is "Maple's Mercantile", clear of Tom's real store).
- Original characters and art only. Never delete Tom's uploads (`reference/`, `art/incoming/`).
- Every craft station and building is crafted or purchased by the player, gated by tier; none given free. Design: regions expansive and open like Sun Haven; controls, inventory, combat and menus like Stardew Valley.

## Rules: before every push

- `bash tools/check.sh` (needs `godot` on PATH or `GODOT=...`). Never push if it fails. CI runs it too (6 shards via `tools/conduct/check_shard.py`; keep each check.sh block self-contained, no shared variables).
- Data generators changed? `bash tools/regen_data.sh` (never one generator alone before a commit); `tools/data_sync_check.sh` fails on drift.

## Core engineering conventions

- **Input:** everything goes through actions `up/down/left/right/a/b/menu` (+ `cycle_back`, `ability`, `pup`, `rally`) set up by `InputSetup`; `TouchControls` presses the same actions (no InputEvents), so UI that reacts to A/B/MENU must poll `Input.is_action_just_pressed` in `_process` (see Dialogue, GameMenu), never rely on `_unhandled_input`. After a dialogue/menu closes `Dialogue.input_blocked()` is true for a moment; gameplay A/B checks respect it. Drawn screens read taps through `TapInput.press_pos(ev)` / `is_release(ev)`. Button words via `InputSetup.prompt(action)` / `PadInput.words(text)` (never hard-code "Tap USE"). Button screens support pads via `ScreenCursor.make` or `PadFocus`.
- **Screens and pauses:** full-screen UIs pause the tree through `Hud.pause(tree, "owner")`, poll actions, close on B, and register on-screen Button rects in `Hud.extra_rects`; restore "was paused" only if `Hud.keep_paused(tree, self)` says so. Every menu has a way out as its last option (`Dialogue.is_way_out`). Cards owning the screen top join group `toast_hold` or `toast_under`. Taps >= 20 px, text never below 7 px (`tools/phone_ui_test.gd`, `tools/text_floor_check.py`).
- **Saves:** to `user://` via `SaveGame`; save slots via `GameState.save_key()` (never hard-code "run"). New `_migrate` step → bump `GameState.SAVE_VERSION`; new container run blocks go in `GameState.RUN_BLOCKS`. Settings live in SaveGame globals via `Settings` (fonts through `Settings.font(base)`).
- **Generators:** data that has a generator is never edited by hand: edit the generator (`tools/gen_*.py`, e.g. gen_stations, gen_gifts, gen_battles, gen_colonies, gen_skill_trees, gen_rec, gen_mega_new + gen_mega_regions, gen_community_farm, gen_romance, gen_collections, gen_decor, gen_wardrobe, gen_casino, gen_epilogue, gen_side_stories, gen_heart_perks), then `bash tools/regen_data.sh`. Grep TOOLS.md for the generator before touching any data/*.json.
- **Tests:** new gameplay gets a headless `tools/*_test.gd`, wired into check.sh as its own block (blank line before and after). Tests are deterministic: never wait on the wall clock; wait game time (`gt += root.get_process_delta_time()` per frame), run with `--fixed-fps 60`, call `seed(n)` in `_initialize`, fix mine layouts with `force_seed`.
- **Time:** gameplay timers use `PlayClock.now()/ms()` (game time, stops while paused), never `Time.get_ticks_msec()`. Day length is per save: `GameState.day_len()/minutes_per_second()`, real-time timers on the game clock via `GameState.real_min(sec)`; never a fixed minutes-per-second. Day/night via `GameState.sunset()/sunrise()/darkness()/is_night()`; never hard-code evening hours.
- **Money:** show amounts with `Money.fmt(n)`/`Money.sym()`; in new text `Money.amount(n)` / `Money.num(n)`; hand-drawn text (`draw_string`) through `Money.t`; money earned through `GameState.add_money(n, source)`. The gangster arc is cash ($).
- **Words:** item counts/articles through `ItemWords` (`count_id(id, n)`, `with_article(name)`, `fill`), never "%d %s" with item_name.
- **Decor:** decor/wear live in `run.decor` (never the bag; `Decor` API); every grant through `DecorSources.grant(m, id, n, source)`, never `add_item`.
- **Ranch:** `Ranch` (scripts/ranch.gd) is the ranching contract: data `data/ranch.json`, state `run["ranch"]` via `Ranch.st()`; code against its signatures (add functions, never change them); `rehome` instead of any death or sale for meat.
- **Rules owners:** difficulty touches combat and battle campaigns only (`Difficulty.mul/add`; foe hits via `GameState.enemy_damage`, allies via `Enemy.ally_damage`); move speed only via `MoveSpeed.calc`; chop/mine swings only via `GameState.hits_for/toughen/swing_damage`; haptics only via `Haptics.buzz(kind)`; sounds via `Music.sfx(name, fallback)` (sfx_audit fails on any missing sound), songs checked with `Music.has_track(t)`, song dips via `Music.set_duck_layer`.
- **Baked map drawing:** static map drawing is baked (GameMap BAKE_*): `draw_map` runs on a painter twin, so nodes made while drawing go through `prop()/anim_prop()/building()/_add_under()/under_layer()`, never `add_child()`. Ground-level props via `GameMap.to_under(node)`; never z_index -1. Many small polygons/lines go through `TriBatch`; respect `Art.clipped(rect)` / `clip_cells()`. Seasonal looks via `GameState.look_se()`.
- **Big shared files** (scripts/game_map.gd, game_state.gd, hud.gd, region.gd): keep edits small and surgical; prefer new scripts with small hooks.
- **Art pipeline basics:** sheets (Tom's uploads or dreams-image renders) land in `art/incoming/`; slicers (`tools/slice_*.py`, magenta key) write `art/gen/` + `manifest.json`, loaded by `Art` (scripts/art.gd). Art files are hardlinked across worktrees: never modify an existing file under art/ or audio/ in place (rm first, then write). After slicing: `python3 tools/art_audit.py --fix <ids>` (ids only), `python3 tools/make_seamless.py --check` (no bare re-run after the first slice), `tools/set_import_lossy.py`, then `godot --headless --path . --import`. Prompt files ask for at most 3 images each.

## Where things live

- `scripts/` all game code (GameState, GameMap, Hud, Region, farm.gd, house.gd, interior.gd, ...); `scenes/` one .tscn per map/area; `data/*.json` game data (mostly generated); `shaders/`, `fonts/`.
- `tools/` generators (gen_*.py), slicers (slice_*.py), headless tests (*_test.gd), shot/probe tools, `tools/conduct/` (CI, shards, code map, cluster), `tools/package/` (deliverable builders).
- `art/incoming/` uploads and renders (never delete), `art/gen/` sliced art + manifest; `audio/music`, `audio/sfx`, `audio/amb`; `reference/` Tom's uploads.
- `docs/`: HANDOFF.md (Baton, rules, log, CONDUCT operating rules), PROJECT-MEMORY.md, STATUS.md, TOOLS.md (catalog), CONDUCT-BRIEF.md (agent rules), INVENTORY.md + inventory.csv, guides/, reports/, src/ (prompt sources).
- `web/` web export patches; `server/` multiplayer relay; `.github/workflows/` CI (conduct-ci.yml).

## The five most-used tools

1. `bash tools/check.sh` - the full gate before every push (`CHECK_SHARD=i/N` for one shard).
2. `bash tools/conduct/ci_run.sh <label> [days]` - check.sh shards + 20 bots + scripted playtest on GitHub Actions; summary in /tmp/ci_<sha>/ and branch `ci-results/<sha>/`.
3. `bash tools/regen_data.sh` - runs every data generator in order.
4. `tools/area_shot.gd` - screenshot any spot: `xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/area_shot.gd -- /tmp/out scene:x:y` (ARC=gangsters env).
5. `tools/playtest.gd` - scripted playthrough with asserts and screenshots: `xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 540x960 -s res://tools/playtest.gd -- /tmp/shots` (delete `~/.local/share/godot/app_userdata/Dreams/save.json` first); look at the PNGs after gameplay changes.
