#!/usr/bin/env python3
"""Collections (CONDUCT 8 P3): the one catalog for the museum, the logs, milestones and the museum room.

Edit this file, never data/collections.json. Writes:
  data/collections.json  wings (museum, in case order), logs (shipping/fish/cooking/crafting/forage),
                         cats (Book pages, data-driven: id, title, kind donate|count|seen|make, badge),
                         milestones, letters, room_names, legends (fish that bypass the value ceiling)
  data/interiors.json    rooms["museum"] (hand-laid, no_furnish) + the library's east-wing doorway (idempotent)
  data/items.json        curators_loupe (top museum prize, value 0 so it can't be sold for a loop)
  data/quests.json       two starter townsfolk quests (Pip, Finn) gated on museum counts
Every entry carries "arc" ("" = both) so each arc's totals can be finished (same rule as Secrets).
check_ids() fails the run on unknown ids, missing icons, or an entry with no source in the game.
"""
import json, os, re, sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
D = os.path.join(ROOT, "data")


def load(n):
    return json.load(open(os.path.join(D, n)))


def save(n, obj):
    path = os.path.join(D, n)
    nl = os.path.exists(path) and open(path, "rb").read()[-1:] == b"\n"
    with open(path, "w") as f:
        json.dump(obj, f, indent=1, ensure_ascii=False)
        if nl:
            f.write("\n")


# ---------------------------------------------------------------- museum wings
WINGS = [
    {"id": "minerals", "title": "Stones & Ores", "case": "museum_case",
     "items": ["coal", "copper", "iron", "tin", "silver", "gold", "bog_iron", "shard", "dark", "moon_shard",
               "sunstone", "frost", "storm_glass", "platinum", "ruby", "sapphire", "emerald", "amethyst"]},
    {"id": "curios", "title": "Nature Curios", "case": "museum_case",
     "items": ["luna_moth", "sun_scarab", "seashell", "eagle_feather", "otter_whisker", "goat_horn"]},
    {"id": "artifacts", "title": "Artifacts", "case": "museum_pedestal",
     "items": ["book", "old_coin", "fossil", "pearl", "map_scrap", "rune_tablet", "relic_orb", "relic_mask",
               "relic_blade", "relic_crown", "river_pearl", "ancient_urn", "storm_eye", "lucky_coin", "pearl_necklace"]},
    {"id": "fish", "title": "Fish", "case": "museum_tank",
     "items": ["minnow", "trout", "sunfish", "carp", "bass", "catfish", "salmon", "eel", "puffer", "goldfish",
               "starfin", "mooncarp", "tuna", "crab", "legendary_koi", "ghost_fish", "sun_trout", "ice_pike", "sky_fish", "ember_koi"]},
]

# Hand hints where a scan can't say it well (shown for missing entries).
WHERE = {
    "legendary_koi": "The lake, at dawn in rain or winter, from year 3. Fishing 30+. Only one exists.",
    "tuna": "A gift from the Sanctuary pool, or a lucky weekly perk.",
    "tuna@gangsters": "The docks charters and the cold colonies.",  # C16a P4 (c16a_14-08): no penguin places in the gang arc
    "crab": "The beach shallows (forage).",
    "ancient_urn": "Buried caches (dig with the hoe where the ground looks turned).",
    "eagle_feather": "Mountain forage, now and then.",
    "goat_horn": "Mountain forage, rarely.",
    "otter_whisker": "Dropped by otters by the water.",
    "book": "Old chests and the library's lost-and-found.",
}

# C15 P4 seasonal fish (gen_mega_new SEASON_FISH): in the fish log (the museum tanks keep their 20 slots).
SEASON_FISH_LOG = ["perch", "smelt", "herring", "flounder", "bream", "chub", "flying_fish", "snapper",
                   "pike", "grayling", "mullet", "mackerel", "sturgeon", "cod", "sardine", "lantern_fish",
                   "prism_trout", "sailfish", "soul_salmon", "frost_pike"]

# Fish the rod can catch (the fish log); tuna and crab come other ways (museum only).
NOT_ROD = ["tuna", "crab"]

# Legends: replace a normal catch once per run when the place and moment fit (bypass the value ceiling).
LEGENDS = {
    # C16a P4 (c16a_05-04): one rule set (Fishing.T koi removed); legends spread over years 1-3 by level + year.
    "legendary_koi": {"scene": "lake", "lvl": 30, "when": "rain_or_winter_dawn", "chance": 0.008, "year": 3, "first_decor": "dc_koi_scroll"},
    # C15 P4 (c15_09-14): a legend per season (gen_mega_new SEASON_LEGENDS); "year" = first year it can bite
    "prism_trout": {"scene": "forest", "lvl": 14, "when": "season:spring", "chance": 0.012},
    "sailfish": {"scene": "beach", "lvl": 18, "when": "season:summer", "chance": 0.012},
    "soul_salmon": {"scene": "lake", "lvl": 22, "when": "season:fall", "chance": 0.01, "year": 2},
    "frost_pike": {"scene": "forest", "lvl": 26, "when": "season:winter", "chance": 0.01, "year": 2},
}

