# Guide #7: ten passes in a row — balance, art audit, creator, feel, audio, net, QA

**Play:** https://excivious27.github.io/Dreams/

**What happened since Guide 06.** You said "go, then the next, times ten".
Here is the list, in the order it was done, each pushed on its own:

1. **Round 2 pass 1 — economy.** A 100-day farming bot (`tools/sim.gd`)
   and the workbook `docs/economy.xlsx`. Found: fall and winter had no
   seeds to buy, planting was free, one crop could be mass-sold at full
   price. Fixed: Maple stocks by season, saturation after 20 sold,
   planting costs energy, start money ◆50/◆60, early crops pay better.
2. **Round 2 pass 2 — mining.** The mine ignored the pickaxe tier (every
   rock took the full hit count) — fixed; ore rocks drop a second lump
   30%+; tool-ladder prices above steel eased. Farm+mine curve: ◆9.5k /
   ◆25k / ◆47k / ◆74k at days 28/56/84/112.
3. **Round 2 pass 3 — combat.** Swords 2/4/6/9 + tool tier; enemies die
   in 3–12 hits at their tier; sword prices up; stingy drop tables got
   ore; golem king and ruin warden shortened. Combat sheet in the workbook.
4. **Round 3 pass 1 — art audit.** `tools/art_audit.py` measures every
   frame of every strip. Found 68 problems; the big ones were double
   sprites (Ladder, Sasha, Val, Mama Rosa, The Kid, Marisol, Nia) from a
   slicer bug — fixed and re-sliced. 27 small ones left (listed in
   STATUS).
5. **Creator + Party art.** The 12C creator panel, preview frame and
   picture buttons are in; the Party tab uses the partner cards as
   buttons.
6. **A shipped bug.** A typing error in the hit code slipped past
   `check.sh` because of a shell quirk (grep -q under pipefail). Fixed
   both. The web build was broken for about ten minutes.
7. **Round 4 pass 1 — feel.** Hitstop and a camera nudge on sword hits
   (more on kills and crits), death puff + thud, boss send-off, crit
   chime, stomp and stink sounds.
8. **Round 5 pass 1 — audio.** Crossfades between areas, pitch drift on
   repeated sounds, five new placeholder tracks (lake, mountain, beach,
   sky, Cat-topia).
9. **Round 6 pass 1 — multiplayer.** Two-process net test green against
   the local relay. Clients auto-rejoin after a drop (3 tries); the relay
   drops dead sockets, caps frame size and message rate.
10. **Round 7 — QA.** Full harness run: smoke, playtest (43 checks, 16
    screenshots reviewed), creator, mine, story (59 beats), hearts, reach,
    walls, net — all green. ui_test has 2 harness-only failures left.

## What to test (quick tour, 10 minutes)

1. Day 1: ◆50, plant six turnips, water — energy drops with planting too.
2. Sell 25 turnips on one day: the report shows the price falling after 20.
3. Fight a Grump: short freeze and a nudge on each hit, a puff when it dies.
4. Walk farm → town → beach: the music crossfades; the beach has its own.
5. Mine floor 1 with a copper pickaxe: two hits a rock.
6. New game → Build your own: the wooden creator panel.
7. Menu → Party with a partner: tap the card to switch.
8. Multiplayer: host, then kill your wifi for 5 seconds — it should
   reconnect on its own (toast says "reconnecting 1/3").

## Open

- Prompts 13 (two batches) — send when ready; Catkins, the finargles,
  the crystal babies, the merkitties still wear placeholder art.
- Relay host decision (free sleeping tier vs ~$4 VPS) — still yours.
- Next in my order: Round 3 pass 2 (the 27 small strip fixes + Mer/Merry
  one-cell offsets), Round 4 pass 2 (tool-swing responsiveness, walk
  acceleration), Round 7 Steam prep.
