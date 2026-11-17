# Dreams — Art Prompts 10: the fix-up batch

WHAT THIS COVERS (checked against the game on 16 Nov after your play-test notes): the title screen needs a PORTRAIT key art (the landscape one gets cropped on a phone); every path in the game is drawn with a scalloped edge set that reads as "bites" (need a clean 47-tile path set for dirt, cobble and sand on grass); the penguin hero only attacks to the right and has no tool/swim/ride/sleep poses; the penguin has no hats/scarves drawn for his own head; the pup has no gear (collars, packs, boots) on the sprite and no fight/hurt/carry poses, and the six other pets have no pack/collar rows either; the fruit trees reuse plain trees out of season (need cherry/orange/plum/apple in blossom, fruiting, bare and snowy); the new Sorcery tree and Pup tree have no node or spell icons and the menu has no Pup tab icon; the mountain ledges need a two-row cliff face set (the current faces are one thin strip); villagers chatting have no speech-bubble set; the HUD buff row has no icons for the new buffs; the boss cards for the Marsh Witch / Golem King / Ruin Warden are reused; and the region cliff borders need matching rock-wall sets for marsh (dead roots), highlands (ice), ruins (broken masonry) and riverlands (river bank).

RULES THAT APPLY TO EVERY IMAGE: 1536×1024, 16-bit pixel art, top-down 3/4 view, clean 1px dark outlines, warm saturated Stardew Valley / Sun Haven palette, flat #FF00FF magenta background, no shading outside sprites, NO GRID LINES, NO TEXT OR LABELS anywhere, no watermark, NO LETTERBOXING (fill the whole 1536×1024). Character sheets use the GRID RULE: 64×96 cells at x = 24 + N×88, y = 24 + M×120 (16 columns, 8 rows). Tile sheets use the TILE RULE: 32×32 tiles at x = 24 + N×40, y = 24 + M×40, exactly 36 columns, and the art inside each tile must continue across its borders. Isolated props: 16 px gaps, base at the bottom.

Save every image under the exact file name in quotes and upload to `art/incoming/`.

---

## BATCH 1 — Title key art (portrait) and wordmark (2 images)

> Make TWO SEPARATE IMAGES, 16-bit pixel art, warm Stardew / Sun Haven palette, NO text except where asked, no watermark.
>
> IMAGE 1 "w184_title_portrait.png": 1024×1820 PORTRAIT (9:16), NOT magenta, a full painted scene: the top third is a twilight sky with a crescent moon, a few stars and soft clouds, with CLEAR EMPTY SKY in the top 30% for a logo to sit in; the middle is a hill with the town's lights, a river with a stone bridge and a waterfall; the bottom third is the farm seen from behind: a small cottage with a glowing window, a fence, a sunflower field, and a kneeling farmer (medium-skin, slim, straw hat, seen from behind) next to a small black-and-tan puppy, both looking at a floating glowing crystal hovering over the field. Leave the bottom 20% quieter (a soft dark grass band) so buttons can sit on it. No text anywhere.
> IMAGE 2 "w185_wordmark.png": 1536×512, flat #FF00FF magenta background, the word DREAMS as a chunky, friendly, hand-lettered pixel wordmark in cream and gold with a soft purple outer glow and a tiny crystal dotting the first letter; two versions stacked: top row 1200 px wide full glow, bottom row the same wordmark 600 px wide without glow (for the pause menu).

---

## BATCH 2 — Clean path sets (3 images)