# C16a P4 (c16a_08-12): Bug net + Critter log. All ages, no animal is harmed: a critter is caught, logged
# and let go (never an item in the bag, never sold, never an ingredient). "kind" = the WorldGen wildlife kind
# the net catches; "net" = net tier needed (0 Twig, 1 Silk, 2 Star); "lvl" = Foraging; "time" day|night|"";
# "spook" 0-1 (higher slips away more, worse while it flees). Legends: no wildlife kind, they turn up on a
# swing at the right season/weather/hour window (Critters.legend_roll).
NETS = {
    "bug_net": {"name": "Twig Net", "name_gang": "Wire Net", "tier": 0, "lvl": 0, "value": 230,
                "desc": "Swing at a bug or a little critter close by to log it in the Book. It's let go right after."},
    "silk_net": {"name": "Silk Net", "name_gang": "Mesh Net", "tier": 1, "lvl": 15, "value": 1000,
                 "desc": "Reaches two steps. Catches the shy ones the Twig Net misses. Foraging 15."},
    "star_net": {"name": "Star Net", "name_gang": "Neon Net", "tier": 2, "lvl": 35, "value": 3300,
                 "desc": "Three steps, never spooks. Catches night bugs and the once-a-season legends. Foraging 35."},
}
CRITTERS = [
    {"id": "cr_ladybug", "kind": "ladybug", "name": "Ladybug", "seasons": ["spring", "summer"], "time": "day", "net": 0, "lvl": 0, "spook": 0.1},
    {"id": "cr_lemon_wing", "kind": "butterfly_yellow", "name": "Lemon Wing", "name_gang": "Taxi Wing", "seasons": ["spring"], "time": "day", "net": 0, "lvl": 0, "spook": 0.3},
    {"id": "cr_orange_flutter", "kind": "butterfly_orange", "name": "Orange Flutter", "seasons": ["spring", "summer", "fall"], "time": "day", "net": 0, "lvl": 0, "spook": 0.3},
    {"id": "cr_sky_wing", "kind": "butterfly_blue", "name": "Sky Wing", "name_gang": "Neon Wing", "seasons": ["spring", "summer"], "time": "day", "net": 0, "lvl": 2, "spook": 0.35},
    {"id": "cr_bumble_bee", "kind": "bee", "name": "Bumble Bee", "seasons": ["spring", "summer"], "time": "day", "net": 0, "lvl": 3, "spook": 0.3},
    {"id": "cr_meadow_hopper", "kind": "grasshopper", "name": "Meadow Hopper", "name_gang": "Alley Cricket", "seasons": ["summer", "fall"], "time": "day", "net": 0, "lvl": 0, "spook": 0.25},
    {"id": "cr_garden_snail", "kind": "snail", "name": "Garden Snail", "seasons": ["spring", "summer", "fall"], "time": "", "net": 0, "lvl": 0, "spook": 0.0},
    {"id": "cr_violet_duchess", "kind": "butterfly_purple", "name": "Violet Duchess", "seasons": ["summer"], "time": "day", "net": 1, "lvl": 8, "spook": 0.45},
    {"id": "cr_pond_dragonfly", "kind": "dragonfly", "name": "Pond Dragonfly", "seasons": ["summer"], "time": "day", "net": 1, "lvl": 10, "spook": 0.5},
    {"id": "cr_green_frog", "kind": "frog", "name": "Green Frog", "seasons": ["spring", "summer"], "time": "", "net": 1, "lvl": 6, "spook": 0.35},
    {"id": "cr_shore_crab", "kind": "crab", "name": "Shore Crab", "name_gang": "Dock Crab", "seasons": [], "time": "", "net": 1, "lvl": 12, "spook": 0.3},
    {"id": "cr_firefly", "kind": "firefly", "name": "Firefly", "seasons": ["spring", "summer", "fall"], "time": "night", "net": 2, "lvl": 20, "spook": 0.2},
    {"id": "cr_sky_jelly", "kind": "jelly", "name": "Sky Jelly", "seasons": [], "time": "", "net": 2, "lvl": 30, "spook": 0.4, "arc": "penguins"},
    # Legends (one per season, Foraging 40, Star Net): logged once, a museum star.
    {"id": "cr_petal_emperor", "kind": "", "name": "Petal Emperor", "seasons": ["spring"], "time": "", "net": 2, "lvl": 40,
     "legend": {"weather": ["rain"], "hours": [6, 10], "chance": 0.04}},
    {"id": "cr_sunwing", "kind": "", "name": "Sunwing", "seasons": ["summer"], "time": "", "net": 2, "lvl": 40,
     "legend": {"weather": ["clear", "sun", ""], "hours": [11, 14], "chance": 0.04}},
    {"id": "cr_ember_moth", "kind": "", "name": "Ember Moth", "seasons": ["fall"], "time": "", "net": 2, "lvl": 40,
     "legend": {"weather": ["fog", "leaves", "rain"], "hours": [17, 21], "chance": 0.04}},
    {"id": "cr_snow_sylph", "kind": "", "name": "Snow Sylph", "seasons": ["winter"], "time": "", "net": 2, "lvl": 40,
     "legend": {"weather": ["snow", "blizzard"], "hours": [6, 18], "chance": 0.04}},
]
CRITTER_WHERE = {"day": "Out by day", "night": "Out at night", "": "Out any time"}
LIVE_WING = {"id": "critters", "title": "Live Exhibit"}


def critter_where(c):
    if "legend" in c:
        L = c["legend"]
        return "Legend: %s, %d-%d o'clock, %s weather. Star Net, Foraging %d." % (
            c["seasons"][0].capitalize(), L["hours"][0], L["hours"][1], "/".join(w for w in L["weather"] if w) or "clear", c["lvl"])
    se = ", ".join(x.capitalize() for x in c["seasons"]) or "All year"
    net = ["Twig Net", "Silk Net", "Star Net"][c["net"]]
    return "%s; %s. %s%s." % (se, CRITTER_WHERE[c["time"]].lower(), net, (", Foraging %d" % c["lvl"]) if c["lvl"] else "")


def critter_items(items):
    for nid, n in NETS.items():
        items[nid] = {"name": n["name"], "name_gang": n["name_gang"], "type": "tool", "value": n["value"], "rarity": "uncommon",
                      "tier": 1 + n["tier"], "desc": n["desc"], "icon": "c16ap4_" + nid}
    for c in CRITTERS:
        items[c["id"]] = {"name": c["name"], "type": "critter", "value": 0, "rarity": "legendary" if "legend" in c else "common",
                          "tier": 1, "desc": "Logged in the Book and let go. " + critter_where(c), "icon": "c16ap4_" + c["id"][3:],
                          "no_sell": True}
        if c.get("arc"):
            items[c["id"]]["arc"] = c["arc"]

