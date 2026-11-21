#!/usr/bin/env python3
"""C15 P2 seasonal goods: one generator for what each season grows, forages, cooks and sells.

Writes (idempotent, runs in regen_data.sh before gen_stations so ECON floors/descs apply):
  data/items.json        new seasonal forage items (icon c15p2_*), winter crop seeds, seasonal dishes
  data/crops.json        winter crops for the winter yields that had no crop (art shares a sheet)
  data/recipes.json      kitchen: seasonal dishes (field "season" = the season it is taught/cooked for)
  data/season_goods.json forage {season: {region: [[id, w], ...]}}, forage_off {season: {id: mult}},
                         shops {shop: {season: [ids]}}, shops_y2 {shop: {season: [ids]}},
                         greenhouse_seeds {season: [seed ids]} (off-season seeds once the glass plot is up)
Runtime: scripts/season_goods.gd (SeasonGoods).
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "data")


def J(n):
    return json.load(open(os.path.join(D, n)))


def W(n, obj):
    with open(os.path.join(D, n), "w") as fh:
        json.dump(obj, fh, indent=1, ensure_ascii=False)


I = J("items.json")
C = J("crops.json")
R = J("recipes.json")

# ---- forage items (art: tools/slice_c15_p2.py) -------------------------------
# id: (name, type, value, tier, rarity, heal, season)
FORAGE = {
    "fiddlehead": ("Fiddlehead Fern", "forage", 18, 1, "common", 1, "spring"),
    "salmonberry": ("Salmonberry", "forage", 14, 1, "common", 1, "spring"),
    "crocus": ("Crocus", "flower", 16, 1, "common", 0, "spring"),
    "sand_dollar": ("Sand Dollar", "forage", 30, 1, "uncommon", 0, "summer"),
    "sea_glass": ("Sea Glass", "forage", 40, 2, "uncommon", 0, "summer"),
    "summer_kelp": ("Summer Kelp", "forage", 12, 1, "common", 1, "summer"),
    "cattail": ("Cattail", "forage", 10, 1, "common", 0, "summer"),
    "water_lily": ("Water Lily", "flower", 28, 1, "uncommon", 0, "summer"),
    "honeysuckle": ("Honeysuckle", "flower", 18, 1, "common", 0, "summer"),
    "chanterelle": ("Chanterelle", "forage", 45, 2, "uncommon", 2, "fall"),
    "hazelnut": ("Hazelnut", "forage", 16, 1, "common", 1, "fall"),
    "rosehip": ("Rosehip", "forage", 14, 1, "common", 1, "fall"),
    "wild_plum": ("Wild Plum", "forage", 20, 1, "common", 1, "fall"),
    "chestnut": ("Chestnut", "forage", 18, 1, "common", 1, "fall"),
    "leaf_bundle": ("Maple Leaf Bundle", "forage", 8, 1, "common", 0, "fall"),
    "holly_sprig": ("Holly Sprig", "forage", 20, 1, "common", 0, "winter"),
    "snow_yam": ("Snow Yam", "forage", 30, 1, "common", 2, "winter"),
    "crystal_icicle": ("Crystal Icicle", "forage", 60, 2, "uncommon", 0, "winter"),
    "winter_honeycomb": ("Winter Honeycomb", "forage", 55, 2, "uncommon", 2, "winter"),
}
DESC = {
    "fiddlehead": "A curled fern shoot from the spring woods. Snap it before it unrolls.",
    "salmonberry": "Tart orange berries that only ripen in spring.",
    "crocus": "The first flower through the thaw.",
    "sand_dollar": "A flat little shell washed up by the summer tide.",
    "sea_glass": "Sea-smoothed glass, frosted aqua. Summer beaches only.",
    "summer_kelp": "Warm-water kelp. Salty, chewy, good in a wrap.",
    "cattail": "A fuzzy reed head from the summer shallows.",
    "water_lily": "A white lily that opens on summer ponds.",
    "honeysuckle": "Sweet summer blossom. Makes a fragrant tea.",
    "chanterelle": "A golden fall mushroom with an apricot smell.",
    "hazelnut": "Fall nuts in a frilly husk.",
    "rosehip": "Red fall hips from the wild rose. Jam-worthy.",
    "wild_plum": "Small purple plums from a hedgerow in fall.",
    "chestnut": "A glossy fall chestnut. Roast it.",
    "leaf_bundle": "Crimson and gold fall leaves, tied with twine.",
    "holly_sprig": "Glossy winter holly with red berries. Lovely on a door.",
    "snow_yam": "A sweet root dug from under the winter snow.",
    "crystal_icicle": "An icicle so clear it rings. Only in deep winter.",
    "winter_honeycomb": "Wild comb from a sleeping hive. A winter treat.",
}
for k, (nm, ty, val, tier, rar, heal, se) in FORAGE.items():
    it = I.get(k, {})
    it.update({"name": nm, "type": ty, "value": val, "tier": tier, "rarity": rar, "icon": "c15p2_" + k,
               "seasons": [se], "desc": DESC[k]})
    it.pop("forage_season", None)
    if heal:
        it["heal"] = heal
    I[k] = it

# ---- winter crops ---------------------------------------------------------------
# crop id: (days, regrow, tier, art sheet, family, tree, seed value, new item (name, value, rarity) or None)
WINTER = {
    "frostkale": (4, 3, 1, "kale", "veg", False, 10, None),
    "snow_radish": (3, 0, 1, "radish", "veg", False, 8, ("Snow Radish", 26, "common")),
    "winter_leek": (5, 0, 1, "leek", "veg", False, 12, ("Winter Leek", 38, "common")),
    "frost_squash": (9, 5, 3, "yellow_squash", "veg", False, 120, None),
    "frost_edelweiss": (7, 0, 3, "poppy", "flower", False, 150, None),
    "frost_dragonfruit": (11, 5, 4, "dragonfruit", "fruit", False, 160, None),
    "winter_cabbage": (12, 0, 5, "cabbage", "veg", False, 600, None),
    "winter_snowdrop": (12, 0, 5, "moonflower", "flower", False, 600, None),
    "penguin_snowberry": (13, 6, 5, "frostberry", "berry", False, 700, None),
    "winter_rose_apple": (14, 6, 5, "apple", "tree", True, 700, None),
}
BANDS = {1: (2, 4), 2: (4, 7), 3: (7, 10), 4: (10, 18), 5: (18, 45)}  # mirror of econ_check BANDS


def _seed_value(cid, days, rg, tier, tree, sval):
    """Seed price that lands the crop at ~85% of its econ_check band ceiling (trees: as given)."""
    if tree:
        return sval
    y = int(I[cid]["value"])
    picks = (1 + max(0, (27 - days) // rg)) if rg else max(1, 27 // days)
    pd = BANDS[tier][1] * 0.85 * 27
    s = (picks * y - pd) / 1.5 if rg else (y - pd / picks) / 1.5
    return max(sval, int(s) + 1)


for cid, (days, regrow, tier, art, fam, tree, sval, new) in WINTER.items():
    if new:
        nm, val, rar = new
        it = I.get(cid, {})
        it.update({"name": nm, "type": "crop", "value": val, "tier": tier, "rarity": rar, "heal": 2,
                   "family": "veg", "icon": "c15p2_" + cid})
        I[cid] = it
    I[cid]["family"] = I[cid].get("family") or fam
    tier = int(I[cid].get("tier", tier))  # econ_check: the crop's tier is its yield's tier
    sval = _seed_value(cid, days, regrow, tier, tree, sval)
    row = {"name": I[cid]["name"], "days": days, "stages": 6 if days > 5 else 4, "yield": cid,
           "color": "4f9a3a" if not tree else "6a4a2a", "top": "bfefff", "season": "winter",
           "tier": tier, "family": fam, "art": art, "c15": True}
    if regrow:
        row["regrow"] = regrow
    if tree:
        row["tree"] = True
    C[cid] = row
    sid = cid + "_seed"
    s = I.get(sid, {})
    s.update({"name": I[cid]["name"] + (" Sapling" if tree else " Seeds"), "type": "seed", "crop": cid,
              "value": sval, "tier": tier, "rarity": "common" if tier <= 2 else ("rare" if tier <= 4 else "epic")})
    s.pop("desc", None)
    s.pop("desc_auto", None)
    if os.path.exists(os.path.join(ROOT, "art", "gen", "items", art + "_seed.png")):
        s["icon"] = art + "_seed"
    I[sid] = s
I.setdefault("moon_melon_seed", {})["icon"] = "c15p2_moon_melon_seed"

# ---- seasonal dishes --------------------------------------------------------------
# id: (name, need, icon, tier, season, energy, heal)
DISHES = {
    "spring_greens": ("Spring Greens Salad", {"fiddlehead": 1, "wild_leek": 1, "dandelion": 1}, "salad", 1, "spring", 40, 2),
    "fiddlehead_saute": ("Fiddlehead Saute", {"fiddlehead": 2, "wild_garlic": 1}, "stir_fry", 1, "spring", 45, 2),
    "strawberry_shortcake": ("Strawberry Shortcake", {"strawberry": 3, "wheat": 1, "#milk": 1}, "cake", 2, "spring", 60, 3),
    "asparagus_tart": ("Asparagus Tart", {"asparagus": 2, "wheat": 1}, "fruit_tart", 2, "spring", 55, 3),
    "salmonberry_jam": ("Salmonberry Jam", {"salmonberry": 4}, "jam", 1, "spring", 30, 1),
    "honeysuckle_tea": ("Honeysuckle Tea", {"honeysuckle": 2}, "herbal_tea", 1, "summer", 35, 1),
    "kelp_salad": ("Sea Kelp Salad", {"summer_kelp": 2, "cucumber": 1}, "salad", 1, "summer", 45, 2),
    "corn_tomato_salad": ("Corn and Tomato Salad", {"corn": 1, "tomato": 2}, "salad", 1, "summer", 50, 2),
    "melon_sorbet": ("Melon Sorbet", {"melon": 1, "honey": 1}, "dream_pudding", 2, "summer", 55, 2),
    "chanterelle_stew": ("Chanterelle Stew", {"chanterelle": 2, "potato": 1}, "mushroom_stew", 2, "fall", 60, 3),
    "hazelnut_cake": ("Hazelnut Cake", {"hazelnut": 3, "wheat": 2}, "sponge_cake", 2, "fall", 55, 3),
    "rosehip_jam": ("Rosehip Jam", {"rosehip": 4}, "jam_plum", 1, "fall", 30, 1),
    "pumpkin_pie": ("Pumpkin Pie", {"pumpkin": 1, "wheat": 1, "#milk": 1}, "pumpkin_pie", 2, "fall", 65, 3),
    "roast_chestnuts": ("Roast Chestnuts", {"chestnut": 4}, "roast_veg", 1, "fall", 35, 2),
    "frostkale_soup": ("Frostkale Soup", {"frostkale": 2, "snow_yam": 1}, "soup_vegetable", 1, "winter", 55, 3),
    "snow_yam_roast": ("Snow Yam Roast", {"snow_yam": 2, "wild_herb": 1}, "roast_veg", 1, "winter", 50, 3),
    "snow_pea_stir_fry": ("Snow Pea Stir-Fry", {"snow_pea": 3, "winter_leek": 1}, "stir_fry", 2, "winter", 55, 3),
    "citrus_tart": ("Winter Citrus Tart", {"orange": 1, "lemon": 1, "wheat": 1}, "fruit_tart", 2, "winter", 60, 3),
    "honeycomb_toast": ("Honeycomb Toast", {"winter_honeycomb": 1, "bread": 1}, "berry_jam_toast", 1, "winter", 50, 2),
}


def need_value(need):
    tot = 0
    for k, n in need.items():
        if k.startswith("#"):
            tot += 36 * n
        else:
            tot += int(I.get(k, {}).get("value", 10)) * n
    return tot


kitchen = R.setdefault("kitchen", [])
taken = {r.get("give") for r in kitchen if not r.get("c15")}
kitchen[:] = [r for r in kitchen if not r.get("c15")]
for did, (nm, need, icon, tier, se, en, heal) in DISHES.items():
    for k in need:
        assert k.startswith("#") or k in I, (did, k)
    if did not in I or I[did].get("c15"):
        it = I.get(did, {})
        it.update({"name": nm, "type": "food", "value": int(round(need_value(need) * 1.4)), "tier": tier,
                   "rarity": "common" if tier == 1 else "uncommon", "energy": en, "heal": heal,
                   "seasons": [se], "c15": True})
        if not os.path.exists(os.path.join(ROOT, "art", "gen", "items", did + ".png")):
            it["icon"] = icon
        it.pop("desc", None)
        I[did] = it
    if did in taken:
        continue
    kitchen.append({"id": did, "name": nm, "need": need, "give": did, "tier": tier, "season": se, "c15": True})

# ---- forage pools ---------------------------------------------------------------------
VALLEY = ["farm", "forest", "meadow", "lake", "beach", "mountain", "orchard_hills", "wild"]
SEASON_FORAGE = {
    "spring": {
        "farm": [["dandelion", 0.15], ["crocus", 0.1]],
        "forest": [["fiddlehead", 0.22], ["morel", 0.06], ["wild_garlic", 0.1]],
        "meadow": [["violet", 0.14], ["daffodil", 0.12], ["crocus", 0.1], ["salmonberry", 0.14]],
        "lake": [["fiddlehead", 0.15], ["bluebell", 0.1]],
        "beach": [["sea_glass", 0.03]],
        "mountain": [["crocus", 0.1], ["fiddlehead", 0.08]],
        "orchard_hills": [["salmonberry", 0.15], ["daffodil", 0.1]],
        "wild": [["fiddlehead", 0.12], ["salmonberry", 0.12]],
    },
    "summer": {
        "farm": [["chamomile", 0.08], ["honeysuckle", 0.12]],
        "forest": [["elderflower", 0.12], ["honeysuckle", 0.08]],
        "meadow": [["honeysuckle", 0.15], ["chamomile", 0.1]],
        "lake": [["cattail", 0.2], ["water_lily", 0.12]],
        "beach": [["sand_dollar", 0.15], ["sea_glass", 0.1], ["summer_kelp", 0.2]],
        "mountain": [["edelweiss", 0.05]],
        "orchard_hills": [["honeysuckle", 0.12]],
        "wild": [["cattail", 0.1], ["honeysuckle", 0.1]],
    },
    "fall": {
        "farm": [["leaf_bundle", 0.15], ["rosehip", 0.1]],
        "forest": [["chanterelle", 0.18], ["hazelnut", 0.16], ["chestnut", 0.12]],
        "meadow": [["rosehip", 0.15], ["wild_plum", 0.12], ["elderberry", 0.1]],
        "lake": [["cattail", 0.12], ["leaf_bundle", 0.1]],
        "beach": [["summer_kelp", 0.06]],
        "mountain": [["hazelnut", 0.1], ["wild_plum", 0.08]],
        "orchard_hills": [["wild_plum", 0.15], ["chestnut", 0.12], ["leaf_bundle", 0.1]],
        "wild": [["chanterelle", 0.1], ["hazelnut", 0.12]],
    },
    "winter": {
        "farm": [["holly_sprig", 0.2], ["snow_yam", 0.15]],
        "forest": [["holly_sprig", 0.2], ["snow_yam", 0.15], ["crystal_icicle", 0.05], ["winter_honeycomb", 0.03]],
        "meadow": [["snow_yam", 0.2], ["winter_honeycomb", 0.06], ["holly_sprig", 0.1]],
        "lake": [["crystal_icicle", 0.15], ["frost_lily", 0.04]],
        "beach": [["crystal_icicle", 0.05]],
        "mountain": [["crystal_icicle", 0.15], ["holly_sprig", 0.1]],
        "orchard_hills": [["holly_sprig", 0.15], ["snow_yam", 0.12]],
        "wild": [["snow_yam", 0.15], ["holly_sprig", 0.12]],
    },
}
# Base-pool rows that thin out (x mult) or vanish (0) in a season. Winter honey stays rare
# (Posy's winter honey ask) and winter_honeycomb is the season's own sweet find.
FORAGE_OFF = {
    "spring": {"acorn": 0.3, "pinecone": 0.5},
    "summer": {"wild_leek": 0.3, "pinecone": 0.4, "acorn": 0.3},
    "fall": {"flower": 0.4, "wild_leek": 0.3},
    "winter": {"berry": 0.0, "flower": 0.0, "wild_leek": 0.0, "honey": 0.25, "mushroom": 0.3, "acorn": 0.3, "wild_herb": 0.5},
}

# ---- shop rotation ------------------------------------------------------------------
# Season-only goods appended to Shops.offers (both arcs: these are shared items; arc-only ids are filtered at runtime).
SHOPS = {
    "store": {"spring": ["spring_greens", "salmonberry_jam"], "summer": ["honeysuckle_tea", "corn_tomato_salad"],
              "fall": ["hazelnut_cake", "roast_chestnuts"], "winter": ["frostkale_soup", "honeycomb_toast"]},
    "orla": {"spring": ["strawberry_shortcake"], "summer": ["melon_sorbet"], "fall": ["pumpkin_pie"], "winter": ["citrus_tart"]},
    "bait": {"spring": ["fiddlehead_saute"], "summer": ["kelp_salad"], "fall": ["chanterelle_stew"], "winter": ["snow_yam_roast"]},
    "potions": {"spring": ["chamomile"], "summer": ["honeysuckle_tea"], "fall": ["rosehip_jam"], "winter": ["hot_cocoa"]},
    "marlowe": {"spring": ["crocus"], "summer": ["sand_dollar"], "fall": ["leaf_bundle"], "winter": ["holly_sprig"]},
    "lodge": {"spring": ["fiddlehead"], "summer": ["cattail"], "fall": ["chestnut"], "winter": ["snow_yam"]},
}
SHOPS_Y2 = {  # year 2+: one more seasonal good per shop
    "store": {"spring": ["asparagus_tart"], "summer": ["kelp_salad"], "fall": ["chanterelle_stew"], "winter": ["snow_pea_stir_fry"]},
    "old_moss": {"spring": ["morel"], "summer": ["water_lily"], "fall": ["chanterelle"], "winter": ["crystal_icicle"]},
}
for d in (SHOPS, SHOPS_Y2):
    for sh in d.values():
        for ids in sh.values():
            for i in ids:
                assert i in I, i

# Off-season seeds for the greenhouse (Maple, once the glass plot exists): next season's staples.
GLASS = {"spring": ["corn_seed", "tomato_seed", "pumpkin_seed"], "summer": ["pumpkin_seed", "cranberry_seed", "frostkale_seed"],
         "fall": ["frostkale_seed", "snow_radish_seed", "turnip_seed"], "winter": ["turnip_seed", "strawberry_seed", "corn_seed"]}
for ids in GLASS.values():
    for i in ids:
        assert i in I, i

# Each forage item lists every season it can be found in (collections/book hints read "seasons").
for k in FORAGE:
    I[k]["seasons"] = [se for se in ("spring", "summer", "fall", "winter")
                       if any(row[0] == k for rows in SEASON_FORAGE[se].values() for row in rows)]
    I[k]["forage_seasons"] = I[k]["seasons"]
W("items.json", I)
W("crops.json", C)
W("recipes.json", R)
W("season_goods.json", {"forage": SEASON_FORAGE, "forage_off": FORAGE_OFF, "valley": VALLEY, "shops": SHOPS,
                        "shops_y2": SHOPS_Y2, "greenhouse_seeds": GLASS,
                        "winter_seeds": ["snow_pea_seed", "frostkale_seed", "snow_radish_seed", "winter_leek_seed"],
                        "winter_rare": ["frost_squash_seed", "frost_edelweiss_seed", "winter_cabbage_seed", "winter_snowdrop_seed"],
                        "festival_treats": {"spring": [["salmonberry_jam", 60], ["strawberry_shortcake", 160]],
                                            "summer": [["honeysuckle_tea", 60], ["melon_sorbet", 200]],
                                            "fall": [["pumpkin_pie", 180], ["roast_chestnuts", 90]],
                                            "winter": [["hot_cocoa", 160], ["honeycomb_toast", 120]]}})
print("gen_seasons: %d forage, %d winter crops, %d dishes" % (len(FORAGE), len(WINTER), len(DISHES)))
