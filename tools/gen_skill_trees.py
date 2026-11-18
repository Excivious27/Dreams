#!/usr/bin/env python3
"""Sun Haven-style skill trees: every skill is a grid of 4 branches (rows) x 10
tiers (columns I-X). Column c opens once 2*c points are spent in that skill.
Keeps every original node (same id, so saves and code that checks node ranks
still work) and fills the rest of the grid with nodes that raise the stats the
game already reads (GameState.bonus). Reads data/skills_base.json, writes
data/skills.json.   Run: python3 tools/gen_skill_trees.py
"""
import json, os
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
base = json.load(open(f"{R}/data/skills_base.json"))
ROMAN = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
# Per-rank amount for filler nodes, by effect key.
AMT = {"extra_crop": 0.04, "farm_energy": 0.04, "crop_value": 0.03, "extra_day": 0.04, "animal_yield": 0.06, "star_chance": 0.02,
       "double_harvest": 0.03, "seed_back": 0.05, "stone_bonus": 1, "ore_bonus": 0.05, "mine_energy": 0.04, "gem_chance": 0.02,
       "shard_bonus": 0.06, "double_hit": 0.04, "forage_bonus": 1, "wood_bonus": 1, "chop_bonus": 1, "sap_chance": 0.06,
       "rare_forage": 0.03, "bite_speed": 0.05, "rare_fish": 0.03, "escape_less": 0.06, "chest_chance": 0.02, "fish_value": 0.06,
       "double_fish": 0.04, "damage": 1, "hp": 8, "energy": 6, "block": 0.03, "crit": 0.03, "kill_energy": 2, "damage_reduction": 0.03,
       "sell_bonus": 0.03, "gift_bonus": 1, "interest": 0.003, "wood_discount": 0.04, "stone_discount": 0.04, "craft_speed": 0.05,
       "build_discount": 0.04, "spark_damage": 1, "mana": 6, "mana_regen": 1, "spell_discount": 0.04, "spell_power": 0.06,
       "pet_hp": 6, "pet_dmg": 1, "pet_speed": 0.05, "pet_def": 1,
       "pass_risk": 0.01, "heat_cool": 0.04, "wash_bonus": 0.02, "job_pay": 0.04, "gun_damage": 1, "supply_rate": 0.05, "helper_hp": 4,
       "ability_cooldown": 0.03, "colony_discount": 0.03,
       "team_damage": 1, "team_defense": 0.02, "team_heal": 2, "friend_gain": 0.05, "pet_bond": 5, "team_xp": 0.04}
DESC = {"extra_crop": "chance of an extra crop", "farm_energy": "less energy to hoe and water", "crop_value": "crop sell value",
        "extra_day": "chance a crop grows an extra day overnight", "animal_yield": "animal products", "star_chance": "chance of a star harvest",
        "double_harvest": "chance of a double harvest", "seed_back": "chance to get a seed back", "stone_bonus": "extra stone per rock",
        "ore_bonus": "extra ore", "mine_energy": "less energy to mine", "gem_chance": "gem chance", "shard_bonus": "crystal shards",
        "double_hit": "chance a swing hits twice", "forage_bonus": "extra forage", "wood_bonus": "extra wood per tree", "chop_bonus": "chop power",
        "sap_chance": "chance of sap", "rare_forage": "rare forage chance", "bite_speed": "faster bites", "rare_fish": "rare fish chance",
        "escape_less": "fewer fish escape", "chest_chance": "treasure chest chance", "fish_value": "fish sell value", "double_fish": "chance of a double catch",
        "damage": "sword damage", "hp": "max health", "energy": "max energy", "block": "chance to block", "crit": "critical hit chance",
        "kill_energy": "energy back per kill", "damage_reduction": "damage taken reduced", "sell_bonus": "sell prices", "gift_bonus": "friendship per gift",
        "interest": "daily interest on savings", "wood_discount": "less wood for building", "stone_discount": "less stone for building",
        "craft_speed": "faster crafting", "build_discount": "cheaper buildings", "spark_damage": "Spark damage", "mana": "max mana",
        "mana_regen": "mana regen", "spell_discount": "cheaper spells", "spell_power": "spell power", "pet_hp": "pup health", "pet_dmg": "pup bite damage",
        "pet_speed": "pup speed", "pet_def": "pup defence", "pass_risk": "less risk passing bills", "heat_cool": "chance heat cools an extra step overnight",
        "wash_bonus": "laundromat payout", "job_pay": "crew job pay", "gun_damage": "gun damage", "supply_rate": "battle supply",
        "helper_hp": "battle helper health", "ability_cooldown": "faster partner power", "colony_discount": "cheaper colony shops",
        "team_damage": "damage while a partner is with you", "team_defense": "less damage taken while a partner is with you",
        "team_heal": "health healed each time you use a partner power", "friend_gain": "friendship from talking and gifts",
        "pet_bond": "pup health", "team_xp": "skill XP while a partner is with you"}