SHIP_TYPES = ["crop", "fruit", "flower", "herb", "forage", "fish", "ore", "gem", "bar", "treasure"]
SHIP_FAMILY = {"crop": "Crops", "fruit": "Fruit", "flower": "Flowers", "herb": "Herbs", "forage": "Forage",
               "fish": "Fish", "ore": "Minerals", "gem": "Minerals", "bar": "Minerals", "treasure": "Treasure"}
COOK_STATIONS = ["kitchen", "campfire", "soda"]

# Book pages (C19 adds "cards" here: one entry + one record_* call, no UI change).
CATS = [
    {"id": "museum", "title": "Museum", "kind": "donate", "badge": "medal_collector"},
    {"id": "shipping", "title": "Shipping log", "kind": "count", "badge": "medal_green_thumb"},
    {"id": "fish", "title": "Fish log", "kind": "count", "badge": "medal_master"},
    {"id": "cooking", "title": "Cookbook", "kind": "make", "badge": "medal_master"},
    {"id": "crafting", "title": "Crafting log", "kind": "make", "badge": "medal_craftsman"},
    {"id": "forage", "title": "Forage log", "kind": "seen", "badge": "medal_explorer"},
    {"id": "ranch", "title": "Ranch log", "kind": "count", "badge": "medal_green_thumb"},
    {"id": "critters", "title": "Critter log", "kind": "seen", "badge": "medal_explorer"},  # C16a P4 bug net
]

# Animal goods (C11a P3). Raw goods fill the Ranch log (Collections.record_ranch when collected) and ship as
# "Animal goods"; made goods ship as "Artisan goods". data/ranch.json "products" (gen_ranch.py) adds the rest.
ANIMAL_RAW = ["egg", "duck_egg", "milk", "goat_milk", "sheep_wool", "honey", "honeycomb", "truffle"]
ARTISAN = ["cheese", "butter", "goat_cheese", "mayonnaise", "duck_mayonnaise", "cream", "yogurt", "honey_jar", "beeswax",
           "beeswax_candle", "yarn", "truffle_oil"]
ANIMAL_WHERE = {"egg": "Your coop hens, every morning you care for them.", "duck_egg": "Ducks in the Big Coop.",
                "milk": "Cows in your barn.", "goat_milk": "Goats in the Big Barn.", "sheep_wool": "Sheep and llamas in your barn.",
                "honey": "Your beehives on the farm; sometimes found in the Meadow.", "honeycomb": "Your beehives, now and then.",
                "truffle": "Happy pigs dig them up outdoors; old forests too."}

