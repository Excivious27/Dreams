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
def battle(rid, title, arc, tier, cols, rows, ground, patch, path, plateaus, water, points, enemies, props, crit, brief, who, win, lose, reward, back, music="battle", **kw):
    exits = [{"rect": [cols // 2 - 2, rows - 1, 4, 1], "scene": back[0], "spawn": back[1:], "facing": "down", "label": "▼ fall back"}]
    kept = {k: R[rid][k] for k in ("light",) if k in R.get(rid, {})}  # C5: hand/other-package keys (P2's fixed darkness) survive a rerun
    R[rid] = {"cols": cols, "rows": rows, "music": music, "backdrop": "mountains" if "snow" in (patch or "") or "frost" in rid else "hills", "ground": ground,
              "path": path, "spawn": [cols // 2, rows - 9], "pad": 7, "border": {"n": "cliff", "s": "trees", "w": "trees", "e": "cliff"},
              "exits": exits, "paths": kw.get("lanes") or [[cols // 2 - 1, rows // 2, 2, rows // 2 - 1], [6, rows // 2, cols - 12, 2]],
              "water_blobs": water, "plateaus": plateaus, "props": props, "patch_set": patch, "ground_threshold": 0.15, "fruit": 0,
              "gen": {"clumps": 10, "scatter": 110, "region_props": [n.split("/")[-1] for n in (kw.get("scatter") or PROP_SETS.get(rid) or ["boulder_m"])], "region_count": 90, "critters": crit, "critter_count": 6}, "forage": 0, "things": [], "enemies": [], "npcs": [],
              "battle": {"title": title, "who": who, "brief": brief, "win": win, "lose": lose, "points": points, "enemies": enemies,
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
ARC_ITEMS = {"penguins": {"crystal_refined": 2}, "gangsters": {"servo": 4, "data_chip": 1}}
# Tier-3 node rewards: refined crystal is a penguin thing; gangsters get parts.
GANG_SWAP = {"crystal_refined": "data_chip"}
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
# Point names per arc / region, where a battlefield's own names don't fit.
POINT_NAMES = {
    ("gangsters", "*", "bf_orchard_line"): {"a": "Old Silo", "c": "Feed Store", "d": "Pump House", "e": "Pickup Camp"},
    ("gangsters", "countryside", "bf_orchard_line"): {"a": "Billboard Hill", "b": "Overpass Row", "c": "Gas Station", "d": "Truck Stop", "e": "Motel Lot"},
    ("gangsters", "*", "bf_bog_crossing"): {"a": "Bait Shack Isle", "c": "Old Boathouse", "f": "Airboat Camp"},
    ("penguins", "*", "bf_frostfield"): {"e": "Igloo Camp"},
    ("penguins", "*", "bf_ash_wastes"): {"a": "Cinder Gate"},
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
SIZE = {1: 4, 2: 5, 3: 5, 4: 6, 5: 7}
# Battle length and pressure by tier: early fights are short and gentle.
TICKET_K = {1: 0.6, 2: 0.8, 3: 1.0, 4: 1.15, 5: 1.3}
# What a campaign asks before you can muster for it (CampaignGate): allies on your
# team, and provisions that become the army's starting supply.
NEED = {1: {"team": 2, "items": {"wood": 20, "stone": 10}, "crystals": 100, "supply": 25},
        2: {"team": 3, "items": {"wood": 30, "copper_bar": 3}, "crystals": 250, "supply": 30},
        3: {"team": 4, "items": {"iron_bar": 4, "stone": 40}, "crystals": 500, "supply": 35},
        4: {"team": 5, "items": {"gold_bar": 2, "iron_bar": 6}, "crystals": 900, "supply": 40},
        5: {"team": 6, "items": {"gold_bar": 5, "crystal_refined": 2}, "crystals": 1400, "supply": 45}}
# The training drill (CampaignGate / BattleDrill): a short guided fight on the
# orchard field with three points close to the camp.
DRILL = {"field": "bf_orchard_line", "who": {"penguins": "Catkins", "gangsters": "Sal"},
         "points": [{"id": "e", "name": "Wagon Camp", "cell": [52, 74], "owner": "ally"},
                    {"id": "d", "name": "Scarecrow Post", "cell": [52, 56], "owner": "neutral"},
                    {"id": "b", "name": "Old Mill", "cell": [52, 38], "owner": "enemy"}],
         "enemies": {"penguins": ["grump"], "gangsters": ["thug_speedster"]}, "supply": 60, "enemy_cap": 3, "wave_every": 9.0,
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
        for p in others:
            p["owner"] = "enemy"
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
    r = {"crystals": int(base * (0.6 + 0.4 * tier)), "supply": {"skirmish": 10, "siege": 6, "escort": 18, "defend": 8, "boss": 8, "gate": 0}[typ],
         "morale": {"skirmish": 8, "siege": 12, "escort": 10, "defend": 10, "boss": 15, "gate": 0}[typ], "items": {}}
    pick = list(REWARD_ITEMS[tier].items())
    k, n = pick[rng.randrange(len(pick))]
    if typ == "gate":  # the gate pays the campaign's big reward instead (no stray item)
        return r
    r["items"][k] = max(1, n // 2)
    if arc == "gangsters" and k in GANG_SWAP:
        r["items"] = {GANG_SWAP[k]: max(1, n // 2)}
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
        fl = {a: [_rf] for a in arcs}
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
            name = nm[(i - 1) % (len(nm) - 1)]
        used[typ] = used.get(typ, 0) + 1
        node = {"id": nid, "name": name, "type": typ, "x": pos[0], "y": pos[1], "layer": layer, "step": STEP[layer]}
        if typ in ("camp", "cache"):
            node["brief"] = {"camp": "A sheltered spot to rest. Morale recovers here, and a camp you hold lets you rest again tomorrow.",
                             "cache": "Abandoned stores. Take the supplies for the next fight, or share them with the locals for morale."}[typ]
            li = dict([list(REWARD_ITEMS[tier].items())[0]])
            if arc == "gangsters":
                li = {GANG_SWAP.get(k, k): v for k, v in li.items()}
            # "share" pays about 0.8x what "take" is worth in goods (C3 economy)
            worth = sum(int(IT[k].get("value", 50)) * v for k, v in li.items()) + 6 * (20 + 4 * tier)
            node["loot"] = {"supply": 20 + 4 * tier, "morale": 15, "crystals": int(round(0.8 * worth / 10.0)) * 10, "items": li}
        else:
            cfgs = {}
            for a in arcs:
                fs = fl[a]
                fid = fs[(i - 1) % len(fs)]
                cfg = _cfg(fid, typ, pos[0], rng, name)
                _name_points(cfg, a, region)
                ek = _kinds(region) + [k for k in R[fid]["battle"]["enemies"] if k in EN and int(EN[k].get("hp", 0)) < 45]
                if a == "penguins":
                    # grumps first (the variants of this region), then a few natives
                    ek = [k for k in GRUMP_AT.get(region, ["grump"]) if k in EN and (k != "crystal_baby" or layer >= 2)] + \
                         [k for k in ek if not k.startswith("thug_") and k not in NOT_PENGUIN and not k.startswith("grump")][:2]
                    if typ in ("boss", "gate") and region in CAPTAINS:
                        cfg["boss"] = "gcap_" + region
                    if typ == "escort":
                        cfg["vehicle"] = "wagon"
                elif typ == "escort":
                    cfg["vehicle"] = "truck"
                if typ in ("siege", "gate"):
                    # Sieges pay for their size: every extra fortified point is time.
                    ne = sum(1 for p in cfg["points"] if p["owner"] == "enemy")
                    cfg["tickets"] = {"siege": 150, "gate": 170}[typ] + 40 * max(0, ne - 3)
                if a == "gangsters" and region in GANG_ONLY:
                    ek = [k for k in ek if k.startswith("thug_") or k in ("soldier", "archer", "rust_knight")] or ek
                if a == "gangsters":
                    ek = [gang_kind(k) for k in ek]
                seen = []
                for k in ek:
                    if k not in seen:
                        seen.append(k)
                cfg["enemies"] = seen[:6]
                cfgs[a] = cfg
            node["cfg"] = cfgs
            if typ in ("boss", "gate"):
                node["boss"] = boss
            if typ == "escort":
                node["convoy_hp"] = 80 + 25 * tier
            if typ == "defend":
                node["hold"] = 75 + 20 * tier
            k = TICKET_K[tier]
            et = {"skirmish": 80, "siege": 150, "escort": 400, "defend": 999, "boss": 110, "gate": 170}[typ]
            node["enemy_tickets"] = et if typ == "defend" else int(round(et * k / 5.0)) * 5
            node["tickets"] = {"skirmish": 110, "siege": 150, "escort": 130, "defend": 140, "boss": 130, "gate": 170}[typ]
            node["wave_every"] = {"skirmish": 7.0, "siege": 6.5, "escort": 7.5, "defend": 5.0, "boss": 7.0, "gate": 6.0}[typ] + max(0, 3 - tier) * 0.75
            node["enemy_cap"] = {"skirmish": 8, "siege": 11, "escort": 8, "defend": 12, "boss": 8, "gate": 12}[typ] + 2 * (tier - 1) + max(0, tier - 2)
            if typ == "escort":
                node["brief"] = {}
                for a in arcs:
                    cv = node["cfg"][a]["convoy"]
                    pn = {p["id"]: p["name"] for p in node["cfg"][a]["points"]}
                    node["brief"][a] = BRIEF["escort"] % (node["cfg"][a]["vehicle"], pn[cv[-1]])
                if len(arcs) == 1:
                    node["brief"] = node["brief"][arcs[0]]
            else:
                node["brief"] = BRIEF[typ] % name
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
    big = {"crystals": 500 + 400 * tier, "items": dict(REWARD_ITEMS[tier]), "strategist": 250 + 100 * tier,
           "arc_items": {a: {k: v * ((tier + 1) // 2) for k, v in ARC_ITEMS[a].items()} for a in ARC_ITEMS}}
    if arc == "gangsters":
        big["items"] = {GANG_SWAP.get(k, k): v for k, v in big["items"].items()}
    if arc == "both":
        gi, gw = GANG_TEXT[region]
        intro, won = {"penguins": intro, "gangsters": gi}, {"penguins": won, "gangsters": gw}
    lead = {a: LEAD[region][a] for a in arcs}
    C[cid] = {"id": cid, "region": region, "title": title, "arc": arc, "tier": tier, "after": ["c_" + a for a in after], "min_pt": max(0, tier - 2),
              "who": {a: lead[a][0] for a in arcs}, "lead": lead, "intro": intro, "won": won, "reward": big, "nodes": nodes, "links": links,
              "need": NEED[tier], "min_battles": best[gate_id], "sense": {a: SENSE[region][a] for a in arcs},
              "region_name": COL.get(region, {}).get("name") or R.get(region, {}).get("name") or region.replace("_", " ").title()}
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

for k in [k for nd in NEED.values() for k in nd["items"]] + list(DRILL["reward"]["items"]):
    assert k in IT, k
for a, ks in DRILL["enemies"].items():
    assert all(k in EN for k in ks), ks
B["_campaigns"] = {"title": "Campaigns", "arc": "none", "tier": 0, "list": C, "drill": DRILL, "kin_gift": KIN_GIFT}
B["_helper_kinds"] = KIN
OUT = os.environ.get("DRY_OUT", D + "/data")  # DRY_OUT=/tmp/x: write the JSON elsewhere to compare
json.dump(R, open(OUT + "/regions.json", "w"), indent=1, ensure_ascii=False)
json.dump(B, open(OUT + "/battles.json", "w"), indent=1, ensure_ascii=False)
print("battles:", [b for b in B if not b.startswith("_")])
print("campaigns:", len(C), sum(len(c["nodes"]) - 1 for c in C.values()), "nodes")

