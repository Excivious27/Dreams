#!/usr/bin/env python3
"""Prompts 16 terrain sheets → art/gen: seamless ground and water textures
(group "seamless", 256×256 each), cliff faces and corners ("cliffs"), big stair
and ramp sets ("stairs"), soft ground edges and shores ("edges"). Merges into
art/gen/manifest.json. Run after slice_art.py and slice_art2.py.
"""
import json, os
import numpy as np
from PIL import Image
from scipy import ndimage
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INC = f"{R}/art/incoming"
GEN = f"{R}/art/gen"
man_p = f"{GEN}/manifest.json"
man = json.load(open(man_p)) if os.path.exists(man_p) else {}


def boxes(img, min_w=30, min_h=40, close=3):
    a = np.array(img.convert("RGB")).astype(int)
    mag = (a[:, :, 0] > 190) & (a[:, :, 1] < 90) & (a[:, :, 2] > 190)
    m2 = ndimage.binary_closing(~mag, iterations=close) if close else ~mag
    lab, _ = ndimage.label(m2)
    bs = [b for b in ndimage.find_objects(lab) if (b[0].stop - b[0].start) > min_h and (b[1].stop - b[1].start) > min_w]
    return [(b[1].start, b[0].start, b[1].stop - b[1].start, b[0].stop - b[0].start) for b in bs]


def keyed(img, box):
    x, y, w, h = box
    c = img.convert("RGBA").crop((x, y, x + w, y + h))
    a = np.array(c).astype(int)
    mag = (a[:, :, 0] > 170) & (a[:, :, 1] < 110) & (a[:, :, 2] > 170)
    a[mag, 3] = 0
    # soften the magenta fringe: pink-tinted edge pixels lose their tint
    fr = (a[:, :, 0] > 150) & (a[:, :, 2] > 150) & (a[:, :, 1] < 120) & ~mag
    a[fr, 3] = 0
    return Image.fromarray(a.astype("uint8"), "RGBA")


def save(group, name, im):
    os.makedirs(f"{GEN}/{group}", exist_ok=True)
    im.save(f"{GEN}/{group}/{name}.png")
    man.setdefault(group, {})[name] = {"file": f"{group}/{name}.png", "w": im.width, "h": im.height}


