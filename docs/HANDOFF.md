# Dreams: Handoff (any Claude account)

The shared memory between Tom's two Claude accounts (Team and personal). Tom switches between them when one hits a usage limit, without warning and without telling either chat, so every session keeps this file current on its own (rules in `CLAUDE.md`). Read it at the start of every session, after `CLAUDE.md`; for depth, `reference/BRIEF.md`, the top of `docs/STATUS.md` and the newest guide in `docs/guides/`.

## Baton (update on every push)

Whoever works next starts here. Keep it short and current; history goes in `docs/STATUS.md`; the whole project's context is in `docs/PROJECT-MEMORY.md`. Times in Pacific.

- **Last update:** 2026-11-19 09:35 PT, Team account (game chat), HANDOFF to the personal account (Team near its usage limit).
- **Done:** Round 13 and CONDUCT 1 of 9 (merged, check.sh rc 0, bots + playtest clean, pushed; report docs/reports/CONDUCT-1.md, guide docs/guides/GUIDE-25.md, spreadsheet sent to Tom).
- **In progress:** nothing. CONDUCT 2 had just been launched and was STOPPED within minutes for this handoff; no work from it exists. Start CONDUCT 2 fresh.
- **Next step:** CONDUCT 2 (rec center, arcade, community farm). Scopes: docs/CONDUCT-2-SCOPES.txt (20 lines). Agent brief: docs/CONDUCT-BRIEF.md (copy to /home/claude/wt/BRIEF_CONDUCT.md; set worktree ids c2_NN). Tooling: tools/conduct/mkwt.sh `<id> <branch>` makes a hardlinked worktree under /home/claude/wt (copy the scripts to /home/claude/wt first; they use absolute paths /home/claude/dreams and /home/claude/wt), tools/conduct/merge_c.sh merges branches and only auto-resolves CLAUDE.md/STATUS.md/HANDOFF.md, json_merge.py for JSON conflicts (check both sides on string conflicts: it keeps "ours"). Watchdog every 30 min (send_later). After CONDUCT 2: CONDUCT 3 (battle campaigns), then wait 5 h, CONDUCT 4-6, wait 5 h, CONDUCT 7-9 + full package and a new artifact page on the personal account (record its id in PROJECT-MEMORY).
- **Jobs running elsewhere:** none (the Team chat may still fire one stale watchdog reminder in its own session; ignore).
- **WIP branches:** none.
- **Open questions for Tom:** see PROJECT-MEMORY section 8.
- **Tom is waiting on:** the nine CONDUCT runs, then the fully updated artifact.

## Decisions (newest first)

Anything Tom decided or answered in chat that the other account needs, one line each with the date.

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

1. **Fresh 20-agent audit.** Start 20 new sub-agents (never reuse earlier findings), each auditing a different part of the game: systems, story and writing (both arcs), balance and economy, UI and controls vs Stardew, maps vs Sun Haven openness, art consistency and missing art, audio, performance on phone and web, multiplayer, saves and migrations, bugs and crashes. Each lists concrete work or fixes Claude can do.
2. **20-bot playtest.** Run the bot harness (`tools/bots.sh`, 20 bots) plus the scripted playtests (`tools/playtest.gd`, story, co-op), look at the screenshots, and add every failure and oddity to the list.
3. **Do every fix AND all open work Claude can do alone:** all art work, all audio work, and any and all work identified as needed on the game in any way (from the audit, the bots, the Baton, STATUS.md, the guides, MISSING-ART.md, plans agreed but not started). That includes code, data, writing, balance, and generating and wiring in art and audio (dreams-image, ACE Music, CC0), so nothing Claude can do is left outstanding. Push in small steps, check.sh before every push, Baton updated each time.
4. **Re-verify.** Rerun check.sh, the playtests and the bots on the finished code; fix what they find; confirm the web deploy is live.
5. **Deliver the full package, 100% complete and up to date,** as one artifact and as files sent directly in the chat (not only repo links):
    - progress report file (what the audit and bots found, what was fixed, what is still open and why);
    - every art prompt file still needed (only what the image tool couldn't make; at most 2-3 images per prompt, each labeled and separated, nothing left out);
    - the complete all-in-one guide of everything Claude needs from Tom (next `docs/guides/GUIDE-NN.md`).
6. Short reply ending with the play link, what changed and what to test.

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