# skill: [(row title, [keys], [filler names...]), x4], {original node id: row}
T = {
 "farming": ([("Crops", ["extra_crop", "double_harvest"], ["Sprout Song", "Tender Care", "Full Rows", "Heavy Stalks", "Plenty", "Overflowing Baskets", "Harvest Dance", "Bumper Crop", "Endless Fields"]),
              ("Soil & Water", ["farm_energy", "extra_day"], ["Soft Soil", "Morning Dew", "Light Hoe", "Rain Reader", "Loam Lore", "Deep Watering", "Rich Earth", "Root Song", "Living Soil"]),
              ("Animals", ["animal_yield"], ["Gentle Hands", "Warm Barn", "Fresh Straw", "Happy Herd", "Brushed Coats", "Best in Show", "Big Eggs", "Full Pails", "Barn Royalty"]),
              ("Seeds & Gold", ["crop_value", "star_chance", "seed_back"], ["Market Eye", "Seed Pouch", "Polished Produce", "Shiny Skins", "Star Sense", "Prize Picker", "Golden Glow", "Heirloom Hands", "Crown Harvest"])],
             {"green_thumb": 0, "harvest_lord": 0, "quick_hands": 1, "sprinkler_plans": 1, "greenhouse_plans": 1, "rich_soil": 1, "harvest_moon": 2, "rancher": 2, "fertilizer": 3, "golden_seeds": 3, "seed_saver": 3, "fields_of_gold": 0}),
 "mining": ([("Stone", ["stone_bonus", "mine_energy"], ["Steady Swing", "Grit", "Rubble Rouser", "Quarry Legs", "Stone Ear", "Boulder Breaker", "Tunnel Lungs", "Bedrock", "Mountain Shoulders"]),
             ("Ore", ["ore_bonus", "double_hit"], ["Copper Nose", "Vein Finder", "Ore Song", "Twin Strike", "Iron Grip", "Rich Seams", "Deep Veins", "Mother Lode", "Heart of Ore"]),
             ("Gems & Crystal", ["gem_chance", "shard_bonus"], ["Sparkle Eye", "Shard Catcher", "Gem Whisper", "Crystal Hum", "Facet Sense", "Glittering Walls", "Prism Touch", "Geode Luck", "Star Stone"]),
             ("Deep Delving", ["mine_energy", "ore_bonus"], ["Lantern Light", "Cave Sense", "Cool Head", "Ladder Luck", "Dark Eyes", "Deep Stamina", "Echo Map", "Abyss Walker", "Core Song"])],
            {"rockbreaker": 0, "iron_will": 3, "copper_eye": 1, "heavy_swing": 1, "deep_breath": 3, "gem_sense": 2, "crystal_resonance": 2, "hot_furnace": 0, "geologist": 2, "core_diver": 3, "prospector": 1, "mountain_heart": 0}),
 "foraging": ([("Forage", ["forage_bonus", "rare_forage"], ["Keen Nose", "Basket Weaver", "Berry Picker", "Mushroom Eye", "Wild Bounty", "Hidden Patches", "Forest Feast", "Rare Herbs", "Wild Heart"]),
               ("Timber", ["wood_bonus", "chop_bonus"], ["Sharp Axe", "Clean Cut", "Timber!", "Heartwood", "Log Roller", "Forest Giant", "Grain Reader", "Splitting Maul", "Ancient Oak"]),
               ("Sap & Bees", ["sap_chance"], ["Sticky Fingers", "Tap Lore", "Sweet Wood", "Honey Sense", "Amber Drops", "Busy Bees", "Golden Sap", "Hive Mind", "Queen's Favour"]),
               ("Wilds", ["rare_forage", "forage_bonus"], ["Quiet Steps", "Trail Lore", "Moss Sense", "Night Walker", "Glint Eye", "Hollow Finder", "Old Paths", "Spirit of the Wood", "Green King"])],
              {"forager": 0, "herbalist": 0, "rare_finds": 0, "lumberjack": 1, "woodcutter": 1, "sap_tapper": 2, "beekeeper": 2, "tracker": 3, "night_eyes": 3, "keeper_of_the_woods": 3, "wild_friend": 3, "old_growth": 1}),
 "fishing": ([("Patience", ["bite_speed"], ["Still Water", "Calm Breath", "Quick Bobber", "Tide Sense", "Ripple Reader", "Dawn Caster", "Lazy River", "Zen Line", "One with the Lake"]),
              ("Line & Reel", ["escape_less", "double_fish"], ["Firm Grip", "Tight Knots", "Steady Reel", "Iron Line", "Double Hook", "Fighting Spirit", "No Escape", "Twin Catch", "Unbreakable"]),
              ("Rare Catch", ["rare_fish", "fish_value"], ["Fish Tales", "Shiny Scales", "Deep Water", "Market Catch", "Rare Lure", "Prize Fish", "Legend Hunter", "Golden Fins", "King of Fish"]),
              ("Treasure", ["chest_chance"], ["Glimmer", "Sunken Sense", "Barnacle Luck", "Wreck Diver", "Pearl Eye", "Old Maps", "Pirate's Luck", "Chest Magnet", "Sea Hoard"])],
             {"patience": 0, "bait_maker": 0, "master_bait": 0, "strong_line": 1, "net_caster": 1, "swimmer": 1, "angler": 2, "lucky_lure": 2, "sea_legend": 2, "trapper": 3, "pond_plans": 3, "treasure_hunter": 3, "tide_whisperer": 2}),
 "combat": ([("Blade", ["damage", "crit"], ["Sharp Edge", "Quick Draw", "Weak Spot", "Clean Strike", "Flurry", "Keen Blade", "Finishing Blow", "Blade Dance", "Master Sword"]),
             ("Guard", ["block", "damage_reduction"], ["Brace", "Parry", "Thick Hide", "Shield Arm", "Iron Stance", "Deflect", "Unshaken", "Bulwark", "Fortress"]),
             ("Vigour", ["hp", "energy"], ["Deep Breaths", "Hearty", "Runner", "Big Lungs", "Iron Gut", "Toughness", "Second Breath", "Endless", "Giant's Heart"]),
             ("Momentum", ["kill_energy", "crit"], ["Rush", "Battle Cry", "Hunter's Eye", "Chain Fighter", "Adrenaline", "Fury", "Unstoppable", "War Song", "Hero's Will"])],
            {"fighter": 0, "critical_eye": 0, "champion": 0, "defender": 1, "iron_skin": 1, "acrobat": 1, "tough": 2, "stamina": 2, "warrior": 2, "second_wind": 3, "berserker": 3, "whirlwind": 3, "legend": 0}),
 "bartering": ([("Selling", ["sell_bonus"], ["Fair Price", "Good Pitch", "Bulk Deal", "Display Skill", "Sharp Ledger", "Hot Market", "Premium Goods", "Top Dollar", "Market King"]),
                ("Buying", ["sell_bonus", "interest"], ["Thrifty", "Coupon Clipper", "Haggler's Grin", "Wholesale", "Back Room Prices", "Insider", "Bargain Sense", "Favourite Customer", "Owns the Shop"]),
                ("Friends", ["gift_bonus"], ["Warm Smile", "Remember Names", "Thoughtful Gifts", "Good Listener", "Town Favourite", "Best Neighbour", "Party Guest", "Heart of Town", "Beloved"]),
                ("Savings", ["interest", "sell_bonus"], ["Piggy Bank", "Rainy Day Fund", "Coin Counter", "Compound", "Nest Egg", "Investor", "Vault Key", "Fortune", "Crystal Hoard"])],
               {"trader": 0, "appraiser": 0, "monopolist": 0, "haggler": 1, "tycoon": 1, "stall_plans": 1, "smooth_talker": 2, "festival_favorite": 2, "patron": 2, "networker": 3, "crystal_baron": 3, "magnate": 3}),
 "building": ([("Timber Work", ["wood_discount"], ["Straight Cuts", "Measure Twice", "Joinery", "Beam Lore", "Saw Song", "Roof Raiser", "Timber Frame", "Master Joiner", "Great Hall"]),
               ("Stone Work", ["stone_discount"], ["Mortar Mix", "Level Eye", "Brick Layer", "Arch Lore", "Cut Stone", "Foundations", "Tower Builder", "Mason's Mark", "Cathedral"]),
               ("Workshop", ["craft_speed"], ["Tidy Bench", "Sharp Tools", "Quick Hands", "Jig Maker", "Assembly Line", "Fine Work", "Clockwork", "Masterwork Mind", "Grand Workshop"]),
               ("Grand Plans", ["build_discount", "craft_speed"], ["Blueprints", "Permit Pal", "Site Boss", "Crew Chief", "Efficient Plans", "Big Thinker", "Skyline", "Visionary", "City Founder"])],
              {"carpenter": 0, "engineer": 0, "bridgewright": 0, "mason": 1, "architect": 1, "grand_architect": 1, "tinkerer": 2, "decorator": 2, "homemaker": 2, "foreman": 3, "master_builder": 3, "city_planner": 3}),
 "magic": ([("Light", ["spark_damage", "spell_power"], ["Kindle", "Bright Spark", "Sun Thread", "Flare", "Halo", "Daybreak", "Lantern Soul", "Solar Crown", "Dawnbringer"]),
            ("Dream", ["spell_discount", "mana_regen"], ["Drowse", "Soft Focus", "Lucid", "Night Thread", "Starlit", "Moon Tide", "Sleepwalker", "Dream Weave", "Dreamer's Crown"]),
            ("Crystal", ["mana", "spell_discount"], ["Facet", "Clear Mind", "Prism Thread", "Hard Light", "Resonant", "Crystal Lattice", "Gem Heart", "Prism Crown", "Living Crystal"]),
            ("The Gift", ["mana", "mana_regen"], ["Spark of Self", "Well Spring", "Inner Hum", "Deep Current", "Overflow", "Old Song", "Star Blood", "Wakeful", "The Whole Gift"])],
           None),
 "pup": ([("Body", ["pet_hp", "pet_def"], ["Good Boy", "Thick Paws", "Healthy Coat", "Big Heart", "Sturdy", "Shaggy Armour", "Old Soldier", "Iron Pup", "Unbreakable Bond"]),
          ("Bite", ["pet_dmg"], ["Little Teeth", "Grip", "Snap", "Lunge", "Shake", "Pounce", "Fangs", "Alpha Bite", "Wolf Jaws"]),
          ("Paws", ["pet_speed"], ["Zoomies", "Fast Feet", "Leap", "Sprint", "Sharp Turns", "Long Stride", "Whirlwind Pup", "Blur", "Lightning Paws"]),
          ("Nose & Pack", ["pet_hp", "pet_speed"], ["Sniffer", "Good Nose", "Treat Finder", "Loyal", "Pack Sense", "Trail Hound", "Faithful", "Heart Hound", "Forever Friend"])],
         {"tough_pup": 0, "thick_coat": 0, "best_friend": 0, "bite": 1, "hunter": 1, "rescue": 1, "quick_paws": 2, "howl": 2, "guard_dog": 2, "sniff": 3, "fetch": 3, "pack_1": 3, "truffle_nose": 3, "pack_2": 3, "tracker": 3, "pack_3": 3, "dream_hound": 2}),
}
# The arcs' own trees (only shown in their arc).
T["hustle"] = ([("Street", ["pass_risk", "heat_cool"], ["Blend In", "Smooth Hands", "Know the Beat", "Quiet Money", "Low Profile", "Cold Trail", "Ghost of the Avenue", "Clean Record", "Nobody Saw Nothing"]),
                ("Money", ["wash_bonus", "job_pay"], ["Small Change", "Spin Cycle", "Payroll", "Clean Sheets", "Fat Envelope", "Good Books", "Front Business", "Silent Partner", "Empire Ledger"]),
                ("Muscle", ["gun_damage", "hp"], ["Steady Aim", "Thick Skin", "Quick Reload", "Street Tough", "Dead Eye", "Brawler", "Iron Nerves", "Sharpshooter", "The Heavy"]),
                ("Operations", ["supply_rate", "helper_hp", "energy"], ["Radio Check", "Drone Tune-Up", "Night Shift", "Supply Run", "Armoured Drones", "Logistics", "Field Command", "War Room", "Kingpin's Reach"])], {})
