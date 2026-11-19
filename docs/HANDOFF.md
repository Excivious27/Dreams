# Dreams: Handoff (any Claude account)

Written 2026-11-18 so Tom's personal Claude account can do the same work as the Team account. Read this after `CLAUDE.md`, `reference/BRIEF.md`, the top of `docs/STATUS.md` and the newest guide in `docs/guides/`.

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
- **CONDUCT** = a fresh 20-agent audit, then a 20-bot playtest, then all recommended work Claude can do alone, then complete art prompt files for anything still needed plus a complete guide of what Claude needs from Tom.
- After every completed piece of work: deliver the full, up-to-date package (progress report, every art prompt file still needed, the complete all-in-one guide) as files sent directly in the chat, not only as repo links.
- Tom likes results details as a spreadsheet in the chat.

## Connecting a new Claude account (Tom, on his phone)

1. Pro or Max plan (Free allows one custom connector; two are needed).
2. Settings: code execution and file creation on; network all domains, or at least `github.com`, `objects.githubusercontent.com`, `opengameart.org`, `acemusic.ai`.
3. Customize → Connectors → GitHub → Connect as Excivious27 → Only select repositories: Dreams and dreams-image-mcp.
4. Customize → Connectors → + Add → Add custom connector: `ace-music`, `https://acemusic.ai/mcp`, OAuth → Connect → Allow (same ACE account).
5. Render → dreams-image-mcp → Environment → copy `MCP_AUTH_TOKEN`. Add custom connector: `dreams-image`, `https://dreams-image-mcp.onrender.com/mcp`, no sign-in, header `Authorization: Bearer <token>` (or URL `.../mcp/<token>` if no header field; keep it secret) → Connect.
6. Set the dreams-image and ACE tools to Always allow; turn all three on in the chat's + menu.
7. First message: "Work on my game Dreams in GitHub repo Excivious27/Dreams (also attach Excivious27/dreams-image-mcp). Read CLAUDE.md, docs/HANDOFF.md, reference/BRIEF.md, the top of docs/STATUS.md and the newest guide in docs/guides/. Save the working rules from HANDOFF.md to memory. Check the connectors with free calls only: ACE Music get_account, and dreams-image list_images on art/incoming. Then tell me you're ready, in a short reply."
