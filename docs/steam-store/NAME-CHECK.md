# Name check: "Dreams" (working title) and alternatives

Status: **Tom decides.** The working title stays "Dreams (working title)" everywhere until he picks. Not legal advice: before paying the Steam fee, run a clearance search on the chosen title (links below; a cheap professional search is advisable for a commercial release).

## Why plain "Dreams" should not ship on Steam (blocker)
- **Trademark:** Sony Interactive Entertainment Europe owns the live US mark DREAMS (Reg. 5362297; filed 2015-12-11, registered 2017-12-26) in class 9 (computer and video game software) and class 41 (online games): the exact word in the exact class (https://markinton.com/trademark/dreams-86846792). Media Molecule's Dreams is still sold and playable on PlayStation and in PS Plus after live support ended on 2023-09-01, so the mark is in use, not abandoned (https://docs.indreams.me/en/whats-happening/news/dreams-live-support).
- **Steam already has games named Dreams/Dream:** two "Dreams" by Vladlen Manshin (casual/indie sim, TBA: https://store.steampowered.com/app/4523470, https://store.steampowered.com/app/4214640) and "Dream" (HyperSloth, 2015: https://store.steampowered.com/app/229580).
- **Search:** Steam store search for "dreams" returns a crowded list, including an adult NSFW title next to it, so an all-ages game would sit beside adult content in search. "dream valley" is owned by Disney Dreamlight Valley; "dream farm" returns four farm games.

## Steam store search (tools/steam_name_search.py, 2026-11-20)
| term | results | top names |
|------|---------|-----------|
| dreams | 10+ | Shape of Dreams; hololive Dreams; Picayune Dreams; Dungeon Dreams 2; Jigsaw Puzzle Dreams; Dreams of Amelia [ADULT NSFW]; Cavern of Dreams; The Smurfs - Dreams; Mimpi Dreams; Dungeon Dreams |
| dream valley | 10+ | Disney Dreamlight Valley and its DLC |
| dream farm | 4 | Harvest Days: My Dream Farm; Dreamland Farm; Dream Fruit Farm; Professional Farmer: American Dream |
| hushfield, moonseed, crowns & crews, two too powerful, pillowfield, penguins & pinstripes, dreamfold | 0 each | - |

## Shortlist (recommended order)
Scored on: fit with the book and both arcs, keeping the dream/night motif (Dream skill path, Dreamwalk, dream scenes in both stories), and conflict risk. Web search on 2026-11-20 is not a legal clearance.

| # | Title | Fit (book / penguins / gangsters) | Dream/night tie | Steam search | Trademark/web search | Risk |
|---|-------|-----------------------------------|-----------------|--------------|----------------------|------|
| 1 | **Hushfield** | quiet-night valley + hush-hush underworld; works as an in-game valley name | yes (night) | 0 | only real place names (Brushfield, Huntingfield); no game or mark | low |
| 2 | **Moonseed** | night + farming; arc-neutral (crystals and cash both fit under a moon) | yes | 0 | no game or US mark MOONSEED; neighbours Starseed (app 1263170), Wildseed, MOONSHIRE (app 2542170) | low-medium (crowded moon/seed space) |
| 3 | **Crowns & Crews** | names both arcs directly: Pip-Pip's crown and the gangster crew | no | 0 | unrelated tabletop titles only | low |
| 4 | **Two Too Powerful** | straight from the book; the pun reads for crews too; weak on "farming" (needs a subtitle without Dreams as the main word) | no | 0 | nearest "Power of Two" (app 1479990), different words | low |
| 5 | **Pillowfield** | dream + field, coined; soft for the gangster arc | yes | 0 | itch "Pillow Valley", Epic "Mellow's PillowLand"; coined word, strong mark | low |
| 6 | **Penguins & Pinstripes** | playful mash of both arcs; doesn't say farming | no | 0 | "The Greatest Penguin Heist of All Time" (app 1451480) shares the penguin+crime theme | low-medium |
| 7 | **Dreamfold** | keeps the word for phone players ("two halves folded into one dream") | yes | 0 | no game found; Dreamwell (tabletop), The Dreamhold (2004 IF) | medium: leading "Dream" stays close to Sony's mark and the crowded Dream-farm space |

Optional bridge for current phone players: the new title on Steam and the title screen, with a small "formerly Dreams" line under the wordmark for one season (through GameInfo, see the rename plan).

## Rejected and why (do not re-propose)
- Any "Dream..."-led farm name: Everdream Valley (app 1403650), Dreamland Farm (app 3311730), Dreamer's Glade (app 3892560), Welcome to Dreamville (app 1682120), Dreamland (app 3521580), Dreams x2 (Vladlen Manshin); and Disney Dreamlight Valley owns "dream valley" search.
- "Twofold ...": an existing game and company (app 2509810).
- "Crystal & Cash": "Crystal Cash" is a slot machine, a gambling tie wrong for an all-ages game.
- "Dreambound": exists on itch.io.
- "Prismatica" (the dream-world name in the lore): a 2015 Steam game (app 377500).

## Checks still to run on the final pick (Chrome lane, no account needed; a step in docs/STEAM.md before "enter app name")
- WIPO Global Brand Database (https://branddb.wipo.int) for the final title and for DREAMS, classes 9 and 41.
- EUIPO eSearch (https://euipo.europa.eu/eSearch/), UK IPO (https://trademarks.ipo.gov.uk/ipo-tmtext), USPTO (https://tmsearch.uspto.gov).
- `python3 tools/steam_name_search.py "<title>"` and a Steam store search page check.
EU/UK/Japan registrations of DREAMS by Sony were not found by web search; Sony Europe owning the US mark makes a UK/EU filing likely, so check the registers.

## Steam name lock (gates the Steamworks session)
Steam lets the name change freely only until the store page passes pre-release review; afterwards a rename needs a support request with reasons (https://partner.steamgames.com/doc/store/editing/name). The name is entered in three places: Store info (Edit Store > Basic Info), Steamworks info (General Application Settings) and every Package name. So: the title is picked **before** "submit store page for review", the same title goes into all three fields, and no field may contain "(working title)".

## Rename plan (when Tom picks)
1. Store copy: change `TITLE` in tools/store_facts.py, run `python3 tools/store_facts.py` (every draft uses the {title} token).
2. Store art: render a new logo (docs/src/steam-capsule-prompts.md prompt 3) as art/incoming/steam/logo_<slug>.png, then `python3 tools/steam_capsules.py --logo art/incoming/steam/logo_<slug>.png` (all 12 assets rebuild in seconds; masters are text-free).
3. Desktop saves: set `application/config/use_custom_user_dir=true` and `custom_user_dir_name="Dreams"` in project.godot BEFORE the first Steam build (a stable internal id, so changing `config/name` later never moves desktop saves or the Auto-Cloud roots). Hook for the builds package (P1) / cloud notes (P2); not done here because it moves the dev-tool save path every test and CLAUDE.md quotes.
4. In-game title: the display title is hard-coded in about 15 player-facing places (title.gd label and Home Screen tips, save_transfer.gd messages, game_map.gd other-window toasts, the web shell's loader/update/rotate text and PWA name in export_presets.cfg + web/head_include.html). Plan: scripts/game_info.gd (`GameInfo.TITLE`) for scripts and a `{{TITLE}}` substitution in web/post_export.py for the web shell; never rename internal ids (save code prefix DRM, BroadcastChannel 'dreams', window.dreams*, cache 'Dreams-music-v1', font 'Dreams Symbols', the /Dreams/ repo path, the user dir id). Do this only after the pick.
5. Title-screen art: art/gen/ui/title_keyart has DREAMS painted in the sky and wordmark_glow/wordmark_moon carry the word. The new text-free key art (art/incoming/steam/key_wide.png) can become the wide title background with the wordmark overlaid (one title source for both layouts); on the pick, new wordmarks. Track the wordmark in docs/MISSING-ART.md only once a title is chosen.