def rows_sorted(bs, band=60):
    return sorted(bs, key=lambda b: (b[1] // band, b[0]))


def square(img, box, inset=4):
    x, y, w, h = box
    return img.convert("RGB").crop((x + inset, y + inset, x + w - inset, y + h - inset)).resize((256, 256), Image.LANCZOS)


f = f"{INC}/w314_ground_seamless_a.png"
if os.path.exists(f):
    im = Image.open(f)
    names = ["meadow_grass", "dry_grass", "dirt_track", "sand", "wet_sand", "snow", "bog", "ruin_floor", "pavement", "pier_concrete",
             "forest_floor", "ash", "coral_sand", "frost", "cloud"]
    bs = rows_sorted([b for b in boxes(im, 200, 200, 0)], 200)
    for n, b in zip(names, bs):
        save("seamless", n, square(im, b))
f = f"{INC}/w315_water_seamless.png"
if os.path.exists(f):
    im = Image.open(f)
    bs = rows_sorted([b for b in boxes(im, 200, 200, 0) if b[3] > 200], 200)
    for n, b in zip(["lake_shallow", "lake_deep", "sea", "river", "bog_water", "lava"], bs):
        save("seamless", n, square(im, b))
f = f"{INC}/w319_ramps_stairs.png"
if os.path.exists(f):
    im = Image.open(f)
    bs = rows_sorted(boxes(im, 100, 100), 300)
    for n, b in zip(["stair_stone", "stair_stone_wide", "ramp_dirt", "ramp_dirt_wide", "stair_wood", "stair_crystal", "stair_iron", "stair_snow"], bs):
        save("stairs", n, keyed(im, b))
f = f"{INC}/w318_cliffs.png"
if os.path.exists(f):
    im = Image.open(f)
    bs = boxes(im, 40, 100)
    top = sorted([b for b in bs if b[1] < 440], key=lambda b: (b[1] // 100, b[0]))
    mid = sorted([b for b in bs if 440 <= b[1] < 620], key=lambda b: b[0])
    low = [b for b in bs if b[1] >= 620]
    for n, b in zip(["grass_strip", "snow_strip", "grass_tall", "snow_tall"], top):
        save("cliffs", n, keyed(im, b))
    pieces = ["outer_l", "outer_r", "inner_l", "inner_r", "side_l", "side_r"]
    for i, b in enumerate(mid):
        save("cliffs", ("grass_" if i < 6 else "snow_") + pieces[i % 6], keyed(im, b))
    strips = sorted([b for b in low if b[2] > 400], key=lambda b: b[1])
    for n, b in zip(["sand_strip", "sand_tall"], strips):
        save("cliffs", n, keyed(im, b))
    small = sorted([b for b in low if b[2] <= 400], key=lambda b: (b[1] // 120, b[0]))
    for n, b in zip(["sand_outer_l", "sand_outer_r", "sand_inner_l", "sand_inner_r", "sand_corner_a", "sand_corner_b", "sand_side_l", "sand_side_r"], small):
        save("cliffs", n, keyed(im, b))
f = f"{INC}/w316_edges_a.png"
if os.path.exists(f):
    im = Image.open(f)
    bs = boxes(im, 60, 60, 0)
    pairs = [("grass_dirt", "sand_wetsand"), ("grass_sand", "dirt_pavement"), ("grass_snow", "grass_forest"), ("grass_bog", "ash_lava"), ("grass_ruin", "coral_sea")]
    strips = sorted([b for b in bs if b[2] > 300], key=lambda b: (b[1] // 150, b[0]))
    for i, b in enumerate(strips):
        nm = pairs[i // 2][i % 2]
        save("edges", nm + "_strip", keyed(im, b))
        x0 = b[0] + b[2]
        corners = sorted([c for c in bs if c[2] <= 300 and x0 <= c[0] < x0 + 300 and b[1] - 10 <= c[1] < b[1] + b[3]], key=lambda c: (c[1] // 60, c[0]))
        for j, c in enumerate(corners[:4]):
            save("edges", "%s_%s" % (nm, ["outer_tl", "outer_tr", "inner_tl", "inner_tr"][j]), keyed(im, c))
f = f"{INC}/w317_shores.png"
if os.path.exists(f):
    im = Image.open(f)
    bs = boxes(im, 60, 60, 0)
    pairs = [("grass_lake", "sand_sea"), ("grass_river", "bog_bogwater"), ("snow_ice", "pier_sea")]
    strips = sorted([b for b in bs if b[2] > 300], key=lambda b: (b[1] // 150, b[0]))
    for i, b in enumerate(strips):
        nm = pairs[i // 2][i % 2]
        save("edges", nm + "_strip", keyed(im, b))
        x0 = b[0] + b[2]
        pcs = sorted([c for c in bs if c[2] <= 300 and x0 <= c[0] < x0 + 560 and abs(c[1] - b[1]) < 40], key=lambda c: c[0])
        for j, c in enumerate(pcs[:4]):
            save("edges", "%s_%s" % (nm, ["outer_tl", "outer_tr", "inner_tl", "inner_tr"][j]), keyed(im, c))


def nearest(bs, x, y):
    return min(bs, key=lambda b: (b[0] - x) ** 2 + (b[1] - y) ** 2)


def kit(fname, table, group="props", close=2):
    f = f"{INC}/{fname}"
    if not os.path.exists(f):
        return
    im = Image.open(f)
    bs = boxes(im, 14, 14, close)
    for name, x, y in table:
        save(group, name, keyed(im, nearest(bs, x, y)))


def fog(img, box):
    """Soft fog painted on magenta: alpha from how white it is (green channel)."""
    x, y, w, h = box
    a = np.array(img.convert("RGB").crop((x, y, x + w, y + h))).astype(float)
    alpha = np.clip((a[:, :, 1] - 20) / 200.0, 0, 1) * 200
    out = np.zeros((h, w, 4), dtype="uint8")
    out[:, :, 0:3] = 245
    out[:, :, 3] = alpha.astype("uint8")
    return Image.fromarray(out, "RGBA")


kit("w320_beach_kit.png", [
    ("bk_shell_conch", 28, 102), ("bk_shell_scallop", 89, 101), ("bk_shell_clam", 157, 107), ("bk_shell_cowrie", 222, 101),
    ("bk_starfish_orange", 304, 95), ("bk_starfish_pink", 374, 100), ("bk_starfish_purple", 434, 100), ("bk_sand_dollar_a", 510, 101),
    ("bk_sand_dollar_b", 570, 101), ("bk_crab", 647, 94), ("bk_pebbles_s", 749, 117), ("bk_pebbles_m", 807, 107), ("bk_pebbles_l", 882, 93),
    ("bk_driftwood_a", 989, 98), ("bk_driftwood_b", 1091, 98), ("bk_footprints", 1192, 63), ("bk_seaweed_a", 1269, 60), ("bk_seaweed_b", 1353, 67),
    ("bk_seaweed_c", 1440, 87), ("bk_dune_s", 17, 264), ("bk_dune_m", 137, 249), ("bk_dune_l", 299, 228), ("bk_tidepool_s", 505, 283),
    ("bk_tidepool_l", 628, 260), ("bk_towel", 802, 283), ("bk_sandcastle", 900, 258), ("bk_rowboat", 1029, 274), ("bk_lifeguard", 1178, 230),
    ("bk_umbrella_red", 1290, 258), ("bk_umbrella_blue", 1407, 258), ("bk_pier_straight", 62, 455), ("bk_pier_ladder", 343, 483),
    ("bk_pier_corner", 649, 483), ("bk_post", 977, 527), ("bk_post_rope", 1148, 527), ("bk_rope", 1315, 564),
    ("bk_foam_0", 26, 824), ("bk_foam_1", 400, 824), ("bk_foam_2", 775, 824), ("bk_foam_3", 1150, 824)])
kit("w321_marsh_kit.png", [
    ("mk_reeds_1", 28, 181), ("mk_reeds_2", 94, 157), ("mk_reeds_3", 161, 130), ("mk_reeds_4", 236, 100), ("mk_reeds_5", 324, 79),
    ("mk_cattail_1", 448, 107), ("mk_cattail_2", 517, 94), ("mk_cattail_3", 592, 75), ("mk_lily_l1", 708, 156), ("mk_lily_s1", 718, 105),
    ("mk_lily_s2", 794, 98), ("mk_lily_l2", 832, 152), ("mk_lily_s3", 876, 94), ("mk_log", 959, 136), ("mk_boardwalk", 1164, 107),
    ("mk_boardwalk_end", 1306, 104), ("mk_boardwalk_corner", 1399, 104),
    ("mk_wisp_blue_0", 53, 635), ("mk_wisp_blue_1", 145, 642), ("mk_wisp_blue_2", 237, 630), ("mk_wisp_blue_3", 327, 642),
    ("mk_wisp_green_0", 54, 743), ("mk_wisp_green_1", 146, 753), ("mk_wisp_green_2", 237, 739), ("mk_wisp_green_3", 327, 751),
    ("mk_frog_sit_0", 475, 638), ("mk_frog_sit_1", 597, 638), ("mk_frog_jump_0", 441, 788), ("mk_frog_jump_1", 543, 754),
    ("mk_frog_jump_2", 647, 773), ("mk_frog_jump_3", 752, 794),
    ("mk_heron_0", 881, 612), ("mk_heron_1", 1039, 614), ("mk_heron_2", 1197, 616), ("mk_heron_3", 1356, 612),
    ("mk_dragonfly_0", 918, 842), ("mk_dragonfly_1", 1074, 831), ("mk_dragonfly_2", 1214, 843), ("mk_dragonfly_3", 1350, 827)])
f = f"{INC}/w321_marsh_kit.png"
if os.path.exists(f):
    im = Image.open(f)
    for name, box in [("mk_fog_l", (60, 300, 620, 260)), ("mk_fog_m", (720, 320, 440, 200)), ("mk_fog_s", (1200, 360, 300, 150))]:
        save("props", name, fog(im, box))


def cave_kit(fname, kinds, props=None):
    f = f"{INC}/{fname}"
    if not os.path.exists(f):
        return
    im = Image.open(f)
    bs = boxes(im, 20, 20, 2)
    big = sorted([b for b in bs if b[2] > 250 and b[3] > 250], key=lambda b: (b[1] // 100, b[0]))
    strips = sorted([b for b in bs if b[2] > 600], key=lambda b: b[1])
    for i, k in enumerate(kinds):
        if 2 * i + 1 < len(big):
            save("seamless", f"cave_{k}_floor", square(im, big[2 * i], 6))
            save("seamless", f"cave_{k}_rock", square(im, big[2 * i + 1], 6))
        if i < len(strips):
            st = strips[i]
            save("cliffs", f"cave_{k}_wall", keyed(im, st))
            cs = sorted([c for c in bs if c[2] < 200 and st[1] + st[3] < c[1] < st[1] + st[3] + 120], key=lambda c: c[0])
            for j, c in enumerate(cs[:4]):
                save("cliffs", f"cave_{k}_{['outer_l', 'outer_r', 'inner_l', 'inner_r'][j]}", keyed(im, c))
    if props:
        low = sorted([b for b in bs if b[1] > 780 and b[2] < 200], key=lambda b: b[0])
        for n, b in zip(props, low):
            save("props", n, keyed(im, b))


cave_kit("w322_cave_kit_a.png", ["earth", "stone", "ice"])
cave_kit("w323_cave_kit_b.png", ["crystal", "lava"], ["cave_stalag_s", "cave_stalag_m", "cave_stalag_l", "cave_stalactite_a", "cave_stalactite_b",
         "cave_cart", "cave_rail", "cave_rail_bend", "cave_arch", "cave_lamp", "cave_mush_blue", "cave_mush_purple", "cave_mush_orange", "cave_pick_rock", "cave_ore_crate"])


def trim(im):
    bb = im.getbbox()
    return im.crop(bb) if bb else im


f = f"{INC}/w325_battle_helpers.png"
if os.path.exists(f):
    im = Image.open(f)
    xs = [20, 160, 300, 440, 585, 735, 885, 1040, 1235, 1370, 1520]
    ys = [15, 140, 270, 400, 530, 640, 750, 875, 1010]
    kinds = [("striker", "crystal"), ("healer", "crystal"), ("warden", "crystal"), ("shade", "crystal"),
             ("striker", "drone"), ("healer", "drone"), ("warden", "drone"), ("shade", "drone")]
    for r, (k, st) in enumerate(kinds):
        for c in range(10):
            anim, i = ("idle", c) if c < 4 else (("act", c - 4) if c < 8 else ("hurt", c - 8))
            box = (xs[c], ys[r], xs[c + 1] - xs[c], ys[r + 1] - ys[r])
            save("helpers", f"{k}_{st}_{anim}_{i}", trim(keyed(im, box)))
kit("w324_battle_structures.png", [
    ("flag_neutral_0", 46, 24), ("flag_neutral_1", 145, 24), ("flag_neutral_2", 244, 24), ("flag_neutral_3", 342, 24),
    ("flag_ally_0", 539, 24), ("flag_ally_1", 639, 24), ("flag_ally_2", 738, 24), ("flag_ally_3", 838, 24),
    ("flag_enemy_0", 1056, 24), ("flag_enemy_1", 1156, 24), ("flag_enemy_2", 1255, 24), ("flag_enemy_3", 1356, 24),
    ("spire_1", 160, 347), ("spire_2", 469, 302), ("spire_3", 807, 220), ("pylon", 1212, 282),
    ("bay_1", 64, 569), ("bay_2", 420, 558), ("bay_3", 789, 493), ("turret", 1282, 611),
    ("ring_0", 53, 847), ("ring_1", 237, 841), ("ring_2", 417, 840), ("ring_3", 601, 839), ("ring_4", 786, 839),
    ("ring_5", 971, 839), ("ring_6", 1158, 839), ("ring_7", 1342, 839)], group="battle")

json.dump(man, open(man_p, "w"), indent=1, sort_keys=True)
for g in ["seamless", "cliffs", "stairs", "edges"]:
    print(g, len(man.get(g, {})))
