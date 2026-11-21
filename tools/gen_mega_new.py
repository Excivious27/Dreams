#!/usr/bin/env python3
"""Builds the six new Round 13 mega regions from tools/mega_regions_new.py.

Writes (idempotently: re-running replaces only what this script owns):
  data/regions.json      every area (hub + outer areas) as a Region entry
  scenes/<area>.tscn     one Region scene per area
  data/items.json        regional materials, fish, dishes, charms and rings (art already in art/gen/items)
  data/enemies.json      recoloured native foes ("tint") and one boss per region ("boss": true)
  data/forage.json       a forage table per area
  data/quests.json       a hook quest per region (opens the way) and a hub job per region
  data/quest_lines.json  the hub jobs' lines
  data/recipes.json      one kitchen recipe per region (regional ingredients: a reason to go back)
  data/mega_travel.json  MegaTravel's data: entries, keepers, lines, hub spawns

Layouts are worked out here on a cell grid (paths first, then buildings and
landmarks beside them, water and hills in the open, things on path-side cells) so
every door, shop, boss and pickup sits next to a road. tools/mega_regions_test.gd
walks every area to prove it.   Run: python3 tools/gen_mega_new.py
"""
import json, os, sys, math, random, zlib
D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(D, "tools"))
from mega_regions_new import REGIONS, BY_ID, EXTRA, EXTERNAL, TIER_STEP

def shash(t):  # stable across runs (Python's hash() is salted per process)
    return zlib.crc32(t.encode())

def J(p): return json.load(open(f"{D}/data/{p}"))
def W(p, v):
    raw = open(f"{D}/data/{p}").read()
    ind = 1 if raw.startswith('{\n "') else (2 if raw.startswith('{\n  "') else None)
    json.dump(v, open(f"{D}/data/{p}", "w"), indent=ind, ensure_ascii=False)
    if ind is None:
        pass

MAN = json.load(open(f"{D}/art/gen/manifest.json"))
_ALPHA = {}


def open_cells(p):
    """Footprint cells (offsets from the prop cell) that the art leaves see-through.

    Mirrors region.gd's footprint (art size * scale, clamped to w/h, tall props keep
    their lower 62%) and drops cells under ~20% opaque (3 of 16 samples), so a round plaza or a hut's
    corner is never an invisible wall (C2 world sweep)."""
    if not p.get("solid", True) or p.get("group", "props") == "buildings":
        return []
    g = p.get("group", "props")
    info = MAN.get(g, {}).get(p["name"])
    if not info:
        return []
    from PIL import Image
    key = info["file"]
    if key not in _ALPHA:
        im = Image.open(f"{D}/art/gen/{key}").convert("RGBA")
        cw = int(info.get("cell_w", info.get("w", im.width)))
        _ALPHA[key] = im.crop((0, 0, min(cw, im.width), im.height)).getchannel("A")
    a = _ALPHA[key]
    psc = float(p.get("scale", 0.5))
    w = int(p.get("w", 0))
    h = int(p.get("h", 1))
    aw = int(math.floor(float(info.get("cell_w", info.get("w", (w + 1) * 32))) * psc / 16 + 0.4))
    ah = int(math.floor(float(info.get("cell_h", info.get("h", h * 32))) * psc / 16 + 0.4))
    if "scale" in p:
        bw, bh = max(aw, 1), max(ah, 1)
    else:
        bw, bh = min(max(aw, 1), w + 1), min(max(ah, 1), h)
    if bh >= 3 and g != "nature":
        bh = max(2, int(math.ceil(bh * 0.62)))
    cx, cy = p["cell"]
    x0 = cx + (w + 1 - bw) // 2
    # The sprite: centred on (cx + (w+1)/2) cells, feet on the bottom of row cy.
    sw, sh = a.width * psc, a.height * psc
    left = (cx + (w + 1) / 2.0) * 16 - sw / 2.0
    top = (cy + 1) * 16 - sh
    out = []
    for yy in range(cy - bh + 1, cy + 1):
        for xx in range(x0, x0 + bw):
            # Sample the cell in a 4x4 grid of art pixels.
            hit = n = 0
            for sy in range(4):
                for sx in range(4):
                    wx = xx * 16 + 2 + sx * 4
                    wy = yy * 16 + 2 + sy * 4
                    px, py = int((wx - left) / psc), int((wy - top) / psc)
                    n += 1
                    if 0 <= px < a.width and 0 <= py < a.height and a.getpixel((px, py)) > 128:
                        hit += 1
            corner = xx in (x0, x0 + bw - 1) and yy in (cy - bh + 1, cy) and bw > 1
            if (hit == 0 or (hit <= 3 and corner)) and not (g == "nature" and yy == cy):  # under ~20%; a tree keeps its trunk row
                out.append([xx - cx, yy - cy])
    return out
def has_art(g, n): return n in MAN.get(g, {})

# ---------------------------------------------------------------- items
# (id: name, type, value, tier, extra). Icons already exist under the same id.
ITEMS = {
    # Gloamwood
    "wisp_thread": ("Wisp Thread", "material", 120, 2, {"rarity": "uncommon", "desc": "Spun by the glade wisps. Warm to the touch."}),
    "wisp_spark": ("Wisp Spark", "material", 160, 3, {"rarity": "rare", "desc": "A wisp's light, caught before it could fade."}),
    "luna_moth": ("Luna Moth", "treasure", 240, 3, {"rarity": "rare", "desc": "Sleeps all day on the lantern posts of Lanternfall."}),
    "ghost_fish": ("Ghostfish", "fish", 150, 2, {"rarity": "uncommon"}),
    "echo_pudding": ("Gloam Pudding", "food", 260, 3, {"rarity": "rare", "heal": 5, "energy": 95}),
    "charm_root": ("Thornroot Charm", "equip", 1400, 3, {"rarity": "epic", "slot": "charm", "stats": {"luck": 3, "mana": 15}, "desc": "The Thornmother's last bud, closed tight."}),
    "ring_glow": ("Glowmoss Ring", "equip", 900, 3, {"rarity": "rare", "slot": "ring", "stats": {"luck": 2}}),
    # Sunscorch
    "sunstone": ("Sunstone", "ore", 210, 3, {"rarity": "rare", "desc": "Holds the day's heat long after dark."}),
    "sun_scarab": ("Sun Scarab", "treasure", 280, 3, {"rarity": "rare", "desc": "A golden beetle carved by the temple builders."}),
    "spice": ("Desert Saffron", "forage", 120, 3, {"rarity": "uncommon"}),
    "sun_trout": ("Sun Trout", "fish", 140, 3, {"rarity": "uncommon"}),
    "sun_loaf": ("Sun Loaf", "food", 240, 3, {"rarity": "rare", "heal": 5, "energy": 100}),
    "charm_sun": ("Colossus Charm", "equip", 1800, 4, {"rarity": "epic", "slot": "charm", "stats": {"damage": 2, "defense": 2}, "desc": "A chip of the Colossus's heart. Still warm."}),
    # Ironline
    "tin": ("Coalbrook Tin", "ore", 120, 3, {"rarity": "uncommon"}),
    "oil": ("Engine Oil", "material", 90, 3, {"rarity": "uncommon"}),
    "chain_link": ("Rail Chain", "material", 110, 3, {"rarity": "uncommon"}),
    "charcoal": ("Firebox Charcoal", "material", 60, 2, {"rarity": "common"}),
    "stew_beef": ("Stoker's Stew", "food", 230, 3, {"rarity": "rare", "heal": 5, "energy": 100}),
    "pocket_watch": ("Baron's Pocket Watch", "equip", 2000, 4, {"rarity": "epic", "slot": "charm", "stats": {"speed": 2, "energy": 25}, "desc": "Runs eight minutes fast. Every train in Ironline ran by it."}),
    "ring_steel": ("Rivet Ring", "equip", 950, 3, {"rarity": "rare", "slot": "ring", "stats": {"defense": 2}}),
    # Frostpeak
    "frost": ("Rime Crystal", "ore", 240, 4, {"rarity": "rare", "desc": "Ice that has forgotten how to melt."}),
    "glass_frosted": ("Glacier Glass", "material", 200, 4, {"rarity": "rare"}),
    "ice_pike": ("Glacier Pike", "fish", 210, 4, {"rarity": "rare"}),
    "frost_sorbet": ("Frost Sorbet", "food", 480, 4, {"rarity": "epic", "heal": 6, "energy": 115}),
    "charm_frost": ("Rime Wyrm Charm", "equip", 2600, 5, {"rarity": "legendary", "slot": "charm", "stats": {"defense": 4, "speed": 1}, "desc": "One scale of the Rime Wyrm, frosted over for good."}),
    "ring_warmth": ("Hearth Ring", "equip", 1300, 4, {"rarity": "rare", "slot": "ring", "stats": {"defense": 1, "energy": 15}}),
    # Windward
    "storm_glass": ("Storm Glass", "ore", 300, 5, {"rarity": "epic", "desc": "Lightning, cooled into crystal."}),
    "storm_fluff": ("Storm Fluff", "material", 230, 5, {"rarity": "rare"}),
    "sky_fish": ("Skyfin", "fish", 240, 5, {"rarity": "rare"}),
    "cloud_souffle": ("Cloud Souffle", "food", 460, 5, {"rarity": "epic", "heal": 7, "energy": 130}),
    "storm_eye": ("Eye of the Storm", "treasure", 1200, 5, {"rarity": "legendary", "desc": "Perfectly calm inside. Listen closely and it hums."}),
    "charm_storm": ("Roc-feather Charm", "equip", 3000, 5, {"rarity": "legendary", "slot": "charm", "stats": {"speed": 2, "luck": 3}}),
    "charm_sky": ("Windward Charm", "equip", 1600, 4, {"rarity": "rare", "slot": "charm", "stats": {"speed": 1, "luck": 1}}),
    # Gilt City
    "lucky_coin": ("Lucky Coin", "treasure", 260, 5, {"rarity": "rare"}),
    "gambler_chip": ("Gilt Chip", "material", 180, 5, {"rarity": "uncommon", "desc": "A house chip from the Gilt casinos, gold-edged and heavy. Collectors pay well for them."}),
    "platinum": ("Platinum Ore", "ore", 320, 5, {"rarity": "epic"}),
    "pearl_necklace": ("Pearl Necklace", "treasure", 900, 5, {"rarity": "epic"}),
    "gold_bundle": ("Gold Leaf", "material", 280, 5, {"rarity": "rare"}),
    "sun_flan": ("Gilded Flan", "food", 480, 5, {"rarity": "epic", "heal": 7, "energy": 130}),
    "ring_platinum": ("Aurum Signet", "equip", 3200, 5, {"rarity": "legendary", "slot": "ring", "stats": {"damage": 3, "luck": 3}, "desc": "Madame Aurum's seal. Doors open for whoever wears it."}),
    "sparkling_wine": ("Sparkling Wine", "gift", 260, 4, {"rarity": "uncommon", "icon": "fine_wine", "desc": "A gold-foiled bottle from the Maison. A trade good: sold, gifted or shelved, never drunk."}),
    "ember_koi": ("Ember Koi", "fish", 260, 5, {"rarity": "rare", "desc": "Fire-gold scales. The Gilded Gardens' pond keeps it warm all winter."}),
    "golden_dice": ("Golden Dice", "equip", 1700, 5, {"rarity": "rare", "slot": "charm", "stats": {"luck": 3}}),
}

RECIPES = [  # kitchen: known once you've held every ingredient (Crafting.mark_known)
    {"id": "echo_pudding", "name": "Gloam Pudding", "need": {"wisp_spark": 1, "milk": 1, "honey": 1}, "give": "echo_pudding", "tier": 2},
    {"id": "sun_loaf", "name": "Sun Loaf", "need": {"dune_date": 2, "spice": 1, "wheat": 2}, "give": "sun_loaf", "tier": 3},
    {"id": "stew_beef", "name": "Stoker's Stew", "need": {"meat": 1, "potato": 2, "charcoal": 1}, "give": "stew_beef", "tier": 3},
    {"id": "frost_sorbet", "name": "Frost Sorbet", "need": {"frost": 1, "milk": 1, "edelweiss": 1}, "give": "frost_sorbet", "tier": 4},
    {"id": "cloud_souffle", "name": "Cloud Souffle", "need": {"storm_fluff": 1, "egg": 2, "milk": 1}, "give": "cloud_souffle", "tier": 4},
    {"id": "sun_flan", "name": "Gilded Flan", "need": {"gold_bundle": 1, "egg": 2, "milk": 1}, "give": "sun_flan", "tier": 4},
]

# ---------------------------------------------------------------- enemies
# new kind: (base kind for abilities/fallback art, tint, raw hp, tier, name, drops, extra)
# Balance (CONDUCT 4, c4_09): raw hp is BEFORE Enemy's home-tier scaling (NATIVE_HP x2.2..5),
# so trash stays ~8-12 raw at tier 2 up to ~20-25 at tier 5 (base_hp < 36: no elite music);
# region bosses are x0.55 of the first pass (they are region bosses, not finales).
# reward: trash ~0.3 x scaled hp, bosses BOSS_REWARD by tier. Drop chances are normalised in
# main() to ~3.4 crystals of expected drop value per raw hp (DROP_PER_HP).
# Kinds P5 draws (enemies/<kind>) are listed in OWN_ART: their tint only applies while the
# fallback sprite (the base kind) is used. extra "status" overrides the base kind's.
ENEMIES = {
    "gloom_moth": ("lantern_moth", "#c8a0ff", 10, 2, "Gloom Moth", [["wisp_thread", 0.35, 1], ["light_mote", 0.08, 1]], {}),
    "thorn_slime": ("mud_slime", "#b878e0", 9, 2, "Thorn Slime", [["slime_gel", 0.6, 1], ["wisp_thread", 0.15, 1]], {}),
    "glade_wisp": ("wisp", "#ffa8e8", 8, 2, "Glade Wisp", [["wisp_spark", 0.2, 1], ["wisp_thread", 0.3, 1]], {}),
    "gloom_spider": ("shard_spider", "#9878f0", 13, 3, "Gloom Spider", [["wisp_thread", 0.5, 2], ["amethyst", 0.06, 1]], {}),
    "thornmother": ("marsh_witch", "#c898ff", 85, 3, "The Thornmother", [["wisp_spark", 1.0, 3], ["luna_moth", 0.5, 1]], {"boss": True, "scale": 1.2}),
    "garden_boss": ("thug_gambler", "#c898ff", 85, 3, "Rosa Thorne", [["thug_cash", 1.0, 4], ["luna_moth", 0.5, 1]], {"boss": True, "scale": 1.15, "char": "gambler", "status": "poison"}),
    "dune_crab": ("rock_crab", "#f4d898", 13, 3, "Dune Crab", [["sunstone", 0.12, 1], ["shell", 0.3, 1]], {}),
    "sand_hound": ("ash_hound", "#e8c080", 15, 3, "Sand Hound", [["pelt", 0.4, 1], ["spice", 0.15, 1]], {}),
    "sun_moth": ("lantern_moth", "#ffc860", 12, 3, "Sun Moth", [["sun_scarab", 0.05, 1], ["light_mote", 0.1, 1]], {}),
    "glass_golem": ("quarry_golem", "#a8f0ff", 18, 3, "Glass Golem", [["glass", 0.8, 2], ["sunstone", 0.2, 1]], {}),
    "sun_colossus": ("ruin_warden", "#ffd868", 105, 4, "The Sun Colossus", [["sunstone", 1.0, 4], ["sun_scarab", 1.0, 1]], {"boss": True, "scale": 1.15}),
    "smuggler_king": ("thug_brute", "#e8b060", 105, 4, "Dune King Vasco", [["thug_cash", 1.0, 5], ["sun_scarab", 1.0, 1]], {"boss": True, "scale": 1.15, "char": "brute", "status": "burn"}),
    "rail_bot": ("rust_knight", "#c89060", 16, 3, "Rail Bot", [["chain_link", 0.4, 1], ["gear", 0.15, 1], ["oil", 0.25, 1]], {}),
    "coal_crawler": ("drip_crawler", "#8a8a8a", 13, 3, "Coal Crawler", [["charcoal", 0.6, 2], ["coal", 0.4, 1]], {}),
    "mill_runner": ("thug_cyber", "#c8a070", 13, 3, "Mill Runner", [["chain_link", 0.3, 1], ["thug_cash", 0.3, 1]], {"char": "cyber"}),
    "tunnel_bat": ("bat", "#6a6a7a", 14, 4, "Tunnel Bat", [["charcoal", 0.6, 1], ["coal", 0.5, 1]], {}),
    "baron_coalbrook": ("thug_enforcer", "", 115, 4, "Baron Coalbrook", [["thug_cash", 1.0, 6], ["chain_link", 1.0, 3]], {"boss": True, "char": "mg_coalbrook", "scale": 1.15}),
    "frost_wolf": ("hill_wolf", "#9cc8f0", 17, 4, "Frost Wolf", [["pelt", 0.5, 1], ["frost", 0.08, 1]], {}),
    "rime_golem": ("golem", "#acdcff", 22, 4, "Rime Golem", [["frost", 0.35, 1], ["stone", 1.0, 3], ["glass_frosted", 0.15, 1]], {}),
    "frost_spider": ("shard_spider", "#88c8f8", 18, 4, "Frost Spider", [["glass_frosted", 0.2, 1], ["silver", 0.2, 1]], {"status": "chill"}),
    "rime_wisp": ("ice_wisp", "#b8e8ff", 14, 4, "Rime Wisp", [["frost", 0.12, 1], ["glass_frosted", 0.15, 1]], {"status": "chill"}),
    "rime_wyrm": ("river_serpent", "", 125, 5, "The Rime Wyrm", [["frost", 1.0, 4], ["glass_frosted", 1.0, 2]], {"boss": True, "scale": 1.2, "art": "rime_wyrm", "status": "chill"}),
    "ice_hauler": ("thug_enforcer", "#a8d8ff", 125, 5, "Big Ike Frost", [["thug_cash", 1.0, 7], ["glass_frosted", 1.0, 2]], {"boss": True, "scale": 1.2, "char": "enforcer", "status": "chill"}),
    "finargle_drone": ("finargle", "#b8e0f0", 15, 3, "Finargle Drone", [["storm_fluff", 0.35, 1], ["finargle_fuzz", 0.3, 1]], {"art": "finargle"}),
    "storm_wisp": ("prism_wisp", "#9aa4ff", 20, 4, "Storm Wisp", [["storm_glass", 0.12, 1], ["wisp_spark", 0.2, 1]], {}),
    "cloud_knight": ("knight", "#c8d8f8", 24, 4, "Cloud Knight", [["storm_fluff", 0.3, 1], ["silver", 0.3, 1]], {}),
    "storm_roc": ("finargle_elder", "", 140, 5, "The Storm Roc", [["storm_glass", 1.0, 3], ["storm_fluff", 1.0, 3]], {"boss": True, "scale": 1.15, "art": "storm_roc"}),
    "gilt_guard": ("knight", "#ffe488", 24, 4, "Gilt Guard", [["gambler_chip", 0.5, 2], ["gold", 0.2, 1]], {}),
    "gilded_mirror": ("mirror", "#ffe070", 22, 4, "Gilded Mirror", [["gold_bundle", 0.15, 1], ["glass", 0.5, 1]], {}),
    "gilt_runner": ("thug_speedster", "#ffd870", 18, 4, "Gilt Runner", [["gambler_chip", 0.4, 1], ["thug_cash", 0.3, 1]], {"char": "speedster"}),
    "madame_aurum": ("thug_gambler", "", 140, 5, "Madame Aurum", [["gambler_chip", 1.0, 8], ["lucky_coin", 1.0, 2]], {"boss": True, "char": "mg_aurum", "scale": 1.15}),
}
# Kinds with their own sheet coming from CONDUCT 4 P5 (enemies/<kind>): tint only on the fallback.
# OWN_ART kinds whose sheet was sliced under another name (C5 P6: the gang bosses and the
# Gilt Guard were drawn as enemies/gang_boss_* and enemies/casino_guard).
ART_AS = {"garden_boss": "gang_boss_gloam", "smuggler_king": "gang_boss_desert", "ice_hauler": "gang_boss_frost",
          "gilt_guard": "casino_guard"}
