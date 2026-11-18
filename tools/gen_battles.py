#!/usr/bin/env python3
"""Conquest battlefields: big varied maps (plateaus, ramps, water, woods) with
control points. Adds/updates entries in data/regions.json and data/battles.json,
and writes scenes/<id>.tscn. Re-runnable.   python3 tools/gen_battles.py
"""
import json, os
D = os.path.join(os.path.dirname(__file__), "..")
R = json.load(open(D + "/data/regions.json"))

def scene(rid):
    open(D + "/scenes/%s.tscn" % rid, "w").write('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/region.gd" id="1"]\n\n[node name="%s" type="Node2D"]\nscript = ExtResource("1")\nregion_id = "%s"\n' % (rid, rid))

B = {}
BOSSES = {"bf_rail_yards": "lt_pike", "bf_dockside": "lt_ostrova", "bf_shattered_vale": "knight", "bf_frostfield": "big_grump"}
def battle(rid, title, arc, tier, cols, rows, ground, patch, path, plateaus, water, points, enemies, props, crit, brief, who, win, lose, reward, back, music="boss"):
    exits = [{"rect": [cols // 2 - 2, rows - 1, 4, 1], "scene": back[0], "spawn": back[1:], "facing": "down", "label": "▼ fall back"}]
    R[rid] = {"cols": cols, "rows": rows, "music": music, "backdrop": "mountains" if "snow" in patch or "frost" in rid else "hills", "ground": ground,
              "path": path, "spawn": [cols // 2, rows - 3], "pad": 7, "border": {"n": "cliff", "s": "trees", "w": "trees", "e": "cliff"},
              "exits": exits, "paths": [[cols // 2 - 1, rows // 2, 2, rows // 2 - 1], [6, rows // 2, cols - 12, 2]],
              "water_blobs": water, "plateaus": plateaus, "props": props, "patch_set": patch, "ground_threshold": 0.15, "fruit": 0,
              "gen": {"clumps": 4, "scatter": 30, "critters": crit, "critter_count": 6}, "forage": 0, "things": [], "enemies": [], "npcs": [],
              "intro": [brief],
              "battle": {"title": title, "who": who, "brief": brief, "win": win, "lose": lose, "points": points, "enemies": enemies,
                         "tickets": 150, "supply": 15, "wave_every": 7.0, "enemy_cap": 16, "tier_bonus": max(0, tier - 2), "reward": reward, "back": back}}
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
       ["shard", "shard_spider", "prism_wisp", "geode_golem", "knight", "crystal_baby"],
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
json.dump(R, open(D + "/data/regions.json", "w"), indent=1, ensure_ascii=False)
json.dump(B, open(D + "/data/battles.json", "w"), indent=1, ensure_ascii=False)
print("battles:", list(B))