T["harmony"] = ([("Bond", ["ability_cooldown", "hp"], ["Paw in Hand", "Trust", "Side by Side", "Warm Feathers", "Kindred", "Shared Breath", "Heart Link", "Unbreakable Friends", "Family"]),
                 ("Song", ["mana", "energy"], ["Hum", "First Verse", "Meow Chorus", "Steady Song", "Tidal Melody", "Waterfall Hymn", "Choir of Stars", "Pow Wow Heart", "The Real One"]),
                 ("Islands", ["colony_discount", "mana"], ["Ferry Friend", "Shell Trader", "Tide Reader", "Reef Guest", "Kelp Weaver", "Ice Friend", "Ember Glass", "Colony Hero", "Star of the Sea"]),
                 ("Wardens", ["helper_hp", "supply_rate"], ["Crystal Nursery", "Bright Spires", "Shining Shields", "Spire Keeper", "Hardened Light", "Warden's Oath", "Prism Wall", "Guardian Choir", "Dawn Ward"])], {})
T["leadership"] = ([("Command", ["team_damage", "ability_cooldown"], ["Lead by Example", "Clear Orders", "On My Mark", "Pincer", "Rally Cry", "Coordinated Strike", "Battle Plan", "Vanguard", "General"]),
                    ("Care", ["team_heal", "team_defense"], ["Look Out", "Patch Up", "Cover Me", "Watch Your Back", "Steady Hands", "Shield Wall", "No One Left Behind", "Guardian", "Heart of the Team"]),
                    ("Bonds", ["friend_gain", "pet_bond"], ["Good Word", "Remember Birthdays", "Pup's Best Friend", "Open Door", "Loyal Hearts", "Inner Circle", "Kindred Spirits", "Unshakable Trust", "Family First"]),
                    ("Strategy", ["helper_hp", "supply_rate", "job_pay", "team_xp"], ["Delegate", "Supply Lines", "Right Job, Right Person", "Teach the Team", "Field Promotions", "Logistics", "Chain of Command", "Grand Strategy", "Legend of the Crew"])], {})