> Make THREE SEPARATE IMAGES, 1536×1024 each, 16-bit pixel art, top-down 3/4 view, warm Stardew / Sun Haven palette, flat #FF00FF magenta background, NO grid lines, NO text, NO letterboxing. TILE RULE: 32×32 tiles at x = 24 + N×40 (36 columns), y = 24 + M×40, four rows. This is a PATH on GRASS. The edge must be SMOOTH and SOFT: a worn, slightly darker rim where the path meets the grass with a few blades of grass overhanging by 2-3 px, NEVER scalloped, NEVER with rounded bumps or bites; corners round gently over exactly 6 px. Tile order is FIXED, reading each row left to right, rows top to bottom: row 0: top edge ×3 variants, bottom ×3, left ×3, right ×3, outer corner top-left ×3, top-right ×3, bottom-left ×3, bottom-right ×3, inner corner top-left ×3, inner top-right ×3, inner bottom-left ×3, inner bottom-right ×3 (36). Row 1: diagonal A ×2, diagonal B ×2, horizontal strip (top+bottom edge) ×2, vertical strip ×2, end cap up ×2, end cap down ×2, end cap left ×2, end cap right ×2, U open up ×2, U open down ×2, U open left ×2, U open right ×2, single isolated ×2, three-way T up/down/left/right ×1 each, plus 6 pure fills (36). Row 2: 36 more pure FILL variants (subtle, seamless, no edges). Row 3: 36 DETAIL DECALS on transparent magenta (pebbles, hoof prints, ruts, puddle, fallen leaf, a dandelion, a crack) that sit on the fill.
>
> IMAGE 1 "w186_path_dirt.png": packed warm brown dirt path on spring grass.
> IMAGE 2 "w187_path_cobble.png": grey-tan rounded cobbles with moss in the joints on grass (the town avenues).
> IMAGE 3 "w188_path_sand.png": pale beach sand on dune grass (the beach walkways); decals are shells, starfish, footprints.

---

## BATCH 3 — Penguin hero: every pose, plus his own hats and scarves (3 images)

> Make THREE SEPARATE IMAGES, 1536×1024 each, 16-bit pixel art, top-down 3/4 view, clean 1px dark outlines, warm palette, flat #FF00FF magenta background, NO grid lines, NO text, NO letterboxing. GRID RULE: 64×96 cells at x = 24 + N×88 (16 columns), y = 24 + M×120 (8 rows). The PENGUIN HERO: a small round blue-black penguin, white belly, orange beak and feet, big friendly eyes, a tiny crystal pendant — EXACTLY as already designed (keep him matching his existing idle/walk/run sheet), drawn 48 px tall in every cell, feet at the bottom.
>
> IMAGE 1 "w189_penguin_actions.png": row 0 ATTACK DOWN ×4 (wing swipe toward camera), row 1 ATTACK UP ×4, row 2 ATTACK SIDE ×4 (facing right; we flip for left) + HURT ×2 + FAINT ×2, row 3 HOE down/side/up ×4 each (12) + 4 spare, row 4 WATERING CAN down/side/up ×4 each, row 5 AXE down/side/up ×4 each, row 6 PICKAXE down/side/up ×4 each, row 7 FISHING cast side ×4, reel side ×4, hold item overhead ×2, eat ×2, sit ×1, sleep ×1, wave ×2. Tools ARE drawn in his wings for this sheet (hoe, can, axe, pickaxe, rod), small and clear.
> IMAGE 2 "w190_penguin_life.png": row 0 SWIM side ×4, swim down ×4, swim up ×4, float ×2, dive ×2; row 1 RIDING the horse (128×128 cells for this row only: walk side ×4, run side ×2, walk down ×2, walk up ×2) — the penguin sits in the saddle; row 2 CARRY ×2, pet animal ×2, dance ×4, laugh ×2, umbrella ×2, shiver ×2, cheer ×2; row 3 POWER-UP (glowing crystal aura) ×8 + magic cast down/side/up ×2 each (wings raised, light between them); rows 4-7 the same four rows again but with the PENGUIN CEREMONY outfit (little purple sash and silver circlet).
> IMAGE 3 "w191_penguin_wear.png": accessories drawn TO FIT THE PENGUIN'S HEAD (not the human hero), each isolated with 16 px gaps, front/side/back views side by side: SCARVES ×6 (red, blue, green, yellow, purple, white; a knotted scarf under the beak with one tail), HATS ×12 (straw hat, wool beanie, top hat, wizard hat, flower crown, miner's helmet with lamp, sailor cap, crown, pumpkin hat, santa hat, bucket hat, sun visor), GOGGLES ×2, BOW TIE ×3 colours, BACKPACK ×2 (small, big). Plus a 6-cell row of PALETTE SWATCH penguins: classic, snow-white, midnight-blue, sunset-orange, mint, rose — the full penguin recoloured, idle pose, for the character creator.

