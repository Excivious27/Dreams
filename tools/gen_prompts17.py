#!/usr/bin/env python3
"""Writes docs/ART-PROMPTS-17.md: everything still drawn as a stand-in that
Art Prompts 16 doesn't already cover: the 13 skill trees' node icons and the
Sun Haven-style skills screen, the remaining item icons, street thugs, the new
screens (crafting, slots, settings, hack, endings), and Prompts 13 (never sent
back). Run: python3 tools/gen_prompts17.py
"""
import json, os, re
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = json.load(open(f"{R}/data/skills.json"))["skills"]
VIS = {"extra_crop": "a sprout bursting with extra vegetables", "double_harvest": "two baskets of crops", "farm_energy": "a light watering can with a feather",
 "extra_day": "a clock over a growing sprout", "animal_yield": "an egg and a milk pail", "crop_value": "a crop with a coin", "star_chance": "a crop with a gold star",
 "seed_back": "a seed returning to an open hand", "growth": "a sunflower in sunbeams", "stone_bonus": "a pile of stones", "mine_energy": "a pickaxe with a feather",
 "ore_bonus": "copper ore chunks", "double_hit": "a pickaxe with a double strike flash", "gem_chance": "a sparkling gem", "shard_bonus": "purple crystal shards",
 "forage_bonus": "a basket of berries", "rare_forage": "a glowing rare mushroom", "wood_bonus": "a stack of logs", "chop_bonus": "an axe in a stump",
 "sap_chance": "a drop of amber sap on bark", "bite_speed": "a bobber with ripples", "escape_less": "a taut fishing line", "double_fish": "two fish on one hook",
 "rare_fish": "a glowing rare fish", "fish_value": "a fish with a coin", "chest_chance": "a small treasure chest", "damage": "a sword with a shine",
 "crit": "a sword striking a star", "block": "a raised shield", "damage_reduction": "a sturdy breastplate", "hp": "a red heart", "energy": "a green energy bolt",
 "kill_energy": "a bolt rising from a defeated slime", "sell_bonus": "a coin stack with an up arrow", "interest": "a piggy bank", "gift_bonus": "a wrapped gift with a heart",
 "wood_discount": "a plank with a tag", "stone_discount": "a brick with a tag", "craft_speed": "a hammer with motion lines", "build_discount": "a blueprint",
 "spark_damage": "a spark of light", "spell_power": "a glowing crystal staff top", "mana": "a blue mana drop", "mana_regen": "a mana drop with a circular arrow",
 "spell_discount": "a spellbook with a tag", "pet_hp": "a dog bone with a heart", "pet_dmg": "a paw with claws", "pet_speed": "a paw with speed lines",
 "pet_def": "a dog collar with a shield tag", "pass_risk": "a folded bill and a calm eye", "heat_cool": "a small flame going out", "wash_bonus": "a washing machine window with coins",
 "job_pay": "an envelope of pay", "gun_damage": "an old toy-like six-shooter (no blood)", "supply_rate": "a crate with an up arrow", "helper_hp": "a little helper crystal/drone with a heart",
 "ability_cooldown": "a paw with a clock", "colony_discount": "a shell with a tag", "capture_speed": "a flag on a hill with speed lines", "start_supply": "a stack of crates",
 "spawner_discount": "a spire blueprint with a tag", "helper_damage": "a helper firing a spark", "ticket_bleed": "a cracked enemy banner", "ticket_guard": "an unbroken banner",
 "team_damage": "two swords crossed", "team_defense": "two shields overlapping", "team_heal": "two hands sharing a heart", "friend_gain": "a heart with a smile",
 "pet_bond": "a hand and a paw touching", "team_xp": "an open book with two hands"}
rules = open(f"{R}/docs/ART-PROMPTS-16.md").read()
p13 = open(f"{R}/docs/ART-PROMPTS-13.md").read()
def blocks(text, batch):
    m = re.search(r"## BATCH %d .*?\n(.*?)(?=\n## |\Z)" % batch, text, re.S)
    return m.group(1).strip().strip("-").strip()
