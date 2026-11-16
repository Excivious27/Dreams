# Dreams — Art Prompts 09: everything still missing for a seamless build

WHAT THIS COVERS (checked against the game as of 16 Nov, after all of Prompts 08 landed): the hero's costumes only have WALK and ACTION rows, so swimming/riding/sleeping/fishing in a costume snap back to the bare base; every villager has one idle + walk but no work/sit/talk/sleep poses and no seasonal outfits; the hero has no portrait set per costume; the six new regions have ground + props but their 47-tile EDGE sets came back as unlabeled squares (need a labelled, strict grid); the town plaza/docks/stable/weather/HUD sheets came back as loose props (good) but several key pieces are missing or unlabeled; there is no interior art for the new buildings (mansion, school, bank, stable, lodge, mill, lighthouse keeper's room, the six regional huts); no shop-counter/portrait art for the 8 new villagers' shops; no festival art; no farm animal babies/adult sets for new animals (goat, sheep, llama, donkey); no pet variants; no crop sprites for the 12 new seeds; no cooking/alchemy/mill station animations for the new recipes; no boss intro cards; no title screen / logo / save-slot art; no sound (not art, but listed at the end so the list is complete).

RULES THAT APPLY TO EVERY IMAGE: 1536×1024, 16-bit pixel art, top-down 3/4 view, clean 1px dark outlines, warm saturated Stardew Valley / Sun Haven palette, flat #FF00FF magenta background, no shading outside sprites, NO GRID LINES, NO TEXT OR LABELS anywhere (labels broke the last tile sheets), no watermark, and NO LETTERBOXING: fill the whole 1536×1024 canvas (five of the last six region sheets came back as 1024×1024 squares with black bars). Character sheets use the GRID RULE: 64×96 cells at x = 24 + N×88, y = 24 + M×120 (16 columns, 8 rows). The hero = medium-skin slim BALD 64 px farmer, same silhouette in every cell. Tile sheets use the TILE RULE: 32×32 tiles at x = 24 + N×40, y = 24 + M×40, exactly 36 columns, and the art inside each tile must continue across its borders (draw the whole set as ONE continuous landscape, then cut).

Save every image under the exact file name in quotes and upload to `art/incoming/`.

---

## BATCH 1 — Costume bodies: the poses that are still bare (6 images)

> Make SIX SEPARATE IMAGES, 1536×1024 each, 16-bit pixel art, top-down 3/4 view, clean 1px dark outlines, warm Stardew / Sun Haven palette, flat #FF00FF magenta background, no grid lines, no text, no letterboxing. GRID RULE: 64×96 cells at x = 24 + N×88, y = 24 + M×120 (16 columns, 8 rows). The hero is the medium-skin, slim-build, BALD 64 px farmer drawn COMPLETE in the row's costume, identical silhouette every cell; tools are never drawn.
>
> LIFE ROW ORDER (16 cells): sit (on a bench, facing down), sleep (lying, side), faint (face down), carry overhead ×2, pet animal (crouch) ×2, wave ×2, dance ×4, eat ×2 (bite, chew), drink.
> WATER ROW ORDER (16 cells): swim side 1-4, swim down 1-4, swim up 1-4, float, dive, climb out ×2 — only a small splash ring around the body, no water surface.
>
> IMAGE 1 "w150_costume_armor_life.png": LIFE rows for the 8 armor sets (Leather, Copper, Iron, Steel, Silver, Gold, Crystal, Moon), one per row in that order.
> IMAGE 2 "w151_costume_outfit_life.png": LIFE rows for the 8 outfits (Farmer, Forester, Fisher, Miner, Merchant, Scholar, Neon Street, Penguin Ceremony).
> IMAGE 3 "w152_costume_armor_water.png": WATER rows for the 8 armor sets (yes, swimming in armor: wet, heavy, comic).
> IMAGE 4 "w153_costume_outfit_water.png": WATER rows for the 8 outfits.
> IMAGE 5 "w154_costume_riding.png": 128×128 cells at x = 24 + N×152 (10 columns), y = 24 + M×125 (8 rows). The hero riding the HORSE in each costume as one complete sprite: rows 0-7 = the 8 armor sets, 10 cells each: walk side 1-4, run side 1-2, walk down 1-2, walk up 1-2.
> IMAGE 6 "w155_costume_riding_b.png": same grid, the 8 outfits.

---

## BATCH 2 — Villagers: full life sets and seasonal looks (6 images)

