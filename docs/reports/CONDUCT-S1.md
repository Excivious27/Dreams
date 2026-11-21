# CONDUCT S1 report: Steam prep, no account needed (2026-11-20)

Everything for Steam that can be built before Tom's Steamworks account exists: Windows and Linux builds in CI, GodotSteam behind a safe service (the game runs the same with no Steam), 60 achievements with a title-screen list, rich presence, a Steam co-op transport, Steam Deck readability and controller-only play, desktop window options, a Steam Input config draft, the upload pipeline (switched off), store text, capsule art, screenshots, a trailer job, ratings and AI disclosure drafts, a name check, and docs/STEAM.md, a one-session brief for the day the account is ready. 18 focus auditors (264 findings) fed 6 fix packages (docs/reports/S1-PACKAGES.md, scopes in docs/reports/S1-SCOPES.txt), then one integration pass. **Final full CI s1i2: PASS (6 shards, 20/20 bots, playtest, live relay, net e2e, Deck perf ok). steam-builds: all green (Linux, Windows, web export unchanged at 135.6 MB).**

**Steam readiness: about 92% done, 4% staged waiting on the account, 4% not started.** 15 of 18 spec items fully done, 3 done with a part waiting (co-op live test, controller glyphs, trailer render). Every account step is staged and listed in docs/STEAM.md. The web/phone build is unchanged (guarded by tools/web_export_guard.py and the web-export job).

**Whole game after S1: about 81% done, 19% remaining** (average of the 93 systems in docs/inventory.csv). Ten new Steam rows (GodotSteam service 85%, web guard 95%, desktop options 88%, Steam Input 70%, achievements 88%, rich presence 75%, Steam co-op 70%, upload pipeline 80%, store materials 85%, ratings drafts 85%); Steam desktop builds rose from 0% to 95%, the Deck/Linux build from 60% to 85%.

## Audit (18 focus auditors, 264 findings: 8 blocker, 121 major, 93 minor, 24 polish, 18 verified-clean notes)

| Area | Main findings |
|---|---|
| Builds, GodotSteam (01-02) | Only a Linux preset; no Windows build, boot test, sizes or version; web pack shipped server/ files; no Steam code at all yet. |
| Achievements, backends (03-05) | Nothing existed; saves path follows the game name; no rich presence; notes list grows without limit (cloud size). |
| Co-op transport (06) | Relay code tied into net.gd; no protocol version check (old builds could join new ones); no Steam lobby path. |
| Deck screens and input (07-08) | 858 text items under Valve's 9 px floor at 1280x800; no typing with a pad; keyboard words shown to pad players; OS file dialog on the Deck. |
| Controller config, perf, desktop (09-10) | No Steam Input config; Deck fullscreen opened as a 540x960 window; no VSync/frame cap, scaling or remembered window. |
| Upload, handoff, ratings (11, 13, 17) | No SteamPipe files or workflow; beasts dropped meat/pelts (animal rule); credits named family; casino needs a ratings call. |
| Store materials (12, 14-16) | No store text, capsule art or shots; "Dreams" clashes with Sony's live US trademark. |
| Web safety (18) | Steam files must never reach the web pack (140 MB gate, 135 MB now). |

## Fix packages

| Package | Fixed |
|---|---|
| P1 Builds, GodotSteam, web safety | Windows Desktop preset beside Linux; new steam-builds.yml (both builds, sizes, first launch, headless boot on Linux and Windows, GodotSteam load probe); `SteamSvc` autoload + `SteamApi` facade with safe no-ops off Steam; `BootProbe` boot test; GodotSteam 4.24 fetched and pinned (desktop only); web_export_guard (static + pack scan); steam_appid.txt never shipped; version 0.9.0. |
| P2 Achievements, backends | 60 achievements (data/achievements.json from gen_achievements.py) + 17 stats; `Achievements` scans saved state, so old saves unlock too; title "Achievements n/60" list; `Presence` rich presence tokens; save codes carry achievements; notes capped at 40; 120 icons + 120 Steam 256 px masters (5 renders). |
| P3 Deck readiness | Deck 9 px text floor (858 -> 0); pad typing (`TextEntry`, `PadKeyboard`, Steam keyboard when present); Deck button names; pad words in dialogue and menus; backup list instead of a file dialog; desktop rows: fullscreen, scaling (smooth / pixel-perfect), VSync, frame cap, pause when inactive, remembered window. |
| P4 Steam co-op, controller config, perf | `NetTransport` split (WebSocket relay unchanged for web/phone; `NetTransportSteam` lobbies + Steam networking; `NetTransportLoop` test twin; `NetRelayRoom` one copy of the room rules); protocol version check (relay answers old_build); Steam invites; Steam Input draft VDF; Deck perf check; Deck fullscreen fixed. |
| P5 Upload pipeline, handoff, ratings | steam/ SteamPipe templates + config (off); steam-upload / steam-login / steam-kit workflows (manual, off); docs/STEAM.md built by steam_handoff.py (22-step Chrome brief); ratings, IARC and AI disclosure drafts; beasts run off instead of dropping meat (animal_rule_test); name filter; Credits and licences page. |
| P6 Store materials | docs/steam-store/: short and long descriptions, bullets, tags, pricing, store fields, system requirements, claims gate; 12 capsule/library/icon assets (9 renders) + checker; 11 1920x1080 screenshots; 46 s trailer script + render job; name check with 7 alternatives. |
| Integration (22:10-23:05) | Fixed the real break: packages looked up `/root/SteamService` but the autoload is `SteamSvc`; all SteamSvc hooks wired (keyboard, input type, overlay, invites, achievement replay); one co-op presence token; title Play together Steam branch; Deck window 1280x800; CI env DREAMS_NO_STEAM=1, Deck perf step, metrics.json, trailer job; 3 integration regressions fixed. |

