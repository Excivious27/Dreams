# CONDUCT 10a report: Decor and cosmetics, part 1 (2026-11-20)

The sixth CONDUCT on the optimised process, and the first half of decor: the catalogue, decorating indoors, the wardrobe and where decor comes from. 20 read/play-only auditors (c10_01..20, 255 findings) fed 6 file-disjoint fix packages (docs/reports/C10A-PACKAGES.md, scopes in docs/reports/C10A-SCOPES.txt). Everything was merged once and checked on GitHub Actions (check.sh in 6 shards, 20 bots, the scripted playtest with screenshots): **C10a passed CI the first time, on run c10a.**

**Process change:** before branching, a contract stub for the new shared system (scripts/decor.gd: data, entry, give/take, rarity, price, stock, roll, wear, RARITIES, WEAR_SLOTS) was written on main with an empty data/decor.json. All six packages coded against fixed signatures, so the merge needed only hook lines and a few test updates, and CI went green with no fix rounds.

**Whole game after CONDUCT 10a: about 74% done, 26% remaining** (average of the 67 systems in docs/inventory.csv). The old single decor row (5%) is now five rows: decor catalogue 85%, decorate mode indoors 80%, decor sources 75%, wardrobe 70%, and outdoor decor (C10b) still 5%. Systems for later CONDUCTs (C14, C20, C21) still count at 0%.

## Audit (20 auditors, 255 findings: 110 major, 113 minor, 32 polish)

| Area | Main findings |
|---|---|
| Catalogue design (01, 07) | No decor data at all: furniture scattered over int_ props, kits and items; no rarity table, price bands, pity or luck rules. |
| Indoor placement (02, 03, 13) | Only a few starter pieces could move; no rotate, store or undo; no per-room wallpaper or floors; one tap could pick a piece up by accident. |
| Wardrobe (04, 09) | No cosmetic slots (armour replaced the look); six drawn costumes and the arc headgear unreachable. |
| Sources (05, 06) | No shop sold decor; no crafted decor; no reward or loot hook handed out decor; no rule kept one-of-a-kind pieces unique. |
| Catalogue screen (08) | No decor page; Book pages forward-only; detail card below the scroll window. |
| Saves, co-op, perf (10) | No run.decor block or migration of placed items; guests could have changed the host's house. |
| Art (11) | Gaps in wall art, tabletop, kitchen/bath, lights, rugs, seamless walls/floors and gangster sets. |
| Economy (12) | Decor as the missing late-game sink: price ladder, low sell-back, re-order fee, no buy-sell loops. |
| Tests (14) and regressions (15-20) | Test plan for the new screens; C9 controllers, saves, data and performance checked: small items only. |

## Fix packages

| Package | Fixed |
|---|---|
| P1 Catalogue, runtime, economy | New tools/gen_decor.py -> data/decor.json (862 entries after the art merge: reuse pool plus P6 renders) and dc_/wr_ items; rarity common..mythic + unique with price bands, pity and luck in `Decor.roll`; 41 crafted pieces through gen_stations (capped at 0.8x inputs, never earns); icons from any art group; uniques protected in sell/trash/gift; run.decor migration (SAVE_VERSION 10). New decor_test (4028 checks). |
| P2 Decorate mode | `DecorMode`: grid ghost (green fits, red + cross blocked, reason shown), Box/Place/Turn/Store/Undo, two-tap place/lift, drag, pad and keys; run.decor.placed per room; floor/under/wall/window layers; rotations; glow from the entry; reserved cells per house tier; per-room wallpaper and flooring; guests can't decorate the host's house. New decor_mode_test. |
| P3 Catalogue screen | `DecorCatalogue`: owned/seen/missing, Type/Rarity/Show/Set chips, 6x5 pages, detail card with where-to-get hints, re-order delivered next morning, set progress with rewards, decor box links from Items and Chest; Book pages go both ways. New decor_catalogue_test. |
| P4 Sources | `DecorSources` (one grant path, uniques refused once owned, deterministic shelves turning every 3 days), `DecorShopScreen`, "Home goods" on every shop counter and mega/colony stalls, loot pools (chests, mines, fishing, bosses, claw, festival), heart perks and side stories hand out decor. New decor_sources_test. |
| P5 Wardrobe | `Wardrobe` + `WardrobeScreen`: outfit/hat/accessory slots, no stats, live preview, honest "Shows on" line, Look toggle; the six drawn costumes and Fedora/Shades/Snow Goggles/Aurora Hood wired. New wardrobe_test. |
| P6 Art | 58 dreams-image renders (budget 60): 22 themed set sheets (gangster, penguin, both), gap categories, 12 seamless wallpapers + 12 floors, 9 animated showpieces (legendary, mythic, unique), a decor UI sheet; new tools/slice_c10a.py writes art/gen/decor + _catalog.json. All ages: no weapons or drinks. |

Merge fixes (before CI, no CI rounds needed):
- Wardrobe put_on/take_off took a box copy twice (pieces lost); penguin pieces' renders overridden.
- `Tickets.have` counted decor twice; the Items tab "Put in the decor box" button never showed.
- Stub-era test asserts updated to the final schema; starter footprints kept; the casino carpet renamed "Lucky Red Carpet".

## Timing (optimised process)

| Stage | Effort | Minutes |
|---|---|---|
| Auditors: 20 read/play-only (01-14 medium, 15-20 low), during the C9 wrap-up | medium / low | overlapped |
| Package plan + contract stub (decor.gd) | medium | ~30 |
| Fix agents (6, medium; P6 art in parallel) | medium | ~60-75 |
| Merge (hook lines, wardrobe/tickets fixes, test updates) | medium | ~35 |
| CI (6 shards + 20 bots + playtest), green first time | | ~45 |
| Package build (report, guide, progress, page) | low | ~10 |
| **Total from plan to verified merge** | | **~190** |

## Still open (next CONDUCTs)
- Exteriors, farm and outdoor decor, casino arc decor, decor in quests and festivals: C10b.
- Hazel and crew-shop counters for decor (interiors.json, town.gd).
- phone_ui_test does not audit the catalogue, shop and wardrobe screens yet.
- Placed decor is not in a texture atlas yet (draw calls in a full house).
- Apparel renders for the 18 drawn heroes (most show nothing from the wardrobe, honestly labelled).
- Two small seams: dc_fl_tatami and dc_wp_penguin_print.
- CharSheet keeps its own rarity rank dict (move to DecorCatalogue.rarity_dots).

## Questions for Tom (defaults are in place)
See Guide 34. The three new ones: Hazel as the furniture seller or a new carpenter; casino-themed home decor in the general catalogue or casino-only; the re-order fee and decor milestone money.
