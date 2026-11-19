# CONDUCT 1 of 9: the first 3 hours, both arcs (2026-11-19)

**Results**
- 20 agents audited and fixed their own areas.
- The 20-bot playtest (3 days each, both arcs) finished with no crashes. The scripted playtest has 0 failures.
- `check.sh` passes, with about 19 new tests added this run.
- Everything is live.

## What the audit found and what was fixed

| Area | Found | Fixed |
|---|---|---|
| Penguin start (day 1-2) | Star Crystal drawn as a pale diamond; new partner invisible until map change; day 2 empty, day 3 crowded; mailbox toast lied | Crystal sprite; partner joins at once; partner scene on day 2; mailbox marker only when mail waits |
| Gangster start (day 1-2) | M.'s intro letter repeated on day 2; Sal called a woman; "Heat 0/5" every morning; Hideout dumped 5 things at once; a Gift boss ambushed new players | Second letter from M. with seeds; Sal is a man everywhere; heat line only once explained; Hideout order: arrive → recruit crew → drill invite → docks; no ambush |
| Goal line | Long goals cut off; wrong gangster order; ripe crop hidden; no arrow outside the mine | `GoalLine`: one short next step; green edge arrow to the goal on outdoor maps; quest log starts with "Now:" |
| Wrong tool | Silent swings, axe could fish, can/rod pulled weeds and smashed crates, mixed wording | `ToolHint`: one clear hint per wrong tool; first-pick toolbar tips |
| Gangster money | Arcade, mega map and HUD hint drew "cash" words raw | `Money.amount/num` everywhere; cash test scans 55,000+ strings |
| Unlock timing | Rec Center had no lead-in; Hazel's letter signed "hazel"; "story first" with no reason | Villager chatter from day 3; real names; Plans locks name the story step |
| Phone screen | **Symbols (◆ ♥ ★ ✓ ▶…) showed as empty boxes on the web build**; campaign list off-screen; tiny buttons | Bundled symbol font; 20-22 px buttons; phone UI test with system fonts off |
| Softlocks | Menus with no way out on B, empty dialogues hung, menu opened mid-cutscene, **key-binding screen couldn't be left on a phone** | B leaves every menu; empty dialogues finish; menu stays shut during story beats; B/MENU cancel a rebind |
| Energy and pacing | A pass-out hid the whole morning summary; clinic took half your money on day 1; no bedtime warning | Morning summary kept; no fees in week 1, then the first clinic visit is free; warnings at midnight and 1:30 |
| Farming first week | Crops didn't say why they weren't growing | Growth text on every tap; morning report counts dry and ripe crops and notes rain watering |
| Town first visits | Shops open at 11pm; no introductions; empty mailbox; board paid 6 for 3 stone | Shops lock with posted hours; all 19 villagers introduce themselves; first-week letters; fair board pay |
| Pup and early combat | First boss took 96/100 HP; wind-up hard to see; no pup tutorial | Fair boss; claw-mark warning icon; pup lesson at the first fight |
| Saves | No way to skip the opening | Skip button (how-to lines still show); old saves migrate into the Round 13 systems |
| Arc systems | Arc picker said almost nothing; arc buildings unexplained | Path cards; a one-time intro for each of 9 arc buildings |
| Rec/arcade | Jukebox reverted within 3 s; visitors blocked cabinets; prizes resold for profit | All fixed; prizes sell for half their ticket cost |
| Community farm/world | Invisible wall on the farm; Hazel absent on a day-1 visit | Fixed; place names per arc |
| Animation | All ten Marked sliced wrong (Ember choppy, Rio facing backwards) | Recut; power poses now play |
| Mega/campaigns | Gloamwood fairy ring invisible; you could walk through vehicles | Fixed; gate test covers both arcs |
| Performance | Up to 7,000 drawing steps per ground chunk caused stutter | Down to 50–200; texture memory capped |

## Still open
- **Art and audio:** nothing outstanding.
- **Minor:** a weapon tip can overlap the boss name card. This goes to C3/C5.
- **Your decisions:** see GUIDE-25.