OWN_ART = ["thornmother", "sun_colossus", "garden_boss", "smuggler_king", "ice_hauler", "dune_crab", "sand_hound", "sun_moth", "glass_golem", "gilt_guard", "rail_bot"]
BOSS_REWARD = {3: 1000, 4: 1800, 5: 2800}  # C8 P4: boss cash + drops + charm >= the area's chests
NATIVE_HP = [1.5, 2.2, 2.8, 3.5, 4.0, 5.0]  # mirrors Enemy.NATIVE_HP (rewards only)
DROP_PER_HP = 3.4
# Region bosses wait for the hub job (Moonpool after Liesl's, etc.): set per boss in main().
# Gangster-arc bosses for the both-arc regions (c4_09 #6): region.gd reads kind/who/text/title/
# win/after "_gangsters". All-ages: a scuffle, then they back down.
# Each mega boss door's own locked line (c12_18-12): the place, not "it", and fit for both
# arcs where the boss changes per arc. %s = the hub's job giver, %s = the hub.
HUB_THE = {"Grand Plaza"}
BOSS_LOCKED = {
    "gloam_moonpool": "The moonpool is still and black, and something among the roses is waiting. Help %s in %s first.",
    "desert_sunken_temple": "Sand has buried the temple door to the lintel. Help %s in %s, and the dunes will shift.",
    "iron_tunnels": "The private platform is roped off: NO PASSENGERS. Help %s in %s first, and you'll get a ticket.",
    "frost_summit": "The snowfield above is quiet. Too quiet. Help %s in %s before you climb.",
    "wind_starfall_garden": "The garden gate is held shut by a wind you can lean on. Help %s in %s first.",
    "gilt_vaults": "The vault doors are shut and the guards won't look at you. Help %s in %s first.",
}

# C12 P3: hub folk lines that follow the arc and progress (read by Talk.region_lines):
# lines_gangsters (gangster arc), after + after_flag (the hub's boss beaten; after_gangsters),
# done_lines + done_quest (their job handed in).
NPC_EXTRA = {
    "mg_liesl": {"lines_gangsters": ["Every lantern here has a moth, and every moth has a name. That one's Gerald.", "Rosa Thorne says the garden pays her rent. The garden has never paid anyone anything.", "Wisp Sparks keep a pudding light. Bring one back and cook something nice."],
                 "after_flag": "boss_gloam_moonpool", "after": ["The garden's breathing again. Gerald's taken to sleeping in the roses.", "Every lantern here has a moth, and every moth has a name. That one's Gerald."],
                 "after_gangsters": ["Nobody collects rent in Lanternfall now. Gerald's moved into the roses.", "Every lantern here has a moth, and every moth has a name. That one's Gerald."]},
    "mg_bramble": {"after_flag": "boss_gloam_moonpool", "after": ["The giant flower stopped sneezing. I sort of miss it.", "I'm not scared of the dark. The dark is scared of my lantern."]},
    "mg_rahim": {"done_quest": "mega_sunscorch_rahim", "done_lines": ["The lamps burn till dawn now. Caravans come in singing.", "Fifty years at this well. Never once seen it run dry."]},
    "mg_nadia": {"lines_gangsters": ["The Glass Canyon was a lake once. Lightning turned the sand to glass.", "Vasco sits on a crate of temple gold and calls himself a king. The scarabs were kings first.", "I'd give a lot for a scarab from the temple. For science."],
                 "done_quest": "mega_sunscorch_job", "done_lines": ["The scarab's a calendar. I've read three months of it. Next month has a festival.", "The Glass Canyon was a lake once. Lightning turned the sand to glass."],
                 "after_flag": "boss_desert_sunken_temple", "after": ["The Colossus is sleeping. Someone finally told it the war was over. You did."],
                 "after_gangsters": ["Vasco's crate sits empty. I'm reading the temple walls at last."]},
    "mg_hollis": {"after_flag": "boss_iron_tunnels", "after": ["Baron's gone and the trains run on time. Well. Mostly on time. On a time.", "My engine's the last one he never bought. She stays mine."]},
    "mg_dot": {"after_flag": "boss_iron_tunnels", "after": ["The Baron's table is free now. Nobody wants it. Too many bad tips in the wood."]},
    "mg_skip": {"after_flag": "boss_iron_tunnels", "after": ["Paper! Trains run again! Read all about it! ...I wrote that one myself."]},
    "mg_brannoch": {"lines_gangsters": ["Hearthhold's been here as long as the snow. Longer, some say.", "Rime Crystal won't melt in a forge. Freeze it into a sorbet instead.", "Big Ike hauls ice off the Summit and sells it back to us. Our own ice."],
                    "after_flag": "boss_frost_summit", "after": ["The Wyrm's snoring again. Hearthhold sleeps easier for it.", "Rime Crystal won't melt in a forge. Freeze it into a sorbet instead."],
                    "after_gangsters": ["Big Ike's sled tracks go down the mountain and don't come back. Good.", "Rime Crystal won't melt in a forge. Freeze it into a sorbet instead."]},
    "mg_tove": {"after_flag": "boss_frost_summit", "after": ["Brannoch says I can go to the Summit now. When I'm nine hundred and one."]},
    "mg_zephyr": {"after_flag": "boss_wind_starfall_garden", "after": ["The sky's ours again. Well, the Roc's, but it shares now.", "Storm Glass comes from where lightning lands. Don't be where lightning lands."]},
    "mg_nimbus": {"done_quest": "mega_windward_job", "done_lines": ["I bottled a breeze. It got out. It's somewhere in the gondola now, being smug.", "The Storm Shelf is calm again. The clouds have stopped flinching."]},
    "mg_pell": {"after_flag": "boss_gilt_vaults", "after": ["Madame's left the Vaults. The fountain water's free. I'm still not used to it."]},
    "mg_cass": {"after_flag": "boss_gilt_vaults", "after": ["Nobody's chasing me any more. It's honestly a bit dull."]},
    "mg_odette": {"after_flag": "boss_gilt_vaults", "after": ["I'm painting the statues to look like whoever I like now. Mostly pigeons."]},
}


GANG_BOSS = {
    "gloam_moonpool": {"kind_gangsters": "garden_boss", "who_gangsters": "Rosa Thorne", "title_gangsters": "Rosa Thorne",
        "text_gangsters": "A woman in a thorn-green coat steps out from behind the roses, pruning shears in one hand. 'This garden pays me rent,' says Rosa Thorne. 'Everyone in Gloamwood pays me rent.'",
        "win_gangsters": "Rosa snips one rose, tucks it in your collar and backs off into the mist. 'Fine. The garden's yours. Water it.' Nobody in Lanternfall pays her again.",
        "after_gangsters": "The roses grow wild again. Nobody collects rent here now."},
    "desert_sunken_temple": {"kind_gangsters": "smuggler_king", "who_gangsters": "Dune King Vasco", "title_gangsters": "Dune King Vasco",
        "text_gangsters": "A big man in a sun-bleached coat sits on a crate of temple gold in the doorway. 'Every caravan pays the Dune King,' says Vasco. 'You're a caravan now.'",
        "win_gangsters": "Vasco climbs off the crate, dusts himself down and laughs. 'Keep the door, then. The sand was getting in my boots anyway.' He leaves the temple to the scholars.",
        "after_gangsters": "Vasco's crate sits empty by the door. The caravans pass for free."},
    "frost_summit": {"kind_gangsters": "ice_hauler", "who_gangsters": "Big Ike Frost", "title_gangsters": "Big Ike Frost",
        "text_gangsters": "A sled the size of a truck, and on it a man the size of the sled. 'Nobody hauls ice off this mountain but Big Ike,' he says, cracking his knuckles.",
        "win_gangsters": "Big Ike sits down in the snow, out of breath. 'All right, all right. The summit's free. Hearthhold can have its ice.' He slides off down the mountain.",
        "after_gangsters": "Sled tracks lead down the mountain. Big Ike doesn't haul here any more."},
}

# ---------------------------------------------------------------- looks
AMB = {  # ambience beds per look (Ambience reads regions.json "amb")
    "gloam": {"crickets": -15.0, "crystal_hum": -26.0}, "desert": {"wind_soft": -13.0}, "rail": {"city_hum": -19.0, "machines": -24.0},
    "snow": {"wind_soft": -12.0}, "sky": {"wind_soft": -11.0}, "gilt": {"town_day": -20.0},
}
AREA_AMB = {"gloam_moonpool": {"marsh": -16.0, "frogs": -18.0}, "gloam_crystal_thicket": {"crystal_hum": -18.0}, "desert_mirage_post": {"campfire": -22.0, "town_day": -22.0},
            "desert_sunken_temple": {"cave": -20.0}, "iron_tunnels": {"cave": -14.0, "basement_drips": -18.0}, "iron_freight_yards": {"machines": -18.0},
            "frost_hearthhold": {"campfire": -20.0}, "frost_caverns": {"cave": -14.0, "crystal_hum": -22.0}, "frost_falls": {"river": -15.0},
            "frost_summit": {"wind_strong": -8.0}, "gilt_casino_row": {"neon_street": -15.0, "crowd": -20.0}, "gilt_vaults": {"cave": -18.0, "basement_drips": -22.0},
            "gilt_gardens": {"birds_day": -16.0}, "wind_starfall_garden": {"crystal_hum": -22.0}}
# Night beds (C6 c6_07): the casino street gets busier after dark, not quieter.
AREA_AMB_NIGHT = {"gilt_casino_row": {"crowd": -16.0, "neon_street": -13.0, "town_day": -24.0}}
# One-shot spots per look/area (Ambience reads regions.json "spots": [spot, min_s, max_s, dB, phase]).
SPOTS = {"gloam": [["owl", 25.0, 60.0, -16.0, "night"], ["insect", 14.0, 32.0, -18.0, ""]],
         "sky": [["gull", 18.0, 40.0, -20.0, "day"]], "snow": [], "desert": [], "rail": [], "gilt": []}
AREA_SPOTS = {"gloam_moonpool": [["frog", 8.0, 18.0, -16.0, "night"]], "frost_caverns": [], "iron_tunnels": [],
              "gilt_vaults": [], "desert_sunken_temple": []}

# Per-look scatter theme (WorldGen.theme: tree clumps, bushes, band) and border stands
# (GameMap border_trees). c4_03/c4_05/c4_04: gloam mushroom/crystal, frost snow pines, desert dry.
THEME = {
    "gloam": {"trees": ["props/mushroom_tree_a", "props/mushroom_tree_b", "props/crystal_tree_pink"], "bushes": False, "logs": False},
    "desert": {"trees": [], "bushes": False, "logs": False, "band": []},
    "snow": {"trees": ["pine_snow", "mid_snowpine", "mid_snowpine_b"], "bushes": False},
    "sky": {"trees": ["cloud_tree_a", "cloud_tree_b", "cloud_tree_c"], "bushes": False, "logs": False},
    "rail": {"trees": [], "bushes": False, "logs": False, "band": []},
    "gilt": {"trees": [], "bushes": False, "logs": False, "band": []},
}
BORDER_TREES = {
    "gloam": {"mid": ["props/mushroom_tree_a", "props/crystal_tree_pink"], "big": ["props/mushroom_tree_b", "props/crystal_tree"]},
    "snow": {"mid": ["mid_snowpine", "mid_snowpine_b"], "big": ["big_snowpine_a", "big_snowpine_b"]},
}
# Darkness per underground area (C5 tuned by eye; default 0.5).
LIGHT = {"desert_sunken_temple": 0.5, "iron_tunnels": 0.6, "frost_caverns": 0.55, "gilt_vaults": 0.55, "hollow_deeps": 0.6}
# Underground areas (c4_05 #6): "cave": true (Ambience/P4), no surface critters or mounds,
# cave scatter instead of the look's.
CAVE = {
    "frost_caverns": ["cave_stalag_l", "cave_stalag_m", "icicles_0", "icicles_1", "icicles_2", "crystal_tree_frost", "cave_mush_blue"],
    "iron_tunnels": ["crates_a", "crates_b", "oil_drums", "cave_stalag_l", "cave_stalag_m", "tyres"],
    "gilt_vaults": ["crates_a", "crates_b", "crates_c", "crates_pallet", "ore_gold_1", "ore_gold_2", "gold_fence_c"],
    "desert_sunken_temple": ["boulder2_s_a", "boulder2_s_b", "rock_s", "cave_stalag_m"],
}

LOOKS = {
    "gloam": {"ground": "grass", "ground_seam": "violet_moss", "path": "flagstone", "border": "trees", "backdrop": "night", "weather": "fireflies",
              "gen": {"region_props": ["gmush_blue", "gmush_purple", "gmush_red", "starflower_blue", "starflower_pink", "spiral_fern", "cave_mush_blue", "cave_mush_purple", "fd_mush_purple", "fd_mush_blue", "crystal_tree_pink"], "region_count": 34,
                      "critters": ["firefly", "butterfly_blue", "owl", "firefly"], "critter_count": 8}},
    "desert": {"ground": "grass", "ground_seam": "sand", "path": "cobble_warm", "border": "cliff", "season": "summer", "cliff_style": ["sand", "stair_wood"], "backdrop": "hills", "weather": "sun",
               "gen": {"region_props": ["dune_0", "dune_1", "dune_2", "dune_3", "dune_4", "dune_5", "dune_6", "dune_7", "dune_8", "dune_9", "dead_tree_s", "dead_tree_m", "boulder2_s_a", "boulder2_s_b", "rock_s"], "region_count": 40,
                       "critters": ["crow", "eagle"], "critter_count": 4}},
    "rail": {"ground": "grass", "ground_seam": "cobble_grey", "path": "city_pavement", "border": "cliff", "cliff_style": ["grass", "stair_iron"], "backdrop": "gritty", "weather": "clear",
             "gen": {"region_props": ["fire_barrel2", "oil_drums", "crates_a", "crates_b", "crates_c", "tyres", "pipe_t", "pipe_s", "dumpster", "cargo_yellow"], "region_count": 26,
                     "critters": ["crow", "sparrow"], "critter_count": 4}},
    "snow": {"ground": "grass", "ground_seam": "snow_packed", "path": "snow_trodden", "border": "trees", "season": "winter", "cliff_style": ["snow", "stair_snow"], "backdrop": "mountains", "weather": "snow",
             "gen": {"region_props": ["snowdrift_0", "snowdrift_1", "snowdrift_2", "snowdrift_3", "snowdrift_4", "snowdrift_5", "rock_snow_s", "rock_snow_m", "bush_snow", "bush_bare_snow", "stump_snow", "grass_tuft_winter"], "region_count": 36,
                     "critters": ["eagle", "rabbit"], "critter_count": 5}},
    "sky": {"ground": "grass", "ground_seam": "cloud_top", "path": "float_stone", "border": "none", "void_color": "eef0ff", "season": "summer", "backdrop": "hills", "weather": "wind", "pet": False,
            "gen": {"region_props": ["skydeco_0", "skydeco_1", "skydeco_2", "skydeco_3", "skydeco_4", "skydeco_5", "skydeco_6", "skydeco_7", "cloud_tree_a", "cloud_tree_b", "cloud_tree_c", "starflower_blue", "starflower_yellow"], "region_count": 34,
                    "critters": ["eagle", "butterfly_blue"], "critter_count": 5}},
    "gilt": {"ground": "grass", "ground_seam": "plaza_tiles", "path": "cobble_warm", "border": "cliff", "cliff_style": ["grass", "stair_iron"], "backdrop": "city", "weather": "clear",
             "gen": {"region_props": ["planter2_0", "planter2_1", "planter2_2", "planter2_3", "topiary_a", "topiary_b", "topiary_c", "hedge2_ball", "hedge2_pot", "flowerbed_pink", "flowerbed_yellow"], "region_count": 24,
                     "critters": ["sparrow"], "critter_count": 3}},
}

