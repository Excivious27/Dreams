#!/usr/bin/env python3
"""Dress every interior so homes and shops feel lived in.

Adds furniture along the walls (wall pictures and windows on the back wall,
shelves/dressers/plants down the sides, plants in the corners, a rug in the
middle) wherever the room is still bare. Added props carry "auto": true, so a
re-run replaces them instead of piling up. Never touches the door lane, the
cell in front of any thing, or a cell an NPC stands on.

    python3 tools/furnish.py      (then run tools/interior_reach.gd via check.sh)
"""
import json, os, random

ROOT = os.path.join(os.path.dirname(__file__), "..")
P = os.path.join(ROOT, "data/interiors.json")
M = json.load(open(os.path.join(ROOT, "art/gen/manifest.json")))
F = M.get("furniture", {})
I = json.load(open(P))

HOMES = {"cottage_a", "cottage_b", "cottage_c", "hazel_house", "mansion", "tam_hut", "moss_hut", "river_hut", "sel_camp",
         "lodge", "lighthouse", "fishing_hut", "water_mill", "stable", "quarry_office"}
WALL = ["painting2_a", "painting2_b", "painting2_c", "painting2_d", "painting2_e", "painting_a", "painting_b", "window_day", "clock", "mirror2", "window_day"]
HOME_SIDE = ["bookcase3_a", "dresser2_a", "plant2_a", "wardrobe2_a", "lamp_floor", "bookcase3_c", "dresser", "plant_b", "chest_closed", "bookcase2_b", "lamp_floor_b", "wardrobe2_b"]
SHOP_SIDE = ["barrel", "crate", "bookcase3_d", "plant2_c", "barrel", "lamp_floor", "crate_cabbage", "plant_c", "bookcase3_e", "flour_sacks"]
CORNER = ["plant2_a", "plant2_b", "plant2_c", "plant2_d", "plant_b", "plant_c"]
RUGS = ["rug_rect_blue", "rug_rect_green", "rug_rect_red", "rug_round_blue", "rug_round_green"]


def have(n):
    return n in F


def cells_of(p):
    x, y = p["cell"]
    return [(x + i, y) for i in range(int(p.get("w", 0)) + 1)]


added = 0
for rid, R in I.items():
    if rid.startswith("_") or not isinstance(R, dict):
        continue
    R["props"] = [p for p in R.get("props", []) if not p.get("auto")]
    cols, rows = int(R.get("cols", 14)), int(R.get("rows", 11))
    rng = random.Random(rid)
    home = rid in HOMES
    used = set()
    for p in R["props"]:
        used.update(cells_of(p))
    keep = set()
    for t in R.get("things", []):
        x, y = t["cell"]
        used.add((x, y))
        keep.update({(x, y + 1), (x, y - 1), (x + 1, y), (x - 1, y)})
    for n in R.get("npcs", []):
        if isinstance(n, dict) and "cell" in n:
            used.add(tuple(n["cell"]))
            keep.add(tuple(n["cell"]))
    dx, dy = R.get("door", [cols // 2, rows - 2])
    for y in range(2, rows):  # the lane from the door up the middle stays open
        for x in (dx - 1, dx, dx + 1):
            keep.add((x, y))
    floor = (cols - 2) * (rows - 3)
    if len(R["props"]) >= floor * 0.22:
        continue  # already well furnished

    def free(c, solid=True):
        x, y = c
        if not (1 <= x <= cols - 2 and 2 <= y <= rows - 2):
            return False
        return c not in used and (not solid or c not in keep)

    def put(name, c, solid=True, w=0):
        global added
        if not have(name):
            return False
        if not all(free((c[0] + i, c[1]), solid) for i in range(w + 1)):
            return False
        p = {"name": name, "cell": [c[0], c[1]], "auto": True}
        if w:
            p["w"] = w
        if not solid:
            p["solid"] = False
        R["props"].append(p)
        used.update((c[0] + i, c[1]) for i in range(w + 1))
        added += 1
        return True

    # Back wall: pictures and windows hang ON the wall row (y=1), every few cells.
    wall = WALL[:]
    rng.shuffle(wall)
    onwall = {tuple(p["cell"]) for p in R["props"] if p["cell"][1] <= 2 and not p.get("solid", True)}
    k = 0
    for x in range(2, cols - 2, 3):
        if any(abs(x - c[0]) <= 1 for c in onwall) or (x, 2) in used:
            continue
        nm = wall[k % len(wall)]
        if have(nm):
            R["props"].append({"name": nm, "cell": [x, 1], "solid": False, "auto": True})
            added += 1
            k += 1
    # Corners.
    for c in [(1, 2), (cols - 2, 2), (1, rows - 2), (cols - 2, rows - 2)]:
        put(rng.choice(CORNER), c)
    # Side walls, every other cell.
    side = (HOME_SIDE if home else SHOP_SIDE)[:]
    rng.shuffle(side)
    k = 0
    for y in range(3, rows - 2, 2):
        for x in (1, cols - 2):
            if put(side[k % len(side)], (x, y)):
                k += 1

json.dump(I, open(P, "w"), indent=1, ensure_ascii=False)
print("furnish: added", added, "props")