# ---------------------------------------------------------------- milestones
# need: int count in cat, "wing:<id>" (every item of that wing), or "all".
# give: {"money": n} and/or {"item": id, "n": n} and/or {"decor": id}. Money <= 5000 each (checked).
MILESTONES = [
    {"id": "mus_5", "cat": "museum", "need": 5, "from": "theo", "give": {"money": 300, "item": "bait", "n": 3},
     "text": "Five pieces in the cases already! Here's a little thank-you, and some bait: fish make fine exhibits. - Theo",
     "text_gangsters": "Five pieces on the shelves. People are already asking where we got them. A little something for you, and bait: fish count too. - Theo"},
    {"id": "mus_10", "cat": "museum", "need": 10, "from": "theo", "give": {"item": "luminous_starfruit_seed", "n": 1},
     "text": "Ten exhibits! A seed someone left with an old atlas. Nobody knows what it grows. I'd love to. - Theo",
     "text_gangsters": "Ten pieces in the Curio Room. Found this seed tucked in an old ledger. Grow it and tell me what it is. - Theo"},
    {"id": "mus_20", "cat": "museum", "need": 20, "from": "theo", "give": {"money": 1000},
     "text": "Twenty! School trips have started asking. Consider this your curator's pay. - Theo",
     "text_gangsters": "Twenty pieces. Folks pay to look now, so you get a cut. Fair's fair. - Theo"},
    {"id": "mus_30", "cat": "museum", "need": 30, "from": "theo", "give": {"decor": "museum_trophy"},
     "text": "Thirty exhibits. The town had a little trophy made for you. It's on your mantel now. - Theo",
     "text_gangsters": "Thirty pieces. The neighbourhood chipped in for a trophy. It's on your shelf at home. - Theo"},
    {"id": "wing_minerals", "cat": "museum", "need": "wing:minerals", "from": "theo", "give": {"money": 1500, "decor": "mineral_display"},
     "text": "Every stone and ore in the valley, in one wing! A little display for your home, too. - Theo",
     "text_gangsters": "Every stone and ore, all in one room. Made you a display shelf for home. - Theo"},
    {"id": "wing_curios", "cat": "museum", "need": "wing:curios", "from": "theo", "give": {"money": 1500, "decor": "curio_jar"},
     "text": "The Nature Curios wing is full. I made you a jar of your own. - Theo",
     "text_gangsters": "The curio shelf is full. Here's a jar of your own for the house. - Theo"},
    {"id": "wing_artifacts", "cat": "museum", "need": "wing:artifacts", "from": "theo", "give": {"money": 1500, "decor": "relic_shelf"},
     "text": "Every artifact found! The valley's whole story, on pedestals. A relic shelf for your home. - Theo",
     "text_gangsters": "Every old piece accounted for, clean provenance and all. A relic shelf for your place. - Theo"},
    {"id": "wing_fish", "cat": "museum", "need": "wing:fish", "from": "finn", "give": {"money": 1500, "decor": "fish_trophy"},
     "text": "Every fish in the tanks. Even the koi! Mounted one for your wall, a pretend one. - Finn",
     "text_gangsters": "Every fish in the tanks. I had a wooden one carved for your wall. - Finn"},
    {"id": "mus_all", "cat": "museum", "need": "all", "from": "theo", "give": {"decor": "dc_founders_orrery", "money": 5000, "item": "curators_loupe", "n": 1},
     "text": "The museum is complete. I didn't think I'd live to write that. Please take my old loupe: it always finds the lucky things. - Theo",
     "text_gangsters": "The Curio Room is complete. Take my old loupe. It has a habit of spotting the good stuff. - Theo"},
    {"id": "ship_25", "cat": "shipping", "need": 25, "from": "maple", "give": {"money": 500},
     "text": "Twenty-five different things through your sell box! The whole town eats better for it. - Maple",
     "text_gangsters": "Twenty-five different goods through your box. Business likes variety. - Maple"},
    {"id": "ship_75", "cat": "shipping", "need": 75, "from": "maple", "give": {"money": 1500, "decor": "shipper_ribbon"},
     "text": "Seventy-five kinds shipped. Here's a ribbon. The fair judges don't give these out for nothing. - Maple",
     "text_gangsters": "Seventy-five kinds of goods. Here's a ribbon for the wall: best supplier on the block. - Maple"},
    {"id": "ship_150", "cat": "shipping", "need": 150, "from": "maple", "give": {"decor": "dc_golden_crate", "money": 4000},
     "text": "A hundred and fifty kinds! I've run out of shelf labels. - Maple",
     "text_gangsters": "A hundred and fifty kinds. I ran out of price tags. - Maple"},
    {"id": "fish_10", "cat": "fish", "need": 10, "from": "finn", "give": {"item": "bait", "n": 20},
     "text": "Ten kinds of fish caught! Bait's on me. - Finn",
     "text_gangsters": "Ten kinds of fish. Bait's on me. - Finn"},
    {"id": "fish_all", "cat": "fish", "need": "all", "from": "finn", "give": {"decor": "dc_golden_rod_mount", "money": 3000},
     "text": "Every fish the rod can find. You're the best angler this lake has seen. - Finn",
     "text_gangsters": "Every fish a rod can find. Best angler on the waterfront. - Finn"},
    {"id": "cook_10", "cat": "cooking", "need": 10, "from": "posy", "give": {"money": 600},
     "text": "Ten dishes cooked! You've got the touch. - Posy",
     "text_gangsters": "Ten dishes. You cook like you mean it. - Posy",
     "from_alt": "bram", "text_alt": "Ten dishes cooked! Posy would be proud. I am, anyway. - Bram",
     "text_alt_gangsters": "Ten dishes. Posy would've hired you. I'm thinking about it. - Bram"},
    {"id": "cook_all", "cat": "cooking", "need": "all", "from": "posy", "give": {"decor": "dc_master_hearth", "money": 3000},
     "text": "You've cooked every recipe there is. Teach me something now! - Posy",
     "text_gangsters": "Every recipe in the book. Your turn to teach me. - Posy",
     "from_alt": "bram", "text_alt": "Every recipe there is, cooked. My kitchen's yours whenever you want it. - Bram",
     "text_alt_gangsters": "Every recipe in the book. The inn kitchen's yours any night you want it. - Bram"},
    {"id": "ranch_3", "cat": "ranch", "need": 3, "from": "benno", "give": {"money": 400, "item": "hay", "n": 40},
     "text": "Three kinds of animal goods from your own ranch! Here's hay for the herd, on the house. - Benno",
     "text_gangsters": "Three kinds of goods off your own ranch. Nobody looks twice at a real farm. Hay's on me. - Benno"},
    # C11b P6 (c11b_10-10): fair ribbons. need "flag:<counter>:<n>" reads run.flags (AnimalShow.record).
    {"id": "ribbon_1", "cat": "ranch", "need": "flag:show_blue:1", "from": "benno", "give": {"money": 300, "decor": "dc_tt_medal_bronze"},
     "text": "Your first blue ribbon! The fair sent a little medal for your wall. - Benno",
     "text_gangsters": "First blue ribbon. The fair sent a medal. Hang it somewhere people see. - Benno"},
    {"id": "ribbon_3", "cat": "ranch", "need": "flag:show_blue:3", "from": "benno", "give": {"money": 800, "decor": "dc_tt_medal_silver"},
     "text": "Three blue ribbons. Folks are starting to ask your secret. - Benno",
     "text_gangsters": "Three blues. The other ranchers are asking questions. Say nothing. - Benno"},
    {"id": "ribbon_8", "cat": "ranch", "need": "flag:show_blue:8", "from": "benno", "give": {"money": 2000, "decor": "dc_tt_trophy_crystal"},
     "text": "Eight blue ribbons! The fair had a crystal trophy made with your name on it. - Benno",
     "text_gangsters": "Eight blues. They had a trophy made with your name on it. Champion of the pens. - Benno"},
    {"id": "ranch_all", "cat": "ranch", "need": "all", "from": "benno", "give": {"money": 2500, "decor": "dc_tt_trophy_farm_a"},
     "text": "Every good a ranch can give, from your own animals. The fair made you a trophy. - Benno",
     "text_gangsters": "Every good a ranch can give, all yours. The block chipped in for a trophy. - Benno"},
    {"id": "craft_25", "cat": "crafting", "need": 25, "from": "hazel", "give": {"item": "chest", "n": 1},
     "text": "Twenty-five things built! Have a spare chest for all of it. - Hazel",
     "text_gangsters": "Twenty-five builds. Here's a spare chest. - Hazel"},
    {"id": "craft_100", "cat": "crafting", "need": 100, "from": "hazel", "give": {"money": 2500},
     "text": "A hundred different builds. You're putting my crew to shame. - Hazel",
     "text_gangsters": "A hundred builds. My crew's getting nervous. - Hazel"},
    {"id": "forage_20", "cat": "forage", "need": 20, "from": "hazel", "give": {"money": 400},
     "text": "Twenty wild things found. The valley shares with those who look. - Hazel",
     "text_gangsters": "Twenty wild finds. The city's got more green in it than people think. - Hazel"},
    # C16a P4: Critter log ladder (Hazel hosts; all caught, logged and let go).
    {"id": "crit_5", "cat": "critters", "need": 5, "from": "hazel", "give": {"money": 300, "decor": "dc_y_firefly_jar"},
     "text": "Five little critters logged and let go! Here's an empty jar for the porch - lights only, no bugs inside. - Hazel",
     "text_gangsters": "Five critters logged and let go. Here's a jar lamp for your step - just a light, nothing in it. - Hazel"},
    {"id": "crit_10", "cat": "critters", "need": 10, "from": "hazel", "give": {"money": 1200},
     "text": "Ten critters in your log. You walk soft now; the meadow noticed. - Hazel",
     "text_gangsters": "Ten critters logged. You move quiet these days. Here's a little something. - Hazel"},
    {"id": "crit_all", "cat": "critters", "need": "all", "from": "hazel", "give": {"money": 3000},
     "text": "Every critter, even the four legends. I've never seen a log like it. - Hazel",
     "text_gangsters": "Every critter in the city, legends too. Nobody's done that. Nobody. - Hazel"},
]

