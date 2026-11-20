# CONDUCT 9 report: Release readiness (2026-11-20)

The fifth CONDUCT on the optimised process. 20 read/play-only auditors (c9_01..20, 189 findings) fed 6 file-disjoint fix packages (docs/reports/C9-PACKAGES.md, scopes in docs/reports/C9-SCOPES.txt): controllers, menus and accessibility, full-screen screens with a pad, haptics + Steam Deck + the web build, save codes/files, and performance/world/co-op. Everything was merged once and checked on GitHub Actions (check.sh in 6 shards, 20 bots, the scripted playtest with screenshots): C9 passed on run c9c after two CI fix rounds.

**Whole game after CONDUCT 9: about 74% done, 26% remaining** (average of the 63 systems in docs/inventory.csv). Controllers 75 -> 92%, saves 90 -> 95% (save codes and files), web build 90 -> 92%, co-op 55 -> 68%, and three rows now counted: haptics 88%, Steam Deck / Linux 60%, accessibility and Options 88%. Systems for later CONDUCTs (hazards/lava C20, General Store C21, marina C14) still count at 0%.

## Audit (20 auditors, 189 findings: 1 blocker, 54 major, 89 minor, 45 polish)

| Area | Main findings |
|---|---|
| Controllers (01-02) | No pad bindings at all, touch pad never hid on a pad, toolbar only forward, rally/pup strip touch-only, no remap, prompts always said "Tap". |
| Steam Deck / desktop (03) | No Linux preset, UI 40% smaller at 1280x800, wall-clock timers, no pause on focus loss, mouse cursor always shown. |
| Haptics (04) | No vibration anywhere (phone, web or pad). |
| Saves (05-06) | Save codes overwrote a farm without asking, lost the Restore farm, no files, no version/check, no real paste on phones, null run blocks and a letter flood for old saves. |
| Accessibility (07) | Text size didn't reach most screens, no text speed, toasts too fast, colour-only cues (rarity, ally/foe bars, danger pips), flashes, Options in one long list. |
| Quest tracker (08) | Spouse job target, needle through walls, mega route home, caption overlap. |
| Performance (09, 19) | Web pack 123 MB, forest +33% nodes from 1034 border-tree sprites, a "300 ms hitch" (probe walking off the map). |
| Tests and flakes (10, 12, 18) | hearts_test rc134, toast_layout serial failure, menu toggle during a map fade. |
| Co-op (11) | Guests saw their own world keys (romance, spouse, cfarm, mega, tickets), relay overwrite, full snapshots. |
| Web deploy (12) | **Blocker:** the web build had not deployed since 04:28 (cancelled/failed runs); Sample playback, Android back, phone fullscreen, offline launch, icons. |
| World look (13-14) | Tiered meadow hill flat, forest band too bright, winter pond edges, sky hub band, rec visitors overlapping. |
| Data sync (17) | Generators gave different output depending on run order. |
| Checklist (15-20) | Smaller text, test and doc items. |

## Fix packages

| Package | Fixed |
|---|---|
| P1 Controller core | `InputSetup.PAD_DEFAULTS` (every action on a pad, LB/RB toolbar both ways, LT dodge, RT partner, R3 pup, L3 rally), `PadInput` (device/family, hot-plug, touch pad hides on a pad and returns on a tap, analog walk curve, list repeat, rumble), pad remap API, `InputSetup.prompt(action)` button words, `PadFocus`/`PadCursor`, hack and creator pad paths, scaled pup strip/stick. New pad_test. |
| P2 Menus, Options, accessibility | GameMenu cursor on all tabs (LB/RB tabs, B steps back a page), Controller buttons page, keyboard rebind warns before stealing, Options grouped (Sound / Display and controls / This farm), Larger text, text speed, message time, reduced motion and flashes, timing help (fish window x1.5), rarity dots and framed ally bars, Save and quit on computers, Back up this farm, Android fullscreen row. New menu_pad_test. |
| P3 Screens with a pad | `ScreenCursor` for Button screens; chest (X pick/put), craft (quantity, MAKE), campaign board, prize counter (all rows reachable), map pins, arcade/bowling decks hide on a pad, left-handed decks, shake off in arcade, gangster blurbs, toasts held over Craft/Chest. New screens_pad_test. |
| P4 Haptics, Deck, web | Deploy fixed (no cancels, skips unchanged builds, light gate), offline launch, maskable icons, music streamed on web, fight music in the pack, Android back, phone fullscreen, "turn your phone upright" card, update banner at the bottom; Linux preset + CI export, Deck fullscreen/touch/cursor, pause on focus loss, `PlayClock` game-time timers, docs/STEAM-DECK.md; `Haptics` (phone, web, pad rumble; whitelist from Music.sfx names; Options rows). New haptics_test. |
| P5 Saves and tracker | `SaveTransfer`: DRM2 codes (version + check), forgiving paste, strict validation, confirm card before overwrite, Restore kept, save/load files, back up all farms (DRMALL), honest write errors (`SaveGame.flush()` bool), phone paste box; null run blocks dropped, old-save letter flood stopped; quest tracker fixes (spouse, routes, captions). New save_transfer_test. |
| P6 Performance, world, co-op | Forest border trees as 159 `BorderBucket`s (forest ~430 nodes, was ~1300), probes stay on the map (`exits_off`), lit tier tops on hills, calmer forest band, world look fixes; `regen_data.sh` + data_sync_check (stable order); co-op guests see host world keys, relay overwrite guard, world sync as deltas; coop_test covers C3-C8. New border_bucket_test. |

CI-only fixes after the merge (two rounds, run c9c green):
- Pillow missing on the CI runner (installed in the workflow).
- A bot pressed the new "Save and quit" in Options (bots skip it).
- gen_collections scanned files unsorted (sorted, so data_sync_check is stable).
- Tests still expecting pre-C9 behaviour (B no longer runs, toolbar steps, flush returning bool).
- Playtest intro presses (pad focus and the new confirm cards).

## Timing (optimised process)

| Stage | Effort | Minutes |
|---|---|---|
| Auditors: 20 read/play-only (medium), during the C8 wrap-up | medium | overlapped |
| Package plan | | ~20 |
| Fix agents (6, medium) | medium | ~60-75 |
| Merge (one merge, hook lines from the reports) | | ~30 |
| CI (6 shards + 20 bots + playtest), incl. two fix rounds | medium | ~95 |
| Package build (report, guide, progress, page) | low | ~10 |
| **Total from plan to verified merge** | | **~220** |

## Still open (next CONDUCTs)
- Web pack is ~105 MB, not the 80 MB target (more lossy art, trim songs in the pack).
- Steam Deck UI scale for 1280x800 still small; physics interpolation off.
- Startup profiling (first load to title) not done.
- Co-op relay host not deployed (needs Tom's choice), so online co-op only works in tests.
- `MoveSpeed.calc` (~490 us) and `GameState.gear_stat` (~190 us) run every frame: cache them.
- Town load: `Npc.setup` ~5 ms each (cache SpriteFrames per sprite).
- Haptic hooks beyond Music.sfx names (tool fx, story shakes, arcade) can be added one line at a time.
- Still open from earlier: speed buffs overwrite each other, fertiliser kept by auto-harvest, animal shop (C11), underwater colony caves, pixel font (C23), audio depth (C13).

## Questions for Tom (defaults are in place)
See Guide 33. The three new ones: iPhone or Android (iPhone browsers can't vibrate); listen for music crackle or gaps after the deploy; which co-op relay host.