---

## BATCH 4 — Pup gear and fighting poses, for every pet (3 images)

> Make THREE SEPARATE IMAGES, 1536×1024 each, 16-bit pixel art, top-down 3/4 view, warm palette, flat #FF00FF magenta background, NO grid lines, NO text, NO letterboxing. 64×64 cells at x = 24 + N×88 (16 columns), y = 24 + M×120 (8 rows), feet at the bottom. The ORIGINAL PUP is the small black-and-tan shepherd puppy with the green collar already in the game; the other pets are the brown dog, corgi, shepherd, hound, white dog, golden retriever, collie, husky, and the three cats (orange, grey, calico) — keep every one EXACTLY matching its existing sheet.
>
> IMAGE 1 "w192_pup_fight.png": one pet per row (original pup, brown, corgi, shepherd, hound, white, golden, collie): BITE side ×4 (lunge, snap), BARK side ×2, HURT ×2, LIMP home side ×4 (one paw up, tail down), GUARD stance ×2 (planted, hackles up), HOWL ×2.
> IMAGE 2 "w193_pup_fight_b.png": same row format for husky, cat orange, cat grey, cat calico (cats: pounce, hiss, hurt, slink, arch, yowl), then rows 4-7: DIG ×6 + FETCH carrying an item in mouth side ×4 + SIT-UP beg ×2 + SLEEP curled ×2 + ROLL ×2 for the original pup, brown dog, corgi, shepherd.
> IMAGE 3 "w194_pup_gear.png": GEAR LAYERS drawn to fit the pets, isolated with 16 px gaps, side/front/back views: LEATHER COLLAR, STUDDED IRON COLLAR, CRYSTAL COLLAR (glowing), SMALL SADDLE PACK, LARGE SADDLE PACK (two bags), TRAIL PACK with bedroll, PUP BOOTS ×4, a red BANDANA, a tiny CRYSTAL CHARM on the collar — each drawn once sized for a 32 px dog and once for a 28 px cat. Then a row of ITEM ICONS 32×32 for the same gear plus Pup Treat (a bone biscuit), and 6 COMMAND ICONS 48×48 (heel/paw print, attack/fang, guard/shield-paw, stay/sitting dog, recall/whistle, pack/saddlebag) and one 48×48 PUP TAB icon (dog face) in the same style as the existing menu tab icons.

---

## BATCH 5 — Fruit trees and the two-row cliff faces (3 images)

> Make THREE SEPARATE IMAGES, 1536×1024 each, 16-bit pixel art, top-down 3/4 view, warm palette, flat #FF00FF magenta background, NO grid lines, NO text, NO letterboxing.
>
> IMAGE 1 "w195_fruit_trees.png": isolated TREES with 24 px gaps, base at the bottom, each ~96 px tall: CHERRY (bare winter, spring blossom, spring with cherries, summer green, fall orange), ORANGE (bare, spring flowers, summer with oranges, fall, snowy), PLUM (bare, blossom, summer with plums, fall, snowy), APPLE (bare, blossom, summer green, fall with red apples, snowy), plus a 4-frame SHAKE strip for each tree in its fruiting state (fruit falling), and 32×32 fruit icons for cherry, orange, plum, apple and a wicker basket.
> IMAGE 2 "w196_cliff_faces.png": TILE RULE 32×32 at x = 24 + N×40 (36 columns): a RAISED GRASS TERRACE seen from below, TWO TILES TALL. Row 0: the UPPER face tiles (grass lip over rock): left end ×2, middle ×8 variants, right end ×2, inner corners ×2, outer corners ×2, plus 20 spares drawn as more middle variants. Row 1: the LOWER face tiles directly beneath (rock base with roots, pebbles, moss; must join seamlessly to row 0 above it), same order. Row 2: RAMPS cut into the face, each two tiles tall drawn as top tile + bottom tile side by side: dirt ramp left/middle/right/single, stone stairs left/middle/right/single, wooden steps single, rope ladder, vine, waterfall over the face ×4 frames. Row 3: the same face set as rows 0-1 but STONE (quarry) instead of grass, 18 upper + 18 lower.
> IMAGE 3 "w197_region_walls.png": TILE RULE 32×32 at x = 24 + N×40 (36 columns), four rows, each row a REGION BORDER WALL seen from the inside, 36 tiles: left end ×3, middle ×24 variants, right end ×3, top-left/top-right/bottom-left/bottom-right corners ×1 each, 2 spares. Row 0 MARSH: a wall of dead black roots and drowned stumps with mist. Row 1 HIGHLANDS: a wall of blue ice and snow-capped rock. Row 2 RUINS: broken ancient masonry, carved faces, ivy. Row 3 RIVERLANDS: a steep green river bank with exposed roots and reeds, water at the base.

