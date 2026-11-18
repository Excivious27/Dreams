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


def _labels(img, close=3):
    a = np.array(img.convert("RGB")).astype(int)
    mag = (a[:, :, 0] > 190) & (a[:, :, 1] < 90) & (a[:, :, 2] > 190)
    m2 = ndimage.binary_closing(~mag, iterations=close) if close else ~mag
    return ndimage.label(m2)[0]


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
    lab = _labels(im, close)
    tot = np.bincount(lab.ravel())
    for name, x, y in table:
        b = nearest(bs, x, y)
        k = np.array(keyed(im, b))
        sub = lab[b[1]:b[1] + b[3], b[0]:b[0] + b[2]]
        ids, cnt = np.unique(sub[sub > 0], return_counts=True)
        # A neighbour reaching into the box (bk_towel had the sandcastle's edge): drop pieces that lie mostly outside it.
        away = [i for i, c in zip(ids, cnt) if c < 0.5 * tot[i]]
        if away:
            k[np.isin(sub, away), 3] = 0
        save(group, name, Image.fromarray(k, "RGBA"))


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


def strip(group, name, frames, h=96):
    """Frames → one horizontal strip (bottom-aligned cells of equal size)."""
    fr = []
    for im in frames:
        im = trim(im)
        k = h / im.height
        fr.append(im.resize((max(1, int(im.width * k)), h), Image.LANCZOS))
    cw = max(f.width for f in fr)
    out = Image.new("RGBA", (cw * len(fr), h), (0, 0, 0, 0))
    for i, f in enumerate(fr):
        out.alpha_composite(f, (i * cw + (cw - f.width) // 2, 0))
    os.makedirs(f"{GEN}/{group}", exist_ok=True)
    out.save(f"{GEN}/{group}/{name}.png")
    man.setdefault(group, {})[name] = {"file": f"{group}/{name}.png", "w": out.width, "h": h, "cell_w": cw, "cell_h": h, "frames": len(fr)}


def colony_sheet(fname, cid, elder, frames, portraits, props, villagers, boss, boss_h=96):
    f = f"{INC}/{fname}"
    if not os.path.exists(f):
        return
    im = Image.open(f)
    bs = boxes(im, 30, 30, 2)
    get = lambda xy: keyed(im, nearest(bs, xy[0], xy[1]))
    for anim, pts in frames.items():
        strip(f"characters/{elder}", anim, [get(p) for p in pts])
    strip(f"characters/{elder}", "walk", [get(p) for p in frames["idle"]])
    for name, p in zip(["neutral", "happy", "sad", "worried", "surprised", "grateful"], portraits):
        save(f"portraits/{elder}", name, trim(get(p)))
    for name, p in props.items():
        save("props", f"{cid}_{name}", trim(get(p)))
    for i, pts in enumerate(villagers):
        vid = f"{cid}_kit_{i + 1}"
        strip(f"characters/{vid}", "idle", [get(p) for p in pts])
        strip(f"characters/{vid}", "walk", [get(p) for p in pts])
    for anim, pts in boss.items():
        strip(f"enemies/cboss_{cid}", anim, [get(p) for p in pts], boss_h)


colony_sheet("w326_colony_coral.png", "coral", "elder_brine",
    {"idle": [(26, 23), (133, 23), (240, 23), (343, 23)], "talk": [(468, 23), (573, 23), (676, 23), (777, 23)], "happy": [(917, 18), (1032, 18)], "sad": [(1170, 22), (1277, 22)]},
    [(44, 148), (287, 148), (529, 148), (776, 148), (1021, 145), (1275, 148)],
    {"house_1": (15, 389), "house_2": (228, 392), "house_3": (440, 380), "stall_open": (651, 408), "stall_closed": (843, 410), "crystal_dim": (1030, 400),
     "crystal_lit": (1185, 400), "beacon_off": (1351, 398), "beacon_on": (1444, 397), "blight_1": (21, 678), "blight_2": (109, 649), "blight_3": (224, 628)},
    [[(395, 639), (474, 639), (549, 639), (626, 639)], [(749, 636), (833, 637), (915, 637), (998, 637)], [(1139, 630), (1238, 631), (1334, 630), (1429, 630)]],
    {"idle": [(15, 780), (174, 786), (324, 784), (464, 789)], "walk": [(15, 780), (174, 786), (324, 784), (464, 789)], "attack": [(608, 771), (748, 791), (912, 792), (1078, 801)], "hurt": [(1247, 792), (1391, 806)]})
colony_sheet("w327_colony_kelp.png", "kelp", "elder_tidewhisker",
    {"idle": [(45, 14), (178, 14), (304, 14)], "talk": [(455, 15), (577, 15), (690, 15), (808, 16)], "happy": [(951, 16), (1073, 16)], "sad": [(1239, 16), (1370, 18)]},
    [(41, 140), (291, 140), (532, 146), (777, 140), (1013, 140), (1260, 141)],
    {"house_1": (18, 364), "house_2": (249, 371), "house_3": (484, 362), "stall_open": (679, 398), "stall_closed": (913, 398), "crystal_dim": (1154, 374),
     "crystal_lit": (1348, 374), "beacon_off": (22, 600), "beacon_on": (139, 600), "blight_1": (261, 624), "blight_2": (489, 627), "blight_3": (680, 616)},
    [[(914, 603), (1064, 603), (1214, 604), (1369, 603)], [(914, 713), (1063, 713), (1213, 713), (1366, 713)], [(915, 844), (1071, 844), (1224, 844), (1373, 844)]],
    {"idle": [(21, 784)], "walk": [(21, 784)], "attack": [(21, 784)], "hurt": [(21, 784)]}, 56)
colony_sheet("w328_colony_ice.png", "ice", "elder_icewhisker",
    {"idle": [(40, 20), (157, 22), (274, 22), (390, 22)], "talk": [(39, 129), (162, 129), (279, 129), (396, 132)], "happy": [(39, 237), (162, 237)], "sad": [(39, 349), (165, 353)]},
    [(541, 7), (788, 7), (1035, 10), (542, 221), (790, 221), (1037, 221)],
    {"house_1": (8, 460), "house_2": (218, 470), "house_3": (442, 437), "stall_open": (667, 458), "stall_closed": (922, 461), "crystal_dim": (1164, 444),
     "crystal_lit": (1359, 430), "beacon_off": (28, 640), "beacon_on": (140, 637), "blight_1": (352, 726), "blight_2": (437, 697), "blight_3": (544, 650),
     "boss_copy_1": (288, 801), "boss_copy_2": (552, 801)},
    [[(838, 643), (958, 644), (1076, 644), (1193, 644)], [(836, 760), (962, 760), (1076, 760), (1194, 760)], [(837, 878), (962, 878), (1082, 878), (1196, 878)]],
    {"idle": [(23, 798)], "walk": [(23, 798)], "attack": [(23, 798)], "hurt": [(288, 801)]})
colony_sheet("w329_colony_ember.png", "ember", "elder_cinderpaw",
    {"idle": [(19, 18), (125, 18), (227, 18), (325, 18)], "talk": [(456, 18), (560, 18), (662, 18), (763, 18)], "happy": [(896, 18), (995, 18)], "sad": [(1127, 18), (1224, 18)]},
    [(41, 154), (286, 155), (524, 155), (763, 155), (1003, 155), (1240, 155)],
    {"house_1": (20, 400), "house_2": (284, 399), "house_3": (566, 400), "stall_open": (874, 425), "stall_closed": (1187, 429), "crystal_dim": (31, 647),
     "crystal_lit": (255, 647), "beacon_off": (483, 647), "beacon_on": (613, 647), "blight_1": (762, 728), "blight_2": (894, 733), "blight_3": (1016, 735)},
    [[(31, 880), (112, 881), (194, 881), (276, 882)], [(389, 879), (469, 879), (548, 880), (627, 881)], [(744, 879), (828, 880), (911, 880), (996, 880)]],
    {"idle": [(1115, 643)], "walk": [(1115, 643)], "attack": [(1115, 643)], "hurt": [(1115, 643)]})

json.dump(man, open(man_p, "w"), indent=1, sort_keys=True)
for g in ["seamless", "cliffs", "stairs", "edges"]:
    print(g, len(man.get(g, {})))
