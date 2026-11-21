# CONDUCT 16b report: battle campaigns (2026-11-21)

Your ask: battles must never block a cozy player, they should still be worth playing (a tiered reward ladder), and the training you tried had to be fixed (the helper popped up out of nowhere, would not follow you, the commands and "can I build helpers?" were unclear, and there was no clear way out). All three are done. Every campaign-held region and the whole main story can now be reached with zero battle wins in both arcs ("the long way"). Wins pay through a star and chest ladder. The training brings the helper in only when you press Build helper, follow works, and you can end it at any step. 18 focus auditors (258 findings) fed 5 fix packages (scopes in /home/claude/wt/C16B_SCOPES.txt, contract in C16B_CONTRACT.md), then one merge and hook integration pass. **Final full CI c16bi: PENDING (started ~10:45 PT).**

**Whole game after C16b: about 82% done, 18% remaining** (average of the 129 systems in docs/inventory.csv). New rows: the long way 88%, battle reward ladder 78%, battle commands and helpers 85%. Moved: battle training 85% -> 90%, battles and campaigns 92% -> 93%.

## Audit (18 focus auditors, 258 findings: 5 blockers, 72 major, 134 minor, 47 polish, plus 18 verified-clean notes)

| Area | Main findings |
|---|---|
| Training (01) | The helper appeared before you knew why. Follow lagged and got stuck. A turret step could soft-lock. Leaving the field did not end the training. |
| Campaigns tier 1-5, both arcs (02-05) | The penguin main story was locked behind "Across the Wastes" (blocker). The gang finale was locked behind two tier-4 campaigns in a row (blocker). Tier 1 had an escort fight too early. Captains had no cards in the gang arc. |
| Commands, building, allies (06, 07, 13) | The rally button did not say what your team was doing. Hold did not hold. Mend and barrage had no buttons. Nothing on screen said you could build helpers or what they cost. Ally ranks from C16a did nothing in battle. |
| Loss and the long way (08) | Regions opened only on a win (blocker). The main story needed wins (blocker). A loss gave no retry or other road. |
| Rewards and board (09, 10) | The only "stars" showed foe level. A won fight could never be replayed. No chests, trophies or mastery. The board did not say what was next. |
| Feel, difficulty (11, 12) | Strikers ran in and out. Ranged foes ignored helpers. No outro beat. No warning when a point you held was under attack. |
| Story, tests, co-op (14, 15, 16) | Story locked behind wins in both arcs (blocker). No zero-win test or a bot that never wins. Guests could start marches. |
| Balance and gang identity (17, 18) | Supply caches paid more than battles. Gang tier 1 used wildlife. Gang node names were penguin names. |

## Fix packages

| Package | Fixed | Images |
|---|---|---|
| P1 Battle core | HELPERS button says what the team is doing (pushing on / follow me / hold here / to a point); a tap opens the orders. Hold here really holds. MEND and BARRAGE buttons. Banner menu explains building (crystals or drones, upkeep, switching keeps paid units). Build ladder by tier. Ally ranks add damage. Whole roster on the battle card. Captions, pad words. Test battle_army_test. | 1 |
| P2 Training, feel, unit AI | Drill finished in both arcs (below). Strikers stand and fight, ranged foes shoot helpers and turrets, light knockback, BLOCK numbers, a 1.2 s outro beat, a red pointer to a held point under attack, ally health bars. Test battle_feel_test. | 0 |
| P3 Campaign flow, the long way, story, tests, co-op | The long way API, loss card, retry and easier retry, 7 long-way story panels and morning beats, gang battle flavour, guest guards. Test zero_win_test (both arcs) and a `nowin` bot style in two bot slots. | 7 |
| P4 Reward ladder + board | BattleRewards and data/battle_rewards.json (gen_battle_rewards.py). Board: earned stars, foe level as dots, one state per row, next campaign, story tag, long way and rematch buttons, actions that fit a phone. Tests battle_rewards_test, c16b_p4_board_test. | 1 |
| P5 Campaign content, balance, gang identity | Long way rows for all 19 campaigns. 11 named gang captains, gang rosters by tier (people only), tier-1 ramp (no escort), cache below battle pay, pay curve, field variety, rail yards and neon dressing, gang node names, "new here" rows. 25 captain boss cards built from existing sprites. Test c16b_p5_test.py. | 0 |
| Merge + hook integration | One reward call per win (Campaign.finish, with Battle's stats). Rematch API. Gang node names and gang provisions. Captain cards on spawn. Gang drill point names. Brief rows "NEW HERE" and "STARS". Test c16b_integ_test; board and loss card shot tool c16b_loss_shot.gd. | 0 |

## What changed

### The long way (battles never block you)
- Every campaign that holds a region has a non-combat road, both arcs. One of four kinds: **toll** (pay and walk through), **quest** (a short favour), **travel** (a ride or path someone shows you) or **story** (a story scene takes you around).
- Toll by tier: T1 150 + 15 wood, T2 400 + 2 copper bars, T3 900 + 3 iron bars, T4 1,600 + 4 iron and 1 gold bar, T5 2,600 + 3 gold bars (crystals or cash). The region opens the next morning with a short scene.
- The long way opens the region and the story exactly as a win does, but gives no win rewards or stars. You can still come back and win it later.
- **Loss card** after a lost or abandoned fight: Try again now / Try again, easier (this fight only) / Take the long way / Back to the campaign map / Not now. An easier retry drops one difficulty step for that fight and caps it at 2 stars.
- Offered at the held border, the colony ferry, the loss card and the campaign board.

### Reward ladder (worth playing)
- **Stars 1-3 per fight:** 1 = win, 2 = no KO, no ally lost and half your tickets left, 3 = all that and under par time. A better rank later pays the difference.
- **Chests by tier:** Supply Chest, Field Chest, War Chest, Commander's Chest (gang: Supply Crate, Field Crate, Strongbox, Kingpin's Safe).
- **First clear** of a campaign: a tier chest plus a trophy decor piece.
- **Mastery** (all 3 stars on a campaign): a mastery chest plus a mastery piece; the legacy weapons Aurora Blade, Prism Lance and Tommy Gun come from here.
- **Star track** per arc: 10, 30, 60 and 100 stars pay strategist XP and money.
- **Ally bonds:** the partners and crew who fought get a battle bond (up to 2).
- **Rematches** of a won fight pay 20% plus XP once a day.
- Economy: the ladder adds 35-90% on top of the campaign's own pay, kept near farming and fishing per minute. Nothing story-essential is in it.