# C10a P3: Decor catalogue milestones: kinds of decor ever owned (DecorCatalogue.progress). Letters
# ride the Collections post; "decor" ids are catalogue entries (gen_decor.py); a gift the catalogue
# doesn't list yet is skipped (the letter never names it). Never a Book cat (would swamp percent()).
DECOR_MILESTONES = [
    {"id": "decor_10", "need": 10, "from": "maple", "give": {"money": 300},
     "text": "Ten different pieces in your home! It's starting to feel lived in. A little something for the next one. - Maple",
     "text_gangsters": "Ten pieces in your place already. Starting to look like somebody lives there. Here's a little something. - Maple"},
    {"id": "decor_25", "need": 25, "from": "maple", "give": {"money": 800},
     "text": "Twenty-five pieces! Folks have started asking who does your decorating. - Maple",
     "text_gangsters": "Twenty-five pieces. People ask who does your decorating. I tell them it's a secret. - Maple"},
    {"id": "decor_50", "need": 50, "from": "maple", "give": {"money": 1500, "decor": "dc_collectors_shelf"},
     "text": "Fifty pieces collected. Here's a collector's shelf, to show off the little ones. - Maple",
     "text_gangsters": "Fifty pieces. A collector's shelf for your place: put the good stuff where folks can see it. - Maple"},
    {"id": "decor_100", "need": 100, "from": "maple", "give": {"money": 3000},
     "text": "A hundred pieces! You could open a showroom. - Maple",
     "text_gangsters": "A hundred pieces. You could run a showroom out of there. - Maple"},
    {"id": "decor_200", "need": 200, "from": "maple", "give": {"money": 5000, "decor": "dc_grand_catalogue_stand"},
     "text": "Two hundred pieces. I had the catalogue's own display stand sent over: you've earned it. - Maple",
     "text_gangsters": "Two hundred pieces. The catalogue's own display stand is yours now. You earned it. - Maple"},
]

LETTERS = {
    "open": "The library's east wing is a museum now. Bring me anything old, shiny or scaly: there's a donation tray by the door. - Theo",
    "open_gangsters": "The library's east wing is the Curio Room now. Bring me anything old, shiny or scaly; the tray's by the door. I keep the ledger. - Theo",
    "thanks": "I catalogued what you left in the tray: %s. The cases look better every day. - Theo",
    "thanks_gangsters": "Logged it all in the ledger: %s. Clean provenance, as always. - Theo",
    "not_open": "Theo's still dusting the east wing.",
}

ROOM_NAMES = {"penguins": "Valley Museum", "gangsters": "The Curio Room"}

QUESTS = [
    {"id": "coll_pip_fossil", "giver": "pip", "text": "Pip wants to see a fossil in the museum. Give one at the donation tray.",
     "text_gangsters": "Pip wants to see a fossil in the Curio Room. Leave one in the tray.", "when": {"flag": "museum_open"},
     "done_when": {"donated": "fossil"}, "reward": {"crystals": 200, "friend": ["pip", 20]}},
    {"id": "coll_finn_tanks", "giver": "finn", "text": "Finn wants five kinds of fish in the museum tanks.",
     "text_gangsters": "Finn wants five kinds of fish in the Curio Room tanks.", "when": {"flag": "museum_open"},
     "done_when": {"museum_wing": ["fish", 5]}, "reward": {"item": ["bait", 10], "friend": ["finn", 15]}},
]

QUEST_LINES = {
    "coll_pip_fossil": {"offer": ["Theo has a museum now! A real one, with glass cases!", "Could you put a fossil in it? I want to see one with a little card under it."],
                        "yes": "Yes! With a card!", "no": "Okay. But the cases look so empty...",
                        "wait": "A fossil, in the museum tray! Theo does the card.",
                        "done": ["I saw it! It has a card and everything!", "I read the card four times. Here, I saved this for you."]},
    "coll_finn_tanks": {"offer": ["Theo's got tanks in that museum, and nothing swimming in them.", "Five kinds of fish in there and I'll stock you up on bait."],
                        "yes": "Good. Fish deserve an audience.", "no": "Suit yourself. They're patient.",
                        "wait": "Five kinds in the tanks. Any five.",
                        "done": ["Saw the tanks. Looks like a proper aquarium now.", "Bait, as promised."]},
}
QUEST_LINES_GANG = {
    "coll_pip_fossil@gangsters": {"offer": ["Theo turned the east wing into a Curio Room! With glass cases!", "Could you put a fossil in there? I want to see it with a little card."]},
    "coll_finn_tanks@gangsters": {"offer": ["Theo's got tanks in that Curio Room and nothing swimming in them.", "Five kinds of fish in there and I'll stock you up on bait."]},
}