# ---------------------------------------------------------------- per-region content
# Each area: size, look overrides, music, links {to: (side, pos)}, structures, things, npcs, enemies...
# Structure: (group/name, w, h, near (x, y) or "center"/"spawn", solid=True, extra thing dict or None)
CONTENT = {}

# ---- Gloamwood (both arcs, opens at chapter 2) -------------------------------------
CONTENT["gloamwood"] = {
    "keeper": "Liesl", "keeper_sprite": "mg_liesl", "keeper_at": [-2, 0], "home_name": "the forest", "hub_name": "Lanternfall", "sfx": "sparkle",
    "hook": {"text": "Liesl the moth-keeper needs 6 flowers and 3 wild herbs to wake the fairy ring.", "items": [["flower", 6], ["wild_herb", 3]], "crystals": 60},
    "lines": {
        "locked": "The ring's asleep, love. It wakes when the valley's had a proper fright and come through it. Come back when the east meadow's quiet again.",
        "offer": ["Oh! You can see the ring? Most folk walk straight through it.", "It goes to Gloamwood: lanterns, moss, the kindest dark you'll ever meet. But the ring's gone sleepy.", "Bring me six flowers and three wild herbs, and I'll sing it awake. Deal?"],
        "yes": "Lovely. Any flowers will do. The ring isn't fussy, only hungry.",
        "wait": "Six flowers and three wild herbs, love. The ring's yawning but it isn't up yet.",
        "done": ["There we are. Hear that? Like a kettle just before it sings.", "Step into the middle and think of lanterns. You'll land in Lanternfall."],
        "travel": "The ring's humming. Off to Lanternfall?",
        "home": "Back to the forest, or somewhere further?",
        "wrong_arc": "The ring doesn't open for you.",
    },
    "mail": {"from": "Liesl", "text": "There's a fairy ring by the forest path that hums at dusk. I keep the moths that keep it. If you've got a minute and a few flowers, come and find me. - Liesl"},
}
# ---- Sunscorch (both, chapter 3) ---------------------------------------------------
CONTENT["sunscorch"] = {
    "keeper": "Sefa", "keeper_sprite": "mg_sefa", "keeper_at": [-2, 0], "home_name": "the beach", "hub_name": "Mirage Post", "sfx": "door",
    "hook": {"text": "Sefa the sand-sailor needs 4 bread and 3 rope before the caravan can cross.", "items": [["bread", 4], ["rope", 3]], "crystals": 90},
    "lines": {
        "locked": "The dune winds are wrong this season. We sail when the valley's had two good stories told about it. Not before.",
        "offer": ["You've got the look of someone who walks too far for fun.", "This wagon sails the sand to Mirage Post, the last well before the Sunscorch. Three days of dunes.", "I'm short on bread and rope. Four loaves, three coils, and you ride free. Yes?"],
        "yes": "Good. The desert eats rope and the crew eats bread. Bring both.",
        "wait": "Four bread, three rope. The wind's turning, friend.",
        "done": ["That'll see us across. Climb aboard, mind the water barrels.", "The sails go up at a word. Mirage Post, and then the whole Expanse."],
        "travel": "Sails are up. Mirage Post?",
        "home": "Back to the coast, or on somewhere else?",
        "wrong_arc": "The caravan isn't taking riders.",
    },
    "mail": {"from": "Sefa", "text": "A sand-sail caravan is beached past the dunes on your coast. We cross to the Sunscorch Expanse when we're stocked. Bring bread if you want a ride. - Sefa"},
}
# ---- Ironline (gangsters, chapter 3) -----------------------------------------------
CONTENT["ironline"] = {
    "keeper": "Conductor Hollis", "keeper_sprite": "mg_hollis", "keeper_at": [-2, 0], "home_name": "the plaza", "hub_name": "Junction City", "sfx": "door",
    "hook": {"text": "Conductor Hollis needs 10 coal and 3 iron bars to run the night train to Ironline.", "items": [["coal", 10], ["iron_bar", 3]], "crystals": 120},
    "lines": {
        "locked": "Night train's not running. Line's tied up in somebody's paperwork. When your name means something in this valley, come back and we'll talk tickets.",
        "offer": ["You're the one moving up in this town. I hear things in a ticket booth.", "There's a night train to Ironline. Rail town, coal smoke, a Baron who thinks he owns every track. He's squeezing the whole line dry.", "My engine's cold. Ten coal and three iron bars and she runs again. You in?"],
        "yes": "Coal for the firebox, iron for the couplings. I'll keep the booth lit.",
        "wait": "Ten coal, three iron bars. She won't run on promises.",
        "done": ["Hear that? That's a firebox catching. Best sound in the world.", "Ticket's on the house. Junction City, end of the line. Watch your pockets."],
        "travel": "All aboard for Junction City?",
        "home": "Back to town, or another stop?",
        "wrong_arc": "Booth's closed. Sign says 'Not today'.",
    },
    "mail": {"from": "Conductor Hollis", "text": "There's a ticket booth by the plaza nobody uses. I run the night train out of it, when I've got coal. Stop by. Could be work in it. - Hollis"},
}
# ---- Frostpeak (both, chapter 4) ----------------------------------------------------
CONTENT["frostpeak"] = {
    "keeper": "Brannoch", "keeper_sprite": "mg_brannoch", "keeper_at": [-2, 0], "home_name": "the mountain", "hub_name": "Hearthhold", "sfx": "door",
    "hook": {"text": "Brannoch the guide needs 4 wool and 6 coal before he'll take you up to Frostpeak.", "items": [["sheep_wool", 4], ["coal", 6]], "crystals": 150},
    "lines": {
        "locked": "Up there? Not yet. The Reach is no place for someone who hasn't seen a few hard winters of trouble. Come back later on in your story.",
        "offer": ["So you want to go higher than the mountain. Everybody does, once.", "Past the clouds there's Frostpeak Reach: Hearthhold, the glaciers, and the Summit, where something big sleeps in the ice.", "Four wool for your coat and six coal for the sled's warmer. Then I'll take you. Agreed?"],
        "yes": "Good. And eat something before you come back. Cold eats the hungry first.",
        "wait": "Four wool, six coal. I'm not hauling a frozen hero down the hill.",
        "done": ["There. Wrap up. Hold on to the rail, not to me.", "Hearthhold's at the top. Ask for the hot spring. Everyone does."],
        "travel": "Sled's waxed. Hearthhold?",
        "home": "Down the mountain, or somewhere else?",
        "wrong_arc": "Brannoch shakes his head.",
    },
    "mail": {"from": "Brannoch", "text": "There's a sled run off the mountain that goes up past the clouds to Frostpeak Reach. I guide it. If you're tough enough by now, come and ask. - Brannoch"},
}
# ---- Windward (penguins, chapter 5) ------------------------------------------------
CONTENT["windward"] = {
    "keeper": "Captain Zephyr", "keeper_sprite": "mg_zephyr", "keeper_at": [-2, 0], "home_name": "the meadow", "hub_name": "Breezehaven", "sfx": "sparkle",
    "hook": {"text": "Captain Zephyr needs 4 cloth and a Refined Crystal to patch the balloon and lift it.", "items": [["cloth", 4], ["crystal_refined", 1]], "crystals": 200},
    "lines": {
        "locked": "Too much weather up there for a passenger, I'm afraid. When the Star Crystal's nearly whole again the winds will calm. Then we fly.",
        "offer": ["Ahoy! Well, ahoy-ish. There's no water. Ahoy anyway!", "Above the sky islands, higher than the station even, are the Windward Isles. Breezehaven. Storm Shelf. And the Roc.", "My envelope's torn and the lift crystal's gone dim. Four cloth and one Refined Crystal and we sail. Aye?"],
        "yes": "Splendid! I'll be right here, being a penguin in a basket.",
        "wait": "Four cloth, one Refined Crystal. Penguins can't fly, you see. Balloons can.",
        "done": ["Patched! Glowing! Hold your hat.", "Breezehaven, here we come. Don't look down. Actually, do. It's lovely."],
        "travel": "Balloon's warm. Breezehaven?",
        "home": "Down to the meadow, or onward?",
        "wrong_arc": "The balloon's basket is full of penguin. There's no room.",
    },
    "mail": {"from": "Captain Zephyr", "text": "A balloon is tied up in the east meadow. It is captained by a penguin. That is me. I fly to the Windward Isles when I have a crew and a patch. - Capt. Zephyr"},
}
# ---- Gilt City (gangsters, chapter 5) ----------------------------------------------
CONTENT["giltcity"] = {
    "keeper": "Mister Pell", "keeper_sprite": "mg_pell", "keeper_at": [-2, 0], "home_name": "the farm", "hub_name": "Grand Plaza", "sfx": "door",
    "hook": {"text": "Mister Pell wants 12 Rolled Bills and a Gold Bar for the invitation to Gilt City.", "items": [["thug_cash", 12], ["gold_bar", 1]], "crystals": 250},
    "lines": {
        "locked": "Madame Aurum doesn't send the car for just anyone. Make a bigger name for yourself, then I'll come back with the engine running.",
        "offer": ["Nice place. Small. Honest. Gilt City is neither.", "Madame Aurum runs the casinos, the gardens and the Vaults under them. She's heard of you. She wants to meet.", "The invitation costs twelve Rolled Bills and one gold bar. Call it a cover charge. In?"],
        "yes": "Wonderful. I'll keep the leather seats warm.",
        "wait": "Twelve Rolled Bills and a gold bar. Madame is patient. I am less so.",
        "done": ["Pleasure doing business. Mind the step, it's real gold.", "Grand Plaza in an hour. Smile for the statues."],
        "travel": "Car's running. The Grand Plaza?",
        "home": "Back to the farm, or another address?",
        "wrong_arc": "The limo's windows stay up.",
    },
    "mail": {"from": "Mister Pell", "text": "Madame Aurum of Gilt City sends her regards and a car. It is parked by your farm. Do not keep it waiting. - P."},
}

# ---------------------------------------------------------------- areas
# links: {to_area: (side, position along that side)}. Mirror sides are matched automatically.
AREAS = {}

def A(aid, **kw): AREAS[aid] = kw

# Gloamwood ------------------------------------------------------------------
A("gloam_lanternfall", cols=42, rows=38, music="mega_gloam", look="gloam", links={"gloam_violet_glade": ("n", 19), "gloam_crystal_thicket": ("e", 15)},
  plaza="flagstone", weather="fireflies",
  structs=[("props/gl_mush_house_a", 3, 3, (9, 12)), ("props/gl_mush_house_b", 3, 3, (31, 11)), ("props/gl_mush_house_a", 3, 3, (9, 26)), ("props/gl_moth_shrine", 2, 2, (16, 9)),
           ("props/gl_lantern_posts", 2, 1, (25, 9)), ("props/mushroom_tree_b", 2, 2, (31, 27)), ("props/lanterns_pink", 3, 1, (24, 14)), ("props/lanterns_cyan", 3, 1, (13, 26)), ("props/giant_flower", 5, 2, (32, 19)),
           ("props/crystal_tree_pink", 1, 1, (6, 30)), ("props/gl_lantern_posts", 2, 1, (16, 23)), ("props/gl_lantern_posts", 2, 1, (26, 23))],
  shop=("props/plaza_04", 4, 2, (26, 18), {"who": "Fenn the lamp-seller", "greet": "Moth-light, glow-jam, things that hum. What'll it be?",
        "items": [["echo_pudding", 330], ["wisp_thread", 160], ["ring_glow", 1150], ["mana_potion", 80], ["potion", 40]]}),
  heal=("props/glow_pond", 4, 2, (14, 17), {"hp": 4, "energy": 60, "msg": "You dip your hands in the glowing pond. Everything aches a little less."}),
  gate=("nature/fairy_ring", 1, 1, "spawn"),
  notes=[("A: read the lantern board", "Lantern board: 'Violet Glade, north. Crystal Thicket, east. The Moonpool is past the glade, and the Thornmother sleeps under it. Please don't wake her. (Someone has written underneath: SOMEONE HAS TO.)'")],
  npcs=[("mg_liesl", "Liesl", "mg_liesl", ["Every lantern here has a moth, and every moth has a name. That one's Bartholomew.", "The Thornmother wasn't always thorns. Once she was the garden.", "Wisp Sparks keep a pudding light. Bring one back and cook something nice."]),
        ("mg_fenn", "Fenn", "mg_fenn", ["Glowmoss grows on the north side of everything. Even me, if I stand still.", "The Crystal Thicket chimes when the wind's right.", "Honey and wisp-light. That's the trick to a Gloam Pudding."]),
        ("mg_bramble", "Bramble", "mg_bramble", ["Did you see the giant flower? It sneezed on me.", "I'm not scared of the dark. The dark is scared of my lantern.", "The ghostfish in the Moonpool can see you even with their eyes closed."])],
  job={"giver": "mg_liesl", "text": "Liesl wants 5 Wisp Thread to mend the lantern nets.", "items": [["wisp_thread", 5]], "reward": {"animal": ["lantern_moth", "Liesl"], "animal_gang": ["peacock", "Liesl"], "gift_key": "mega:gloam_job", "crystals": 300, "item": ["luna_moth", 1], "friend": ["mg_liesl", 15]},
       "lines": {"offer": ["The moth nets are fraying and the moths keep wandering off to the Glade.", "Five Wisp Thread would mend them. The glade wisps leave it everywhere."], "yes": "You're a dear. Mind the slimes, they're sticky.", "done": ["Perfect. Bartholomew says thank you. Bartholomew is the moth."]}},
  intro=["The ring lets go of you in a hush of moth-wings. Lanterns everywhere, hung from mushrooms taller than houses, and the moss underfoot is violet and soft.", "This is Lanternfall. Somebody waves. Somebody is always waving here."])
A("gloam_violet_glade", cols=50, rows=44, music="mega_gloam", look="gloam", ground_seam="teal_moss_dense", links={"gloam_lanternfall": ("s", 23), "gloam_moonpool": ("n", 30)},
  water=[(4, 11)], hills=[(5, 33)], gen_extra={"clumps": 2},
  structs=[("props/mushroom_tree_a", 2, 2, (12, 12)), ("props/mushroom_tree_b", 2, 2, (38, 30)), ("props/giant_flower", 5, 2, (36, 12)), ("props/carnivore_plant", 1, 1, (14, 32))],
  things=[("loot", {"item": "wisp_spark", "n": 1, "every": 3, "hint": "A: a spark caught in a web", "sprite": "props/spiral_fern"}),
          ("loot", {"item": "luna_moth", "n": 1, "every": 6, "hint": "A: a moth asleep on a cap", "sprite": "props/gmush_purple"}),
          ("loot", {"item": "glowcap", "n": 2, "every": 3, "hint": "A: glowing caps in a ring", "sprite": "props/gmush_blue"}),
          ("note", {"hint": "A: read the carved stone", "text": "A stone, carved with roots: 'The Glade remembers every footstep. Walk kindly.'"}),
          ("mrock", {"ore": "amethyst", "hp": 3, "n": 1, "sprite": "props/mrock_moss"}), ("mrock", {"ore": "stone", "hp": 2, "n": 3, "sprite": "props/mrock_moss"})],
  enemies=[("gloom_moth", 3), ("thorn_slime", 3), ("glade_wisp", 2)],
  forage=[["wild_herb", 0.4], ["mushroom", 0.4], ["glowcap", 0.2], ["flower", 0.3], ["cave_bloom", 0.08]],
  intro=["Teal moss up to your ankles and flowers that open as you pass. The Glade breathes in when you breathe out."])
A("gloam_crystal_thicket", cols=48, rows=42, music="mega_gloam_thicket", music_fallback="hollow_heart", look="gloam", ground_seam="crystal_grass", links={"gloam_lanternfall": ("w", 18)},
  hills=[(34, 10)], water=[(36, 32)],
  structs=[("props/crystal_tree", 3, 2, (16, 12)), ("props/crystal_tree_pink", 1, 1, (28, 30)), ("props/grotto_crystal_a", 3, 2, (22, 33)), ("props/crystal_arch_a", 3, 2, (40, 20)),
           ("props/crystal_tree_sway", 1, 1, (10, 30))],
  things=[("mrock", {"ore": "amethyst", "hp": 3, "n": 1, "sprite": "props/ore_amethyst"}), ("mrock", {"ore": "amethyst", "hp": 3, "n": 1, "sprite": "props/ore_amethyst_1"}),
          ("mrock", {"ore": "shard", "hp": 4, "n": 2, "sprite": "props/ore_crystal"}), ("mrock", {"ore": "silver", "hp": 3, "n": 1, "sprite": "props/ore_silver"}),
          ("loot", {"item": "wisp_spark", "n": 2, "every": 4, "hint": "A: sparks humming in the crystals", "sprite": "props/ccrystal_2"}),
          ("note", {"hint": "A: listen to the chimes", "text": "The crystals ring a note when you touch them. Touch them in a row and it's almost a song. Almost the song Liesl hums."})],
  enemies=[("gloom_spider", 3), ("glade_wisp", 3), ("prism_wisp", 1)],
  forage=[["crystal_bloom", 0.15], ["glowcap", 0.3], ["wild_herb", 0.3], ["mushroom", 0.3]],
  intro=["Crystal grass, crystal trees, a wind that rings like a hundred tiny bells. Every step is a chord."])
