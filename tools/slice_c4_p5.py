#!/usr/bin/env python3
"""CONDUCT 4 fix package P5 art (image tool renders in art/incoming/c4/).

  thornmother.png      enemies/thornmother (walk 4, idle, attack 3, hurt) + ui/card_thornmother
  sun_colossus.png     enemies/sun_colossus (same layout)          + ui/card_sun_colossus
  gang_bosses.png      enemies/gang_boss_gloam / _desert / _frost   + ui/card_gang_boss_*
  desert_enemies.png   enemies/dune_crab, sand_hound, sun_moth, glass_golem
  guards.png           enemies/casino_guard, rail_bot
  hidden_kit.png       props/hidden_crack_wall, hidden_vine_curtain, hidden_stairs,
                       hidden_cave_mouth_<cave|gloam|desert|frost|city>
  props_mix.png        props/stall_knit, props/boutique_gold, nature/alien_tree_a..c
  station_kit.png      kits/station_wall, _window, _door, _pipes, _console, _corner (group "kits/station")
  ground_bits.png      decals/glass_a..c, props/cf_bed_halfdug_a/_b, props/cf_saplings_staked
  cloudstone_cliff.png cliffs/cloudstone_strip, cloudstone_side_l, cloudstone_side_r
  gloam_npc_walks.png  characters/mg_liesl|mg_fenn|mg_bramble walk_up (4) + walk (4, side, faces right)
  (procedural)         fx/firefly_0..3 (soft glow pulse, 24 px)

Boss cards are composed from the existing card frame (ui/card_big_grump) with the
boss's idle frame on the left, so every card matches the others.
Enemy frames face right (Enemy flips them when moving left).
Run after the other slicers:  python3 tools/slice_c4_p5.py [step ...]
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_comp import blobs, rows_of, tight, piece, row_n
import numpy as np
from PIL import Image, ImageFilter

SRC = "c4/"


def _rm(group, name):
    p = os.path.join(S.OUT, group, name + ".png")
    if os.path.exists(p):
        os.remove(p)  # hardlinked art: never write in place


def save(img, group, name):
    _rm(group, name)
    return S.save(img, group, name)


def strip(frames, group, name):
    _rm(group, name)
    S.strip(frames, group, name)


def rgba_of(file):
    """Keyed sheet; renders that came back with a real alpha keep it (min of both)."""
    src = Image.open(os.path.join(S.INC, SRC + file)).convert("RGBA")
    a = S.key_magenta(src)
    sa = np.asarray(src)[..., 3]
    a[..., 3] = np.minimum(a[..., 3], sa)
    return a


def merged_rows(rgba, n_rows, n_per, merge=10, min_area=1500):
    """Rows of exactly n_per boxes: small bits (sparkles, smoke, whips) join the nearest frame."""
    bx = blobs(rgba, merge=merge, min_area=min_area)
    rows = [r for r in rows_of(bx) if len(r) >= 1]
    big = sorted(rows, key=lambda r: -sum((b[2] - b[0]) * (b[3] - b[1]) for b in r))[:n_rows]
    big.sort(key=lambda r: r[0][1])
    out = []
    for r in big:
        r = sorted(r, key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))
        keep = sorted(r[:n_per], key=lambda b: b[0])
        for b in r[n_per:]:
            cx = (b[0] + b[2]) / 2
            i = min(range(len(keep)), key=lambda k: abs((keep[k][0] + keep[k][2]) / 2 - cx))
            k = keep[i]
            keep[i] = (min(k[0], b[0]), min(k[1], b[1]), max(k[2], b[2]), max(k[3], b[3]))
        assert len(keep) == n_per, (len(keep), n_per)
        out.append(keep)
    assert len(out) == n_rows, [len(r) for r in rows]
    return out


def frames_at(rgba, boxes, h, ref=None, flip=False):
    """Scale every frame by one factor so the reference frames are h tall."""
    ref = ref or boxes
    hs = sorted(b[3] - b[1] for b in ref)
    f = h / float(hs[len(hs) // 2])
    P = [piece(rgba, tight(rgba, b), factor=f) for b in boxes]
    P = [S_clean(p) for p in P]
    if flip:
        P = [p.transpose(Image.FLIP_LEFT_RIGHT) for p in P]
    return P


def S_clean(im):
    a = np.asarray(im).copy()
    a[..., 3] = np.where(a[..., 3] > 140, 255, np.where(a[..., 3] > 60, a[..., 3], 0))
    return Image.fromarray(a)


IDLE = {}  # kind -> first frame (cards)


def boss8(file, kind, h, flip=False):
    rgba = rgba_of(file)
    r1, r2 = merged_rows(rgba, 2, 4)
    W = frames_at(rgba, r1 + r2, h, ref=r1, flip=flip)
    g = "enemies/" + kind
    strip(W[0:4], g, "walk")
    strip([W[0], W[2]], g, "idle")
    strip(W[4:7], g, "attack")
    strip([W[7]], g, "hurt")
    IDLE[kind] = W[0]


def thornmother():
    boss8("thornmother.png", "thornmother", 150)


def sun_colossus():
    boss8("sun_colossus.png", "sun_colossus", 172, flip=True)


def rows4(file, kinds, heights, flip=True):
    rgba = rgba_of(file)
    rows = merged_rows(rgba, len(kinds), 4)
    for kind, row, h in zip(kinds, rows, heights):
        P = frames_at(rgba, row, h, ref=row[:2], flip=flip)
        g = "enemies/" + kind
        strip([P[0], P[1]], g, "walk")
        strip([P[0], P[0], P[1], P[1]], g, "idle")
        strip([P[0], P[2], P[2]], g, "attack")
        strip([P[3]], g, "hurt")
        IDLE[kind] = P[0]


def gang_bosses():
    rows4("gang_bosses.png", ["gang_boss_gloam", "gang_boss_desert", "gang_boss_frost"], [80, 82, 80])


def desert():
    rows4("desert_enemies.png", ["dune_crab", "sand_hound", "sun_moth", "glass_golem"], [46, 54, 58, 76])


def guards():
    rows4("guards.png", ["casino_guard", "rail_bot"], [62, 60])


def cards():
    """ui/card_<boss>: the shared ornate frame with the boss on the left (game draws the name)."""
    base = Image.open(os.path.join(S.OUT, "ui", "card_big_grump.png")).convert("RGBA")
    a = np.asarray(base).astype(np.int32)
    W, H = base.size
    # Inner panel: the dark red area. Repaint it as a clean vertical-banded gradient.
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    inner_box = (24, 30, W - 24, H - 22)
    x0, y0, x1, y1 = inner_box
    panel = np.zeros((y1 - y0, x1 - x0, 4), np.int32)
    xs = np.linspace(0, 1, x1 - x0)[None, :]
    ys = np.linspace(0, 1, y1 - y0)[:, None]
    shade = 0.55 + 0.45 * (1 - np.abs(ys - 0.5) * 1.6) * (1 - 0.6 * xs)
    panel[..., 0] = (92 * shade).astype(int)
    panel[..., 1] = (14 * shade).astype(int)
    panel[..., 2] = (22 * shade).astype(int)
    panel[..., 3] = 255
    for kind in ["thornmother", "sun_colossus", "gang_boss_gloam", "gang_boss_desert", "gang_boss_frost"]:
        if kind not in IDLE:
            continue
        c = a.copy()
        # repaint everything in the panel that is not the gold frame (the old boss, its clouds)
        reg = c[y0:y1, x0:x1]
        rr, gg, bb = reg[..., 0], reg[..., 1], reg[..., 2]
        gold = (rr > 120) & (gg > 70) & (bb < gg) & (rr > bb + 40)
        m = (~gold) & (reg[..., 3] > 0)
        m[12:-6, 14:-14] = True
        reg[m] = panel[m]
        img = Image.fromarray(c.astype(np.uint8))
        spr = IDLE[kind]
        ph = (y1 - y0) - 16
        f = ph / float(spr.height)
        sw = round(spr.width * f)
        if sw > (x1 - x0) * 0.45:
            f = (x1 - x0) * 0.45 / spr.width
            sw = round(spr.width * f)
        big = spr.resize((sw, max(1, round(spr.height * f))), Image.NEAREST)
        # soft glow behind the boss
        glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
        gl = Image.new("RGBA", big.size, (255, 200, 140, 0))
        al = np.asarray(big)[..., 3]
        gl.putalpha(Image.fromarray((al > 0).astype(np.uint8) * 90))
        px = x0 + 40
        py = y1 - 8 - big.height
        glow.alpha_composite(gl, (px, py))
        glow = glow.filter(ImageFilter.GaussianBlur(10))
        img.alpha_composite(glow)
        img.alpha_composite(big, (px, py))
        save(img, "ui", "card_" + kind)


def hidden_kit():
    rgba = rgba_of("hidden_kit.png")
    r1, r2 = merged_rows(rgba, 2, 4, merge=8, min_area=3000)
    names = ["hidden_crack_wall", "hidden_vine_curtain", "hidden_stairs", "hidden_cave_mouth_cave",
             "hidden_cave_mouth_gloam", "hidden_cave_mouth_desert", "hidden_cave_mouth_frost", "hidden_cave_mouth_city"]
    widths = [64, 56, 48, 72, 72, 72, 72, 72]
    for nm, b, w in zip(names, r1 + r2, widths):
        im = S_clean(piece(rgba, tight(rgba, b), factor=w / float(b[2] - b[0])))
        save(im, "props", nm)


def props_mix():
    rgba = rgba_of("props_mix.png")
    rows = rows_of(blobs(rgba, merge=8, min_area=3000))
    rows = [r for r in rows if len(r) >= 2]
    assert [len(r) for r in rows] == [2, 3], [len(r) for r in rows]
    for nm, b, w in zip(["stall_knit", "boutique_gold"], rows[0], [92, 104]):
        save(S_clean(piece(rgba, tight(rgba, b), factor=w / float(b[2] - b[0]))), "props", nm)
    for nm, b in zip(["alien_tree_a", "alien_tree_b", "alien_tree_c"], rows[1]):
        f = 96 / float(b[3] - b[1])
        save(S_clean(piece(rgba, tight(rgba, b), factor=f)), "nature", nm)


def station_kit():
    rgba = rgba_of("station_kit.png")
    rows = merged_rows(rgba, 2, 3, merge=6, min_area=3000)
    names = ["station_wall", "station_window", "station_door", "station_pipes", "station_console", "station_corner"]
    hs = sorted(b[3] - b[1] for b in rows[0])
    f = 64 / float(hs[1])  # one wall height for every piece
    for nm, b in zip(names, rows[0] + rows[1]):
        save(S_clean(piece(rgba, tight(rgba, b), factor=f)), "kits/station", nm)


def ground_bits():
    rgba = rgba_of("ground_bits.png")
    rows = rows_of(blobs(rgba, merge=14, min_area=2500))
    rows = [r for r in rows if len(r) >= 3]
    assert len(rows) == 2, [len(r) for r in rows]
    for i, b in enumerate(rows[0][:3]):
        im = piece(rgba, tight(rgba, b), factor=64 / float(b[2] - b[0]))
        q = np.asarray(im).copy()
        q[..., 3] = (q[..., 3].astype(np.int32) * 225 // 255).astype(np.uint8)  # sits on sand
        save(Image.fromarray(q), "decals", "glass_" + "abc"[i])
    beds = rows[1][:2]
    for nm, b in zip(["cf_bed_halfdug_a", "cf_bed_halfdug_b"], beds):
        save(S_clean(piece(rgba, tight(rgba, b), factor=64 / float(b[2] - b[0]))), "props", nm)
    rest = rows[1][2:]
    u = (min(b[0] for b in rest), min(b[1] for b in rest), max(b[2] for b in rest), max(b[3] for b in rest))
    trees = row_n(rgba, [u], 3, min_gap=4)
    assert len(trees) == 3, trees
    f = 56 / float(max(b[3] - b[1] for b in trees))  # cf_sapling is 60 tall
    for i, b in enumerate(trees):
        save(S_clean(piece(rgba, tight(rgba, b), factor=f)), "props", "cf_sapling_staked_" + "abc"[i])
    save(S_clean(piece(rgba, tight(rgba, u), factor=f)), "props", "cf_saplings_staked")


def cloudstone():
    rgba = rgba_of("cloudstone_cliff.png")
    rows = rows_of(blobs(rgba, merge=8, min_area=3000))
    strip_b = max(rows[0], key=lambda b: b[2] - b[0])
    sides = sorted(rows[1], key=lambda b: b[0])
    assert len(sides) == 2, rows
    ref = Image.open(os.path.join(S.OUT, "cliffs", "grass_strip.png"))
    f = ref.height / float(strip_b[3] - strip_b[1])
    save(S_clean(piece(rgba, tight(rgba, strip_b), w=ref.width, h=ref.height)), "cliffs", "cloudstone_strip")
    for nm, b in zip(["cloudstone_side_l", "cloudstone_side_r"], sides):
        rf = Image.open(os.path.join(S.OUT, "cliffs", "grass_" + nm.split("_", 1)[1] + ".png"))
        save(S_clean(piece(rgba, tight(rgba, b), w=rf.width, h=rf.height)), "cliffs", nm)


def gloam_walks():
    rgba = rgba_of("gloam_npc_walks.png")
    rows = merged_rows(rgba, 3, 8, merge=3, min_area=600)
    for cid, row in zip(["mg_liesl", "mg_fenn", "mg_bramble"], rows):
        P = frames_at(rgba, row, 48, ref=row[:4])
        g = "characters/" + cid
        strip(P[0:4], g, "walk_up")
        strip(P[4:8], g, "walk")
        strip([P[0]], g, "idle_up")


def fireflies():
    """fx/firefly_0..3: a warm yellow-green glow that pulses (24 px, soft halo, bright core)."""
    n = 24
    yy, xx = np.mgrid[0:n, 0:n]
    d = np.hypot(xx - (n - 1) / 2, yy - (n - 1) / 2)
    for i, k in enumerate([0.55, 0.8, 1.0, 0.75]):
        halo = np.clip(1 - d / (11 * (0.7 + 0.3 * k)), 0, 1) ** 2.2 * 150 * k
        core = np.where(d <= 1.6 + k, 255, 0)
        mid = np.clip(1 - d / (4 + 1.5 * k), 0, 1) * 230
        a = np.maximum(np.maximum(halo, core), mid).astype(np.uint8)
        im = np.zeros((n, n, 4), np.uint8)
        im[..., 0] = np.where(d <= 2.2, 255, 214)
        im[..., 1] = 255
        im[..., 2] = np.where(d <= 2.2, 220, 120)
        im[..., 3] = a
        save(Image.fromarray(im), "fx", "firefly_%d" % i)


STEPS = [thornmother, sun_colossus, gang_bosses, desert, guards, cards, hidden_kit, props_mix,
         station_kit, ground_bits, cloudstone, gloam_walks, fireflies]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    only = sys.argv[1:]
    for fn in STEPS:
        if only and fn.__name__ not in only and not (fn is cards):
            continue
        fn(); print("ok", fn.__name__)
    data = json.dumps(S.manifest, indent=1, sort_keys=True)
    os.remove(mpath)  # hardlinked across worktrees: never write it in place
    with open(mpath, "w") as fh:
        fh.write(data)
