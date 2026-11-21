#!/usr/bin/env python3
"""CONDUCT 14 P6 art slicer: redraws of broken existing art ids (rm first, then write).

Sources (dreams-image renders, art/incoming/c14p6/):
  flame_core.png  -> items/flame_core (c14_17-01: the old icon was a broken fragment)
  dunes.png, dunes-2.png (5 isolated props each, one row) -> nature/dune_0..9
                      (c14_17-04 / c14_15-01: the old set were square sand crops)
  nature_fix.png  -> nature/hedge (round free-standing shrub), nature/grass_tuft_winter (no key halo)
  icons_fix.png   -> items/luck_potion, harvest_potion (no card crop), golem_core (no sliver)

Colour key: the C11b violet-safe key (cut magenta only in regions touching near-pure
#FF00FF); renders that already carry alpha keep it. Pieces are found as alpha blobs
(sparks within a few px merge into their piece), cropped, and scaled down to the
target box with a hard alpha edge. Usage: python3 tools/slice_c14_art.py [--check]
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INC = os.path.join(ROOT, "art", "incoming", "c14p6")
GEN = os.path.join(ROOT, "art", "gen")
MAN = os.path.join(GEN, "manifest.json")

# sheet -> (group, [ids left to right], (max_w, max_h))
JOBS = [
    ("flame_core.png", "items", ["flame_core"], (32, 32)),
    ("dunes.png", "nature", ["dune_0", "dune_1", "dune_2", "dune_3", "dune_4"], (40, 30)),
    ("dunes-2.png", "nature", ["dune_5", "dune_6", "dune_7", "dune_8", "dune_9"], (40, 30)),
    ("nature_fix.png", "nature", ["hedge", "grass_tuft_winter"], [(40, 35), (116, 89)]),  # c14_17-18, c14_16-14
    ("icons_fix.png", "items", ["luck_potion", "harvest_potion", "golem_core"], (32, 32)),  # c14_17-06, c14_17-16
]


def load(path):
    a = np.array(Image.open(path).convert("RGBA"))
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    loose = (r > 150) & (g < 110) & (b > 150) & (r - g > 80) & (b - g > 80)
    strict = (r > 215) & (b > 215) & (g < 60)
    lab, _ = ndimage.label(loose)
    hit = np.unique(lab[strict & loose])
    a[np.isin(lab, hit[hit > 0]), 3] = 0
    return a


def pieces(a, n, join=24):
    """The n biggest alpha blobs (specks within 24 px join), left to right."""
    solid = a[..., 3] > 40
    lab, k = ndimage.label(ndimage.binary_dilation(solid, iterations=join))
    sizes = ndimage.sum(solid, lab, range(1, k + 1))
    keep = list(np.argsort(sizes)[::-1][:n] + 1)
    boxes = []
    for i in keep:
        ys, xs = np.where((lab == i) & solid)
        boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1, i))
    boxes.sort(key=lambda b: b[0])
    out = []
    for x0, y0, x1, y1, i in boxes:
        crop = a[y0:y1, x0:x1].copy()
        crop[~(lab[y0:y1, x0:x1] == i), 3] = 0
        out.append(crop)
    return out


def shrink(crop, box):
    h, w = crop.shape[:2]
    s = min(box[0] / w, box[1] / h)
    tw, th = max(1, round(w * s)), max(1, round(h * s))
    im = Image.fromarray(crop)
    # premultiplied box filter so the key colour never bleeds into the edge
    arr = np.array(im).astype(float)
    arr[..., :3] *= arr[..., 3:4] / 255.0
    pm = Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA").resize((tw, th), Image.BOX)
    p = np.array(pm).astype(float)
    al = p[..., 3:4]
    rgb = np.where(al > 0, p[..., :3] * 255.0 / np.maximum(al, 1), 0)
    out = np.dstack([rgb, np.where(al[..., 0] >= 110, 255, 0)]).clip(0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


# Seamless ground re-renders (c14_17-07 / c14_15-02): 1024 render -> 256 box-filtered, then the
# Poisson periodic component (tools/make_seamless.seamless) so the edges wrap with no fade ghosts.
SEAMLESS = ["cobble_warm", "cobble_grey", "cobble_moss", "brick_herring", "flagstone", "ballast"]
# Patterned ones: crop a whole number of pattern periods (autocorrelation peaks) before the
# shrink, so the bond lines up across the wrap instead of breaking every 8 cells.
PATTERNED = ["brick_herring"]


def period_crop(im):
    a = np.asarray(im.convert("L")).astype(float)
    a -= a.mean()
    f = np.fft.fft2(a)
    ac = np.real(np.fft.ifft2(f * np.conj(f)))
    out = []
    for prof in (ac[0, :], ac[:, 0]):
        n = len(prof)
        p = int(np.argmax(prof[60:n // 2])) + 60
        k = max(1, (n - 8) // p)
        lo, hi = k * p - 6, min(n - 1, k * p + 6)
        out.append(int(np.argmax(prof[lo:hi + 1])) + lo if hi < n else k * p)
    return im.crop((0, 0, out[0], out[1]))


def seamless_jobs(check):
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import importlib.util
    spec = importlib.util.spec_from_file_location("ms", os.path.join(ROOT, "tools", "make_seamless.py"))
    ms = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ms)
    out = []
    for nm in SEAMLESS:
        src = os.path.join(INC, nm + ".png")
        if not os.path.exists(src):
            continue
        im = Image.open(src).convert("RGB")
        if nm in PATTERNED:
            im = period_crop(im)
        im = im.resize((256, 256), Image.BOX)
        a = np.array(im).astype(float)
        o = ms.seamless(a).clip(0, 255).astype(np.uint8)
        o = np.dstack([o, np.full(o.shape[:2], 255, np.uint8)])
        if not check:
            dst = os.path.join(GEN, "seamless", nm + ".png")
            if os.path.exists(dst):
                os.remove(dst)
            Image.fromarray(o, "RGBA").save(dst)
        out.append("seamless/%s 256x256 wrap %.1f" % (nm, ms.stats(o.astype(float))[1]))
    return out


# Mega-region villagers (c14_17-08): 4 per sheet, one per row, 12 cells = walk down x4,
# walk side (facing right; NPCs flip for left) x4, walk up (back view) x4. Writes walk (4),
# walk_up (4), idle_up (back still), idle_side (side still); walk_down stays (it matches idle).
MG_SHEETS = {
    "mg_walk_a.png": ["mg_liesl", "mg_fenn", "mg_bramble", "mg_sefa"],
    "mg_walk_b.png": ["mg_rahim", "mg_nadia", "mg_hollis", "mg_dot"],
    "mg_walk_c.png": ["mg_skip", "mg_brannoch", "mg_ingrid", "mg_tove"],
    "mg_walk_d.png": ["mg_zephyr", "mg_gull", "mg_nimbus", "mg_pell"],
    "mg_walk_e.png": ["mg_odette", "mg_cass", "mg_aurum", "mg_coalbrook"],
}


def row_bands(a, n):
    rows = (a[..., 3] > 40).any(axis=1)
    lab, k = ndimage.label(rows)
    bands = [(np.where(lab == i)[0].min(), np.where(lab == i)[0].max() + 1) for i in range(1, k + 1)]
    bands = sorted(bands, key=lambda b: b[1] - b[0], reverse=True)[:n]
    return sorted(bands)


def cells12(a, n=12):
    """12 evenly spaced figures in a row: cut at the emptiest column near each expected
    boundary (wide hats and staffs can touch, so blobs alone don't separate them)."""
    col = (a[..., 3] > 40).sum(axis=0).astype(float)
    xs = np.where(col > 0)[0]
    x0, x1 = xs.min(), xs.max() + 1
    cw = (x1 - x0) / float(n)
    cuts = [x0]
    for i in range(1, n):
        e = x0 + cw * i
        lo, hi = int(e - cw * 0.3), int(e + cw * 0.3)
        cuts.append(lo + int(np.argmin(col[lo:hi])))
    cuts.append(x1)
    out = []
    for i in range(n):
        c = a[:, cuts[i]:cuts[i + 1]].copy()
        solid = c[..., 3] > 40
        lab, k = ndimage.label(ndimage.binary_dilation(solid, iterations=2))
        if k > 1:  # keep the figure (biggest blob) and what touches it, drop neighbour slivers
            sizes = ndimage.sum(solid, lab, range(1, k + 1))
            keep = int(np.argmax(sizes)) + 1
            for j in range(1, k + 1):
                if j != keep and sizes[j - 1] < sizes[keep - 1] * 0.08:
                    c[lab == j, 3] = 0
        ys, xs2 = np.where(c[..., 3] > 40)
        out.append(c[ys.min():ys.max() + 1, xs2.min():xs2.max() + 1])
    return out


OLD_SIDE = {}  # villager -> its old side still (read once, before this slicer replaces it)


def faces_left(f, grp, man):
    """Does this side frame face the other way from the villager's old side art?"""
    if grp not in OLD_SIDE:
        info = man[grp].get("idle_side") or man[grp]["walk"]
        o = Image.open(os.path.join(GEN, info["file"])).convert("RGBA")
        OLD_SIDE[grp] = o.crop((0, 0, int(info.get("cell_w", o.width)), o.height))
    o = OLD_SIDE[grp]
    def prof(im):
        a = np.array(im.resize((32, 40), Image.BOX)).astype(float)
        return (a[..., :3] * (a[..., 3:4] / 255.0)).ravel()
    po = prof(o)
    same = np.abs(prof(f) - po).mean()
    flip = np.abs(prof(f.transpose(Image.FLIP_LEFT_RIGHT)) - po).mean()
    return flip < same


def strip(frames, cw, ch):
    out = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * cw + (cw - f.width) // 2, ch - f.height))
    return out


def mg_jobs(check, man):
    made = []
    for sheet, ids in MG_SHEETS.items():
        src = os.path.join(INC, sheet)
        if not os.path.exists(src):
            continue
        a = load(src)
        for (y0, y1), cid in zip(row_bands(a, len(ids)), ids):
            ps = cells12(a[y0:y1])
            if len(ps) != 12:
                print("skip", cid, len(ps))
                continue
            grp = "characters/" + cid
            if done(man, grp, "walk_up"):
                continue
            ref = Image.open(os.path.join(GEN, man[grp]["walk_down"]["file"])).convert("RGBA")
            rh = int((np.array(ref)[..., 3] > 40).any(axis=1).sum())  # figure height in the old art
            s = rh / float(np.median([p.shape[0] for p in ps]))
            fr = [shrink(p, (max(1, round(p.shape[1] * s)), max(1, round(p.shape[0] * s)))) for p in ps]
            side, up = fr[4:8], fr[8:12]
            if faces_left(side[0], grp, man):  # the game's side strips face right (NPCs flip for left)
                side = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in side]
            cw = max(f.width for f in fr[4:]) + 2
            ch = max(f.height for f in fr[4:]) + 1
            outs = {"walk": strip(side, cw, ch), "walk_up": strip(up, cw, ch),
                    "idle_up": strip(up[:1], cw, ch), "idle_side": strip(side[:1], cw, ch)}
            for nm, im in outs.items():
                rel = "%s/%s.png" % (grp, nm)
                n = im.width // cw
                if not check:
                    dst = os.path.join(GEN, rel)
                    if os.path.exists(dst):
                        os.remove(dst)
                    im.save(dst)
                    man.setdefault(grp, {})[nm] = {"file": rel, "w": im.width, "h": im.height, "frames": n, "cell_w": cw, "cell_h": ch, "c14p6": True}
                made.append("%s %s x%d %dx%d" % (grp, nm, n, cw, ch))
    return made