> Make SIX SEPARATE IMAGES, 1536×1024 each, same style and rules (no grid lines, no text, no letterboxing). 48×64 cells at x = 24 + N×88 (16 columns), y = 24 + M×120 (8 rows), one villager per row, feet at the bottom of the cell. Keep each villager EXACTLY as already designed (same hair, clothes, colours) so they match their existing walk sheets.
>
> VILLAGER LIFE ROW (16 cells): work pose 1-2 (their job), sit, talk/gesture 1-2, laugh, wave, sleep (in bed, top-down), carry, eat, dance 1-2, umbrella (rain), cold/shiver (winter), fish from a bank, shop-counter pose (hands on counter, facing down).
>
> IMAGE 1 "w156_villagers_life_a.png": Maple (store), Gideon (smith), Wren (potions), Alder (mayor), Finn (fisherman), Lumi (artist), Theo (scholar), Hazel (farmer).
> IMAGE 2 "w157_villagers_life_b.png": Bram (innkeeper), Posy (baker), Juniper (nurse), Rook (hunter), Sal (drifter), Marlowe (lighthouse keeper), Orla (miller), Benno (stable hand).
> IMAGE 3 "w158_villagers_life_c.png": Ivy (bank teller), Tam (shepherd), Old Moss (hermit), Granite (foreman), Sel (ruins scholar), Pip, Wren jr, Tobin (kids; Mabel on image 4).
> IMAGE 4 "w159_villagers_seasonal.png": SEASONAL OUTFIT walk rows (idle down, idle up, idle side, walk side ×4, walk down ×4, walk up ×4, 1 spare): row 0 Maple winter coat, row 1 Gideon summer apron, row 2 Wren fall shawl, row 3 Alder festival sash, row 4 Finn winter oilskins, row 5 Hazel summer straw hat, row 6 Posy winter scarf, row 7 Mabel (kid) all-season walk set.
> IMAGE 5 "w160_villagers_seasonal_b.png": same row format: Lumi winter, Theo summer, Bram festival, Juniper winter, Rook winter furs, Sal winter coat, Pip winter, Tobin summer.
> IMAGE 6 "w161_villager_portraits_seasonal.png": 96×96 cells at x = 24 + N×120 (12 columns), y = 24 + M×120 (8 rows): portrait variants (neutral, happy, sad, surprised) × (winter outfit, festival outfit, summer outfit) for Maple, Gideon, Wren, Alder, Finn, Hazel, Posy, Rook — one villager per row, 12 cells = 4 expressions × 3 outfits.

---

## BATCH 3 — Region EDGE tile sets, strict and labelled by position only (6 images)

> Make SIX SEPARATE IMAGES, 1536×1024 each, 16-bit pixel art, top-down 3/4 view, warm Stardew / Sun Haven palette, flat #FF00FF magenta background, NO grid lines, NO text, NO letterboxing (fill the full 1536×1024). TILE RULE: 32×32 tiles at x = 24 + N×40 (36 columns), y = 24 + M×40, four rows = 144 tiles, each tile isolated on magenta but drawn so edges CONTINUE across tile borders. This sheet is ONE "feature ground" against grass. Tile order is FIXED and must be followed exactly, reading each row left to right, rows top to bottom: row 0: top edge ×3 variants, bottom ×3, left ×3, right ×3, outer corner top-left ×3, top-right ×3, bottom-left ×3, bottom-right ×3, inner corner top-left ×3, inner top-right ×3, inner bottom-left ×3, inner bottom-right ×3 (36). Row 1: diagonal A ×2, diagonal B ×2, horizontal strip (top+bottom edge) ×2, vertical strip ×2, end cap up ×2, end cap down ×2, end cap left ×2, end cap right ×2, U open up ×2, U open down ×2, U open left ×2, U open right ×2, single isolated ×2, three-way T up/down/left/right ×1 each, plus 6 pure fills (36). Row 2: 36 more pure FILL variants (subtle texture differences, no edges). Row 3: 36 DETAIL DECALS that sit on the fill (small stones, plants, cracks, puddles; transparent background).
>
> IMAGE 1 "w162_edge_marsh.png": black bog water with reed rims against marsh grass.
> IMAGE 2 "w163_edge_quarry.png": a one-tile cut-stone terrace step (chiselled face on the bottom/sides) against gravel.
> IMAGE 3 "w164_edge_orchard.png": packed-earth sheep track against lush grass.
> IMAGE 4 "w165_edge_highlands.png": snow patch against frosty tussock grass.
> IMAGE 5 "w166_edge_ruins.png": raised mossy flagstone floor with a crumbled lip against grass.
> IMAGE 6 "w167_edge_river.png": flowing river (with a 4-frame current animation drawn as 4 consecutive fill tiles in row 2, and 4 rapids tiles) against wet meadow grass with a wet sand bank.

---

## BATCH 4 — Interiors for every new building (6 images)