L = []
L.append("# Dreams — Art Prompts 17: skill trees, the last stand-ins, and Prompts 13\n")
L.append("WHAT THIS COVERS, in order: (1) Prompts 13 again (the penguin-book creatures and places: never came back), (2) icons for all 520 skill-tree nodes plus the Sun Haven-style skills screen, (3) the last 37 item icons, (4) the six street-thug types and the Big Grump, (5) the new screens (crafting, save slots, settings, the hack, quality stars), (6) the four ending paintings, (7) turf and heist pieces, (8) the President's new look, (9) the app icon. Art Prompts 16 is the other half of the job (ground, cliffs, stairs, beach, caves, battles, colonies, lieutenants, town projects, Marked, Gift effects, the chrome).\n")
L.append("RULES THAT APPLY TO EVERY IMAGE: 1536×1024, 16-bit pixel art, clean 1px dark outlines, warm saturated Stardew Valley / Sun Haven palette (gangster-arc pieces in the dark underworld palette where it says so), flat #FF00FF magenta background unless the batch says fill the image, NO GRID LINES, NO TEXT OR LABELS OR NUMBERS anywhere, no watermark, NO LETTERBOXING. At least 16 px of clear magenta between separate sprites. All ages: no blood, nothing gory.\n")
L.append("SKILL ICON GRID (batch 2): 40 square icons, each 112×112, in 4 rows of 10: icon N (1–40) sits at x = 24 + ((N−1) mod 10)×148, y = 24 + floor((N−1)/10)×148. Each icon is a small framed picture like Sun Haven's skill icons: a rounded square tile with a 3px gold frame, a soft coloured background in the ROW COLOUR given, and one clear object in the middle with a soft top-left light. Every row uses its own background colour; icons in a row look like a set. No numbers or text on the icons.\n")
L.append("\n---\n")
L.append("## BATCH 1 — Prompts 13 again: the penguin book's creatures, places and items (12 images)\n")
L.append("These never came back, so the game still uses stand-ins for Catkins' Cat-topia, the finargles, the crystal babies, the merkitties, the catship and the summit. Same prompts as before.\n")
L.append(blocks(p13, 1) + "\n")
L.append(blocks(p13, 2) + "\n")
L.append("\n---\n")
ROWCOL = ["soft leaf green", "soft sky blue", "warm terracotta", "soft violet"]
order = ["farming", "mining", "foraging", "fishing", "combat", "magic", "pup", "bartering", "building", "leadership", "strategist", "harmony", "hustle"]
L.append("## BATCH 2 — Skill-tree icons: 13 images, one per skill (40 icons each)\n")
L.append("> Make THIRTEEN SEPARATE IMAGES, one per skill, using the SKILL ICON GRID (40 icons, 112×112, 4 rows of 10, x = 24 + col×148, y = 24 + row×148). Row 1 background soft leaf green, row 2 soft sky blue, row 3 warm terracotta, row 4 soft violet. Gold 3px frame on every icon. EVERY ICON MUST LOOK DIFFERENT: draw what the node's NAME suggests (\"Morning Dew\" = dewdrops on a leaf, \"Rally Cry\" = a raised fist with sound waves), using its theme only as a guide; icons get grander left to right (tier I simple, tier X ornate with a little sparkle). No text, no numbers.\n>")
for i, sk in enumerate(order):
    nodes = sorted(S[sk]["nodes"], key=lambda n: (n["row"], n["tier"]))
    br = S[sk]["branches"]
    parts = []
    for n in nodes:
        k = next(iter(n.get("effect", {}) or {}), "")
        hint = VIS.get(k, n["desc"].split("(")[0].strip().lower())
        parts.append("%d. %s (theme: %s)" % (len(parts) + 1, n["name"], hint))
    style = " DARK UNDERWORLD palette with neon accents (gangster arc)." if sk == "hustle" else (" crystal-pastel palette (penguin arc)." if sk == "harmony" else "")
    L.append("> IMAGE \"w%d_skill_icons_%s.png\": the %s tree.%s Row 1 = %s, row 2 = %s, row 3 = %s, row 4 = %s. Icons in order: %s.\n>" % (
        340 + i, sk, S[sk]["name"].upper(), style, br["0"], br["1"], br["2"], br["3"], "; ".join(parts)))
