# CONDUCT 2 report: Rec Center, arcade, community farm, plus Tom's playtest notes (2026-11-19)

Run on the personal account. Phase 1: 20 agents (old process, stopped at 13:05 by a server restart and Tom's switch to the new process; every agent committed and reported). Phase 2 (new process): 8 file-disjoint fix packages built from the agents' leftovers and Tom's 21 phone-playtest notes. One merge, one full check.sh, 20 bots and the scripted playtest.

**Whole game after CONDUCT 2: about 71% done, 29% remaining.** The total fell slightly from CONDUCT 1's 73%. Tom added big new scope today (decor and cosmetics, ranching, seasons, long-run progression, writing, audio depth, world aesthetics), so the percentage is now measured against a larger finished game.

## Phase 1: area agents (found / fixed / test)

| Area | Found | Fixed | Test |
|---|---|---|---|
| Bowling feel (c2_01, merged via P6) | Aim nearly luck on a phone (40 ms window); fallen pins inert; abrupt flow; no versus | Drag-to-aim on the foul line with a predicted path, gold power band, pin sticks that knock pins, pinsetter sweep, split calls, versus games against villagers on one strength table (Tobin ~95 to Maple ~195), results card with ticket breakdown | bowling_test |
| Block Jumper (c2_02 + P6) | Respawn put movers out of step; checkpoints on obstacles; flat difficulty; solver missed routes | Respawn clock by x, checkpoints on 1.2 s calm runways, 26-46 s level curve with combos, wider-beam solver proving every checkpoint, whole-screen tap to jump, ceiling art, dead buttons dim | jumper_test, jumper_solve replay 36/36 |
| Crystal/Neon Stack, Whack-a-Grump (c2_03) | B ended rounds and lost the coin; Stack too fast; Whack scoring paid 186 tickets a coin | Pause card, gentler curve, top-out beat, READY/GO, countdown, tap boxes, rescored | stack_whack_test |
| Claw, Duck Pond, Skee-Ball, snack bar (c2_04) | Skee-Ball had no skill; claw stingy; Duck Pond overpaid; snack bar thin | Real 9-ball Skee-Ball with new art, centring-driven claw grip with pity, Duck Pond rebalanced, four snacks with effects and icons | rec_games_test |
| Ticket economy (c2_05) | Tickets→prize→sell made money; repeatable loop prizes | Payout caps, 1/8 resale, `check_economy()` refuses loops, weekly Sprout Fizz, 12-week pacing sim, clearer prize screen | ticket_econ_test |
| Rec hub (c2_06) | League night took every lane; bowlers misplaced; 24 h opening; no schedule shown | House lane always free, bowl with villagers, 9am-midnight hours, festival closing, desk "What's on today?", situational chatter | rec_test |
| Rec visuals (c2_07) | Empty ground floor, faint neon, no night look | New decor art, carpets, posters, neon, `RecGlow` lighting, lit lot at night | rec_test |
| Rec audio (c2_08) | Ambience inaudible; one pin sound for everything | "Ten Pin Strut" and "Nickel Record" (ACE), 11-record jukebox, graded pin sounds, positional lanes, arcade bed | rec_audio_test |
| Community farm stages (c2_09) | Softlock at "lot cleared"; compost and donated seeds ignored | Overnight builds with reveals, seeds planted, seasonal asks, fixes | commons_test |
| Volunteers (c2_10) | Stacked volunteers; empty market morning; broken chat bubbles | Own cells, visible work jobs, shifts, rain shelter, barks, lend-a-hand tasks | cf_volunteer_test |
| Community farm map (c2_11) | Box tree edge; debris looked decorative; bare spring fruit trees | Organic woodland edge, new debris art, paths joined, fruit trees in leaf (all orchards), gangster city-block edge (14 new pieces) | cf_layout_test |
| Touch input (c2_12) | Every tap counted twice on drawn screens; fingers held into cabinets; hack terminal unleavable | `TapInput`, release handling, UNPLUG button, chip sizes | touch_ui_test, phone_ui_test |
| Gangster flavour (c2_13) | Penguin prizes and lines in the gangster arc | Gangster lines for every visitor, Fuzzy Dice, Pinstripe Fedora, Neon Stack | gang_flavour_test |
| Integration (c2_14) | Rec fed nothing else | Six arcade quests, perks, mail, festival tickets, board notes, score board | rec_links_test |
| First hours (c2_15) | Goal arrow 7 cells off; meadow before its letter; morning line a day behind | Fixed arrow, letter first, morning Next: synced | first_hours_test |
| UI softlocks (c2_16, + main chat) | Game left paused with nothing on screen; toasts over boss card and pup buttons | `Hud.keep_paused` (screens/dialogues only keep the pause while something needs it), freeze guard, toast placement | toast_layout_test, softlock_test |
| Test hardening (c2_17) | Wall-clock waits, clock-seeded mines | Game-time waits, `--fixed-fps 60`, seeds | gang_play/mine/campaign tests |
| World sweep (c2_18) | "Bus" in Ironline, hard ground patches, animals on the farm track | Night train lines, "Junction City" song, ground fixes, pen moved | mega_region_test |
| Performance (c2_19) | Rec floors 179-247 draws, arcade 212-251 | TriBatch, `ScreenCover`, `RegionData`: rec 110-114 draws, arcade 83-105 | perf_test |

## Phase 2: fix packages (Tom's playtest notes first)

| Package | Tom's notes fixed | Also |
|---|---|---|
| P1 Mines and combat | Pickaxe/tools now 30% of a sword in fights; crates and barrels always break with feedback on every hit; 35 varied guardian encounters (single, packs, swarms, themed, arc-only) with quick-to-marathon wake times; way-down arrow follows the real walking route | mine_keeper_test |
| P2 Movement | Hero keeps facing after stopping; diagonal approach targets the right thing for tools and attacks; pup swims instead of walking on water | move_target_test |
| P3 Combat music | Big Grump music holds the whole fight; danger music by tier, kept while chased, smooth fades; 4 new ACE songs | danger_music_test |
| P4 World | Fish only in deep water; lighthouse wall fixed; mushroom look-alikes fixed; farmhouse 33% bigger | Hub see-through cells, fairy ring moved, volunteers off beds, market day vs festival |
| P5 Wording | Locked areas: in-world sense lines + the true next step, per region and arc; skill points shimmer; "The Two Too Powerful Penguins"; Meow Pow Wow earned from Catkins | campaign_words_test, meow_gate_test, skill_glow_test |
| P6 Arcade | (bowling merge, villager strength, Block Jumper checkpoints) | bowling_test, jumper_test |
| P7 Art | Big Grump card fixed; 55 mine rocks crisp; CrispArt pixel shader for buildings/props/nature; blur ranking docs/FUZZY-ART.md | crisp_art_test |
| P8 Desktop | Full-screen play on computers, HUD to the edges, menus centred, touch controls auto-hidden, F11/Options fullscreen | desktop_layout_test |

## Tests

Full check.sh on the merged code, 20 bots × 3 days, playtest.gd: results in the Baton and below.

## Still open (carried to later CONDUCTs)

- Re-render the worst fuzzy buildings (hq_*, ward_*, then docs/FUZZY-ART.md), blocked today by the image server's daily limit (273/300): CONDUCT 5.
- New, very distinctive gangster heroes (One-Piece-level unique designs): CONDUCT 5/7.
- Windward hub edge notches; tune the gangster city edge; asphalt east road at the lot garden: CONDUCT 4/14.
- Battle first-redraw cost (draw_map chunk clipping), HUD batching: CONDUCT 9.
- Dialogue box lower on desktop; centred touch controls when forced on a wide screen: CONDUCT 9.
- Block Jumper audit with double jump: CONDUCT 8.
- New scope from Tom: CONDUCT 10 decor and cosmetics, 11 ranching, 12 writing, 13 audio depth, 14 world aesthetics, 15 seasons, 16 progression.