---

## BATCH 6 — Icons: Sorcery, Pup tree, spells, buffs, speech bubbles, boss cards (3 images)

> Make THREE SEPARATE IMAGES, 1536×1024 each, 16-bit pixel art, warm palette, flat #FF00FF magenta background, NO grid lines, NO text, NO letterboxing. Icons are 48×48 at x = 24 + N×64 (23 columns), y = 24 + M×64, each a bevelled rounded square with a dark outline and a soft inner highlight, like the existing skill icons.
>
> IMAGE 1 "w198_icons_sorcery_pup.png": row 0 SORCERY NODE ICONS in this order: Spark, Deep Well, Attunement, Glow, Light Lance, Rain Call, Haste, Crystal Sense, Shard Skin, Ember, Radiance, Growth, Lull, Mana Flow, Crystal Shield, Moonbeam, Sunder, Warp Home, Bloom, Resonance, Gem Eye, Light Bearer, Dreamwalk; row 1: Crystal Heart, Awakening, then the three PATH badges (Light: sun ray, Dream: crescent in a cloud, Crystal: faceted gem) and 13 SPELL CAST icons (same spells, round, glowing, for the hotbar); row 2 PUP NODE ICONS: Tough Pup, Sniff, Fetch, Bite, Guard Dog, Quick Paws, Saddle Pack, Howl, Truffle Nose, Thick Coat, Big Pack, Rescue, Hunter, Tracker, Trail Pack, Dream Hound, Best Friend; row 3: skill tree TAB icons for Farming, Mining, Foraging, Fishing, Combat, Bartering, Building, Sorcery, Pup (9), and 9 LOCKED versions (grey with a small padlock).
> IMAGE 2 "w199_icons_buffs_bubbles.png": row 0 BUFF icons 32×32: speed, luck, defense, warm, cool, well fed, rested, wet, poisoned, burning, asleep, stunned, shielded, haste, glow, resonance, pup aura (17); row 1 SPEECH BUBBLES 48×40 for villagers talking to each other: "...", "!", "?", heart, music note, angry scribble, laugh, zzz, idea bulb, crossed-swords, fish, coin (12) in a cream bubble with a tail pointing down; row 2 EMOTE strip 4 frames each for: laugh, wave, nod, shrug (16 cells); row 3 JOURNAL icons 32×32: story quest, villager quest, board job, hint/pencil, done check, new star, pup, festival, bell, letter, map pin, warning (12).
> IMAGE 3 "w200_boss_cards_b.png": three BOSS INTRO CARDS 500×168 each, stacked with 40 px gaps, same frame style as the existing cards (dark painted banner with a gold border, the boss on the left, a dramatic sky on the right, NO text): the MARSH WITCH (a tall bent figure of roots and lantern-light, frogs at her feet), the GOLEM KING (a crowned stone giant with crystal eyes), the RUIN WARDEN (a stone knight statue cracked and glowing from inside). Below them, 6 small 96×96 BOSS PORTRAITS (the three above plus Big Grump, the President's Man, the Commander) for the journal.

---

## NOT ART (for later): sound list

> Ambience per region (marsh frogs, quarry wind and chains, highlands wind, ruins hum, riverlands water, orchard bees); pup barks/whines/howl; spell casts (spark, lance, radiance, lull, bloom, warp, dreamwalk); festival music ×4; shop/inn/bank/school/chapel interior loops; fruit shake; board pin.