# Whole-character re-renders (c14_17-19 Dark Crystal gutted by the key, c14_17-10 Elder Brine
# speckled): sheet -> (group, [(anim, frames) per row]); scaled to the old figure height.
REDRAWS = {
    "dark_crystal.png": ("enemies/dark_crystal", [("idle", 4), ("attack", 4), ("hurt", 2)], 22),  # shards join their core
    "elder_brine.png": ("characters/elder_brine", [("idle", 4), ("walk", 4), ("talk", 4), ("happy", 2), ("sad", 2)], 0),
    "elder_cinderpaw.png": ("characters/elder_cinderpaw", [("idle", 4), ("walk", 4), ("talk", 4), ("happy", 2), ("sad", 2)], 0),
    "elder_icewhisker.png": ("characters/elder_icewhisker", [("idle", 4), ("walk", 4), ("talk", 4), ("happy", 2), ("sad", 2)], 0),
    "elder_tidewhisker.png": ("characters/elder_tidewhisker", [("idle", 4), ("walk", 4), ("talk", 4), ("happy", 2), ("sad", 2)], 0),
}


def redraw_jobs(check, man):
    made = []
    for sheet, (grp, rows, join) in REDRAWS.items():
        src = os.path.join(INC, sheet)
        if not os.path.exists(src) or done(man, grp, "idle"):
            continue
        a = load(src)
        old = Image.open(os.path.join(GEN, man[grp]["idle"]["file"])).convert("RGBA")
        rh = int((np.array(old)[..., 3] > 40).any(axis=1).sum())
        bands = row_bands(a, len(rows))
        frames = {}
        for (y0, y1), (anim, n) in zip(bands, rows):
            frames[anim] = pieces(a[y0:y1], n, join) if join else cells12(a[y0:y1], n)
        s = rh / float(np.median([p.shape[0] for p in frames["idle"]]))
        sized = {k: [shrink(p, (max(1, round(p.shape[1] * s)), max(1, round(p.shape[0] * s)))) for p in v] for k, v in frames.items()}
        cw = max(f.width for v in sized.values() for f in v) + 2
        ch = max(f.height for v in sized.values() for f in v) + 1
        for anim, fr in sized.items():
            im = strip(fr, cw, ch)
            rel = "%s/%s.png" % (grp, anim)
            if not check:
                dst = os.path.join(GEN, rel)
                if os.path.exists(dst):
                    os.remove(dst)
                im.save(dst)
                man[grp][anim] = {"file": rel, "w": im.width, "h": im.height, "frames": len(fr), "cell_w": cw, "cell_h": ch, "c14p6": True}
            made.append("%s %s x%d %dx%d" % (grp, anim, len(fr), cw, ch))
    return made


