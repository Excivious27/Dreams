#!/usr/bin/env python3
"""CONDUCT 14 P6 prop dressing -> data/props_c14.json (read by scripts/prop_dress.gd).

{scene: [{id, cell, layer, anim?}]}: id "group/name" (group defaults to props),
layer "prop" (solid y-sorted sprite), "deco" (walk-through sprite) or "under"
(ground-level, under the player: rails, rugs of litter). PropDress skips any cell
that is blocked, holds a thing/prop, is water or (prop/deco) a path at run time, so
this file can stay a plan: it lays lamp rows along the roads, furniture clusters
round the plaza, themed scatter in the open lots and rails in the rail yards.
Fixes c14_18-07 (sparse hub towns), c14_18-11 (empty colony islands),
c14_18-13 (bare Star Station / Breezehaven fields), c14_18-16 (Ruins without
ruin props), c14_18-19 (rail yards without track).
Usage: python3 tools/gen_props_c14.py [--check]
"""
import json
import os
import random
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "props_c14.json")
REG = os.path.join(ROOT, "data", "regions.json")
MAN = os.path.join(ROOT, "art", "gen", "manifest.json")

# scene -> recipe. lamp: lamp id along roads (every `lamp_step` cells, alternate sides);
# plaza: ids round the plaza layer's edge; scatter: [(ids, count)] in open lots;
# rails: rows of rail_h ("under") across the map; islands: scatter on island discs only.
RECIPES = {
    "iron_junction": {
        "lamp": "props/lamp2_tall_0", "lamp_step": 6,
        "plaza": ["props/bench2_iron_a", "props/city_planter", "props/bollard_a", "props/mailbox2_red", "props/bollard_b"],
        "scatter": [(["props/crates_a", "props/crates2_a", "props/barrel2_a", "props/city_pallets", "props/crates_pallet"], 16),
                    (["props/bollard_a", "props/signpost", "props/city_planter"], 8)],
        "rails": [14, 37],
    },
    "iron_freight_yards": {
        "lamp": "props/lamp2_tall_1", "lamp_step": 7,
        "scatter": [(["props/crates_a", "props/crates_b", "props/crates2_b", "props/barrel2_a", "props/barrel2_b", "props/city_pallets", "props/crates_pallet_b"], 22),
                    (["props/bollard_c", "props/rope_coil"], 6)],
        "rails": [8, 17, 26, 38],
    },
    "gilt_grand_plaza": {
        "lamp": "props/lamp2_tall_2", "lamp_step": 5,
        "plaza": ["props/topiary_a", "props/planter2_0", "props/bench2_green_a", "props/topiary_b", "props/planter2_1", "props/flowerbed_red"],
        "scatter": [(["props/topiary_a", "props/topiary_b", "props/topiary_c", "props/hedge2_pot"], 14),
                    (["props/flowerbed_pink", "props/flowerbed_yellow", "props/flowerbed_blue", "props/planter2_2", "props/planter2_3"], 14),
                    (["props/bench2_green_b", "props/statue2_founder"], 4)],
    },
    "frost_hearthhold": {
        "lamp": "nature/lamp_snow", "lamp_step": 6,
        "plaza": ["props/bench2_wood_a_winter", "props/planter2_0_winter", "props/barrel2_a", "props/planter2_1_winter"],
        "scatter": [(["props/snowdrift_0", "props/snowdrift_1", "props/snowdrift_2", "props/snowdrift_3", "props/snowdrift_4", "props/snowdrift_5"], 18),
                    (["nature/log_snow", "props/crates_a", "props/barrel2_b", "nature/bush_snow", "props/sled_rack" ], 12)],
    },
    "desert_mirage_post": {
        "lamp": "props/lamp2_short_0", "lamp_step": 7,
        "scatter": [(["nature/dune_%d" % i for i in range(10)], 26),
                    (["props/crates_a", "props/barrel2_a", "props/cart_covered", "props/barrel_a"], 8)],
    },
    "wind_breezehaven": {
        "lamp": "props/lamp2_short_1", "lamp_step": 6,
        "scatter": [(["props/skydeco_0", "props/skydeco_1", "props/skydeco_2", "props/skydeco_3", "props/skydeco_6"], 24),
                    (["props/planter2_0", "props/bench2_wood_a", "props/starflower_blue", "props/starflower_pink"], 10)],
    },
    "wind_starfall_garden": {
        "lamp": "props/lamp2_short_2", "lamp_step": 6,
        "scatter": [(["props/starflower_blue", "props/starflower_pink", "props/starflower_yellow", "props/skydeco_0", "props/skydeco_1", "props/skydeco_3"], 28),
                    (["props/moon_crystal_blue", "props/bench2_iron_a"], 5)],
    },
    "ruins": {
        "scatter": [(["props/bf_ruin_pillar", "props/bf_ruin_wall", "props/toppled_statue", "props/stone_arch"], 12),
                    (["props/rubble_a", "props/rubble_b", "nature/rock_m", "nature/rock_s"], 14)],
    },
    "colony_coral": {"islands": [(["props/shell_a", "props/shell_b", "props/shell_c", "props/bk_shell_conch", "props/bk_shell_scallop", "props/ri_shells_0", "props/ri_shells_1"], 40),
                                 (["props/rope_coil", "props/buoy2_red", "props/crab_pots2", "props/ri_fishing_net", "props/barrel2_a"], 14)]},
    "colony_kelp": {"islands": [(["props/shell_a", "props/shell_b", "props/ri_shells_0", "props/bk_shell_clam", "props/rope_coil"], 34),
                                (["props/buoy2_yellow", "props/crab_pots2", "props/ri_fishing_net", "props/crates_a"], 14)]},
    "colony_ice": {"islands": [(["props/snowdrift_0", "props/snowdrift_1", "props/snowdrift_2", "props/snowdrift_3", "props/snowdrift_4"], 40),
                               (["nature/log_snow", "props/crates_a", "props/barrel2_b", "props/rope_coil"], 12)]},
    "colony_ember": {"islands": [(["nature/rock_m", "nature/rock_s", "props/barrel2_a", "props/crates_b"], 30),
                                 (["props/rope_coil", "props/crab_pots2", "props/shell_c"], 12)]},
}