# Curator's Loupe: +2 luck charm (luck flows through GameState.gear_stat into drop rolls).
LOUPE = {"name": "Curator's Loupe", "type": "equip", "value": 0, "tier": 3, "rarity": "legendary", "slot": "charm",
         "stats": {"luck": 2}, "desc": "Theo's old loupe. It always finds the lucky things."}


# ---------------------------------------------------------------- museum room
COLS, ROWS = 18, 15
DISPLAY_ROWS = [3, 5, 7, 9, 11]
SLOT_X = [1, 2, 3, 4, 5, 6, 11, 12, 13, 14, 15, 16]   # aisle x 7..10


def slots():
    """Case cells per wing: minerals row 3 + row 5 left, curios row 5 right, artifacts row 7 + row 11 right,
    fish row 9 + row 11 (two-wide tanks on pair-aligned cells)."""
    s = {"minerals": [(x, 3) for x in SLOT_X] + [(x, 5) for x in SLOT_X[:6]],
         "curios": [(x, 5) for x in SLOT_X[6:]],
         "artifacts": [(x, 7) for x in SLOT_X] + [(13, 11), (14, 11), (15, 11)],
         "fish": [(x, 9) for x in SLOT_X] + [(x, 11) for x in SLOT_X[:6]] + [(11, 11), (12, 11)]}
    for w in WINGS:
        assert len(s[w["id"]]) == len(w["items"]), (w["id"], len(s[w["id"]]))
    return s


def room():
    s = slots()
    props, things, cases = [], [], []
    for w in WINGS:
        cells = s[w["id"]]
        for i, (item, c) in enumerate(zip(w["items"], cells)):
            cases.append({"item": item, "wing": w["id"], "cell": list(c)})
            things.append({"type": "museum", "act": "case", "item": item, "cell": list(c), "hint": "A: look", "solid": True})
            if w["case"] == "museum_tank":
                if i % 2 == 0:
                    props.append({"name": "museum_tank", "cell": list(c), "w": 1})  # w = extra cells
            else:
                props.append({"name": w["case"], "cell": list(c)})
    props += [{"name": "museum_rope", "cell": [7, 3], "solid": False}, {"name": "museum_rope", "cell": [10, 3], "solid": False},
              {"name": "museum_counter", "cell": [11, 13], "w": 1},
              {"name": "plant2_b", "cell": [1, 13]}, {"name": "plant2_b", "cell": [16, 13]},
              {"name": "rug_rect_green", "cell": [8, 7], "w": 1, "solid": False}]
    things += [{"type": "museum", "act": "counter", "cell": [11, 13], "hint": "A: donation tray", "solid": True},
               {"type": "museum", "act": "counter", "cell": [12, 13], "hint": "A: donation tray", "solid": True},
               {"type": "museum", "act": "plaque", "wing": "minerals", "cell": [3, 2], "hint": "A: read the plaque", "solid": False},
               {"type": "museum", "act": "plaque", "wing": "artifacts", "cell": [14, 2], "hint": "A: read the plaque", "solid": False}]
    return {"museum": True, "no_furnish": True, "cols": COLS, "rows": ROWS, "floor": "fl_wood", "wall": "wl_plaster",
            "door": [8, ROWS - 1], "back": ["in_library", 10, 3], "door_prop": "doorway_ornate", "door_hint": "A: back to the library",
            "music": "chapel", "windows": [4, 13], "pet": False,
            "wall_props": [{"name": "museum_sign_wing", "x": 3}, {"name": "museum_sign_wing", "x": 14}],
            "props": props, "things": things, "npcs": [], "cases": cases,
            "intro": "Glass cases in neat rows, a velvet rope, a little brass bell. The Valley Museum.",
            "gangsters": {"floor": "fl_wood_dark", "intro": "Glass cases, a velvet rope, a ledger by the tray. The Curio Room."}}


def patch_library(rooms):
    lib = rooms["library"]
    lib["props"] = [p for p in lib["props"] if not (p.get("name") == "doorway_ornate" and p.get("cell") == [10, 2])]
    lib["props"].append({"name": "doorway_ornate", "cell": [10, 2], "solid": False})
    lib["things"] = [t for t in lib["things"] if t.get("type") != "museum"]
    lib["things"].append({"type": "museum", "act": "enter", "cell": [10, 2], "hint": "A: Museum (east wing)", "solid": True})


# ---------------------------------------------------------------- scans
def source_text():
    """All game text except the item catalog itself (to prove each entry can be found)."""
    out = []
    skip = {"items.json", "collections.json", "gift_lines.json", "talk.json", "npcs.json", "skills.json", "skills_old.json"}
    for d, ext in (("scripts", ".gd"), ("data", ".json")):
        for f in sorted(os.listdir(os.path.join(ROOT, d))):
            if f.endswith(ext) and f not in skip:
                out.append(open(os.path.join(ROOT, d, f), encoding="utf-8").read())
    return "\n".join(out)


_SG = None
_CROP_SE = None


def where_hint(item_id, it, forage, pools):
    """C15 P2 (c15_04-23): the book says when, too: seasonal forage places and a season tag."""
    global _SG, _CROP_SE
    if _SG is None:
        p = os.path.join(ROOT, "data", "season_goods.json")
        _SG = json.load(open(p)) if os.path.exists(p) else {}
        _CROP_SE = {}
        for c in load("crops.json").values():
            if isinstance(c, dict) and c.get("season", "any") != "any" and isinstance(c.get("season"), str):
                _CROP_SE.setdefault(c.get("yield"), c["season"])
    h = _where_hint(item_id, it, forage, pools)
    ses = list(it.get("forage_seasons") or [])
    if ses:
        places = []
        for se in ses:
            for reg, rows in _SG.get("forage", {}).get(se, {}).items():
                if any(r[0] == item_id for r in rows) and reg not in places:
                    places.append(reg)
        if h.startswith("Out in the world") or not h.startswith("Forage"):
            h = "Forage: " + ", ".join(x.replace("_", " ").title() for x in places[:2])
    elif item_id in (_CROP_SE or {}) and it.get("type") in ("crop", "fruit", "flower"):
        ses = [_CROP_SE[item_id]]
    if ses and len(ses) < 4 and not item_id in WHERE:
        h += " (" + ", ".join(x.title() for x in ses) + ")"
    return h