# Merkitty colony kits (c14_17-20: pinholed, and walk was a byte copy of idle): 4 per sheet,
# one per row, 8 cells = idle x4 (front) + walk x4 (side hop, facing right).
KIT_SHEETS = {
    "kits_a.png": ["coral_kit_1", "coral_kit_2", "coral_kit_3", "ice_kit_1"],
    "kits_b.png": ["ice_kit_2", "ice_kit_3", "ember_kit_1", "ember_kit_2"],
    "kits_c.png": ["ember_kit_3", "kelp_kit_1", "kelp_kit_2", "kelp_kit_3"],
}


def kit_jobs(check, man):
    made = []
    for sheet, ids in KIT_SHEETS.items():
        src = os.path.join(INC, sheet)
        if not os.path.exists(src):
            continue
        a = load(src)
        for (y0, y1), cid in zip(row_bands(a, len(ids)), ids):
            grp = "characters/" + cid
            if done(man, grp, "idle"):
                continue
            ps = cells12(a[y0:y1], 8)
            old = Image.open(os.path.join(GEN, man[grp]["idle"]["file"])).convert("RGBA")
            rh = int((np.array(old)[..., 3] > 40).any(axis=1).sum())
            s = rh / float(np.median([p.shape[0] for p in ps[:4]]))
            fr = [shrink(p, (max(1, round(p.shape[1] * s)), max(1, round(p.shape[0] * s)))) for p in ps]
            cw = max(f.width for f in fr) + 2
            ch = max(f.height for f in fr) + 1
            for anim, part in (("idle", fr[:4]), ("walk", fr[4:])):
                im = strip(part, cw, ch)
                rel = "%s/%s.png" % (grp, anim)
                if not check:
                    dst = os.path.join(GEN, rel)
                    if os.path.exists(dst):
                        os.remove(dst)
                    im.save(dst)
                    man[grp][anim] = {"file": rel, "w": im.width, "h": im.height, "frames": 4, "cell_w": cw, "cell_h": ch, "c14p6": True}
                made.append("%s %s x4 %dx%d" % (grp, anim, cw, ch))
    return made