# C14b P3: dressing strips that loop as ambient motion (art name -> fps).
AMBIENT_FPS = {"buoy2_yellow": 5.0, "buoy2_red": 5.0}


def footprint(p):
    """Cells a region prop covers (with a 1-cell margin) so nothing lands inside it."""
    x, y = p["cell"]
    w = int(p.get("w") or 0)
    h = int(p.get("h") or 1)
    return {(cx, cy) for cx in range(x - 1, x + w + 2) for cy in range(y - h - 1, y + 2)}


def build(regions, man):
    out = {}
    for scene, rc in RECIPES.items():
        d = regions.get(scene)
        if d is None:
            continue
        cols, rows = int(d["cols"]), int(d["rows"])
        rng = random.Random(scene)
        taken = set()
        for p in d.get("props", []):
            taken |= footprint(p)
        things = d.get("things", [])
        for t in (things if isinstance(things, list) else []):
            if "cell" in t:
                tx, ty = t["cell"]
                taken |= {(tx + i, ty + j) for i in (-1, 0, 1) for j in (-1, 0, 1)}
        sx, sy = (d.get("spawn") or [cols // 2, rows // 2])[:2]
        taken |= {(int(sx) + i, int(sy) + j) for i in range(-2, 3) for j in range(-2, 3)}
        path = set()
        for pr in d.get("paths", []):
            for y in range(pr[1], pr[1] + pr[3]):
                for x in range(pr[0], pr[0] + pr[2]):
                    path.add((x, y))
        near_path = {(x + i, y + j) for (x, y) in path for i in (-1, 0, 1) for j in (-1, 0, 1)}
        lst = []

        def ok(c, margin=3):
            return (margin <= c[0] < cols - margin and margin <= c[1] < rows - margin
                    and c not in taken and c not in near_path)

        def put(id_, c, layer="prop"):
            g, n = id_.split("/", 1)
            if n not in man.get(g, {}):
                return False
            e = {"id": id_, "cell": [c[0], c[1]], "layer": layer}
            if n in AMBIENT_FPS and int(man[g][n].get("frames", 1)) > 1:
                e["anim"] = AMBIENT_FPS[n]  # C14b P3 (c14b_16-14): bob strips play (random start via Anim.apply)
            lst.append(e)
            taken.update({(c[0] + i, c[1] + j) for i in (-1, 0, 1) for j in (-1, 0, 1)})
            return True

        if rc.get("lamp"):  # lamps one cell off each road, alternating sides
            step = int(rc.get("lamp_step", 6))
            for k, pr in enumerate(d.get("paths", [])):
                x, y, w, h = pr
                if w >= h:
                    for i, xx in enumerate(range(x + 2, x + w - 1, step)):
                        c = (xx, y - 1) if (i + k) % 2 == 0 else (xx, y + h)
                        if c not in path and ok(c, 2):
                            put(rc["lamp"], c)
                else:
                    for i, yy in enumerate(range(y + 2, y + h - 1, step)):
                        c = (x - 1, yy) if (i + k) % 2 == 0 else (x + w, yy)
                        if c not in path and ok(c, 2):
                            put(rc["lamp"], c)
        for lay in d.get("layers", []):  # furniture ring round the plaza
            if not rc.get("plaza"):
                break
            x, y, w, h = lay["rect"]
            ring = [(xx, y - 1) for xx in range(x + 1, x + w - 1, 3)] + [(xx, y + h) for xx in range(x + 1, x + w - 1, 3)]
            ring += [(x - 1, yy) for yy in range(y + 2, y + h - 1, 3)] + [(x + w, yy) for yy in range(y + 2, y + h - 1, 3)]
            for i, c in enumerate(ring):
                if ok(c, 2):
                    put(rc["plaza"][i % len(rc["plaza"])], c)
        for row in rc.get("rails", []):  # track under everything; PropDress skips blocked cells
            for x in range(1, cols - 1):
                if (x, row) not in taken or (x, row) in path:
                    g, n = "props", "rail_h"
                    if n in man.get(g, {}):
                        lst.append({"id": "props/rail_h", "cell": [x, row], "layer": "under"})
        for ids, n in rc.get("scatter", []):
            ids = [i for i in ids if i.split("/", 1)[1] in man.get(i.split("/", 1)[0], {})]
            tries = 0
            placed = 0
            while ids and placed < n and tries < n * 60:
                tries += 1
                c = (rng.randrange(3, cols - 3), rng.randrange(3, rows - 3))
                if ok(c) and put(rng.choice(ids), c, "prop" if rng.random() < 0.5 else "deco"):
                    placed += 1
        for ids, n in rc.get("islands", []):
            ids = [i for i in ids if i.split("/", 1)[1] in man.get(i.split("/", 1)[0], {})]
            isl = d.get("islands") or []
            tries = 0
            placed = 0
            while ids and isl and placed < n and tries < n * 80:
                tries += 1
                il = rng.choice(isl)
                r = float(il["r"]) * 0.75
                c = (int(il["c"][0] + rng.uniform(-r, r)), int(il["c"][1] + rng.uniform(-r, r)))
                if (c[0] - il["c"][0]) ** 2 + (c[1] - il["c"][1]) ** 2 > r * r:
                    continue
                if ok(c) and put(rng.choice(ids), c, "deco"):
                    placed += 1
        out[scene] = lst
    return out


def main():
    regions = json.load(open(REG))
    regions = regions.get("regions", regions)
    man = json.load(open(MAN))
    data = build(regions, man)
    txt = json.dumps(data, indent=1, sort_keys=True) + "\n"
    if "--check" in sys.argv:
        cur = open(OUT).read() if os.path.exists(OUT) else ""
        if cur != txt:
            print("props_c14.json is stale: run python3 tools/gen_props_c14.py")
            sys.exit(1)
        print("props_c14.json up to date")
        return
    open(OUT, "w").write(txt)
    print("\n".join(f"{k}: {len(v)}" for k, v in data.items()))


if __name__ == "__main__":
    main()