def _where_hint(item_id, it, forage, pools):
    if item_id in WHERE:
        return WHERE[item_id]
    if str(LEGENDS.get(item_id, {}).get("when", "")).startswith("season:"):
        L = LEGENDS[item_id]
        return "Legend: %s, in %s, fishing %d+%s. Only one exists." % (
            L["scene"].title(), L["when"][7:], L["lvl"], ", from year %d" % L["year"] if L.get("year") else "")
    if item_id in ANIMAL_WHERE:
        return ANIMAL_WHERE[item_id]
    if item_id in ARTISAN:
        return "Make it from animal goods (Pantry Press, Loom, Mayo Machine or Honey Extractor)."
    t = it.get("type", "")
    places = [k for k, tab in forage.items() if any(e[0] == item_id for e in tab)]
    if t == "fish" and it.get("seasons"):
        # C15 P4: seasonal fish carry their own seasons/water/weather/time (c15_09-03).
        se = "/".join(x.title() for x in it["seasons"])
        where = "Ponds, rivers and the lake" if it.get("water") == "fresh" else "The sea, the docks and charters"
        bits = [where, se]
        if it.get("weather"):
            bits.append("only in " + "/".join(it["weather"]))
        if it.get("when"):
            bits.append("by day" if it["when"] == "day" else "at night")
        return ", ".join(bits)
    if t == "fish":
        p = pools.get(item_id, [])
        v = int(it.get("value", 0))
        lvl = max(0, (v - 25 - 40 - 10 + 14) // 15)
        p = [x for x in p if x not in ("fishing", "region", "marina", "beach_fx")]
        s = ", ".join(x.replace("_", " ").title() for x in p[:2]) or "Somewhere in the water"
        # mirrors Fishing.T["when"] (fishing.gd): day-only fish are never hinted "at night"
        when = {"goldfish": "day", "sun_trout": "day"}.get(item_id, "night")
        return s + (", %s with bait, fishing %d+" % ("by day" if when == "day" else "at night", lvl) if v > 75 else "")
    if places:
        return "Forage: " + ", ".join(x.replace("_", " ").title() for x in places[:2])
    if t in ("ore", "gem", "material", "bar"):
        return "The mines, or rocks out in the wilds."
    if t in ("crop", "fruit", "flower"):
        return "Grow it on the farm."
    if t == "treasure":
        return "Old chests, buried caches and lucky catches."
    return "Out in the world somewhere."


def fish_pools():
    out = {}
    for f in sorted(os.listdir(os.path.join(ROOT, "scripts"))):  # stable order on every filesystem (CI)
        if not f.endswith(".gd"):
            continue
        txt = open(os.path.join(ROOT, "scripts", f), encoding="utf-8").read()
        for m in re.finditer(r"\[([^\[\]]*\"(?:minnow|trout|carp|bass|salmon|eel)\"[^\[\]]*)\]", txt):
            for fid in re.findall(r"\"([a-z_]+)\"", m.group(1)):
                out.setdefault(fid, [])
                scene = f[:-3]
                # C16a P4 (c16a_14-01): only real maps (scenes/<id>.tscn) are places, never script names
                if not os.path.exists(os.path.join(ROOT, "scenes", scene + ".tscn")):
                    continue
                if scene not in out[fid]:
                    out[fid].append(scene)
    return out


def arc_of(it):
    return str(it.get("arc", ""))


def main():
    items = load("items.json")
    recipes = load("recipes.json")
    buildings = load("buildings.json")
    forage = load("forage.json")
    src = source_text()
    pools = fish_pools()

    def sourced(i):
        return re.search(r"[\"']%s[\"']" % re.escape(i), src) is not None

    wings = []
    for w in WINGS:
        ents = [{"item": i, "arc": arc_of(items[i]), "where": where_hint(i, items[i], forage, pools)} for i in w["items"]]
        for e in ents:
            if e["item"] + "@gangsters" in WHERE:
                e["where_gangsters"] = WHERE[e["item"] + "@gangsters"]
        wings.append({"id": w["id"], "title": w["title"], "entries": ents})

    ranch_json = load("ranch.json") if os.path.exists(os.path.join(ROOT, "data", "ranch.json")) else {}
    raw = list(ANIMAL_RAW) + [k for k in (ranch_json.get("products") or {}) if k not in ANIMAL_RAW]
    raw = [i for i in raw if i in items]
    ranch_log = [{"item": i, "arc": arc_of(items[i]), "family": "Animal goods", "where": where_hint(i, items[i], forage, pools)} for i in raw]
    ship, dropped = [], []
    for i in raw + [a for a in ARTISAN if a in items]:
        ship.append({"item": i, "arc": arc_of(items[i]), "family": "Animal goods" if i in raw else "Artisan goods",
                     "where": where_hint(i, items[i], forage, pools)})
    animal = {e["item"] for e in ship}
    for i, it in items.items():
        if i in animal:
            continue
        if it.get("type") in SHIP_TYPES and int(it.get("value", 0)) > 0 and not it.get("alias_of"):
            if sourced(i) or it.get("type") in ("crop", "fruit", "flower"):
                ship.append({"item": i, "arc": arc_of(it), "family": SHIP_FAMILY[it["type"]], "where": where_hint(i, it, forage, pools)})
            else:
                dropped.append(i)
    # Crops/fruit/flowers count only if a seed or tree yields them (crops.json yield) or they're sourced.
    yields = {c.get("yield") for c in load("crops.json").values() if isinstance(c, dict)}
    ship = [e for e in ship if e["family"] not in ("Crops", "Fruit", "Flowers") or e["item"] in yields or sourced(e["item"])]
    ship = [e for e in ship if e["family"] in ("Animal goods", "Artisan goods")] + [e for e in ship if e["family"] not in ("Animal goods", "Artisan goods")]

    fish_log = [{"item": i, "arc": arc_of(items[i]), "where": where_hint(i, items[i], forage, pools)}
                for i in WINGS[3]["items"] + SEASON_FISH_LOG if i not in NOT_ROD]

    book_arc = {}  # a book's arc from the station that owns it (book 'robot' -> Robotics Bench, gangsters)
    for _bid, _b in buildings.items():
        if isinstance(_b, dict) and isinstance(_b.get("station"), dict) and _b.get("arc"):
            book_arc.setdefault(str(_b["station"].get("book", _bid)), str(_b["arc"]))

    def station_arc(s):
        return str(buildings.get(s, {}).get("arc", "") or book_arc.get(s, "") or "")

    cook, craft = [], []
    for s, lst in recipes.items():
        for r in lst:
            rid = str(r["id"])
            if rid.startswith(("brew_", "keg_")):
                continue
            e = {"recipe": rid, "station": s, "item": str(r.get("give", rid)), "name": r.get("name", rid),
                 "arc": str(r.get("arc", "") or station_arc(s))}
            (cook if s in COOK_STATIONS else craft).append(e)
    forage_log = [{"item": i, "arc": arc_of(it), "where": where_hint(i, it, forage, pools)}
                  for i, it in items.items() if it.get("type") in ("forage", "herb") and int(it.get("value", 0)) > 0 and sourced(i)]

    items["curators_loupe"] = LOUPE
    critter_items(items)
    critter_log = [{"item": c["id"], "arc": c.get("arc", ""), "where": critter_where(c)} for c in CRITTERS]
    out = {"_": "Generated by tools/gen_collections.py", "cats": CATS, "wings": wings,
           "logs": {"shipping": ship, "fish": fish_log, "cooking": cook, "crafting": craft, "forage": forage_log, "ranch": ranch_log,
                    "critters": critter_log},
           "stations": sorted({e["station"] for e in craft}), "milestones": MILESTONES, "decor_milestones": DECOR_MILESTONES, "letters": LETTERS,
           "room_names": ROOM_NAMES, "legends": LEGENDS,
           "critters": CRITTERS, "nets": NETS, "live_wing": LIVE_WING}
    check(out, items, src)
    save("collections.json", out)
    save("items.json", items)
    rooms = load("interiors.json")
    rooms["museum"] = room()
    patch_library(rooms)
    save("interiors.json", rooms)
    q = load("quests.json")
    mine = {x["id"]: x for x in QUESTS}
    have = {x["id"] for x in q["side"]}
    q["side"] = [mine.get(x["id"], x) for x in q["side"]] + [x for x in QUESTS if x["id"] not in have]
    save("quests.json", q)
    ql = load("quest_lines.json")
    ql.update(QUEST_LINES)
    ql.update(QUEST_LINES_GANG)
    save("quest_lines.json", ql)
    for arc in ("penguins", "gangsters"):
        ok = lambda e: e["arc"] in ("", arc)
        print("collections %s: museum %d, shipping %d, fish %d, cooking %d, crafting %d, forage %d" % (
            arc, sum(1 for w in wings for e in w["entries"] if ok(e)), sum(map(ok, ship)), sum(map(ok, fish_log)),
            sum(map(ok, cook)), sum(map(ok, craft)), sum(map(ok, forage_log))))
    print("shipping log left out (no source found): %d (%s...)" % (len(dropped), ", ".join(dropped[:8])))


# Pre-C10 milestone props drawn at fixed farmhouse cells (Collections.DECOR_AT).
LEGACY_DECOR = {"museum_trophy", "mineral_display", "relic_shelf", "curio_jar", "fish_trophy", "shipper_ribbon"}


def check(out, items, src):
    bad = []
    icons = os.path.join(ROOT, "art", "gen", "items")
    have_icon = {f[:-4] for f in os.listdir(icons) if f.endswith(".png")}
    for w in out["wings"]:
        for e in w["entries"]:
            i = e["item"]
            if i not in items:
                bad.append("unknown museum item " + i)
            elif i not in have_icon and items[i].get("icon", i) not in have_icon:
                bad.append("no icon " + i)
            elif i not in out["legends"] and not (items[i].get("water") and items[i].get("seasons")) \
                    and not re.search(r"[\"']%s[\"']" % re.escape(i), src):  # seasonal fish: Fishing.season_fish
                bad.append("museum item with no source " + i)
    for m in out["milestones"] + out["decor_milestones"]:
        g = m["give"]
        if "decor" in g and not (g["decor"].startswith("dc_") or g["decor"] in LEGACY_DECOR):
            bad.append("milestone decor id must be a catalogue id (dc_...): " + m["id"])
        if int(g.get("money", 0)) > 5000:
            bad.append("milestone money over 5000: " + m["id"])
        if "item" in g and g["item"] not in items:
            bad.append("milestone item unknown: " + g["item"])
        for k in ("text", "text_gangsters"):
            low = m[k].lower() if k.endswith("gangsters") else ""
            for word in ("crystal", "wine", "gambl", "penguin", "beer"):
                if word in low:
                    bad.append("gang text word %r in %s" % (word, m["id"]))
    ids = [m["id"] for m in out["milestones"] + out["decor_milestones"]]
    if len(ids) != len(set(ids)):
        bad.append("duplicate milestone ids")
    if any(c["id"] == "decor" for c in out["cats"]):
        bad.append("decor must not be a Book cat (DecorCatalogue has its own page)")
    for L in out["legends"].values():
        if "first_decor" in L and not L["first_decor"].startswith("dc_"):
            bad.append("legend first_decor must be a catalogue id")
    if bad:
        print("\n".join(bad))
        sys.exit(1)


if __name__ == "__main__":
    main()