# Hero swims (c14_17-13: Bo, June, Rafe, Nia, Ollie, Marisol swam by sitting or waving):
# 3 per sheet, 5 cells = swim side x3, swim toward x1, swim away x1; figure 0.65 x idle
# height (the other heroes' ratio), bottom-aligned in the 112 px cell.
SWIM_SHEETS = {"swim_a.png": ["bo", "june", "rafe"], "swim_b.png": ["nia", "ollie", "marisol"]}


def swim_jobs(check, man):
    made = []
    for sheet, ids in SWIM_SHEETS.items():
        src = os.path.join(INC, sheet)
        if not os.path.exists(src):
            continue
        a = load(src)
        for (y0, y1), cid in zip(row_bands(a, len(ids)), ids):
            grp = "characters/" + cid
            if done(man, grp, "swim"):
                continue
            ps = cells12(a[y0:y1], 5)
            old = Image.open(os.path.join(GEN, man[grp]["idle"]["file"])).convert("RGBA")
            ih = int((np.array(old)[..., 3] > 40).any(axis=1).sum())
            s = 0.65 * ih / float(np.median([p.shape[0] for p in ps]))
            fr = [shrink(p, (max(1, round(p.shape[1] * s)), max(1, round(p.shape[0] * s)))) for p in ps]
            ch = int(man[grp]["swim"].get("cell_h", 112))
            for anim, part in (("swim", fr[:3]), ("swim_down", fr[3:4]), ("swim_up", fr[4:5])):
                cw = max(f.width for f in part) + 2
                im = strip(part, cw, ch)
                rel = "%s/%s.png" % (grp, anim)
                if not check:
                    dst = os.path.join(GEN, rel)
                    if os.path.exists(dst):
                        os.remove(dst)
                    im.save(dst)
                    man[grp][anim] = {"file": rel, "w": im.width, "h": im.height, "frames": len(part), "cell_w": cw, "cell_h": ch, "c14p6": True}
                made.append("%s %s x%d %dx%d" % (grp, anim, len(part), cw, ch))
    return made


