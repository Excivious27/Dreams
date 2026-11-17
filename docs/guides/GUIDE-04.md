# Guide #4: where the game is, what to test, what comes next

**Where the game is now (16 Nov, night).** Play: https://excivious27.github.io/Dreams/

Since Guide #3: your whole play-test list is in (water lined up with its
collision, mouse/tap tool aiming, enterable buildings with a lane to every door,
villagers with routines and homes, voiced side quests, scripted villager scenes,
the community board, an economy with demand and saturation, gathering tiers,
Sorcery and Pup trees, the pup as a real companion), plus: timed crafting and
tiered buildings with permits, companions with hold-B abilities and the
partner-choice scene (penguins always offered in the penguin arc), Mer and the
flooded grotto on floor 5, web multiplayer for up to 8 (host / join by room
code), all six Prompts-10 batches sliced and wired, the character select fixed
(precreated heroes play as drawn, gang versions in the gangster arc, "Build your
own" for the paper-doll creator), and tonight's combat/mine rebuild below.

Harnesses are all green: smoke, playtest (43 checks), reach, walls, ui, mine,
creator, net (two-process).

## What changed tonight (test these first)

1. **The mine.** No ladder down. Dig and fight on a floor; around 10 rocks the
   floor's *keeper* wakes (boss card). Beat it and the rock splits into a
   shaft. Floors step up a tier every 4 (Meadow, Woodland, Deep, Crystal, Dark,
   Heart); each tier has its own ore pool and enemy pool; keepers get an extra
   ability per floor into the tier. Every 5th floor opened goes on Granite's
   lift on floor 1. Floor 5 is still Mer's grotto (swim with her to reach the
   shaft).
2. **Combat.** Knockback decays on repeated hits; a juggled enemy answers with
   a lunge; heavy tiers barely slide. Enemies lunge, enrage under 35% hp, shoot
   (poison/fire/ice/dark), shield, summon, stomp, blink, regenerate. They can
   poison, burn, chill, slow, weaken or daze you (icons under the hearts;
   sleeping clears). Spells pierce half of armour.
3. **One tier table** (`data/tiers.json`) drives every enemy's hp, damage,
   speed, armour, knockback resistance, abilities, status strength, loot and xp,
   and the player's own tier (sword tier, combat skill, defence, Sorcery) is
   measured on the same scale.
4. **Character select.** Pick Dad / Mom / Pax / Kairi / a penguin and you play
   as them; Gangster Paradise uses the gang sprites for Dad and Pax. "Build your
   own" opens the creator. The dresser only re-dresses custom/penguin heroes.
5. **Invisible walls.** Region props now block only the footprint their art
   actually covers (fixed ~50 oversized footprints across marsh, highlands,
   jungle, neon, uptown, countryside, sky, orchard hills, ruins, quarry,
   riverlands, docks).
6. **Villagers** with a separate home now go home for an hour mid-day too.

**How to test on the phone**
- Mine: floor 1 → dig ten rocks → keeper → shaft → floor 2. Then come back up and
  check the shaft is still open on floor 1.
- Forest: hit a wolf three times fast and step back; it should charge you.
- Marsh: let a bog hag hit you; the green poison icon should tick hp down.
- New game as Pax in Gangster Paradise; new game as "Build your own".
- Multiplayer is wired but the relay is only on my machine — see B below.

## What I build next, in order

1. Gangster chapters 2–5 fully scripted and playable, with the decisions that
   matter (gangster shops push villagers out; bitter companions go to the Dark
   Crystal; the bell ending). Recruitable gangsters use Prompts-11 Batch 3.
2. New heroes (Prompts-11 Batches 1–2) into the select screen with cards.
3. Deploy the relay and test two phones together; reconnects; host hand-off.
4. Audio pass (real music/sfx replacing placeholders).
5. Balance from your next play-test; Steam export presets.

Estimate to a complete, playable 100% at the current quality bar: ~14–18 of my
hours from here (the other chat's 650–1,300 hours is *your* time to a polished
commercial release, with rewrites, many play-test rounds and re-prompted art —
a different bar; both numbers are honest).

## What I need from you

**A. Art — Prompts 11, six batches of six.** Batch 3 (gangsters) and Batch 5
(mine tiers) unblock the most; the rest can come in any order.

**B. One decision:** the multiplayer relay needs a host. Options: (1) you rent
a ~$4/month VPS (DigitalOcean/Hetzner) and paste me the IP — I give you the
three commands; (2) I set it up on a free tier (Fly.io/Render) that sleeps when
idle and takes ~20 s to wake — fine for testing. "You decide" = option 2.

**C. Play-test the five things above** and send the list.

## Still parked
- Gangster-shop takeovers and the bell ending are data-only (`companions.json`
  "decisions") until item 1 above.
- Status icons for chilled / slowed / weakened / dazed borrow other icons until
  Prompts-11 Batch 4 lands; mine floors below 10 reuse lava/ice tiles until
  Batch 5.
- Audio placeholders.
