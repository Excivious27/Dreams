#!/usr/bin/env python3
"""The Hollow Heart: the region under mine floor 150 (both arcs). A vast glowing
cavern-world with its own people, lore, loot and a last guardian. Adds it to
data/regions.json and writes scenes/hollow_heart.tscn.  Run: python3 tools/gen_deep_region.py
"""
import json, os
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
p = f"{R}/data/regions.json"
raw = open(p).read(); regs = json.loads(raw)
regs["hollow_heart"] = {
    "cols": 76, "rows": 64, "music": "mine", "backdrop": "night", "ground": "teal_moss", "path": "stone", "pet": True,
    "spawn": [38, 60], "pad": 7, "border": {"n": "cliff", "s": "cliff", "w": "cliff", "e": "cliff"},
    "exits": [{"rect": [36, 63, 4, 1], "scene": "meadow", "spawn": [31, 9], "facing": "down", "label": "▼ the long lift up"}],
    "paths": [[37, 8, 2, 54], [10, 30, 56, 2], [10, 12, 2, 20], [64, 12, 2, 20], [10, 12, 56, 2]],
    "water_blobs": [{"c": [18, 46], "r": 6, "seed": 151, "fish": ["mooncarp", "eel", "puffer"]}, {"c": [58, 46], "r": 5, "seed": 152, "fish": ["mooncarp", "catfish"]},
                    {"c": [24, 20], "r": 4, "seed": 153, "fish": ["mooncarp"]}],
    "props": [{"name": "geode_chamber", "cell": [34, 4], "w": 6, "h": 4}, {"name": "mushroom_tree_a", "cell": [14, 38], "w": 2, "h": 2},
              {"name": "mushroom_tree_b", "cell": [60, 36], "w": 2, "h": 2}, {"name": "mushroom_tree_a", "cell": [50, 22], "w": 2, "h": 2},
              {"name": "mushroom_tree_b", "cell": [26, 54], "w": 2, "h": 2}, {"name": "star_crater", "cell": [48, 50], "w": 4, "h": 3}],
    "gen": {"clumps": 2, "scatter": 10, "critters": ["firefly", "bat", "firefly", "moth", "bat"], "critter_count": 18},
    "forage": 10,
    "things": [
        {"type": "note", "cell": [38, 56], "who": "", "text": "Carved into the rock by the lift, in a hand older than the town: WHERE THE STAR WAS BORN, IT STILL BEATS."},
        {"type": "note", "cell": [12, 14], "who": "", "text": "A miner's journal, waterlogged: \"Day 40. The light down here isn't from the crystals. The crystals are from the light.\""},
        {"type": "note", "cell": [64, 14], "who": "", "text": "A painted wall: a falling star, a field, two small figures, and a long line of people carrying pieces of it away."},
        {"type": "loot", "cell": [20, 28], "item": "crystal_refined", "n": 2, "hint": "A: a crystal growing out of the moss", "every": 3, "solid": False},
        {"type": "loot", "cell": [56, 28], "item": "cave_bloom", "n": 3, "hint": "A: glowing blooms", "every": 2, "solid": False},
        {"type": "loot", "cell": [30, 44], "item": "sapphire", "n": 1, "hint": "A: a blue glint in the wall", "every": 5, "solid": False},
        {"type": "loot", "cell": [46, 40], "item": "relic_orb", "n": 1, "hint": "A: something round in a nest of roots", "every": 14, "solid": False},
        {"type": "loot", "cell": [10, 50], "item": "wonder_elixir", "n": 1, "hint": "A: an old miner's flask", "every": 10, "solid": False},
        {"type": "boss", "cell": [38, 9], "kind": "light_eater", "who": "", "text": "The geode splits like an egg. What climbs out has no face, only a hunger shaped like light, and it turns toward the warmth in your pocket.",
         "win": "It folds in on itself and goes out, the way a candle does. In the empty geode, something beats: slow, steady, warm. The Heart.",
         "after": "The empty geode. Something inside still beats.", "reward": "relic_crown", "max_hp": 1, "hint": "A: the great geode", "solid": False, "title": "The Last Keeper"},
    ],
    "npcs": [
        {"id": "sel", "cell": [40, 54], "lines": ["You came down all hundred and fifty. Of course you did.", "Every rune I've ever read points here.", "The Heart isn't a place. It's a someone."]},
    ],
    "enemies": [{"kind": "light_eater", "count": 1}, {"kind": "obsidian_sentinel", "count": 3}, {"kind": "prism_wisp", "count": 3}, {"kind": "void_eel", "count": 2}, {"kind": "mirror", "count": 2}],
    "intro": ["The lift goes down past where the rope should run out, and then it stops, and there is a whole country under the world.",
              "Moss that glows teal, rivers that run with light, mushrooms as tall as houses, and far off, in a geode the size of the town hall, something beating like a heart."],
}
ind = 1 if raw.startswith('{\n "') else 2
json.dump(regs, open(p, "w"), indent=ind, ensure_ascii=False)
open(f"{R}/scenes/hollow_heart.tscn", "w").write('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/region.gd" id="1"]\n\n[node name="hollow_heart" type="Node2D"]\nscript = ExtResource("1")\nregion_id = "hollow_heart"\n')
print("hollow_heart written")