# Merkitty sing strips (c14_17-14: upscaled mush): 3 rows x 4 frames, scaled to the old sing height.
SING_SHEET = ("merkitty_sing.png", ["merkitty_a", "merkitty_b", "merkitty_c"])


def sing_jobs(check, man):
    made = []
    src = os.path.join(INC, SING_SHEET[0])
    if not os.path.exists(src):
        return made
    a = load(src)
    for (y0, y1), cid in zip(row_bands(a, 3), SING_SHEET[1]):
        grp = "characters/" + cid
        if done(man, grp, "sing"):
            continue
        ps = cells12(a[y0:y1], 4)
        old = Image.open(os.path.join(GEN, man[grp]["idle"]["file"])).convert("RGBA")
        ih = int((np.array(old)[..., 3] > 40).any(axis=1).sum())
        s = ih / float(np.median([p.shape[0] for p in ps]))
        fr = [shrink(p, (max(1, round(p.shape[1] * s)), max(1, round(p.shape[0] * s)))) for p in ps]
        ch = max(int(man[grp]["sing"].get("cell_h", 64)), max(f.height for f in fr))
        cw = max(f.width for f in fr) + 2
        im = strip(fr, cw, ch)
        rel = grp + "/sing.png"
        if not check:
            dst = os.path.join(GEN, rel)
            if os.path.exists(dst):
                os.remove(dst)
            im.save(dst)
            man[grp]["sing"] = {"file": rel, "w": im.width, "h": im.height, "frames": 4, "cell_w": cw, "cell_h": ch, "c14p6": True}
        made.append("%s sing x4 %dx%d" % (grp, cw, ch))
    return made


FORCE = "--force" in sys.argv


def done(man, grp, anim):
    """Character jobs scale from the old art's height: never re-run on their own output."""
    return not FORCE and bool(man.get(grp, {}).get(anim, {}).get("c14p6"))


def main():
    check = "--check" in sys.argv
    man = json.load(open(MAN))
    made = []
    for sheet, group, ids, box in JOBS:
        src = os.path.join(INC, sheet)
        if not os.path.exists(src):
            print("missing", src)
            continue
        ps = pieces(load(src), len(ids))
        assert len(ps) == len(ids), (sheet, len(ps))
        for k, (name, crop) in enumerate(zip(ids, ps)):
            im = shrink(crop, box[k] if isinstance(box, list) else box)
            rel = f"{group}/{name}.png"
            if not check:
                dst = os.path.join(GEN, rel)
                if os.path.exists(dst):
                    os.remove(dst)  # art is hardlinked across worktrees: never write in place
                im.save(dst)
                man.setdefault(group, {})[name] = {"file": rel, "w": im.width, "h": im.height}
            made.append(f"{group}/{name} {im.width}x{im.height}")
    made += seamless_jobs(check)
    made += mg_jobs(check, man)
    made += redraw_jobs(check, man)
    made += kit_jobs(check, man)
    made += swim_jobs(check, man)
    made += sing_jobs(check, man)
    if not check:
        with open(MAN, "w") as f:
            json.dump(man, f, indent=1, sort_keys=True)
    print("\n".join(made))


if __name__ == "__main__":
    main()
