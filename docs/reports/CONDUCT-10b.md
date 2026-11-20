# CONDUCT 10b report: Decor and cosmetics, part 2 (2026-11-20)

The second half of decor: farmhouse exteriors, decorating the yard and farm, Tess the new carpenter, the casino side arc (The Gilded Ace), the wardrobe on every hero, art fixes and a shop rotation bug fix. 20 read/play-only auditors (c10b_01..20, 369 findings) fed 6 file-disjoint fix packages (docs/reports/C10B-PACKAGES.md, scopes in docs/reports/C10B-SCOPES.txt). Everything was merged once and checked on GitHub Actions (check.sh in 6 shards, 20 bots, the scripted playtest with screenshots). **The first CI run failed (scipy missing on CI for the new house-parts check, plus one flaky playtest step); after adding scipy, C10b passed CI on run c10b2.**

**Whole game after CONDUCT 10b: about 77% done, 23% remaining** (average of the 68 systems in docs/inventory.csv). The outdoor decor row (5%) became two rows: yard and farm decorating 80% and farmhouse exteriors 85%. The casino rose from 0% to 75%, the wardrobe from 70% to 82%, decor sources from 75% to 85%. Systems for later CONDUCTs (C14, C20, C21) still count at 0%.

## Audit (20 auditors, 369 findings: 8 blocker, 130 major, 166 minor, 65 polish)

| Area | Main findings |
|---|---|
| Exteriors (01) | One fixed look per farmhouse tier; no part masks, no night/winter fit; winter nights showed a bare roof (old bug). |
| Yard placement (02, 09, 12) | Decorate mode was indoor only; no blocked-cell rules for soil, buildings, exits or river; debris could grow under placed things; perf and save size untested with heavy decor. |
| Outdoor art (03, 08) | Few outdoor pieces; mixed scales, slivers, key halos, bad seams (tatami, penguin print), wallpaper/flooring not usable as room surfaces (blocker). |
| Casino (04, 05) | No casino; needed odds under 100%, deterministic RNG, limits and self-control, heat ties, all-ages words. |
| Quests, festivals, shops (06, 07, 10) | No furniture seller, crew counters missing, shelves did not really rotate, flat price ladder, re-order fee too high. |
| Wardrobe (11) | Two catalogues collided; most drawn heroes showed nothing; co-op friends wore your clothes. |
| Words, tests, regressions (13-20) | Gang words, test plan, C10a regressions, bugs sweep, performance and docs: small items only. |

## Fix packages

| Package | Fixed |
|---|---|
| P1 Catalogue, shops, economy | 82 promoted yard pieces + exterior catalogue entries (1034 decor entries in all); wallpaper/flooring as room surfaces; geometric price ladder; 10% re-order fee (min 10); real shelf rotation; Tess the carpenter (new villager, workshop shelf, letter day 3, heart perks); Marlene/Deuce/Specs/Halo crew counters; econ_check sink sim; SAVE_VERSION 11. |
| P2 Yard decorating | Decorate mode outdoors: Decorate yard button + Plans board option, reserved cells (house, exits, river, pens, building sites), drag-to-paint paths, footsteps on paths, NightGlow, canopy fade, winter looks, co-op per-piece deltas; relayout 389 -> 23 ms. |
| P3 House exteriors | `HouseExterior` + house_palette shader: 61 styles over 9 tabs (8 roofs, 11 walls incl. brick/fieldstone/log, 4 glass, 4 stone, 8 doors, 6 shutters, 8 porches, 8 mailboxes, 4 pen fences); live preview, buy once, night/winter refit, winter-night bug fixed. New house_exterior_test. |
| P4 Casino | The Gilded Ace on Casino Row (gangster arc, 6pm-2am): slots 94.6%, roulette 97.3%, Big/Small 97.2%, blackjack 6:5 97.4%, video poker 97.3% (all from gen_casino.py, every bet under 99%); deterministic outcomes; limits ($500 daily loss limit on, hands cap, Take a break, reality check); heat ties; Odds board; keepsakes for trying tables, never for money. New casino_test. |
| P5 Wardrobe | One catalogue (old saves migrated); hats and face pieces pinned on all 16 drawn heroes; capes on every hero; Wardrobe at the dresser; co-op look sync; wear sets claimable; water/life rows for costumes. |
| P6 Art | 18 renders: 87 outdoor pieces (garden, lights, seasonal, gangster yard), 32 winter twins, seams fixed (tatami, penguin print, carpets, planks), key halos and slivers cleared, keepsake renders. |

Merge fixes: yard renders got draw scale/season/desc in gen_decor; shop rotation really rotates (md5 key); owned uniques say owned when ordered; scipy added to CI.

## Timing (optimised process)

| Stage | Role | Effort | Minutes |
|---|---|---|---|
| Auditors (20 read/play-only; 01-14 medium, 15-20 low) | auditor | medium / low | ~45 |
| Package plan | conductor | medium | ~25 |
| Fix agents (6 in parallel, art in P3/P4/P5/P6) | fixer | medium | ~70 |
| Merge (hooks, rotation fix, regenerated data) | conductor | medium | ~35 |
| CI run 1 (failed: scipy, flaky playtest) + fix | CI / conductor | | ~50 |
| CI run c10b2 (6 shards + 20 bots + playtest), pass | CI | | ~45 |
| Package build (report, guide, progress, page) | packager | low | ~10 |
| **Total** | | | **~280** |

## Still open (next CONDUCTs)
- Casino story chain (The Straight Game with Deuce) and the High Roller room; house cut once the casino is yours.
- Casino song and ambience bed (existing sound names used for now).
- Villager decor requests (deliver a piece, decorate a room).
- Lumi commissions (custom paint colourways).
- chair2 2x redraw.
- Apparel sit and ride redraws (ride rows fall back to walking).
- Web service-worker patches were skipped this round.

## Tom's open calls (defaults kept)
1. Casino name: "The Gilded Ace".
2. Blackjack pays 6:5 (house keeps about 2.6%) vs 3:2 (about 0.5%).
3. $500 daily loss limit on by default.
4. Penguin arc: a prize wheel, or nothing (default nothing).
5. Gangster farmhouse: city look by default.
6. Restyle cost and crew day.
7. Tess reuses the unused "Delve" villager art.
8. Rare creator hats kept by old saves.
9. Yard decor on empty building slots goes back to the box when building starts.
