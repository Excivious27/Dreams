#!/usr/bin/env python3
"""Batch-2 sheets (tool animations, portraits, villagers, Grumps army, gangsters,
crystals, the President, interiors, crafting, mine, fishing, seasons, weather,
effects, UI, hideout and moon tiles). Uses the helpers from slice_art.py.

Run: python3 tools/slice_art2.py   (after slice_art.py; both write art/gen/manifest.json)
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_art import load, crop, scale_to, save, strip, bbox, fg_mask, cells_by_grid, cells_by_projection, component_at, TILE2
from PIL import Image
import numpy as np

CHAR_H = {"man": 74, "woman": 78, "son": 64, "girl": 59, "dog": 40}


def region_bbox(rgba, reg):
    b = bbox(fg_mask(rgba[reg[1]:reg[3], reg[0]:reg[2]]))
    if b is None:
        return None
    return (reg[0] + b[0], reg[1] + b[1], reg[0] + b[2], reg[1] + b[3])


def comps(rgba, reg, gap=6, min_size=12):
    rows = cells_by_projection(rgba, region=reg, row_gap=200, col_gap=gap, min_size=min_size)
    out = [b for r in rows for b in r]
    out.sort(key=lambda b: b[0])
    return out


def scaled_strip(rgba, boxes, group, name, factor):
    frames = []
    for b in boxes:
        im = crop(rgba, b)
        w, h = im.size
        frames.append(scale_to(im, width=max(1, round(w * factor)), height=max(1, round(h * factor))))
    strip(frames, group, name)


# ---------------------------------------------------------------- characters

def tools(file, char_id):
    rgba = S.remove_thin_lines(load(file), 4)
    grid = cells_by_grid(rgba, 12, 8, region=(150, 52, 1536, 998), inset=6)
    rows = ["hoe", "water", "axe", "pickaxe", "cast", "reel", "hold", "eat"]
    dirs = ["down", "right", "up"]
    first = grid[0][0]
    factor = CHAR_H[char_id] / (first[3] - first[1])
    for r, action in enumerate(rows):
        for d, dname in enumerate(dirs):
            boxes = [b for b in grid[r][d * 4:(d + 1) * 4] if b]
            scaled_strip(rgba, boxes, "characters/" + char_id, f"{action}_{dname}", factor)


def portraits(file, pid):
    rgba = load(file)
    grid = cells_by_grid(rgba, 3, 2, inset=8)
    names = ["neutral", "happy", "sad", "angry", "surprised", "embarrassed"]
    i = 0
    for row in grid:
        for b in row:
            if b:
                save(scale_to(crop(rgba, b), width=96, height=96), "portraits/" + pid, names[i])
            i += 1


def villagers():
    rgba = load("villagers.png")
    ids = ["barnaby", "greta", "wren", "alder", "finn", "lumi", "theo", "hazel"]
    cells = cells_by_grid(rgba, 4, 2, trim=False)
    i = 0
    for row in cells:
        for (x0, y0, x1, y1) in row:
            vid = ids[i]; i += 1
            rows = cells_by_projection(rgba, region=(x0 + 4, y0 + 4, x1 - 4, y1 - 4), row_gap=8, col_gap=10, min_size=30)
            rows = [r for r in rows if r]
            stand = max(rows[0], key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))
            H = 72
            save(scale_to(crop(rgba, stand), height=H), "characters/" + vid, "view_front")
            walk = sorted(rows[-1], key=lambda b: b[0])[:4]
            frames = [scale_to(crop(rgba, b), height=H - 6) for b in walk]
            strip(frames, "characters/" + vid, "walk_down")


def crew():
    rgba = S.remove_thin_lines(load("crew.png"), 3)
    ids = ["riley", "manny", "eli", "jax", "vex", "nico"]
    rh = 1024 / 6
    for i, cid in enumerate(ids):
        y0, y1 = int(i * rh) + 6, int((i + 1) * rh) - 6
        ports = cells_by_grid(rgba, 2, 1, region=(5, y0, 445, y1), inset=6)[0]
        for b, nm in zip(ports, ["neutral", "happy"]):
            if b:
                save(scale_to(crop(rgba, b), width=96, height=96), "portraits/" + cid, nm)
        stand = region_bbox(rgba, (452, y0, 628, y1))
        H = 72
        save(scale_to(crop(rgba, stand), height=H), "characters/" + cid, "view_front")
        walk = [b for b in cells_by_grid(rgba, 4, 1, region=(632, y0, 1168, y1), inset=4)[0] if b]
        strip([scale_to(crop(rgba, b), height=H) for b in walk], "characters/" + cid, "walk_down")


def rivals():
    rgba = S.remove_thin_lines(load("rivals.png"), 2)
    ids = ["cyber", "brute", "flame", "speedster", "gambler", "enforcer"]
    rh = 1024 / 6
    for i, rid in enumerate(ids):
        y0, y1 = int(i * rh) + 40, int((i + 1) * rh) - 22
        ports = cells_by_grid(rgba, 2, 1, region=(5, int(i * rh) + 6, 262, y1), inset=4)[0]
        for b, nm in zip(ports, ["neutral", "angry"]):
            if b:
                save(scale_to(crop(rgba, b), width=96, height=96), "portraits/" + rid, nm)
        poses = [b for b in cells_by_grid(rgba, 4, 1, region=(268, int(i * rh) + 6, 578, y1), inset=4)[0] if b]
        H = 76
        factor = H / (poses[0][3] - poses[0][1])
        for b, nm in zip(poses, ["view_front", "view_right", "view_back", "view_left"]):
            im = crop(rgba, b); w, h = im.size
            save(scale_to(im, width=round(w * factor), height=round(h * factor)), "characters/" + rid, nm)
        g = "characters/" + rid
        scaled_strip(rgba, [b for b in cells_by_grid(rgba, 4, 1, region=(582, y0, 888, y1), inset=4)[0] if b], g, "idle", factor)
        scaled_strip(rgba, [b for b in cells_by_grid(rgba, 4, 1, region=(892, y0, 1332, y1), inset=4)[0] if b], g, "attack", factor)
        scaled_strip(rgba, [b for b in cells_by_grid(rgba, 2, 1, region=(1338, y0, 1536, y1), inset=4)[0] if b], g, "hurt", factor)


def gang_heroes():
    rgba = S.remove_thin_lines(load("gang_heroes.png"), 2)
    for i, cid in enumerate(["man_gang", "son_gang"]):
        oy = i * 443
        H = CHAR_H["man" if i == 0 else "son"]
        poses = [b for b in cells_by_grid(rgba, 4, 1, region=(5, oy + 8, 483, oy + 216), inset=4)[0] if b]
        factor = H / (poses[0][3] - poses[0][1])
        g = "characters/" + cid
        for b, nm in zip(poses, ["view_front", "view_right", "view_back", "view_left"]):
            im = crop(rgba, b); w, h = im.size
            save(scale_to(im, width=round(w * factor), height=round(h * factor)), g, nm)
        scaled_strip(rgba, [b for b in cells_by_grid(rgba, 4, 1, region=(487, oy + 50, 908, oy + 216), inset=4)[0] if b], g, "walk_down", factor)
        scaled_strip(rgba, [b for b in cells_by_grid(rgba, 4, 1, region=(912, oy + 50, 1358, oy + 216), inset=4)[0] if b], g, "walk", factor)
        punch = comps(rgba, (10, oy + 278, 788, oy + 440), gap=14, min_size=40)[:4]
        scaled_strip(rgba, punch, g, "attack", factor)
        hurt = comps(rgba, (792, oy + 278, 1358, oy + 440), gap=14, min_size=40)[:2]
        scaled_strip(rgba, hurt, g, "hurt", factor)
        ports = cells_by_grid(rgba, 2, 2, region=(1365, oy + 6, 1774, oy + 440), inset=6)
        names = ["neutral", "angry", "determined", "sad"]
        k = 0
        for row in ports:
            for b in row:
                if b:
                    save(scale_to(crop(rgba, b), width=96, height=96), "portraits/" + cid, names[k])
                k += 1


def president():
    rgba = S.remove_thin_lines(load("president.png"), 2)
    g = "characters/president"
    ports = cells_by_grid(rgba, 1, 3, region=(4, 4, 284, 884), inset=6)
    for row, nm in zip(ports, ["neutral", "smug", "angry"]):
        if row[0]:
            save(scale_to(crop(rgba, row[0]), width=96, height=96), "portraits/president", nm)
    poses = [b for b in cells_by_grid(rgba, 4, 1, region=(292, 8, 1108, 318), inset=6)[0] if b]
    H = 96
    factor = H / (poses[0][3] - poses[0][1])
    for b, nm in zip(poses, ["view_front", "view_right", "view_back", "view_left"]):
        im = crop(rgba, b); w, h = im.size
        save(scale_to(im, width=round(w * factor), height=round(h * factor)), g, nm)
    scaled_strip(rgba, [b for b in cells_by_grid(rgba, 4, 1, region=(1122, 50, 1774, 318), inset=6)[0] if b], g, "idle", factor)
    scaled_strip(rgba, comps(rgba, (292, 365, 1282, 585), gap=16, min_size=60)[:4], g, "attack", factor)
    scaled_strip(rgba, comps(rgba, (292, 625, 1282, 870), gap=16, min_size=60)[:4], g, "charge", factor)
    scaled_strip(rgba, comps(rgba, (1300, 430, 1774, 740), gap=16, min_size=60)[:2], g, "hurt", factor)


# ---------------------------------------------------------------- enemies

def grump_army():
    rgba = S.remove_thin_lines(load("grump_army.png"), 2)
    bands = {"soldier": (140, 242), "archer": (290, 388), "knight": (430, 552), "wisp": (600, 692), "commander": (740, 1010)}
    heights = {"soldier": 44, "archer": 44, "knight": 64, "wisp": 36, "commander": 110}
    cols = {"idle": (238, 572, 4), "walk": (578, 912, 4), "attack": (918, 1336, 4), "hurt": (1342, 1536, 2)}
    for kind, (y0, y1) in bands.items():
        g = "enemies/" + kind
        idle = [b for b in cells_by_grid(rgba, 4, 1, region=(238, y0, 572, y1), inset=3)[0] if b]
        factor = heights[kind] / (idle[0][3] - idle[0][1])
        for anim, (x0, x1, n) in cols.items():
            boxes = [b for b in cells_by_grid(rgba, n, 1, region=(x0, y0, x1, y1), inset=3)[0] if b]
            scaled_strip(rgba, boxes, g, anim, factor)


def crystals():
    rgba = S.remove_thin_lines(load("crystals.png"), 2)
    g = "characters/light_crystal"
    H = 64
    idle = [b for b in cells_by_grid(rgba, 4, 1, region=(180, 110, 705, 235), inset=3)[0] if b]
    factor = H / (idle[0][3] - idle[0][1])
    scaled_strip(rgba, idle, g, "idle", factor)
    scaled_strip(rgba, [b for b in cells_by_grid(rgba, 4, 1, region=(180, 255, 705, 390), inset=3)[0] if b], g, "speak", factor)
    for b, nm in zip(cells_by_grid(rgba, 3, 1, region=(760, 115, 1515, 355), inset=6)[0], ["neutral", "happy", "worried"]):
        if b:
            save(scale_to(crop(rgba, b), width=96, height=96), "portraits/light_crystal", nm)
    g = "enemies/dark_crystal"
    H = 120
    idle = [b for b in cells_by_grid(rgba, 4, 1, region=(180, 505, 810, 648), inset=3)[0] if b]
    factor = H / (idle[0][3] - idle[0][1])
    scaled_strip(rgba, idle, g, "idle", factor)
    scaled_strip(rgba, [b for b in cells_by_grid(rgba, 4, 1, region=(180, 655, 810, 815), inset=3)[0] if b], g, "attack", factor)
    scaled_strip(rgba, [b for b in cells_by_grid(rgba, 2, 1, region=(180, 825, 505, 965), inset=3)[0] if b], g, "hurt", factor)
    for b, nm in zip(cells_by_grid(rgba, 2, 1, region=(875, 560, 1505, 860), inset=6)[0], ["neutral", "angry"]):
        if b:
            save(scale_to(crop(rgba, b), width=96, height=96), "portraits/dark_crystal", nm)


# ---------------------------------------------------------------- tiles & props

def tileset3x3(rgba, reg, name, inset=4, center_inset=None):
    """center_inset: crop the middle tile further (sheets whose every cell has a fringe)."""
    grid = cells_by_projection(rgba, region=reg, row_gap=3, col_gap=3, min_size=50)
    tiles = []
    for ri, row in enumerate(grid[:3]):
        for ci, b in enumerate(row[:3]):
            ins = inset
            if center_inset is not None and ri == 1 and ci == 1:
                ins = center_inset
            tiles.append(scale_to(crop(rgba, (b[0] + ins, b[1] + ins, b[2] - ins, b[3] - ins)), width=TILE2, height=TILE2, cover=True))
    if len(tiles) < 9:
        print("  (tileset", name, "found", len(tiles), ")")
        return
    sheet = Image.new("RGBA", (TILE2 * 3, TILE2 * 3))
    for i, t in enumerate(tiles):
        sheet.alpha_composite(t, ((i % 3) * TILE2, (i // 3) * TILE2))
    save(sheet, "tiles", name)


def props_from(rgba, group, spec):
    """spec: name -> (region, (w, h))  bbox inside region, scaled to fit w x h."""
    for nm, (reg, (w, h)) in spec.items():
        b = region_bbox(rgba, reg)
        if b is None:
            print("  (nothing at", nm, ")"); continue
        save(scale_to(crop(rgba, b), width=w, height=h), group, nm)


def seasons():
    su = load("summer.png")
    tileset3x3(su, (25, 60, 445, 355), "grass_summer", inset=4) if False else None
    gs = cells_by_grid(su, 3, 3, region=(28, 62, 440, 350), trim=False)
    tiles = [scale_to(crop(su, (b[0] + 6, b[1] + 6, b[2] - 6, b[3] - 6)), width=TILE2, height=TILE2, cover=True) for row in gs for b in row]
    sheet = Image.new("RGBA", (TILE2 * 3, TILE2 * 3))
    for i, t in enumerate(tiles):
        sheet.alpha_composite(t, ((i % 3) * TILE2, (i // 3) * TILE2))
    save(sheet, "tiles", "grass_summer")
    props_from(su, "nature", {
        "hedge": ((900, 60, 1050, 200), (40, 40)),
        "apple_tree": ((30, 515, 200, 725), (80, 100)), "orange_tree": ((210, 515, 370, 725), (80, 100)), "plum_tree": ((380, 515, 545, 725), (80, 100)),
        "bush_red": ((545, 560, 690, 725), (40, 40)), "bush_blue": ((690, 560, 820, 725), (40, 40)), "bush_white": ((820, 560, 960, 725), (40, 40)),
        "sunflower_bush": ((960, 560, 1100, 725), (40, 48)), "logs": ((1230, 580, 1380, 725), (48, 36)),
        "sunflowers": ((850, 365, 980, 500), (32, 32)), "wheat": ((1370, 365, 1510, 500), (32, 36)),
    })
    props_from(su, "props", {
        "hay": ((560, 770, 700, 960), (40, 48)), "trough": ((1020, 790, 1200, 960), (56, 40)), "birdbath": ((1210, 770, 1320, 960), (36, 56)),
        "haystack": ((1330, 770, 1510, 960), (56, 56)), "stone_wall": ((480, 215, 860, 355), (96, 40)),
    })
    fa = load("fall.png")
    tileset3x3(fa, (25, 60, 505, 495), "grass_fall", center_inset=22)
    tileset3x3(fa, (530, 60, 1005, 495), "dirt_fall", center_inset=22)
    tileset3x3(fa, (1030, 60, 1510, 495), "stone_fall", center_inset=22)
    props_from(fa, "nature", {
        "tree_red": ((40, 775, 200, 1005), (96, 128)), "tree_orange": ((210, 775, 380, 1005), (96, 128)), "tree_birch": ((390, 775, 545, 1005), (80, 128)),
        "bush_fall_red": ((555, 830, 700, 960), (40, 40)), "bush_fall_orange": ((700, 830, 820, 960), (40, 40)), "berry_bush_fall": ((820, 830, 950, 960), (40, 40)),
        "rock_fall": ((950, 840, 1050, 960), (36, 36)), "log_fall": ((1060, 830, 1180, 960), (48, 36)), "mushrooms_fall": ((1190, 840, 1300, 960), (28, 32)),
        "stump_fall": ((1430, 560, 1510, 660), (36, 36)), "flowers_fall": ((1390, 850, 1510, 960), (36, 36)),
    })
    wi = load("winter.png")
    tileset3x3(wi, (25, 60, 445, 500), "grass_winter", center_inset=22)
    tileset3x3(wi, (525, 60, 945, 500), "soil_winter", center_inset=22)
    props_from(wi, "nature", {
        "bush_snow": ((40, 520, 210, 680), (40, 40)), "bush_bare_snow": ((220, 520, 400, 680), (40, 40)), "berry_bush_snow": ((420, 540, 560, 680), (40, 40)),
        "rock_snow_s": ((980, 560, 1090, 680), (28, 28)), "rock_snow_m": ((1100, 540, 1290, 680), (48, 48)), "rock_snow_l": ((1310, 520, 1510, 680), (60, 60)),
        "stump_snow": ((780, 560, 900, 680), (36, 36)),
        "pine_snow": ((320, 690, 480, 960), (80, 140)), "pine_snow_s": ((40, 750, 160, 960), (56, 100)),
        "tree_bare": ((850, 690, 1050, 960), (96, 128)), "tree_bare_s": ((540, 760, 650, 960), (56, 100)),
        "lamp_snow": ((1400, 700, 1510, 940), (24, 56)),
    })
    props_from(wi, "buildings", {"fence_snow": ((1080, 800, 1240, 930), (32, 32))})
    ice = cells_by_projection(wi, region=(985, 60, 1515, 500), row_gap=3, col_gap=3, min_size=50)
    tiles = [scale_to(crop(wi, (b[0] + 22, b[1] + 22, b[2] - 22, b[3] - 22)), width=TILE2, height=TILE2, cover=True) for row in ice[:3] for b in row[:3]]
    if len(tiles) == 9:
        sheet = Image.new("RGBA", (TILE2 * 3, TILE2 * 3))
        for i, t in enumerate(tiles):
            sheet.alpha_composite(t, ((i % 3) * TILE2, (i // 3) * TILE2))
        save(sheet, "tiles", "ice")


def weather():
    rgba = load("weather.png")
    def strip_from(reg, n, name, h):
        boxes = comps(rgba, reg, gap=10, min_size=6)[:n]
        frames = [scale_to(crop(rgba, b), height=h) for b in boxes]
        strip(frames, "fx", name)
    strip_from((230, 50, 620, 210), 3, "raindrop", 24)
    strip_from((700, 50, 1280, 210), 3, "rain_splash", 28)
    strip_from((130, 260, 620, 390), 3, "snowflake", 16)
    strip_from((700, 260, 1440, 390), 4, "leaf_green", 20)
    strip_from((50, 430, 710, 590), 4, "leaf_orange", 20)
    strip_from((790, 440, 1440, 590), 4, "firefly", 20)
    strip_from((60, 680, 830, 880), 4, "window_glow", 48)
    props_from(rgba, "props", {"lantern_unlit": ((900, 610, 1090, 950), (28, 64)), "lantern_lit": ((1120, 610, 1320, 950), (28, 64))})


def ui2():
    rgba = load("ui_kit2.png")
    for b, nm in zip(comps(rgba, (70, 20, 500, 155), gap=10, min_size=40)[:3], ["slot", "slot_hover", "slot_selected"]):
        save(scale_to(crop(rgba, b), width=40, height=40), "ui", nm)
    for b, nm in zip(comps(rgba, (1120, 30, 1480, 140), gap=10, min_size=30)[:3], ["pheart_empty", "pheart_half", "pheart_full"]):
        save(scale_to(crop(rgba, b), width=24, height=24), "ui", nm)
    props_from(rgba, "ui", {"hotbar_frame": ((40, 160, 1510, 345), (504, 64)), "dialogue_box": ((30, 345, 1510, 615), (508, 92)),
                            "clock_frame": ((5, 765, 630, 1010), (200, 80)), "quest_scroll": ((1160, 815, 1330, 965), (32, 32)),
                            "exclaim": ((1340, 815, 1510, 965), (24, 32))})
    for b, nm in zip(comps(rgba, (150, 615, 1400, 770), gap=12, min_size=40)[:7], ["skill_combat", "skill_farming", "skill_mining", "skill_foraging", "skill_fishing", "skill_bartering", "skill_building"]):
        save(scale_to(crop(rgba, b), width=32, height=32), "ui", nm)
    for b, nm in zip(comps(rgba, (660, 820, 1150, 950), gap=12, min_size=40)[:4], ["season_spring", "season_summer", "season_fall", "season_winter"]):
        save(scale_to(crop(rgba, b), width=24, height=24), "ui", nm)


def combat_fx():
    rgba = load("combat_fx.png")
    names = ["slash", "spark", "poof", "sparkle", "heal", "levelup", "bolt", "pawring"]
    sizes = {"slash": 64, "spark": 32, "poof": 48, "sparkle": 32, "heal": 48, "levelup": 64, "bolt": 32, "pawring": 72}
    bands = [(10, 140), (145, 235), (240, 350), (360, 445), (455, 570), (575, 715), (725, 800), (815, 1014)]
    for (y0, y1), nm in zip(bands, names):
        boxes = comps(rgba, (240, y0, 1310, y1), gap=20, min_size=8)[:6]
        if not boxes:
            print("  (fx none", nm, ")"); continue
        hmax = max(b[3] - b[1] for b in boxes)
        wmax = max(b[2] - b[0] for b in boxes)
        factor = sizes[nm] / max(hmax, wmax)
        scaled_strip(rgba, boxes, "fx", nm, factor)


def fishing():
    rgba = load("fishing.png")
    bob = comps(rgba, (90, 80, 1440, 230), gap=10, min_size=30)
    frames = [scale_to(crop(rgba, b), height=24) for b in bob[:4]]
    strip(frames, "fx", "bobber")
    frames = [scale_to(crop(rgba, b), height=32) for b in bob[4:6]]
    strip(frames, "fx", "bobber_bite")
    frames = [scale_to(crop(rgba, b), width=40, height=40) for b in comps(rgba, (180, 280, 1340, 470), gap=12, min_size=30)[:4]]
    strip(frames, "fx", "splash")
    ids = ["sunfish", "trout", "carp", "catfish", "salmon", "bass", "eel", "puffer", "goldfish", "starfin", "mooncarp", "boot"]
    grid = cells_by_grid(rgba, 6, 2, region=(30, 530, 1515, 950), inset=6)
    i = 0
    for row in grid:
        for b in row:
            if b and i < len(ids):
                save(scale_to(crop(rgba, b), width=32, height=32), "items", ids[i])
            i += 1


def mine_tiles():
    rgba = load("mine_tiles.png")
    tileset3x3(rgba, (25, 60, 455, 505), "mine_floor", center_inset=18)
    walls = cells_by_grid(rgba, 6, 3, region=(470, 60, 1505, 548), trim=False)
    names = {(0, 0): "wall_tl", (0, 1): "wall_t", (0, 5): "wall_tr", (1, 0): "wall_l", (1, 5): "wall_r", (2, 0): "wall_bl", (2, 1): "wall_b", (2, 5): "wall_br"}
    for (r, c), nm in names.items():
        x0, y0, x1, y1 = walls[r][c]
        b = region_bbox(rgba, (x0 + 4, y0 + 4, x1 - 4, y1 - 4))
        if b:
            save(scale_to(crop(rgba, b), width=TILE2, height=TILE2, cover=True), "tiles", nm)
    props_from(rgba, "props", {
        "ladder_down": ((70, 585, 260, 795), (36, 40)), "ladder_up": ((285, 575, 460, 795), (36, 56)),
        "rail": ((480, 620, 670, 785), (40, 32)), "rail_corner": ((680, 620, 870, 785), (40, 32)), "beam": ((910, 575, 1180, 805), (64, 56)),
    })
    row = comps(rgba, (30, 830, 1510, 965), gap=14, min_size=40)[:10]
    for b, nm in zip(row, ["mrock_a", "mrock_b", "mrock_moss", "ore_copper", "ore_iron", "ore_gold", "ore_crystal", "ore_dark", "cave_mushroom", "cave_moss"]):
        save(scale_to(crop(rgba, b), width=36, height=36), "props", nm)


def crafting():
    rgba = load("crafting.png")
    props_from(rgba, "props", {
        "workbench2": ((60, 40, 455, 345), (96, 72)), "furnace_off": ((530, 120, 705, 325), (40, 56)), "furnace_on": ((710, 120, 885, 325), (40, 56)),
        "chest_closed": ((1010, 160, 1150, 300), (36, 32)), "chest_open": ((1190, 140, 1345, 300), (36, 40)),
        "scarecrow2": ((715, 355, 885, 615), (40, 64)), "beehive2": ((910, 355, 1090, 615), (40, 60)), "keg": ((1120, 370, 1310, 615), (40, 56)), "jar": ((1350, 450, 1490, 615), (28, 36)),
    })
    frames = [scale_to(crop(rgba, b), width=48, height=48) for b in comps(rgba, (40, 470, 680, 620), gap=20, min_size=40)[:3]]
    strip(frames, "props", "sprinkler")
    frames = [scale_to(crop(rgba, b), height=80) for b in comps(rgba, (280, 660, 1250, 975), gap=20, min_size=60)[:4]]
    strip(frames, "props", "resonator")


def interior():
    rgba = load("interior.png")
    tileset3x3(rgba, (15, 85, 340, 415), "floor_wood")
    tileset3x3(rgba, (365, 85, 705, 415), "rug_red")
    for b, nm in zip(comps(rgba, (715, 110, 1125, 375), gap=6, min_size=60)[:3], ["wall_l", "wall_m", "wall_r"]):
        save(scale_to(crop(rgba, b), width=TILE2, height=TILE2 * 2), "tiles", "int_" + nm)
    props_from(rgba, "furniture", {
        "window": ((1140, 105, 1305, 375), (32, 64)), "door": ((1335, 105, 1505, 375), (32, 64)),
        "bed_single": ((20, 470, 200, 745), (40, 64)), "bed_double": ((230, 450, 500, 745), (64, 80)), "table": ((520, 490, 740, 705), (56, 56)),
        "chair_down": ((750, 490, 870, 690), (28, 44)), "chair_up": ((880, 500, 990, 690), (28, 40)), "bookshelf": ((1010, 470, 1220, 705), (56, 64)),
        "fireplace": ((1240, 390, 1510, 705), (72, 96)), "kitchen": ((10, 770, 440, 985), (120, 64)), "dresser": ((440, 810, 630, 985), (48, 48)),
        "plant": ((640, 770, 790, 985), (32, 64)), "lamp": ((790, 760, 910, 985), (28, 64)), "pet_bed": ((920, 840, 1080, 970), (40, 32)),
        "clock": ((1090, 840, 1210, 960), (28, 28)), "chest_closed": ((1230, 840, 1350, 965), (32, 32)), "chest_open": ((1370, 810, 1510, 965), (32, 40)),
    })


def hideout():
    rgba = load("hideout_tiles.png")
    tileset3x3(rgba, (25, 25, 395, 355), "asphalt")
    tileset3x3(rgba, (400, 25, 740, 355), "sidewalk")
    tileset3x3(rgba, (745, 25, 1100, 355), "dirt_lot", center_inset=16)
    props_from(rgba, "props", {
        "chain_fence_h": ((1110, 30, 1260, 185), (32, 32)), "chain_fence_v": ((1420, 30, 1510, 350), (16, 64)), "chain_gate": ((1270, 190, 1420, 350), (32, 36)),
        "dumpster": ((25, 375, 235, 530), (56, 40)), "fire_barrel_0": ((640, 390, 720, 535), (24, 40)),
        "crates_a": ((990, 380, 1138, 545), (40, 44)), "crates_b": ((1140, 380, 1270, 545), (40, 44)), "crates_c": ((1280, 380, 1510, 545), (64, 48)),
        "shack": ((40, 555, 945, 1005), (7 * TILE2, 6 * TILE2)), "black_market": ((990, 600, 1510, 1005), (5 * TILE2, 4 * TILE2)),
    })
    frames = [scale_to(crop(rgba, b), height=40) for b in comps(rgba, (640, 380, 985, 540), gap=8, min_size=30)[:4]]
    strip(frames, "props", "fire_barrel")
    frames = [scale_to(crop(rgba, b), width=56, height=32) for b in comps(rgba, (270, 390, 630, 530), gap=12, min_size=60)[:2]]
    strip(frames, "props", "neon_open")


def moon():
    rgba = load("moon_tiles.png")
    tileset3x3(rgba, (5, 15, 365, 365), "moon_dust", center_inset=14)
    tileset3x3(rgba, (375, 15, 745, 365), "crater")
    props_from(rgba, "props", {
        "moon_grass_a": ((760, 50, 860, 130), (24, 24)), "moon_grass_b": ((860, 50, 950, 130), (24, 24)), "moon_grass_c": ((950, 40, 1050, 130), (28, 28)),
        "moon_crystal_blue_s": ((1075, 20, 1220, 160), (36, 36)), "moon_crystal_pink_s": ((1230, 20, 1360, 160), (36, 36)), "moon_crystal_pink_t": ((1370, 20, 1500, 160), (36, 36)),
        "moon_crystal_blue": ((1075, 160, 1270, 360), (56, 56)), "moon_crystal_pink": ((1290, 160, 1500, 360), (56, 56)),
        "rocket_house": ((20, 375, 425, 1000), (4 * TILE2, 6 * TILE2 + 8)), "landing_pad": ((445, 420, 765, 725), (3 * TILE2, 3 * TILE2)),
        "bulb_plant": ((450, 770, 570, 950), (28, 48)), "spiral_fern": ((880, 810, 980, 950), (24, 32)),
    })
    frames = [scale_to(crop(rgba, b), width=64, height=72) for b in comps(rgba, (810, 480, 1515, 665), gap=10, min_size=60)[:4]]
    strip(frames, "props", "teleporter")


if __name__ == "__main__":
    # Start from the existing manifest so batch 1 entries are kept.
    mpath = os.path.join(S.OUT, "manifest.json")
    if os.path.exists(mpath):
        S.manifest.update(json.load(open(mpath)))
    steps = [
        ("tools_man", lambda: tools("tools_man.png", "man")), ("tools_woman", lambda: tools("tools_woman.png", "woman")),
        ("tools_son", lambda: tools("tools_son.png", "son")), ("tools_girl", lambda: tools("tools_girl.png", "girl")),
        ("tools_dog", lambda: tools("tools_dog.png", "dog")),
        ("portraits", lambda: [portraits(f"portraits_{c}.png", c) for c in ["man", "woman", "son", "girl", "dog"]]),
        ("villagers", villagers), ("crew", crew), ("rivals", rivals), ("gang_heroes", gang_heroes), ("president", president),
        ("grump_army", grump_army), ("crystals", crystals), ("seasons", seasons), ("weather", weather), ("ui2", ui2),
        ("combat_fx", combat_fx), ("fishing", fishing), ("mine_tiles", mine_tiles), ("crafting", crafting),
        ("interior", interior), ("hideout", hideout), ("moon", moon),
    ]
    only = sys.argv[1:]
    for name, fn in steps:
        if only and name not in only:
            continue
        try:
            fn(); print("ok", name)
        except Exception as e:
            import traceback; traceback.print_exc()
            print("FAIL", name, repr(e))
    with open(mpath, "w") as f:
        json.dump(S.manifest, f, indent=1, sort_keys=True)
