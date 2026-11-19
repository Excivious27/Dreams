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

# Where people live (home kit + a living set), where they work (crates, barrels,
# lamps: no pianos or stoves in a stable), and public rooms (books, plants, lamps:
# no cabbage crates in the chapel or the bank). Everything else is a shop.
HOMES = {"cottage_a", "cottage_b", "cottage_c", "hazel_house", "mansion", "tam_hut", "moss_hut", "river_hut", "lodge"}
WORKS = {"stable", "quarry_office", "water_mill", "lighthouse", "fishing_hut", "sel_camp"}
PUBLIC = {"chapel", "bank", "library", "hall", "clinic", "school"}
# No window_day here: the walls draw their own windows (a prop one beside or on top looked doubled).
WALL = ["painting2_a", "painting2_b", "painting2_c", "painting2_d", "painting2_e", "painting_a", "painting_b", "clock", "mirror2"]
HOME_SIDE = ["bookcase3_a", "dresser2_a", "kitchen_stove", "wardrobe2_a", "lamp_floor", "bookcase3_c", "nightstand_a", "plant2_c", "chest_closed", "piano", "lamp_floor_b", "toy_chest", "pet_bed"]
SHOP_SIDE = ["barrel", "crate", "bookcase3_d", "plant2_c", "barrel", "lamp_floor", "crate_cabbage", "plant_c", "bookcase3_e"]
# "barrels3" (barrels + rope) / "low_table" are correct since the int_light alias fix; not added here so rooms keep their look.
WORK_SIDE = ["barrel", "crate", "lamp_floor", "plant2_c", "barrel", "crate", "plant_c", "bookcase3_d"]
PUBLIC_SIDE = ["bookcase3_d", "plant2_c", "lamp_floor", "bookcase3_e", "plant_c", "lamp_floor_b", "plant2_b", "globe2"]
CORNER = ["plant2_a", "plant2_b", "plant2_c", "plant2_d", "plant_b", "plant_c"]
RUGS = ["rug_rect_blue", "rug_rect_green", "rug_rect_red", "rug_round_blue", "rug_round_green", "rug2_blue", "rug2_green", "rug2_red", "rug2_round_red"]
TABLES = ["table_square_cloth", "table_round_cloth", "table_square"]
HUTS = {"tam_hut", "moss_hut", "river_hut", "lodge"}


def have(n):
    return n in F


def cells_of(p):
    x, y = p["cell"]
    return [(x + i, y) for i in range(int(p.get("w", 0)) + 1)]


added = 0
for rid, R in I.items():
    if rid.startswith("_") or not isinstance(R, dict) or R.get("no_furnish"):
        continue
    R["props"] = [p for p in R.get("props", []) if not p.get("auto")]
    cols, rows = int(R.get("cols", 14)), int(R.get("rows", 11))
    rng = random.Random(rid)
    home = rid in HOMES
    kit_all = HOME_SIDE if home else (WORK_SIDE if rid in WORKS else (PUBLIC_SIDE if rid in PUBLIC else SHOP_SIDE))
    # No pianos or kitchen stoves in reed huts, a lodge or the mansion's living room;
    # no bookcases or cabbage crates in the forge, potion shop or bakery.
    if rid in HUTS or rid == "mansion":
        kit_all = [k for k in kit_all if k not in ("piano", "kitchen_stove", "toy_chest")]
    if rid in ("smith", "potions", "bakery"):
        kit_all = [k for k in kit_all if k not in ("bookcase3_d", "bookcase3_e", "crate_cabbage")]  # SHOP_SIDE already has barrels and a crate
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
    for y in range(max(2, dy - 3), rows):  # the lane just inside the door stays open
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
    onwall |= {(int(w["x"]), 1) for w in R.get("wall_props", [])}
    wins = {int(w) for w in R.get("windows", [4, cols - 5])}

    def top_px(p):  # where a back-row piece's top lands once interior.gd fits it
        i = F.get(p["name"], {})
        aw, ah = i.get("cell_w", i.get("w", 32)), i.get("cell_h", i.get("h", 32))
        y = p["cell"][1]
        sc = min(0.5, ((int(p.get("w", 0)) + 1) * 16 * 1.2 + 4) / max(1, aw), min(54, (y + 1) * 16) / max(1, ah))
        return (y + 1) * 16 - ah * sc

    # Columns where a tall machine, stair or board by the back wall would hide a picture.
    tall = {c[0] for p in R["props"] if p["cell"][1] in (2, 3) and top_px(p) < 24 for c in cells_of(p)}
    k = 0
    for x in range(2, cols - 2, 3):
        # Never on a window, between two windows, behind a tall piece, or beside another picture.
        if x in wins or (x - 1 in wins and x + 1 in wins) or x in tall or any(abs(x - c[0]) <= 1 for c in onwall) or (x, 2) in used:
            continue
        nm = wall[k % len(wall)]
        if have(nm):
            R["props"].append({"name": nm, "cell": [x, 1], "solid": False, "auto": True})
            added += 1
            k += 1
    # Corners: one plant at most, the rest from the room's own kit.
    kit = kit_all[:]
    for i, c in enumerate([(1, 2), (cols - 2, 2), (1, rows - 2), (cols - 2, rows - 2)]):
        if c[1] == 2 and c[0] in wins:
            continue  # a back corner under a window stays clear (a crate would hide the glass)
        if c[1] == 2 and (c[0], 3) in used:
            continue  # a corner behind a back-row machine stays empty
        put(rng.choice(CORNER) if i == 0 else rng.choice(kit), c)
    # Homes: a living set in the middle (a rug under a table and two chairs), unless
    # the room already has its own table.
    has_table = any(p["name"].startswith(("table", "low_table", "round_set", "dining", "grand_desk", "map_table", "skin_bench", "reading_table")) for p in R["props"])
    if home and not has_table and cols >= 8 and rows >= 7:
        cx = cols // 2 + (2 if dx <= cols // 2 else -2)
        cy = rows // 2
        if put(rng.choice(TABLES), (cx, cy)):
            put("chair_d", (cx - 1, cy))  # faces right, toward the table
            put("chair_c", (cx + 1, cy))  # faces left
            put(rng.choice(RUGS), (cx - 1, cy + 1), solid=False, w=2)  # fitted to 3 cells, not 1
    # Side walls, every other cell.
    side = kit_all[:]
    rng.shuffle(side)
    k = 0
    def near_same(name, c):  # the same piece one or two cells away reads as copy-paste
        return any(p["name"] == name and abs(p["cell"][0] - c[0]) <= 1 and abs(p["cell"][1] - c[1]) <= 2 for p in R["props"])

    for y in range(4, rows - 3, 2):  # one free cell between corner and side pieces
        for x in (1, cols - 2):
            if (x, y - 1) in used or (x, y + 1) in used:
                continue  # never right above/below another piece (tall sprites stack)
            for _ in range(len(side)):
                if not near_same(side[k % len(side)], (x, y)):
                    break
                k += 1
            if put(side[k % len(side)], (x, y)):
                k += 1

json.dump(I, open(P, "w"), indent=1, ensure_ascii=False)
print("furnish: added", added, "props")
