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
5. **The artifact page** (one hosted page with tabs: progress, guide, prompts, report): tools/package/build_final_page.py + page_template.html. Publish with the Artifact tool. Each account owns its own page: Team page `67cf3116-3dba-4920-801d-e0ebd5f7c947`. The personal account creates one on first use and records its id here.
6. The play link.

Update docs/INVENTORY.md and docs/inventory.csv first so the numbers are current.

## Baton (update on every push)

Whoever works next starts here. Keep it short and current; history goes in `docs/STATUS.md`; the whole project's context is in `docs/PROJECT-MEMORY.md`. Times in Pacific.

- **Last update:** 2026-11-19 16:30 PT, personal account.
- **Done:** Round 13, CONDUCT 1, CONDUCT 2 (merged and pushed: 20 area agents + 8 fix packages covering Tom's 21 playtest notes; check.sh rc 0, 20 bots clean, playtest 0 failures; report docs/reports/CONDUCT-2.md, guide docs/guides/GUIDE-26.md, progress xlsx + artifact page sent in chat).
- **In progress:** nothing between CONDUCTs; CONDUCT 3 (battle campaigns) starts next with the new process.
- **Next step:** CONDUCT 3 (battle campaigns): 20 read-only auditors + 20 bots -> 5-6 fix packages (include C2 leftovers that fit: see docs/reports/CONDUCT-2.md "Still open") -> merge, check.sh, bots, playtest, push -> package (artifact + files). Then wait 5 h, CONDUCT 4-6, wait 5 h, CONDUCT 7-9, then CONDUCT 10-17 (docs/CONDUCT-PLAN.md), then the final package. Tom's playtest notes: docs/TOM-PLAYTEST-2026-11-19.md.
- **Jobs running elsewhere:** none.
- **WIP branches:** none.
- **Open questions for Tom:** see PROJECT-MEMORY section 8.
- **Tom is waiting on:** the nine CONDUCT runs plus CONDUCT 10 (decor and cosmetics), CONDUCT 11 (ranching), CONDUCT 12 (writing), CONDUCT 13 (audio depth), CONDUCT 14 (aesthetics), CONDUCT 15 (seasons), CONDUCT 16 (progression) and CONDUCT 17 (multiplayer), then the fully updated artifact.

## Decisions (newest first)

Anything Tom decided or answered in chat that the other account needs, one line each with the date.

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

**How it runs (standing process, Tom 2026-11-19; target about 2-2.5 hours per CONDUCT).** Agents must not each run the full check.sh: the sandbox has 2 CPUs and one Godot lock, so 20 full suites queue for hours.

1. **Fresh 20-agent audit (read and play only, about 40 min).** Start 20 new sub-agents (never reuse earlier findings), each on a different part of the game or of this CONDUCT's focus: systems, story and writing (both arcs), balance and economy, UI and controls vs Stardew, maps vs Sun Haven openness, art consistency and missing art, audio, performance on phone and web, multiplayer, saves and migrations, bugs and crashes, plus regression checks of the last CONDUCT. Auditors read code and data, play their area by short scripts, take screenshots and look at them. They may write a small focused test or probe that reproduces a finding. They do **not** change game code and do **not** run tools/check.sh. Each returns a findings list: what's wrong, where (file/function), how to reproduce, a suggested fix, art/audio needed, and anything only Tom can decide.
2. **20-bot playtest** (`tools/bots.sh 3 DIR`) plus the scripted playtests (`tools/playtest.gd`, story, co-op), run while the auditors work or right after; look at the screenshots and add every failure and oddity to the list.
3. **Synthesize (main chat).** Merge and dedupe all findings. Group them into **5-6 fix packages, each owning separate files/systems** so no two packages edit the same thing. Add all open work Claude can do alone (Baton, STATUS.md, guides, MISSING-ART.md, plans agreed but not started), including art (dreams-image) and audio (ACE Music, CC0).
4. **5-6 fix agents in parallel** (worktrees via tools/conduct/mkwt.sh), one package each, with a 60-75 minute cap. Each fixes its package fully, adds or extends tests for what it fixed, makes and wires in the art and audio its package needs, runs **only its own targeted tests** (under `flock /tmp/godot.lock`), commits, and reports. The main chat may take a package itself.
5. **Merge once** (tools/conduct/merge_c.sh), then one full `tools/check.sh`, then the 20 bots and the playtest again. Fix what they find, push (Baton updated), confirm the web deploy is live.
6. **Deliver the full package** (see "Tom's deliverables" at the top: the 100%-complete guide, the progress xlsx with % done and % remaining, the report, art prompts or "none", the updated artifact page) as files in the chat.
7. Short reply ending with the play link, what changed and what to test.

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
