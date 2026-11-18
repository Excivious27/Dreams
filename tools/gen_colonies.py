#!/usr/bin/env python3
"""The merkitty colonies (penguin arc side arc): four big island regions in the
sea beyond the beach, each with a fading star crystal. Writes the colony_*
entries in data/regions.json, data/colonies.json, scenes/colony_*.tscn, the
colony bosses in data/enemies.json and the colony items in data/items.json.
Re-runnable.   python3 tools/gen_colonies.py
"""
import json, os, math
D = os.path.join(os.path.dirname(__file__), "..")
R = json.load(open(D + "/data/regions.json"))
E = json.load(open(D + "/data/enemies.json"))
I = json.load(open(D + "/data/items.json"))
G = json.load(open(D + "/data/gifts.json"))

def scene(rid):
    open(D + "/scenes/%s.tscn" % rid, "w").write('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/region.gd" id="1"]\n\n[node name="%s" type="Node2D"]\nscript = ExtResource("1")\nregion_id = "%s"\n' % (rid, rid))

def item(id, name, typ, val, tier, **kw):
    d = {"name": name, "type": typ, "value": val, "rarity": "rare" if tier >= 3 else "uncommon", "tier": tier, "arc": "penguins"}
    d.update(kw); I[id] = d

item("colony_light", "Colony Light", "key", 0, 4, desc="The steady glow of a saved colony's star crystal. The Crystal Ward wants four.")
item("coral_charm", "Coral Charm", "equip", 900, 3, slot="charm", stats={"defense": 2, "luck": 1}, desc="Grown, not carved. Warm in your hand.")
item("tide_pearl", "Tide Pearl", "equip", 1400, 3, slot="ring", stats={"mana": 15, "speed": 1}, desc="You can hear the sea in it.")
item("kelp_wrap", "Kelp Wrap", "food", 120, 2, energy=40, heal=2)
item("frost_lily", "Frost Lily", "material", 160, 3, desc="Never melts.")
item("ember_glass", "Ember Glass", "material", 220, 3, desc="Glass made in a volcano by a very patient cat.")
item("starfish_snack", "Starfish Snack (biscuit)", "food", 90, 2, energy=30, friend=2)

GIFTS_NEW = {
 "c_coral": {"name": "Choking Reef", "colour": "ff7aa0", "gap": 2.8, "moves": [{"type": "zones", "n": 5, "fx": "slow", "linger": 3.0}, {"type": "ring", "n": 14, "gap_n": 3}, {"type": "pull", "secs": 1.2}],
   "rule": {"type": "back", "closed": 0.3, "open": 1.8, "turn": 1.4}, "tip": "Its front is armoured reef. Bait the circles, step round, and hit it from behind."},
 "c_kelp": {"name": "Black Tide", "colour": "4ad0a0", "gap": 2.6, "pull_force": 44.0, "moves": [{"type": "pull", "secs": 1.5}, {"type": "lines", "n": 3}, {"type": "spiral", "secs": 1.4}],
   "rule": {"type": "window", "after": "spiral", "secs": 2.2, "stagger": 1.0, "closed": 0.3, "open": 2.2}, "tip": "Get out of the tide's pull, wait out the spiral, then hit it while it's spent."},
 "c_ice": {"name": "Hollow Winter", "colour": "bfe9ff", "gap": 2.8, "clones": {"n": 2, "at": [0.6, 0.3]}, "moves": [{"type": "ring", "n": 12, "gap_n": 2}, {"type": "zones", "n": 4, "fx": "slow"}],
   "rule": {"type": "real", "open": 1.0}, "tip": "Its reflections cast no shadow. Hit the one with a shadow."},
 "c_ember": {"name": "Smother", "colour": "ff7a3a", "gap": 2.6, "trail": True, "moves": [{"type": "dash"}, {"type": "zones", "n": 5, "fx": "burn", "linger": 2.4}, {"type": "dash"}],
   "rule": {"type": "cycle", "on": 5.0, "off": 3.0, "closed": 0.25, "open": 2.0}, "tip": "It burns too hot to touch, then has to cool. Dodge the trails; strike when the ring goes white."},
}
G["gifts"].update(GIFTS_NEW)

