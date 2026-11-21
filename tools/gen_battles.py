#!/usr/bin/env python3
"""Conquest battlefields: big varied maps (plateaus, ramps, water, woods) with
control points. Adds/updates entries in data/regions.json and data/battles.json,
and writes scenes/<id>.tscn. Re-runnable.   python3 tools/gen_battles.py
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(os.path.dirname(__file__), "..")
R = json.load(open(D + "/data/regions.json"))

def scene(rid):
    open(D + "/scenes/%s.tscn" % rid, "w").write('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/region.gd" id="1"]\n\n[node name="%s" type="Node2D"]\nscript = ExtResource("1")\nregion_id = "%s"\n' % (rid, rid))

B = {}
BOSSES = {"bf_rail_yards": "lt_pike", "bf_dockside": "lt_ostrova", "bf_shattered_vale": "knight", "bf_frostfield": "big_grump"}
# Themed scatter per battlefield, so the long stretches between points aren't bare.
PROP_SETS = {"bf_frostfield": ["rock_snow_l", "rock_snow_m", "rock_snow_s", "boulder_m", "stump_snow", "bush_snow"],
             "bf_shattered_vale": ["boulder_l", "boulder_m", "crystal_rock", "mine_crystal_rock_1", "cave_stalag_m", "stalagmite_a"],
             "bf_rail_yards": ["drums", "tyres", "crates_a", "oil_drums"],
             "bf_dockside": ["crates_a", "crates_pallet", "barrel_a", "oil_drums"]}
# Catkins is penguin-only (Hearts.in_arc): a free field's brief in the gangster arc is
# spoken by the crew's own voice (Battle reads "who_<arc>" first; c9_14).
GANG_SPEAKER = {"Catkins": "Halo"}
def battle(rid, title, arc, tier, cols, rows, ground, patch, path, plateaus, water, points, enemies, props, crit, brief, who, win, lose, reward, back, music="battle", **kw):
    exits = [{"rect": [cols // 2 - 2, rows - 1, 4, 1], "scene": back[0], "spawn": back[1:], "facing": "down", "label": "▼ fall back"}]
    kept = {k: R[rid][k] for k in ("light",) if k in R.get(rid, {})}  # C5: hand/other-package keys (P2's fixed darkness) survive a rerun
    R[rid] = {"cols": cols, "rows": rows, "music": music, "backdrop": "mountains" if "snow" in (patch or "") or "frost" in rid else "hills", "ground": ground,
              "path": path, "spawn": [cols // 2, rows - 9], "pad": 7, "border": {"n": "cliff", "s": "trees", "w": "trees", "e": "cliff"},
              "exits": exits, "paths": kw.get("lanes") or [[cols // 2 - 1, rows // 2, 2, rows // 2 - 1], [6, rows // 2, cols - 12, 2]],
              "water_blobs": water, "plateaus": plateaus, "props": props, "patch_set": patch, "ground_threshold": 0.15, "fruit": 0,
              "gen": {"clumps": 10, "scatter": 110, "region_props": [n.split("/")[-1] for n in (kw.get("scatter") or PROP_SETS.get(rid) or ["boulder_m"])], "region_count": 90, "critters": crit, "critter_count": 6}, "forage": 0, "things": [], "enemies": [], "npcs": [],
              "battle": {"title": title, "who": who, "who_gangsters": GANG_SPEAKER.get(who, who), "brief": brief, "win": win, "lose": lose, "points": points, "enemies": enemies,
                         "tickets": 150, "supply": 15, "wave_every": 7.0, "enemy_cap": 16, "tier_bonus": max(0, tier - 2), "reward": reward, "back": back}}
    if patch is None:
        del R[rid]["patch_set"]
    R[rid].update(kept)
    for k in ("backdrop", "border", "ground_threshold", "ground_seam", "cliff_style", "border_trees", "water_shore", "light"):
        if k in kw:
            R[rid][k] = kw[k]
    if "theme" in kw:  # bf_themes scatter theme (WorldGen.theme)
        R[rid]["gen"]["theme"] = kw["theme"]
        if kw["theme"].get("trees") == []:
            R[rid]["gen"]["clumps"] = 0
            R[rid]["gen"]["scatter"] = 40  # decks, pavement, sewers: a few crates, not a junkyard
            R[rid]["gen"]["region_count"] = 60
    if rid in BOSSES:
        R[rid]["battle"]["boss"] = BOSSES[rid]
    B[rid] = {"title": title, "arc": arc, "tier": tier, "blurb": brief.split(".")[0] + "."}
    scene(rid)

# ---- penguin arc: crystal helpers ----------------------------------------------
battle("bf_frostfield", "Frostfield Front", "penguins", 2, 110, 88, "grass", "snowpatch", "stone",
       [{"blobs": [{"c": [24, 24], "r": 11, "seed": 101}, {"c": [34, 18], "r": 7, "seed": 102}]},
        {"blobs": [{"c": [86, 26], "r": 12, "seed": 103}]},
        {"blobs": [{"c": [55, 52], "r": 10, "seed": 104}, {"c": [64, 58], "r": 6, "seed": 105}]},
        {"blobs": [{"c": [86, 26], "r": 5, "seed": 106}]}],
       [{"c": [20, 62], "r": 7, "seed": 107, "fish": ["trout"]}, {"c": [92, 66], "r": 6, "seed": 108, "fish": ["trout"]}],
       [{"id": "a", "name": "Aurora Rise", "cell": [24, 22], "owner": "enemy"}, {"id": "b", "name": "Frozen Mill", "cell": [55, 30], "owner": "neutral"},
        {"id": "c", "name": "Glacier Shelf", "cell": [86, 24], "owner": "enemy"}, {"id": "d", "name": "Hollow Ridge", "cell": [56, 52], "owner": "neutral"},
        {"id": "e", "name": "Camp Catkins", "cell": [55, 78], "owner": "ally"}],
       ["grump", "ice_wisp", "crystal_baby", "hill_wolf", "shard"],
       [{"name": "stone_circle", "cell": [52, 28], "w": 4, "h": 2}],
       ["crow", "rabbit", "sparrow"],
       "The Dark Crystal's grumps hold the high ground over Frostfield. Take the ridges, raise crystal spires, and push them off the plateaus.",
       "Catkins", "Frostfield breathes again. The spires hum like a choir that finally found its note.", "Back to camp. The ridges will still be there tomorrow.",
       {"crystals": 400, "items": {"crystal_refined": 4, "aurora_blade": 1}}, ["town", 40, 60])
battle("bf_shattered_vale", "Shattered Vale", "penguins", 4, 118, 92, "grass", "ruinfloor", "stone",
       [{"blobs": [{"c": [30, 30], "r": 13, "seed": 111}]}, {"blobs": [{"c": [30, 30], "r": 6, "seed": 112}]},
        {"blobs": [{"c": [90, 34], "r": 12, "seed": 113}, {"c": [98, 26], "r": 6, "seed": 114}]},
        {"blobs": [{"c": [60, 60], "r": 9, "seed": 115}]}],
       [{"c": [60, 30], "r": 8, "seed": 116, "fish": ["mooncarp"]}],
       [{"id": "a", "name": "Shard Crown", "cell": [30, 29], "owner": "enemy"}, {"id": "b", "name": "Prism Lake", "cell": [60, 42], "owner": "neutral"},
        {"id": "c", "name": "Broken Gate", "cell": [92, 32], "owner": "enemy"}, {"id": "d", "name": "Vale Steps", "cell": [60, 60], "owner": "neutral"},
        {"id": "e", "name": "Sunken Shrine", "cell": [20, 70], "owner": "neutral"}, {"id": "f", "name": "Spire Camp", "cell": [70, 84], "owner": "ally"}],
       ["shard", "shard_spider", "prism_wisp", "geode_golem", "crystal_baby"],
       [{"name": "stone_circle", "cell": [58, 58], "w": 4, "h": 2}],
       ["crow", "owl"],
       "The Vale broke when the Dark Crystal fell through it. Its shards still march. Hold the six points and the shards will stop answering it.",
       "Catkins", "The shards in the Vale go quiet, then warm. Some of them follow your spires home.", "The Vale is too loud today. Rest and come back.",
       {"crystals": 900, "items": {"crystal_battery": 2, "prism_lance": 1}}, ["town", 40, 60])
# ---- gangster arc: drone helpers -------------------------------------------------
battle("bf_rail_yards", "The Rail Yards", "gangsters", 2, 112, 86, "grass", "track", "stone",
       [{"blobs": [{"c": [22, 22], "r": 10, "seed": 201}]}, {"blobs": [{"c": [90, 22], "r": 10, "seed": 202}]},
        {"blobs": [{"c": [56, 46], "r": 8, "seed": 203}]}],
       [{"c": [90, 64], "r": 6, "seed": 204, "fish": ["catfish"]}],
       [{"id": "a", "name": "Signal Tower", "cell": [22, 20], "owner": "enemy"}, {"id": "b", "name": "Coal Depot", "cell": [56, 26], "owner": "neutral"},
        {"id": "c", "name": "Water Tower", "cell": [90, 20], "owner": "enemy"}, {"id": "d", "name": "Turntable", "cell": [56, 46], "owner": "neutral"},
        {"id": "e", "name": "Your Boxcar", "cell": [56, 76], "owner": "ally"}],
       ["thug_brute", "thug_cyber", "thug_speedster", "soldier", "archer"],
       [{"name": "big_crane", "group": "buildings", "cell": [60, 24], "w": 3, "h": 3}, {"name": "container_red", "cell": [40, 40], "w": 2, "h": 1}, {"name": "container_blue", "cell": [72, 40], "w": 2, "h": 1}],
       ["crow", "sparrow"],
       "The President's people run the freight through the rail yards. Take the towers, set up drone bays, and the trains run for you.",
       "Halo", "The yard's yours. The night freight blows its whistle twice as it passes your boxcar.", "Pull back to the boxcar. We regroup.",
       {"crystals": 450, "items": {"servo": 6, "data_chip": 2}}, ["hideout", 26, 38])
battle("bf_dockside", "Dockside War", "gangsters", 4, 116, 90, "grass", "ruinfloor", "stone",
       [{"blobs": [{"c": [28, 28], "r": 11, "seed": 211}, {"c": [20, 20], "r": 5, "seed": 212}]}, {"blobs": [{"c": [90, 30], "r": 12, "seed": 213}]},
        {"blobs": [{"c": [90, 30], "r": 5, "seed": 214}]}],
       [{"c": [58, 60], "r": 12, "seed": 215, "fish": ["eel", "salmon"]}],
       [{"id": "a", "name": "Customs House", "cell": [28, 26], "owner": "enemy"}, {"id": "b", "name": "Crane Row", "cell": [58, 26], "owner": "neutral"},
        {"id": "c", "name": "Warehouse Nine", "cell": [90, 28], "owner": "enemy"}, {"id": "d", "name": "The Breakwater", "cell": [30, 62], "owner": "neutral"},
        {"id": "e", "name": "Ferry Slip", "cell": [92, 66], "owner": "neutral"}, {"id": "f", "name": "Your Trawler", "cell": [58, 82], "owner": "ally"}],
       ["thug_enforcer", "thug_cyber", "thug_flame", "thug_gambler", "rust_knight", "soldier"],
       [{"name": "warehouse_a", "group": "buildings", "cell": [86, 22], "w": 4, "h": 3}, {"name": "big_crane", "group": "buildings", "cell": [54, 22], "w": 3, "h": 3}],
       ["crow"],
       "The docks are where the President's money comes in. Six points, four of his crews. Bring drones, bring the crew, and hold the water.",
       "Marlene", "The harbour lights come on one by one, and every one of them is yours.", "The tide's against us. Back to the trawler.",
       {"crystals": 1000, "items": {"crystal_battery": 2, "tommy_gun": 1}}, ["hideout", 26, 38])
# ---- campaign fields (round 11): any arc can fight here ------------------------
def _rprops(region, extra=()):
    return list((R.get(region, {}).get("gen") or {}).get("region_props") or []) + list(extra)

PROP_SETS["bf_orchard_line"] = _rprops("orchard_hills") or ["boulder_m", "stump"]
PROP_SETS["bf_bog_crossing"] = _rprops("marsh") or ["boulder_m"]
PROP_SETS["bf_ash_wastes"] = _rprops("wastes") or ["boulder_m"]
PROP_SETS["bf_neon_block"] = _rprops("neon") or ["crates_a", "oil_drums"]
battle("bf_orchard_line", "The Orchard Line", "both", 1, 104, 84, "grass", "track", "dirt",
       [{"blobs": [{"c": [20, 22], "r": 10, "seed": 301}, {"c": [28, 16], "r": 6, "seed": 302}]},
        {"blobs": [{"c": [84, 22], "r": 10, "seed": 303}]},
        {"blobs": [{"c": [52, 50], "r": 7, "seed": 304}]}],
       [{"c": [86, 58], "r": 6, "seed": 305, "fish": ["trout"]}],
       [{"id": "a", "name": "Cider Press", "cell": [20, 20], "owner": "enemy"}, {"id": "b", "name": "Windbreak Row", "cell": [52, 28], "owner": "neutral"},
        {"id": "c", "name": "Old Granary", "cell": [84, 20], "owner": "enemy"}, {"id": "d", "name": "Beehive Hollow", "cell": [52, 50], "owner": "neutral"},
        {"id": "e", "name": "Wagon Camp", "cell": [52, 74], "owner": "ally"}],
       ["hill_wolf", "grump", "soldier", "archer"],
       [{"name": "stone_circle", "cell": [50, 26], "w": 4, "h": 2}],
       ["rabbit", "sparrow", "crow"],
       "Grumps have dug in among the apple rows. Take the press and the granary and the orchard is ours again.",
       "Catkins", "The orchard rows are quiet. Somebody's already picking apples.", "Back to the wagons. The apples will keep.",
       {"crystals": 300, "items": {"potion": 3, "copper_bar": 6}}, ["town", 40, 60], music="battle")
battle("bf_bog_crossing", "Bog Crossing", "both", 2, 108, 86, "grass", "bog", "dirt",
       [{"blobs": [{"c": [22, 24], "r": 9, "seed": 311}]}, {"blobs": [{"c": [88, 24], "r": 10, "seed": 312}]},
        {"blobs": [{"c": [86, 60], "r": 7, "seed": 313}]}],
       [{"c": [40, 44], "r": 8, "seed": 314, "fish": ["catfish"]}, {"c": [72, 42], "r": 7, "seed": 315, "fish": ["eel"]}, {"c": [14, 72], "r": 6, "seed": 316}],
       [{"id": "a", "name": "Witchlight Isle", "cell": [22, 22], "owner": "enemy"}, {"id": "b", "name": "Heron Causeway", "cell": [54, 30], "owner": "neutral"},
        {"id": "c", "name": "Drowned Mill", "cell": [88, 22], "owner": "enemy"}, {"id": "d", "name": "Frog Chorus", "cell": [24, 58], "owner": "neutral"},
        {"id": "e", "name": "Reed Fort", "cell": [86, 60], "owner": "neutral"}, {"id": "f", "name": "Raft Camp", "cell": [54, 76], "owner": "ally"}],
       ["mud_slime", "bog_hag", "river_serpent", "drip_crawler", "lantern_moth"],
       [{"name": "stone_circle", "cell": [52, 28], "w": 4, "h": 2}],
       ["frog", "heron", "dragonfly"],
       "The bog has more mouths than paths. Hold the causeways and the reeds, and the mire lets you through.",
       "Catkins", "The fog lifts off the bog like a lid. The frogs start singing again.", "The mire wins today. Back to the rafts.",
       {"crystals": 500, "items": {"greater_potion": 2, "iron_bar": 5}}, ["town", 40, 60])
battle("bf_ash_wastes", "The Ashen Flats", "both", 3, 110, 86, "dead_grass", None, "cracked_earth",
       [{"blobs": [{"c": [24, 20], "r": 11, "seed": 321}]}, {"blobs": [{"c": [90, 22], "r": 11, "seed": 322}, {"c": [98, 30], "r": 5, "seed": 323}]},
        {"blobs": [{"c": [56, 50], "r": 8, "seed": 324}]}],
       [{"c": [24, 62], "r": 5, "seed": 325}],
       [{"id": "a", "name": "Spike Gate", "cell": [24, 18], "owner": "enemy"}, {"id": "b", "name": "Glass Dunes", "cell": [56, 26], "owner": "neutral"},
        {"id": "c", "name": "Burnt Watchtower", "cell": [90, 20], "owner": "enemy"}, {"id": "d", "name": "Dry Well", "cell": [56, 50], "owner": "neutral"},
        {"id": "e", "name": "Lantern Camp", "cell": [56, 76], "owner": "ally"}],
       ["soldier", "archer", "wisp", "ash_hound"],
       [{"name": "stone_circle", "cell": [54, 48], "w": 4, "h": 2}],
       ["crow", "snake"],
       "Nothing grows on the Ashen Flats but trouble. Take the gate and the watchtower and the wind changes.",
       "Catkins", "The ash settles. Under it, something green is already trying.", "Pull back to the lanterns. The flats aren't going anywhere.",
       {"crystals": 700, "items": {"gold_bar": 3, "amethyst": 2}}, ["town", 40, 60],
       backdrop="night", border={"n": "cliff", "s": "trees", "w": "trees", "e": "cliff"}, ground_seam="ash")
battle("bf_neon_block", "The Neon Block", "gangsters", 3, 104, 84, "wet_asphalt_0", None, "neon_sidewalk",
       [{"blobs": [{"c": [22, 20], "r": 9, "seed": 331}]}, {"blobs": [{"c": [84, 20], "r": 9, "seed": 332}]},
        {"blobs": [{"c": [52, 48], "r": 6, "seed": 333}]}],
       [{"c": [86, 58], "r": 5, "seed": 334}],
       [{"id": "a", "name": "Dragon Sign", "cell": [22, 18], "owner": "enemy"}, {"id": "b", "name": "Night Market", "cell": [52, 26], "owner": "neutral"},
        {"id": "c", "name": "Pachinko Hall", "cell": [84, 18], "owner": "enemy"}, {"id": "d", "name": "The Overpass", "cell": [52, 48], "owner": "neutral"},
        {"id": "e", "name": "Laundromat Lot", "cell": [20, 60], "owner": "neutral"}, {"id": "f", "name": "Getaway Van", "cell": [52, 74], "owner": "ally"}],
       ["thug_speedster", "thug_gambler", "thug_cyber", "thug_flame", "thug_brute"],
       [{"name": "container_red", "cell": [36, 38], "w": 2, "h": 1}, {"name": "container_blue", "cell": [68, 38], "w": 2, "h": 1}],
       ["rat", "pigeon"],
       "Every sign on this block belongs to the President's crews. Switch them off one by one and the street is yours.",
       "Halo", "The block hums under your colours. The night market reopens before you've even left.", "Too hot tonight. Back to the van.",
       {"crystals": 700, "items": {"data_chip": 3, "servo": 6}}, ["hideout", 26, 38],
       backdrop="night", border={"n": "cliff", "s": "cliff", "w": "trees", "e": "cliff"}, ground_seam="pavement")

# ---- themed fields (CONDUCT 3 P4): one per region, see tools/bf_themes.py -------
import bf_themes
for _fid in list(bf_themes.OLD):
    bf_themes.tweak_old(R, _fid)

def _kinds0(region):
    _en = json.load(open(D + "/data/enemies.json"))["enemies"]
    out = []
    for e in R.get(region, {}).get("enemies", []):
        k = e if isinstance(e, str) else e.get("kind")
        if k in _en and not k.startswith(("lt_", "marked_", "cboss_")) and int(_en[k].get("hp", 0)) < 45 and k not in out:
            out.append(k)
    return out
bf_themes.build(battle, _kinds0, _rprops)
campaign_field = bf_themes.campaign_field

# ---- campaigns: every major region is opened by a strategic campaign -----------
# A board of 5-7 territories with branching routes; each battle node is a fight
# on a bf_* field with its own objective, points, waves and rewards; camps and
# caches are resolved on the board. Scripts: Campaign (rules, save under
# run["campaign"]), CampaignScreen (the board), Battle (node objectives).
import random
# Region-themed fields (P4, tools/bf_themes.py): each campaign fights on its own region's field.
try:
    import sys as _sys
    _sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from bf_themes import campaign_field
except ImportError:
    campaign_field = lambda r: None
EN = json.load(open(D + "/data/enemies.json"))["enemies"]
COL = json.load(open(D + "/data/colonies.json"))
IT = json.load(open(D + "/data/items.json"))
IT = IT.get("items", IT)

def _kinds(region):
    out = []
    for e in R.get(region, {}).get("enemies", []):
        k = e if isinstance(e, str) else e.get("kind")
        if k in EN and not k.startswith(("lt_", "marked_", "cboss_")) and int(EN[k].get("hp", 0)) < 45 and k not in out:
            out.append(k)
    return out

# Regions that each arc reaches (secrets.gd lists): penguins never see gang turf and vice versa.
# Tom 2026-11-19: the Wastes and the four island colonies are penguin-only.
PENG_ONLY = ["sky", "station", "jungle", "wastes", "colony_coral", "colony_kelp", "colony_ice", "colony_ember"]
GANG_ONLY = ["docks", "neon", "uptown", "underground", "countryside"]
SPEAK = {"penguins": "Catkins", "gangsters": "Halo"}
# Who leads each campaign (Tom C3: Catkins is not the voice of every campaign).
# A list of fallbacks; Campaign.who() picks the first one you have met ("pal" =
# whichever of Pip-Pip / Nova you are not playing). The order follows the book.
LEAD = {
    "orchard_hills": {"penguins": ["pal"], "gangsters": ["Sal"]},
    "highlands": {"penguins": ["Big Jim", "pal"], "gangsters": ["Sal"]},
    "quarry": {"penguins": ["pal"], "gangsters": ["Sal"]},
    "marsh": {"penguins": ["pal"], "gangsters": ["Sal"]},
    "riverlands": {"penguins": ["pal"], "gangsters": ["Halo", "Sal"]},
    "ruins": {"penguins": ["Catkins", "pal"], "gangsters": ["Halo", "Sal"]},
    "wastes": {"penguins": ["pal"]},
    "sky": {"penguins": ["Big Jim", "Coldy", "pal"]},
    "station": {"penguins": ["Coldy", "pal"]},
    "jungle": {"penguins": ["Catkins", "pal"]},
    "colony_coral": {"penguins": ["Grandmother Brine"]},
    "colony_kelp": {"penguins": ["Old Tidewhisker"]},
    "colony_ice": {"penguins": ["Coldy", "Captain Icewhisker"]},
    "colony_ember": {"penguins": ["Lady Cinderpaw"]},
    "countryside": {"gangsters": ["Sal"]},
    "docks": {"gangsters": ["Sal"]},
    "neon": {"gangsters": ["Halo", "Sal"]},
    "underground": {"gangsters": ["Halo", "Sal"]},
    "uptown": {"gangsters": ["Halo", "Sal"]},
}

# ---- Grumps: the penguin campaigns' foes (Tom C3) -----------------------------------
# Grumps were once Crystopia crystals that the Dark Crystal turned. Each variant
# has its own build from the shared enemy behaviours. Art "enemies/grump_<v>" (P4);
# until a sheet exists the plain grump is drawn with "fallback_tint" (Enemy).
GRUMPS = {
    "grump_crystal": {"name": "Crystal Grump", "hp": 18, "dmg": 2, "speed": 24, "tier": 2, "abilities": ["ranged", "shield"], "tint": "#9fe8ff", "scale": 1.15, "blurb": "tough, fires shard volleys"},
    "grump_storm": {"name": "Storm Grump", "hp": 12, "dmg": 2, "speed": 34, "tier": 2, "abilities": ["ranged", "blink"], "status": "weak", "tint": "#b47cff", "blurb": "violet lightning zaps"},
    "grump_frost": {"name": "Frost Grump", "hp": 10, "dmg": 1, "speed": 30, "tier": 1, "abilities": ["lunge"], "status": "slow", "tint": "#cdeeff", "blurb": "its bite slows you"},
    "grump_coral": {"name": "Coral Grump", "hp": 11, "dmg": 1, "speed": 30, "tier": 1, "abilities": ["regen", "lunge"], "tint": "#ff9a8a", "blurb": "mends itself when left alone"},
    "grump_ember": {"name": "Ember Grump", "hp": 12, "dmg": 2, "speed": 34, "tier": 2, "abilities": ["lunge", "enrage"], "status": "burn", "tint": "#ff8a3d", "blurb": "burns, and flares up when hurt"},
    "grump_moss": {"name": "Moss Grump", "hp": 9, "dmg": 1, "speed": 28, "tier": 1, "abilities": ["blink", "stomp"], "status": "slow", "tint": "#86c86e", "blurb": "ambushes and roots you"},
    "grump_brute": {"name": "Brute Grump", "hp": 30, "dmg": 3, "speed": 20, "tier": 3, "abilities": ["stomp", "enrage", "shield"], "tint": "#9a86c0", "scale": 1.6, "blurb": "big, slow, hits hard"},
    "grump_wisp": {"name": "Wisp Grump", "hp": 5, "dmg": 1, "speed": 58, "tier": 1, "abilities": ["blink"], "tint": "#efe6ff", "scale": 0.85, "blurb": "fast flyer"},
}
# Grump variants per penguin campaign region (first = most common), plus the
# other creatures that are simply native there.
GRUMP_AT = {
    "orchard_hills": ["grump", "grump_moss", "crystal_baby"], "highlands": ["grump_frost", "grump_wisp", "crystal_baby"],
    "quarry": ["grump_crystal", "grump_moss", "crystal_baby"], "marsh": ["grump_moss", "grump_coral"],
    "riverlands": ["grump_coral", "grump_storm"], "ruins": ["grump_crystal", "grump_storm", "grump_brute"],
    "wastes": ["grump_ember", "grump", "grump_crystal"], "sky": ["grump_storm", "grump_wisp", "grump_frost"],
    "station": ["grump_crystal", "grump_storm", "grump_wisp"], "jungle": ["grump_moss", "grump_coral", "grump_ember"],
    "colony_coral": ["grump_coral", "grump_wisp"], "colony_kelp": ["grump_coral", "grump_moss", "grump_storm"],
    "colony_ice": ["grump_frost", "grump_crystal", "grump_brute"], "colony_ember": ["grump_ember", "grump_brute", "grump_storm"],
}
# Named grump captains, one per penguin campaign (boss and gate nodes).
CAPTAINS = {
    "orchard_hills": ("Captain Bramblesnout", "grump_moss"), "highlands": ("Frostjaw", "grump_frost"),
    "quarry": ("Old Shardback", "grump_crystal"), "marsh": ("Mirewhisker", "grump_moss"),
    "riverlands": ("Tidegrudge", "grump_coral"), "ruins": ("Gloomcrown", "grump_storm"),
    "wastes": ("Cinderhowl", "grump_ember"), "sky": ("Stormcrest", "grump_storm"),
    "station": ("Prismjaw", "grump_crystal"), "jungle": ("Thornmaw", "grump_moss"),
    "colony_coral": ("Reefgrudge", "grump_coral"), "colony_kelp": ("Murkfin", "grump_coral"),
    "colony_ice": ("Hailbrute", "grump_brute"), "colony_ember": ("Ashmaw", "grump_ember"),
}
# Named gang captains, one per campaign the gangster arc fights (C16b P5: c16b_03-01/02,
# 05-02, 18-01, 18-10, 04-05). Built on a thug's character strip ("char") with its own
# tint and scale; never blink (a captain should stand and be fought). All ages: they
# back off and leave, nobody is hurt.
GANG_CAPTAINS = {
    "orchard_hills": ('Harlan "Hayride" Voss', "thug_brute", "#d9a35c"),
    "countryside": ("Road Boss Dutch", "thug_brute", "#e0c060"),
    "highlands": ("Ridge Boss Kestrel", "thug_enforcer", "#9fb8d8"),
    "quarry": ("Crusher Kade", "thug_brute", "#c8b090"),
    "marsh": ("Smuggler Queen Rook", "thug_gambler", "#7fd0a0"),
    "riverlands": ("Toll Man Dukes", "thug_cyber", "#7fc8ff"),
    "ruins": ("The Curator", "thug_flame", "#c9a0ff"),
    "docks": ("Ironside Mae", "thug_enforcer", "#ff9a6a"),
    "neon": ("Neon Sable", "thug_flame", "#ff6ad5"),
    "underground": ("Old Pipes Mulgrew", "thug_enforcer", "#a0c070"),
    "uptown": ("Mr. Gilt", "thug_enforcer", "#ffd760"),
}
# Gang foes by campaign tier (C16b P5: c16b_03-03, 05-03, 18-02, 18-20, 04-01): people
# only, never wildlife or monsters; layer 1 opens soft, deeper layers add the tier's
# own kinds, the gate brings one signature kind. Region extras join from layer 2.
GANG_ROSTER = {
    1: {1: ["thug_lookout", "thug_speedster"], 2: ["thug_brute"], 3: ["thug_cyber"]},
    2: {1: ["thug_speedster", "thug_cyber", "thug_gambler"], 2: ["thug_brute"], 3: ["thug_flame"]},
    3: {1: ["thug_cyber", "thug_gambler", "thug_flame"], 2: ["thug_brute"], 3: ["thug_enforcer"]},
    4: {1: ["thug_flame", "thug_brute", "thug_gambler"], 2: ["thug_enforcer"], 3: ["rust_knight"]},
    5: {1: ["thug_flame", "thug_brute", "thug_enforcer"], 2: ["rust_knight"], 3: ["gilt_guard"]},
}
GANG_REGION_FOES = {"uptown": ["gilt_runner", "gilt_guard"], "docks": ["rust_knight"], "underground": ["coal_crawler"]}
# Display names for the thugs (C16b P5: c16b_03-09, 18-15); "blurb" is the board tag.
THUG_NAMES = {"thug_speedster": ("Street Runner", "fast, darts in"), "thug_brute": ("Heavy", "big, hits hard"),
              "thug_cyber": ("Goggles Lookout", "shoots, dazzles"), "thug_gambler": ("Trickster", "shoots, vanishes"),
              "thug_enforcer": ("Enforcer", "shielded, stomps"), "thug_flame": ("Flare Crew", "throws flares"),
              "thug_lookout": ("Lookout", "just watching"), "rust_knight": ("Rust Knight", "shielded, charges"),
              "drip_crawler": ("Drip Crawler", "spits from range")}
def _gang_roster(tier, layer, region, gate):
    R_ = GANG_ROSTER[min(5, max(1, tier))]
    out = list(R_[1])
    if layer >= 2:
        out += R_[2] + GANG_REGION_FOES.get(region, [])
    if gate or layer >= 4:
        out += R_[3]
    return [k for k in dict.fromkeys(out) if k in EN]
# Penguin campaigns never field the gangster-world soldiers.
NOT_PENGUIN = ("soldier", "archer", "knight")
# Gangster campaigns field thugs, never the penguin-world soldiers/grumps (c4_17 #7).
GANG_FOES = {"soldier": "thug_speedster", "archer": "thug_gambler", "knight": "thug_enforcer", "grump": "thug_cyber"}
def gang_kind(k):
    return "thug_cyber" if k.startswith("grump") else GANG_FOES.get(k, k)
# Crystal Kin (Tom C3): crystal babies start as foes; after a campaign battle with
# them, proving your purpose (a gift, or Meow Pow Wow) turns them into a helper
# kind you can raise at spawners. HelperUnit reads "_helper_kinds" generically.
KIN = {"crystal_kin": {"crystal": "Crystal Kin", "drone": "Crystal Kin", "hp": 30, "colour": "9fe8ff", "act": "striker", "arc": "penguins",
               "flag": "crystal_kin", "art": "enemies/crystal_baby", "cost": 20, "does": "stomps foes"}}
KIN_GIFT = {"item": "crystal_refined", "n": 2}

def _write_grumps():
    EJ = json.load(open(D + "/data/enemies.json"))
    E = EJ["enemies"]
    for k, g in GRUMPS.items():
        e = {"hp": g["hp"], "dmg": g["dmg"], "speed": g["speed"], "xp": 3 + 3 * g["tier"], "tier": g["tier"], "abilities": list(g["abilities"]),
             "name": g["name"], "reward": 2 + 3 * g["tier"], "art": k, "art_fallback": "grump", "fallback_tint": g["tint"], "grump": True}
        if g.get("status"):
            e["status"] = g["status"]
        if g.get("scale"):
            e["scale"] = g["scale"]
        E[k] = e
        EJ["drops"][k] = [["grump_dust", 0.7, 1], ["shard", 0.25, 1], ["fiber", 0.2, 1]]
    for reg, (nm, base) in CAPTAINS.items():
        g = GRUMPS[base]
        t = next(c[1] for c in CAMPS if c[0] == reg)
        ab = list(dict.fromkeys(g["abilities"] + ["enrage"]))
        e = {"hp": 14 + 8 * t, "dmg": 1 + (t + 1) // 2, "speed": max(20, g["speed"] - 4), "xp": 12 + 8 * t, "tier": t, "abilities": ab, "name": nm,
             "reward": 8 + 6 * t, "boss": True, "art": base, "art_fallback": "grump", "fallback_tint": g["tint"], "scale": round(g.get("scale", 1.0) * 1.35, 2), "grump": True}
        if g.get("status"):
            e["status"] = g["status"]
        E["gcap_" + reg] = e
        EJ["drops"]["gcap_" + reg] = [["grump_dust", 1.0, 3], ["shard", 1.0, 2], ["light_mote", 0.3, 1]]
    for k, (nm, blurb) in THUG_NAMES.items():
        if k in E:
            E[k]["name"] = nm
            E[k]["blurb"] = blurb
    for reg, (nm, base, tint) in GANG_CAPTAINS.items():
        g = E[base]
        t = next(c[1] for c in CAMPS if c[0] == reg)
        ab = [a for a in dict.fromkeys(list(g.get("abilities", [])) + ["enrage"]) if a != "blink"]
        e = {"hp": max(int(g.get("hp", 10)), 14 + 8 * t), "dmg": 1 + (t + 1) // 2, "speed": min(40, max(20, int(g.get("speed", 30)) - 4)),
             "xp": 12 + 8 * t, "tier": t, "abilities": ab, "name": nm, "reward": 8 + 6 * t, "boss": True,
             "char": base.replace("thug_", ""), "tint": tint, "scale": 1.3, "gang_captain": True}
        if g.get("status"):
            e["status"] = g["status"]
        E["gcap_g_" + reg] = e
        EJ["drops"]["gcap_g_" + reg] = [["rounds", 1.0, 6], ["data_chip", 0.3, 1], ["cherry_fizz", 0.5, 1]]
    json.dump(EJ, open(os.environ.get("DRY_OUT", D + "/data") + "/enemies.json", "w"), indent=1, ensure_ascii=False)
    return E
# What you sense at the edge of a region its campaign still holds (Campaign.gate_words
# adds the step that's actually next). One line per arc that reaches the region.
SENSE = {
    "orchard_hills": {"penguins": "Branches creak where there's no wind, and small grumpy eyes blink from every orchard row.",
                      "gangsters": "A car with its lights off sits at the top of the orchard road. Then you spot a second one."},
    "highlands": {"penguins": "A howl rolls down off the ridge, and the heather lies flat as if something huge just lay down on it.",
                  "gangsters": "Engines idle up on the ridge. Someone has a lookout on every switchback."},
    "quarry": {"penguins": "The ground rumbles. Rocks shift on their own, and something in the dust is breathing.",
               "gangsters": "A rock crusher starts up with nobody at the controls. The quarry's taken, and they don't want visitors."},
    "marsh": {"penguins": "Fog rolls over your boots and a hundred frogs stop singing at once. Something in the reeds is waiting.",
              "gangsters": "Headlights blink twice across the bog, then go dark. That's a signal, and it isn't for you."},
    "riverlands": {"penguins": "For a moment the river runs the wrong way. Grump tracks line both banks.",
                   "gangsters": "Every bridge has a car parked across it with the engine running."},
    "ruins": {"penguins": "The old stones hum with a cold purple light. Whatever guards the ruins is wide awake.",
              "gangsters": "Floodlights sweep the old ruins. Somebody has turned them into a fortress."},
    "wastes": {"penguins": "The air tastes of ash and the black stones hum. Out there, Grumps march in rows like soldiers.",
               "gangsters": "Dust devils, and inside them, motorbikes. The President's patrols ride the Wastes."},
    "sky": {"penguins": "The wind up the cloud stair sings a warning, and armour glints on every step."},
    "station": {"penguins": "A cold hum comes down from the station, and its lights blink in Grump colours."},
    "jungle": {"penguins": "The green planet's trees lean toward you, and the shadows under them move."},
    "colony_coral": {"penguins": "The reef glows the wrong colour, and every fish has gone quiet.",
                     "gangsters": "Speedboats circle the reef, slowly, the way sharks do."},
    "colony_kelp": {"penguins": "The kelp sways against the tide. Something big is hiding in it.",
                    "gangsters": "Searchlights cut through the kelp. Someone is guarding a shipment out there."},
    "colony_ice": {"penguins": "Frost cracks across the water toward you, and the ice groans like a giant waking up.",
                   "gangsters": "Floodlit ice, a fence of oil drums, and guards stamping their feet to keep warm."},
    "colony_ember": {"penguins": "Smoke hangs over the atoll and the sea hisses where lava meets it. Grump drums, far off.",
                     "gangsters": "Smoke, sirens, and a flag you don't like on the atoll's highest rock."},
    "countryside": {"gangsters": "A roadblock of parked trucks. Somebody whistles, and three more doors open."},
    "docks": {"gangsters": "Crates move with nobody carrying them, and every crane on the docks has a lookout."},
    "neon": {"gangsters": "The neon flickers in a pattern. Someone is telling the whole district you're coming."},
    "uptown": {"gangsters": "Private security on every corner, and every earpiece turns your way."},
    "underground": {"gangsters": "Water drips, and under it, footsteps that stop whenever yours do."},
}
REWARD_ITEMS = {1: {"potion": 3, "copper_bar": 5}, 2: {"greater_potion": 2, "iron_bar": 5}, 3: {"gold_bar": 3, "crystal_refined": 3},
                4: {"crystal_battery": 2, "ruby": 1, "sapphire": 1}, 5: {"crystal_battery": 3, "gold_bar": 6, "emerald": 1}}
ARC_ITEMS = {"penguins": {"crystal_refined": 2}, "gangsters": {"servo": 4, "data_chip": 1, "rounds": 40}}
# Tier-3 node rewards: refined crystal is a penguin thing; gangsters get parts.
# Fantasy heals swap for the gang's sodas (C16b P5: c16b_03-10, 18-13).
GANG_SWAP = {"crystal_refined": "data_chip", "potion": "cherry_fizz", "greater_potion": "golden_float"}
# Items a campaign both arcs share may pay on a battle node (no potions or crystals: those are one arc's).
SHARED_OK = ("copper_bar", "iron_bar", "gold_bar", "ruby", "sapphire", "emerald", "crystal_battery")
# Gate win money by tier (C16b P5: c16b_17-05; was 500 + 400 * tier = 900/1300/1700/2100/2500).
GATE_PAY = {1: 900, 2: 2000, 3: 3600, 4: 6000, 5: 9000}
# Node pay curve by tier (was 0.6 + 0.4 * tier = 1.0/1.4/1.8/2.2/2.6).
def _pay_k(tier):
    return 0.5 + 0.5 * tier ** 1.5
# Cache goods: a low item, never the tier's top one (C16b P5: c16b_04-04, 05-08).
CACHE_ITEMS = {1: {"potion": 2}, 2: {"potion": 3}, 3: {"greater_potion": 1}, 4: {"greater_potion": 1}, 5: {"greater_potion": 2}}
# (region, tier, after, title, fields, boss, start camp, names[7], intro, won)
CAMPS = [
    ("orchard_hills", 1, [], "The Orchard Road", ["bf_orchard_line"], "big_grump", "Forest Edge Camp",
     ["Bramble Gap", "Fallen Fence", "Honey Cellars", "Picker's Rest", "Crab-Apple Ridge", "Long Barn", "The Cider Press"],
     "The road north runs through the orchards, and the orchards are full of grumps. Push them out row by row.",
     "The orchard road is open. The trees seem to stand a little straighter."),
    ("highlands", 2, ["orchard_hills"], "Highland March", {"penguins": ["bf_frostfield", "bf_orchard_line"], "gangsters": ["bf_orchard_line", "bf_rail_yards"]}, "hill_wolf", "Hilltop Bivouac",
     ["Wolf Run", "Cairn Field", "Shepherd's Hut", "Windy Saddle", "Frostbite Ledge", "Howling Tor", "The High Gate"],
     "The highland passes are held by wolves and winter wisps. Climb, hold the ledges, and the high country opens.",
     "The highland gate swings open. The wind up here sounds almost friendly now."),
    ("quarry", 2, [], "Quarry Breakers", {"penguins": ["bf_shattered_vale", "bf_ash_wastes"], "gangsters": ["bf_rail_yards", "bf_ash_wastes"]}, "quarry_golem", "Beach Road Camp",
     ["Rubble Gate", "Crane Pit", "Echo Shaft", "Foreman's Hut", "Slag Hill", "Crab Steps", "The Deep Cut"],
     "Golems have taken the quarry roads. Break their lines and the old cutters' paths are ours.",
     "The quarry falls quiet. Somewhere below, a golem sets its hammer down."),
    ("marsh", 2, [], "Into the Mire", ["bf_bog_crossing"], "bog_hag", "Dune Grass Camp",
     ["Reedbank", "Lily Causeway", "Witch's Larder", "Dry Hummock", "Sunken Chapel", "Mosswater", "Witchlight Isle"],
     "Fog, frogs and bog hags. Find firm ground, hold it, and walk the causeways into the marsh.",
     "The marsh mists part. The frogs sing you through."),
    ("riverlands", 2, ["marsh"], "Riverlands Run", ["bf_bog_crossing", "bf_orchard_line"], "river_serpent", "Marsh Ferry Camp",
     ["Ferry Steps", "Willow Bend", "Otter Holt", "Ford of Stones", "Mill Race", "Serpent Pool", "The Weir"],
     "River serpents have the fords. Escort the ferry stores, take the weir, and the river is ours to cross.",
     "The weir is open and the river runs easy. Fish jump all the way upstream."),
    ("ruins", 3, ["quarry"], "Ruin Siege", {"penguins": ["bf_shattered_vale", "bf_ash_wastes"], "gangsters": ["bf_ash_wastes", "bf_rail_yards"]}, "ruin_guardian", "Meadow Gate Camp",
     ["Broken Stair", "Moss Court", "Hall of Pillars", "Scribes' Rest", "Toppled Arch", "Guardian Walk", "The Star Arch"],
     "The ruins have guardians, and the guardians have never let anyone in. Be the first.",
     "The guardians lower their stone heads. The arch is open."),
    ("wastes", 1, [], "Across the Wastes", ["bf_ash_wastes"], "obsidian_sentinel", "Standing Stones Camp",
     ["Dead Tree Line", "Spike Field", "Lantern Well", "Bone-Dry Gully", "Rusted Outpost", "Ash Ridge", "The Wastes Gate"],
     "Past the standing stones the land goes grey. Ember Grumps march in rows from the old outposts. Free the gate and the wastes are open.",
     "The wastes gate creaks open. The grey land waits, quieter than before."),
    ("sky", 3, ["wastes", "highlands"], "The Cloud Stair", ["bf_frostfield", "bf_shattered_vale"], "knight", "Summit Camp",
     ["Cloudfoot", "Ice Ladder", "Prism Shelf", "Finargle Roost", "Star Ledge", "Thin Air Fort", "The Sky Stair"],
     "Above the clouds the mountain keeps climbing. Storm Grumps crackle on every ledge. Climb it battle by battle, and bring them home.",
     "The sky stair is yours. The clouds part under your feet like a carpet."),
    ("station", 4, ["sky"], "Station Approach", ["bf_shattered_vale", "bf_frostfield"], "geode_golem", "Moonlit Pad",
     ["Docking Ring", "Airlock Row", "Hydro Bay", "Crew Galley", "Solar Wing", "Reactor Walk", "The Command Deck"],
     "The station drifts dark, and shards crawl its corridors. Take it ring by ring.",
     "The station lights come on, one deck at a time. Somebody left the radio playing."),
    ("jungle", 4, ["station"], "Green Planet Landing", ["bf_bog_crossing", "bf_shattered_vale"], "shard_spider", "Landing Zone",
     ["Fern Wall", "Glow Pool", "Vine Bridge", "Flower Canopy", "Spore Hollow", "Root Temple", "The Heart Grove"],
     "The green planet's jungle is thick with shards. Cut a way in, one clearing at a time.",
     "The jungle opens. The giant flowers turn to watch you pass, and they seem pleased."),
    ("colony_coral", 2, [], "Reef Rescue", {"penguins": ["bf_bog_crossing"], "gangsters": ["bf_dockside", "bf_bog_crossing"]}, "river_serpent", "Boat Landing",
     ["Shell Beach", "Tide Pools", "Crab Kingdom", "Pearl Cove", "Coral Arch", "Wreck Point", "The Reef Gate"],
     "The coral colony is cut off by crabs and serpents. Fight your way across the reef to reach them.",
     "The reef gate opens. The merkitties are waving from the shore."),
    ("colony_kelp", 3, ["colony_coral"], "Kelp Forest Crossing", {"penguins": ["bf_bog_crossing", "bf_frostfield"], "gangsters": ["bf_dockside", "bf_bog_crossing"]}, "void_eel", "Driftwood Raft",
     ["Kelp Edge", "Bubble Field", "Sunken Bell", "Eel Narrows", "Glow Shallows", "Black Tide Bar", "The Kelp Gate"],
     "The kelp forest is dark and full of eels. Light a path through and the colony can breathe.",
     "The kelp sways open. Little lights blink on all along the path."),
    ("colony_ice", 4, ["colony_kelp"], "Frozen Isle Landing", ["bf_frostfield"], "geode_golem", "Ice Floe Camp",
     ["Snowdrift Beach", "Seal Rocks", "Frost Chapel", "Aurora Field", "Glacier Mouth", "Winter Den", "The Ice Gate"],
     "Hollow Winter has frozen the island solid. Break the ice walls and reach the colony.",
     "The ice gate cracks and melts. The colony sends out hot cocoa."),
    ("colony_ember", 5, ["colony_ice"], "Ember Isle Assault", ["bf_ash_wastes"], "ash_hound", "Cinder Cove",
     ["Ash Shore", "Smoke Hollow", "Lava Bridge", "Ember Market", "Cinder Cone", "Hound Kennels", "The Ember Gate"],
     "The ember island smoulders. Ash hounds patrol the bridges. Cross, hold, and reach the last colony.",
     "The smoke clears from the ember isle. Above it, real stars."),
    ("countryside", 1, [], "The Highway Job", ["bf_orchard_line", "bf_rail_yards"], "thug_speedster", "Motel Lot",
     ["Billboard Bend", "Gas Station", "Truck Stop", "Diner Booth", "Toll Booth", "Overpass", "The Long Highway"],
     "The highway out of the hideout is watched by the President's lookouts. Take the road back, stop by stop.",
     "The highway is clear. A trucker honks twice as he passes. That means thank you."),
    ("docks", 2, ["countryside"], "Dockside Push", ["bf_dockside", "bf_rail_yards"], "rust_knight", "Back Alley",
     ["Fish Market", "Net Lofts", "Bonded Store", "Tugboat Yard", "Pier Six", "Customs Shed", "The Harbour Gate"],
     "The docks are the President's front door. Every pier is guarded. Take them one by one.",
     "The harbour gate is yours. The gulls sound like they're laughing at somebody else for once."),
    ("neon", 3, ["docks"], "Neon Nights", ["bf_neon_block", "bf_rail_yards"], "thug_flame", "Harbour Stairs",
     ["Noodle Row", "Arcade Alley", "Karaoke Box", "Rooftop Garden", "Signal Bridge", "Dragon Court", "The Neon Gate"],
     "Every block in Neon answers to a sign, and every sign answers to the President. Take the blocks back, street by street.",
     "The neon gate flickers to your colours. The whole street hums along."),
    ("uptown", 4, ["underground"], "Uptown Assault", ["bf_neon_block", "bf_dockside"], "thug_enforcer", "Neon Overpass",
     ["Lawn Terrace", "Fountain Plaza", "Gallery Steps", "Valet Ramp", "Glass Atrium", "Tower Gardens", "The Tower Gate"],
     "Uptown is all lawns, glass and guards. Take the plazas and the tower road opens.",
     "The tower gate stands open. Up close, the tower looks smaller."),
    ("underground", 4, ["neon"], "Down the Manhole", ["bf_neon_block", "bf_rail_yards"], "drip_crawler", "Manhole Camp",
     ["Drip Tunnel", "Pipe Junction", "Old Platform", "Rat King's Hall", "Pump Room", "Sluice Gate", "The Pit Door"],
     "Under Neon the tunnels go on for miles. Crawlers and the President's crews hold every junction.",
     "The pit door grinds open. Down here, your name echoes."),
]

# Gangster lines for the campaigns both arcs share (the CAMPS text is the penguin one).
GANG_TEXT = {
    "orchard_hills": ("The President's lookouts have the orchard road. Every row of trees hides a parked car. Push them out, row by row.",
                      "The orchard road is ours. The lookouts drove off in a hurry, and the pickers are waving from the ladders."),
    "highlands": ("Up on the ridge the President's crews watch every switchback. Climb, take the lookouts, and the high country is open.",
                  "The high gate is ours. Up here the radio finally gets a signal, and it's playing our song."),
    "quarry": ("A crew runs the quarry like a fort: crushers, floodlights, guards on every ledge. Shut it down, pit by pit.",
               "The crushers go quiet. The quarry workers come back to their own jobs, and nobody takes a cut."),
    "marsh": ("Smugglers run boats through the marsh at night. Find their landings, take them, and the causeways are ours.",
              "The marsh landings are ours. The frogs are louder than the outboard motors now."),
    "riverlands": ("Every bridge over the river has a car parked across it. Clear the bridges and the river roads open.",
                   "The bridges are clear. Trucks roll across the river again, and nobody pays a toll."),
    "ruins": ("Someone turned the old ruins into a fortress: floodlights, fences, a guard at every arch. Get in where nobody has.",
              "The floodlights go dark one by one. The ruins are quiet, and they belong to everyone again."),
}
# Gang-arc territory names for the shared campaigns (C16b P5: c16b_18-03); written as
# node["name_gangsters"] (Campaign/CampaignScreen show it in the gang arc).
NAMES_GANG = {
    "orchard_hills": ["Packing Shed", "Fallen Fence", "Fruit Stand", "Picker's Rest", "Ridge Lay-by", "Long Barn", "The Cider Works"],
    "highlands": ["Switchback One", "Cairn Lay-by", "Shepherd's Hut", "Windy Saddle", "Radio Mast", "Lookout Tor", "The High Gate"],
    "quarry": ["Rubble Gate", "Crane Pit", "Crusher House", "Foreman's Hut", "Slag Hill", "Truck Ramp", "The Deep Cut"],
    "marsh": ["Bait Shack", "Plank Causeway", "Boat Shed", "Dry Hummock", "Old Pump House", "Airboat Dock", "Smugglers' Landing"],
    "riverlands": ["Ferry Steps", "Willow Bend", "Bridge Two", "Ford of Stones", "Mill Race", "Toll Bridge", "The Weir"],
    "ruins": ["Broken Stair", "Floodlight Court", "Hall of Pillars", "Guard Hut", "Toppled Arch", "Fence Walk", "The Star Arch"],
}
# Region labels where the map name differs from the colony/region data (c16b_03-08).
REGION_NAME = {"countryside": "The Highway"}
# ---- The long way (C16b contract section 2; P3's Campaign.long_way reads it) ---------
# Every campaign has a non-battle way into its region, both arcs, all ages: it opens
# the region and its story exactly as a win does, but pays none of the win rewards.
# kind: quest (a short favour), toll (pay and walk), travel (a guide or a ride),
# story (a scene that finds another way). Cost scales with tier (LONG_COST).
LONG_COST = {1: {"money": 150, "items": {"wood": 15}}, 2: {"money": 400, "items": {"copper_bar": 2}},
             3: {"money": 900, "items": {"iron_bar": 3}}, 4: {"money": 1600, "items": {"iron_bar": 4, "gold_bar": 1}},
             5: {"money": 2600, "items": {"gold_bar": 3}}}
LONG_WAY = {
    "orchard_hills": ("quest", ["Help the orchard keeper mend the back fence", "Follow the pickers' path round the rows"],
                      "The orchard keeper knows a pickers' path round the back rows. Mend her fence first and she'll walk you through.",
                      "The old orchard keeper hates the lookouts too. Fix her fence and she'll show you the farm track nobody watches."),
    "countryside": ("quest", ["Fetch a spare tyre for the stranded trucker", "Ride in his cab past the roadblock"],
                    None, "A trucker is stuck at the motel with a flat. Bring him a spare tyre and he'll take you past the roadblock in his cab."),
    "highlands": ("travel", ["Pay the shepherd for a guide", "Take the sheep trail over the saddle"],
                  "Big Jim's shepherd friend knows a sheep trail over the saddle. It's long and windy, but nobody guards it.",
                  "A shepherd up the valley runs sheep over the saddle every week. Pay her for the trip and walk up with the flock."),
    "quarry": ("toll", ["Pay the cutters' toll", "Walk the old cutters' path into the pit"],
               "The old stone cutters still keep a path along the cliff. Pay their toll and they'll open the gate for you.",
               "The quarry workers keep their own gate at the back. Pay their union fee and they'll let you in with the morning shift."),
    "marsh": ("travel", ["Hire a flat-bottom boat", "Pole through the reeds at dawn"],
              "A frog-catcher hires out a flat-bottom boat. Pole through the reeds at dawn, when the bog is quiet.",
              "A bait-shack owner rents airboats by the hour. Pay up and slip through the reeds before the smugglers wake up."),
    "riverlands": ("toll", ["Pay the ferry keeper", "Cross on the night ferry"],
                   "The ferry keeper still runs one boat at night. Pay the fare and cross while the river sleeps.",
                   "The ferry still runs one late boat. Pay the fare and cross while the bridge crews are changing shifts."),
    "ruins": ("quest", ["Bring the scribe three old rubbings", "Take the scribes' tunnel under the arch"],
              "An old scribe knows a tunnel under the arch. Bring her paper and charcoal for her rubbings and she'll lead the way.",
              "A night watchman at the ruins wants out. Bring him the supplies he asks for and he'll unlock the service gate."),
    "wastes": ("story", ["Ask the standing stones' keeper for the old road", "Walk the ash road by lantern light"],
               "The keeper of the standing stones remembers an ash road from before the Grumps. Carry a lantern and walk it at night.",
               "An old prospector draws you a map of a dry road round the patrols. It's slow going, but it gets you there."),
    "sky": ("travel", ["Pay Finargle's balloon fare", "Float up past the cloud stair"],
            "Finargle's balloon goes up past the cloud stair on clear days. Pay the fare, hold on, and don't look down.", None),
    "station": ("story", ["Help Coldy fix the old shuttle", "Dock at the back airlock"],
                "Coldy thinks the old shuttle still flies. Help fix it and you can dock at the back airlock, where nobody's looking.", None),
    "jungle": ("travel", ["Pay for a seat on the supply pod", "Land in the quiet clearing"],
               "A supply pod lands in a quiet clearing once a week. Buy a seat and you're down below the canopy.", None),
    "colony_coral": ("travel", ["Pay the boatman", "Sail round the reef at high tide"],
                     "At high tide a boat can slip round the reef. The boatman knows when. Pay him and sail round.", None),
    "colony_kelp": ("quest", ["Bring the colony lamps for the dark path", "Follow the lamps through the kelp"],
                    "The colony would light a path through the kelp if someone brought them lamp oil and wicks.", None),
    "colony_ice": ("travel", ["Pay the icebreaker's captain", "Ride in the icebreaker's wake"],
                   "An icebreaker cuts a channel to the island every few days. Pay the captain and ride in its wake.", None),
    "colony_ember": ("story", ["Ask Lady Cinderpaw for the cool path", "Cross the old stone bridge at low smoke"],
                     "Lady Cinderpaw remembers a cool stone bridge where the lava never reaches. Cross it when the smoke is low.", None),
    "docks": ("toll", ["Pay the harbour pilot", "Come in by the fishing boats' slip"],
              None, "A harbour pilot owes Sal a favour, almost. Pay the rest and come in with the fishing boats at dawn."),
    "neon": ("quest", ["Fix the arcade owner's sign", "Walk through the back of the arcade"],
             None, "The arcade owner's sign keeps blowing a fuse. Fix it and she'll let you through the back door onto the next block."),
    "underground": ("story", ["Buy Sal's old sewer map", "Follow the map through the dry tunnels"],
                    None, "Sal still has a sewer map from the old days. It costs, but it shows dry tunnels the crews forgot about."),
    "uptown": ("story", ["Get a caterer's uniform", "Walk in through the service entrance"],
               None, "Every party uptown needs caterers. Rent a uniform, carry a tray, and walk right in through the service entrance."),
}
def _long_way(region, tier, arcs):
    kind, steps, pt, gt = LONG_WAY[region]
    lw = {"kind": kind, "id": "lw_" + region, "cost": {"money": LONG_COST[tier]["money"], "items": dict(LONG_COST[tier]["items"])},
          "steps": list(steps), "text": pt or gt, "text_gang": gt or pt, "unlock_after": "always"}
    return lw
# What each tier adds to the banner menu (C16b P5: c16b_04-02, 02-13, 05-10); Battle
# (P1) reads _campaigns.unlocks to tier-gate builds, the briefing names what is new.
UNLOCKS = {1: {"builds": ["striker", "healer"], "orders": ["mend"], "words": "Strikers, healers and mending"},
           2: {"builds": ["warden"], "orders": ["upgrade", "fortify"], "words": "Wardens, upgrades and fortify"},
           3: {"builds": ["shade", "turret"], "orders": ["barrage"], "words": "Shades, turrets and barrage"},
           4: {"builds": [], "orders": [], "words": ""}, 5: {"builds": [], "orders": [], "words": ""}}
# Point names per arc / region, where a battlefield's own names don't fit.
POINT_NAMES = {
    ("gangsters", "*", "bf_orchard_line"): {"a": "Old Silo", "c": "Feed Store", "d": "Pump House", "e": "Pickup Camp"},
    ("gangsters", "countryside", "bf_rail_yards"): {"a": "Gas Station", "b": "Overpass", "c": "Billboard Bend", "d": "Truck Stop", "e": "Motel Lot"},
    ("gangsters", "countryside", "bf_orchard_line"): {"a": "Billboard Hill", "b": "Overpass Row", "c": "Gas Station", "d": "Truck Stop", "e": "Motel Lot"},
    ("gangsters", "*", "bf_bog_crossing"): {"a": "Bait Shack Isle", "c": "Old Boathouse", "f": "Airboat Camp"},
    ("penguins", "*", "bf_frostfield"): {"e": "Igloo Camp"},
    ("penguins", "*", "bf_ash_wastes"): {"a": "Cinder Gate"},
    # C16b P5 (c16b_05-17): the Ember Isle finale has its own names on the ash field
    ("penguins", "colony_ember", "bf_ash_wastes"): {"a": "Lava Bridge", "b": "Ember Market", "c": "Cinder Cone", "d": "Smoke Hollow", "e": "Cinder Cove"},
}
def _name_points(cfg, arc, region):
    m = dict(POINT_NAMES.get((arc, "*", cfg["field"]), {}))
    m.update(POINT_NAMES.get((arc, region, cfg["field"]), {}))
    for p in cfg["points"]:
        if p["id"] in m:
            p["name"] = m[p["id"]]

# Board layouts: [x, y] in 0..1 on the board, then links. Slot 0 is the start camp.
LAYOUTS = {
    4: {"pos": [[0.5, 0.92], [0.24, 0.66], [0.76, 0.66], [0.5, 0.40], [0.5, 0.10]],
        "links": [[0, 1], [0, 2], [1, 3], [2, 3], [3, 4]], "layer": [0, 1, 1, 2, 3]},
    5: {"pos": [[0.5, 0.92], [0.22, 0.70], [0.78, 0.70], [0.5, 0.50], [0.26, 0.28], [0.56, 0.09]],
        "links": [[0, 1], [0, 2], [1, 3], [2, 3], [3, 4], [3, 5], [4, 5]], "layer": [0, 1, 1, 2, 3, 4]},
    6: {"pos": [[0.5, 0.92], [0.24, 0.72], [0.76, 0.72], [0.18, 0.48], [0.66, 0.50], [0.40, 0.28], [0.60, 0.08]],
        "links": [[0, 1], [0, 2], [1, 3], [1, 4], [2, 4], [3, 5], [4, 5], [4, 6], [5, 6]], "layer": [0, 1, 1, 2, 2, 3, 4]},
    7: {"pos": [[0.5, 0.93], [0.18, 0.74], [0.5, 0.70], [0.82, 0.74], [0.24, 0.47], [0.76, 0.47], [0.5, 0.29], [0.5, 0.08]],
        "links": [[0, 1], [0, 2], [0, 3], [1, 4], [2, 4], [2, 5], [3, 5], [4, 6], [5, 6], [6, 7], [5, 7]], "layer": [0, 1, 1, 1, 2, 2, 3, 4]},
}
# Each board picks one of three shapes of its layout (same links): as drawn,
# mirrored, or swayed (rows shifted alternately), so boards don't all look alike.
def _layout(n, cid):
    L = LAYOUTS[n]
    v = random.Random(cid + ":layout").randrange(3)
    pos = [list(p) for p in L["pos"]]
    if v == 1:
        pos = [[round(1.0 - x, 2), y] for x, y in pos]
    elif v == 2:
        pos = [[round(min(0.88, max(0.12, x + (0.09 if L["layer"][i] % 2 else -0.09) * (1 if i else 0))), 2), y] for i, (x, y) in enumerate(pos)]
    return {"pos": pos, "links": L["links"], "layer": L["layer"]}

# Node type pools by layer (the last layer is always the gate: a siege with a boss).
POOL = {1: ["skirmish", "skirmish", "escort", "cache"], 2: ["siege", "defend", "escort", "camp", "boss"], 3: ["camp", "cache", "defend", "boss", "siege"]}
# Tier 1 boards teach the basics: no sieges or defends before the gate.
POOL_T1 = {1: ["skirmish", "skirmish", "skirmish", "cache"], 2: ["skirmish", "boss", "escort"], 3: ["camp", "boss", "skirmish"]}
# Board size by tier: short early campaigns, growing modestly (territories, camp excluded).
SIZE = {1: 4, 2: 5, 3: 6, 4: 6, 5: 7}  # C16b: T3 now 6 (was 5), longer than T2
# Battle length and pressure by tier: early fights are short and gentle.
TICKET_K = {1: 0.6, 2: 0.8, 3: 1.0, 4: 1.15, 5: 1.3}
# What a campaign asks before you can muster for it (CampaignGate): allies on your
# team, and provisions that become the army's starting supply.
NEED = {1: {"team": 2, "items": {"wood": 20, "stone": 10}, "crystals": 100, "supply": 25},
        2: {"team": 3, "items": {"wood": 30, "copper_bar": 3}, "crystals": 250, "supply": 30},
        3: {"team": 4, "items": {"iron_bar": 4, "stone": 40}, "crystals": 500, "supply": 35},
        4: {"team": 4, "items": {"gold_bar": 2, "iron_bar": 6}, "crystals": 900, "supply": 40},
        5: {"team": 4, "items": {"gold_bar": 5, "crystal_refined": 2}, "crystals": 1400, "supply": 45}}
# The training drill (CampaignGate / BattleDrill): a short guided fight on the
# orchard field with three points close to the camp.
DRILL = {"field": "bf_orchard_line", "who": {"penguins": "Catkins", "gangsters": "Sal"},
         "points": [{"id": "e", "name": "Wagon Camp", "cell": [52, 74], "owner": "ally"},
                    {"id": "d", "name": "Scarecrow Post", "cell": [52, 56], "owner": "neutral"},
                    {"id": "b", "name": "Old Mill", "cell": [52, 38], "owner": "enemy"}],
         "enemies": {"penguins": ["grump"], "gangsters": ["thug_lookout"]},
         # gang drill point names (C16b P5: c16b_18-05; BattleDrill reads point_names[arc] when set)
         "point_names": {"gangsters": {"e": "Getaway Car", "d": "Phone Booth", "b": "Corner Store"}}, "supply": 60, "enemy_cap": 3, "wave_every": 9.0,
         "reward": {"crystals": 150, "items": {"potion": 3}}}
STEP = {1: 0, 2: 0, 3: 1, 4: 1}
BRIEF = {
    "skirmish": "A quick clash at %s. Take the points and their line breaks.",
    "siege": "%s is dug in and fortified: their points take twice as long to turn. Bring helpers and a plan.",
    "escort": "Our supply %s has to reach %s. Walk with it: it only rolls with friends beside it and no foes on it.",
    "defend": "Hold %s. Their gates keep pouring foes out; keep at least one point until the timer runs out.",
    "boss": "Their captain holds %s. Bring the captain down and the rest will scatter.",
    "gate": "%s: the last wall before the region. Every point fortified, and their commander takes the field.",
}

# Penguin boss/gate briefs with the captain's name (CAPTAINS); "turn back" is the Meow Pow Wow's word.
BRIEF_CAPTAIN = {
    "boss": "%s holds %s. Turn the captain back and the rest will scatter.",
    "gate": "%s: the last wall before the region. Every point fortified, and %s takes the field.",
}

# Gang-arc node briefs (C16b P5: c16b_03-05): turf words, the captain by name.
BRIEF_GANG = {
    "skirmish": "Their lookouts hold %s. Take the corners and they pull out.",
    "siege": "%s is locked down: their points take twice as long to turn. Bring the crew and a plan.",
    "escort": "Our %s has to reach %s. Stay with it: it only rolls with the crew beside it and nobody in the way.",
    "defend": "Hold %s. Their cars keep dropping off more of them; keep at least one point until the clock runs out.",
    "boss": "%s runs %s. Make them back off and the crew scatters.",
    "gate": "%s: the last block before the turf. Every point locked down, and %s steps in.",
}
# What the brief calls each convoy (C16b P5: c16b_02-20).
VEHICLE_WORD = {"wagon": "crystal sled", "truck": "supply truck"}

def _field_points(fid):
    return [dict(p) for p in R[fid]["battle"]["points"]]

def _cfg(fid, typ, side, rng, name):
    pts = _field_points(fid)
    camp = [p for p in pts if p["owner"] == "ally"][0]
    others = [p for p in pts if p is not camp]
    cx = camp["cell"][0]
    def dist(p):
        return abs(p["cell"][0] - camp["cell"][0]) + abs(p["cell"][1] - camp["cell"][1])
    cfg = {"field": fid}
    if typ in ("skirmish", "boss"):
        half = [p for p in others if (p["cell"][0] < cx) == (side < 0.5) or p["cell"][0] == cx]
        if len(half) < 2:
            half = sorted(others, key=dist)[:3]
        use = [camp] + sorted(half, key=dist)[:3]
        for p in use[1:]:
            p["owner"] = "neutral" if dist(p) == min(dist(q) for q in use[1:]) else "enemy"
        cfg["points"] = use
    elif typ in ("siege", "gate"):
        # C16b P5 (c16b_17-01, 05-16): the nearest point is open ground (neutral, not
        # fortified), so you are never 1 point against 4-5 from the first second; a
        # siege also leaves the far point unfortified, so it is not a copy of the gate.
        near = min(others, key=dist)
        far = max(others, key=dist)
        for p in others:
            p["owner"] = "neutral" if p is near else "enemy"
            if p is not near and not (typ == "siege" and p is far):
                p["efort"] = True
        cfg["points"] = [camp] + others
    elif typ == "escort":
        side_pts = [p for p in others if (p["cell"][0] <= cx) == (side < 0.5)] or others
        target = max(side_pts, key=dist)
        mid = min([p for p in others if p is not target], key=lambda p: abs(p["cell"][0] - (camp["cell"][0] + target["cell"][0]) / 2) + abs(p["cell"][1] - (camp["cell"][1] + target["cell"][1]) / 2))
        target["owner"] = "enemy"
        mid["owner"] = "neutral"
        extra = [p for p in others if p is not target and p is not mid]
        use = [camp, mid, target] + extra[:1]
        cfg["points"] = use
        cfg["convoy"] = [camp["id"], mid["id"], target["id"]]
    elif typ == "defend":
        far = sorted(others, key=dist, reverse=True)[:2]
        for p in others:
            p["owner"] = "ally"
        for p in far:
            p["owner"] = "enemy"
            p["gate"] = True
        cfg["points"] = [camp] + others
    return cfg

def _reward(tier, typ, arc, rng):
    base = {"skirmish": 120, "siege": 220, "escort": 180, "defend": 200, "boss": 240, "gate": 0}[typ]
    r = {"crystals": int(base * _pay_k(tier)), "supply": {"skirmish": 10, "siege": 6, "escort": 18, "defend": 8, "boss": 8, "gate": 0}[typ],
         "morale": {"skirmish": 8, "siege": 12, "escort": 10, "defend": 10, "boss": 15, "gate": 0}[typ], "items": {}}
    pick = list(REWARD_ITEMS[tier].items())
    k, n = pick[rng.randrange(len(pick))]
    if typ == "gate":  # the gate pays the campaign's big reward instead (no stray item)
        return r
    if arc == "both" and k not in SHARED_OK:  # C16b: no potions/crystals in a shared reward
        k, n = next(((a, b) for a, b in pick if a in SHARED_OK), ("copper_bar", 4))
    r["items"][k] = max(1, n // 2)
    if arc == "gangsters" and k in GANG_SWAP:
        r["items"] = {GANG_SWAP[k]: max(1, n // 2)}
    if arc == "gangsters":  # C16b P5 (c16b_18-04): gang fights pay rounds
        r["items"]["rounds"] = 10 * tier
    return r

EN = _write_grumps()
C = {}
for (region, tier, after, title, fields, boss, start_name, names, intro, won) in CAMPS:
    cid = "c_" + region
    rng = random.Random(cid)
    arc = "penguins" if region in PENG_ONLY else ("gangsters" if region in GANG_ONLY else "both")
    arcs = ["penguins", "gangsters"] if arc == "both" else [arc]
    fl = fields if isinstance(fields, dict) else {a: fields for a in arcs}
    _rf = campaign_field(region)
    if _rf and _rf in R:
        # C16b P5 (c16b_04-08): the region's own field first (it always hosts the gate),
        # then one of the campaign's older fields, so a board is not one field throughout.
        fl = {a: [_rf] + [f for f in fl[a] if f != _rf and f in R and B.get(f, {}).get("arc") in ("both", a)][:1] for a in arcs}
    n = SIZE[tier]
    L = _layout(n, cid)
    pools = POOL_T1 if tier <= 1 else POOL
    nm = list(names)
    nodes = []
    used = {}
    for i, (pos, layer) in enumerate(zip(L["pos"], L["layer"])):
        nid = "n%d" % i
        if i == 0:
            nodes.append({"id": nid, "name": start_name, "type": "start", "x": pos[0], "y": pos[1], "layer": 0})
            continue
        last = i == len(L["pos"]) - 1
        if last:
            typ = "gate"
            name = nm[-1]
            gname = NAMES_GANG.get(region, nm)[-1]
        else:
            pool = [t for t in pools[min(layer, 3)] if used.get(t, 0) < (2 if t in ("skirmish", "siege") else 1)] or ["skirmish"]
            if tier <= 2 and layer == 1:  # early boards open with an easy win, never an escort
                pool = [t for t in pool if t != "escort"] or ["skirmish"]
            # never two non-battles on one layer, at most one camp and one cache, and
            # a 5-node board keeps its hub (every route passes it) a fight
            if any(nn["layer"] == layer and nn["type"] in ("camp", "cache") for nn in nodes) or (n <= 5 and layer == 2) \
                    or sum(1 for nn in nodes if nn["type"] in ("camp", "cache")) >= (1 if n <= 5 else 2):
                pool = [t for t in pool if t not in ("camp", "cache")]
            typ = pool[rng.randrange(len(pool))]
            # C16b P5 (c16b_05-11): from tier 4 the last layer before the gate always
            # previews the captain, so the gate is never your first meeting.
            if tier >= 4 and layer == max(L["layer"]) - 1 and not used.get("boss") and \
                    not any(nn.get("type") == "boss" for nn in nodes) and i == max(j for j, ly in enumerate(L["layer"]) if ly == layer):
                typ = "boss"
            name = nm[(i - 1) % (len(nm) - 1)]
            gname = NAMES_GANG.get(region, nm)[(i - 1) % (len(nm) - 1)]
        used[typ] = used.get(typ, 0) + 1
        node = {"id": nid, "name": name, "type": typ, "x": pos[0], "y": pos[1], "layer": layer, "step": STEP[layer]}
        if arc == "both" and region in NAMES_GANG:
            node["name_gangsters"] = gname
        if typ in ("camp", "cache"):
            node["brief"] = {"camp": "A sheltered spot to rest. Morale recovers here, and a camp you hold lets you rest again tomorrow.",
                             "cache": "Abandoned stores. Take the supplies for the next fight, or share them with the locals for morale."}[typ]
            li = dict(CACHE_ITEMS[tier])
            if arc == "gangsters":
                li = {"cherry_fizz": 2 + tier // 2, "rounds": 10 + 5 * tier}  # sodas, not the Golden Float
            # C16b P5 (c16b_04-04, 05-08): "share" pays about 0.6x a skirmish's money and
            # "take" is supply plus a low item, so a free node never out-pays a battle.
            node["loot"] = {"supply": 20 + 4 * tier, "morale": 15, "crystals": int(round(0.6 * 120 * _pay_k(tier) / 10.0)) * 10, "items": li}
        else:
            cfgs = {}
            for a in arcs:
                fs = fl[a]
                fid = fs[0] if last else fs[(i - 1) % len(fs)]
                cfg = _cfg(fid, typ, pos[0], rng, name)
                _name_points(cfg, a, region)
                ek = _kinds(region) + [k for k in R[fid]["battle"]["enemies"] if k in EN and int(EN[k].get("hp", 0)) < 45]
                if a == "penguins":
                    # grumps first (the variants of this region), then a few natives
                    ek = [k for k in GRUMP_AT.get(region, ["grump"]) if k in EN and (k != "crystal_baby" or layer >= 2)] + \
                         [k for k in ek if not k.startswith("thug_") and k not in NOT_PENGUIN and not k.startswith("grump")][:2]
                    if tier <= 1 and typ != "gate":  # C16b P5 (c16b_02-07): tier-1 openers field tier-1 foes only
                        ek = [k for k in ek if int(EN[k].get("tier", 1)) <= (1 if layer <= 1 else 2)] or ["grump"]
                    if typ in ("boss", "gate") and region in CAPTAINS:
                        cfg["boss"] = "gcap_" + region
                    if typ == "escort":
                        cfg["vehicle"] = "wagon"
                else:
                    # C16b P5: the gang fields people by tier, never the field's wildlife
                    ek = _gang_roster(tier, layer, region, typ == "gate")
                    if typ in ("boss", "gate") and region in GANG_CAPTAINS:
                        cfg["boss"] = "gcap_g_" + region
                    if typ == "escort":
                        cfg["vehicle"] = "truck"
                if typ in ("siege", "gate"):
                    # Sieges pay for their size: every extra fortified point is time.
                    ne = sum(1 for p in cfg["points"] if p["owner"] == "enemy")
                    cfg["tickets"] = {"siege": 150, "gate": 170}[typ] + 40 * max(0, ne - 3)
                seen = []
                for k in ek:
                    if k not in seen:
                        seen.append(k)
                if a == "penguins" and tier >= 2:  # C16b P5 (c16b_04-01): the roster builds up layer by layer
                    seen = seen[:3] if layer <= 1 else (seen[:5] if typ != "gate" else seen)
                cfg["enemies"] = seen[:6]
                cfgs[a] = cfg
            node["cfg"] = cfgs
            if typ in ("boss", "gate"):
                node["boss"] = ("gcap_g_" + region) if arc == "gangsters" and region in GANG_CAPTAINS else boss
            if typ == "escort":
                node["convoy_hp"] = 70 + 45 * tier  # C16b P5 (c16b_17-11): was 80 + 25 * tier
            if typ == "defend":
                node["hold"] = 75 + 20 * tier
            k = TICKET_K[tier]
            et = {"skirmish": 80, "siege": 150, "escort": 400, "defend": 999, "boss": 110, "gate": 170}[typ]
            node["enemy_tickets"] = et if typ == "defend" else int(round(et * k / 5.0)) * 5
            node["tickets"] = {"skirmish": 110, "siege": 150, "escort": 130, "defend": 140, "boss": 130, "gate": 170}[typ]
            node["wave_every"] = {"skirmish": 7.0, "siege": 6.5, "escort": 7.5, "defend": 5.0, "boss": 7.0, "gate": 6.0}[typ] + max(0, 3 - tier) * 0.75
            node["enemy_cap"] = {"skirmish": 8, "siege": 11, "escort": 8, "defend": 12, "boss": 8, "gate": 12}[typ] + 2 * (tier - 1) + max(0, tier - 2)
            node["brief"] = {}
            for a in arcs:
                cf_ = node["cfg"][a]
                pn = {p["id"]: p["name"] for p in cf_["points"]}
                nn_ = name if a == "penguins" else gname
                if typ == "escort":
                    words = BRIEF if a == "penguins" else BRIEF_GANG
                    node["brief"][a] = words["escort"] % (VEHICLE_WORD.get(cf_["vehicle"], cf_["vehicle"]), pn[cf_["convoy"][-1]])
                elif typ in ("boss", "gate") and a == "penguins" and region in CAPTAINS:
                    # C12: the penguin brief names the region's Grump captain (and never says
                    # "commander": the Wastes' Grump Commander is a different, story fight).
                    cap = CAPTAINS[region][0]
                    node["brief"][a] = (BRIEF_CAPTAIN[typ] % (cap, name)) if typ == "boss" else (BRIEF_CAPTAIN[typ] % (name, cap))
                elif typ in ("boss", "gate") and a == "gangsters" and region in GANG_CAPTAINS:
                    cap = GANG_CAPTAINS[region][0]
                    node["brief"][a] = (BRIEF_GANG[typ] % (cap, nn_)) if typ == "boss" else (BRIEF_GANG[typ] % (nn_, cap))
                else:
                    node["brief"][a] = (BRIEF if a == "penguins" else BRIEF_GANG)[typ] % nn_
            if len(arcs) == 1:
                node["brief"] = node["brief"][arcs[0]]
            node["reward"] = _reward(tier, typ, arc, rng)
        nodes.append(node)
    links = [["n%d" % a, "n%d" % b] for a, b in L["links"]]
    for nd in nodes:
        nd["links"] = sorted({b if a == nd["id"] else a for a, b in links if nd["id"] in (a, b)})
    # Fewest battles from the camp to the gate (camps and caches are free).
    import heapq
    byid = {nd["id"]: nd for nd in nodes}
    best = {"n0": 0}
    hq = [(0, "n0")]
    while hq:
        dd, cur = heapq.heappop(hq)
        for l in byid[cur]["links"]:
            w = dd + (0 if byid[l]["type"] in ("camp", "cache") else 1)
            if w < best.get(l, 99):
                best[l] = w
                heapq.heappush(hq, (w, l))
    gate_id = [nd["id"] for nd in nodes if nd["type"] == "gate"][0]
    big = {"crystals": GATE_PAY[tier], "items": dict(REWARD_ITEMS[tier]), "strategist": 250 + 100 * tier,
           "arc_items": {a: {k: v * ((tier + 1) // 2) for k, v in ARC_ITEMS[a].items()} for a in ARC_ITEMS}}
    if arc == "gangsters":
        big["items"] = {GANG_SWAP.get(k, k): v for k, v in big["items"].items()}
    if arc == "both":
        gi, gw = GANG_TEXT[region]
        intro, won = {"penguins": intro, "gangsters": gi}, {"penguins": won, "gangsters": gw}
    lead = {a: LEAD[region][a] for a in arcs}
    C[cid] = {"id": cid, "region": region, "title": title, "arc": arc, "tier": tier, "after": ["c_" + a for a in after], "min_pt": max(0, tier - 2),
              "who": {a: lead[a][0] for a in arcs}, "lead": lead, "intro": intro, "won": won, "reward": big, "nodes": nodes, "links": links,
              "need": NEED[tier], "min_battles": best[gate_id], "long_way": _long_way(region, tier, arcs), "sense": {a: SENSE[region][a] for a in arcs},
              "region_name": REGION_NAME.get(region) or COL.get(region, {}).get("name") or R.get(region, {}).get("name") or region.replace("_", " ").title()}
    # sanity: every reward item exists, every enemy exists, every field exists
    for nd in nodes:
        for k in list(nd.get("reward", {}).get("items", {})) + list(nd.get("loot", {}).get("items", {})):
            assert k in IT, (cid, k)
        for a, cf in nd.get("cfg", {}).items():
            assert cf["field"] in R and cf["enemies"], (cid, nd["id"], a)
            assert all(k in EN for k in cf["enemies"]), (cid, cf["enemies"])
            assert a != "gangsters" or not any(k.startswith(("grump_", "gcap_")) for k in cf["enemies"]), (cid, cf["enemies"])
            assert a != "penguins" or not any(k in NOT_PENGUIN or k.startswith("thug_") for k in cf["enemies"]), (cid, cf["enemies"])
            assert cf.get("boss", "x") == "x" or cf["boss"] in EN, cf["boss"]
        if "boss" in nd:
            assert nd["boss"] in EN, nd["boss"]
    for k in big["items"]:
        assert k in IT, k
    # C16b P5 checks: the long way exists and is all-ages text for every arc it serves;
    # gang bosses are named gang captains; no free node out-pays a battle node.
    lw = C[cid]["long_way"]
    assert lw["text"] and lw["text_gang"] and lw["steps"] and all(k in IT for k in lw["cost"]["items"]), cid
    battle_pay = [nd["reward"]["crystals"] for nd in nodes if nd.get("reward") and nd["type"] != "gate"]
    for nd in nodes:
        if "loot" in nd and battle_pay:
            take = sum(int(IT[k].get("value", 50)) * v for k, v in nd["loot"]["items"].items())
            assert nd["loot"]["crystals"] < min(battle_pay) and take < min(battle_pay), (cid, nd["id"], nd["loot"], min(battle_pay))
        for a, cf in nd.get("cfg", {}).items():
            if a == "gangsters" and nd["type"] in ("boss", "gate"):
                assert str(cf.get("boss", "")).startswith("gcap_g_"), (cid, nd["id"], cf.get("boss"))
            if a == "gangsters":
                assert all(k.startswith(("thug_", "gilt_", "coal_")) or k == "rust_knight" for k in cf["enemies"]), (cid, cf["enemies"])

for k in [k for nd in NEED.values() for k in nd["items"]] + list(DRILL["reward"]["items"]):
    assert k in IT, k
for a, ks in DRILL["enemies"].items():
    assert all(k in EN for k in ks), ks
B["_campaigns"] = {"title": "Campaigns", "arc": "none", "tier": 0, "list": C, "drill": DRILL, "kin_gift": KIN_GIFT, "unlocks": {str(k): v for k, v in UNLOCKS.items()}}
B["_helper_kinds"] = KIN
OUT = os.environ.get("DRY_OUT", D + "/data")  # DRY_OUT=/tmp/x: write the JSON elsewhere to compare
json.dump(R, open(OUT + "/regions.json", "w"), indent=1, ensure_ascii=False)
json.dump(B, open(OUT + "/battles.json", "w"), indent=1, ensure_ascii=False)
print("battles:", [b for b in B if not b.startswith("_")])
print("campaigns:", len(C), sum(len(c["nodes"]) - 1 for c in C.values()), "nodes")

