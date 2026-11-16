#!/usr/bin/env python3
"""World batch sheets (W1..). Uses slice_art helpers; merges into art/gen/manifest.json.
Run after slice_art.py and slice_art2.py:  python3 tools/slice_world.py
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_art import load, crop, scale_to, save, strip, bbox, fg_mask, cells_by_grid, cells_by_projection, TILE2
from slice_art2 import region_bbox, comps, props_from, tileset3x3
from PIL import Image
import numpy as np


def tile(rgba, box, inset=3):
    im = scale_to(crop(rgba, (box[0] + inset, box[1] + inset, box[2] - inset, box[3] - inset)), width=TILE2, height=TILE2, cover=True)
    # Kill dark grid-line remnants on the outer 2px by copying the 3rd row/col outward.
    a = np.asarray(im).copy()
    for k in (0, 1):
        a[k, :] = a[2, :]; a[-1 - k, :] = a[-3, :]
        a[:, k] = a[:, 2]; a[:, -1 - k] = a[:, -3]
    return Image.fromarray(a)


def sheet_from(tiles, cols):
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGBA", (TILE2 * cols, TILE2 * rows))
    for i, t in enumerate(tiles):
        out.alpha_composite(t, ((i % cols) * TILE2, (i // cols) * TILE2))
    return out


def grid_tiles(rgba, reg, cols, rows, inset=3):
    g = cells_by_grid(rgba, cols, rows, region=reg, trim=False)
    return [tile(rgba, b, inset) for row in g for b in row]


def save_set(name, tiles, cols):
    sh = sheet_from(tiles, cols)
    save(sh, "tiles", name)
    S.manifest["tiles"][name].update({"cell_w": TILE2, "cell_h": TILE2, "cols": cols})


# ---------------------------------------------------------------- W1 ground

def w1():
    rgba = load("w1_ground.png")
    # Six 3x3 grounds along the top row, each ~235px wide.
    names = ["g_short", "g_tall", "g_flower", "g_dry", "g_mud", "g_gravel"]
    xs = [(18, 255), (270, 505), (525, 760), (775, 1012), (1030, 1265), (1285, 1520)]
    for nm, (x0, x1) in zip(names, xs):
        save_set(nm, grid_tiles(rgba, (x0, 20, x1, 270), 3, 3, 6), 3)
    # Transitions: three bands (dirt, sand, stone), each 12 pieces laid out as 4 groups of 2x2.
    # Layout per band: [top edge L,R / bottom edge L,R] [left,right edges x2] [outer corners 2x2] [inner corners 2x2]
    bands = {"t_dirt": (300, 500), "t_sand": (515, 710), "t_stone": (725, 915)}
    groups = [(18, 290), (305, 578), (620, 893), (935, 1205), (1250, 1520)]
    for nm, (y0, y1) in bands.items():
        tiles = []
        for (x0, x1) in groups:
            tiles += grid_tiles(rgba, (x0, y0, x1, y1), 2, 2, 6)
        # 20 tiles: g0 = edge top(2) / bottom(2); g1 = left/right halves; g2,g3,g4 = corners variants
        save_set(nm, tiles, 4)
    # 12 scatter decorations.
    deco = cells_by_grid(rgba, 12, 1, region=(10, 925, 1525, 1015), trim=False)[0]
    for i, b in enumerate(deco):
        bb = region_bbox(rgba, (b[0] + 4, b[1] + 4, b[2] - 4, b[3] - 4))
        if bb:
            save(scale_to(crop(rgba, bb), width=TILE2, height=TILE2), "tiles", "w_deco_%d" % i)


# ---------------------------------------------------------------- W2 forest

def w2():
    rgba = load("w2_forest.png")
    save_set("forest_floor", grid_tiles(rgba, (12, 8, 230, 222), 3, 3, 6), 3)
    save_set("forest_path", grid_tiles(rgba, (255, 8, 470, 222), 3, 3, 6), 3)
    # forest-floor-meets-grass: 4x2 pieces
    save_set("t_forest", grid_tiles(rgba, (495, 8, 975, 222), 4, 2, 6), 4)
    deco = cells_by_grid(rgba, 10, 1, region=(8, 235, 985, 320), trim=False)[0]
    for i, b in enumerate(deco):
        bb = region_bbox(rgba, (b[0] + 3, b[1] + 3, b[2] - 3, b[3] - 3))
        if bb:
            save(scale_to(crop(rgba, bb), width=36, height=36), "nature", "fdeco_%d" % i)
    props_from(rgba, "nature", {
        "big_oak": ((15, 335, 255, 605), (96, 128)), "big_pine": ((265, 335, 415, 605), (72, 140)),
        "hollow_tree": ((420, 335, 665, 605), (128, 160)), "willow": ((670, 335, 850, 605), (96, 128)),
        "berry_thicket": ((855, 420, 985, 605), (56, 56)),
        "giant_log": ((15, 640, 315, 820), (128, 64)), "stump_axe": ((320, 640, 460, 820), (48, 56)),
        "forest_shrine": ((785, 630, 985, 820), (80, 96)),
        "hidden_pond": ((15, 830, 345, 1010), (144, 96)),
        "deer": ((355, 830, 540, 1010), (56, 64)), "fox": ((555, 870, 680, 1010), (40, 40)), "rabbit": ((695, 870, 820, 1010), (36, 36)), "owl": ((830, 850, 985, 1010), (48, 56)),
    })
    props_from(rgba, "buildings", {"woodcutter_hut": ((465, 630, 780, 820), (160, 112)),
                                   "great_tree": ((990, 10, 1536, 1015), (280, 520))})


# ---------------------------------------------------------------- W3 river

def w3():
    rgba = load("w3_river.png")
    W, H = rgba.shape[1], rgba.shape[0]
    # Row 1: river straight (2 variants, 4 frames each) ; bends 2x4 grid of 4-frame? Treat: two straights at (10..290),(295..575); bends at (580..1310) 2 rows x 8
    def strip4(reg, name, w=TILE2, h=TILE2, cover=True, group="tiles"):
        boxes = cells_by_grid(rgba, 4, 1, region=reg, trim=False)[0]
        frames = [scale_to(crop(rgba, (b[0] + 4, b[1] + 4, b[2] - 4, b[3] - 4)), width=w, height=h, cover=cover) for b in boxes]
        strip(frames, group, name)
    strip4((10, 8, 290, 160), "river_v")
    strip4((295, 8, 575, 160), "river_v2")
    # bends: top row 8 cells, bottom row 8 cells at x 580..1310, y 8..85 / 88..160
    for r, (y0, y1) in enumerate([(8, 85), (88, 160)]):
        boxes = cells_by_grid(rgba, 8, 1, region=(580, y0, 1310, y1), trim=False)[0]
        for k in range(2):
            frames = [scale_to(crop(rgba, (b[0] + 3, b[1] + 3, b[2] - 3, b[3] - 3)), width=TILE2, height=TILE2, cover=True) for b in boxes[k * 4:(k + 1) * 4]]
            strip(frames, "tiles", "river_bend_%d" % (r * 2 + k))
    # Row 2: river meets lake (4 frames), lake 9-slice animated ×3? Actually three 3x3 blocks at (335..655),(660..975),(980..1310): frames 1..3 of the lake 9-slice. We take block1 as the set.
    strip4((10, 175, 330, 320), "river_mouth", TILE2, TILE2 * 2)
    lake_frames = []
    for (x0, x1) in [(335, 655), (660, 975), (980, 1310)]:
        lake_frames.append(grid_tiles(rgba, (x0, 175, x1, 320), 3, 3, 6))
    # Save lake set as 3 animation frames of a 3x3: layout columns = 3 frames side by side (9 cols x 3 rows? simpler: one sheet per frame)
    for i, tiles in enumerate(lake_frames):
        save_set("lake_%d" % i, tiles, 3)
    # Row 3: lake meets grass (12 pieces), each a 4-frame mini strip? They look like 12 cells × (4 frames?) at y 330..400 — 24 cells: 12 pieces × 2 frames. Take frame 1 of each.
    for nm, (y0, y1) in [("t_water_grass", (330, 400)), ("t_water_sand", (405, 475))]:
        row = cells_by_projection(rgba, region=(10, y0, 1310, y1), row_gap=100, col_gap=3, min_size=30)
        boxes = sorted([b for r in row for b in r], key=lambda b: b[0])
        tiles = []
        for b in boxes:
            w = b[2] - b[0]
            h = b[3] - b[1]
            n = max(1, round(w / h))
            step = w / n
            for k in range(n):
                sq = (int(b[0] + k * step), b[1], int(b[0] + (k + 1) * step), b[3])
                tiles.append(scale_to(crop(rgba, sq), width=TILE2, height=TILE2, cover=True))
        print("  ", nm, len(tiles), "pieces")
        save_set(nm, tiles[:18], 6)
    # Row 4: waterfall (4 frames, tall), rapids (4), ford (4), wooden bridge (4 = 3 pieces + ?)
    strip4((10, 495, 330, 615), "waterfall", TILE2, TILE2 * 2)
    strip4((335, 495, 655, 615), "rapids")
    strip4((660, 495, 975, 615), "ford")
    strip4((980, 495, 1310, 615), "bridge_wood", TILE2 * 2, TILE2, False)
    # Row 5: stone bridge (4), dock 9-slice? (4 cells), rowboat (4)
    strip4((10, 630, 445, 745), "bridge_stone", TILE2 * 2, TILE2, False)
    props_from(rgba, "props", {"dock_piece": ((450, 630, 915, 745), (TILE2 * 2, TILE2))})
    strip4((920, 630, 1310, 745), "rowboat", TILE2 * 2, TILE2, False, "props")
    # Row 6: fishing hut (4 frames same), reeds (4+4), lily pads (8)
    props_from(rgba, "buildings", {"fishing_hut": ((10, 755, 165, 900), (112, 112))})
    boxes = cells_by_grid(rgba, 8, 1, region=(670, 755, 1310, 825), trim=False)[0]
    for i, b in enumerate(boxes[:4]):
        save(tile(rgba, b, 3), "nature", "reeds_%d" % i)
    for i, b in enumerate(boxes[4:8]):
        save(tile(rgba, b, 3), "nature", "cattail_%d" % i)
    boxes = cells_by_grid(rgba, 8, 1, region=(670, 830, 1310, 900), trim=False)[0]
    for i, b in enumerate(boxes):
        save(tile(rgba, b, 3), "nature", "lily_%d" % i)
    # Row 7: ducks (2), heron (4), beaver dam (4)
    boxes = cells_by_grid(rgba, 6, 1, region=(10, 905, 665, 980), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=28) for b in boxes[:2]], "props", "duck")
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=44) for b in boxes[2:6]], "props", "heron")
    props_from(rgba, "props", {"beaver_dam": ((670, 905, 830, 980), (96, 48))})
    # Row 8: water mill (4 frames), lighthouse (4 frames)
    boxes = cells_by_grid(rgba, 4, 1, region=(10, 990, 665, 1195), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=200) for b in boxes], "buildings", "water_mill")
    boxes = cells_by_grid(rgba, 4, 1, region=(670, 990, 1310, 1195), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=224) for b in boxes], "buildings", "lighthouse")


# ---------------------------------------------------------------- W4 cliffs

def w4():
    rgba = load("w4_cliffs.png")
    # Two rows of 13 cliff pieces (2-tall and 3-tall variants).
    for r, (y0, y1, h) in enumerate([(8, 150, 2), (160, 340, 3)]):
        boxes = cells_by_grid(rgba, 13, 1, region=(10, y0, 1536, y1), trim=False)[0]
        for i, b in enumerate(boxes):
            bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
            if bb:
                save(scale_to(crop(rgba, bb), width=TILE2, height=TILE2 * h, cover=True), "tiles", "cliff%d_%d" % (h, i))
    props_from(rgba, "props", {
        "cliff_stairs_up": ((10, 350, 130, 500), (TILE2, TILE2 * 2)), "cliff_stairs_down": ((130, 350, 240, 500), (TILE2, TILE2 * 2)),
        "dirt_ramp": ((245, 350, 350, 500), (TILE2, TILE2 * 2)), "rope_ladder": ((355, 350, 455, 500), (TILE2, TILE2 * 2)),
        "cave_mouth": ((460, 350, 630, 500), (TILE2 * 3, TILE2 * 2)), "mine_entrance": ((635, 350, 760, 500), (TILE2 * 3, TILE2 * 2)),
        "boulder_l": ((770, 390, 840, 490), (36, 36)), "boulder_m": ((845, 405, 900, 490), (28, 28)), "boulder_s": ((900, 420, 950, 490), (20, 20)),
        "rockslide": ((955, 380, 1120, 500), (96, 56)), "goat": ((1125, 395, 1200, 490), (36, 40)),
        "lookout_tower": ((10, 520, 230, 1010), (96, 192)), "rope_bridge": ((240, 520, 775, 790), (160, 80)),
        "mountain_backdrop": ((780, 520, 1536, 1010), (384, 192)),
    })
    boxes = cells_by_grid(rgba, 4, 1, region=(1210, 395, 1536, 490), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=16) for b in boxes], "fx", "hawk_shadow")
    boxes = cells_by_grid(rgba, 4, 1, region=(200, 800, 775, 1010), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=96) for b in boxes], "props", "hot_spring")


# ---------------------------------------------------------------- batch 2

def w8():
    rgba = load("w8_deepmine.png")
    for nm, reg in {"mf_earth": (12, 10, 200, 190), "mf_stone": (215, 10, 405, 190), "mf_ice": (420, 10, 610, 190), "mf_lava": (625, 10, 810, 190)}.items():
        save_set(nm, grid_tiles(rgba, reg, 3, 3, 6), 3)
    def strip4(reg, name, w=TILE2, h=TILE2):
        boxes = cells_by_grid(rgba, 4, 1, region=reg, trim=False)[0]
        strip([scale_to(crop(rgba, (b[0] + 3, b[1] + 3, b[2] - 3, b[3] - 3)), width=w, height=h, cover=True) for b in boxes], "tiles", name)
    strip4((820, 10, 1115, 95), "lava")
    strip4((820, 100, 1115, 190), "cave_water")
    save_set("mf_ice_cracked", grid_tiles(rgba, (1130, 10, 1320, 190), 3, 3, 6) + grid_tiles(rgba, (1335, 10, 1520, 190), 3, 3, 6), 3)
    # Walls per variant: 4 groups of 3 cols x 3 rows (earth, stone, ice, lava) at y 205..415
    for i, nm in enumerate(["earth", "stone", "ice", "lava"]):
        x0 = 12 + i * 205
        tiles = grid_tiles(rgba, (x0, 205, x0 + 195, 415), 3, 3, 4)
        save_set("mw_" + nm, tiles, 3)
    # Ore nodes row (9) and rock sizes (2 rows x 8)
    row = cells_by_grid(rgba, 9, 1, region=(850, 205, 1525, 275), trim=False)[0]
    for b, nm in zip(row, ["node_copper", "node_iron", "node_gold", "node_silver", "node_coal", "node_crystal", "node_dark", "node_ruby", "node_emerald"]):
        bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
        if bb: save(scale_to(crop(rgba, bb), width=40, height=40), "props", nm)
    for r, (y0, y1) in enumerate([(280, 345), (350, 415)]):
        row = cells_by_grid(rgba, 8, 1, region=(850, y0, 1525, y1), trim=False)[0]
        for i, b in enumerate(row):
            bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
            if bb: save(scale_to(crop(rgba, bb), width=44 if i % 2 else 28, height=44 if i % 2 else 28), "props", "mrock_%s_%d" % (["earth", "stone", "ice", "lava"][i // 2], r))
    props_from(rgba, "props", {
        "ladder_a": ((12, 440, 70, 560), (24, 56)), "ladder_b": ((75, 440, 130, 560), (24, 56)),
        "beam_lamp": ((135, 440, 275, 560), (64, 56)), "beam_b": ((280, 440, 375, 560), (48, 56)), "beam_c": ((380, 440, 445, 560), (36, 56)), "beam_d": ((450, 440, 545, 560), (48, 56)),
        "elevator": ((555, 440, 710, 615), (72, 96)), "cart": ((715, 450, 800, 530), (40, 40)), "cart_full": ((805, 450, 890, 530), (40, 40)),
        "rail_v": ((900, 450, 975, 530), (32, 32)), "rail_c": ((980, 450, 1060, 530), (32, 32)), "rail_h": ((1065, 450, 1140, 530), (32, 32)), "rail_c2": ((1145, 450, 1220, 530), (32, 32)), "rail_x": ((1225, 450, 1300, 530), (32, 32)), "rail_end": ((1305, 450, 1380, 530), (32, 32)), "rope_fence": ((1390, 450, 1525, 530), (64, 32)),
        "skeleton": ((12, 580, 110, 690), (44, 40)), "bones": ((115, 600, 200, 690), (36, 28)), "pick_rock": ((200, 590, 285, 690), (36, 36)), "treasure": ((285, 600, 375, 690), (36, 32)), "shaft": ((380, 580, 495, 690), (48, 48)),
        "stalagmite_a": ((950, 590, 1010, 690), (24, 40)), "stalagmite_b": ((1010, 590, 1060, 690), (24, 40)),
        "stalactite_a": ((810, 700, 890, 800), (24, 40)), "stalactite_b": ((890, 700, 950, 800), (24, 40)), "stalactite_c": ((950, 700, 1020, 800), (24, 40)),
        "geode_chamber": ((985, 570, 1536, 1015), (320, 256)),
    })
    row = cells_by_grid(rgba, 4, 1, region=(500, 600, 780, 690), trim=False)[0]
    for b, nm in zip(row, ["cluster_blue", "cluster_purple", "cluster_red", "cluster_green"]):
        bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
        if bb: save(scale_to(crop(rgba, bb), width=36, height=36), "props", nm)
    row = cells_by_grid(rgba, 3, 1, region=(780, 600, 945, 690), trim=False)[0]
    for b, nm in zip(row, ["gmush_red", "gmush_blue", "gmush_purple"]):
        bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
        if bb: save(scale_to(crop(rgba, bb), width=32, height=32), "props", nm)
    save_set("cave_lake", grid_tiles(rgba, (12, 705, 560, 885), 6, 2, 4), 6)


def w6():
    rgba = load("w6_farmland.png")
    for nm, reg in {"field_rows": (12, 10, 210, 215), "field_rows2": (225, 10, 425, 215), "wheat_1": (440, 10, 640, 215), "wheat_2": (655, 10, 855, 215), "orchard": (870, 10, 1065, 215),
                    "hay_field": (12, 230, 200, 415), "stone_wall_set": (210, 230, 470, 415), "hedge_set": (485, 230, 710, 415), "farm_track": (725, 230, 985, 415)}.items():
        save_set(nm, grid_tiles(rgba, reg, 3, 3, 6), 3)
    row = cells_by_grid(rgba, 3, 1, region=(1080, 20, 1330, 215), trim=False)[0]
    props_from(rgba, "props", {"trellis": ((1080, 20, 1330, 215), (128, 96))})
    # ditch: 4 cols x 3 rows (straight, corner, end frames)
    save_set("ditch", grid_tiles(rgba, (1000, 230, 1520, 415), 4, 3, 4), 4)
    props_from(rgba, "buildings", {
        "silo": ((12, 430, 165, 680), (80, 128)), "barn_big": ((170, 430, 460, 680), (160, 144)), "stable": ((465, 480, 690, 680), (128, 96)),
        "coop2": ((695, 500, 850, 680), (80, 88)), "grain_elevator": ((1170, 430, 1536, 1000), (192, 320)),
    })
    props_from(rgba, "props", {"pig_pen": ((860, 510, 1070, 680), (112, 80)), "trough2": ((1075, 560, 1165, 620), (48, 24)),
        "tractor": ((555, 700, 690, 830), (64, 64)), "bale_round": ((700, 720, 780, 830), (40, 40)), "bale_square": ((785, 720, 860, 830), (40, 40)),
        "farm_cart": ((860, 720, 975, 830), (64, 48)), "scarecrow_a": ((980, 700, 1060, 830), (32, 64)), "scarecrow_b": ((1065, 700, 1160, 830), (32, 64))})
    row = cells_by_grid(rgba, 4, 1, region=(12, 690, 545, 885), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=160) for b in row], "buildings", "windmill2")
    pairs = [("cow2", (12, 895, 300, 1010), 2), ("sheep2", (300, 895, 575, 1010), 2), ("chicken", (580, 895, 785, 1010), 2)]
    for nm, reg, n in pairs:
        row = cells_by_grid(rgba, n, 1, region=reg, trim=False)[0]
        strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=48 if nm != "chicken" else 32) for b in row], "props", nm)
    props_from(rgba, "props", {"pig": ((790, 905, 940, 1010), (48, 40)), "horse": ((950, 890, 1130, 1010), (64, 64))})


def w5():
    rgba = load("w5_beach.png")
    save_set("sand", grid_tiles(rgba, (12, 10, 205, 200), 3, 3, 9), 3)
    save_set("sand_wet", grid_tiles(rgba, (215, 10, 410, 200), 3, 3, 9), 3)
    # sand meets sea: two 4x2 groups = 16 pieces (frames). Use as 8 edge pieces x 2 frames; take first 8 as edges.
    g1 = grid_tiles(rgba, (420, 10, 680, 200), 4, 2, 3)
    g2 = grid_tiles(rgba, (690, 10, 950, 200), 4, 2, 3)
    save_set("t_sand_sea", g1 + g2, 4)
    save_set("sea", grid_tiles(rgba, (965, 10, 1170, 200), 3, 3, 6), 3)
    foam = cells_by_grid(rgba, 4, 2, region=(1180, 10, 1480, 200), trim=False)
    strip([tile(rgba, b, 3) for b in foam[0]], "tiles", "foam")
    strip([tile(rgba, b, 3) for b in foam[1]], "tiles", "foam2")
    row = cells_by_grid(rgba, 4, 1, region=(12, 215, 500, 325), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=72) for b in row], "props", "tide_pool")
    row = cells_by_grid(rgba, 12, 1, region=(510, 215, 1525, 325), trim=False)[0]
    for b, nm in zip(row, ["shell_a", "shell_b", "shell_c", "starfish", "seaweed", "driftwood", "crab", "bucket", "sandcastle", "footprints", "bottle", "coconut_p"]):
        bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
        if bb: save(scale_to(crop(rgba, bb), width=28, height=28), "props", nm)
    props_from(rgba, "nature", {"palm": ((12, 335, 215, 575), (72, 128))})
    props_from(rgba, "buildings", {"beach_hut": ((225, 335, 540, 575), (144, 128)), "galleon": ((12, 730, 950, 1010), (448, 160))})
    save_set("pier", grid_tiles(rgba, (545, 340, 900, 575), 3, 2, 4), 3)
    props_from(rgba, "props", {"beached_boat": ((915, 380, 1100, 540), (96, 72)), "shipwreck_small": ((1110, 335, 1536, 575), (224, 112)),
        "lifeguard": ((245, 600, 370, 715), (40, 64)), "umbrella_red": ((375, 600, 530, 715), (64, 64)), "umbrella_blue": ((535, 600, 690, 715), (64, 64)), "umbrella_yellow": ((695, 600, 860, 715), (64, 64))})
    row = cells_by_grid(rgba, 2, 1, region=(12, 600, 240, 715), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=48) for b in row], "props", "buoy")
    row = cells_by_grid(rgba, 4, 1, region=(870, 600, 1255, 715), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=48) for b in row], "props", "bonfire")
    row = cells_by_grid(rgba, 2, 1, region=(1265, 600, 1525, 715), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=36) for b in row], "props", "seagull")
    row = cells_by_grid(rgba, 5, 2, region=(960, 740, 1536, 1010), trim=False)
    for r in range(2):
        for i, b in enumerate(row[r]):
            bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
            if bb: save(scale_to(crop(rgba, bb), width=40, height=40), "nature", "dune_%d" % (r * 5 + i))


def w7():
    rgba = load("w7_town.png")
    for nm, reg in {"cobble_a": (12, 10, 150, 150), "cobble_b": (160, 10, 300, 150), "brick_road": (310, 10, 450, 150), "flagstone": (460, 10, 600, 150)}.items():
        save_set(nm, grid_tiles(rgba, reg, 3, 3, 5), 3)
    props_from(rgba, "props", {
        "low_wall_a": ((610, 20, 765, 80), (80, 24)), "low_wall_b": ((610, 95, 765, 150), (80, 24)),
        "iron_fence": ((775, 20, 895, 75), (64, 24)), "iron_fence_v": ((905, 20, 960, 80), (24, 32)), "iron_gate": ((970, 20, 1230, 80), (128, 32)),
        "iron_fence_b": ((775, 95, 895, 150), (64, 24)), "iron_corner": ((905, 95, 960, 150), (24, 32)), "iron_gate_b": ((970, 95, 1230, 150), (128, 32)),
        "hedge_corner": ((1245, 20, 1395, 80), (64, 32)), "hedge_short": ((1245, 95, 1320, 150), (32, 24)), "hedge_corner_b": ((1405, 20, 1536, 80), (64, 32)), "hedge_b": ((1405, 95, 1536, 150), (64, 32)),
        "flowerbed_red": ((12, 170, 130, 270), (48, 32)), "flowerbed_yellow": ((135, 170, 240, 270), (48, 32)), "flowerbed_pink": ((245, 170, 350, 270), (48, 32)), "flowerbed_blue": ((355, 170, 465, 270), (48, 32)),
        "lamp_lit": ((475, 170, 545, 270), (24, 56)), "lamp_unlit": ((550, 170, 610, 270), (24, 56)), "lamp_tall_a": ((615, 170, 675, 270), (24, 56)), "lamp_tall_b": ((680, 170, 735, 270), (24, 56)),
        "lamp_arm_a": ((740, 170, 810, 270), (32, 56)), "lamp_arm_b": ((815, 170, 885, 270), (32, 56)),
        "bench_wood": ((900, 190, 1030, 260), (64, 32)), "bench_green": ((1045, 190, 1180, 260), (64, 32)),
        "mailbox_red": ((1160, 760, 1215, 850), (24, 40)), "notice_board": ((1035, 755, 1140, 850), (56, 48)), "well_stone": ((920, 760, 1020, 850), (48, 48)), "barrel_a": ((825, 780, 900, 850), (28, 32)), "cart_covered": ((700, 745, 820, 850), (64, 56)),
        "statue": ((665, 865, 790, 1000), (56, 72)), "dog_house": ((800, 880, 905, 1000), (48, 48)), "bicycle": ((915, 890, 1060, 1000), (64, 48)),
        "stall_red": ((190, 745, 310, 850), (64, 56)), "stall_blue": ((315, 745, 440, 850), (64, 56)), "stall_green": ((445, 745, 565, 850), (64, 56)), "stall_yellow": ((570, 745, 690, 850), (64, 56)),
    })
    props_from(rgba, "buildings", {
        "bandstand": ((1245, 95, 1536, 345), (144, 128)), "inn": ((12, 300, 345, 545), (176, 128)), "bakery": ((355, 345, 555, 545), (112, 112)), "clinic": ((565, 345, 780, 545), (112, 112)),
        "library": ((790, 335, 1010, 545), (128, 112)), "chapel": ((1020, 290, 1215, 545), (96, 144)), "school": ((1230, 360, 1536, 545), (160, 112)),
        "clock_tower": ((12, 560, 165, 860), (80, 160)), "station": ((185, 560, 620, 720), (224, 96)), "bell_tower": ((1245, 560, 1536, 1010), (160, 256)),
    })
    row = cells_by_grid(rgba, 4, 1, region=(380, 290, 580, 350), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=24) for b in row], "fx", "chimney_smoke")
    props_from(rgba, "props", {"train": ((625, 590, 1170, 720), (288, 64))})
    row = cells_by_grid(rgba, 4, 1, region=(12, 865, 655, 1000), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=64) for b in row], "props", "fountain2")
    row = cells_by_grid(rgba, 2, 1, region=(1070, 890, 1230, 1000), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=20) for b in row], "props", "pigeon")


# ---------------------------------------------------------------- batch 3

def w22():
    rgba = load("w22_interiors.png")
    floors = ["fl_wood", "fl_stone", "fl_tile", "fl_carpet_red", "fl_carpet_blue", "fl_carpet_green", "fl_concrete", "fl_grate"]
    xs = [(12, 200), (215, 400), (420, 610), (630, 815), (835, 1025), (1045, 1235), (1245, 1335), (1385, 1525)]
    for nm, (x0, x1) in zip(floors, xs):
        if nm in ("fl_concrete", "fl_grate"):
            save_set(nm, grid_tiles(rgba, (x0, 10, x1, 195), 2, 2, 6)[:1] * 9, 3)
        else:
            save_set(nm, grid_tiles(rgba, (x0, 10, x1, 195), 3, 3, 6), 3)
    walls = ["wl_plaster", "wl_brick", "wl_floral", "wl_striped", "wl_concrete", "wl_wood"]
    xs = [(12, 165), (185, 345), (365, 520), (545, 700), (720, 875), (895, 1050)]
    for nm, (x0, x1) in zip(walls, xs):
        g = cells_by_grid(rgba, 3, 1, region=(x0, 215, x1, 335), trim=False)[0]
        for i, b in enumerate(g):
            save(scale_to(crop(rgba, (b[0] + 3, b[1] + 3, b[2] - 3, b[3] - 3)), width=TILE2, height=TILE2 * 2, cover=True), "tiles", "%s_%s" % (nm, ["l", "m", "r"][i]))
    props_from(rgba, "furniture", {
        "door_wood": ((1065, 225, 1125, 335), (28, 56)), "door_wood_open": ((1135, 225, 1205, 335), (36, 56)), "door_metal": ((1220, 225, 1285, 335), (28, 56)), "door_metal_open": ((1300, 225, 1365, 335), (36, 56)),
        "door_glass": ((1380, 225, 1445, 335), (28, 56)), "door_glass_open": ((1455, 225, 1525, 335), (36, 56)),
        "window_day": ((12, 355, 120, 455), (48, 44)), "window_night": ((135, 355, 245, 455), (48, 44)), "window_boarded": ((255, 355, 360, 455), (48, 44)),
        "stairs_up": ((810, 345, 920, 465), (48, 56)), "stairs_down": ((935, 345, 1115, 465), (80, 56)),
        "rug_round_red": ((1130, 360, 1245, 455), (56, 44)), "rug_round_blue": ((1265, 360, 1380, 455), (56, 44)), "rug_round_green": ((1395, 360, 1510, 455), (56, 44)),
        "rug_rect_red": ((12, 480, 170, 560), (72, 40)), "rug_rect_blue": ((185, 480, 340, 560), (72, 40)), "rug_rect_green": ((355, 480, 510, 560), (72, 40)),
        "counter": ((525, 490, 690, 565), (80, 36)), "counter_corner": ((700, 480, 835, 575), (64, 48)), "counter_end": ((845, 490, 1000, 575), (72, 44)),
        "shelf_empty": ((1035, 480, 1175, 575), (64, 48)), "shelf_jars": ((1205, 480, 1340, 575), (64, 48)), "shelf_books": ((1375, 480, 1520, 575), (64, 48)),
        "table_round": ((12, 595, 115, 680), (48, 44)), "table_round_cloth": ((120, 595, 215, 680), (48, 44)), "table_square": ((225, 595, 325, 680), (48, 44)), "table_square_cloth": ((330, 595, 425, 680), (48, 44)),
        "table_long": ((440, 595, 600, 680), (80, 40)), "table_long_cloth": ((605, 595, 770, 680), (80, 40)),
        "chair_a": ((785, 595, 840, 680), (24, 40)), "chair_b": ((850, 595, 905, 680), (24, 40)), "chair_c": ((920, 595, 985, 680), (24, 40)), "chair_d": ((995, 595, 1060, 680), (24, 40)),
        "armchair_a": ((1090, 595, 1150, 680), (28, 40)), "armchair_b": ((1160, 595, 1220, 680), (28, 40)), "armchair_c": ((1230, 595, 1295, 680), (28, 40)), "armchair_d": ((1300, 595, 1365, 680), (28, 40)),
        "stool_wood": ((1385, 610, 1440, 680), (20, 28)), "stool_blue": ((1455, 610, 1510, 680), (20, 28)),
        "bed_blue": ((12, 700, 110, 800), (48, 56)), "bed_red": ((115, 700, 215, 800), (48, 56)), "bed_double_green": ((225, 700, 350, 800), (64, 56)),
        "wardrobe_a": ((375, 700, 470, 800), (40, 56)), "wardrobe_b": ((490, 700, 585, 800), (40, 56)), "dresser": ((600, 700, 700, 800), (44, 48)),
        "bookshelf_a": ((710, 700, 810, 800), (44, 56)), "bookshelf_b": ((830, 700, 935, 800), (44, 56)), "stove_iron": ((1425, 700, 1520, 800), (40, 56)),
        "sink": ((12, 830, 115, 920), (48, 48)), "fridge": ((130, 830, 215, 920), (36, 56)), "toilet": ((225, 830, 300, 920), (32, 48)), "bathtub": ((315, 830, 430, 920), (56, 40)), "mirror": ((450, 830, 515, 920), (28, 44)),
        "lamp_floor": ((545, 830, 600, 920), (24, 56)), "lamp_floor_b": ((605, 830, 665, 920), (24, 56)), "lamp_table_a": ((690, 830, 760, 920), (32, 44)), "lamp_table_b": ((765, 830, 835, 920), (32, 44)),
        "plant_a": ((845, 830, 920, 920), (32, 48)), "plant_b": ((925, 830, 985, 920), (32, 48)), "plant_c": ((990, 830, 1060, 920), (32, 48)), "clock_grand": ((1075, 830, 1145, 920), (28, 56)),
        "painting_a": ((1160, 840, 1250, 920), (40, 36)), "painting_b": ((1265, 840, 1350, 920), (40, 36)), "painting_c": ((1360, 840, 1430, 920), (36, 36)), "painting_d": ((1445, 840, 1525, 920), (36, 36)),
        "tv_off": ((12, 935, 130, 1015), (48, 40)), "tv_on": ((150, 935, 270, 1015), (48, 40)), "radio": ((300, 950, 400, 1015), (44, 32)), "safe": ((440, 935, 530, 1015), (40, 44)), "crate": ((560, 940, 660, 1015), (40, 40)), "barrel": ((690, 935, 785, 1015), (36, 44)), "trash": ((810, 935, 890, 1015), (28, 40)),
    })
    row = cells_by_grid(rgba, 4, 1, region=(380, 355, 790, 455), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=44) for b in row], "furniture", "window_rain")
    row = cells_by_grid(rgba, 4, 1, region=(950, 700, 1400, 800), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=56) for b in row], "furniture", "fireplace_anim")


def w23():
    rgba = load_hue("w23_wildlife.png")
    # Left block: 10 rows x 8 cells (4 idle + 4 walk), x 10..755. Right block same, x 770..1515.
    left = ["rabbit", "deer", "hedgehog", "turtle", "heron", "sparrow", "bee", "fish_jump", "seagull", "goat"]
    right = ["squirrel", "fox", "frog", "duck", "crow", "butterfly", "firefly", "crab", "bat", "owl"]
    rh = 800 / 10
    for r in range(10):
        y0, y1 = int(10 + r * rh), int(10 + (r + 1) * rh)
        for names, (x0, x1) in [((left,), (10, 755)), ((right,), (770, 1515))]:
            nm = names[0][r]
            boxes = row_sprites(rgba, (x0, y0 + 2, x1, y1 - 2), 8) if nm != "butterfly" else cells_by_grid(rgba, 8, 1, region=(x0, y0, x1, y1), trim=False)[0]
            h = {"deer": 56, "heron": 56, "goat": 48, "fox": 40, "owl": 44, "butterfly": 24, "bee": 20, "firefly": 20}.get(nm, 32)
            frames = []
            for b in boxes:
                bb = region_bbox(rgba, (b[0], b[1], b[2], b[3])) if nm != "butterfly" else region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
                frames.append(scale_to(crop(rgba, bb), height=h) if bb else Image.new("RGBA", (8, 8)))
            if nm in ("seagull", "bat"):
                frames[4:8] = frames[:4]  # the fly cells on the sheet are uneven; reuse idle
            strip(frames[:4], "wildlife/" + nm, "idle")
            strip(frames[4:8], "wildlife/" + nm, "walk")
            if nm == "butterfly":
                # three colour variants, 4 frames each
                boxes2 = row_sprites(rgba, (x0, y0 + 2, x1, y1 - 2), 12)
                for k, col in enumerate(["orange", "blue", "yellow"]):
                    fr = [scale_to(crop(rgba, region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))), height=24) for b in boxes2[k * 4:(k + 1) * 4]]
                    strip(fr, "wildlife/butterfly_" + col, "idle")
    # Row 11: cats (3 colours x 4), dog (4 idle + 4 walk)
    y0, y1 = 815, 905
    boxes = row_sprites(rgba, (10, y0, 950, y1), 12)
    for k, col in enumerate(["grey", "orange", "black"]):
        fr = [scale_to(crop(rgba, region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))), height=36) for b in boxes[k * 4:(k + 1) * 4]]
        strip(fr, "wildlife/cat_" + col, "idle")
    boxes = row_sprites(rgba, (960, y0, 1515, y1), 7)
    fr = [scale_to(crop(rgba, region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))), height=40) for b in boxes]
    strip(fr[:4], "wildlife/stray_dog", "idle"); strip(fr[4:7], "wildlife/stray_dog", "walk")
    y0, y1 = 915, 1010
    boxes = row_sprites(rgba, (10, y0, 460, y1), 5)
    strip([scale_to(crop(rgba, region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))), height=28) for b in boxes], "wildlife/rat", "idle")
    boxes = row_sprites(rgba, (490, y0, 950, y1), 5)
    strip([scale_to(crop(rgba, region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))), height=32) for b in boxes], "wildlife/pigeon", "idle")
    boxes = row_sprites(rgba, (960, y0, 1515, y1), 5)
    strip([scale_to(crop(rgba, region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))), height=28) for b in boxes], "wildlife/dragonfly", "idle")


def w9():
    img = Image.open(os.path.join(S.INC, "w9_sky.png")).convert("RGBA")
    W, H = img.size
    names = ["sky_day", "sky_sunset", "sky_night", "sky_mountains", "sky_sea", "sky_forest"]
    rh = H / 6
    for i, nm in enumerate(names):
        strip_img = img.crop((0, int(i * rh) + 4, W, int((i + 1) * rh) - 4))
        strip_img = strip_img.resize((1086, 112), Image.LANCZOS)
        save(strip_img, "backdrops", nm)


def w10():
    rgba = load("w10_crystal.png")
    save_set("g_glow", grid_tiles(rgba, (12, 10, 200, 200), 3, 3, 9), 3)
    save_set("g_glow_b", grid_tiles(rgba, (215, 10, 400, 200), 3, 3, 9), 3)
    save_set("pale_stone", grid_tiles(rgba, (420, 10, 610, 200), 3, 3, 6), 3)
    save_set("t_glow", grid_tiles(rgba, (625, 10, 1025, 200), 4, 2, 4) + grid_tiles(rgba, (1040, 10, 1240, 200), 2, 2, 4) + grid_tiles(rgba, (1255, 10, 1520, 200), 2, 2, 4), 4)
    row = cells_by_grid(rgba, 12, 1, region=(12, 215, 1200, 315), trim=False)[0]
    for i, b in enumerate(row):
        bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
        if bb: save(scale_to(crop(rgba, bb), width=32, height=32), "props", "cdeco_%d" % i)
    row = cells_by_grid(rgba, 4, 1, region=(1210, 225, 1520, 310), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))), height=20) for b in row], "fx", "crystal_firefly")
    props_from(rgba, "props", {
        "ccrystal_1": ((12, 330, 130, 460), (28, 28)), "ccrystal_2": ((140, 330, 250, 460), (40, 40)), "ccrystal_3": ((260, 330, 370, 460), (48, 52)), "ccrystal_4": ((380, 320, 540, 460), (72, 72)),
        "crystal_tree": ((545, 320, 790, 530), (112, 128)), "crystal_arch_a": ((12, 480, 175, 680), (72, 96)), "crystal_arch_b": ((180, 480, 330, 680), (72, 96)), "crystal_arch_c": ((340, 480, 540, 680), (96, 96)),
        "standing_stones": ((545, 530, 840, 690), (144, 96)), "crystal_bridge": ((845, 520, 1125, 690), (144, 80)),
    })
    row = cells_by_grid(rgba, 4, 1, region=(800, 320, 1520, 470), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=72) for b in row], "props", "glow_pond")
    row = cells_by_grid(rgba, 4, 1, region=(1135, 480, 1520, 560), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))), height=24) for b in row], "wildlife/crystal_fish", "idle")
    row = cells_by_grid(rgba, 2, 1, region=(1210, 575, 1420, 690), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))), height=32) for b in row], "wildlife/moon_rabbit", "idle")
    row = cells_by_grid(rgba, 4, 1, region=(12, 700, 1520, 1010), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=200) for b in row], "props", "star_crater")


def load_hue(name, thresh=90):
    """Like load() but keys out every magenta/purple-hued pixel regardless of
    brightness, so dark grid lines between cells never count as sprite."""
    img = np.array(Image.open(os.path.join(S.INC, name)).convert("RGBA")).astype(np.int32)
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    mag = np.minimum(r, b) - g
    bg = (mag > thresh) & (np.abs(r - b) < 70)
    out = img.astype(np.uint8)
    out[..., 3] = np.where(bg, 0, 255).astype(np.uint8)
    return out


def row_sprites(rgba, reg, n, gap=4):
    """Boxes of the n sprites in a row region, found by connected components so
    uneven cells never cut a sprite in half. Close components are merged, then
    the nearest pairs are merged until exactly n remain."""
    boxes = comps(rgba, reg, gap=gap, min_size=6)
    boxes = [list(b) for b in boxes]
    # merge overlapping / near x-ranges
    boxes.sort(key=lambda b: b[0])
    merged = []
    for b in boxes:
        if merged and b[0] <= merged[-1][2] + 3:
            m = merged[-1]
            m[0] = min(m[0], b[0]); m[1] = min(m[1], b[1]); m[2] = max(m[2], b[2]); m[3] = max(m[3], b[3])
        else:
            merged.append(b)
    while len(merged) > n:
        gaps = [(merged[i + 1][0] - merged[i][2], i) for i in range(len(merged) - 1)]
        g, i = min(gaps)
        a, b = merged[i], merged[i + 1]
        merged[i:i + 2] = [[min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])]]
    if len(merged) < n:
        # Sprites touch (dust trails, ground lines): fall back to equal cells across the content.
        x0 = min(b[0] for b in merged); x1 = max(b[2] for b in merged)
        y0 = min(b[1] for b in merged); y1 = max(b[3] for b in merged)
        cw = (x1 - x0) / n
        merged = [[int(x0 + i * cw), y0, int(x0 + (i + 1) * cw), y1] for i in range(n)]
    return [tuple(b) for b in merged]


# ---------------------------------------------------------------- batches 4-7

def w11():
    rgba = load("w11_wastes.png")
    save_set("dead_grass", grid_tiles(rgba, (12, 10, 225, 215), 3, 3, 9), 3)
    save_set("cracked_earth", grid_tiles(rgba, (235, 10, 445, 215), 3, 3, 9), 3)
    save_set("purple_soil", grid_tiles(rgba, (455, 10, 665, 215), 3, 3, 9), 3)
    save_set("t_dead", grid_tiles(rgba, (675, 10, 1110, 200), 5, 2, 4), 5)
    row = cells_by_grid(rgba, 9, 1, region=(12, 230, 775, 305), trim=False)[0]
    for i, b in enumerate(row):
        bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
        if bb: save(scale_to(crop(rgba, bb), width=32, height=32), "props", "wdeco_%d" % i)
    row = cells_by_grid(rgba, 4, 1, region=(785, 230, 1110, 305), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))), height=20) for b in row], "fx", "fog_wisp")
    props_from(rgba, "nature", {"dead_tree_s": ((20, 330, 130, 500), (36, 56)), "dead_tree_m": ((140, 330, 270, 500), (56, 72)), "dead_tree_l": ((280, 330, 450, 500), (80, 96)), "dead_giant": ((460, 320, 720, 520), (128, 160))})
    props_from(rgba, "props", {"dspike_1": ((730, 400, 800, 470), (24, 28)), "dspike_2": ((810, 380, 900, 470), (40, 40)), "dspike_3": ((910, 360, 1010, 470), (48, 56)), "dspike_4": ((1020, 360, 1120, 470), (56, 64)),
        "corrupt_well": ((20, 540, 190, 690), (72, 72)), "ruined_cottage": ((200, 510, 460, 690), (128, 96)), "toppled_statue": ((480, 560, 700, 690), (112, 64)),
        "dark_spire": ((1130, 10, 1536, 690), (192, 320))})
    row = cells_by_grid(rgba, 4, 1, region=(725, 500, 1110, 580), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))), height=28) for b in row], "fx", "storm_shadow")
    row = cells_by_grid(rgba, 4, 1, region=(725, 590, 1110, 690), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))), height=44) for b in row], "props", "grump_fire")
    row = cells_by_grid(rgba, 4, 1, region=(12, 700, 1536, 1010), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=260) for b in row], "props", "dark_spire_anim")


def w16():
    rgba = load("w16_hideout.png")
    save_set("asphalt2", grid_tiles(rgba, (12, 10, 200, 195), 3, 3, 6), 3)
    save_set("sidewalk2", grid_tiles(rgba, (210, 10, 395, 195), 3, 3, 6), 3)
    save_set("weedy_lot", grid_tiles(rgba, (405, 10, 590, 195), 3, 3, 6), 3)
    save_set("gravel2", grid_tiles(rgba, (600, 10, 775, 195), 3, 3, 6), 3)
    save_set("t_curb", grid_tiles(rgba, (12, 200, 775, 260), 12, 1, 3), 12)
    props_from(rgba, "props", {
        "rail_s": ((790, 30, 860, 110), (32, 32)), "rail_cv": ((865, 30, 940, 110), (32, 32)), "rail_x": ((945, 30, 1015, 110), (32, 32)),
        "chain_h": ((1030, 25, 1195, 115), (64, 36)), "chain_c": ((1210, 25, 1290, 115), (32, 36)), "chain_g": ((1300, 25, 1400, 115), (40, 36)), "chain_broken": ((1410, 25, 1520, 115), (48, 36)),
        "wood_fence_a": ((790, 130, 1025, 200), (96, 32)), "wood_fence_b": ((1040, 130, 1310, 200), (96, 32)), "wood_fence_pile": ((1320, 150, 1410, 200), (40, 24)), "wood_fence_c": ((1420, 130, 1520, 200), (40, 32)),
        "trailer": ((12, 290, 330, 460), (160, 80)), "gas_station": ((340, 280, 760, 460), (208, 96)), "diner_pink": ((770, 275, 1000, 460), (112, 96)), "diner_cyan": ((1010, 275, 1240, 460), (112, 96)),
        "motel_pink": ((12, 480, 395, 660), (192, 96)), "motel_cyan": ((405, 480, 790, 660), (192, 96)), "water_tower": ((800, 480, 900, 660), (48, 96)), "billboard": ((930, 500, 1100, 660), (80, 80)),
        "bus_stop": ((1110, 500, 1275, 660), (80, 72)), "payphone": ((1290, 520, 1350, 660), (24, 64)), "dumpster2": ((1360, 540, 1510, 660), (72, 56)),
        "drums": ((12, 700, 130, 790), (56, 44)), "tyres": ((140, 710, 240, 790), (48, 40)), "rusted_car": ((250, 700, 450, 790), (96, 48)), "pickup": ((460, 700, 660, 790), (96, 48)),
        "crow_a": ((900, 720, 960, 790), (24, 28)), "crow_b": ((970, 720, 1050, 790), (32, 28)),
        "pole_a": ((20, 810, 110, 910), (36, 56)), "pole_wire": ((120, 810, 330, 910), (96, 56)), "pole_corner": ((340, 810, 500, 910), (72, 56)), "storm_drain": ((510, 830, 670, 910), (64, 36)),
        "pole_b": ((20, 920, 180, 1010), (72, 48)), "pole_c": ((190, 920, 370, 1010), (80, 48)),
        "drive_in": ((1020, 690, 1536, 1010), (256, 160)),
    })
    row = cells_by_grid(rgba, 2, 1, region=(680, 710, 890, 790), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=44) for b in row], "props", "chained_dog")
    row = cells_by_grid(rgba, 4, 1, region=(690, 810, 940, 910), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=44) for b in row], "props", "fire_barrel2")
    row = cells_by_grid(rgba, 6, 1, region=(380, 920, 1010, 1010), trim=False)[0]
    for i, b in enumerate(row):
        bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
        if bb: save(scale_to(crop(rgba, bb), width=36, height=36), "props", "graffiti_%d" % i)


def w17():
    rgba = load("w17_docks.png")
    save_set("concrete_pier", grid_tiles(rgba, (12, 10, 180, 180), 3, 3, 6), 3)
    save_set("wood_dock", grid_tiles(rgba, (190, 10, 360, 180), 3, 3, 6), 3)
    save_set("t_dock_edge", grid_tiles(rgba, (370, 10, 1520, 180), 12, 2, 4), 12)
    g = []
    for x0, x1 in [(12, 185), (195, 365), (375, 560)]:
        g += grid_tiles(rgba, (x0, 195, x1, 300), 3, 2, 4)
    save_set("harbour", g[:9], 3)
    props_from(rgba, "buildings", {"warehouse_a": ((12, 320, 290, 540), (144, 112)), "warehouse_b": ((300, 320, 665, 540), (176, 112)), "warehouse_c": ((700, 330, 930, 540), (112, 96)),
        "lighthouse_rust": ((40, 740, 160, 1010), (56, 128)), "big_crane": ((1030, 690, 1536, 1010), (240, 160))})
    props_from(rgba, "props", {"crane": ((940, 320, 1110, 540), (80, 112)),
        "container_red": ((1150, 330, 1280, 390), (64, 32)), "container_blue": ((1320, 330, 1450, 390), (64, 32)), "container_orange": ((1150, 400, 1280, 450), (64, 32)), "container_green": ((1320, 400, 1450, 450), (64, 32)),
        "container_red2": ((1110, 470, 1200, 550), (40, 40)), "container_blue2": ((1210, 470, 1300, 550), (40, 40)), "container_orange2": ((1310, 470, 1400, 550), (40, 40)), "container_green2": ((1410, 470, 1500, 550), (40, 40)),
        "cargo_ship": ((12, 560, 625, 700), (320, 72)), "tugboat": ((640, 570, 870, 700), (112, 64)), "trawler": ((880, 560, 1140, 700), (128, 72)), "fish_market": ((1180, 570, 1390, 700), (112, 72)),
        "bollard_a": ((180, 750, 240, 810), (24, 28)), "bollard_b": ((245, 760, 300, 810), (24, 24)), "bollard_c": ((305, 750, 370, 810), (28, 28)), "rope_coil": ((390, 760, 460, 810), (28, 24)), "rope_loose": ((470, 760, 540, 830), (36, 36)),
        "oil_drums": ((575, 750, 680, 830), (48, 40)), "forklift": ((690, 750, 860, 830), (80, 40)), "crates_pallet": ((880, 760, 960, 830), (36, 36)), "crates_pallet_b": ((970, 760, 1090, 830), (56, 36)),
        "guard_booth": ((180, 840, 400, 970), (104, 64)), "floodlight_off": ((420, 850, 490, 990), (28, 64)), "floodlight_on": ((510, 850, 580, 990), (28, 64))})
    row = cells_by_grid(rgba, 2, 1, region=(640, 880, 790, 930), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=24) for b in row], "props", "gull_dock")
    row = cells_by_grid(rgba, 2, 1, region=(830, 880, 1010, 930), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=20) for b in row], "props", "rat_dock")


def w18():
    rgba = load("w18_neon.png")
    frames = [grid_tiles(rgba, (x0, 10, x0 + 160, 150), 2, 2, 4) for x0 in (12, 185, 355, 525)]
    for i, fr in enumerate(frames):
        save_set("wet_asphalt_%d" % i, fr[:1] * 9, 3)
    save_set("neon_sidewalk", grid_tiles(rgba, (695, 10, 860, 150), 3, 3, 5), 3)
    props_from(rgba, "props", {"crosswalk": ((870, 10, 1010, 150), (64, 64)), "storm_drain2": ((1020, 10, 1140, 150), (64, 64))})
    row = cells_by_grid(rgba, 4, 1, region=(1155, 25, 1525, 140), trim=False)[0]
    strip([scale_to(crop(rgba, (b[0] + 4, b[1] + 4, b[2] - 4, b[3] - 4)), width=48, height=40) for b in row], "props", "puddle")
    row = cells_by_grid(rgba, 2, 1, region=(12, 165, 390, 320), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=96) for b in row], "buildings", "neon_bar")
    row = cells_by_grid(rgba, 4, 1, region=(400, 165, 1090, 320), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=96) for b in row], "buildings", "arcade")
    row = cells_by_grid(rgba, 4, 1, region=(1110, 170, 1525, 320), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=96) for b in row], "buildings", "noodle_stand")
    props_from(rgba, "buildings", {"neon_hotel": ((12, 340, 340, 620), (176, 160)), "ramen_shop": ((350, 360, 550, 540), (112, 96)), "karaoke": ((570, 350, 790, 540), (112, 96))})
    props_from(rgba, "props", {"vend_red": ((815, 365, 900, 480), (36, 56)), "vend_red2": ((915, 365, 1000, 480), (36, 56)), "vend_blue": ((1070, 365, 1160, 480), (36, 56)), "vend_blue2": ((1170, 365, 1260, 480), (36, 56)), "vend_purple": ((1320, 365, 1410, 480), (36, 56)), "vend_purple2": ((1420, 365, 1510, 480), (36, 56)),
        "scooter": ((360, 550, 470, 620), (56, 40)), "taxi": ((500, 540, 650, 620), (72, 40)), "payphone2": ((690, 540, 760, 620), (28, 48)),
        "rooftop": ((515, 640, 785, 790), (128, 80)), "fire_escape": ((810, 640, 975, 790), (72, 80)), "alley": ((1000, 640, 1275, 790), (128, 80)), "cat_wall": ((1300, 640, 1525, 760), (112, 56))})
    row = cells_by_grid(rgba, 8, 1, region=(815, 530, 1525, 615), trim=False)[0]
    for i, b in enumerate(row):
        bb = region_bbox(rgba, (b[0] + 3, b[1] + 3, b[2] - 3, b[3] - 3))
        if bb: save(scale_to(crop(rgba, bb), width=40, height=40), "props", "neon_sign_%d" % i)
    row = cells_by_grid(rgba, 3, 1, region=(12, 640, 500, 760), trim=False)[0]
    for b, nm in zip(row, ["lanterns_red", "lanterns_cyan", "lanterns_pink"]):
        bb = region_bbox(rgba, (b[0] + 3, b[1] + 3, b[2] - 3, b[3] - 3))
        if bb: save(scale_to(crop(rgba, bb), width=80, height=48), "props", nm)
    row = cells_by_grid(rgba, 4, 1, region=(12, 800, 1525, 1010), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=112) for b in row], "buildings", "neon_dragon")


def w19():
    rgba = load("w19_uptown.png")
    save_set("marble", grid_tiles(rgba, (12, 10, 195, 180), 3, 3, 6), 3)
    save_set("polished_road", grid_tiles(rgba, (200, 10, 380, 180), 3, 3, 6), 3)
    save_set("lawn", grid_tiles(rgba, (390, 10, 570, 180), 3, 3, 6), 3)
    save_set("hedge_maze", grid_tiles(rgba, (580, 10, 940, 180), 4, 2, 3), 4)
    props_from(rgba, "props", {"gold_fence_a": ((950, 20, 1075, 100), (64, 36)), "gold_fence_b": ((1085, 20, 1210, 100), (64, 36)), "gold_fence_c": ((950, 110, 1075, 190), (64, 36)), "gold_gate": ((1085, 110, 1210, 190), (64, 40)),
        "lux_car_black": ((580, 200, 730, 280), (72, 40)), "lux_car_red": ((740, 200, 870, 280), (72, 40)), "limo": ((580, 290, 870, 350), (144, 36)), "guard_booth2": ((890, 200, 1010, 340), (56, 72)),
        "cctv_a": ((1040, 210, 1110, 300), (32, 40)), "cctv_b": ((1120, 210, 1190, 300), (32, 40)),
        "topiary_a": ((20, 630, 120, 740), (40, 56)), "topiary_b": ((130, 630, 210, 740), (36, 56)), "topiary_c": ((220, 630, 300, 740), (36, 56)), "statue_cane": ((320, 620, 420, 740), (44, 64)),
        "red_carpet": ((440, 650, 600, 720), (80, 32)), "red_carpet_end": ((600, 650, 730, 720), (64, 32)), "spotlight_pink": ((760, 620, 850, 740), (40, 56)), "spotlight_cyan": ((870, 620, 960, 740), (40, 56)), "rope_barrier": ((990, 640, 1110, 740), (56, 48))})
    row = cells_by_grid(rgba, 4, 1, region=(12, 200, 560, 345), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=72) for b in row], "props", "gold_fountain")
    props_from(rgba, "buildings", {"bank": ((12, 370, 280, 600), (144, 112)), "mansion": ((300, 360, 700, 600), (208, 128)), "penthouse": ((710, 370, 940, 600), (120, 120)), "president_tower": ((1225, 10, 1536, 1010), (160, 512))})
    row = cells_by_grid(rgba, 2, 2, region=(950, 360, 1215, 580), trim=False)
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=48) for rr in row for b in rr], "props", "helicopter")
    row = cells_by_grid(rgba, 4, 1, region=(12, 760, 1200, 1010), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=128) for b in row], "buildings", "tower_top_anim")


def w12():
    rgba = load("w12_skyislands.png")
    save_set("cloud", grid_tiles(rgba, (12, 10, 225, 215), 3, 3, 9), 3)
    save_set("cloud_star", grid_tiles(rgba, (235, 10, 445, 215), 3, 3, 9), 3)
    save_set("t_cloud_edge", grid_tiles(rgba, (455, 10, 1110, 215), 9, 2, 4), 9)
    save_set("float_stone", grid_tiles(rgba, (1120, 70, 1200, 150), 1, 1, 4) * 9, 3)
    row = cells_by_grid(rgba, 4, 1, region=(1215, 70, 1525, 150), trim=False)[0]
    strip([scale_to(crop(rgba, (b[0] + 3, b[1] + 3, b[2] - 3, b[3] - 3)), width=TILE2, height=TILE2, cover=True) for b in row], "tiles", "wind")
    row = cells_by_grid(rgba, 8, 1, region=(12, 235, 850, 335), trim=False)[0]
    for i, b in enumerate(row):
        bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
        if bb: save(scale_to(crop(rgba, bb), width=32, height=32), "props", "skydeco_%d" % i)
    row = cells_by_grid(rgba, 4, 1, region=(860, 250, 1220, 330), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))), height=20) for b in row], "fx", "mist_puff")
    row = cells_by_grid(rgba, 2, 1, region=(1240, 240, 1525, 330), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=36) for b in row], "wildlife/eagle", "idle")
    props_from(rgba, "nature", {"cloud_tree_a": ((20, 380, 160, 620), (64, 96)), "cloud_tree_b": ((170, 370, 330, 620), (80, 112)), "cloud_tree_c": ((340, 370, 500, 620), (80, 112))})
    props_from(rgba, "props", {"sky_stairs": ((510, 370, 720, 640), (96, 128)), "sky_temple": ((740, 350, 1080, 640), (160, 144)), "sky_bridge": ((60, 650, 860, 850), (352, 96)), "observatory": ((1050, 350, 1536, 1010), (224, 320))})
    row = cells_by_grid(rgba, 4, 1, region=(12, 860, 970, 1010), trim=False)[0]
    strip([scale_to(crop(rgba, (b[0] + 3, b[1] + 3, b[2] - 3, b[3] - 3)), width=224, height=112) for b in row], "fx", "sky_whale")


def w13():
    rgba = load("w13_mooncolony.png")
    save_set("moon_dust2", grid_tiles(rgba, (12, 10, 225, 215), 3, 3, 9), 3)
    save_set("metal_walk", grid_tiles(rgba, (235, 10, 445, 215), 3, 3, 9), 3)
    save_set("glass_floor", grid_tiles(rgba, (455, 10, 665, 215), 3, 3, 9), 3)
    row = cells_by_grid(rgba, 4, 1, region=(675, 10, 1015, 100), trim=False)[0]
    strip([scale_to(crop(rgba, (b[0] + 3, b[1] + 3, b[2] - 3, b[3] - 3)), width=TILE2, height=TILE2, cover=True) for b in row], "tiles", "glass_twinkle")
    row = cells_by_grid(rgba, 3, 1, region=(680, 110, 1080, 240), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=64) for b in row], "props", "airlock")
    save_set("dome_wall", grid_tiles(rgba, (12, 225, 665, 350), 9, 2, 4), 9)
    props_from(rgba, "buildings", {"greenhouse_dome": ((12, 360, 300, 540), (160, 112)), "moon_mine": ((815, 620, 1050, 770), (112, 72)), "moon_spire_big": ((1080, 10, 1536, 770), (240, 400))})
    props_from(rgba, "props", {"radio_dish": ((330, 360, 470, 540), (72, 96)), "solar_field": ((480, 370, 650, 520), (96, 80)), "rover": ((660, 380, 830, 480), (80, 48)), "crashed_probe": ((850, 370, 1060, 480), (96, 56)),
        "moonrock_l": ((12, 550, 110, 620), (44, 36)), "moonrock_m": ((120, 560, 200, 620), (32, 28)), "moonrock_s": ((210, 570, 270, 620), (24, 20)),
        "starflower_blue": ((300, 540, 370, 620), (32, 40)), "starflower_pink": ((380, 540, 450, 620), (32, 40)), "starflower_yellow": ((460, 540, 530, 620), (32, 40)),
        "alien_stall": ((300, 620, 540, 770), (120, 80)), "alien_vend_a": ((575, 640, 680, 770), (48, 64)), "alien_vend_b": ((690, 640, 790, 770), (48, 64))})
    row = cells_by_grid(rgba, 4, 1, region=(680, 530, 1080, 615), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=44) for b in row], "props", "glow_pool_moon")
    row = cells_by_grid(rgba, 2, 1, region=(12, 640, 280, 760), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=44) for b in row], "props", "moon_cow")
    row = cells_by_grid(rgba, 4, 1, region=(12, 780, 1536, 1010), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=160) for b in row], "props", "moon_spire_anim")


def w14():
    rgba = load("w14_station.png")
    save_set("metal_a", grid_tiles(rgba, (12, 10, 220, 215), 3, 3, 9), 3)
    save_set("metal_b", grid_tiles(rgba, (230, 10, 440, 215), 3, 3, 9), 3)
    save_set("hazard", grid_tiles(rgba, (450, 10, 660, 215), 3, 3, 9), 3)
    save_set("grating", grid_tiles(rgba, (670, 10, 880, 215), 3, 3, 9), 3)
    save_set("metal_wall", grid_tiles(rgba, (890, 25, 1525, 215), 6, 2, 4), 6)
    row = cells_by_grid(rgba, 3, 1, region=(12, 240, 540, 380), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=64) for b in row], "props", "sliding_door")
    row = cells_by_grid(rgba, 2, 1, region=(560, 240, 950, 380), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=56) for b in row], "props", "console")
    row = cells_by_grid(rgba, 4, 1, region=(960, 240, 1525, 380), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=64) for b in row], "props", "holo_table")
    row = cells_by_grid(rgba, 2, 1, region=(12, 390, 300, 545), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=72) for b in row], "props", "cryo_pod")
    row = cells_by_grid(rgba, 4, 1, region=(320, 390, 975, 545), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=72) for b in row], "props", "viewport")
    props_from(rgba, "props", {"cargo_grey": ((985, 420, 1105, 530), (56, 56)), "cargo_red": ((1115, 420, 1235, 530), (56, 56)), "cargo_yellow": ((1245, 420, 1365, 530), (56, 56)), "robot_arm": ((1380, 390, 1525, 545), (72, 72)),
        "vend_space": ((12, 570, 140, 720), (56, 72)), "bunk": ((150, 570, 310, 720), (72, 72)), "hydroponics": ((330, 570, 545, 720), (96, 72)), "escape_pod": ((1240, 570, 1525, 720), (128, 72)),
        "bridge": ((555, 745, 1525, 1010), (480, 128))})
    row = cells_by_grid(rgba, 4, 1, region=(560, 560, 1210, 740), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=96) for b in row], "props", "reactor")
    row = cells_by_grid(rgba, 4, 1, region=(12, 770, 540, 880), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=48) for b in row], "props", "teleporter2")
    row = cells_by_grid(rgba, 4, 1, region=(12, 890, 540, 1000), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=32) for b in row], "props", "drone")


def w15():
    rgba = load("w15_jungle.png")
    save_set("teal_moss", grid_tiles(rgba, (12, 10, 200, 190), 3, 3, 9), 3)
    save_set("violet_soil", grid_tiles(rgba, (210, 10, 400, 190), 3, 3, 9), 3)
    bio = [grid_tiles(rgba, (x0, 10, x0 + 190, 190), 3, 3, 9) for x0 in (410, 605, 800)]
    for i, fr in enumerate(bio):
        save_set("bio_path_%d" % i, fr, 3)
    save_set("t_pink_water", grid_tiles(rgba, (910, 10, 1525, 180), 10, 2, 4), 10)
    row = cells_by_grid(rgba, 12, 1, region=(12, 210, 1170, 300), trim=False)[0]
    for i, b in enumerate(row):
        bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
        if bb: save(scale_to(crop(rgba, bb), width=32, height=36), "props", "jdeco_%d" % i)
    props_from(rgba, "props", {"vines_a": ((1180, 195, 1300, 310), (56, 56)), "vines_b": ((1310, 195, 1420, 310), (56, 56)), "vines_c": ((1430, 195, 1525, 310), (48, 56)),
        "mushroom_tree_a": ((12, 330, 230, 640), (96, 144)), "mushroom_tree_b": ((240, 320, 500, 640), (128, 160)), "crashed_ship": ((500, 410, 880, 640), (192, 112)), "alien_statue": ((880, 330, 1110, 640), (96, 160))})
    row = cells_by_grid(rgba, 2, 1, region=(510, 330, 720, 440), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=56) for b in row], "props", "carnivore_plant")
    row = cells_by_grid(rgba, 4, 1, region=(1110, 330, 1525, 480), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=56) for b in row], "wildlife/jelly", "idle")
    row = cells_by_grid(rgba, 2, 1, region=(1130, 480, 1525, 640), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=72) for b in row], "wildlife/six_deer", "idle")
    row = cells_by_grid(rgba, 4, 1, region=(12, 690, 1525, 1010), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=160) for b in row], "props", "giant_flower")


def w20():
    rgba = load("w20_underground.png")
    save_set("sewer_brick", grid_tiles(rgba, (12, 10, 200, 160), 3, 3, 6), 3)
    save_set("sewer_brick_b", grid_tiles(rgba, (210, 10, 395, 160), 3, 3, 6), 3)
    save_set("sewer_mossy", grid_tiles(rgba, (405, 10, 595, 160), 3, 3, 6), 3)
    row = cells_by_grid(rgba, 4, 1, region=(605, 25, 940, 140), trim=False)[0]
    strip([scale_to(crop(rgba, (b[0] + 3, b[1] + 3, b[2] - 3, b[3] - 3)), width=TILE2, height=TILE2, cover=True) for b in row], "tiles", "sewer_water")
    props_from(rgba, "props", {"grate_a": ((955, 30, 1050, 125), (36, 36)), "grate_b": ((1060, 30, 1155, 125), (36, 36)), "sewer_ladder": ((1180, 15, 1240, 150), (24, 64)), "manhole_closed": ((1270, 40, 1390, 130), (48, 40)), "manhole_open": ((1400, 40, 1520, 130), (48, 40)),
        "pipe_s": ((12, 420, 190, 470), (80, 24)), "pipe_c": ((200, 410, 270, 480), (32, 36)), "pipe_t": ((280, 410, 345, 480), (32, 36)), "pipe_valve": ((355, 405, 430, 490), (36, 40)),
        "boxing_ring": ((420, 400, 780, 620), (176, 112)), "bleachers": ((790, 400, 975, 580), (96, 96)), "cage": ((1010, 410, 1240, 580), (112, 88)), "weight_bench": ((1290, 420, 1420, 560), (64, 72)), "punching_bag": ((1440, 400, 1520, 580), (36, 96)),
        "betting_booth": ((12, 500, 215, 720), (96, 112)), "bottle_crate_a": ((230, 500, 345, 580), (56, 40)), "bottle_crate_b": ((230, 600, 300, 720), (36, 56)), "bottle_crate_c": ((310, 610, 400, 720), (44, 56)),
        "card_table": ((460, 630, 740, 730), (128, 56)), "jukebox_a": ((800, 600, 895, 720), (44, 60)), "jukebox_b": ((905, 600, 1000, 720), (44, 60)), "bulb_off": ((1045, 605, 1115, 715), (28, 56)), "bulb_on": ((1125, 605, 1195, 715), (28, 56)), "cockroach": ((1440, 640, 1510, 690), (28, 16)),
        "ugraffiti_a": ((12, 750, 110, 850), (40, 40)), "ugraffiti_b": ((130, 750, 220, 850), (40, 40)), "ugraffiti_c": ((12, 850, 110, 940), (40, 40)), "ugraffiti_d": ((120, 850, 220, 940), (40, 40)), "ugraffiti_e": ((12, 940, 110, 1010), (40, 36)), "ugraffiti_f": ((120, 940, 220, 1010), (40, 36))})
    g = grid_tiles(rgba, (12, 170, 1525, 400), 11, 2, 4)
    save_set("sewer_wall", g, 11)
    row = cells_by_grid(rgba, 2, 1, region=(1230, 650, 1430, 700), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=20) for b in row], "props", "sewer_rat")
    row = cells_by_grid(rgba, 4, 1, region=(230, 750, 1525, 1010), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=128) for b in row], "props", "arena")


def w21():
    rgba = load("w21_countryside.png")
    save_set("highway", grid_tiles(rgba, (12, 10, 225, 215), 3, 3, 9), 3)
    save_set("highway_b", grid_tiles(rgba, (235, 10, 445, 215), 3, 3, 9), 3)
    save_set("shoulder", grid_tiles(rgba, (455, 10, 665, 215), 3, 3, 9), 3)
    save_set("t_road_edge", grid_tiles(rgba, (680, 10, 1195, 215), 5, 2, 4), 5)
    props_from(rgba, "props", {"tunnel": ((1200, 10, 1536, 360), (160, 160)), "highway_bridge": ((12, 230, 760, 360), (352, 64)),
        "motel_sign": ((12, 380, 185, 540), (80, 72)), "billboard2": ((210, 380, 440, 540), (112, 72)), "rest_stop": ((450, 380, 840, 540), (192, 80)), "payphone3": ((850, 400, 920, 540), (28, 64)), "broken_bus": ((930, 380, 1340, 540), (192, 80)), "hitchhiker": ((1380, 380, 1500, 540), (48, 64)),
        "farm_silo_b": ((350, 560, 580, 760), (112, 96)), "radio_tower_a": ((590, 560, 650, 760), (28, 96)), "radio_tower_b": ((660, 560, 720, 760), (28, 96)),
        "checkpoint_down": ((12, 790, 260, 1000), (120, 96)), "checkpoint_up": ((270, 790, 500, 1000), (112, 96)), "roadblock": ((510, 840, 1050, 1000), (256, 72)), "stone_head": ((1080, 580, 1536, 1000), (224, 208))})
    row = cells_by_grid(rgba, 4, 1, region=(770, 240, 1195, 360), trim=False)[0]
    strip([scale_to(crop(rgba, (b[0] + 3, b[1] + 3, b[2] - 3, b[3] - 3)), width=TILE2, height=TILE2 * 2, cover=True) for b in row], "tiles", "river_road")
    save_set("cornfield_night", grid_tiles(rgba, (12, 580, 330, 760), 4, 2, 4)[:9] if len(grid_tiles(rgba, (12, 580, 330, 760), 4, 2, 4)) >= 9 else grid_tiles(rgba, (12, 580, 330, 760), 4, 2, 4) * 2, 3)
    row = cells_by_grid(rgba, 4, 1, region=(740, 560, 1110, 760), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=96) for b in row], "props", "wind_turbine")


def w24():
    rgba = load_hue("w24_animals.png")
    names = ["chicken2", "rooster", "cow_brown", "cow_bw", "sheep_woolly", "pig_a", "pig_b", "goat2", "horse2", "duck2"]
    rh = 850 / 10
    for r, nm in enumerate(names):
        y0, y1 = int(8 + r * rh), int(8 + (r + 1) * rh)
        h = {"horse2": 56, "cow_brown": 48, "cow_bw": 48}.get(nm, 36)
        for anim, (x0, x1, n) in {"idle": (12, 455, 4), "walk": (465, 990, 5), "eat": (1000, 1220, 2), "baby": (1235, 1525, 4 if nm not in ("chicken2", "rooster", "duck2") else 5)}.items():
            boxes = row_sprites(rgba, (x0, y0 + 2, x1, y1 - 2), n)
            frames = []
            for b in boxes:
                bb = region_bbox(rgba, b)
                if bb: frames.append(scale_to(crop(rgba, bb), height=h if anim != "baby" else h * 0.6))
            if frames:
                strip(frames, "animals/" + nm, anim)
    row = cells_by_grid(rgba, 5, 1, region=(130, 870, 1250, 1010), trim=False)[0]
    for b, nm in zip(row, ["egg", "milk_pail", "wool", "feed_bag", "saddle"]):
        bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
        if bb: save(scale_to(crop(rgba, bb), width=32, height=32), "items", nm)


def w25():
    # This sheet uses a DARK magenta background (≈141,2,138), so key by hue not brightness.
    img = np.array(Image.open(os.path.join(S.INC, "w25_weather.png")).convert("RGBA")).astype(np.int32)
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    # Soft key: alpha = distance from the background colour; un-mix the colour
    # so translucent fog/dust/snow sheets become real alpha overlays.
    bgc = np.array([141, 2, 138], dtype=np.float64)
    f = img[..., :3].astype(np.float64)
    dist = np.sqrt(((f - bgc) ** 2).sum(-1))
    a = np.clip((dist - 12.0) / 150.0, 0.0, 1.0)
    fg = np.where(a[..., None] > 0.02, (f - (1.0 - a[..., None]) * bgc) / np.maximum(a[..., None], 0.02), f)
    rgba = np.zeros(img.shape, dtype=np.uint8)
    rgba[..., :3] = np.clip(fg, 0, 255).astype(np.uint8)
    rgba[..., 3] = (a * 255).astype(np.uint8)
    # grid lines are pure bright magenta: force them out
    rgba[..., 3] = np.where((np.minimum(r, b) - g > 200), 0, rgba[..., 3]).astype(np.uint8)
    names = [["ov_rain", "ov_heavy_rain"], ["ov_snow", "ov_blizzard"], ["ov_petals", "ov_leaves"], ["ov_fireflies", "ov_fog"], ["ov_dust", "ov_sandstorm"], ["ov_ash", "ov_meteors"]]
    for r in range(6):
        y0, y1 = 10 + r * 133, 10 + (r + 1) * 133
        for k in range(2):
            x0 = 30 + k * 760
            boxes = cells_by_grid(rgba, 4, 1, region=(x0, y0, x0 + 720, y1), trim=False)[0]
            frames = [scale_to(crop(rgba, (b[0] + 6, b[1] + 6, b[2] - 6, b[3] - 6)), width=128, height=96, cover=True) for b in boxes]
            strip(frames, "fx", names[r][k])
    boxes = cells_by_grid(rgba, 4, 1, region=(12, 820, 1525, 1010), trim=False)[0]
    strip([scale_to(crop(rgba, (b[0] + 4, b[1] + 4, b[2] - 4, b[3] - 4)), width=512, height=128) for b in boxes], "fx", "aurora")


def w26():
    rgba = load("w26_travel.png")
    props_from(rgba, "props", {"signpost_1": ((12, 30, 130, 200), (36, 64)), "signpost_2": ((145, 30, 265, 200), (40, 64)), "signpost_3": ((280, 30, 400, 200), (40, 64)), "milestone": ((460, 50, 580, 200), (36, 48)),
        "town_gate": ((590, 10, 960, 205), (176, 96)), "stone_arch": ((965, 10, 1225, 205), (112, 96)), "iron_gate2": ((1235, 10, 1525, 205), (128, 96)),
        "toll_closed": ((12, 220, 240, 380), (112, 80)), "toll_open": ((250, 220, 450, 380), (96, 80)), "bus_side": ((470, 230, 830, 380), (176, 64)), "train_car": ((850, 230, 1230, 380), (176, 64)), "train_engine": ((1240, 230, 1525, 380), (144, 64)),
        "ferry": ((12, 400, 390, 590), (176, 96)), "crystal_door_closed": ((12, 600, 240, 800), (112, 96)), "crystal_door_cracked": ((250, 600, 470, 800), (112, 96)), "crystal_door_open": ((480, 600, 700, 800), (112, 96)),
        "drawbridge_closed": ((720, 600, 1110, 800), (176, 96)), "drawbridge_open": ((1130, 600, 1525, 800), (176, 96))})
    row = cells_by_grid(rgba, 4, 1, region=(400, 400, 910, 590), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=96) for b in row], "props", "balloon")
    row = cells_by_grid(rgba, 4, 1, region=(930, 420, 1525, 590), trim=False)[0]
    strip([scale_to(crop(rgba, region_bbox(rgba, b)), height=64) for b in row], "props", "warp_pad")
    row = cells_by_grid(rgba, 12, 1, region=(12, 830, 1525, 1010), trim=False)[0]
    for b, nm in zip(row, ["pin_farm", "pin_town", "pin_forest", "pin_lake", "pin_beach", "pin_mine", "pin_mountain", "pin_meadow", "pin_wastes", "pin_moon", "pin_docks", "pin_tower"]):
        bb = region_bbox(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2))
        if bb: save(scale_to(crop(rgba, bb), width=40, height=48), "ui", nm)


def w27():
    img = Image.open(os.path.join(S.INC, "w27_worldmap.png")).convert("RGBA")
    img = img.resize((540, 960), Image.LANCZOS)
    save(img, "ui", "world_map")




# ---------------------------------------------------------------- batch W28-W31 (terrain)

def _cut(rgba, box, w=None, h=None, cover=False):
    bb = region_bbox(rgba, box)
    if not bb:
        return Image.new("RGBA", (w or 8, h or 8))
    im = crop(rgba, bb)
    if w and h:
        return scale_to(im, width=w, height=h, cover=cover)
    if h:
        return scale_to(im, height=h)
    return scale_to(im, width=w)


def _tile(rgba, cx, y0, y1, half=66, inset=5):
    bb = region_bbox(rgba, (cx - half, y0, cx + half, y1))
    if not bb:
        return Image.new("RGBA", (TILE2, TILE2))
    bb = (bb[0] + inset, bb[1] + inset, bb[2] - inset, bb[3] - inset)
    return scale_to(crop(rgba, bb), width=TILE2, height=TILE2, cover=True)


def w28():
    rgba = load("w28_cliff_grass.png")
    tiles = []
    for cx in [182, 348, 515, 685, 850, 1013, 1185, 1355]:
        tiles.append(_tile(rgba, cx, 118, 262))
    for cx in [114, 281, 437, 601, 766, 931, 1100, 1266, 1433]:
        tiles.append(_tile(rgba, cx, 312, 450))
    # order on the sheet: tl, top, tr, left, mid, right, ibl, ibottom, ibr, ileft, iright, itl, itop, itr, bl, bottom, br
    save_set("t_cliffg", tiles, 17)
    names = ["face_l", "face_a", "face_b", "face_c", "face_r", "fcorner_l", "fcorner_r", "stairs_l", "stairs_m", "stairs_r", "ramp"]
    for cx, nm in zip([70, 175, 283, 390, 498, 648, 785, 957, 1083, 1210, 1403], names):
        save(_cut(rgba, (cx - 50, 548, cx + 50, 748), TILE2, TILE2 * 2, cover=True), "tiles", "cliffg_" + nm)
    for cx, nm in zip([95, 235, 377], ["lip_l", "lip_m", "lip_r"]):
        save(_cut(rgba, (cx - 65, 862, cx + 65, 940), TILE2 * 2, TILE2), "tiles", "cliffg_" + nm)
    for cx, nm in zip([543, 693], ["gap_l", "gap_r"]):
        save(_cut(rgba, (cx - 58, 858, cx + 58, 950), h=64), "props", "cliff_" + nm)
    for cx, nm, h in zip([846, 940, 1060, 1178, 1322, 1458], ["s_a", "s_b", "m_a", "m_b", "l_a", "l_b"], [28, 24, 44, 44, 64, 64]):
        save(_cut(rgba, (cx - 58, 858, cx + 58, 955), h=h), "props", "boulder2_" + nm)


def w29():
    rgba = load("w29_cliff_stone.png")
    def band(y0, y1, n):
        return row_sprites(rgba, (20, y0, 1525, y1), n, gap=5)
    r1 = band(160, 243, 16)
    r2 = band(297, 383, 13)
    r3 = band(462, 528, 14)
    snow = band(596, 680, 9)
    def t(b):
        bb = region_bbox(rgba, b)
        if not bb:
            return Image.new("RGBA", (TILE2, TILE2))
        bb = (bb[0] + 4, bb[1] + 4, bb[2] - 4, bb[3] - 4)
        return scale_to(crop(rgba, bb), width=TILE2, height=TILE2, cover=True)
    # top4 bottom4 left4 right4 | outerTL TR BL BR, innerTL TR BL BR, T4, center
    tiles = [t(b) for b in r1] + [t(b) for b in r2]
    save_set("t_cliffs_raw", tiles, 16)
    top, bottom, left, right = r1[0:4], r1[4:8], r1[8:12], r1[12:16]
    outer, inner, tee, center = r2[0:4], r2[4:8], r2[8:12], r2[12]
    # Autotile order used by Art.T_CLIFF_IDX: tl top tr left mid right ibl ibottom ibr ileft iright itl itop itr bl bottom br (same as t_cliffg)
    ordered = [outer[0], top[0], outer[1], left[0], center, right[0], inner[2], bottom[1], inner[3], left[1], right[1], inner[0], top[1], inner[1], outer[2], bottom[0], outer[3]]
    save_set("t_cliffs", [t(b) for b in ordered], 17)
    for i, b in enumerate(r3[0:4]):
        save(t(b), "tiles", "cliffs_ledge_%d" % i)
    for i, b in enumerate(r3[4:8]):
        save(t(b), "tiles", "cliffs_slope_%d" % i)
    for i, b in enumerate(r3[8:12]):
        save(t(b), "tiles", "cliffs_ramp_%d" % i)
    for i, b in enumerate(r3[12:14]):
        save(t(b), "tiles", "cliffs_stairs_%d" % i)
    for i, b in enumerate(snow):
        save(t(b), "tiles", "cliffs_snow_%d" % i)
    save(_cut(rgba, (25, 770, 300, 1000), h=128), "props", "cave_mouth2")
    save(_cut(rgba, (318, 770, 596, 1000), h=128), "props", "mine_entrance2")
    strip([_cut(rgba, (x0, 780, x0 + 110, 1000), TILE2, TILE2 * 2, cover=True) for x0 in (608, 720, 828, 938)], "tiles", "waterfall2")
    save(_cut(rgba, (1060, 770, 1525, 1000), h=64), "props", "rope_bridge2")


def w30():
    rgba = load("w30_water_edges.png")
    cols = [18 + i * 115.5 for i in range(13)]
    def row(y0, y1):
        return [_cut(rgba, (int(x) + 2, y0, int(x) + 110, y1), TILE2, TILE2, cover=True) for x in cols]
    g = row(15, 97) + row(105, 187) + row(195, 277)
    save_set("water_grass_raw", g, 13)
    sd = row(295, 377) + row(385, 467) + row(475, 557)
    save_set("water_sand_raw", sd, 13)
    strip([_cut(rgba, (x0, 578, x0 + 100, 660), TILE2, TILE2, cover=True) for x0 in (18, 128, 238, 348)], "tiles", "water2")
    strip([_cut(rgba, (x0, 578, x0 + 100, 660), TILE2, TILE2, cover=True) for x0 in (480, 590, 700, 810)], "tiles", "water2_light")
    strip([_cut(rgba, (x0, 596, x0 + 130, 636), TILE2 * 2, 12) for x0 in (955, 1095, 1235, 1375)], "fx", "foam_strip")
    bends = [_cut(rgba, (int(x0), y0, int(x0) + 100, y1), TILE2, TILE2, cover=True) for (y0, y1) in [(690, 778), (790, 878)] for x0 in (18, 128, 238, 348)]
    save_set("river_bends", bends, 4)
    save(_cut(rgba, (500, 690, 945, 880), h=96), "props", "bridge_wood2")
    save(_cut(rgba, (1020, 690, 1460, 880), h=96), "props", "bridge_stone2")
    for x0, x1, nm in [(25, 160, "dock2_end"), (175, 300, "dock2_mid"), (315, 365, "dock2_post"), (390, 510, "dock2_corner"), (530, 665, "dock2_side")]:
        save(_cut(rgba, (x0, 905, x1, 1005), h=48), "props", nm)
    for i, x0 in enumerate((700, 795, 890, 985)):
        save(_cut(rgba, (x0, 915, x0 + 90, 1000), h=20), "nature", "lily2_%d" % i)
    for i, x0 in enumerate((1110, 1205, 1300, 1395)):
        save(_cut(rgba, (x0, 905, x0 + 95, 1005), h=40), "nature", "reeds2_%d" % i)


def w31():
    rgba = load("w31_paths.png")
    def block(x0, y0, name):
        tiles = []
        for r in range(4):
            for c in range(8):
                bx = x0 + c * 91.5
                by = y0 + r * 99
                tiles.append(_cut(rgba, (int(bx) + 2, int(by) + 2, int(bx) + 86, int(by) + 84), TILE2, TILE2, cover=True))
        save_set(name, tiles, 8)
    block(25, 25, "path_dirt_raw")
    block(790, 25, "path_cobble_raw")
    block(25, 425, "path_sand_raw")
    block(790, 425, "path_worn_raw")
    for i, nm in enumerate(["pebbles", "puddle", "hoofprints", "ruts", "leaves", "flower_edge", "mushroom_edge", "roots"]):
        x0 = 10 + i * 108
        save(_cut(rgba, (x0 + 2, 845, x0 + 104, 955), TILE2, TILE2), "tiles", "pdeco_" + nm)
    for i, nm in enumerate(["tuft_a", "tuft_b", "tuft_c", "clover", "dandelion", "pebbles"]):
        x0 = 905 + i * 100
        save(_cut(rgba, (x0, 850, x0 + 100, 950), h=28), "nature", "gdeco_" + nm)




# ---------------------------------------------------------------- batch W32-W35 (cinematics)

def _row_strip(rgba, reg, n, group, name, h, pad_to=None, gap=6):
    """n sprites in a labelled row -> strip with every frame scaled to height h.
    pad_to: force each frame onto a fixed canvas (w,h) centred at the bottom."""
    boxes = row_sprites(rgba, reg, n, gap=gap)
    frames = []
    for b in boxes:
        bb = region_bbox(rgba, b)
        fr = scale_to(crop(rgba, bb), height=h) if bb else Image.new("RGBA", (8, 8))
        frames.append(fr)
    if pad_to:
        pw, ph = pad_to
        out = []
        for f in frames:
            c = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
            c.alpha_composite(f, ((pw - f.width) // 2, ph - f.height))
            out.append(c)
        frames = out
    strip(frames, group, name)


def _row_particles(rgba, reg, n, group, name, factor, canvas):
    """Equal cells, each scaled by the same factor, centred on a fixed canvas."""
    x0, y0, x1, y1 = reg
    cw = (x1 - x0) / n
    frames = []
    for i in range(n):
        box = (int(x0 + i * cw) + 2, y0, int(x0 + (i + 1) * cw) - 2, y1)
        bb = region_bbox(rgba, box)
        c = Image.new("RGBA", canvas, (0, 0, 0, 0))
        if bb:
            f = crop(rgba, bb)
            f = scale_to(f, width=max(1, round(f.width * factor)), height=max(1, round(f.height * factor)))
            c.alpha_composite(f, ((canvas[0] - f.width) // 2, (canvas[1] - f.height) // 2))
        frames.append(c)
    strip(frames, group, name)


def _row_fixed(rgba, reg, n, group, name, h):
    """Rows where frames keep the same ground line but very different widths
    (falling trees): cut equal cells, trim each, keep a common frame box."""
    x0, y0, x1, y1 = reg
    cw = (x1 - x0) / n
    frames = []
    for i in range(n):
        box = (int(x0 + i * cw) + 2, y0, int(x0 + (i + 1) * cw) - 2, y1)
        bb = region_bbox(rgba, box)
        frames.append(crop(rgba, bb) if bb else Image.new("RGBA", (8, 8)))
    H = max(f.height for f in frames)
    sc = h / H
    frames = [scale_to(f, width=max(1, round(f.width * sc)), height=max(1, round(f.height * sc))) for f in frames]
    strip(frames, group, name)


def w32():
    rgba = load("w32_tree_fall.png")
    _row_fixed(rgba, (195, 62, 740, 188), 4, "fx", "oak_shake", 112)
    _row_fixed(rgba, (185, 192, 1525, 318), 8, "fx", "oak_fall_r", 112)
    _row_fixed(rgba, (185, 322, 1525, 448), 8, "fx", "oak_fall_l", 112)
    _row_fixed(rgba, (210, 458, 1400, 538), 6, "fx", "trunk_break", 56)
    for i, b in enumerate(row_sprites(rgba, (220, 540, 700, 612), 3)):
        save(scale_to(crop(rgba, region_bbox(rgba, b)), height=40), "nature", "stump2_%d" % i)
    _row_fixed(rgba, (195, 618, 740, 718), 4, "fx", "pine_shake", 112)
    _row_fixed(rgba, (185, 722, 1525, 840), 8, "fx", "pine_fall_r", 112)
    _row_particles(rgba, (215, 842, 1525, 910), 8, "fx", "leaf_burst", 0.6, (64, 64))
    _row_particles(rgba, (215, 920, 1000, 1005), 6, "fx", "wood_chips", 0.6, (64, 64))


def w33():
    rgba = load("w33_rock_break.png")
    rows = [("rock_s_break", 22, 125, 48), ("rock_m_break", 140, 252, 64), ("ore_copper_break", 272, 382, 56), ("ore_iron_break", 392, 502, 56), ("ore_crystal_break", 517, 628, 56)]
    for nm, y0, y1, h in rows:
        _row_strip(rgba, (290, y0, 1525, y1), 10, "fx", nm, h, (72, 72))
    _row_strip(rgba, (300, 650, 1200, 740), 6, "fx", "dust_puff", 44, (72, 64))
    _row_particles(rgba, (300, 760, 1100, 862), 6, "fx", "stone_chips", 0.6, (64, 64))
    for b, nm in zip(row_sprites(rgba, (300, 895, 1525, 1005), 10), ["wood", "stone", "copper", "iron", "shard", "fiber", "sap", "acorn", "pinecone", "berry"]):
        save(scale_to(crop(rgba, region_bbox(rgba, b)), width=32, height=32), "items", "pop_" + nm)


def w34():
    rgba = load("w34_crop_cinematics.png")
    _row_strip(rgba, (880, 338, 1260, 412), 4, "fx", "sprout_pop", 36, (48, 48))
    _row_strip(rgba, (1025, 440, 1400, 532), 4, "fx", "crop_wilt", 44, (56, 56))
    _row_strip(rgba, (1025, 525, 1400, 612), 4, "fx", "crop_revive", 44, (56, 56))
    _row_strip(rgba, (1025, 600, 1470, 708), 4, "props", "scarecrow3", 80, (96, 96))
    _row_strip(rgba, (1025, 712, 1515, 802), 6, "wildlife/crow", "land", 44, (56, 56))
    _row_strip(rgba, (1025, 805, 1440, 895), 4, "wildlife/crow", "takeoff", 44, (56, 56))
    _row_strip(rgba, (225, 845, 840, 1005), 4, "props", "sprinkler_spray", 96, (96, 96))
    # the farmer rows are a generic hero (not our playables): keep as reference strips
    _row_strip(rgba, (235, 65, 1010, 182), 6, "fx", "ref_hoe", 96)
    _row_strip(rgba, (235, 185, 1010, 300), 6, "fx", "ref_water", 96)
    for nm, y0, y1 in [("turnip", 425, 522), ("strawberry", 528, 620), ("corn", 628, 712), ("pumpkin", 715, 812)]:
        _row_strip(rgba, (235, y0, 810, y1), 6, "fx", "ref_harvest_" + nm, 96)


def w35():
    rgba = load("w35_fishing_swim.png")
    _row_strip(rgba, (195, 62, 770, 140), 6, "fx", "bobber_cast", 48, (72, 64))
    _row_strip(rgba, (195, 145, 550, 208), 4, "fx", "bobber2", 40, (56, 48))
    _row_strip(rgba, (755, 140, 1060, 210), 4, "fx", "bobber2_bite", 48, (56, 56))
    for nm, y0, y1 in [("a", 222, 298), ("b", 300, 375), ("c", 378, 452)]:
        _row_strip(rgba, (215, y0, 1020, y1), 8, "fx", "fish_jump_" + nm, 56, (72, 72))
    _row_strip(rgba, (180, 515, 560, 585), 6, "fx", "reel_splash", 48, (72, 56))
    _row_strip(rgba, (735, 510, 950, 580), 4, "fx", "alert", 44, (48, 56))
    _row_strip(rgba, (975, 505, 1250, 625), 3, "fx", "ref_catch_large", 96)
    _row_strip(rgba, (1275, 515, 1515, 625), 3, "fx", "ref_catch_small", 96)
    for nm, reg, n in [("swim_down", (175, 640, 705, 712), 6), ("swim_up", (175, 720, 705, 795), 6), ("swim_side", (175, 805, 705, 880), 6), ("tread", (950, 645, 1330, 712), 4), ("dive", (950, 718, 1410, 795), 6), ("climb_out", (945, 805, 1300, 890), 4)]:
        _row_strip(rgba, reg, n, "fx", "ref_" + nm, 56)
    _row_particles(rgba, (195, 905, 760, 970), 6, "fx", "ripple_ring", 0.6, (72, 40))




# ---------------------------------------------------------------- batch W36-W43 (emotes, portraits, interiors)

def _pieces(rgba, reg, names, group, factor=0.5, gap=6):
    """Labelled row of len(names) pieces, each scaled by `factor` (sheet 64px = 1 cell = 32px in art/gen)."""
    boxes = row_sprites(rgba, reg, len(names), gap=gap)
    for b, nm in zip(boxes, names):
        bb = region_bbox(rgba, b)
        if not bb:
            continue
        im = crop(rgba, bb)
        save(scale_to(im, width=max(1, round(im.width * factor)), height=max(1, round(im.height * factor))), group, nm)


def _anim(rgba, reg, n, group, name, factor=0.5, gap=6):
    boxes = row_sprites(rgba, reg, n, gap=gap)
    frames = []
    for b in boxes:
        bb = region_bbox(rgba, b)
        im = crop(rgba, bb) if bb else Image.new("RGBA", (8, 8))
        frames.append(scale_to(im, width=max(1, round(im.width * factor)), height=max(1, round(im.height * factor))))
    strip(frames, group, name)


def w36():
    rgba = load("w36_emotes.png")
    names = [["surprise", "confused", "heart", "heart_broken"], ["sweat", "angry", "music", "sleep"], ["idea", "laugh", "cry", "think"], ["gift", "coin", "star", "skull"]]
    xs = [(12, 380), (395, 765), (778, 1148), (1160, 1528)]
    ys = [(178, 265), (362, 448), (547, 633), (732, 818)]
    for r, (y0, y1) in enumerate(ys):
        for k, (x0, x1) in enumerate(xs):
            _anim(rgba, (x0, y0, x1, y1), 4, "emotes", names[r][k], 0.5)
    _pieces(rgba, (135, 920, 645, 1005), ["bubble_a", "bubble_b", "bubble_c", "bubble_think"], "emotes", 0.5)
    _anim(rgba, (915, 920, 1395, 1005), 4, "emotes", "talk", 0.5)


def w39():
    rgba = load("w39_portraits.png")
    ids = ["shopkeeper", "blacksmith", "potion", "mayor", "drifter", "fisherman", "artist", "scholar", "young_farmer", "innkeeper", "baker", "nurse"]
    moods = ["neutral", "happy", "sad", "angry", "surprised"]
    rows = [(130, 270), (275, 415), (420, 560), (565, 705), (710, 850), (855, 995)]
    lcols = [165, 285, 405, 525, 645]
    rcols = [932, 1050, 1168, 1286, 1404]
    for i, pid in enumerate(ids):
        y0, y1 = rows[i % 6]
        cols = lcols if i < 6 else rcols
        for m, x0 in zip(moods, cols):
            im = crop(rgba, (x0 + 3, y0 + 3, x0 + 108, y1 - 3))
            save(scale_to(im, height=96), "portraits/" + pid, m)


def w43():
    rgba = load("w43_interior_floors_walls.png")
    floors = ["fl_wood_light", "fl_wood", "fl_wood_dark", "fl_stone", "fl_tile", "fl_carpet_red", "fl_carpet_blue", "fl_carpet_green", "fl_carpet_purple", "fl_concrete", "fl_brick", "fl_bakery", "fl_clinic", "fl_inn"]
    xs = [(25, 148), (180, 303), (335, 458)]
    ys = [(140, 262), (305, 427), (470, 592), (635, 757), (800, 922)]
    i = 0
    for (y0, y1) in ys:
        for (x0, x1) in xs:
            if i >= len(floors):
                break
            save_set(floors[i], grid_tiles(rgba, (x0, y0, x1, y1), 3, 3, 3), 3)
            i += 1
    walls = ["wl_plaster", "wl_wood", "wl_striped", "wl_striped_red", "wl_striped_green", "wl_floral", "wl_floral_blue", "wl_stone", "wl_brick", "wl_bakery", "wl_clinic", "wl_library"]
    wy = [150, 210, 268, 328, 386, 446, 504, 562, 616, 670, 726, 782]
    wx = [(712, 802), (822, 920), (930, 1032), (1040, 1142), (1160, 1260), (1278, 1374), (1390, 1512)]
    parts = ["_l", "_m", "_m2", "_m3", "_r", "_corner", "_window"]
    for nm, y0 in zip(walls, wy):
        for (x0, x1), part in zip(wx, parts):
            save(_cut(rgba, (x0, y0, x1, y0 + 52), TILE2, TILE2 * 2, cover=True), "tiles", nm + part)
    _pieces(rgba, (215, 925, 570, 965), ["baseboard_wood", "baseboard_white", "baseboard_stone"], "tiles", 0.5)
    _pieces(rgba, (750, 905, 1090, 1000), ["doorway_wood", "doorway_stone", "doorway_ornate"], "furniture", 0.5)
    _pieces(rgba, (1290, 905, 1510, 1000), ["stairs2_up", "stairs2_down"], "furniture", 0.5)


def w40():
    rgba = load("w40_shop_interiors.png")
    _pieces(rgba, (35, 135, 895, 250), ["counter2_l", "counter2_m", "counter2_m2", "counter2_r", "counter2_corner", "counter2_glass"], "furniture")
    _pieces(rgba, (950, 160, 1040, 250), ["register"], "furniture")
    _pieces(rgba, (1120, 150, 1260, 260), ["scales"], "furniture")
    _pieces(rgba, (1320, 140, 1500, 290), ["seed_rack"], "furniture")
    _pieces(rgba, (35, 340, 800, 538), ["shelf_jars", "shelf_cans", "shelf_seeds", "shelf_dry", "shelf_house", "shelf_misc"], "furniture")
    _pieces(rgba, (835, 360, 1075, 455), ["crate_carrots", "crate_tomatoes"], "furniture")
    _pieces(rgba, (835, 465, 1075, 545), ["crate_cabbage", "crate_corn"], "furniture")
    _anim(rgba, (1110, 365, 1515, 455), 4, "furniture", "anvil2")
    _anim(rgba, (25, 635, 645, 825), 4, "furniture", "forge")
    _pieces(rgba, (650, 635, 890, 825), ["weapon_rack", "tool_rack"], "furniture")
    _pieces(rgba, (895, 680, 1100, 795), ["bellows", "quench_barrel"], "furniture")
    _pieces(rgba, (1120, 630, 1520, 825), ["potion_shelf_a", "potion_shelf_b", "potion_shelf_c", "potion_shelf_d"], "furniture")
    _anim(rgba, (30, 895, 450, 1000), 4, "furniture", "cauldron")
    _pieces(rgba, (495, 895, 880, 1000), ["herbs_a", "herbs_b", "herbs_c", "herbs_d"], "furniture")
    _pieces(rgba, (915, 905, 1040, 995), ["mortar"], "furniture")
    _anim(rgba, (1100, 895, 1515, 1000), 4, "furniture", "crystal_ball")


def w41():
    rgba = load("w41_home_interiors.png")
    _pieces(rgba, (15, 110, 280, 245), ["bed2_blue", "bed2_red", "bed2_green"], "furniture")
    _pieces(rgba, (295, 110, 540, 245), ["bed2_double_blue", "bed2_double_red"], "furniture")
    _pieces(rgba, (545, 110, 670, 245), ["bunk_bed"], "furniture")
    _pieces(rgba, (680, 110, 840, 245), ["nightstand_a", "nightstand_b"], "furniture")
    _pieces(rgba, (850, 110, 1045, 245), ["wardrobe2_a", "wardrobe2_b"], "furniture")
    _pieces(rgba, (1055, 110, 1255, 245), ["dresser2_a", "dresser2_b"], "furniture")
    _pieces(rgba, (1262, 110, 1528, 245), ["bookcase2_a", "bookcase2_b", "bookcase2_c"], "furniture")
    _anim(rgba, (25, 285, 445, 395), 4, "furniture", "fireplace2")
    _pieces(rgba, (455, 285, 625, 395), ["fireplace2_unlit"], "furniture")
    _pieces(rgba, (635, 285, 1005, 395), ["armchair2_red", "armchair2_blue", "armchair2_green", "armchair2_yellow"], "furniture")
    _pieces(rgba, (1030, 285, 1528, 395), ["sofa_red", "sofa_blue", "sofa_green"], "furniture")
    _pieces(rgba, (15, 455, 150, 555), ["table2_round"], "furniture")
    _pieces(rgba, (160, 455, 345, 555), ["table2_long8"], "furniture")
    _pieces(rgba, (350, 455, 510, 555), ["table2_long4"], "furniture")
    _pieces(rgba, (530, 470, 750, 555), ["chair2_a_down", "chair2_a_left", "chair2_a_right", "chair2_a_up"], "furniture")
    _pieces(rgba, (760, 470, 975, 555), ["chair2_b_down", "chair2_b_left", "chair2_b_right", "chair2_b_up"], "furniture")
    _pieces(rgba, (985, 455, 1528, 555), ["rug2_round_red", "rug2_round_blue", "rug2_red", "rug2_blue", "rug2_green", "rug2_runner"], "furniture")
    _pieces(rgba, (15, 628, 625, 705), ["kitchen_sink", "kitchen_stove", "kitchen_counter_a", "kitchen_counter_b", "kitchen_fridge", "kitchen_corner"], "furniture")
    _anim(rgba, (645, 600, 945, 705), 4, "furniture", "kettle")
    _pieces(rgba, (960, 625, 1195, 705), ["cat_bed", "dog_bed"], "furniture")
    _pieces(rgba, (1205, 610, 1335, 705), ["cradle"], "furniture")
    _pieces(rgba, (1355, 610, 1510, 705), ["toy_chest"], "furniture")
    _pieces(rgba, (15, 765, 175, 855), ["piano"], "furniture")
    _anim(rgba, (190, 765, 445, 855), 4, "furniture", "clock_grand2")
    _pieces(rgba, (460, 775, 550, 850), ["wall_clock"], "furniture")
    _pieces(rgba, (555, 775, 1010, 850), ["painting2_a", "painting2_b", "painting2_c", "painting2_d", "painting2_e", "painting2_f"], "furniture")
    _pieces(rgba, (1025, 765, 1115, 855), ["mirror2"], "furniture")
    _pieces(rgba, (1120, 765, 1528, 855), ["plant2_a", "plant2_b", "plant2_c", "plant2_d", "plant2_e", "plant2_f"], "furniture")
    _pieces(rgba, (15, 920, 665, 1012), ["curtain_red_closed", "curtain_red_open", "curtain_blue_closed", "curtain_blue_open", "curtain_green_closed", "curtain_green_open"], "furniture")
    _pieces(rgba, (675, 920, 835, 1012), ["window2_day_a", "window2_day_b"], "furniture")
    _pieces(rgba, (850, 920, 1015, 1012), ["window2_night_a", "window2_night_b"], "furniture")
    _pieces(rgba, (1030, 920, 1205, 1012), ["stairs3_up", "stairs3_down"], "furniture")
    _pieces(rgba, (1210, 920, 1528, 1012), ["door2_wood", "door2_wood_open", "door2_glass", "door2_metal"], "furniture")


def w42():
    rgba = load("w42_public_interiors.png")
    _pieces(rgba, (140, 65, 395, 185), ["bar_counter"], "furniture")
    _anim(rgba, (405, 85, 545, 185), 4, "furniture", "beer_taps")
    _pieces(rgba, (600, 100, 745, 185), ["stool_red", "stool_blue", "stool_green"], "furniture")
    _pieces(rgba, (760, 70, 930, 185), ["round_set_a"], "furniture")
    _pieces(rgba, (935, 70, 1085, 185), ["round_set_b"], "furniture")
    _pieces(rgba, (1095, 65, 1245, 185), ["keg_wall"], "furniture")
    _pieces(rgba, (1250, 100, 1390, 185), ["hanging_mugs"], "furniture")
    _pieces(rgba, (1395, 60, 1525, 185), ["hearth"], "furniture")
    _anim(rgba, (225, 240, 495, 345), 4, "furniture", "bakery_oven")
    _pieces(rgba, (510, 240, 850, 345), ["bread_rack_a", "bread_rack_b", "bread_rack_c"], "furniture")
    _pieces(rgba, (865, 240, 1055, 345), ["cake_case"], "furniture")
    _pieces(rgba, (1070, 240, 1250, 345), ["flour_sacks"], "furniture")
    _pieces(rgba, (1260, 240, 1520, 345), ["prep_table"], "furniture")
    _pieces(rgba, (170, 395, 385, 510), ["hospital_bed_a", "hospital_bed_b"], "furniture")
    _pieces(rgba, (425, 395, 660, 510), ["curtain_open", "curtain_closed"], "furniture")
    _pieces(rgba, (685, 395, 860, 510), ["medicine_cabinet"], "furniture")
    _pieces(rgba, (890, 395, 1100, 510), ["doctor_desk"], "furniture")
    _pieces(rgba, (1140, 395, 1240, 510), ["scale"], "furniture")
    _pieces(rgba, (1270, 395, 1375, 510), ["skeleton_poster"], "furniture")
    _pieces(rgba, (1410, 395, 1510, 510), ["eye_chart"], "furniture")
    _pieces(rgba, (155, 555, 760, 680), ["bookcase3_a", "bookcase3_b", "bookcase3_c", "bookcase3_d", "bookcase3_e", "bookcase3_f"], "furniture")
    _pieces(rgba, (765, 555, 965, 680), ["reading_table"], "furniture")
    _pieces(rgba, (975, 555, 1070, 680), ["globe"], "furniture")
    _pieces(rgba, (1075, 555, 1205, 680), ["card_catalogue"], "furniture")
    _pieces(rgba, (1210, 555, 1325, 680), ["library_ladder"], "furniture")
    _pieces(rgba, (1340, 555, 1520, 680), ["armchair_window"], "furniture")
    _pieces(rgba, (155, 725, 505, 835), ["council_table"], "furniture")
    _pieces(rgba, (520, 725, 725, 835), ["mayor_desk"], "furniture")
    _pieces(rgba, (740, 725, 865, 835), ["flag_a", "flag_b"], "furniture")
    _pieces(rgba, (895, 725, 1060, 835), ["notice_board2"], "furniture")
    _pieces(rgba, (1085, 725, 1185, 835), ["podium"], "furniture")
    _pieces(rgba, (1200, 725, 1520, 835), ["pew_a", "pew_b"], "furniture")
    _pieces(rgba, (150, 865, 365, 990), ["altar"], "furniture")
    _anim(rgba, (380, 880, 585, 990), 4, "furniture", "candle_stand")
    _pieces(rgba, (605, 865, 1115, 990), ["stained_a_day", "stained_a_night", "stained_b_day", "stained_b_night", "stained_c_day", "stained_c_night"], "furniture")
    _pieces(rgba, (1140, 880, 1350, 990), ["pew_c", "pew_d"], "furniture")
    _pieces(rgba, (1355, 865, 1490, 990), ["organ"], "furniture")




# ---------------------------------------------------------------- batch W44-W47 (UI, weather)

def _icon(rgba, box, group, name, size=48):
    save(_cut(rgba, box, size, size), group, name)


def w45():
    rgba = load("w45_ui_touch.png")
    _pieces(rgba, (20, 100, 300, 235), ["joy_base_a", "joy_base_b"], "ui", 0.5)
    _pieces(rgba, (335, 130, 505, 215), ["joy_knob_light", "joy_knob_dark"], "ui", 0.5)
    _pieces(rgba, (540, 95, 1520, 235), ["btn_blue", "btn_blue_down", "btn_green", "btn_green_down", "btn_red", "btn_red_down", "btn_gold", "btn_gold_down"], "ui", 0.5)
    _pieces(rgba, (15, 315, 625, 395), ["sbtn_blue", "sbtn_blue_down", "sbtn_green", "sbtn_green_down", "sbtn_red", "sbtn_red_down", "sbtn_gold", "sbtn_gold_down"], "ui", 0.5)
    _pieces(rgba, (645, 315, 1045, 395), ["ic_run", "ic_menu", "ic_map", "ic_journal", "ic_inventory"], "ui", 0.5)
    _pieces(rgba, (1070, 310, 1520, 420), ["slot_attack", "slot_tool", "slot_interact", "slot_custom"], "ui", 0.5)
    tools = ["hoe", "can", "axe", "pickaxe", "scythe", "rod", "sword", "iron_sword", "hammer", "hand", "check"]
    for b, nm in zip(row_sprites(rgba, (15, 495, 815, 565), 11), tools):
        save(_cut(rgba, b, 48, 48), "items", nm)
    cats = ["cat_crops", "cat_seeds", "cat_fish", "cat_forage", "cat_ore", "cat_bars", "cat_gems", "cat_potions", "cat_gifts"]
    for b, nm in zip(row_sprites(rgba, (825, 495, 1525, 565), 9), cats):
        save(_cut(rgba, b, 48, 48), "ui", nm)
    rows = [
        ((120, 645, 850, 705), ["potato", "turnip", "carrot", "corn", "tomato", "strawberry", "pumpkin", "melon"]),
        ((120, 720, 600, 780), ["potato_seed", "turnip_seed", "carrot_seed", "corn_seed", "tomato_seed"]),
        ((120, 795, 600, 855), ["trout", "bass", "salmon", "tuna", "catfish"]),
        ((120, 865, 600, 925), ["berry", "mushroom", "wild_herb", "flower", "honey"]),
        ((120, 945, 505, 1000), ["copper", "iron", "silver", "gold"]),
        ((980, 645, 1315, 705), ["copper_bar", "iron_bar", "silver_bar", "gold_bar"]),
        ((980, 725, 1315, 785), ["ruby", "sapphire", "emerald", "amethyst"]),
        ((980, 810, 1360, 870), ["potion", "energy_tea", "luck_potion", "harvest_potion"]),
        ((980, 905, 1430, 970), ["gift_red", "gift_blue", "gift_green", "gift_gold", "gift_purple"]),
    ]
    for reg, names in rows:
        for b, nm in zip(row_sprites(rgba, reg, len(names)), names):
            save(_cut(rgba, b, 48, 48), "items", nm)


def w44():
    rgba = load("w44_ui_frames.png")
    _pieces(rgba, (15, 110, 800, 245), ["panel_wood2", "panel_parchment2", "panel_slate", "panel_crystal", "panel_neon"], "ui", 0.5)
    _pieces(rgba, (815, 145, 1095, 205), ["tab_idle", "tab_active"], "ui", 0.5)
    _pieces(rgba, (1115, 145, 1400, 205), ["tab2_idle", "tab2_active"], "ui", 0.5)
    _pieces(rgba, (1430, 130, 1515, 215), ["close_x"], "ui", 0.5)
    _pieces(rgba, (40, 355, 275, 435), ["scroll_track", "scroll_thumb", "scroll_up", "scroll_down"], "ui", 0.5)
    _pieces(rgba, (320, 350, 650, 440), ["slot2", "slot2_selected", "slot2_locked"], "ui", 0.5)
    _pieces(rgba, (670, 360, 925, 430), ["heart2_full", "heart2_half", "heart2_empty"], "ui", 0.5)
    _pieces(rgba, (965, 370, 1150, 420), ["sheart_full", "sheart_half", "sheart_empty"], "ui", 0.5)
    _pieces(rgba, (1190, 355, 1520, 430), ["energy_bar"], "ui", 0.5)
    _pieces(rgba, (30, 535, 330, 625), ["crystal_l", "crystal_m", "crystal_s"], "ui", 0.5)
    _pieces(rgba, (360, 530, 820, 635), ["clock_spring", "clock_summer", "clock_fall", "clock_winter"], "ui", 0.5)
    _pieces(rgba, (875, 540, 1515, 615), ["wx_sunny", "wx_partly", "wx_cloudy", "wx_rain", "wx_storm", "wx_snow", "wx_windy", "wx_fog"], "ui", 0.5)
    _pieces(rgba, (55, 725, 195, 840), ["daynight_dial"], "ui", 0.5)
    _pieces(rgba, (285, 725, 385, 825), ["quest_marker"], "ui", 0.5)
    _pieces(rgba, (420, 730, 860, 815), ["pin2_town", "pin2_forest", "pin2_farm", "pin2_docks", "pin2_mountain", "pin2_crystal"], "ui", 0.5)
    _pieces(rgba, (885, 695, 1520, 850), ["speech_box"], "ui", 0.5)
    _pieces(rgba, (95, 925, 465, 975), ["choice_idle"], "ui", 0.5)
    _pieces(rgba, (95, 975, 465, 1020), ["choice_pressed"], "ui", 0.5)
    _pieces(rgba, (620, 925, 1320, 995), ["toast_banner"], "ui", 0.5)


def w46():
    rgba = load("w46_skills_social.png")
    skills = ["farming", "mining", "foraging", "fishing", "combat", "bartering", "building"]
    ys = [(140, 225), (228, 312), (315, 400), (402, 488), (490, 575), (577, 662), (665, 750)]
    for (y0, y1), nm in zip(ys, skills):
        save(_cut(rgba, (20, y0, 115, y1), 48, 48), "ui", "skill2_" + nm)
        for b, lv in zip(row_sprites(rgba, (235, y0, 600, y1), 5), range(1, 6)):
            save(_cut(rgba, b, 32, 32), "ui", "badge_%s_%d" % (nm, lv))
    _anim(rgba, (630, 140, 1080, 215), 6, "fx", "skill_up", 0.5)
    _pieces(rgba, (1095, 140, 1520, 250), ["gift_love", "gift_like", "gift_neutral", "gift_hate"], "ui", 0.5)
    _pieces(rgba, (1160, 370, 1480, 425), ["ribbon_friend"], "ui", 0.5)
    _pieces(rgba, (1160, 430, 1480, 485), ["ribbon_close"], "ui", 0.5)
    _pieces(rgba, (1160, 490, 1480, 548), ["ribbon_best"], "ui", 0.5)
    _pieces(rgba, (1160, 625, 1520, 715), ["medal_explorer", "medal_collector", "medal_master"], "ui", 0.5)
    _pieces(rgba, (1160, 765, 1520, 855), ["medal_green_thumb", "medal_champion", "medal_craftsman"], "ui", 0.5)
    _pieces(rgba, (20, 815, 300, 890), ["banner_spring"], "ui", 0.5)
    _pieces(rgba, (315, 815, 595, 890), ["banner_summer"], "ui", 0.5)
    _pieces(rgba, (20, 900, 300, 975), ["banner_fall"], "ui", 0.5)
    _pieces(rgba, (315, 900, 595, 975), ["banner_winter"], "ui", 0.5)
    _pieces(rgba, (1030, 665, 1135, 800), ["marker_birthday"], "ui", 0.5)
    _pieces(rgba, (1030, 805, 1135, 940), ["marker_festival"], "ui", 0.5)
    _pieces(rgba, (600, 655, 1020, 975), ["calendar"], "ui", 0.5)
    # hearts rows: one heart of each colour from the rows (empty, full, gold)
    save(_cut(rgba, (722, 345, 760, 385), 24, 24), "ui", "fheart_empty")
    save(_cut(rgba, (722, 468, 760, 508), 24, 24), "ui", "fheart_full")
    save(_cut(rgba, (722, 530, 760, 570), 24, 24), "ui", "fheart_gold")


def w47():
    rgba_raw = np.array(Image.open(os.path.join(S.INC, "w47_weather_extra.png")).convert("RGBA")).astype(np.int32)
    # Soft key (same as W25): translucent overlays on a magenta backdrop.
    bgc = np.array([255, 0, 255], dtype=np.float64)
    f = rgba_raw[..., :3].astype(np.float64)
    dist = np.sqrt(((f - bgc) ** 2).sum(-1))
    a = np.clip((dist - 20.0) / 170.0, 0.0, 1.0)
    fg = np.where(a[..., None] > 0.02, (f - (1.0 - a[..., None]) * bgc) / np.maximum(a[..., None], 0.02), f)
    rgba = np.zeros(rgba_raw.shape, dtype=np.uint8)
    rgba[..., :3] = np.clip(fg, 0, 255).astype(np.uint8)
    rgba[..., 3] = (a * 255).astype(np.uint8)
    # Each panel holds 4 frames side by side inside a frame border; cut the interior.
    def panel(x0, y0, x1, y1, name, fw=4, size=(128, 96)):
        W = (x1 - x0) / fw
        frames = [scale_to(crop(rgba, (int(x0 + i * W) + 3, y0 + 3, int(x0 + (i + 1) * W) - 3, y1 - 3)), width=size[0], height=size[1], cover=True) for i in range(fw)]
        strip(frames, "fx", name)
    row1 = [(40, "ov2_rain"), (295, "ov2_storm"), (545, "ov2_drizzle"), (785, "ov2_snow"), (1020, "ov2_blizzard"), (1265, "ov2_hail")]
    for x0, nm in row1:
        panel(x0, 125, x0 + 245, 230, nm)
    row2 = [(40, "ov2_sandstorm"), (310, "ov2_ash"), (550, "ov2_petals"), (795, "ov2_leaves"), (1040, "ov2_fireflies"), (1265, "ov2_fog")]
    for x0, nm in row2:
        panel(x0, 295, x0 + 245, 400, nm)
    panel(40, 465, 305, 575, "ov2_godrays")
    panel(320, 465, 560, 575, "ov2_lightning")
    panel(570, 465, 825, 575, "ov2_sunglare")
    panel(835, 465, 1090, 575, "ov2_moonglow")
    panel(1105, 465, 1495, 575, "shooting_star", 3, (96, 72))
    save(scale_to(crop(rgba, (30, 655, 620, 775)), width=512, height=110), "fx", "rainbow")
    panel(640, 650, 1515, 780, "aurora2", 4, (512, 128))
    panel(350, 840, 1185, 1000, "cloud_shadow", 4, (256, 160))




# ---------------------------------------------------------------- batch W48-W51 (trees, landmarks, farm buildings, animals)

def _cells(rgba, reg, n, group, names_or_name, h, as_strip=False):
    """Equal cells across reg (trees that touch each other), trimmed per cell."""
    x0, y0, x1, y1 = reg
    cw = (x1 - x0) / n
    out = []
    for i in range(n):
        box = (int(x0 + i * cw) + 2, y0, int(x0 + (i + 1) * cw) - 2, y1)
        bb = region_bbox(rgba, box)
        im = crop(rgba, bb) if bb else Image.new("RGBA", (8, 8))
        out.append(scale_to(im, height=h))
    if as_strip:
        strip(out, group, names_or_name)
    else:
        for im, nm in zip(out, names_or_name):
            save(im, group, nm)


def w48():
    rgba = load("w48_big_trees.png")
    y0, y1 = 178, 348
    _cells(rgba, (12, y0, 292, y1), 3, "nature", ["big_oak_a", "big_oak_b", "big_oak_c"], 128)
    _cells(rgba, (292, y0, 532, y1), 3, "nature", ["big_pine_a", "big_pine_b", "big_pine_c"], 128)
    _cells(rgba, (532, y0, 692, y1), 3, "nature", ["big_birch_a", "big_birch_b", "big_birch_c"], 128)
    _cells(rgba, (695, y0, 822, y1), 1, "nature", ["big_willow"], 128)
    _cells(rgba, (826, y0, 1012, y1), 2, "nature", ["big_cherry_a", "big_cherry_b"], 128)
    _cells(rgba, (1016, y0, 1202, y1), 2, "nature", ["big_maple_a", "big_maple_b"], 128)
    _cells(rgba, (1206, y0, 1362, y1), 2, "nature", ["big_dead_a", "big_dead_b"], 128)
    _cells(rgba, (1366, y0, 1532, y1), 2, "nature", ["big_snowpine_a", "big_snowpine_b"], 128)
    mid = ["mid_oak", "mid_pine", "mid_birch", "mid_willow", "mid_cherry", "mid_maple", "mid_dead", "mid_snowpine", "mid_oak_b", "mid_pine_b", "mid_birch_b", "mid_willow_b", "mid_cherry_b", "mid_maple_b", "mid_dead_b", "mid_snowpine_b"]
    for b, nm in zip(row_sprites(rgba, (10, 462, 1535, 582), 16), mid):
        save(_cut(rgba, b, h=96), "nature", nm)
    _cells(rgba, (130, 648, 430, 822), 2, "nature", "oak_sway", 112, True)
    _cells(rgba, (445, 648, 690, 822), 2, "nature", "pine_sway", 112, True)
    save(_cut(rgba, (700, 640, 1530, 825), h=96), "nature", "treeline")
    for b, nm in zip(row_sprites(rgba, (110, 915, 870, 1005), 6), ["bush2_green", "bush2_flower", "bush2_berry", "bush2_yellow", "bush2_red", "bush2_blue"]):
        save(_cut(rgba, b, h=32), "nature", nm)


def w49():
    rgba = load("w49_landmarks.png")
    _anim(rgba, (15, 140, 605, 362), 4, "props", "windmill3", 0.5)
    save(_cut(rgba, (625, 140, 835, 362), h=128), "props", "watchtower")
    save(_cut(rgba, (875, 155, 1215, 352), h=96), "props", "stone_circle")
    save(_cut(rgba, (1235, 175, 1530, 335), h=48), "props", "hollow_log")
    frames = [_cut(rgba, (x0, y0, x0 + 210, y0 + 120), 128, 96, cover=False) for (x0, y0) in [(20, 455), (230, 455), (20, 575), (230, 575)]]
    strip(frames, "props", "waterfall_pool")
    save(_cut(rgba, (455, 480, 605, 672), h=48), "props", "old_well")
    save(_cut(rgba, (625, 500, 835, 672), h=48), "props", "abandoned_cart")
    save(_cut(rgba, (855, 480, 975, 672), h=64), "props", "scarecrow_field")
    save(_cut(rgba, (1015, 460, 1205, 682), h=96), "props", "lookout_platform")
    save(_cut(rgba, (1225, 465, 1530, 692), h=80), "props", "hermit_hut")
    frames = [_cut(rgba, (x0, y0, x0 + 195, y0 + 115), 96, 64, cover=False) for (x0, y0) in [(15, 780), (215, 780), (15, 895), (215, 895)]]
    strip(frames, "props", "campsite")
    save(_cut(rgba, (435, 780, 625, 1012), h=96), "props", "cat_statue")
    save(_cut(rgba, (675, 785, 835, 985), h=64), "props", "signpost_cluster")
    save(_cut(rgba, (865, 785, 1185, 995), h=64), "props", "bus_shelter")
    save(_cut(rgba, (1205, 785, 1530, 1005), h=64), "props", "toll_house")


def w50():
    rgba = load("w50_farm_buildings.png")
    _cells(rgba, (25, 100, 335, 262), 2, "props", ["coop_small", "coop_small_open"], 80)
    _cells(rgba, (340, 100, 700, 262), 2, "props", ["coop_big", "coop_big_open"], 96)
    _cells(rgba, (705, 100, 1060, 262), 2, "props", ["barn_small", "barn_small_open"], 96)
    _cells(rgba, (1070, 100, 1525, 262), 2, "props", ["barn_big", "barn_big_open"], 112)
    save(_cut(rgba, (25, 340, 145, 520), h=112), "props", "silo2")
    _anim(rgba, (155, 340, 725, 520), 4, "props", "greenhouse2", 0.5)
    save(_cut(rgba, (735, 345, 845, 520), h=64), "props", "well_roofed")
    save(_cut(rgba, (865, 345, 1045, 520), h=72), "props", "shed")
    save(_cut(rgba, (1055, 345, 1325, 520), h=96), "props", "stable2")
    save(_cut(rgba, (1335, 345, 1525, 520), h=128), "props", "mill")
    _anim(rgba, (10, 590, 565, 700), 4, "props", "fish_pond", 0.5)
    for b, nm in zip(row_sprites(rgba, (565, 590, 1525, 700), 8), ["beehive3_a", "beehive3_b", "keg2", "preserves_jar", "furnace2_off", "furnace2_on", "workbench3", "anvil_stand"]):
        save(_cut(rgba, b, h=40 if nm not in ("workbench3",) else 44), "props", nm)
    _anim(rgba, (10, 760, 325, 840), 4, "props", "sprinkler_basic", 0.5)
    _anim(rgba, (365, 760, 685, 840), 4, "props", "sprinkler_quality", 0.5)
    _anim(rgba, (695, 760, 1015, 840), 4, "props", "sprinkler_iridium", 0.5)
    for b, nm in zip(row_sprites(rgba, (1035, 755, 1525, 845), 3), ["scarecrow_classic", "scarecrow_knight", "scarecrow_pumpkin"]):
        save(_cut(rgba, b, h=48), "props", nm)
    for x0, x1, pre in [(10, 495, "fence2_wood"), (515, 1005, "fence2_stone"), (1015, 1525, "fence2_iron")]:
        for b, part in zip(row_sprites(rgba, (x0, 912, x1, 992), 5), ["_h", "_corner", "_end", "_gate", "_gate_open"]):
            save(_cut(rgba, b, h=32), "props", pre + part)


def _box_anim(rgba, box, n, group, name, h):
    x0, y0, x1, y1 = box
    _row_strip(rgba, (x0 + 14, y0 + 13, x1 - 14, y1 - 12), n, group, name, h, None, 2)


def w51():
    rgba = load("w51_farm_animals_more.png")
    # The animation boxes are opaque beige panels: key the panel colour too, then
    # drop the thin box borders.
    rgb = rgba[..., :3].astype(np.int32)
    beige = np.abs(rgb - np.array([244, 213, 160])).sum(-1) < 60
    rgba = rgba.copy()
    rgba[..., 3] = np.where(beige, 0, rgba[..., 3])
    rgba = S.remove_thin_lines(rgba, 2)
    hx = [(178, 445, "idle", 4), (458, 855, "walk", 6), (870, 1290, "gallop", 6), (1305, 1495, "eat", 2)]
    for (x0, x1, a, n) in hx:
        _box_anim(rgba, (x0, 66, x1, 134), n, "animals/horse3", a, 48)
        _box_anim(rgba, (x0, 150, x1, 220), n, "animals/horse3_saddle", a, 48)
    for (x0, x1, a, n) in [(145, 340, "idle", 4), (355, 655, "walk", 6)]:
        _box_anim(rgba, (x0, 240, x1, 318), n, "animals/donkey", a, 40)
    for (x0, x1, a, n) in [(795, 980, "idle", 4), (995, 1290, "walk", 6), (1305, 1530, "spit", 4)]:
        _box_anim(rgba, (x0, 240, x1, 318), n, "animals/llama", a, 44)
    for (x0, x1, a, n) in [(130, 258, "idle", 4), (270, 420, "walk", 4)]:
        _box_anim(rgba, (x0, 340, x1, 408), n, "animals/rabbit_brown", a, 24)
    for (x0, x1, a, n) in [(555, 685, "idle", 4), (695, 830, "walk", 4)]:
        _box_anim(rgba, (x0, 340, x1, 408), n, "animals/rabbit_white", a, 24)
    for (x0, x1, a, n) in [(955, 1100, "idle", 4), (1115, 1340, "walk", 6)]:
        _box_anim(rgba, (x0, 340, x1, 408), n, "animals/duck_water", a, 28)
    _box_anim(rgba, (1400, 340, 1530, 408), 4, "animals/bee_swarm", "idle", 20)
    for y0, nm in [(428, "cat2_orange"), (495, "cat2_black"), (562, "cat2_calico")]:
        for (x0, x1, a, n) in [(210, 430, "idle", 4), (445, 800, "walk", 6), (815, 985, "sleep", 2), (1000, 1170, "sit", 2)]:
            _box_anim(rgba, (x0, y0, x1, y0 + 56), n, "animals/" + nm, a, 28)
    for y0, nm in [(638, "dog_golden"), (712, "dog_collie"), (787, "dog_husky")]:
        for (x0, x1, a, n) in [(190, 340, "idle", 4), (355, 590, "walk", 6), (605, 840, "run", 6), (860, 955, "sit", 2), (970, 1080, "sleep", 2), (1090, 1330, "dig", 6), (1345, 1530, "bark", 4)]:
            _box_anim(rgba, (x0, y0, x1, y0 + 60), n, "animals/" + nm, a, 32)
    babies = [("chick", 10, 130, 140, 255), ("calf", 265, 385, 395, 510), ("lamb", 520, 640, 650, 765), ("piglet", 775, 895, 905, 1020), ("kid_goat", 1030, 1150, 1160, 1275), ("foal", 1285, 1405, 1415, 1530)]
    for nm, i0, i1, w0, w1 in babies:
        _box_anim(rgba, (i0, 905, i1, 978), 4, "animals/" + nm, "idle", 22)
        _box_anim(rgba, (w0, 905, w1, 978), 4, "animals/" + nm, "walk", 22)





if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    if os.path.exists(mpath):
        S.manifest.update(json.load(open(mpath)))
    steps = [("w1", w1), ("w2", w2), ("w3", w3), ("w4", w4), ("w5", w5), ("w6", w6), ("w7", w7), ("w8", w8), ("w22", w22), ("w23", w23), ("w9", w9), ("w10", w10), ("w11", w11), ("w16", w16), ("w17", w17), ("w18", w18), ("w19", w19), ("w12", w12), ("w13", w13), ("w14", w14), ("w15", w15), ("w20", w20), ("w21", w21), ("w24", w24), ("w25", w25), ("w26", w26), ("w27", w27), ("w28", w28), ("w29", w29), ("w30", w30), ("w31", w31), ("w32", w32), ("w33", w33), ("w34", w34), ("w35", w35), ("w36", w36), ("w39", w39), ("w43", w43), ("w40", w40), ("w41", w41), ("w42", w42), ("w44", w44), ("w45", w45), ("w46", w46), ("w47", w47), ("w48", w48), ("w49", w49), ("w50", w50), ("w51", w51)]
    only = sys.argv[1:]
    for name, fn in steps:
        if only and name not in only:
            continue
        try:
            fn(); print("ok", name)
        except Exception as e:
            import traceback; traceback.print_exc(); print("FAIL", name, repr(e))
    with open(mpath, "w") as f:
        json.dump(S.manifest, f, indent=1, sort_keys=True)