COL = {
 "colony_coral": {"name": "Coral Reach", "tier": 1, "elder": "Grandmother Brine",
   "intro": ["You came by the ferry? Then the sea still lets some through. Good.", "Our star crystal sits in the reef shrine. It's fading, and the reef is turning grey and grabbing at us.",
             "We need food for the little ones, the grey crabs chased off, and the three tide beacons lit so the shoals come home. Then wake the crystal."],
   "need": {"#fish": 6, "kelp_wrap": 0}, "need_text": "The little ones haven't eaten properly in days.", "need_thanks": "Oh, the kits will eat tonight. Bless you.",
   "foe_word": "Grey crabs", "kills": 8, "beacons": 3, "enemies": ["rock_crab", "mud_slime", "river_serpent"],
   "boss": "cboss_coral", "boss_name": "The Grey Reef", "boss_art": "cboss_coral", "gift": "c_coral",
   "crystal_dim": "A star crystal, pink as a shell, barely glowing. Something grey has grown over half of it.",
   "crystal_wake": "You lay your hands on the crystal. The grey reef around it shudders, peels away from the stone, and stands up.",
   "crystal_restored": "The crystal flares rose-gold. All across the reef, grey coral flushes back to colour, and the water fills with fish.",
   "crystal_after": "The crystal hums with the sound of the tide.", "thanks": "You gave us back the sea. Come and go as you please, friend of the reef.",
   "ability": "coral_ward", "ability_name": "Coral Ward", "ability_desc": "Hits land softer (+2 defence, always).", "spells": [], "mana": 0,
   "shop_who": "Reef trader", "shop": [["coral_charm", 900], ["kelp_wrap", 120], ["pearl", 300], ["starfish_snack", 90]]},
 "colony_kelp": {"name": "Kelp Hollow", "tier": 2, "elder": "Old Tidewhisker",
   "intro": ["The forest under the water is dying, and it was the only home we had.", "The crystal in the kelp temple feeds the kelp. The dark is feeding on the crystal.",
             "Bring us plank and rope to shore up the stilt-houses, chase the shadow serpents out, light the beacons, and wake the crystal."],
   "need": {"plank": 30, "rope": 6}, "need_text": "The stilt-houses lean further every tide.", "need_thanks": "That'll hold. That'll hold for years.",
   "foe_word": "Shadow serpents", "kills": 10, "beacons": 3, "enemies": ["river_serpent", "wisp", "slime"],
   "boss": "cboss_kelp", "boss_name": "The Black Tide", "boss_art": "cboss_kelp", "gift": "c_kelp",
   "crystal_dim": "A green star crystal wrapped in black kelp. Its light pulses slower each time.",
   "crystal_wake": "The black kelp unwinds from the crystal and gathers itself into a long, cold shape.",
   "crystal_restored": "Green light floods the hollow. The kelp lifts toward it like it's breathing again.",
   "crystal_after": "The crystal glows green and slow, like a heartbeat.", "thanks": "Swim with us any time. The sea knows you now.",
   "ability": "tideswim", "ability_name": "Tideswim", "ability_desc": "You can swim in any deep water, no partner needed.", "spells": [], "mana": 10,
   "shop_who": "Kelp weaver", "shop": [["tide_pearl", 1400], ["kelp_wrap", 120], ["rope", 30]]},
 "colony_ice": {"name": "Frostfin Isle", "tier": 3, "elder": "Captain Icewhisker",
   "intro": ["You picked a cold day to visit. Every day is a cold day now.", "Our crystal used to keep the isle just warm enough. Now the winter has a mind of its own, and it copies us.",
             "Firewood for the hearths, the wisps chased off, the beacons lit, and then we wake the crystal together."],
   "need": {"wood": 40, "coal": 10}, "need_text": "The hearths are down to embers.", "need_thanks": "Warm hands. You don't know what that means up here.",
   "foe_word": "Ice wisps", "kills": 10, "beacons": 4, "enemies": ["ice_wisp", "hill_wolf", "crystal_baby"],
   "boss": "cboss_ice", "boss_name": "Hollow Winter", "boss_art": "cboss_ice", "gift": "c_ice",
   "crystal_dim": "A pale blue crystal inside a block of ice that wasn't there last year.",
   "crystal_wake": "The ice cracks. Something steps out of it wearing your shape, then two more.",
   "crystal_restored": "The ice melts off the crystal in one long sigh. Snow keeps falling, but it's the gentle kind again.",
   "crystal_after": "The crystal glitters like frost on a window.", "thanks": "The isle is yours whenever you need a cold drink and a warm hearth.",
   "ability": "frost_step", "ability_name": "Frost Step", "ability_desc": "Chill, freeze and slow can't touch you. You also learn the Lull spell.", "spells": ["lull"], "mana": 10,
   "shop_who": "Ice fisher", "shop": [["frost_lily", 160], ["hot_cocoa", 160], ["starfish_snack", 90]]},
 "colony_ember": {"name": "Emberclaw Atoll", "tier": 4, "elder": "Lady Cinderpaw",
   "intro": ["Careful, the sand is hot. It's always been hot. Now it's angry.", "Our crystal tamed the mountain. The dark has woken it.",
             "Bring us glass and silver to rebuild the vents, put out the moths, light the beacons, and wake the crystal before the mountain wakes properly."],
   "need": {"glass": 10, "silver_bar": 3}, "need_text": "The vents are cracked. Glass and silver to patch them.", "need_thanks": "There. Now the mountain breathes where we tell it.",
   "foe_word": "Lantern moths", "kills": 12, "beacons": 4, "enemies": ["lantern_moth", "geode_golem", "shard"],
   "boss": "cboss_ember", "boss_name": "The Smother", "boss_art": "cboss_ember", "gift": "c_ember",
   "crystal_dim": "A crystal like a coal, red at the centre, black at the edges. The black is spreading.",
   "crystal_wake": "The black crust splits. What comes out is all heat and no light.",
   "crystal_restored": "The crystal blazes gold, and the mountain settles down like a cat by a fire.",
   "crystal_after": "The crystal glows like the last coal in a good fire.", "thanks": "Our fires are yours. Take some of the light with you.",
   "ability": "starfire", "ability_name": "Starfire", "ability_desc": "+20 max mana and the Radiance spell: a ring of starlight.", "spells": ["radiance"], "mana": 20,
   "shop_who": "Glassblower", "shop": [["ember_glass", 220], ["crystal_glass", 260], ["tide_pearl", 1400]]},
}
COL["colony_coral"]["need"] = {"#fish": 6}
OUT = {}
import zlib
_OLD = json.load(open(D + "/data/regions.json"))
_OLD = _OLD.get("regions", _OLD)