### Campaign board
- Opening line: "Each new region is held. Win its campaign for the best rewards, or take the long way around."
- ★ only for stars you earned; foe level shows as dots (Foe Lv ●●○). Each row has one clear state. "★ Story" tag on story campaigns; regions opened the long way say "(another way in)". The next campaign is shown. Take the long way and Rematch buttons; actions wrap to fit a phone.

### Battle core
- **HELPERS button** says what your team is doing: pushing on, follow me, hold here, or ▸ a point. Your team follows you by default. A tap opens the orders list.
- **MEND and BARRAGE** have their own buttons under HELPERS, with icons.
- **"Yes, you can build them":** the banner menu says what each helper costs (crystals in the penguin arc, drones in the gang arc), the upkeep, and that switching keeps the ones you paid for.
- **Tier ladder:** T1 striker and healer (and mend), T2 warden, turret and fortify, T3 shade, barrage and level-3 upgrades. Each new tier says what is new.
- **Ally ranks** (partner rank, crew level) add damage, shown on the battle card. Fallen allies can be called back.

### Training (your case)
- The helper appears only after you press **Build helper**, with a visible arrival (sparkle and scale-in).
- **Follow works:** helpers keep up with you (a little faster than you walk) and stay within reach.
- Hold is now called **Guard banner**. No turret step can lock you in.
- **End training** at any step: the button, the pause menu, or walking off the field (it asks first). You can come back any time.
- Tickets are explained, and the reward shows as crystals or cash.

### Feel and AI
Strikers stand and fight instead of running back and forth. Ranged foes shoot helpers and turrets too. Helper hits give a light knockback. Blocked hits say BLOCK. Units of a point you lose step down with a poof. A short outro beat before the results. A red pointer when a point you hold is under attack. Reduced motion respected.

### Gang captains and rosters
- 11 named gang captains: Harlan "Hayride" Voss (Orchard Hills), Road Boss Dutch (The Highway), Ridge Boss Kestrel (Highlands), Crusher Kade (Quarry), Smuggler Queen Rook (Marsh), Toll Man Dukes (Riverlands), The Curator (Ruins), Ironside Mae (Docks), Neon Sable (Neon), Old Pipes Mulgrew (Underground), Mr. Gilt (Uptown).
- Gang foes are people only, by tier: Street Runner, Heavy, Goggles Lookout, Flare Crew, Enforcer. Gang node names and gang provisions (rounds instead of wood).
- Every captain in both arcs now has a boss card.

## Images and audio

**Images: 9** from dreams-image (P1 1, P2 0, P3 7, P4 1, P5 0): the MEND/BARRAGE icon pair, 7 long-way story panels, and a sheet of 8 chest icons. All sliced and placed. Plus **25 captain boss cards** built from existing sprites (no new renders). **ACE: 0.** Prompts: docs/reports/ART-PROMPTS-CONDUCT-16b.md (already made, nothing for you to make).

## Timing

| Stage | Role | Effort | Minutes |
|---|---|---|---|
| Auditors (18 focus, read/play-only), 09:15-09:45 PT | auditor | medium | ~30 |
| Packages + contract (258 findings into 5 packages), 09:45-09:55 | conductor | medium | ~10 |
| Fix agents P1-P5 in parallel, 09:55-10:25 | fixer | medium | ~30 |
| Merges + hook agent, 10:25-10:45 | integrator | medium | ~20 |
| Final full CI c16bi, started ~10:45 | CI | | PENDING |
| **Total** | | | **~1.5 h wall clock (09:15-10:45) + final CI** |
| Agents per effort | | | 18 medium auditors; 5 medium fixers; 1 hook integrator |
| Images used | | | 9 (+ 25 cards from existing sprites) |
| ACE credits used | | | 0 |

## Still open

- **Art (docs/ART-QUEUE.md):** 19 unique campaign trophies (placeholders use existing decor now), about 10 mastery cosmetics, star and medal sprites (the board uses ★), 2 new helper kinds per arc for a recruit rung.
- **Campaign flow:** Ops turf grant on a gang win, rout supply floor, retreat morale on Very easy, gang flavour lines in more places.
- **Battle core:** an auto-battle assist for Very easy, pad glyph icons, "Press" instead of "Hold" in the order hint for keys, team name tags at 6 px.
- **Content:** drill point letters E/D/B in the penguin drill, void borders in bf_themes, captain HP floors.
- **Co-op:** guests see the board read-only and cannot march; following the host into a region is your call (b).

## Tom's calls

(a) **Gang arc tier 5.** The gang arc has no tier-5 campaign. Add an optional post-game "elite" campaign with no region attached? Default: yes, in C22.

(b) **Co-op past a border.** When the host has opened a region (won or the long way), can a guest follow the host in? Default: yes, visit-only, in C17.