A("gloam_moonpool", cols=48, rows=44, music="mega_gloam_moonpool", music_fallback="marsh", look="gloam", ground_seam="teal_moss_wet", weather="fog", links={"gloam_violet_glade": ("s", 20)},
  water=[(10, 26), (37, 28)], boss_at=(35, 20),
  structs=[("props/gl_thorn_rose", 1, 1, (27, 6)), ("props/grotto_pool_a", 4, 2, (32, 14)), ("props/mushroom_tree_b", 2, 2, (12, 12)), ("nature/hollow_tree", 6, 3, (36, 36)), ("props/vines_a", 2, 1, (16, 7)), ("props/vines_b", 2, 1, (31, 7))],
  things=[("loot", {"item": "luna_moth", "n": 1, "every": 7, "hint": "A: moths circling a stump", "sprite": "nature/stump2_1"}),
          ("heal", {"hp": 4, "energy": 50, "msg": "Moonlight off the water settles on you like a blanket.", "hint": "A: sit by the moonlit water"}),
          ("note", {"hint": "A: read the old sign", "text": "An old garden sign, nearly swallowed by thorns: 'MOTHER'S GARDEN. PLEASE DO NOT PICK THE ROSES. SHE WILL KNOW.'"})],
  boss={"kind": "thornmother", "who": "The Thornmother", "title": "The Thornmother", "reward": "charm_root",
        "text": "Thorns uncoil from the dark water and stand up into a shape like a woman made of brambles. 'Another one who walks on my garden,' she whispers.",
        "win": "The thorns loosen and fall away, and for a moment there is only an old gardener, very tired, smiling. Then there is only a rose by the water, and a bud closed tight.",
        "after": "A single rose grows by the water. It turns to follow you, gently."},
  enemies=[("gloom_spider", 2), ("thorn_slime", 3), ("gloom_moth", 2)], fish=["ghost_fish", "ghost_fish", "eel", "mooncarp"],
  forage=[["glowcap", 0.3], ["mushroom", 0.4], ["cave_bloom", 0.12], ["wild_herb", 0.3]],
  intro=["Mist on black water, and a moon in it that isn't the moon in the sky. Somewhere under the thorns something is sleeping very lightly."])

# Sunscorch --------------------------------------------------------------------
A("desert_mirage_post", cols=44, rows=40, music="mega_desert", look="desert", links={"desert_dune_sea": ("w", 18), "desert_glass_canyon": ("n", 21)},
  plaza="cobble_warm", water=[(9, 9)],
  structs=[("props/ds_house_a", 3, 3, (12, 25)), ("props/ds_house_b", 3, 3, (33, 27)), ("props/ds_bazaar_tent", 4, 3, (31, 12)), ("props/ds_sun_obelisk", 2, 2, (17, 9)),
           ("props/ds_house_a", 3, 3, (36, 20)), ("props/plaza_00", 4, 2, (14, 14)),
           ("props/plaza_03", 4, 2, (29, 20)), ("props/water_tower", 2, 2, (37, 31)), ("nature/palm", 1, 1, (6, 14)), ("nature/palm", 1, 1, (14, 6)),
           ("props/well_stone", 2, 1, (24, 12)), ("props/campsite", 2, 2, (8, 30))],
  shop=("props/plaza_07", 4, 2, (23, 26), {"who": "Old Rahim", "greet": "Shade, water, and whatever the caravans dropped off. Look around.",
        "items": [["sun_loaf", 300], ["spice", 160], ["dune_date", 60], ["greater_potion", 260], ["potion", 40]]}),
  heal=("props/well_stone", 2, 1, (18, 26), {"hp": 4, "energy": 60, "msg": "Cold well water, the best thing you've ever tasted."}),
  gate=("props/ds_sand_caravan", 2, 1, "spawn"),
  notes=[("A: read the caravan board", "Caravan board: 'DUNE SEA west. GLASS CANYON north, and past it the SUNKEN TEMPLE, where the Colossus guards the door. Water before you go. Water after you go.'")],
  npcs=[("mg_sefa", "Sefa", "mg_sefa", ["The dunes move a little every night. The map moves with them.", "Desert Saffron grows where the crabs dig. Funny, that.", "Sun Loaf keeps three days in a saddlebag. Learned that the hard way."]),
        ("mg_rahim", "Rahim", "mg_rahim", ["Fifty years at this well. Never once seen it run dry.", "The temple builders drew suns on everything. Even the spoons.", "Bring me sunstones and I'll pay you in shade. And something better than shade."]),
        ("mg_nadia", "Nadia", "mg_nadia", ["The Colossus isn't evil. It's a guard that nobody told the war was over.", "The Glass Canyon was a lake once. Lightning turned the sand to glass.", "I'd give a lot for a scarab from the temple. For science."])],
  extra_jobs=[{"id": "mega_sunscorch_rahim", "giver": "mg_rahim", "text": "Old Rahim wants 4 Sunstones to keep the well's night lamps warm.", "items": [["sunstone", 4]],
               "reward": {"crystals": 900, "item": ["sun_loaf", 2]},
               "lines": {"offer": ["Sunstones hold the day's heat all night. Four of them under the lamp-posts and the well stays lit till dawn.", "The Dune Sea and the Glass Canyon have them, if you can crack the rocks."],
                         "yes": "Good. Mind the hounds. They like shiny things too.", "done": ["Feel that? Warm as noon. The caravans will see the Post from three dunes off now."]}}],
  job={"giver": "mg_nadia", "text": "Nadia the scholar wants 2 Sun Scarabs from the Sunken Temple.", "items": [["sun_scarab", 2]], "reward": {"animal": ["ostrich", "Nadia"], "gift_key": "mega:desert_job", "crystals": 700, "item": ["greater_potion", 2], "friend": ["mg_nadia", 15]},
       "lines": {"offer": ["The Sunken Temple's full of carved scarabs. Gold ones. They're the key to the whole script.", "Two would do. I'd go myself but I'm a scholar, not a hero."], "yes": "Wonderful! Mind the glass golems. They don't mind you.", "done": ["Look at the wings! It's a calendar. The whole beetle is a calendar."]}},
  intro=["The caravan rolls in under a white sky. Tents, a stone well, palms leaning over a little green oasis, and beyond it nothing but gold in every direction.", "Mirage Post. The last well before the Sunscorch Expanse."])
A("desert_dune_sea", cols=54, rows=46, music="mega_desert", look="desert", weather="dust", links={"desert_mirage_post": ("e", 20)},
  hills=[(14, 12)], water=[(38, 36)],
  structs=[("props/broken_bus", 6, 2, (28, 10)), ("props/bk_dune_l", 6, 2, (40, 12)), ("props/skeleton", 1, 1, (24, 30)), ("props/rusted_car", 3, 1, (8, 24)), ("nature/dead_giant", 4, 2, (32, 32))],
  things=[("loot", {"item": "spice", "n": 2, "every": 2, "hint": "A: saffron in a hollow", "sprite": "nature/dune_9"}),
          ("loot", {"item": "dune_date", "n": 3, "every": 2, "hint": "A: a date palm's drop", "sprite": "nature/palm"}),
          ("loot", {"item": "old_coin", "n": 2, "every": 4, "hint": "A: something glints in the sand", "sprite": "nature/dune_6"}),
          ("mrock", {"ore": "sunstone", "hp": 3, "n": 1, "sprite": "props/boulder2_m_a"}), ("mrock", {"ore": "stone", "hp": 2, "n": 3, "sprite": "props/boulder2_s_a"}),
          ("note", {"hint": "A: read the bleached sign", "text": "A sign, sand-scoured almost blank: '...ASIS 2 DAYS. DO NOT FOLLOW THE SINGING.'"})],
  enemies=[("dune_crab", 3), ("sand_hound", 2), ("sun_moth", 2)], fish=["sun_trout", "carp", "catfish"],
  forage=[["spice", 0.3], ["dune_date", 0.4], ["fiber", 0.3], ["flower", 0.1]],
  intro=["Dunes like frozen waves, as far as you can see. Somewhere out here a bus is half buried, and something under the sand is singing."])
A("desert_glass_canyon", cols=50, rows=44, music="mega_desert_canyon", music_fallback="quarry", look="desert", ground_seam="cave_earth_floor", links={"desert_mirage_post": ("s", 22), "desert_sunken_temple": ("n", 22)},
  hills=[(10, 14), (38, 12)], feature=("grass_dry", [(12, 34, 5)]),
  structs=[("props/stone_head", 6, 3, (12, 26)), ("props/toppled_statue", 4, 2, (34, 22)), ("props/standing_stones", 5, 2, (32, 34))],
  things=[("mrock", {"ore": "sunstone", "hp": 3, "n": 1, "sprite": "props/boulder2_m_b"}), ("mrock", {"ore": "sunstone", "hp": 3, "n": 1, "sprite": "props/boulder2_l_a"}),
          ("mrock", {"ore": "gold", "hp": 4, "n": 1, "sprite": "props/ore_gold"}), ("mrock", {"ore": "copper", "hp": 2, "n": 2, "sprite": "props/ore_copper"}),
          ("loot", {"item": "glass", "n": 3, "every": 2, "hint": "A: lightning glass in the sand", "sprite": "props/crystal_rock"}),
          ("heal", {"hp": 3, "energy": 40, "msg": "A little spring in the rock, cold and clear.", "hint": "A: a spring in the rock"}),
          ("note", {"hint": "A: read the carving", "text": "Carved over the canyon path: a sun, a giant with a spear, and rows of tiny people bowing. Someone has added a moustache to the giant."})],
  enemies=[("glass_golem", 2), ("dune_crab", 2), ("sand_hound", 2)],
  forage=[["spice", 0.2], ["fiber", 0.4], ["dune_date", 0.2]],
  intro=["Red rock walls and a floor of sand fused into glass in long, lightning-shaped streaks. It crunches. The golems here are made of it."])
A("desert_sunken_temple", cols=46, rows=42, music="mega_desert_temple", music_fallback="ruins", look="desert", ground_seam="pale_stone", path="flagstone", border="cliff", links={"desert_glass_canyon": ("s", 20)},
  boss_at=(21, 9), plaza=None,
  structs=[("props/ds_sun_obelisk", 2, 2, (16, 9)), ("props/ds_sun_obelisk", 2, 2, (28, 9)), ("props/r_ruins_45", 4, 3, (13, 12)), ("props/r_ruins_46", 4, 3, (31, 12)), ("props/r_ruins_14", 5, 2, (12, 28)), ("props/r_ruins_33", 7, 3, (32, 30)),
           ("props/r_ruins_41", 1, 1, (17, 7)), ("props/r_ruins_42", 1, 1, (27, 7)), ("props/r_ruins_24", 2, 1, (8, 20)), ("props/r_ruins_19", 2, 1, (38, 20)),
           ("props/r_ruins_01", 1, 1, (16, 20)), ("props/r_ruins_02", 1, 1, (28, 20)), ("props/r_ruins_07", 2, 1, (22, 34))],
  things=[("loot", {"item": "sun_scarab", "n": 1, "every": 5, "hint": "A: a gold scarab in a niche", "sprite": "props/r_ruins_48"}),
          ("loot", {"item": "gold", "n": 2, "every": 3, "hint": "A: an offering bowl", "sprite": "props/r_ruins_51"}),
          ("mrock", {"ore": "sunstone", "hp": 3, "n": 2, "sprite": "props/r_ruins_06"}),
          ("note", {"hint": "A: read the tablet", "text": "A tablet: 'THE SUN SET ITS GUARD AT THE DOOR AND SAID: KEEP THEM OUT UNTIL I RETURN. THE SUN DID NOT RETURN.'"}),
          ("note", {"hint": "A: read the rune stone", "text": "Runes glow faintly as you pass. They spell, as far as you can tell, 'WELCOME'. Then, smaller: 'MOSTLY'."})],
  boss={"kind": "sun_colossus", "who": "The Sun Colossus", "title": "The Sun Colossus", "reward": "charm_sun",
        "text": "Sand pours off a giant of gold stone as it stands. Its spear comes down across the doorway. 'NONE PASS UNTIL THE SUN RETURNS.'",
        "win": "The Colossus kneels, slowly, and the light behind its eyes turns from white to warm. 'The sun... has returned,' it says, looking at you. It sits down to rest for the first time in a thousand years.",
        "after": "The Colossus sits by the door, at peace, sun on its face."},
  enemies=[("ruin_guardian", 2), ("sun_moth", 3), ("glass_golem", 1)],
  forage=[["spice", 0.2], ["fiber", 0.3]],
  intro=["Half buried in sand, a temple of pale stone. Braziers still burn at the far door, and something enormous is sitting very still in front of it."])

# Ironline ----------------------------------------------------------------------
A("iron_junction", cols=44, rows=40, music="mega_iron", look="rail", links={"iron_freight_yards": ("w", 17), "iron_mill_district": ("n", 21)},
  plaza="city_pavement", ground_seam="brick_herring",
  structs=[("buildings/station", 13, 4, (14, 12)), ("props/train_engine", 7, 2, (31, 14)), ("buildings/warehouse_b", 10, 5, (32, 30)), ("props/water_tower", 2, 2, (8, 29)),
           ("props/floodlight_on", 0, 1, (17, 24)), ("props/floodlight_on", 0, 1, (27, 24)), ("props/bus_stop", 4, 2, (12, 25)), ("props/payphone", 0, 1, (27, 11)), ("props/ir_signal_tower", 1, 2, (37, 8)), ("props/ir_coal_hopper", 2, 2, (7, 20))],
  shop=("props/plaza_70", 4, 2, (24, 27), {"who": "Dot's Dining Car", "greet": "Coffee's hot, stew's hotter. Cash only, sugar.",
        "items": [["stew_beef", 290], ["coffee", 90], ["ring_steel", 1200], ["greater_potion", 260], ["potion", 40]]}),
  heal=("props/bench2_iron_a", 2, 1, (17, 27), {"hp": 4, "energy": 60, "msg": "You sit a while and watch the trains not come. It's nicer than it sounds."}),
  gate=("props/ticket_booth", 3, 1, "spawn"),
  notes=[("A: read the timetable", "Timetable, all trains CANCELLED by order of BARON COALBROOK. Underneath, in chalk: 'FREIGHT YARDS WEST. MILL NORTH. THE BARON HIDES IN THE TUNNELS PAST THE MILL. SOMEBODY DO SOMETHING.'")],
  npcs=[("mg_hollis", "Hollis", "mg_hollis", ["Every rail in this valley runs through Junction. That's why the Baron wants it.", "Rail Chain, Engine Oil, Tin. Junction runs on all three.", "My engine's the last one he hasn't bought. She stays mine."]),
        ("mg_dot", "Dot", "mg_dot", ["You want the stew? Everybody wants the stew.", "Charcoal from the firebox, that's the secret. Smoky.", "The Baron eats here. Tips terribly."]),
        ("mg_skip", "Skip", "mg_skip", ["Paper! Baron cancels all trains! Read all about it!", "I sold a paper to a rail bot once. It tried to eat it.", "The tunnels go under the whole city. I've seen like, half."])],
  job={"giver": "mg_hollis", "text": "Hollis needs 4 Rail Chain and 2 Engine Oil to fix the yard switch.", "items": [["chain_link", 4], ["oil", 2]], "reward": {"crystals": 650, "item": ["gear", 2], "friend": ["mg_hollis", 15]},
       "lines": {"offer": ["The Baron's bots wrecked the yard switch. No switch, no trains, no Junction.", "Four Rail Chain and two cans of Engine Oil. The bots carry both."], "yes": "Good. Hit 'em where the rivets are.", "done": ["She switches! Hear that clunk? That's freedom, that is."]}},
  intro=["The night train screeches into Junction City under a sky the colour of an old penny. Coal smoke, brick, and every timetable on the station wall says CANCELLED.", "Somebody here runs the rails. Somebody here is about to have a very bad week."])
A("iron_freight_yards", cols=54, rows=44, music="mega_iron", look="rail", ground_seam="ballast", path="dock_concrete", links={"iron_junction": ("e", 18)},
  feature=("curb_road", [(14, 12, 5), (40, 34, 5)]),
  structs=[("props/ir_coal_hopper", 2, 2, (20, 12)), ("props/ir_signal_tower", 1, 2, (46, 30)), ("props/crane", 2, 2, (12, 30)), ("props/container_red", 3, 1, (30, 10)), ("props/container_blue", 3, 1, (36, 12)), ("props/cargo_yellow", 2, 1, (20, 32)),
           ("props/forklift", 2, 1, (40, 26)), ("props/container_green", 3, 1, (8, 12)), ("props/train_car", 5, 2, (28, 32)), ("props/water_tower", 2, 2, (44, 9))],
  things=[("loot", {"item": "oil", "n": 2, "every": 2, "hint": "A: a leaky oil drum", "sprite": "props/oil_drums"}),
          ("loot", {"item": "chain_link", "n": 2, "every": 3, "hint": "A: chain on a broken coupling", "sprite": "props/crates_pallet"}),
          ("loot", {"item": "charcoal", "n": 3, "every": 2, "hint": "A: a tipped coal hopper", "sprite": "props/cargo_yellow"}),
          ("mrock", {"ore": "tin", "hp": 3, "n": 2, "sprite": "props/boulder2_m_a"}), ("mrock", {"ore": "iron", "hp": 3, "n": 2, "sprite": "props/ore_iron"}),
          ("note", {"hint": "A: read the manifest", "text": "A shipping manifest: '400 crates TIN to BARON. 300 crates COAL to BARON. 1 crate TEDDY BEARS to BARON (personal).'"})],
  enemies=[("rail_bot", 3), ("thug_brute", 2), ("coal_crawler", 2)],
  forage=[["fiber", 0.4], ["wild_herb", 0.2]],
  intro=["Rows of rusting freight cars, cranes like skeletons, and rail bots patrolling with lanterns. All of it stamped COALBROOK."])
