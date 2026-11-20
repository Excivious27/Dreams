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
    "legendary_koi": "The lake, at dawn in rain or winter. Fishing 8+. Only one exists.",
    "tuna": "A gift from the Sanctuary pool, or a lucky weekly perk.",
    "crab": "The beach shallows (forage).",
    "ancient_urn": "Buried caches (dig with the hoe where the ground looks turned).",
    "eagle_feather": "Mountain forage, now and then.",
    "goat_horn": "Mountain forage, rarely.",
    "otter_whisker": "Dropped by otters by the water.",
    "book": "Old chests and the library's lost-and-found.",
}

# Fish the rod can catch (the fish log); tuna and crab come other ways (museum only).
NOT_ROD = ["tuna", "crab"]

# Legends: replace a normal catch once per run when the place and moment fit (bypass the value ceiling).
LEGENDS = {
    "legendary_koi": {"scene": "lake", "lvl": 8, "when": "rain_or_winter_dawn", "chance": 0.04},
}

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
]

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
    {"id": "mus_all", "cat": "museum", "need": "all", "from": "theo", "give": {"money": 5000, "item": "curators_loupe", "n": 1},
     "text": "The museum is complete. I didn't think I'd live to write that. Please take my old loupe: it always finds the lucky things. - Theo",
     "text_gangsters": "The Curio Room is complete. Take my old loupe. It has a habit of spotting the good stuff. - Theo"},
    {"id": "ship_25", "cat": "shipping", "need": 25, "from": "maple", "give": {"money": 500},
     "text": "Twenty-five different things through your sell box! The whole town eats better for it. - Maple",
     "text_gangsters": "Twenty-five different goods through your box. Business likes variety. - Maple"},
    {"id": "ship_75", "cat": "shipping", "need": 75, "from": "maple", "give": {"money": 1500, "decor": "shipper_ribbon"},
     "text": "Seventy-five kinds shipped. Here's a ribbon. The fair judges don't give these out for nothing. - Maple",
     "text_gangsters": "Seventy-five kinds of goods. Here's a ribbon for the wall: best supplier on the block. - Maple"},
    {"id": "ship_150", "cat": "shipping", "need": 150, "from": "maple", "give": {"money": 4000},
     "text": "A hundred and fifty kinds! I've run out of shelf labels. - Maple",
     "text_gangsters": "A hundred and fifty kinds. I ran out of price tags. - Maple"},
    {"id": "fish_10", "cat": "fish", "need": 10, "from": "finn", "give": {"item": "bait", "n": 20},
     "text": "Ten kinds of fish caught! Bait's on me. - Finn",
     "text_gangsters": "Ten kinds of fish. Bait's on me. - Finn"},
    {"id": "fish_all", "cat": "fish", "need": "all", "from": "finn", "give": {"money": 3000},
     "text": "Every fish the rod can find. You're the best angler this lake has seen. - Finn",
     "text_gangsters": "Every fish a rod can find. Best angler on the waterfront. - Finn"},
    {"id": "cook_10", "cat": "cooking", "need": 10, "from": "posy", "give": {"money": 600},
     "text": "Ten dishes cooked! You've got the touch. - Posy",
     "text_gangsters": "Ten dishes. You cook like you mean it. - Posy"},
    {"id": "cook_all", "cat": "cooking", "need": "all", "from": "posy", "give": {"money": 3000},
     "text": "You've cooked every recipe there is. Teach me something now! - Posy",
     "text_gangsters": "Every recipe in the book. Your turn to teach me. - Posy"},
    {"id": "craft_25", "cat": "crafting", "need": 25, "from": "hazel", "give": {"item": "chest", "n": 1},
     "text": "Twenty-five things built! Have a spare chest for all of it. - Hazel",
     "text_gangsters": "Twenty-five builds. Here's a spare chest. - Hazel"},
    {"id": "craft_100", "cat": "crafting", "need": 100, "from": "hazel", "give": {"money": 2500},
     "text": "A hundred different builds. You're putting my crew to shame. - Hazel",
     "text_gangsters": "A hundred builds. My crew's getting nervous. - Hazel"},
    {"id": "forage_20", "cat": "forage", "need": 20, "from": "willow", "give": {"money": 400},
     "text": "Twenty wild things found. The valley shares with those who look. - Willow",
     "text_gangsters": "Twenty wild finds. The city's got more green in it than people think. - Willow"},
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


def where_hint(item_id, it, forage, pools):
    if item_id in WHERE:
        return WHERE[item_id]
    t = it.get("type", "")
    places = [k for k, tab in forage.items() if any(e[0] == item_id for e in tab)]
    if t == "fish":
        p = pools.get(item_id, [])
        v = int(it.get("value", 0))
        lvl = max(0, (v - 25 - 40 - 10 + 14) // 15)
        s = ", ".join(x.replace("_", " ").title() for x in p[:2]) or "Somewhere in the water"
        return s + (", at night with bait, fishing %d+" % lvl if v > 75 else "")
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
                if scene not in out[fid] and scene not in ("game_map", "game_state", "collections"):
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
        wings.append({"id": w["id"], "title": w["title"], "entries": ents})

    ship, dropped = [], []
    for i, it in items.items():
        if it.get("type") in SHIP_TYPES and int(it.get("value", 0)) > 0 and not it.get("alias_of"):
            if sourced(i) or it.get("type") in ("crop", "fruit", "flower"):
                ship.append({"item": i, "arc": arc_of(it), "family": SHIP_FAMILY[it["type"]], "where": where_hint(i, it, forage, pools)})
            else:
                dropped.append(i)
    # Crops/fruit/flowers count only if a seed or tree yields them (crops.json yield) or they're sourced.
    yields = {c.get("yield") for c in load("crops.json").values() if isinstance(c, dict)}
    ship = [e for e in ship if e["family"] not in ("Crops", "Fruit", "Flowers") or e["item"] in yields or sourced(e["item"])]

    fish_log = [{"item": i, "arc": arc_of(items[i]), "where": where_hint(i, items[i], forage, pools)}
                for i in WINGS[3]["items"] if i not in NOT_ROD]

    def station_arc(s):
        return str(buildings.get(s, {}).get("arc", "") or "")

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
    out = {"_": "Generated by tools/gen_collections.py", "cats": CATS, "wings": wings,
           "logs": {"shipping": ship, "fish": fish_log, "cooking": cook, "crafting": craft, "forage": forage_log},
           "stations": sorted({e["station"] for e in craft}), "milestones": MILESTONES, "letters": LETTERS,
           "room_names": ROOM_NAMES, "legends": LEGENDS}
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
            elif i not in out["legends"] and not re.search(r"[\"']%s[\"']" % re.escape(i), src):
                bad.append("museum item with no source " + i)
    for m in out["milestones"]:
        g = m["give"]
        if int(g.get("money", 0)) > 5000:
            bad.append("milestone money over 5000: " + m["id"])
        if "item" in g and g["item"] not in items:
            bad.append("milestone item unknown: " + g["item"])
        for k in ("text", "text_gangsters"):
            low = m[k].lower() if k.endswith("gangsters") else ""
            for word in ("crystal", "wine", "gambl", "penguin", "beer"):
                if word in low:
                    bad.append("gang text word %r in %s" % (word, m["id"]))
    if bad:
        print("\n".join(bad))
        sys.exit(1)


if __name__ == "__main__":
    main()