EXTRA = {"leadership": ("Leadership", "Working with your team: partners, the pup, your crew or companions, battle helpers and friends. Levels up whenever you work together."),
         "hustle": ("Hustle", "The street: passing bills, washing money, your crew, your guns and your drones. Gangster arc only."),
         "harmony": ("Harmony", "The bonds of the penguin arc: your partners, the song, the merkitty islands and the crystal wardens. Penguin arc only.")}
for k, (nm, ds) in EXTRA.items():
    base["skills"].setdefault(k, {"name": nm, "desc": ds, "nodes": []})
MAGIC_ROW = {"light": 0, "dream": 1, "crystal": 2, "core": 3}


def fmt(k, v):
    if isinstance(v, float) and v < 1:
        return "+%d%% %s" % (round(v * 100), DESC[k])
    return "+%s %s" % (v, DESC[k])


out = {"_format": "Sun Haven-style grids (tools/gen_skill_trees.py): 4 branches x 10 tiers. Column c opens after 2*c points spent in the skill. 1 point per level.",
       "tier_points": 2, "skills": {}}
total = 0
for sk, sd in base["skills"].items():
    rows, rowmap = T[sk]
    grid = [[None] * 10 for _ in range(4)]
    for n in sd["nodes"]:
        r = MAGIC_ROW[n.get("branch", "core")] if sk == "magic" else rowmap[n["id"]]
        c = min(9, 2 * int(n["tier"]))
        while c < 10 and grid[r][c] is not None:
            c += 1
        if c >= 10:  # row full at the end: walk back
            c = 9
            while grid[r][c] is not None:
                c -= 1
        m = dict(n)
        m.pop("requires", None)
        m["tier"] = c
        m["row"] = r
        grid[r][c] = m
    nodes = []
    for r in range(4):
        title, keys, names = rows[r]
        ni = 0
        for c in range(10):
            if grid[r][c] is None:
                k = keys[(c + r) % len(keys)]
                ranks = 3 if c < 6 else (2 if c < 9 else 1)
                a = AMT[k] * (2 if c == 9 else 1)
                a = round(a, 3) if isinstance(a, float) else a
                nm = names[ni % len(names)]
                ni += 1
                grid[r][c] = {"id": f"{sk}_{r}_{c}", "name": nm, "desc": fmt(k, a) + (" (per rank)" if ranks > 1 else ""),
                              "ranks": ranks, "tier": c, "row": r, "effect": {k: a}}
            nodes.append(grid[r][c])
    total += len(nodes)
    out["skills"][sk] = {"name": sd["name"], "desc": sd["desc"], "branches": {str(i): rows[i][0] for i in range(4)}, "nodes": nodes}
    if sk in ("hustle", "harmony"):
        out["skills"][sk]["arc"] = "gangsters" if sk == "hustle" else "penguins"
    if sk == "magic":
        out["skills"][sk]["branch_keys"] = sd.get("branches", {})
json.dump(out, open(f"{R}/data/skills.json", "w"), indent=1, ensure_ascii=False)
print("nodes:", total)
