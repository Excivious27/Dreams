#!/usr/bin/env python3
"""Writes data/wardrobe.json: the cosmetic wardrobe pieces (CONDUCT 10a P5).

Every piece is a Decor wear entry (Decor.WEAR_SLOTS) plus how it is drawn:
  renders  "doll"     PaperDoll layers on the build-your-own hero (outfit body sheet,
                      hat/face 3-view sheet pinned to the head anchor)
           "penguin"  pinned accessory on the penguin heroes (Pip-Pip, Nova) and the
                      plain penguin sprite; see Wardrobe.PENGUIN_ANCHOR
  doll     {"body": sheet} | {"hat": "group/name"} | {"face": "group/name"}
  penguin  {"neck"|"face"|"hat": "group/name"}
  starter  free in the wardrobe for that arc (everyday clothes, like hair)
Cosmetics never carry stats. Ids are decor.json's wherever P1's catalogue already has
the piece (C10b: one id set; the old C10a ids live on in ALIAS for saves), so name,
price and sources stay P1's and this file only adds the render contract. Pieces only
the wardrobe has (colourway hats, bowties, penguin goggles, knight helm) carry their own
"sources" + "pools" ([pool, weight]) and Wardrobe.register() files them into Decor's
loot pools at runtime. SETS (street, snowfolk) list obtainable pieces and a reward;
register() adds them to Decor's sets so the catalogue can pay them.
Edit this file, then run it (regen_data.sh runs it right after gen_decor.py: its self-check reads decor.json).
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRICE = {"common": 150, "uncommon": 400, "rare": 900, "epic": 2000, "legendary": 4500, "mythic": 9000}
SELL_SHARE = 0.2  # sell-back share of the price (P1's econ_check owns the ladder)

SETS = {
    "street": {"name": "Street Set", "arc": "gangsters", "desc": "Sharp suits and tilted brims for the crew boss.",
               "pieces": ["wr_outfit_pinstripe", "wr_outfit_vest", "wr_outfit_armored", "wr_fedora", "wr_shades"],
               "reward": {"money": 1500, "decor": "wr_hat_bandana_gold"}},
    "snowfolk": {"name": "Snowfolk Set", "arc": "penguins", "desc": "Quilted, puffy and ready for a snowball war.",
                 "pieces": ["wr_outfit_parka", "wr_outfit_crystal_parka", "wr_aurora_hood", "wr_snow_goggles", "wr_bowtie_red", "wr_scarf_blue"],
                 "reward": {"money": 1500, "decor": "wr_goggles_ice"}},
}
# Old C10a ids -> the decor.json id (saves keep working: Wardrobe.migrate()).
ALIAS = {"wr_farmer_clothes": "wr_outfit_farmer", "wr_fisher_gear": "wr_outfit_fisher", "wr_forester_cloak": "wr_outfit_forester",
         "wr_miner_overalls": "wr_outfit_miner", "wr_merchant_coat": "wr_outfit_merchant", "wr_scholar_robe": "wr_outfit_scholar",
         "wr_neon_jacket": "wr_outfit_neon", "wr_ceremony_coat": "wr_outfit_penguin", "wr_pinstripe_suit": "wr_outfit_pinstripe",
         "wr_padded_vest": "wr_outfit_vest", "wr_armored_suit": "wr_outfit_armored", "wr_puffy_parka": "wr_outfit_parka",
         "wr_crystal_parka": "wr_outfit_crystal_parka", "wr_starlight_mantle": "wr_outfit_starlight"}
for _h in ("straw", "cap", "beanie", "flatcap", "bandana", "kerchief", "earmuffs", "cowboy", "tophat", "flower_crown", "hood", "witch",
           "goggles", "crystal_crown", "halo"):
    ALIAS["wr_hat_" + _h] = "wr_" + _h
# Loot for wardrobe-only pieces (decor.json pool weights by rarity).
POOL_W = {"common": 600, "uncommon": 260, "rare": 100, "epic": 30, "legendary": 8, "mythic": 8}
OWN_LOOT = {"wr_hat_beanie_blue": ["chest_t2"], "wr_hat_beanie_green": ["chest_t2"], "wr_hat_beanie_gold": ["chest_t3"],
            "wr_hat_bandana_blue": ["chest_t2"], "wr_hat_bandana_green": ["chest_t2"], "wr_hat_bandana_gold": ["chest_t3"],
            "wr_bowtie_red": ["chest_t2", "fishing"], "wr_bowtie_blue": ["chest_t2", "fishing_sea"],
            "wr_goggles_brass": ["chest_t3"], "wr_goggles_ice": ["chest_t4"], "wr_hat_knight": ["chest_t4", "boss"]}

# id, slot, name, rarity, arc, renders, draw, set, starter, desc
P = []
def add(i, slot, name, rarity, arc, renders, draw, st="", starter=False, desc="", pdraw=None):
    i = ALIAS.get(i, i)
    P.append(dict(id=i, slot=slot, name=name, rarity=rarity, arc=arc, renders=renders, doll=draw if renders != "penguin" else {},
                  penguin=pdraw or ({} if renders == "doll" else draw), set=st, starter=starter, desc=desc))

# Everyday outfits (whole-body costume sheets, custom hero)
add("wr_farmer_clothes", "outfit", "Farmer's Clothes", "common", "", "doll", {"body": "outfit_farmer"}, "everyday", True, "Patched knees, deep pockets.")
add("wr_fisher_gear", "outfit", "Fisher's Gear", "common", "", "doll", {"body": "outfit_fisher"}, "everyday", True, "Smells faintly of the lake.")
add("wr_forester_cloak", "outfit", "Forester's Cloak", "common", "", "doll", {"body": "outfit_forester"}, "everyday", True, "Green as the deep woods.")
add("wr_miner_overalls", "outfit", "Miner's Overalls", "common", "", "doll", {"body": "outfit_miner"}, "everyday", True, "Comes with its own helmet lamp.")
add("wr_merchant_coat", "outfit", "Merchant's Coat", "common", "", "doll", {"body": "outfit_merchant"}, "everyday", True, "A coat with a pocket for every coin.")
add("wr_scholar_robe", "outfit", "Scholar's Robe", "common", "", "doll", {"body": "outfit_scholar"}, "everyday", True, "Ink stains are a sign of wisdom.")
add("wr_neon_jacket", "outfit", "Neon Street Jacket", "common", "gangsters", "doll", {"body": "outfit_neon"}, "everyday", True, "Glows a little under streetlights.")
add("wr_ceremony_coat", "outfit", "Ceremony Coat", "common", "penguins", "doll", {"body": "outfit_penguin"}, "everyday", True, "Black and white, very formal, very penguin.")
# The six drawn arc costumes
add("wr_pinstripe_suit", "outfit", "Pinstripe Suit", "rare", "gangsters", "doll", {"body": "outfit_pinstripe"}, "street", False, "Pressed sharp. People lower their voices.")
add("wr_padded_vest", "outfit", "Padded Vest", "uncommon", "gangsters", "doll", {"body": "outfit_vest"}, "street", False, "Quilted, sturdy, many pockets.")
add("wr_armored_suit", "outfit", "Armored Suit", "epic", "gangsters", "doll", {"body": "outfit_armored"}, "street", False, "A suit with plates sewn in. Looks the part.")
add("wr_puffy_parka", "outfit", "Puffy Parka", "uncommon", "penguins", "doll", {"body": "outfit_parka"}, "snowfolk", False, "So puffy you could nap standing up.")
add("wr_crystal_parka", "outfit", "Crystal Parka", "epic", "penguins", "doll", {"body": "outfit_crystal_parka"}, "snowfolk", False, "Frost-blue, with crystal toggles.")
add("wr_starlight_mantle", "outfit", "Starlight Mantle", "legendary", "penguins", "doll", {"body": "outfit_starlight"}, "snowfolk", False, "Woven from a clear winter night.")
# Arc headgear (sliced 3-view-plus hats_poses sheets)
add("wr_fedora", "hat", "Fedora", "uncommon", "gangsters", "doll", {"hat": "hats_poses/fedora"}, "street", False, "Tilted just so.")
add("wr_shades", "acc", "Shades", "uncommon", "gangsters", "doll", {"face": "hats_poses/shades"}, "street", False, "Too cool to squint.")
add("wr_snow_goggles", "acc", "Snow Goggles", "uncommon", "penguins", "doll", {"face": "hats_poses/snow_goggles"}, "snowfolk", False, "For seeing through a blizzard.")
add("wr_aurora_hood", "hat", "Aurora Hood", "rare", "penguins", "doll", {"hat": "hats_poses/aurora_hood"}, "snowfolk", False, "Shimmers green and violet.")
# Shared hats (art/gen/hats)
for hid, nm, rar, desc in [("straw", "Straw Hat", "common", "Keeps the sun off."), ("cap", "Ball Cap", "common", "Worn a little crooked."),
                           ("beanie", "Beanie", "common", "Warm ears, happy farmer."), ("flatcap", "Flat Cap", "common", "Old-fashioned and dapper."),
                           ("bandana", "Bandana", "common", "Tied on tight."), ("kerchief", "Kerchief", "common", "A bright square of cloth."),
                           ("earmuffs", "Earmuffs", "uncommon", "Fluffy and toasty."), ("cowboy", "Cowboy Hat", "uncommon", "Wide brim, big attitude."),
                           ("tophat", "Top Hat", "uncommon", "Instantly fancy."), ("flower_crown", "Flower Crown", "uncommon", "Fresh from the meadow."),
                           ("hood", "Traveller's Hood", "uncommon", "For long roads."), ("witch", "Pointy Hat", "rare", "Very pointy. Very magical."),
                           ("goggles", "Tinker Goggles", "rare", "Pushed up, ready to tinker."), ("knight", "Knight's Helm", "epic", "Visor up, of course."),
                           ("crystal_crown", "Crystal Crown", "legendary", "Rings softly in the wind."), ("halo", "Halo", "mythic", "Nobody knows where it came from.")]:
    add("wr_hat_" + hid, "hat", nm, rar, "", "doll", {"hat": "hats/" + hid}, "", hid in ("straw", "cap"), desc)
SCARF = {"red": "d8403a", "blue": "3f6fd8", "green": "4aa84a", "yellow": "e8c23a", "purple": "8a5ad8", "white": "f4f4f4"}
# Colourways of the knit/cloth hats (luma recolour, PaperDoll._colourway)
for hid, nm in [("beanie", "Beanie"), ("bandana", "Bandana")]:
    for col, hexv, rar in [("blue", "5c84e0", "uncommon"), ("green", "62b266", "uncommon"), ("gold", "f2d27a", "rare")]:
        add("wr_hat_%s_%s" % (hid, col), "hat", "%s %s" % (col.capitalize(), nm), rar, "", "doll", {"hat": "hats/" + hid, "tint": hexv}, "", False, "Same cosy %s, new colour." % nm.lower())
# Penguin accessories (pinned on Pip-Pip / Nova; whole-penguin wear sheets on the plain penguin)
for col, rar in [("red", "common"), ("blue", "common"), ("green", "common"), ("yellow", "uncommon"), ("purple", "uncommon"), ("white", "rare")]:
    add("wr_scarf_" + col, "acc", col.capitalize() + " Scarf", rar, "penguins", "penguin", {"neck": "decor/pg_scarf", "tint": SCARF[col], "plain": "scarf_" + col}, "snowfolk", col == "red", "Knitted with room for flippers.")
add("wr_bowtie_red", "acc", "Red Bowtie", "uncommon", "penguins", "penguin", {"neck": "decor/pg_bowtie", "tint": "d8403a", "plain": "bowtie_red"}, "snowfolk", False, "Ready for a very fancy fish dinner.")
add("wr_bowtie_blue", "acc", "Blue Bowtie", "uncommon", "penguins", "penguin", {"neck": "decor/pg_bowtie", "tint": "3f6fd8", "plain": "bowtie_blue"}, "snowfolk", False, "Ready for a very fancy fish dinner.")
add("wr_goggles_brass", "hat", "Brass Goggles", "rare", "penguins", "penguin", {"face": "decor/pg_goggles", "tint": "ffffff", "plain": "goggles_a"}, "snowfolk", False, "For flying very fast. Or pretending to.")
add("wr_goggles_ice", "hat", "Ice Goggles", "rare", "penguins", "penguin", {"face": "decor/pg_goggles", "tint": "a8e0ff", "plain": "goggles_b"}, "snowfolk", False, "Frosty lenses, perfect for snow.")


def main():
    ids = set()
    items = {}
    for p in P:
        assert p["id"] not in ids, p["id"]
        ids.add(p["id"])
        assert p["slot"] in ("hat", "top", "bottom", "outfit", "acc", "shoes"), p
        assert p["rarity"] in PRICE, p
        assert p["arc"] in ("", "gangsters", "penguins"), p
        assert p["set"] in ("", "everyday") or p["set"] in SETS, p
        price = PRICE[p["rarity"]]
        d = p["doll"]
        art = ("body/" + d["body"]) if "body" in d else (d.get("hat") or d.get("face") or (p["penguin"].get("neck") or p["penguin"].get("face") or ""))
        items[p["id"]] = {
            "name": p["name"], "cat": p["slot"], "slot": p["slot"], "rarity": p["rarity"], "arc": p["arc"], "layer": "wear",
            "size": [1, 1], "rot": 1, "glow": False, "art": art, "icon": art, "price": price, "sell": int(price * SELL_SHARE),
            "sources": [{"kind": "loot", "ref": r} for r in OWN_LOOT.get(p["id"], [])], "set": p["set"], "renders": p["renders"],
            "doll": p["doll"], "penguin": p["penguin"], "starter": p["starter"], "starter_arc": p["arc"] if p["starter"] else "",
            "pools": [[r, POOL_W[p["rarity"]]] for r in OWN_LOOT.get(p["id"], [])], "desc": p["desc"], "stats": {}}
    # Self-checks: no stats on cosmetics, every set has both arcs' pieces where it says, counts
    for i, e in items.items():
        assert not e["stats"], i
    n_arc = {a: sum(1 for e in items.values() if e["arc"] in ("", a)) for a in ("gangsters", "penguins")}
    assert min(n_arc.values()) >= 20, n_arc
    # One id set (c10b_11-01): every piece is decor.json's or has its own loot/set source.
    dpath = os.path.join(ROOT, "data", "decor.json")
    decor = json.load(open(dpath))["items"] if os.path.exists(dpath) else {}
    rewards = {str(st["reward"].get("decor", "")) for st in SETS.values()}
    for i, e in items.items():
        assert i not in ALIAS, i
        if e["starter"] or i in decor:
            continue
        assert e["pools"] or i in rewards, "no source for wardrobe-only piece " + i
    for sid, st in SETS.items():
        for pid in st["pieces"]:
            assert pid in items or pid in decor, (sid, pid)
            a = items.get(pid, decor.get(pid, {})).get("arc", "")
            assert a in ("", st["arc"]), (sid, pid, a)
    out = {"_doc": "Generated by tools/gen_wardrobe.py (edit that).", "sets": SETS, "alias": ALIAS, "items": items}
    path = os.path.join(ROOT, "data", "wardrobe.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)
        f.write("\n")
    if "-q" not in sys.argv:
        print("wardrobe.json: %d pieces (gangsters %d, penguins %d)" % (len(items), n_arc["gangsters"], n_arc["penguins"]))


if __name__ == "__main__":
    main()