## Timing

| Stage | Role | Effort | Minutes |
|---|---|---|---|
| Auditors (18 focus, read/play-only), 19:55-21:00 PT | auditor | medium | ~65 |
| Package plan (hand-built, 264 findings into 6 packages) | conductor | medium | in the 21:00 hand-off |
| Fix agents P1-P6 in parallel, 21:00-22:10 | fixer | medium | ~70 |
| Integration (merge, hooks, regen, CI), 22:10-23:05 | integrator | medium | ~55 |
| Package build (report, guide, progress, page) | packager | low | ~10 |
| **Total** | | | **~200 wall clock (19:55-23:15)** |
| Agents per effort | | | 18 medium auditors; 6 medium fixers; 1 integrator |
| CI first-run result | | | s1i FAIL (c11b_integ_test, campaign_map_test: integration regressions, fixed); s1i2 PASS; steam-builds first run FAIL (Deck boot window 1279x720, fixed to 1280x800), re-run all green |
| CI minutes | | | ~12 package subset runs + 2 full runs x ~14 min + 4 steam-builds runs |
| Images used | | | ~14 (5 achievement sheets + 9 store art) |
| ACE credits used | | | 0 |

## Steam readiness (S1 spec items)

| # | Item | Done | Staged, waiting on account | Not started | % |
|---|---|---|---|---|---|
| 01 | Windows/Linux builds, CI, sizes, boot test | yes | | | 100 |
| 02 | GodotSteam + SteamService, safe no-ops | yes | live test with the real App ID | | 90 |
| 03 | Achievements, part A | yes | entry in Steamworks | | 90 |
| 04 | Achievements, part B + title list + icons | yes | icon upload | | 90 |
| 05 | Backend switch, cloud paths, rich presence | yes | Auto-Cloud + presence upload | | 90 |
| 06 | Steam co-op transport | in code, tested with a fake Steam | two-account live test | physics interpolation | 75 |
| 07 | Deck readability | yes | | | 100 |
| 08 | Controller-only + Steam keyboard | yes (word prompts) | Deck keyboard check | icon glyphs | 85 |
| 09 | Steam Input config + perf | yes (Deck perf ok in CI) | official config + Deck review | | 90 |
| 10 | Desktop window/display | yes | | | 100 |
| 11 | Upload pipeline | yes, switched off | builder account + secrets | | 90 |
| 12 | Store text | drafts | | | 95 |
| 13 | Ratings + AI disclosure | drafts | | casino decision (Tom) | 90 |
| 14 | Capsule art | 12 assets | | logo after the title pick | 95 |
| 15 | Screenshots + trailer | 11 screenshots, trailer job | | trailer not rendered yet | 80 |
| 16 | Name check | 7 alternatives | | title pick (Tom) | 90 |
| 17 | Steamworks handoff brief | docs/STEAM.md | | | 100 |
| 18 | Web build safety | guard + web-export job | | | 100 |
| | **Overall (average)** | | | | **~92** |

Split: **done 92%, staged waiting on the account 4%, not started 4%** (the missing points of each row, added up across the 18 items).

## Still open
- Account steps (all in docs/STEAM.md "When Tom's Steamworks account is ready"): App ID, depots, achievements and stats entry, Auto-Cloud, rich presence, Steam Input official config, builder account and GitHub secrets, store fields, content survey, pricing, release date, Deck review.
- Controller icon glyphs (words only today; Valve accepts matching names).
- Physics interpolation for smooth motion at high refresh rates (own package).
- Trailer: the job is wired (Run workflow > trailer) but not run yet.
- Wide-screen interior zoom; title wide art still shows the painted DREAMS word plus the wordmark (fix after the title pick).
- Town sign clipping, Neon's empty east third, Orchard Hills pale overlay (world drawing; store shots avoid them).
- Achievements unlock at the next save, not the exact moment inside battles and minigames.
- Web service worker is empty (pre-existing; a web item, not Steam).
- Remote branches ci/s1p1web-eba24970a and wip/c11bp4-nofarm can be deleted (the sandbox was not allowed to).

## Tom's decisions (defaults kept until he answers)
1. **Title.** Sony owns the live US trademark DREAMS for video games, so plain "Dreams" should not go on Steam. Seven alternatives, best first: **Hushfield**, Moonseed, Crowns & Crews, Two Too Powerful, Pillowfield, Penguins & Pinstripes, Dreamfold. Default: "Dreams (working title)" until he picks. Full notes: docs/steam-store/NAME-CHECK.md.
2. **Casino (gangster arc).** A: keep real casino games (likely PEGI 18). B: fantasy reskin with invented games (likely PEGI 12, recommended). C: switch it off in Steam builds (PEGI 12). Default: no change until he picks. docs/steam-store/ratings.md.
3. **Studio name** for Developer, Publisher and the credits line. No default.
4. **Price.** Draft $19.99 with a 15% launch discount for 7 days ($16.99). docs/steam-store/pricing.md.
5. **Uploader account inbox.** An email inbox for a limited Steam builder account that uploads builds (optional phone for Steam Guard). No default.