> Make SIX SEPARATE IMAGES, 1536×1024 each, same style, flat #FF00FF magenta background, NO grid lines, NO text, NO letterboxing. Each image = interior KITS: on the top row, 32×32 floor tiles ×8 and wall tiles ×8 (wall: left end, middle ×3, right end, corner, window, door) for that building's look; below, every piece of furniture isolated with 16 px gaps, base at the bottom, sized for a 26 px hero (a chair ≈ 32 px tall, a counter ≈ 48 px wide).
>
> IMAGE 1 "w168_int_mansion_bank.png": top half the MAYOR'S MANSION (parquet floor, panelled wall; grand desk, bookcases ×3, portraits ×6 of past mayors, globe, fireplace 4-frame, armchairs ×2, chandelier, rug, kettle on a stand, filing cabinet, town charter on a lectern), bottom half the BANK (marble floor, stone wall; teller window with brass grille, vault door closed/open, ledger desk, coin stacks ×3, safe, velvet rope posts ×3, clock, ivy plant, waiting bench).
> IMAGE 2 "w169_int_school_stable.png": top half the SCHOOL (plank floor, chalkboard wall; four small desks, teacher's desk, chalkboard with the moon drawn on, globe, bookshelf, coat hooks, easel, stack of slates, class pet frog in a jar, bell, alphabet frieze) and the STABLE interior (dirt floor, timber wall; stalls ×3 open/closed, hay loft ladder, tack wall, feed bins, water trough 4-frame, lantern, saddle stand, cat on a beam).
> IMAGE 3 "w170_int_lodge_mill.png": top half ROOK'S LODGE (stone floor, log wall; pelts on the wall ×3, bow rack, trap pile, drying meat, map table with pins, fire pit 4-frame, bunk, antler hooks, skinning bench), bottom half ORLA'S MILL (flour-dusted floor, timber wall; millstones 4-frame turning, hopper, flour sacks ×4, grain chute, scales, sieve, bread crates, mouse hole, the big wheel axle through the wall).
> IMAGE 4 "w171_int_lighthouse_huts.png": LIGHTHOUSE keeper's room (round stone floor, curved wall pieces ×6; spiral stair up, lamp mechanism 4-frame, oil cans, charts on the wall, telescope, hammock, kettle, logbook desk, fog bell) and the three HUTS: Tam's shepherd hut (wool bales, cider press, crook rack, cot), Old Moss's marsh hut (frog jars ×3, reed mats, bubbling pot 4-frame, hanging herbs ×4), and the fishing hut at the river (nets, rods ×3, bait buckets, fish on ice).
> IMAGE 5 "w172_int_quarry_ruins.png": GRANITE'S quarry office (stone floor; blueprint table, hard hats on hooks, dynamite crate, ore samples case ×6 minerals, time clock, coffee pot 4-frame, cot, safety poster frame blank) and SEL'S ruins camp (tent interior: rune rubbings ×4, specimen table, lantern, bedroll, crystal in a cage glowing 4-frame, stacked tablets, ink and brushes).
> IMAGE 6 "w173_int_shop_counters.png": SHOP COUNTER pieces for all 8 new villagers so they can sell: Marlowe's lamp-oil counter, Orla's flour counter, Benno's tack counter, Ivy's teller counter, Tam's wool counter, Old Moss's jar counter, Granite's ore counter, Sel's relic counter — each a 96×48 counter with goods on it and an open/closed sign variant (no readable text: a hanging board, blank), plus a 48×48 "shop bell", "coin tray", "price tag" (blank), "open flag", "closed shutter" set.

---

## BATCH 5 — Crops, animals, pets, stations, festivals (6 images)

> Make SIX SEPARATE IMAGES, 1536×1024 each, same style, magenta background, NO grid lines, NO text, NO letterboxing.
>
> IMAGE 1 "w174_crops_c.png": 32×48 cells at x = 24 + N×40 (36 columns), y = 24 + M×60 (12 rows): the 12 NEW CROPS, one per row, growth stages: seedling, sprout, young, growing, mature, harvest-ready, harvested stub, withered, + 4 seasonal/quality variants: cranberry, hops (on a pole), grape (on a trellis), tea leaf bush, cotton, flax, sugar beet, rice (in a paddy square), lotus (in water), snow pea (on a trellis), ghost pepper, moon melon (glowing).
> IMAGE 2 "w175_animals_c.png": 48×48 cells at x = 24 + N×88 (16 columns), y = 24 + M×120 (8 rows): goat adult (idle ×2, walk ×4, eat ×2, sleep ×2, hurt, happy ×2, 3 spare) row 0, goat kid row 1, sheep adult row 2 (incl. shorn variant idle ×2), lamb row 3, llama adult row 4, llama cria row 5, donkey adult row 6, foal row 7.
> IMAGE 3 "w176_pets.png": same grid: DOG variants ×4 (the brown-with-blue-eyes pup is already in the game; add corgi, shepherd, spotted hound, fluffy white) rows 0-3 with idle ×2, walk ×4, run ×4, sit, sleep, bark ×2, play ×2; CAT variants ×4 (orange, grey, black, calico) rows 4-7 same cells.
> IMAGE 4 "w177_stations_anim.png": 64×64 cells at x = 24 + N×88 (16 columns), y = 24 + M×120 (8 rows), 4-frame working animations per station tier: row 0 kitchen stove (tier 1-4, 4 frames each), row 1 alchemy cauldron (4 tiers), row 2 mill (4 tiers: hand quern, small mill, big mill, water-powered), row 3 smithy forge (4 tiers), row 4 workbench (4 tiers), row 5 loom and spinning wheel (2 tiers each), row 6 cider press, cheese press, beehive extractor, kiln (4 frames each), row 7 the finished-product "pop" FX ×4 kinds.
> IMAGE 5 "w178_festival_spring_summer.png": FESTIVAL decor: SPRING egg festival (bunting pastel ×3, egg baskets ×3, hidden eggs ×12 colours small, maypole 4-frame ribbons, flower arch, petal carpet tiles ×4, stage) and SUMMER lantern festival (paper lanterns ×6 colours 2-frame, lantern strings ×3, floating lanterns on water 4-frame ×3, fireworks 6-frame ×3 colours, food stalls ×4, dance floor tiles ×4, bonfire 4-frame big).
> IMAGE 6 "w179_festival_fall_winter.png": FALL harvest fair (pumpkin stacks ×3, corn stooks ×3, hay maze walls straight/corner/end, scarecrow contest ×4, pie table, prize ribbons ×3, cider barrels, lantern turnips ×4, leaf pile 4-frame jump) and WINTER star festival (snowman 3 stages, ice sculptures ×4, star lanterns ×4, gift pile, hot cocoa stand, skating pond edge tiles ×9, snowball 4-frame, evergreen with lights 2-frame big, candle rows ×3).

---

## BATCH 6 — Title, menus, bosses, sound list (4 images + a note)

> Make FOUR SEPARATE IMAGES, 1536×1024 each, same style, magenta background, NO grid lines, NO letterboxing. These may contain the single word "DREAMS" in image 1 only.
>
> IMAGE 1 "w180_title.png": a TITLE SCREEN: 1536×1024 painted key art (not tiles) of the farm at dawn with the Light Crystal glowing in the field, the town and lake in the distance, the moon above — plus, isolated on magenta in the lower third, the wordmark "DREAMS" as chunky pixel letters (three variants: plain, glowing, with a small crescent), a "press to start" ornament (no text, a pulsing gem 4-frame), and a 2-frame twinkle.
> IMAGE 2 "w181_menus.png": menu chrome, isolated on magenta: save-slot card 240×72 (empty, filled, selected), slot number badges ×3, arc badges (penguin crest, gangster crest), season/day chips, a pause panel 240×320, buttons 96×28 ×4 states (normal, hover, pressed, disabled) in wood and in parchment, toggle switch on/off, slider, checkbox ×2, scroll bar pieces ×3, tab strip ×6 tabs normal/selected (Items, Skills, Social, Map, Quests, Options — as icons only: bag, star, heart, map, scroll, gear), tooltip bubble 9-slice, a confirm dialog 200×120, loading spinner 8-frame, cursor hand/arrow/grab.
> IMAGE 3 "w182_boss_cards.png": 6 boss INTRO CARDS 480×160 each (isolated, 2 columns × 3 rows): Big Grump, Thug Brute (the President's man), Marsh Witch, Golem King, Ruin Warden, Dark Crystal — each a dramatic head-and-shoulders portrait on the left, a dark gradient to the right (space for a name, no text), with an ornate pixel frame.
> IMAGE 4 "w183_hero_portraits_costumes.png": 96×96 cells at x = 24 + N×120 (12 columns), y = 24 + M×120 (8 rows): dialogue portraits of the medium-slim hero WEARING each armor set (rows 0-3: leather, copper, iron, steel / silver, gold, crystal, moon — 2 sets per row, 6 expressions each: neutral, happy, sad, angry, surprised, determined) and each outfit (rows 4-7: the 8 outfits, 2 per row, same 6 expressions).

> NOTE (no image): the last thing standing between this build and "seamless" is audio. When you're ready I'll give you a separate list for a music tool (12 region/season tracks, 4 festival tracks, 2 boss tracks, title theme) and an SFX list (~90 one-shots: tools by tier, footsteps by ground, UI, animals, weather). The current placeholders are generated beeps.