A("iron_mill_district", cols=50, rows=44, music="mega_iron", look="rail", ground_seam="brick_herring", path="cobble_warm", links={"iron_junction": ("s", 23), "iron_tunnels": ("n", 24)},
  structs=[("buildings/warehouse_c", 6, 4, (12, 12)), ("buildings/silo", 4, 5, (36, 13)), ("buildings/grain_elevator", 11, 5, (34, 33)), ("props/fire_barrel2", 1, 1, (14, 30)),
           ("props/radio_tower_b", 1, 1, (8, 22)), ("props/forklift", 2, 1, (16, 22))],
  things=[("loot", {"item": "charcoal", "n": 2, "every": 2, "hint": "A: a cooling firebox", "sprite": "props/fire_barrel2"}),
          ("loot", {"item": "gear", "n": 1, "every": 4, "hint": "A: a broken press", "sprite": "props/crates_b"}),
          ("mrock", {"ore": "tin", "hp": 3, "n": 2, "sprite": "props/boulder2_s_b"}), ("mrock", {"ore": "coal", "hp": 2, "n": 3, "sprite": "props/ore_coal"}),
          ("heal", {"hp": 3, "energy": 40, "msg": "A fire barrel and a crate to sit on. Warm hands, warm heart.", "hint": "A: warm up at the barrel"}),
          ("note", {"hint": "A: read the poster", "text": "A poster: 'WORK HARDER. THE BARON IS WATCHING.' Someone has drawn him a very small hat."})],
  enemies=[("mill_runner", 2), ("thug_flame", 2), ("rail_bot", 2)],
  forage=[["fiber", 0.4]],
  intro=["Brick mills with every window lit, chimneys coughing, and a great silo with the Baron's crest painted on it twice as tall as a house."])
A("iron_tunnels", cols=46, rows=42, music="underground", look="rail", ground_seam="cave_stone_floor", path="ballast", border="cliff", backdrop="night", weather="clear",
  links={"iron_mill_district": ("s", 21)}, boss_at=(21, 9),
  structs=[("props/ir_baron_car", 7, 2, (27, 7)), ("props/cave_rail", 2, 1, (12, 14)), ("props/cave_rail_bend", 2, 1, (33, 14)), ("props/cave_cart", 1, 1, (14, 28)), ("props/mine_dark_lamp_0", 0, 1, (17, 7)),
           ("props/mine_dark_lamp_1", 0, 1, (26, 7)), ("props/cave_stalag_l", 1, 1, (8, 22)), ("props/cave_stalag_m", 1, 1, (38, 24)), ("props/cave_ore_crate", 1, 1, (32, 30))],
  things=[("mrock", {"ore": "tin", "hp": 3, "n": 2, "sprite": "props/mrock_stone_0"}), ("mrock", {"ore": "gold", "hp": 4, "n": 1, "sprite": "props/ore_gold_1"}),
          ("mrock", {"ore": "coal", "hp": 2, "n": 3, "sprite": "props/ore_coal_1"}),
          ("loot", {"item": "thug_cash", "n": 3, "every": 3, "hint": "A: the Baron's petty cash box", "sprite": "props/cave_ore_crate"}),
          ("note", {"hint": "A: read the Baron's ledger", "text": "The Baron's ledger: every station, every rail, every penny of Ironline, and in the margin, 'buy the moon??'"})],
  boss={"kind": "baron_coalbrook", "who": "Baron Coalbrook", "title": "Baron Coalbrook", "reward": "pocket_watch",
        "text": "A man in a coal-black coat steps off a private rail car and checks a gold pocket watch. 'You're eight minutes late for your own defeat.'",
        "win": "The Baron sits down hard on his own rail car. 'Fine. FINE. The trains can run.' He hands over the watch. 'It's eight minutes fast. It always was.'",
        "after": "The Baron's rail car, empty. A timetable on the seat reads: ALL TRAINS RUNNING."},
  enemies=[("coal_crawler", 3), ("rail_bot", 2), ("tunnel_bat", 2)],
  forage=[["mushroom", 0.3], ["fiber", 0.3]],
  intro=["Under the mills the old rail tunnels run in the dark, lamps flickering along the walls. Far ahead, a private rail car is parked with all its lights on."])

# Frostpeak ---------------------------------------------------------------------
A("frost_hearthhold", cols=44, rows=40, music="mega_frost", look="snow", path="snow_paving", links={"frost_glacier": ("n", 21), "frost_caverns": ("w", 17), "frost_falls": ("e", 17)},
  plaza="snow_paving",  # paths paved too (C2): trodden snow over the plaza cut it into four grey islands
  structs=[("props/fr_lodge", 3, 3, (12, 12)), ("props/fr_cabin", 2, 2, (31, 12)), ("props/fr_hearth", 3, 2, (22, 9)), ("props/fr_bell_tower", 2, 3, (37, 20)), ("props/fr_lodge", 3, 3, (36, 30)), ("props/fishing_hut_stilts_winter", 5, 3, (32, 29)), ("props/crystal_tree_frost", 2, 2, (8, 26)),
           ("nature/lamp_snow", 0, 1, (17, 24)), ("nature/lamp_snow", 0, 1, (27, 24)), ("nature/big_snowpine_a", 1, 2, (6, 9)), ("nature/big_snowpine_b", 1, 2, (38, 9)), ("props/fr_cabin", 2, 2, (8, 18))],
  shop=("props/ice_stall_open", 7, 2, (21, 28), {"who": "Ingrid's Stall", "greet": "Warm things for cold people. Everything's knitted, even the sorbet. Not really.",
        "items": [["frost_sorbet", 580], ["ring_warmth", 1600], ["hot_cocoa", 200], ["greater_potion", 260], ["potion", 40]]}),
  heal=("props/hot_spring", 2, 2, (12, 27), {"hp": 5, "energy": 80, "msg": "You sink into the hot spring up to your chin. Somewhere a snowflake lands on your nose and gives up."}),
  gate=("props/fr_sled_station", 2, 2, "spawn"),
  notes=[("A: read the guide's board", "Guide's board: 'GLACIER FIELDS north, then the SUMMIT. RIME CAVERNS west. FROZEN FALLS east, good fishing. Something big sleeps on the Summit. Don't sing near it.'")],
  npcs=[("mg_brannoch", "Brannoch", "mg_brannoch", ["Hearthhold's been here as long as the snow. Longer, some say.", "Rime Crystal won't melt in a forge. Freeze it into a sorbet instead.", "The Wyrm on the Summit wakes every hundred years. Lucky you."]),
        ("mg_ingrid", "Ingrid", "mg_ingrid", ["Edelweiss, milk and a Rime Crystal. That's a sorbet that never melts.", "My grandmother knitted the first igloo. Don't ask how.", "Glacier Glass makes the best windows. You can see next week through it."]),
        ("mg_tove", "Tove", "mg_tove", ["I named the pike in the falls. They're all called Pike.", "The caverns sing when the wind goes through. I sing back.", "Brannoch says I can go to the Summit when I'm nine hundred."])],
  job={"giver": "mg_ingrid", "text": "Ingrid wants 3 Rime Crystals and 2 Glacier Glass for her new window.", "items": [["frost", 3], ["glass_frosted", 2]], "reward": {"animal": ["snow_yak", "Ingrid"], "gift_key": "mega:frost_job", "crystals": 1100, "max_energy": 10, "friend": ["mg_ingrid", 15]},
       "lines": {"offer": ["I want a window that never frosts over. Rime Crystal for the frame, Glacier Glass for the pane.", "Three crystals and two glass. The Caverns and the Glacier have both."], "yes": "Wrap up warm. The golems don't feel the cold, but you do.", "done": ["Look at that view. I can see the Summit from my stove! Here, something for your trouble."]}},
  intro=["The sled tips you out in front of a village of snow-domed houses with smoke curling from every chimney. Lanterns on poles, a steaming spring, and the peaks all round like a crown.", "Hearthhold. Even the snow seems friendly here."])
A("frost_glacier", cols=52, rows=44, music="mega_frost", look="snow", ground_seam="frost_grass", links={"frost_hearthhold": ("s", 24), "frost_summit": ("n", 30)},
  hills=[(10, 12), (40, 30)], feature=("cave_ice", [(36, 12, 5), (12, 32, 4)]), gen_extra={"clumps": 2},
  structs=[("props/crystal_tree_frost", 2, 2, (20, 30)), ("props/ice_crystal_lit", 3, 3, (30, 22)), ("nature/big_snowpine_a", 1, 2, (8, 24))],
  things=[("mrock", {"ore": "frost", "hp": 4, "n": 1, "sprite": "props/mrock_ice_0"}), ("mrock", {"ore": "frost", "hp": 4, "n": 1, "sprite": "props/mrock_ice_1"}),
          ("mrock", {"ore": "silver", "hp": 3, "n": 2, "sprite": "props/ore_silver_1"}),
          ("loot", {"item": "glass_frosted", "n": 1, "every": 3, "hint": "A: a sheet of clear ice", "sprite": "props/icicles_1"}),
          ("loot", {"item": "edelweiss", "n": 2, "every": 2, "hint": "A: edelweiss in the lee of a rock", "sprite": "nature/rock_snow_m"}),
          ("note", {"hint": "A: read the cairn", "text": "A cairn with a plaque: 'FOR THE CLIMBERS WHO TURNED BACK. YOU WERE RIGHT.'"})],
  enemies=[("frost_wolf", 3), ("rime_wisp", 2), ("rime_golem", 1)],
  forage=[["edelweiss", 0.4], ["wild_herb", 0.2], ["fiber", 0.2]],
  intro=["White in every direction, blue in the cracks. The glacier groans under you like a very old dog getting comfortable."])
A("frost_caverns", cols=46, rows=42, music="mega_frost_caverns", music_fallback="mine_deep", look="snow", ground_seam="cave_ice_floor", path="snow_paving", border="cliff", weather="clear", backdrop="night", links={"frost_hearthhold": ("e", 18)},
  feature=("cave_ice", [(14, 12, 4), (30, 32, 4)]),
  structs=[("props/cave_stalag_l", 1, 1, (12, 22)), ("props/cave_stalag_m", 1, 1, (34, 12)), ("props/ice_crystal_lit", 3, 3, (24, 9)), ("props/crystal_tree_frost", 2, 2, (8, 32)),
           ("props/icicles_0", 3, 1, (33, 26)), ("props/cave_stalactite_a", 1, 1, (20, 33))],
  things=[("mrock", {"ore": "frost", "hp": 4, "n": 1, "sprite": "props/mrock_ice_0"}), ("mrock", {"ore": "frost", "hp": 4, "n": 2, "sprite": "props/mrock_ice_1"}),
          ("mrock", {"ore": "sapphire", "hp": 4, "n": 1, "sprite": "props/ore_crystal_1"}), ("mrock", {"ore": "silver", "hp": 3, "n": 2, "sprite": "props/ore_silver"}),
          ("loot", {"item": "glass_frosted", "n": 2, "every": 3, "hint": "A: a frozen pane in the wall", "sprite": "props/icicles_2"}),
          ("note", {"hint": "A: read the frozen journal", "text": "A journal frozen into the ice, readable through it: 'The caverns hum the same note as the Summit. I think the Wyrm is snoring.'"})],
  enemies=[("frost_spider", 3), ("rime_golem", 2), ("rime_wisp", 2)],
  forage=[["mushroom", 0.3], ["cave_bloom", 0.1]],
  intro=["Blue ice overhead, blue ice underfoot, and your breath hangs in the air like it's afraid to leave. The walls hum one long, low note."])
A("frost_falls", cols=48, rows=42, music="mega_frost", look="snow", ground_seam="snow_smooth", links={"frost_hearthhold": ("w", 17)},
  water=[(30, 24), (12, 30)],
  structs=[("props/waterfall_pool", 5, 2, (32, 13)), ("props/fishing_hut_stilts_winter", 5, 3, (14, 13)), ("nature/big_snowpine_b", 1, 2, (8, 22))],
  things=[("loot", {"item": "ice_pike", "n": 1, "every": 4, "hint": "A: a pike frozen in the edge ice", "sprite": "props/icicles_1"}),
          ("heal", {"hp": 4, "energy": 50, "msg": "The falls roar under the ice. Somehow it's peaceful.", "hint": "A: watch the frozen falls"}),
          ("mrock", {"ore": "frost", "hp": 4, "n": 1, "sprite": "props/mrock_ice_1"}),
          ("note", {"hint": "A: read the fishing log", "text": "Fishing log, Tove (age 8): 'Monday: Pike. Tuesday: Pike. Wednesday: a different Pike.'"})],
  enemies=[("frost_wolf", 2), ("rime_wisp", 2), ("rime_golem", 1)], fish=["ice_pike", "ice_pike", "trout", "salmon"],
  forage=[["edelweiss", 0.3], ["wild_herb", 0.3]],
  intro=["A waterfall frozen halfway down, still pouring under its skin of ice. The pools below are open and dark, and full of pike."])
A("frost_summit", cols=44, rows=40, music="mega_frost_summit", music_fallback="mega_frost", look="snow", ground_seam="snow_smooth", weather="blizzard", links={"frost_glacier": ("s", 20)}, boss_at=(20, 8),
  hills=[(8, 22)],
  structs=[("props/ice_crystal_lit", 3, 3, (11, 9)), ("props/ice_crystal_lit", 3, 3, (30, 9)), ("props/crystal_tree_frost", 2, 2, (14, 32)), ("props/snowdrift_3", 2, 1, (30, 32))],
  things=[("mrock", {"ore": "frost", "hp": 4, "n": 2, "sprite": "props/mrock_ice_0"}),
          ("loot", {"item": "glass_frosted", "n": 2, "every": 4, "hint": "A: wind-polished ice", "sprite": "props/icicles_2"}),
          ("note", {"hint": "A: read the summit flag", "text": "A ragged flag on a pole. Under it, a tin with notes from everyone who made it. The newest says: 'SHHH. IT'S SLEEPING.'"}),
          ("creature", {"species": "frost_wyrmling", "species_gang": "tortoise", "flag": "boss_frost_summit", "key": "mega:frost_wyrmling", "giver": "Ingrid", "hint": "A: a nest in the snow",
                        "wait": "A hollow in the snow, warm somehow. Whatever owns it is up on the summit, and not in the mood.",
                        "line": "Something small and sleepy blinks up at you from the snow hollow, and follows you all the way down. Ingrid will bring it to your farm.",
                        "line_gang": "An old tortoise sits in the warm hollow, frost on its shell, very patient. It follows you, slowly. Ingrid will truck it to your place."})],
  boss={"kind": "rime_wyrm", "who": "The Rime Wyrm", "title": "The Rime Wyrm", "reward": "charm_frost",
        "text": "The snowfield shrugs. A head as long as a sled lifts out of the ice, frost pouring from its jaws, and two pale eyes open. It is not pleased to be awake.",
        "win": "The Wyrm sighs a long, cold sigh and curls back down into the snow. Before it sleeps it drops one scale at your feet, as if to say: fine. You win. Now let me sleep.",
        "after": "The snow over the Wyrm rises and falls, slowly. It's snoring."},
  enemies=[("frost_wolf", 2), ("frost_spider", 2), ("rime_wisp", 2)],
  forage=[["edelweiss", 0.4]],
  intro=["The top of the world. Wind like knives, sky like glass, and in the middle of the snowfield a long shape under the snow, breathing."])