def _seed(rid):
    """Stable island seed: keep the seed the colony already has (so maps never
    reshape on a rerun), else derive one that's the same every run."""
    isl = (_OLD.get(rid) or {}).get("islands") or []
    if isl and isinstance(isl[0], dict) and "seed" in isl[0]:
        return int(isl[0]["seed"]) - 1
    return zlib.crc32(rid.encode()) % 900


for rid, c in COL.items():
    cols, rows = 96, 76
    # Islands: a big main island, two smaller ones joined by sand bars, and a reef islet.
    isl = [{"c": [40, 40], "r": 22, "seed": _seed(rid) + 1}, {"c": [72, 26], "r": 11, "seed": _seed(rid) + 2},
           {"c": [70, 56], "r": 10, "seed": _seed(rid) + 3}, {"c": [56, 33], "r": 5, "seed": 4}, {"c": [57, 48], "r": 5, "seed": 5},
           {"c": [18, 16], "r": 7, "seed": _seed(rid) + 6}]
    pts = {"elder": [40, 44], "shop": [44, 44], "crystal": [72, 24], "beacons": [[24, 30], [42, 57], [70, 58], [18, 16]][: c["beacons"]]}
    things = [{"type": "elder", "cell": pts["elder"], "hint": "A: " + c["elder"], "solid": True},
              {"type": "colony_shop", "cell": pts["shop"], "hint": "A: " + c["shop_who"], "solid": True},
              {"type": "star_crystal", "cell": pts["crystal"], "hint": "A: the star crystal", "solid": True}]
    for i, b in enumerate(pts["beacons"]):
        things.append({"type": "beacon", "key": "b%d" % i, "cell": b, "hint": "A: tide beacon", "solid": True})
    # Secrets: a buried cache on the islet, a message in a bottle, a lore stone.
    things += [{"type": "loot", "cell": [20, 18], "item": "pearl", "n": 1, "every": 7, "empty": "Just sand and a crab, now.", "hint": "A: dig", "solid": False},
               {"type": "note", "cell": [30, 40], "who": "", "text": "A carving on a flat stone: four crystals in a ring around a fifth, dark one. Under it, in merkitty scratch-script: 'They were one star, once.'", "hint": "A: carved stone", "solid": False},
               {"type": "loot", "cell": [68, 60], "item": "crystal_refined", "n": 1, "every": 5, "empty": "The tide will bring more.", "hint": "A: tide pool", "solid": False}]
    R[rid] = {"cols": cols, "rows": rows, "music": "beach", "backdrop": "sea", "ground": "grass", "path": "sand", "spawn": [40, 60], "pad": 6,
              "border": {"n": "water", "s": "water", "w": "water", "e": "water"},
              "exits": [{"rect": [38, 63, 4, 1], "scene": "beach", "spawn": [12, 22], "facing": "down", "label": "▼ ferry home"}],
              "paths": [[39, 44, 2, 20], [42, 34, 32, 2], [40, 50, 32, 2], [18, 22, 2, 20], [18, 41, 24, 2]], "islands": isl, "island_shore": "sand",
              "plateaus": [{"blobs": [{"c": [34, 32], "r": 7, "seed": 41}]}, {"blobs": [{"c": [74, 22], "r": 5, "seed": 42}]}],
              "patch_set": "sand", "ground_threshold": -0.05, "fruit": 0, "forage": 6,
              "gen": {"clumps": 2, "scatter": 18, "critters": ["seagull", "crab", "sparrow"], "critter_count": 8},
              "things": things, "enemies": [{"kind": k, "count": 3, "colony": True} for k in c["enemies"]], "npcs": [],
              "intro": [c["intro"][0]], "colony": rid}
    # Each island looks and feels like itself.
    LOOK = {"colony_coral": {"music": "colony_coral", "critters": ["seagull", "crab", "turtle"]},
            "colony_kelp": {"music": "colony_kelp", "ground": "teal_moss", "ground_seam": "teal_moss", "patch_set": "bog", "critters": ["frog", "heron", "dragonfly"], "weather": "fog"},
            "colony_ice": {"music": "colony_ice", "season": "winter", "patch_set": "snowpatch", "critters": ["seagull", "otter", "moon_rabbit"], "weather": "snow"},
            "colony_ember": {"music": "colony_ember", "ground": "dead_grass", "ground_seam": "ash", "patch_set": "sand", "critters": ["firefly", "crow", "snake"]}}
    lk = LOOK.get(rid, {})
    for key in ("music", "ground", "ground_seam", "patch_set", "weather", "season"):
        if key in lk:
            R[rid][key] = lk[key]
    if "critters" in lk:
        R[rid]["gen"]["critters"] = lk["critters"]
    scene(rid)
    E["enemies"]["cboss_" + rid.split("_")[1]] = {"hp": 70 + 30 * c["tier"], "dmg": 2 + c["tier"] // 2, "speed": 26, "xp": 50 + 20 * c["tier"], "tier": c["tier"] + 1,
        "abilities": [], "gift": c["gift"], "art": c["boss_art"], "name": c["boss_name"], "reward": 100 * c["tier"]}
    E["drops"]["cboss_" + rid.split("_")[1]] = [["crystal_refined", 1.0, 2]]
    OUT[rid] = {k: v for k, v in c.items() if k not in ("boss_art", "gift", "enemies")}
json.dump(R, open(D + "/data/regions.json", "w"), indent=1, ensure_ascii=False)
json.dump(E, open(D + "/data/enemies.json", "w"), indent=1, ensure_ascii=False)
json.dump(I, open(D + "/data/items.json", "w"), indent=1, ensure_ascii=False)
json.dump(G, open(D + "/data/gifts.json", "w"), indent=1, ensure_ascii=False)
json.dump(OUT, open(D + "/data/colonies.json", "w"), indent=1, ensure_ascii=False)
print("colonies:", list(OUT))
