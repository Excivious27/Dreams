# Dreams: Handoff (any Claude account)

The shared memory between Tom's two Claude accounts (Team and personal). Tom switches between them when one hits a usage limit, without warning and without telling either chat, so every session keeps this file current on its own (rules in `CLAUDE.md`). Read it at the start of every session, after `CLAUDE.md`; for depth, `reference/BRIEF.md`, the top of `docs/STATUS.md` and the newest guide in `docs/guides/`.

## Tom's deliverables (every account, every time; Tom 2026-11-19)

Tom judges progress only by these. The Team account always gave them; the other account must too.

**Every reply** ends with: the play link https://excivious27.github.io/Dreams/ (after a push it auto-deploys), what changed, what to test, and at most one question, placed last. Phone-length.

**During long jobs (CONDUCT, agent rounds):** send Tom a short check-in (SendUserMessage) at least every 60 minutes: what finished, what's running, any problem (restarts, failures), the ETA. Watchdog every 30 minutes (see CONDUCT).

**At the end of every completed piece of work (each CONDUCT, each round, each big fix), the full package, sent as FILES in the chat (SendUserFile) and not only as repo links:**
1. **The complete all-in-one guide**: `docs/guides/GUIDE-NN.md` (next number). It must be **100% complete on its own**: every single thing still needed from Tom to finish the whole game, not only this round's delta. That includes taste calls, open story questions, accounts, uploads, art prompts still needed (or "none"), and how to test the latest changes. Carry over every still-open item from earlier guides.
2. **The progress spreadsheet** (.xlsx, Arial, header row styled): an Overview tab with **% complete for the whole game and % remaining**, plus % per area. A tab per system (from docs/inventory.csv: area, system, status, % done, % remaining, tests, notes). A tab for this round (area / found / fixed / test). A tab "Still needed from Tom". Template: tools/package/Dreams-Progress-CONDUCT-1.xlsx (built inline; tools/package/build_progress.py is the older builder).
3. **The report**: `docs/reports/CONDUCT-N.md` (or ROUND-N.md): found/fixed table, tests, what's left.
4. **Every art prompt file still needed** (max 2-3 images per prompt). Usually none, because the image tool makes the art; then say "no art prompts needed".
5. **The artifact page** (one hosted page with tabs: progress, guide, prompts, report): tools/package/build_final_page.py + page_template.html. Publish with the Artifact tool. Each account owns its own page: Team page `67cf3116-3dba-4920-801d-e0ebd5f7c947`. The personal account creates one on first use and records its id here. Personal account page: `020b3d87-1157-464f-ade4-cc0bd58ebe1c` (https://claude.ai/artifact/1Fe3QCxpCddzt5oDP2jZAs), built by tools/package/build_page_c2.py (arg = CONDUCT number; reads the guide, report, inventory.csv, plan.md and the playtest notes) + tools/package/build_progress_c2.py (xlsx; recalc with soffice for cached values).
6. The play link.

Update docs/INVENTORY.md and docs/inventory.csv first so the numbers are current.

## Baton (update on every push)

Whoever works next starts here. Keep it short and current; history goes in `docs/STATUS.md`; the whole project's context is in `docs/PROJECT-MEMORY.md`. Times in Pacific.

- **Last update:** 2026-11-19 21:05 PT, personal account.
- **Done:** CONDUCT 1-4 pushed (C4 report docs/reports/CONDUCT-4.md, Guide 28). CONDUCT CI optimisation done: `bash tools/conduct/ci_run.sh <label> 3` runs check.sh in 6 shards + 20 bots on GitHub Actions (~10 min, verify3 PASS); see HANDOFF CONDUCT section + PROJECT-MEMORY 3.
- **In progress:** CONDUCT 5 (home-world look and feel). 20 auditor reports: /home/claude/wt/c5_reports/*.md (copy in docs/reports/c5_audit/ when merged). 6 fix agents launched 20:55 (plan /home/claude/wt/C5_PACKAGES.md, worktrees /home/claude/wt/c5f_p1..p6, branches c5f/p1..p6, reports /home/claude/wt/c5f_reports/pN.md + .done); cap ~22:10.
- **Next step:** C4 package to Tom; when C5 agents finish: merge (merge_c.sh), local smoke, ci_run.sh c5, fix, push, C5 package; start C6 auditors (audio) at the C5 merge.
- **Jobs running elsewhere:** 6 C5 fix agents in the personal sandbox (lost on a switch: relaunch from C5_PACKAGES.md, which is also committed as docs/reports/C5-PACKAGES.md).
- **WIP branches:** none.
- **Open questions for Tom:** see PROJECT-MEMORY section 8.
- **Tom is waiting on:** the nine CONDUCT runs plus CONDUCT 10 (decor and cosmetics), CONDUCT 11 (ranching), CONDUCT 12 (writing), CONDUCT 13 (audio depth), CONDUCT 14 (aesthetics), CONDUCT 15 (seasons), CONDUCT 16 (progression), CONDUCT 17 (multiplayer), CONDUCT 18 (cutscenes) and CONDUCT 19 (trading cards), CONDUCT 20 (hazards, jumping/flight, lava mega region), CONDUCT 21 (The General Store side arc), CONDUCT 22 (polish + code cleanup), CONDUCT 23 (art direction), then the fully updated artifact.

## Decisions (newest first)

Anything Tom decided or answered in chat that the other account needs, one line each with the date.

- 2026-11-19 22:37 Tom (phone playtest): mining and harvesting are far too fast early: make the player work for it through progression; the watering can must need refilling; the "planted seeds" text stays stuck at the top of the screen; tapping the pup offers the Pack option before you own a pack; the inventory needs drag and drop; every inventory sorting option should match Stardew's exactly (polished, intuitive, optimised management). Fixes go into CONDUCT 6 as an extra package (P7); deeper pacing in C8.
- 2026-11-19 22:33 Tom: a complete review of all team, ally, crew, companion and pup functions so everything is seamless, intuitive and works as intended: CONDUCT 11b.
- 2026-11-19 22:30 Tom: the town should be expanded and embellished (bigger, richer): CONDUCT 14.
- 2026-11-19 22:27 Tom: an expansive tier-based marina by the beach; the beach region much larger; NPCs who work, sell, trade, give quests, provide passage to other regions (earned travel) and take you out fishing (charters); a sophisticated build integrated with the whole game: CONDUCT 14 (with the earned fast-travel tiers).
- 2026-11-19 20:03 Tom: real gambling is allowed (casino can use real betting, still all-ages tone), and real wine can be crafted and sold, but nobody drinks it: no drinking, no status effects (wines are trade goods, not food). Maison Dorée sells Sparkling Wine (sell/gift item). Supersedes the grape-cordial default.
- 2026-11-19 18:55 Tom: a major side arc for The General Store (his real store): massive outside and inside matching the real store and its departments (toys, upstairs trading cards, sports, disc golf, grills, drinkware, workwear, auto, hardware, power equipment repair, airsoft, model kits), the store's logo from generalstorespokane.com turned into pixel art with the image tool, fun non-serious quests tied to NPC routines, tiered upgrades (expand the upstairs card department etc.). No family/staff names; third-party brands replaced by invented names. CONDUCT 21; polish -> C22, art direction -> C23.
- 2026-11-19 18:48 Tom: hazards in hazardous regions (rising spikes, gaps to jump, rolling rocks, pouring lava), a new LAVA mega region, and a Sun Haven-style jump plus brief flight/glide that grows with progress tiers, themed to Dreams; embellished thoroughly; plus random tier-based hazards in mine floors (18:49): CONDUCT 20.
- 2026-11-19 18:43 Tom: make sure these have a run: dating/marriage (C7 build, C12 writing), quest tracker (done C3, polish C9), collections museum/shipping/fish logs (C8), haptics + save export/import (C9); then after the queue CONDUCT 22 polish pass (economy, menus, saves) + cleanup of the two biggest code files, CONDUCT 23 one consistent art direction; then the final package. See docs/CONDUCT-PLAN.md.
- 2026-11-19 18:24-18:25 Tom: add difficulty modes Very easy / Easy / Default / Hard that apply ONLY to combat and battle campaigns (everything else unchanged), and a day-length option in the opening (new game) menu: 15, 20, 30 or 40 real minutes per in-game day. Built in CONDUCT 4 as an extra package (settings per save slot, changeable later in Settings).
- 2026-11-19 17:39 Tom: a sophisticated, progressive, tiered fast-travel system that must be EARNED and feels organic (mine carts, planes, trains, clouds, boats, etc., not menu teleports). Planned in CONDUCT 14 (exploration/world) with pacing checked in CONDUCT 16.
- 2026-11-19 17:21 Tom added a trading card system: extremely sophisticated, booster packs to buy, trade with NPCs and other players, region-specific cards/sets, tiered and progressive, unified with the whole game. Planned as CONDUCT 19 (after C18, before the final package; multiplayer trading checked with C17's net layer).
- 2026-11-19 17:12 Tom answered the 31 Guide 11 story questions (defaults hold except as noted; feed into C3 campaigns, C7/C12 story, C11 helpers, C14 exploration): (1) Grumps were NOT pets: they were once crystals living in Crystopia (spelled C-R-Y-S-T-O-P-I-A); Meow Pow Wow turns them back. (2) The Dark Crystal uses his magic to persuade and convert crystals to his cause. (3) Pip-Pip's goal OK; Nova is inspired to use the Meow Pow Wow to spread love and joy through the whole universe, beyond defeating the Dark Crystal: kingdoms of happiness for all; Pip-Pip wants to help fulfil that dream. (4) Finargle queen default, but not too easy, with an expansive storyline: scenery and areas to explore. WHOLE GAME: great explorability, fun creative design, hidden areas, secret ways up/down, passages: artistically placed, not over the top. (5) Catkins was taught by the Star Crystal long ago; she is thousands of years old, from an ancient line of cat guardians who protect/preserve the Meow Pow Wow, practised as a spiritual way (Buddhism mixed with Avatar-style elemental philosophy): monasteries, meditations; expand that spirituality. (6) Big Jim gets a tail in the epilogue, hates it, then loves it over the top and becomes extraordinarily good at it with special abilities. (7) Tower bell default, but tie it into the story (the Star Crystal visits the hero at the beginning); ALL timelines must match, no plot holes, seamless plot. (8) default. (9) one story per colony + plenty of island side quests; lots of creative exploration, especially UNDERWATER: underwater caverns, glowing caves with different corals, unique items for new recipes. (10) yes. (11) the four elders, very old but youthful and sprightly like Catkins (ancient magic, like elves). (12) default PLUS the gangster arc's origin: you first set out to take down the gangs to restore peace, little by little built your own gang to fight them and were partly corrupted by fighting corruption; choices let you redeem your original purpose and recruit like-minded teammates. (13) default but a COOLER name than Walter Kestrel. (14) default. (15) default. (16) backstories OK; each lieutenant's special ability was bestowed by the Dark Crystal (a very late, hidden discovery). (17) yes, Inspector Hale. (18) default. (19) yes. (20) yes; AND every recruit/helper can be automated to tasks: farming, combat, foraging etc., with energy levels, work amounts, their own tiered levelling per skill, assignable to chests you place (they deposit into them); sophisticated but intuitive, not over the top; applies to any recruit/helper (plan: C11 with ranch helpers, base in C3/C7). (21-28) all side stories yes (romance already answered). (29) his daughter's ideas will keep coming; the main story Tom read (built with her) is the guiding spine of the penguin arc. (30) gentle sad scenes OK; most key Grumps are converted crystals, but include creatures beyond crystals too. (31) tone as is, EXCEPT add a CASINO side arc (gangster arc): a complex, progressive, tiered casino you bring into town against NPC pushback; expand it in stages, hire staff; its own side arc tied into the game's tier system (keep it all-ages: chips/tickets, no real-money themes). Planned: C7/C12 story, casino in C10-C16 window (see CONDUCT-PLAN).
- 2026-11-19 16:54 Tom answered Guide 26: (1) rename Whack-a-Grump/Duck Pond for the gangster arc; gangster arc starts with an arc-fitting weapon instead of a sword. (2) Community farm builds take a FEW DAYS each (prolonged, rich side arc). (3) Arcade/rec must take much longer than 3 months to finish: recurring renovation/expansion announcements keep adding new things (cabinets unlocking ~3 months is fine, the whole rec is not). (4) Prize Candy counts as loved gift for Candy lovers. (5) Gangster Rec Hall open to 2am. (6) Skee-Ball 10 OK. (7) default. (8) gangster danger tier gets its own song(s). (9) tools 30% OK. (10) try it. (11) yes, move greenhouse plot for house upgrades. (12) crisp pixel look, but must look smooth and clean, not blocky/choppy. (13) Tom will test. (14) meadow boss OK. (15) keep listed. (16) keep shops locking; homes open late to friends at 4+ hearts. (17) keep 7-day grace. (18) quest tracker: player picks the active quest from a polished quest-checkbox menu; a small, themed, unobtrusive corner pointer guides to the tracked quest all game; in the mines it always points to the way down. (19) yes. (21) wants the 31 Guide 11 story questions again (sent 16:57). (22) dating and marriage built in, G-rated like Stardew. (23) farm debris regrows and changes seasonally; lots of cuttable grass for fiber/animal food; audit regrowth rates of all items, tiered by rarity; story regions stay locked until their campaign is won, but campaigns build up slowly: easy simple early wins, clear tutorials, easy ally support/teammates, intuitive menus, fun not choppy, cozy not over the top.
- 2026-11-19 16:40 (Tom, answering C3 questions): (1) Penguin campaign enemies are Grump-themed, with MANY variants (not only the storm-cloud Grump): crystalline ones, violet ones crackling with lightning, etc., each with its own build, abilities and strengths (art via image tool). (2) Catkins must NOT lead every campaign and must not be met so early; rebuild the penguin arc to follow Tom's book (reference/) as the spine, with story branches built off it, embellished with lots of in-game content so it cannot be beaten fast (C3 starts with campaigns; C7/C12 carry the full story restructure). (3) Crystal babies can first appear as campaign enemies, but there must be a way to convert them to allies by proving your true purpose. (4) Every battlefield is themed to its own region: unique, no reused fields (art via image tool; C3 starts, C14 finishes).
- 2026-11-19 16:17: Tom: NO 5-hour waits unless he says otherwise. Run all queued CONDUCTs (3 through 18) back to back without pause, then the final package.
- 2026-11-19 15:54: Tom added CONDUCT 18: cutscenes across the whole game (art panels + staged NPC scenes, great writing), incl. an intro before the player starts showing Crystopia's backstory (the Dark Crystal, the corruption) for the penguin arc; quirky/funny side-quest scenes; big openings (arcade/Rec Center etc.). Order: C2-C9 (5 h waits), C10-C18, then the final package and artifact.
- 2026-11-19 15:52: Tom: Steam Deck compatible when published (aim for Verified); planned in CONDUCT 9 with controller support and the Steam build.
- 2026-11-19 15:50: Tom: full game controller support (Xbox layout) on computer and on phone (Bluetooth pad), single player and multiplayer; built in CONDUCT 9, checked per player in CONDUCT 17 (docs/CONDUCT-PLAN.md).
- 2026-11-19 15:16: Tom: the report, guide, progress sheet etc. must always be shared as an artifact in the chat (the published artifact page with every part), in addition to the files.
- 2026-11-19 15:13: Tom added CONDUCT 17 (multiplayer: full co-op review of the whole game, versus/co-op modes for bowling, Skee-Ball, arcade and more; after it Tom sets up a ~$4/month relay server and starts testing with friends). Order: C2-C9 (5 h waits), C10-C17, then the final package and artifact.
- 2026-11-19 14:32: Tom added CONDUCT 15 (seasons: unique festivals, holidays, events, seasonal items/quests) and CONDUCT 16 (progression and balance across every way to play: nothing too fast, unlocks take time and effort, quick/moderate/long goals, some big rewards only in year 2-3). Order: C2-C9 (5 h waits), C10 decor, C11 ranching, C12 writing, C13 audio, C14 aesthetics, C15 seasons, C16 progression, then the final package and artifact.
- 2026-11-19 14:27: Tom added CONDUCT 13 (audio depth: alternate area soundtracks, many seasonal alternates, full audit of every sound/song pairing) and CONDUCT 14 (aesthetic quality: graphics, region maps, boundaries, explorability, geography, smooth edges). Order: C2-C9 (5 h waits), C10 decor, C11 ranching, C12 writing, C13 audio, C14 aesthetics, then the final package and artifact.
- 2026-11-19 14:13: Tom added CONDUCT 12: a very thorough writing/story/dialogue pass across the whole game, both arcs, all lines cohesive with progress, NPCs, quests and storylines (docs/CONDUCT-PLAN.md). Order: C2-C9 (with the 5 h waits), C10 decor, C11 ranching, C12 writing, then the final package and artifact.
- 2026-11-19 14:06: Tom: some raised animals can be trained to join the team like Pup (part of CONDUCT 11).
- 2026-11-19 14:05: Tom: a massively sophisticated ranching/livestock ecosystem (coops, barns, classic animals plus bought/quest-earned exotics and fantastic creatures; gangster arc: genetically modified creatures), progressively tiered, with its own skill tree, unified with the whole game. Planned as CONDUCT 11 (see docs/CONDUCT-PLAN.md).
- 2026-11-19 14:01: Tom: desktop play must fill the screen properly (full screen on a computer); phones unchanged. In CONDUCT 2 fix package P8.
- 2026-11-19 13:46: Tom added CONDUCT 10 (after C9): decor and cosmetics ecosystem. A massive, tiered selection of furniture, art, decor, wallpaper, flooring, house exteriors, outdoor/farm decor, apparel and footwear, earned/bought/found/quest rewards, with a wide rarity spread from common to one-of-a-kind ultra rare; audit every place in the game it can plug in and how, then build it. Details in docs/CONDUCT-PLAN.md.
- 2026-11-19 13:36: Tom: keep going through ALL nine CONDUCTs start to finish (and the final package/artifact) without stopping. His phone playtest notes (20 items) are in docs/TOM-PLAYTEST-2026-11-19.md; each is assigned to a CONDUCT and must be done.
- 2026-11-19: CONDUCT process changed (standing rule): 20 read/play-only auditors (no code changes, no check.sh) → synthesize into 5-6 file-disjoint fix packages → 5-6 fix agents in parallel with targeted tests only (60-75 min cap) → one merge, one full check.sh, bots, playtest → full package. Target about 2-2.5 h per CONDUCT. Agents that were mid-run under the old process switch now (see Baton).
- 2026-11-19: Both accounts give Tom the same deliverables: a play link every reply, check-ins at least hourly on long jobs, and after every completed piece of work the full package (complete guide, progress xlsx with % done/% remaining, report, art prompts or 'none', updated artifact page) as files in the chat. See "Tom's deliverables".
- 2026-11-19: Watchdog: during every CONDUCT (and any agent/bot job), check all agents and bots every 30 minutes and restart anything stopped or stuck (details under CONDUCT).
- 2026-11-18: Default move speed stays as it is (Tom withdrew "twice as fast"); speed comes from gear, potions, foods, mounts and skills.
- 2026-11-18: Fishing only with the rod in hand.
- 2026-11-18: After Round 13: CONDUCT x3, wait 5 h, CONDUCT x3, wait 5 h, CONDUCT x3, each run aimed at specific parts of the game; then the fully updated artifact.
- 2026-11-18: Battle campaigns open only after natural lead-in (story chapter 2, training drill, team, provisions) with a clear briefing at the start.
- 2026-11-18: All art and all audio for every job must be generated and integrated: nothing outstanding at the end.
- 2026-11-18: Gangster arc uses cash, not crystals; gangster characters look serious, cool, dark underworld/cyberpunk, ages ~15-30, all-ages content.
- 2026-11-18: CONDUCT step 3 = every fix AND all open work Claude can do alone: all art, all audio, any work identified as needed anywhere.
- 2026-11-18: CONDUCT spelled out in full under Tom's commands; both accounts run it the same way.
- 2026-11-18: Handoffs are automatic; Tom never writes or sends one. Each chat keeps this file current itself.
- 2026-11-18: Both accounts use the same Claude Project instructions (below) so every new chat starts on Dreams.
- 2026-11-18: dreams-image default quality is high; 300 images/day through Nov 25, then 60.
- 2026-11-18: Multiplayer relay may go on Render (second Starter service); not decided or deployed.

## Log (newest first, 30 lines max)

One line per finished piece of work: date, account, what was done.

- 2026-11-19, personal: CONDUCT 2 merged and pushed (rec/arcade/commons + 8 fix packages: mines, movement, combat music, world, wording/skills/Meow Pow Wow, arcade/bowling, art crispness, desktop full screen).
- 2026-11-19, Team: handoff to personal account; CONDUCT 1 package delivered; CONDUCT tooling + brief committed (tools/conduct/, docs/CONDUCT-BRIEF.md).
- 2026-11-19, Team: CONDUCT 1 merged and pushed (20 agents: first 3 hours both arcs, phone UI font, performance batching, softlocks, saves, goal line, town, tools).
- 2026-11-19, Team: docs/PROJECT-MEMORY.md (full project context) + tools/setup_sandbox.sh; handoff rule: every push keeps PROJECT-MEMORY current.
- 2026-11-19, Team: CONDUCT 1 first merges (inventory, farm week, early gating, early combat).
- 2026-11-18, Team: Round 13 finished and pushed (10 jobs, bots + playtest clean).
- 2026-11-18, Team: handoff made automatic (CLAUDE.md rules, Baton, Decisions, Log, Project instructions).
- 2026-11-18, Team: HANDOFF.md created; dreams-image server deployed and connected; ACE Music connected.

## Claude Project instructions (same on both accounts)

Tom puts this text in a claude.ai Project called "Dreams" on each account, so every new chat in it starts on the game without him saying anything:

> This project is my game Dreams, GitHub repo Excivious27/Dreams. At the start of every chat, attach that repo (and Excivious27/dreams-image-mcp when the image server is involved), git pull, and follow CLAUDE.md, starting with docs/HANDOFF.md. Two Claude accounts take turns on this game without warning, so keep docs/HANDOFF.md current on every push as CLAUDE.md says, without being asked. Then do what I ask, or continue from the Baton's next step if I don't ask for anything specific.

## Where everything lives

| What | Where |
| --- | --- |
| Play link (web build, phone) | https://excivious27.github.io/Dreams/ |
| Game code, art, audio, docs | GitHub `Excivious27/Dreams` (public), branch `main` |
| Repo rules for Claude | `CLAUDE.md` |
| Setup brief | `reference/BRIEF.md` |
| Progress log | `docs/STATUS.md` (keep it current) |
| Latest all-in-one guide | newest file in `docs/guides/` (GUIDE-24 on Nov 18) |
| Image server code | GitHub `Excivious27/dreams-image-mcp` (private) |
| Image server (live) | `https://dreams-image-mcp.onrender.com` (Render, Starter plan) |
| Music | ACE Music (acemusic.ai), Creator plan, connector `ace-music` |
| Multiplayer relay | `server/` in this repo (not deployed yet) |

Godot 4.5.1, GDScript, portrait 270×480, nearest filter, touch D-pad + A/B/MENU, saves in `user://`, web export with threads off, deployed to Pages by GitHub Actions on every push to `main`.

## Work done so far (newest first)

| Date | Round | What it added |
| --- | --- | --- |
| Nov 19 | Round 13: audio fixes | Music streams on the web (57 of 61 songs had been silent), no silence while loading, 338 effects softened, footsteps match the real ground |
| Nov 18 | Round 12: art complete | 179 dreams-image renders + 12 redraws; Prompts 17–30 all drawn and sliced in |
| Nov 18 | Audio project | 61 ACE Music tracks, 45 ACE jingles, 306 CC0 effects (96 OpenGameArt packs), 40 ambience beds |
| Nov 18 | Round 11: Tom's playtest list | Region campaigns, CliffPainter cliffs, energy revamp, 26 mine layouts, farm river, tiered hills, Hero tab |
| Nov 18 | CONDUCT loops 1–10 | 20-agent audits + 20-bot playtests with fixes each loop |
| Nov 17 | Systems rounds | 134 crops, workshop/stations/vehicles/rocket, Gifts and the ten Marked, cyber stations, balance/feel/audio/multiplayer/QA passes |
| Nov 17 | Story | Penguin arc from Tom and his daughter's book (*The Two Too Powerful Penguins*); gangster arc all-ages |
| Nov 16 | Foundations | Scaffold, touch controls, web deploy, characters, open-world regions, art batches 04–11, writing round 1 |

In the game now: farm, town, beach, mountain, forest, lake, meadow, crystal meadow, outskirts, mines, moon and campaign-gated story regions; Stardew-style farming, tools, 134 crops, animals, seasons, villagers with hearts/gifts/birthdays/perks; two arcs (penguins: Pip-Pip and Nova, sanctuary, colonies; gangsters: Racket, heat, turf, heists, cyber) with their own stations, items and buildings; weapons, spells, guns (no blood), bosses, battles, campaigns, skill trees, Hero tab, endings; co-op up to 8 through the relay.

## State on 2026-11-18

- The Team account's game chat was running an art pass (building redraws w494+) through dreams-image. Only one account should push to `main` at a time.
- dreams-image: OpenAI image generation/editing that commits PNGs to `art/incoming/` (never overwrites). Default quality high. Limit 300 images/day through 2026-11-25, then 60/day; the limit is per server, shared by both accounts. Each result reports OpenAI usage.
- OpenAI is billed from Tom's linked ChatGPT balance; organization verification was still in review.
- Open items: image commits each trigger the test workflow (a skip-CI tag would save Actions minutes); relay not deployed (Render Starter is an option); OpenAI verification.

## Tom's commands

### CONDUCT

When Tom sends **CONDUCT** (alone or with a focus), run the whole cycle below to the end without stopping to ask, then deliver. It is the same on both accounts.

**How it runs (standing process, Tom 2026-11-19, optimized 20:18; target about 1.5-2 h between finished CONDUCTs).** The sandbox has 2 CPUs and one Godot lock: heavy runs (full check.sh, 20 bots) go to GitHub Actions (free 4-vCPU runners) through `tools/conduct/ci_run.sh`, never locally.

1. **20 auditors (read and play only, ~35-40 min).** 14 focus-area auditors + 4 regression auditors + 1 performance + 1 inventory/docs. Rules: docs/CONDUCT-BRIEF.md ("Auditors"). Each appends findings AS IT FINDS THEM to `/home/claude/wt/cN_reports/<id>.jsonl` (one JSON per line: id, area, severity blocker/major/minor/polish, title, files[], repro, fix, art_needed, audio_needed, needs_tom) and writes `<id>.done` at the end. Read-only auditors don't run Godot; playing auditors use short scripts under `flock /tmp/godot.lock`; nobody runs bots.sh or check.sh.
2. **Bots on CI** during the audit: `bash tools/conduct/ci_run.sh audit-cN 3` (6 check shards + 20 bots; summary in /tmp/ci_<sha>/summary.txt and on branch ci-results/<sha>/).
3. **Sort (~10 min):** `python3 tools/conduct/cluster.py /home/claude/wt/cN_reports N` writes cN_packages_draft.md (dedupe by files+title, file-disjoint packages, one owner for each big shared file: game_map.gd, game_state.gd, hud.gd, region.gd). Review it, add open work, art/audio and Tom's notes, commit it as docs/reports/CN-PACKAGES.md.
4. **5-6 fix agents in parallel**, branched from the merged, pushed main (worktrees via mkwt), 60-75 min cap, targeted tests only under flock (docs/CONDUCT-BRIEF.md "Fix agents").
5. **Merge once**, local smoke test only, then `ci_run.sh post-cN 3` (full check + 20 bots on CI). Fix what fails, push main (Baton), confirm deploy.yml deploys. Build the package while the post-merge CI run works.
6. **Pipeline:** when the fix agents finish and the merge starts, launch the NEXT CONDUCT's 14 focus auditors on a snapshot worktree of origin/main; launch its 4 regression auditors + performance + inventory auditors only after the merge is pushed.
7. **Deliver the full package** (Tom's deliverables) with a timing table (audit, sort, fix, merge+CI, package, total, gap since the last CONDUCT ended). Short reply ending with the play link.

**Fallbacks:** if CI results don't appear on ci-results within 45 min, ci_run.sh tries `gh run download`; if that fails it exits 3: run check.sh and bots.sh locally as before (note it in the Baton).

**Watchdog (Tom, 2026-11-19):** while any agents or bots run (in a CONDUCT or any other job), check on every one of them **every 30 minutes**: is it still working (recent tool use, commits, log output), stuck, or stopped (for example after a server restart)? Resume stopped agents from their transcript (or re-create them with the same scope if they can't be resumed), restart dead bot/test runs, and note it in the Baton. Use the session's scheduled-message tool (send_later, 30 minutes) to wake yourself for each check, and schedule the next one at every check until all agents are done. Never let avoidable downtime build up.

If a usage limit ends the chat mid-CONDUCT, the Baton says which step it reached; the next chat (either account) carries on from there.

### HANDOFF

Optional: finish or park the current step, push, fill in the Baton, reply with a 3-line summary. Handoffs happen automatically anyway.

## Tom's working rules (from the Team account's memory)

- Tom works only from his phone, never a computer. Short replies ending with the play link, what changed and what to test; one question max, last. Never ask him to run commands.
- Run `bash tools/check.sh` before every push; never push if it fails.
- Design: every region expansive and open like Sun Haven (organic edges, not fenced boxes); controls, inventory, combat and menus exactly like Stardew Valley (keys and mobile); the farm starts like Stardew (empty house with bed and dresser, overgrown field, no animals or buildings).
- "100% done" means a polished, Stardew-grade commercial release (Steam later). Depth rounds in order: writing, balance, art, feel, audio, multiplayer hardening, QA/Steam.
- Art prompt files: each prompt asks for at most 2–3 images (ChatGPT breaks on more), every image labeled and separated, nothing left out. Original characters and art only. Never delete Tom's uploads (`reference/`, `art/incoming/`).
- Penguin arc: *The Two Too Powerful Penguins*; Pip-Pip (crowned) and Nova (wizard hat) are the pair, not a male/female variant. It has its own stations and buildings, matching the gangster side.
- Gangster arc: guns fine, no blood or graphic violence, no drugs, prostitution or other mature content; its own items, armor, weapons, stations and buildings.
- Every craft station and building is crafted or purchased by the player, gated by tier; none given free.
- Music comes from ACE Music: Claude sends song prompts after Tom approves, fetches the songs and places them.
- All art and audio a piece of work needs is generated (dreams-image, ACE Music, CC0) and integrated by Claude, with nothing left outstanding.
- After every completed piece of work: deliver the full, up-to-date package (progress report, every art prompt file still needed, the complete all-in-one guide) as files sent directly in the chat, not only as repo links.
- Tom likes results details as a spreadsheet in the chat.

## Connecting a new Claude account (Tom, on his phone)

1. Pro or Max plan (Free allows one custom connector; two are needed).
2. Settings: code execution and file creation on; network all domains, or at least `github.com`, `objects.githubusercontent.com`, `opengameart.org`, `acemusic.ai`.
3. Customize → Connectors → GitHub → Connect as Excivious27 → Only select repositories: Dreams and dreams-image-mcp.
4. Customize → Connectors → + Add → Add custom connector: `ace-music`, `https://acemusic.ai/mcp`, OAuth → Connect → Allow (same ACE account).
5. Render → dreams-image-mcp → Environment → copy `MCP_AUTH_TOKEN`. Add custom connector: `dreams-image`, `https://dreams-image-mcp.onrender.com/mcp`, no sign-in, header `Authorization: Bearer <token>` (or URL `.../mcp/<token>` if no header field; keep it secret) → Connect.
6. Set the dreams-image and ACE tools to Always allow; turn all three on in the chat's + menu.
6b. First message in a new sandbox, Claude runs `bash tools/setup_sandbox.sh` itself (installs Godot 4.5.1 headless and Python deps, first import); Tom does nothing.
7. Create a Project called "Dreams" and paste the Claude Project instructions above into it. Start every Dreams chat inside that Project; no first message is needed beyond what Tom wants done.