# Windward ------------------------------------------------------------------------
A("wind_breezehaven", cols=44, rows=40, music="mega_wind", look="sky", links={"wind_sunrise_shelf": ("w", 17), "wind_storm_shelf": ("n", 21)},
  plaza="float_stone",
  structs=[("props/sky_temple", 9, 3, (14, 11)), ("props/windmill3", 3, 3, (33, 12)), ("props/wi_prop_cottage", 2, 2, (8, 26)), ("props/wi_prop_cottage", 2, 2, (34, 21)),
           ("props/wi_wind_shrine", 2, 2, (27, 9)), ("nature/cloud_tree_a", 2, 2, (36, 26)),
           ("nature/cloud_tree_b", 2, 2, (30, 31)), ("props/sky_stairs", 5, 3, (36, 33))],
  shop=("props/wi_cloud_stall", 2, 1, (14, 27), {"who": "Gull's Goods", "greet": "Feathers, fluff, and food that floats! Mind it doesn't float off.",
        "items": [["cloud_souffle", 560], ["charm_sky", 1700], ["storm_fluff", 480], ["greater_potion", 260], ["wonder_elixir", 900]]}),
  heal=("props/glow_pool_moon", 2, 1, (24, 26), {"hp": 5, "energy": 80, "msg": "You lie back on a cloud. It's exactly as comfortable as you always hoped."}),
  gate=("props/wi_mooring_tower", 2, 2, "spawn"),
  notes=[("A: read the wind vane", "Wind vane board: 'SUNRISE SHELF west, gentle. STORM SHELF north, not gentle. STARFALL GARDEN past the storm, where the Roc nests. Hold on to your hat. Hold on to your penguin.'")],
  npcs=[("mg_zephyr", "Zephyr", "mg_zephyr", ["Breezehaven! Where penguins fly, technically, in baskets.", "Storm Glass comes from where lightning lands. Don't be where lightning lands.", "The Roc thinks the whole sky is its nest. It isn't wrong."]),
        ("mg_gull", "Gull", "mg_gull", ["There's a cloud pool on Sunrise Shelf. Skyfin bite there at dawn.", "Storm Fluff makes a souffle rise like a cloud. Because it is one.", "I came up in a balloon forty years ago. Never found the way down. Never looked."]),
        ("mg_nimbus", "Nimbus", "mg_nimbus", ["The Star Crystal's light reaches all the way up here. The clouds love it.", "The Storm Shelf was calm, once. The Roc changed that.", "Bring me Storm Glass and I'll teach you to bottle a breeze. Well. Pay you, anyway."])],
  job={"giver": "mg_nimbus", "text": "Nimbus wants 3 Storm Glass and 2 Storm Fluff to calm the winds.", "items": [["storm_glass", 3], ["storm_fluff", 2]], "reward": {"animal": ["cloud_sheep", "Nimbus"], "animal_gang": ["emu", "Nimbus"], "gift_key": "mega:wind_job", "crystals": 1500, "max_hp": 20, "friend": ["mg_nimbus", 15]},
       "lines": {"offer": ["The winds are getting wilder every day. I can calm them, with the right weather in a jar.", "Three Storm Glass and two Storm Fluff. The Storm Shelf has plenty."], "yes": "Splendid. Don't hold anything metal up there.", "done": ["Feel that? A breeze. Just a breeze. Take this, you'll need it on the Shelf."]}},
  intro=["The balloon drifts up through the last cloud and into blue. Islands float in it like stepping stones, one with a windmill, one with a temple, one with a penguin waving both flippers.", "Breezehaven. The wind here smells of rain that hasn't happened yet."])
A("wind_sunrise_shelf", cols=50, rows=44, music="mega_wind", look="sky", ground_seam="cloud", links={"wind_breezehaven": ("e", 18)},
  water=[(12, 30)], hills=[(34, 12)],
  structs=[("props/sky_bridge", 10, 2, (22, 31)), ("nature/cloud_tree_c", 2, 2, (12, 12)), ("nature/cloud_tree_a", 2, 2, (38, 32))],
  things=[("loot", {"item": "storm_fluff", "n": 1, "every": 3, "hint": "A: a tuft of storm cloud", "sprite": "props/skydeco_5"}),
          ("loot", {"item": "star_dust", "n": 1, "every": 3, "hint": "A: dust from a falling star", "sprite": "props/skydeco_2"}),
          ("mrock", {"ore": "storm_glass", "hp": 4, "n": 1, "sprite": "props/moon_crystal_blue_s"}), ("mrock", {"ore": "silver", "hp": 3, "n": 2, "sprite": "props/ore_silver"}),
          ("note", {"hint": "A: read the sky-stone", "text": "A stone that floats, carved: 'FIRST LIGHT FALLS HERE FIRST.' The carving glows faintly pink."})],
  enemies=[("finargle_drone", 3), ("storm_wisp", 3)], fish=["sky_fish", "sky_fish", "mooncarp"],
  forage=[["star_dust", 0.15], ["flower", 0.3], ["wild_herb", 0.3]],
  intro=["Pink cloud and gold light. The Shelf is always just at sunrise, no matter what time it is down below."])
A("wind_storm_shelf", cols=48, rows=42, music="mega_wind_storm", music_fallback="danger", look="sky", ground_seam="starry_cloud", weather="storm", links={"wind_breezehaven": ("s", 22), "wind_starfall_garden": ("n", 22)},
  hills=[(10, 12), (38, 30)],
  structs=[("props/wi_storm_vane", 1, 1, (24, 12)), ("props/lightning_rod", 0, 1, (16, 20)), ("props/lightning_rod", 0, 1, (32, 22)), ("props/moon_crystal_blue", 2, 2, (36, 12)), ("props/moon_crystal_pink", 2, 2, (12, 32))],
  things=[("mrock", {"ore": "storm_glass", "hp": 4, "n": 1, "sprite": "props/moon_crystal_blue_s"}), ("mrock", {"ore": "storm_glass", "hp": 4, "n": 1, "sprite": "props/moon_crystal_pink_s"}),
          ("mrock", {"ore": "gold", "hp": 4, "n": 1, "sprite": "props/ore_gold"}),
          ("loot", {"item": "storm_fluff", "n": 2, "every": 3, "hint": "A: storm fluff snagged on a rod", "sprite": "props/skydeco_5"}),
          ("note", {"hint": "A: read the warning sign", "text": "A sign, scorched: 'DO NOT STAND HERE DURING STORMS. (IT IS ALWAYS STORMING.)'"})],
  enemies=[("storm_wisp", 3), ("cloud_knight", 2), ("finargle_drone", 2)],
  forage=[["star_dust", 0.1], ["wild_herb", 0.2]],
  intro=["Black cloud underfoot, lightning in it like veins. The rods hum. Your hair stands up. So does the pup's."])
A("wind_starfall_garden", cols=46, rows=42, music="mega_wind", look="sky", ground_seam="starry_cloud", path="float_stone", links={"wind_storm_shelf": ("s", 21)}, boss_at=(21, 9),
  water=[(36, 28)],
  structs=[("props/observatory", 6, 4, (12, 30)), ("props/star_crater", 3, 2, (32, 14)), ("props/moon_crystal_pink_t", 1, 1, (14, 12)), ("props/moon_crystal_blue", 2, 2, (28, 32))],
  things=[("loot", {"item": "star_dust", "n": 2, "every": 3, "hint": "A: a crater full of glitter", "sprite": "props/skydeco_2"}),
          ("loot", {"item": "storm_eye", "n": 1, "every": 14, "hint": "A: something perfectly calm in a nest", "sprite": "props/ri_nest"}),
          ("creature", {"species": "storm_roc", "species_gang": "", "flag": "boss_wind_starfall_garden", "key": "mega:roc_young", "giver": "Nimbus", "hint": "A: a ring of soft down",
                        "wait": "A ring of soft down, crackling with static. Something huge sleeps nearby. Not yet.",
                        "line": "A young roc, no bigger than a goose, tumbles out of the down and peeps at you. It's decided you're family. Nimbus will walk it down to your farm."}),
          ("heal", {"hp": 5, "energy": 60, "msg": "Starlight in the garden settles on you. You feel very small, and very fine.", "hint": "A: lie under the stars"}),
          ("note", {"hint": "A: read the star chart", "text": "A star chart, with one star circled again and again: the one that fell on the valley. Next to it: 'IT'S COMING HOME.'"})],
  boss={"kind": "storm_roc", "who": "The Storm Roc", "title": "The Storm Roc", "reward": "charm_storm",
        "text": "Wings like thunderheads open over the garden. The Roc lands, and every star in the garden flickers. It screams once, and the wind screams with it.",
        "win": "The Roc folds its wings and the storm goes with them. It looks at you, then at the Star Crystal's glow, and bows its great head. A feather drifts down, crackling.",
        "after": "The Roc's nest, empty and peaceful. A breeze, just a breeze."},
  enemies=[("storm_wisp", 2), ("cloud_knight", 2), ("finargle_drone", 2)], fish=["sky_fish", "mooncarp"],
  forage=[["star_dust", 0.2], ["flower", 0.3]],
  intro=["Above the storm, the sky goes dark and full of stars, close enough to touch. Flowers glow in the cloud. In the middle of it all, a nest the size of a barn."])

# Gilt City ----------------------------------------------------------------------
A("gilt_grand_plaza", cols=44, rows=40, music="mega_gilt", look="gilt", ground_seam="cobble_warm", path="plaza_tiles", links={"gilt_casino_row": ("e", 17), "gilt_gardens": ("w", 17)},
  plaza="plaza_tiles",
  structs=[("buildings/mansion", 12, 4, (21, 11)), ("props/gold_fountain", 3, 2, (12, 15)), ("props/gc_aurum_statue", 1, 2, (31, 15)), ("props/plaza_16", 0, 1, (17, 24)),
           ("props/plaza_17", 0, 1, (27, 24)), ("props/plaza_67", 4, 2, (10, 27)), ("props/plaza_68", 4, 2, (33, 27)), ("props/lux_car_red", 3, 1, (36, 33))],
  shop=("props/plaza_05", 4, 2, (24, 27), {"who": "Maison Dorée", "greet": "Only the finest. Prices on request. Requests are discouraged.",
        "items": [["sun_flan", 600], ["golden_dice", 2100], ["sparkling_wine", 340], ["greater_potion", 260], ["wonder_elixir", 900]]}),
  heal=("props/fountain2", 6, 3, (19, 30), {"hp": 5, "energy": 80, "msg": "You sit on the fountain's edge. The spray is cool and smells faintly of money."}),
  gate=("props/limo", 4, 1, "spawn"),
  notes=[("A: read the brass plaque", "Brass plaque: 'GILT CITY. CASINO ROW east, and beneath it THE VAULTS. GILDED GARDENS west. By order of MADAME AURUM, everything here is hers. Including this plaque.'")],
  npcs=[("mg_pell", "Pell", "mg_pell", ["Madame owns the casinos, the gardens, the Vaults, and the fountain. The water is rented.", "Collectors pay well for Gilt Chips. The Gilded Ace on the Row takes cash only.", "She'll see you in the Vaults. She sees everyone in the Vaults, eventually."]),
        ("mg_odette", "Odette", "mg_odette", ["I paint the statues. Madame keeps asking me to make them look more like her.", "Gold leaf on a flan. Disgusting. Delicious.", "The gardens are the only place in Gilt City that's free. Don't tell her."]),
        ("mg_cass", "Cass", "mg_cass", ["Fastest legs in Gilt. Madame's guards can't catch me.", "There's a lucky coin under every third bench. I've checked.", "I'd steal her crown, but it's glued on."])],
  job={"giver": "mg_odette", "text": "Odette wants 3 Gold Leaf and a Pearl Necklace for her masterpiece.", "items": [["gold_bundle", 3], ["pearl_necklace", 1]], "reward": {"crystals": 2000, "item": ["wonder_elixir", 1], "max_hp": 20, "friend": ["mg_odette", 15]},
       "lines": {"offer": ["I'm painting Gilt City as it really is. For that I need real gold leaf and a real pearl.", "Three Gold Leaf and one Pearl Necklace. The Vaults have both, if you're brave."], "yes": "Wonderful. Wear something dark, the guards hate that.", "done": ["Perfect. Look at it shine! She'll hate it. Here, for you."]}},
  intro=["The limousine purrs into a plaza paved with gold-veined stone. Statues, fountains, a mansion with a hundred windows, and every lamp post has a little crown on top.", "Gilt City. Everything glitters. Everything has a price."])
A("gilt_casino_row", cols=50, rows=42, music="mega_gilt", look="gilt", ground_seam="city_pavement", path="brick_herring", links={"gilt_grand_plaza": ("w", 17), "gilt_vaults": ("n", 24)},
  structs=[("props/gc_casino", 8, 4, (24, 12), {"type": "casino", "hint": "A: enter The Gilded Ace"}),
           ("buildings/neon_hotel", 9, 4, (10, 30), {"type": "note", "hint": "A: read the hotel sign", "who": "", "text": "The Neon Hotel. A brass sign: ROOMS FOR GUESTS OF THE GILDED ACE. Tonight every room is booked; the desk clerk points you across the Row to the casino."}), ("buildings/penthouse", 6, 4, (36, 12)), ("props/spotlight_pink", 1, 1, (24, 9)), ("props/spotlight_cyan", 1, 1, (30, 30)),
           ("props/betting_booth", 3, 2, (12, 30), {"type": "casino_odds", "hint": "A: read the odds board"}), ("props/lux_car_black", 3, 1, (36, 32)), ("props/neon_sign_2", 2, 1, (8, 22)), ("props/neon_sign_5", 2, 1, (40, 22))],
  things=[("loot", {"item": "gambler_chip", "n": 3, "every": 2, "hint": "A: chips under a table", "sprite": "props/card_table"}),
          ("loot", {"item": "lucky_coin", "n": 1, "every": 4, "hint": "A: a coin in the fountain", "sprite": "props/fountain2"}),
          ("mrock", {"ore": "gold", "hp": 4, "n": 2, "sprite": "props/ore_gold"}),
          ("note", {"hint": "A: read the house rules", "text": "House rules: 1. The house always wins. 2. See rule 1. 3. No running. (Someone has crossed out 3 and written CASS WAS HERE.)"})],
  enemies=[("thug_gambler", 2), ("gilt_runner", 2), ("gilt_guard", 2)],
  forage=[["flower", 0.3]],
  intro=["Neon on gold. Every door is a casino, every window shows somebody winning, and none of them look happy about it."])
A("gilt_gardens", cols=50, rows=44, music="mega_gilt", look="gilt", ground_seam="meadow_grass", path="cobble_moss", border="trees", links={"gilt_grand_plaza": ("e", 18)},
  water=[(14, 30), (36, 12)],
  structs=[("props/hedge2_arch", 5, 2, (24, 12)), ("props/plaza_50", 4, 3, (14, 13)), ("props/gold_fountain", 3, 2, (36, 30)), ("props/plaza_29", 3, 1, (22, 30)), ("props/plaza_31", 3, 1, (30, 26)),
           ("props/plaza_45", 2, 1, (8, 22)), ("props/topiary_a", 1, 1, (40, 22)), ("props/hedge2_tree", 1, 1, (28, 35))],
  things=[("loot", {"item": "pearl_necklace", "n": 1, "every": 10, "hint": "A: something shining in the hedge", "sprite": "props/hedge2_ball"}),
          ("loot", {"item": "dark_rose", "n": 2, "every": 2, "hint": "A: velvet roses", "sprite": "props/flowerbed_red"}),
          ("heal", {"hp": 4, "energy": 60, "msg": "A bench under a rose arch. The only free thing in Gilt City.", "hint": "A: rest on the bench"}),
          ("note", {"hint": "A: read the gardener's note", "text": "Gardener's note: 'Madame wants the roses gold. Roses do not come in gold. I have explained this nine times.'"})],
  enemies=[("gilt_guard", 2), ("thug_enforcer", 2), ("gilded_mirror", 1)], fish=["carp", "ember_koi", "goldfish"],
  forage=[["dark_rose", 0.2], ["flower", 0.4], ["wild_herb", 0.2]],
  intro=["Hedges clipped into crowns, roses in perfect rows, gold-fish in gold ponds. Even the bees look expensive."])
A("gilt_vaults", cols=46, rows=42, music="underground", look="gilt", ground_seam="floor_checker", path="plaza_tiles", border="cliff", backdrop="night", links={"gilt_casino_row": ("s", 21)}, boss_at=(21, 9),
  structs=[("props/gc_vault_door", 5, 3, (28, 8)), ("props/gold_fence_a", 2, 1, (12, 14)), ("props/gold_fence_b", 2, 1, (32, 14)), ("props/gold_gate", 1, 1, (16, 7)), ("props/gold_gate", 1, 1, (27, 7)),
           ("props/treasure", 2, 1, (12, 28)), ("props/statue2_founder", 3, 2, (34, 28)), ("props/crates_pallet", 2, 1, (22, 33)), ("props/crates_pallet_b", 2, 1, (26, 33))],
  things=[("loot", {"item": "gold_bundle", "n": 1, "every": 3, "hint": "A: a stack of gold leaf", "sprite": "props/chest_open"}),
          ("loot", {"item": "pearl_necklace", "n": 1, "every": 8, "hint": "A: a velvet case", "sprite": "props/chest_closed"}),
          ("mrock", {"ore": "platinum", "hp": 5, "n": 1, "sprite": "props/ore_silver_2"}), ("mrock", {"ore": "platinum", "hp": 5, "n": 1, "sprite": "props/ore_silver_1"}),
          ("note", {"hint": "A: read the vault ledger", "text": "Vault ledger: 'Gold: yes. Pearls: yes. Friends: (blank).'"})],
  boss={"kind": "madame_aurum", "who": "Madame Aurum", "title": "Madame Aurum", "reward": "ring_platinum",
        "text": "A woman in gold steps out from between the stacks, crown glittering. 'So you're the one my car's been driving about. Let's see what you're worth.'",
        "win": "Madame Aurum laughs, actually laughs, and sits on a pile of coins. 'Oh, I like you. Keep the ring. The Vaults can spare it. And the gardens are yours to wander, free.'",
        "after": "Madame Aurum's stack of coins. She left a note: 'Dinner? Bring the flan.'"},
  enemies=[("gilt_guard", 3), ("gilded_mirror", 2), ("thug_enforcer", 1)],
  forage=[],
  intro=["Under the casinos, the Vaults: gold in stacks to the ceiling, fences of gold, and the soft tick of somebody counting."])