L.append("\n---\n")
L.append("## BATCH 3 — The skills screen and skill badges (1 image)\n")
L.append("> IMAGE \"w353_skills_ui.png\", magenta background, each piece separate: (1) a SKILLS PANEL frame 760×440 in Sun Haven style: deep red outer frame with gold corner studs, a dark wood inner board, empty (no text); (2) a TIER HEADER cell 60×36 in two states: open (bright green) and locked (dark brown); (3) a NODE FRAME 72×72 in four states: empty socket, available (soft glow), learned (gold frame), maxed (gold frame with a small green gem); (4) a SKILL POINTS box 150×90 (tan parchment, empty); (5) an EXP BAR 300×26 empty and its green fill 300×26; (6) THIRTEEN SKILL TAB BADGES 64×64 (round, coloured rim, one object each): Farming (watering can), Mining (pickaxe), Foraging (axe and leaf), Fishing (fish), Combat (sword), Sorcery (crystal staff), Pup (paw), Bartering (coin pouch), Building (hammer and plank), Leadership (two hands clasped over a star), Strategist (a map with a flag), Harmony (a crystal heart with a music note, pastel), Hustle (a fedora over a neon dollar sign, dark); (7) the same 13 badges again at 128×128 for the big panel.\n")
items = json.load(open(f"{R}/data/items.json"))
miss = [l[2:].strip() for l in open(f"{R}/docs/MISSING-ART.md").read().split("## Item icons")[1].split("##")[0].splitlines() if l.startswith("- ")]
L.append("\n---\n")
L.append("## BATCH 4 — The last item icons (1 image)\n")
L.append("> IMAGE \"w354_item_icons_last.png\": %d ITEM ICONS, 48×48 each, in rows of 12 (x = 24 + N×120, y = 24 + M×120), each isolated on magenta with the same soft top-left light as the other item icons, no frames, no text. In this order: %s.\n" % (len(miss), "; ".join("%d. %s (%s)" % (i + 1, items[m]["name"], str(items[m].get("desc", ""))[:70]) for i, m in enumerate(miss))))
L.append("\n---\n")
L.append("## BATCH 5 — Street thugs and the Big Grump (4 images)\n")
L.append("> Make FOUR SEPARATE IMAGES, character sheets on the GRID RULE (64×96 cells at x = 24 + N×88, y = 24 + M×120, 16 columns × 8 rows, feet at the bottom, 56 px tall), DARK UNDERWORLD palette, all ages: guns are old-fashioned and toy-like, no blood. Each image holds TWO characters, rows 0–3 and rows 4–7. Per character: row A IDLE down/up/side ×2 each, WALK down ×4, up ×4, side ×2; row B WALK side ×2 more, ATTACK down/up/side ×3 each, HURT ×2, KNOCKED DOWN (sitting, dazed stars) ×2, TAUNT ×1; row C SPECIAL MOVE ×6, VIEWS front/right/back/left, 2 spare; row D a 96×96 PORTRAIT across two cells and 3 expressions (angry, hurt, dazed).\n>\n> IMAGE \"w355_thugs_a.png\": the CYBER THUG (hoodie, visor glowing cyan, wrist gadget; special: a zap from the gadget) and the BRUTE (huge, flat cap, rolled sleeves; special: a ground stomp).\n> IMAGE \"w356_thugs_b.png\": the FLAME THUG (orange leather jacket, lighter; special: a puff of cartoon flame, no burns) and the SPEEDSTER (track suit, sneakers; special: a dash with speed lines).\n> IMAGE \"w357_thugs_c.png\": the CARD SHARK (waistcoat, visor, a fan of cards; special: flicks cards) and the ENFORCER (long coat, fedora, cane; special: a cane sweep).\n> IMAGE \"w358_big_grump.png\": warm farm palette instead: the BIG GRUMP (a grump the size of a cow: a big grumpy fluffball with stubby horns, tiny angry eyes; walk ×4 each way, attack ×4 (a belly flop), hurt ×2, poof ×4) on rows 0–3, and rows 4–7 the GRUMP COMMANDER's 4 minions as small grumps in four colours, idle ×4 and walk ×4 each.\n")
L.append("\n---\n")
L.append("## BATCH 6 — New screens: crafting, slots, settings, the hack, quality stars (2 images)\n")
L.append("> IMAGE \"w359_screens_a.png\", magenta background, each piece separate: (1) a CRAFTING PANEL 520×860 (wood board with brass corners, empty); (2) a RECIPE CARD 500×68 in three states: can make (warm), missing items (dull red tint), undiscovered (dark with a big faint question-mark shape, no letters); (3) a MAKE button 180×56 and pressed state; (4) a QUANTITY stepper: minus 48×48, plus 48×48, MAX 72×48 (no letters: use a double up-arrow); (5) QUALITY STARS 24×24: a silver star and a gold star, plus 16×16 versions; (6) a SAVE SLOT CARD 480×120 in three states: empty (dashed outline), penguin farm (pastel with a tiny penguin), gangster farm (dark with a tiny fedora).\n> IMAGE \"w360_screens_b.png\": (1) SETTINGS ICONS 48×48: music note, speaker, hand (button size), left/right hand swap arrows, a feather (easy mode), a save disk, a copy symbol, a paste clipboard; (2) the HACKING TERMINAL screen 520×860: a dark green-black CRT with scanlines and a chunky metal bezel, empty; four ARROW KEYS 96×96 (up, right, down, left) in dim and lit cyan states; a row of 12 progress pips 16×16 dim/lit; (3) a TURF FLAG 32×48 (a small crew flag on a pole, 4-frame wave) and a HEIST BOARD 160×120 (cork board with pins, string and photos of buildings, no text).\n")
L.append("\n---\n")
L.append("## BATCH 7 — The four endings (1 image, fill the whole image)\n")
L.append("> IMAGE \"w361_endings.png\": FOUR PAINTED PANELS, each 744×488, in a 2×2 layout with a 16 px dark gap, filling the whole 1536×1024 (no magenta). Soft painterly pixel art, warm and quiet. TOP LEFT \"Two Crystals\" (penguin arc, healed): a field at sunrise, two crystals side by side half-buried in the soil, one bright and one softly glowing, two penguins on the fence. TOP RIGHT \"The Quiet Mountain\" (penguin arc, shattered): the mountain summit at dawn, a small new sapling where a great dark crystal used to stand, sparkling dust in the air. BOTTOM LEFT \"A Tired Man\" (gangster arc, freed): a marble lobby, an old man in a grey suit sitting on the floor looking at his hands, a broken purple stone at his feet, morning light through tall windows. BOTTOM RIGHT \"The Chair\" (gangster arc, taken): a dark office high in a tower, a too-big chair facing a window over the neon city, a faint purple glow on the desk. No text anywhere.\n")
L.append("\n---\n")
L.append("## BATCH 8 — The President, rewritten (1 image)\n")
L.append("> IMAGE \"w362_president.png\": the PRESIDENT, now \"M.\": the hero's old mentor, the man who got them out of the city. Sixties, kind tired face that has gone cold, neat grey beard, grey three-piece suit, a fist-sized purple stone set in his chest where a pocket square would be (glowing softly, not gory). DARK UNDERWORLD palette, GRID RULE sheet as in batch 5: row 0 IDLE ×4 each direction (seated in a big chair ×2, standing ×2); row 1 WALK ×4 down/up/side; row 2 ATTACK ×6 (purple shards fly from the stone), CAST ×4 (the stone flares), HURT ×2; row 3 DEFEATED (kneeling, stone cracked) ×3 and FREED (sitting, stone gone, looking at his hands) ×3; row 4 PORTRAITS 128×128: warm (the old mentor), cold, angry, pleading, broken, freed; row 5 a BOSS CARD 300×420 (standing under one hard light in an iron frame).\n")
L.append("\n---\n")
L.append("## BATCH 9 — App icon (1 image, fill the whole image)\n")
L.append("> IMAGE \"w363_app_icon.png\": 1024×1024 (square, the only image not 1536×1024), filling the whole image, no magenta: the Dreams app icon. A night sky gradient from deep indigo to violet, a big glowing star crystal in the middle with soft light rays, a tiny farmhouse silhouette and a penguin and a cat silhouette on the horizon. Readable at 48 px. No text.\n")
open(f"{R}/docs/ART-PROMPTS-17.md", "w").write("\n".join(L))
print("prompts 17 written,", sum(1 for x in L if "IMAGE" in x), "blocks")