# Second areas for converted regions --------------------------------------------
A("hollow_deeps", cols=50, rows=44, music="mega_hollow_deeps", music_fallback="hollow_heart", look="gloam", ground_seam="cave_crystal_floor", path="cave_stone_floor", border="cliff", backdrop="night", weather="clear",
  links={"hollow_heart": ("w", 20)}, water=[(34, 30), (16, 12)], feature=("cave_water", [(36, 12, 4)]),
  structs=[("props/mushroom_tree_a", 2, 2, (12, 30)), ("props/mushroom_tree_b", 2, 2, (40, 22)), ("props/grotto_crystal_a", 3, 2, (26, 10)), ("props/cave_lamp", 0, 1, (20, 22)),
           ("props/cave_cart", 1, 1, (30, 22)), ("props/mine_crystal_bigrock_1", 2, 2, (8, 22)), ("props/geode_chamber", 6, 3, (38, 36))],
  things=[("mrock", {"ore": "sapphire", "hp": 4, "n": 1, "sprite": "props/mine_crystal_ore_a_0"}), ("mrock", {"ore": "amethyst", "hp": 4, "n": 1, "sprite": "props/mine_crystal_ore_b_0"}),
          ("mrock", {"ore": "shard", "hp": 3, "n": 2, "sprite": "props/mine_crystal_ore_a_1"}), ("mrock", {"ore": "gold", "hp": 4, "n": 1, "sprite": "props/ore_gold_2"}),
          ("loot", {"item": "crystal_refined", "n": 1, "every": 4, "hint": "A: a crystal glowing in the moss", "sprite": "props/ccrystal_3"}),
          ("loot", {"item": "cave_bloom", "n": 2, "every": 2, "hint": "A: blooms by the glowing water", "sprite": "props/cave_mush_blue"}),
          ("creature", {"species": "deep_glowworm", "species_gang": "volt_gecko", "key": "mega:hollow_glow", "giver": "", "hint": "A: a soft light in the moss",
                        "line": "A glowworm curls round your finger and won't let go. It wants to see the sky. It'll be at your farm by morning.",
                        "line_gang": "A little gecko with a battery-blue glow skitters up your sleeve. Somebody's lab lost it. It's yours now."}),
          ("heal", {"hp": 5, "energy": 60, "msg": "You sit by the glowing water. The light goes right through you, warm.", "hint": "A: rest by the glow"}),
          ("note", {"hint": "A: read the miners' slate", "text": "A miners' slate, chalk still sharp: 'Camp 9. Water here glows. Drank it. Feel fine. Feel BETTER than fine. Do not tell the foreman.'"}),
          ("note", {"hint": "A: read the old map", "text": "An old map pinned to a crate: the Heart in the middle, and around it a ring of caverns marked 'DEEPS', 'DEEPER', and one just marked 'NO'."})],
  enemies=[("prism_wisp", 3), ("obsidian_sentinel", 2), ("void_eel", 2), ("gloom_spider", 2)], fish=["mooncarp", "ghost_fish", "eel"],
  forage=[["cave_bloom", 0.3], ["glowcap", 0.3], ["mushroom", 0.3], ["crystal_bloom", 0.1]],
  intro=["East of the Heart the caverns open into rivers of light: crystal floors, glowing pools, and the cold ashes of a miners' camp nobody ever came back for."])
A("sky_reaches", cols=48, rows=42, music="mega_sky_reaches", music_fallback="sky", look="sky", ground_seam="cloud", links={"sky": ("s", 22)}, water=[(12, 14)],
  structs=[("nature/cloud_tree_a", 2, 2, (10, 28)), ("nature/cloud_tree_b", 2, 2, (36, 30)), ("props/sky_bridge", 10, 2, (24, 20)), ("props/wi_wind_shrine", 2, 2, (30, 8))],
  things=[("loot", {"item": "star_dust", "n": 2, "every": 3, "hint": "A: dust shaken off a passing whale", "sprite": "props/skydeco_2"}),
          ("loot", {"item": "storm_fluff", "n": 1, "every": 4, "hint": "A: a curl of storm cloud", "sprite": "props/skydeco_5"}),
          ("mrock", {"ore": "silver", "hp": 3, "n": 2, "sprite": "props/moon_crystal_blue_s"}), ("mrock", {"ore": "star_dust", "hp": 4, "n": 1, "sprite": "props/moon_crystal_pink_s"}),
          ("heal", {"hp": 4, "energy": 50, "msg": "The whale's song rolls through the cloud. You feel lighter.", "hint": "A: listen to the whale"}),
          ("note", {"hint": "A: read the knight's carving", "text": "Carved into a floating stone: 'THE WHALE IS NOT LOST. IT IS WAITING FOR SOMEONE WHO WILL LISTEN.'"})],
  enemies=[("finargle_drone", 3), ("storm_wisp", 2), ("archer", 1)], fish=["sky_fish", "mooncarp"],
  forage=[["star_dust", 0.15], ["flower", 0.3], ["wild_herb", 0.3]],
  intro=["Above the Cloud Isles the air thins and sings. A shadow the size of a town slides under the clouds below you: the sky whale, circling, circling."])

# ---------------------------------------------------------------- layout engine
OPP = {"n": "s", "s": "n", "w": "e", "e": "w"}
ARROW = {"n": "▲", "s": "▼", "w": "◀", "e": "▶"}

def exit_geom(side, p, cols, rows):
    """rect, path end point (x,y of the 2-wide lane's top-left at the edge), spawn [x,y], facing."""
    if side == "n": return [p, 0, 4, 1], (p + 1, 0), [p + 2, 2.5], "down"
    if side == "s": return [p, rows - 1, 4, 1], (p + 1, rows - 2), [p + 2, rows - 2.5], "up"
    if side == "w": return [0, p, 1, 4], (0, p + 1), [2.5, p + 2], "right"
    return [cols - 1, p, 1, 4], (cols - 2, p + 1), [cols - 2.5, p + 2], "left"

def route(a, b, order):
    (ax, ay), (bx, by) = a, b
    out = []
    if order == "hv":
        out.append([min(ax, bx), ay, abs(bx - ax) + 2, 2])
        out.append([bx, min(ay, by), 2, abs(by - ay) + 2])
    else:
        out.append([ax, min(ay, by), 2, abs(by - ay) + 2])
        out.append([min(ax, bx), by, abs(bx - ax) + 2, 2])
    return out

def cells_of(rects):
    s = set()
    for x, y, w, h in rects:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                s.add((xx, yy))
    return s

class Grid:
    def __init__(s, cols, rows):
        s.cols, s.rows = cols, rows
        s.occ = {}
    def free(s, c):
        x, y = c
        return 0 <= x < s.cols and 0 <= y < s.rows and c not in s.occ
    def mark(s, cells, tag, margin=0):
        for (x, y) in cells:
            for dy in range(-margin, margin + 1):
                for dx in range(-margin, margin + 1):
                    s.occ.setdefault((x + dx, y + dy), tag)

def cheb_dist_field(cols, rows, src):
    INF = 999
    d = {(x, y): INF for y in range(rows) for x in range(cols)}
    q = []
    for c in src:
        if c in d:
            d[c] = 0; q.append(c)
    i = 0
    while i < len(q):
        x, y = q[i]; i += 1
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (x + dx, y + dy)
                if n in d and d[n] > d[(x, y)] + 1:
                    d[n] = d[(x, y)] + 1; q.append(n)
    return d

def build_area(aid, mega, spec, links_geom):
    L = dict(LOOKS[spec["look"]])
    cols, rows = spec["cols"], spec["rows"]
    tier = next(a["tier"] for a in BY_ID[mega]["areas"] if a["id"] == aid)
    is_hub = aid == BY_ID[mega].get("hub")
    R = {"cols": cols, "rows": rows, "music": spec["music"], "tier": tier, "pad": 6, "fruit": 0,
         "mega": mega, "area_name": spec.get("name", "")}
    if spec.get("music_fallback"):
        R["music_fallback"] = spec["music_fallback"]
    for k in ("ground", "ground_seam", "path", "border", "void_color", "backdrop", "weather", "season", "cliff_style", "pet"):
        v = spec.get(k, L.get(k))
        if v is not None:
            R[k] = v
    R["path_lip"] = {"snow": "8a9ab030", "sky": "c0d0e020", "desert": "8a5a2a38", "gloam": "2a1a3a50", "rail": "2a2a2a48", "gilt": "6a4a1a40"}[spec["look"]]
    R["ground"] = R["ground_seam"]  # not "grass": that would draw the valley's grass instead of the seamless ground
    R["amb"] = dict(AMB.get(spec["look"], {}))
    R["amb"].update(AREA_AMB.get(aid, {}))
    if aid in AREA_AMB_NIGHT:
        R["amb_night"] = dict(R["amb"])
        R["amb_night"].update(AREA_AMB_NIGHT[aid])
    sp = [] if aid in CAVE else SPOTS.get(spec["look"], []) + AREA_SPOTS.get(aid, [])
    if sp:
        R["spots"] = sp
    if aid in CAVE:  # C5: underground areas drop the look's surface beds (wind, streets); Ambience skips them too
        for k in ("wind_soft", "wind_strong", "town_day", "crowd", "city_hum", "neon_street", "birds_day", "birds_dawn", "waves", "leaves"):
            R["amb"].pop(k, None)
    R["gen"] = json.loads(json.dumps(L["gen"]))
    R["gen"].update(spec.get("gen_extra", {}))
    if spec["look"] in THEME:
        R["gen"]["theme"] = json.loads(json.dumps(THEME[spec["look"]]))
    if spec["look"] in BORDER_TREES and R.get("border") == "trees":
        R["border_trees"] = BORDER_TREES[spec["look"]]
    if aid in CAVE:
        R["cave"] = True
        R["gen"]["critters"] = []
        R["gen"]["critter_count"] = 0
        R["gen"]["region_props"] = [n for n in CAVE[aid] if has_art("props", n) or has_art("nature", n)]
        R["gen"]["region_count"] = 16
        R["gen"]["theme"] = {"trees": [], "bushes": False, "logs": False, "band": []}
    if is_hub:
        R["gen"]["region_count"] = max(10, R["gen"].get("region_count", 20) // 2)
    G = Grid(cols, rows)
    cx, cy = cols // 2 - 1, rows // 2 - 1
    paths = []
    exits = []
    # exits and the lanes to them
    for to, (side, p) in spec["links"].items():
        rect, end, spawn, facing = exit_geom(side, p, cols, rows)
        tside, tp = links_geom[(to, aid)]
        tdim = AREAS.get(to) or EXTERNAL[to]
        trect, tend, tspawn, tfacing = exit_geom(tside, tp, tdim["cols"], tdim["rows"])
        exits.append({"rect": rect, "scene": to, "spawn": tspawn, "facing": tfacing, "label": "%s %s" % (ARROW[side], (AREAS.get(to) or {}).get("name") or EXT_NAME.get(to) or area_name(to))})
        paths += route((cx, cy), end, "hv" if side in "ns" else "vh")
        G.mark(cells_of([rect]), "X", 4)
    spawn = None
    if is_hub:
        sp = (cx + 1, rows - 7)
        spawn = [sp[0], sp[1]]
        paths += route((cx, cy), (cx, rows - 6), "hv")
        G.mark({sp}, "S", 2)
    else:
        spawn = None
    boss_at = spec.get("boss_at")
    if boss_at:
        paths += route((cx, cy), boss_at, "hv")
    # Spur lanes out to clearings, so outer areas aren't just a cross.
    pcs = cells_of(paths)
    spurs = spec.get("spurs")
    if spurs is None:
        spurs = []
        quads = [(int(cols * 0.22), int(rows * 0.28)), (int(cols * 0.74), int(rows * 0.28)), (int(cols * 0.22), int(rows * 0.72)), (int(cols * 0.74), int(rows * 0.72))]
        quads.sort(key=lambda q: -min(abs(q[0] - x) + abs(q[1] - y) for x, y in pcs))
        spurs = quads[:1 if is_hub else 2]
    for i, sp_ in enumerate(spurs):
        paths += route((cx, cy), sp_, "hv" if i % 2 == 0 else "vh")
    pcs = cells_of(paths)
    G.mark(pcs, "P", 1)
    dist = cheb_dist_field(cols, rows, pcs)
    R["paths"] = paths
    R["exits"] = exits
    if spec.get("plaza"):
        R["layers"] = [{"tile": spec["plaza"], "rect": [cx - 5, cy - 4, 12, 10]}]
        G.mark(cells_of([[cx - 5, cy - 4, 12, 10]]), "P", 1)
    props, things, npcs = [], [], []
    rng = random.Random(shash(aid) % 100000)

    def edge_ok(x, y, m=5):
        return m <= x < cols - m and m <= y < rows - m

    # boss arena first: it owns its spot
    if boss_at:
        bx, by = boss_at
        bc = (bx, by - 2)
        b = dict(spec["boss"])
        b.update({"type": "boss", "cell": list(bc), "max_hp": 1, "solid": False, "hint": "A: face it"})
        things.append(b)
        G.mark({bc}, "B", 2)

    def place_struct(name, w, h, near, maxd=4, solid=True, thing=None, thing_dy=0):
        g, nm = name.split("/", 1)
        if not has_art(g, nm):
            print("  (no art: %s)" % name)
            return None
        if near == "spawn":
            near = (spawn[0] - 4 - w, spawn[1] + 1)
        tx, ty = near
        best = None
        for y in range(4 + h, rows - 4):
            for x in range(4, cols - 4 - w):
                fp = [(xx, yy) for yy in range(y - h + 1, y + 1) for xx in range(x, x + w + 1)]
                if any(not G.free(c) for c in fp):
                    continue
                ring = [(xx, yy) for yy in range(y - h, y + 2) for xx in range(x - 1, x + w + 2)]
                if any((c in G.occ and G.occ[c] not in ("P",)) for c in ring if c not in fp):
                    continue
                if any(G.occ.get(c) == "P" and c in pcs for c in ring):
                    continue
                if min(dist.get((xx, y), 99) for xx in range(x, x + w + 1)) > maxd:
                    continue
                score = abs(x + w / 2 - tx) + abs(y - ty)
                if best is None or score < best[0]:
                    best = (score, x, y, fp)
        if best is None:
            print("  (no room for %s near %s in %s)" % (name, near, aid))
            return None
        _, x, y, fp = best
        G.mark(fp, "B", 1)
        p = {"name": nm, "cell": [x, y], "w": w, "h": h}
        if g != "props":
            p["group"] = g
        if not solid:
            p["solid"] = False
        props.append(p)
        if thing is not None:
            t = dict(thing)
            t["cell"] = [x + (w + 1) // 2, y + thing_dy]
            if "solid" not in t:
                t["solid"] = True
            things.append(t)
        return (x, y)

    if is_hub:
        e = spec["gate"]
        place_struct(e[0], e[1], e[2], e[3], maxd=3, solid=True, thing={"type": "mega_gate", "mega": mega, "home": True, "hint": "A: travel"})
        sname, sw, sh, snear, sdef = spec["shop"]
        t = {"type": "shop", "hint": "A: shop"}
        t.update(sdef)
        t["items"] = [[i, p if p else int(ITEMS.get(i, (0, 0, 100))[2] * 1.5) or 100] for i, p in t["items"]]
        place_struct(sname, sw, sh, snear, maxd=3, thing=t)
        hname, hw, hh, hnear, hdef = spec["heal"]
        t = {"type": "heal", "hint": "A: rest"}
        t.update(hdef)
        place_struct(hname, hw, hh, hnear, maxd=3, thing=t)
    # water and hills in the open
    def blob_spot(near, r, tag):
        tx, ty = near
        best = None
        R2 = int(math.ceil(r * (1.25 if tag == "W" else 1.0) + 2))
        for y in range(R2 + 2, rows - R2 - 2):
            for x in range(R2 + 2, cols - R2 - 2):
                ok = True
                for yy in range(y - R2, y + R2 + 1):
                    for xx in range(x - R2, x + R2 + 1):
                        if (xx - x) ** 2 + (yy - y) ** 2 <= R2 * R2 and not G.free((xx, yy)):
                            ok = False; break
                    if not ok: break
                if not ok: continue
                sc = abs(x - tx) + abs(y - ty)
                if best is None or sc < best[0]:
                    best = (sc, x, y)
        if best is None:
            return None
        _, x, y = best
        G.mark({(xx, yy) for yy in range(y - R2, y + R2 + 1) for xx in range(x - R2, x + R2 + 1) if (xx - x) ** 2 + (yy - y) ** 2 <= R2 * R2}, tag)
        return (x, y)
    wb = []
    fish = spec.get("fish") or ["carp", "trout", "salmon"]
    for i, near in enumerate(spec.get("water", [])):
        r = 4 if is_hub else 5
        at = blob_spot(near, r, "W")
        if at is None:
            at = blob_spot(near, 3, "W"); r = 3
        if at:
            wb.append({"c": [at[0] + 0.5, at[1] + 0.5], "r": r, "seed": shash(aid + str(i)) % 900 + 11, "fish": fish, "shore": spec.get("shore", "sand" if spec["look"] == "desert" else "grass")})
        else:
            print("  (no room for water near %s in %s)" % (near, aid))
    if wb:
        R["water_blobs"] = wb
    for st in spec.get("structs", []):
        name, w, h, near = st[:4]
        place_struct(name, w, h, near, maxd=6, thing=st[4] if len(st) > 4 else None)  # a 5th entry = the struct's door thing (C10b P4)
    pl = []
    for i, near in enumerate(spec.get("hills", [])):
        r = 6
        at = blob_spot(near, r, "H")
        for rr in (5, 4):
            if at is None:
                at = blob_spot(near, rr, "H"); r = rr
        if at:
            pl.append({"blobs": [{"c": [at[0], at[1]], "r": r, "ry": r * 0.75, "seed": shash(aid + "h" + str(i)) % 900 + 7}], "upper": []})
        else:
            print("  (no room for a hill near %s in %s)" % (near, aid))
    if pl:
        R["plateaus"] = pl
    if spec.get("feature"):
        setn, blobs = spec["feature"]
        R["feature_blobs"] = [{"set": setn, "blobs": [{"c": [x, y], "r": r, "seed": shash(aid + setn + str(i)) % 900 + 3} for i, (x, y, r) in enumerate(blobs)]}]
    # things beside the roads
    cand = [(x, y) for y in range(rows) for x in range(cols) if dist[(x, y)] == 2 and edge_ok(x, y) and G.free((x, y))]
    placed = [tuple(t["cell"]) for t in things]
    def pick(target=None):
        best = None
        for c in cand:
            if not G.free(c):
                continue
            md = min([max(abs(c[0] - p[0]), abs(c[1] - p[1])) for p in placed] or [20])
            if md < 3:
                continue
            sc = min(md, 9) - (0.15 * (abs(c[0] - target[0]) + abs(c[1] - target[1])) if target else 0) + rng.random() * 0.5
            if best is None or sc > best[0]:
                best = (sc, c)
        if best is None:
            return None
        c = best[1]
        placed.append(c)
        G.mark({c}, "T", 1)
        return c
    tlist = list(spec.get("things", []))
    for hint, text in spec.get("notes", []):
        tlist.append(("note", {"hint": hint, "text": text}))
    for kind, td in tlist:
        c = pick()
        if c is None:
            print("  (no spot for %s in %s)" % (kind, aid)); continue
        t = {"type": kind, "cell": list(c)}
        t.update({k: v for k, v in td.items() if k != "sprite"})
        if kind in ("loot", "heal", "note", "creature"):
            t["solid"] = False
        if kind == "mrock":
            t["hint"] = "A: mine it"
        if "sprite" in td:
            g, nm = td["sprite"].split("/", 1)
            if has_art(g, nm):
                pp = {"name": nm, "cell": list(c), "solid": False}
                if g != "props":
                    pp["group"] = g
                props.append(pp)
        if kind == "note":
            t.setdefault("who", "")
        things.append(t)
    # villagers: on the road's shoulder near the middle
    for i, (nid, nm, sprite, lines) in enumerate(spec.get("npcs", [])):
        best = None
        for y in range(rows):
            for x in range(cols):
                c = (x, y)
                if dist[c] != 0 or not edge_ok(x, y, 6):  # on the road itself: scatter and secrets keep off it
                    continue
                if any(max(abs(c[0] - n["cell"][0]), abs(c[1] - n["cell"][1])) < 5 for n in npcs):
                    continue
                if any(max(abs(c[0] - t["cell"][0]), abs(c[1] - t["cell"][1])) < 2 for t in things):
                    continue
                if spawn and max(abs(c[0] - spawn[0]), abs(c[1] - spawn[1])) < 3:
                    continue
                sc = abs(x - cx) + abs(y - cy) + rng.random()
                if best is None or sc < best[0]:
                    best = (sc, c)
        if best:
            nd = {"id": nid, "name": nm, "sprite": sprite, "role": BY_ID[mega]["name"], "cell": list(best[1]), "lines": lines, "wander": 10.0}
            nd.update(NPC_EXTRA.get(nid, {}))  # C12 P3: arc / after-boss / job-done lines (Talk.region_lines)
            npcs.append(nd)
    for p in props:
        oc = open_cells(p)
        if oc:
            p["open"] = oc
    R["props"] = props
    R["things"] = things
    R["npcs"] = npcs
    R["enemies"] = [{"kind": k, "count": n} for k, n in spec.get("enemies", [])]
    R["forage"] = 0 if is_hub else 8
    R["spawn"] = spawn if spawn else [int(exits[0]["rect"][0]) + 2, 0]
    if not is_hub:
        # Default spawn: just inside the first exit (used when nothing else says where).
        rect, end, sp, fc = exit_geom(*spec["links"][list(spec["links"])[0]], cols, rows)
        R["spawn"] = [int(sp[0]), int(sp[1])]
    if spec.get("intro"):
        R["intro"] = spec["intro"]
    if aid in CAVE or aid.startswith("hollow_"):
        # C5: fixed darkness 0..1 underground (GameMap reads it); written last so reruns match the file (c6_17-1)
        R["light"] = LIGHT.get(aid, 0.5)
    return R

EXT_NAME = {"hollow_heart": "the Hollow Heart", "sky": "the Cloud Isles"}
# The side/position of the new exit on each existing map (their way to the second area).
EXT_LINKS = {("hollow_heart", "hollow_deeps"): ("e", 29), ("sky", "sky_reaches"): ("n", 14)}

def patch_external(regs):
    """Give the existing maps their exit (and a lane to it) to their new second area."""
    for (ext, aid), (side, p) in EXT_LINKS.items():
        R = regs[ext]
        rect, end, spawn, facing = exit_geom(side, p, R["cols"], R["rows"])
        mside, mp = AREAS[aid]["links"][ext]
        mrect, mend, mspawn, mfacing = exit_geom(mside, mp, AREAS[aid]["cols"], AREAS[aid]["rows"])
        R["exits"] = [e for e in R.get("exits", []) if e.get("scene") != aid]
        R["exits"].append({"rect": rect, "scene": aid, "spawn": mspawn, "facing": mfacing, "label": "%s %s" % (ARROW[side], AREAS[aid]["name"])})
        lane = EXT_LANES[ext]
        if lane not in R["paths"]:
            R["paths"].append(lane)
    regs["sky"]["void_color"] = LOOKS["sky"]["void_color"]  # the cloud bank past the edge, not a black band (c9_14)
    # The Sky Isles' plain Finargles are the queen's drones (c4_08 #6).
    for e in regs["sky"].get("enemies", []):
        if isinstance(e, dict) and e.get("kind") in ("finargle", "finargle_drone"):
            e["kind"] = "finargle_drone"
        elif isinstance(e, list) and e and e[0] == "finargle":
            e[0] = "finargle_drone"

EXT_LANES = {"hollow_heart": [66, 30, 10, 2], "sky": [15, 0, 2, 4]}

_ITEMS_CACHE = {}
def J_items():
    if not _ITEMS_CACHE:
        _ITEMS_CACHE.update(J("items.json"))
    return _ITEMS_CACHE

def check_ids(regs, I, E, Q, travel):
    """Every id a mega area hands out, sells or asks for must exist (c4_10 #2/#3)."""
    bad = []
    def need(i, where):
        if i not in I and i not in ("crystals",):
            bad.append("%s: %s" % (where, i))
    for r in REGIONS + EXTRA:
        for a in r["areas"]:
            R = regs[a["id"]]
            for t in R.get("things", []):
                w = "%s %s" % (a["id"], t.get("type"))
                for k in ("item", "reward"):
                    if isinstance(t.get(k), str) and t.get(k):
                        need(t[k], w)
                if t.get("type") == "mrock":
                    need(t.get("ore", ""), w) if t.get("ore") not in ("stone",) or "stone" in I else None
                for it in t.get("items", []):
                    need(it[0], w + " shop")
            for wb in R.get("water_blobs", []):
                if isinstance(wb, dict):
                    for f in wb.get("fish", []):
                        need(f, a["id"] + " fish")
            for f in R.get("fish", []):
                need(f, a["id"] + " fish")
            for e in R.get("enemies", []):
                k = e.get("kind") if isinstance(e, dict) else e[0]
                if k not in E["enemies"]:
                    bad.append("%s enemy: %s" % (a["id"], k))
    for k, (_b, _t, _h, _ti, _n, drops, _x) in ENEMIES.items():
        for d in drops:
            need(d[0], k + " drop")
    for q in Q["side"]:
        if str(q["id"]).startswith("mega_"):
            for it in q.get("done_when", {}).get("items", []):
                need(it[0], q["id"])
            rw = q.get("reward", {})
            if rw.get("item"):
                need(rw["item"][0], q["id"] + " reward")
    for rc in RECIPES:
        for i in rc["need"]:
            need(i, "recipe " + rc["id"])
    for aid, spec in AREAS.items():
        for f in spec.get("forage", []):
            need(f[0], aid + " forage")
    if bad:
        sys.exit("gen_mega_new: unknown ids\n  " + "\n  ".join(bad))

def area_name(aid):
    for r in REGIONS + EXTRA:
        for a in r["areas"]:
            if a["id"] == aid:
                return a["name"]
    return aid

# ---------------------------------------------------------------- write
def main():
    for aid, spec in AREAS.items():
        spec.setdefault("name", area_name(aid))
    links_geom = {}
    for aid, spec in AREAS.items():
        for to, sp in spec["links"].items():
            links_geom[(aid, to)] = sp
    links_geom.update(EXT_LINKS)
    for (a, b), (side, p) in list(links_geom.items()):
        if (b, a) not in links_geom:
            sys.exit("one-way link %s -> %s" % (a, b))
        if links_geom[(b, a)][0] != OPP[side]:
            sys.exit("link %s -> %s: sides %s / %s don't face" % (a, b, side, links_geom[(b, a)][0]))
    for r in REGIONS:
        jid = "mega_%s_job" % r["id"]
        job = AREAS[r["hub"]]["job"]
        job["reward"].pop("friend", None)  # keepers aren't villagers: no hidden hearts (c4_10 #9)
        giver = next((n[1] for n in AREAS[r["hub"]].get("npcs", []) if n[0] == job["giver"]), "someone")
        for a in r["areas"]:
            bs = AREAS[a["id"]].get("boss")
            if bs:
                bs["when"] = {"quest": jid}
                hub = CONTENT[r["id"]]["hub_name"]
                hub = ("the " + hub) if hub in HUB_THE else hub
                bs["locked"] = BOSS_LOCKED.get(a["id"], "The way on is shut for now. Help %s in %s first.") % (giver, hub)
                if r["arc"] == "both":
                    bs.update(GANG_BOSS.get(a["id"], {}))
    regs = J("regions.json")
    owned = {aid for aid in AREAS}
    for aid in owned:
        regs.pop(aid, None)
    for r in REGIONS + EXTRA:
        for a in r["areas"]:
            if a["id"] not in AREAS:
                sys.exit("no layout for " + a["id"])
            regs[a["id"]] = build_area(a["id"], r["id"], AREAS[a["id"]], links_geom)
            open(f"{D}/scenes/{a['id']}.tscn", "w").write('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/region.gd" id="1"]\n\n[node name="%s" type="Node2D"]\nscript = ExtResource("1")\nregion_id = "%s"\n' % (a["id"], a["id"]))
    patch_external(regs)
    # mega ore rocks come back after `every` days by ore tier (c4_10 #1; Region honours it)
    for r in REGIONS + EXTRA:
        for a in r["areas"]:
            for t in regs[a["id"]].get("things", []):
                if t.get("type") == "mrock" and "every" not in t:
                    ot = int(ITEMS.get(t.get("ore", ""), (0, 0, 0, J_items().get(t.get("ore", ""), {}).get("tier", 1)))[3])
                    t["every"] = {0: 3, 1: 3, 2: 4, 3: 5, 4: 6, 5: 7}.get(ot, 4)
    W("regions.json", regs)
    # items
    I = J("items.json")
    for iid, (nm, typ, val, tier, extra) in ITEMS.items():
        assert has_art("items", iid) or has_art("items", extra.get("icon", "")), iid
        d = {"name": nm, "type": typ, "value": val, "tier": tier}
        d.update(extra)
        I[iid] = d
    W("items.json", I)
    # enemies
    E = J("enemies.json")
    ival = {k: int(v.get("value", 0)) for k, v in I.items()}
    for k, (base, tint, hp, tier, nm, drops, extra) in ENEMIES.items():
        b = E["enemies"][base]
        d = {"hp": hp, "dmg": max(1, int(b.get("dmg", 2)) + (1 if tier >= 4 else 0)), "speed": b.get("speed", 30), "xp": max(4, hp // 3), "tier": tier,
             "abilities": list(b.get("abilities", [])), "name": nm}
        ak = ART_AS.get(k, k)
        own = k in OWN_ART and os.path.isdir(f"{D}/art/gen/enemies/{ak}")
        if own:  # P5's sheet is in: no char, no tint
            d["art"] = ak
        elif extra.get("char"):
            d["char"] = extra["char"]
            if tint:
                d["tint"] = tint
        else:
            fb = extra.get("art", b.get("art", base))
            if k in OWN_ART:  # sheet not sliced yet: Enemy falls back at runtime
                d.update({"art": k, "art_fallback": fb})
                if tint:
                    d["fallback_tint"] = tint
            else:
                d["art"] = fb
                if tint:
                    d["tint"] = tint
        st = extra.get("status", b.get("status"))
        if st:
            d["status"] = st
        for kk in ("boss", "scale"):
            if kk in extra:
                d[kk] = extra[kk]
        if extra.get("boss"):
            d["dmg"] = max(d["dmg"], 3)
            d["xp"] = hp
            d["reward"] = BOSS_REWARD[tier]
            for a in ("enrage", "lunge"):
                if a not in d["abilities"]:
                    d["abilities"].append(a)
        else:
            d["reward"] = max(6, int(round(hp * NATIVE_HP[tier] * 0.3)))
            # drop value per raw hp ~DROP_PER_HP: scale every chance by one factor (capped at 1)
            ev = sum(c * n * ival.get(i, 0) for i, c, n in drops)
            if ev > 0:
                f = DROP_PER_HP * hp / ev
                drops = [[i, round(min(1.0, c * f), 3), n] for i, c, n in drops]
        E["enemies"][k] = d
        E["drops"][k] = drops
    # first-pass kinds renamed/replaced in CONDUCT 4 (no area spawns them any more)
    for old in ("gale_finargle",):
        E["enemies"].pop(old, None)
        E["drops"].pop(old, None)
    W("enemies.json", E)
    # forage
    F = J("forage.json")
    for aid, spec in AREAS.items():
        F.pop(aid, None)
        if spec.get("forage"):
            F[aid] = spec["forage"]
    W("forage.json", F)
    # quests
    Q = J("quests.json")
    Q["side"] = [q for q in Q["side"] if not str(q["id"]).startswith("mega_")]
    QL = J("quest_lines.json")
    for k in [k for k in QL if k.startswith("mega_")]:
        QL.pop(k)
    travel = {}
    for r in REGIONS:
        C = CONTENT[r["id"]]
        hk = C["hook"]
        Q["side"].append({"id": r["unlock"]["quest"], "giver": "gate_" + r["id"], "arc": r["arc"], "text": hk["text"], "when": {},
                          "done_when": {"items": hk["items"]}, "take": True, "reward": {"crystals": hk["crystals"], "flag": r["unlock"]["flag"]}})
        hub = AREAS[r["hub"]]
        job = hub["job"]
        jid = "mega_%s_job" % r["id"]
        Q["side"].append({"id": jid, "giver": job["giver"], "arc": r["arc"], "text": job["text"], "when": {"flag": r["unlock"]["flag"]},
                          "done_when": {"items": job["items"]}, "take": True, "reward": job["reward"]})
        QL[jid] = job["lines"]
        for xj in hub.get("extra_jobs", []):  # side jobs at the hub (Rahim's sunstones, c4_11 #5)
            Q["side"].append({"id": xj["id"], "giver": xj["giver"], "arc": r["arc"], "text": xj["text"], "when": {"flag": r["unlock"]["flag"]},
                              "done_when": {"items": xj["items"]}, "take": True, "reward": xj["reward"]})
            QL[xj["id"]] = xj["lines"]
        hreg = regs[r["hub"]]
        gate = next(t for t in hreg["things"] if t["type"] == "mega_gate")
        e = dict(r["entry"])
        e.update({"w": C.get("entry_w", 0), "keeper_at": C.get("keeper_at", [-2, 0]), "home_name": C["home_name"]})
        e.setdefault("spawn", [e["cell"][0], e["cell"][1] + 2])
        travel[r["id"]] = {"name": r["name"], "arc": r["arc"], "hub": r["hub"], "hub_name": C["hub_name"], "hub_spawn": [gate["cell"][0], gate["cell"][1] + 2],
                           "areas": [a["id"] for a in r["areas"]], "entry": e, "unlock": {"tier": r["unlock"]["tier"], "hint": {arc: "Opens " + t + "." for arc, t in TIER_STEP.get(r["unlock"]["tier"], {}).items()}}, "quest": r["unlock"]["quest"],
                           "keeper": C["keeper"], "keeper_sprite": C["keeper_sprite"], "lines": C["lines"], "mail": C["mail"], "sfx": C.get("sfx", "door")}
    check_ids(regs, I, E, Q, travel)
    W("quests.json", Q)
    W("quest_lines.json", QL)
    # recipes (kitchen keeps unknown recipes when gen_stations.py runs)
    RC = J("recipes.json")
    ids = {r["id"] for r in RECIPES}
    # Milk and eggs as families (#milk/#egg: goat milk and duck eggs count), exactly as
    # gen_stations.py writes kitchen needs, so the two generators agree in any order (c9_17).
    fam_recipes = []
    for r in RECIPES:
        r = json.loads(json.dumps(r))
        r["need"] = {({"milk": "#milk", "egg": "#egg"}.get(k, k)): n for k, n in r["need"].items()}
        fam_recipes.append(r)
    RC["kitchen"] = [r for r in RC["kitchen"] if r["id"] not in ids] + fam_recipes
    W("recipes.json", RC)
    json.dump({"_": "Written by tools/gen_mega_new.py (edit tools/mega_regions_new.py / gen_mega_new.py, not this).", "regions": travel},
              open(f"{D}/data/mega_travel.json", "w"), indent=1, ensure_ascii=False)
    print("mega regions:", len(REGIONS), "areas:", len(AREAS), "items:", len(ITEMS), "enemies:", len(ENEMIES))

if __name__ == "__main__":
    main()
