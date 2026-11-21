#!/usr/bin/env python3
"""C14 P1 slicer: winter looks for the lake's shore buildings (c14_02-18).

  art/incoming/c14p1/fishing_hut_winter.png -> buildings/c14p1_fishing_hut_winter (112x105, like fishing_hut)
  art/incoming/c14p1/water_mill_winter.png  -> buildings/c14p1_water_mill_winter (4-frame strip 652x200, like water_mill)

Each piece is cut to its alpha box and fitted bottom-centred into the original's
frame so doors and footprints line up. Never edits an existing art file in place.
Run: python3 tools/slice_c14p1.py
"""
import json, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INC = os.path.join(ROOT, "art", "incoming", "c14p1")
GEN = os.path.join(ROOT, "art", "gen")
MAN = os.path.join(GEN, "manifest.json")


def fit(src, w, h, box_w, box_h):
    """Alpha-crop src, scale it to fit box (box_w x box_h), paste bottom-centred in w x h."""
    a = src.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    src = src.crop(a.getbbox())
    s = min(box_w / src.width, box_h / src.height)
    src = src.resize((max(1, round(src.width * s)), max(1, round(src.height * s))), Image.LANCZOS)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(src, ((w - src.width) // 2, h - src.height))
    return out


def save(img, rel):
    p = os.path.join(GEN, rel)
    if os.path.exists(p):
        os.remove(p)  # hardlinked across worktrees: never write in place
    img.save(p)


DESPILL = ["r_orchard_17", "r_orchard_23", "r_orchard_48", "r_orchard_44"]


def despill():
    """c14_02-15: the Orchard Hills set pieces carry a dark magenta key fringe
    (e.g. 128,31,132): recolour magenta-hued pixels to a warm dark outline of the
    same brightness (pink blossoms, where red >> blue, are left alone)."""
    import numpy as np
    for n in DESPILL:
        p = os.path.join(GEN, "props", n + ".png")
        a = np.array(Image.open(p).convert("RGBA")).astype(int)
        r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
        m = (al > 0) & (abs(r - b) < 45) & (np.minimum(r, b) - g > 60)
        lum = (r + g + b) / 3.0
        a[..., 0] = np.where(m, lum * 0.78, r)
        a[..., 1] = np.where(m, lum * 0.56, g)
        a[..., 2] = np.where(m, lum * 0.42, b)
        save(Image.fromarray(a.clip(0, 255).astype("uint8"), "RGBA"), "props/%s.png" % n)
        print("despill", n, int(m.sum()))


CAPTIONED = ["ri_bone_pile", "ri_boulder4_0", "ri_boulder4_1", "ri_boulder4_2", "ri_cairn",
             "ri_dead_bush_0", "ri_dead_bush_1", "ri_eagle_nest", "ri_hot_spring2", "ri_mountain_flower",
             "ri_pine_stump", "ri_vent_0", "ri_vent_1", "ri_vent_2", "ri_vent_3"]


def uncaption(man):
    """c14_02-06: these ri_* props were sliced with the sheet's beige name plate
    ('...es (3), Cairn,') under them and slivers of their neighbours at the sides:
    cut the plate rows off the bottom and keep the widest run of columns."""
    import numpy as np
    for n in CAPTIONED:
        p = os.path.join(GEN, "props", n + ".png")
        if not os.path.exists(p) or man["props"].get(n, {}).get("uncaptioned"):
            continue  # done once already: never cut twice
        a = np.array(Image.open(p).convert("RGBA"))
        h, w = a.shape[:2]
        op = a[..., 3] > 0
        beige = op & (a[..., 0] > 195) & (a[..., 1] > 170) & (a[..., 2] > 140)
        rowb = beige.sum(axis=1)
        low = [y for y in range(h - 8, h) if rowb[y] > 0.2 * w and op[y].sum() >= w - 3]  # a full-width plate row
        if not low:
            continue  # no plate at the bottom: leave it
        cut = low[-1]
        while cut > 0 and (rowb[cut - 1] > 0.08 * w or op[cut - 1].sum() >= w - 3):
            cut -= 1  # plate rows (text rows still show beige between letters) and its border
        if cut < h * 0.5:
            continue  # that much "plate" is the prop itself (bones, hot spring rocks)
        a = a[:cut]
        rows_on = (a[..., 3] > 0).any(axis=1)
        for y in range(len(rows_on) - 1, max(0, len(rows_on) - 7), -1):
            if not rows_on[y]:
                a = a[:y]  # a detached sliver of the plate border under a gap
                break
        # thin plate-border leftovers: bottom rows much wider-but-thinner than the body
        while a.shape[0] > 4 and (a[-1, :, 3] > 0).sum() > 0 and (a[-1, :, 3] > 0).sum() < 0.15 * (a[-3, :, 3] > 0).sum():
            a = a[:-1]
        cols = (a[..., 3] > 0).any(axis=0)
        runs, start = [], None
        for x in range(w + 1):
            on = x < w and (cols[x] or (x + 1 < w and cols[x + 1] and start is not None))
            if on and start is None:
                start = x
            elif not on and start is not None:
                runs.append((start, x))
                start = None
        if a.shape[0] == 0:
            continue
        if runs:
            x0, x1 = max(runs, key=lambda r: r[1] - r[0])
            a = a[:, x0:x1]
        ys = np.where((a[..., 3] > 0).any(axis=1))[0]
        if len(ys):
            a = a[ys[0]:]
        img = Image.fromarray(a, "RGBA")
        save(img, "props/%s.png" % n)
        man["props"][n] = {"file": "props/%s.png" % n, "w": img.width, "h": img.height, "uncaptioned": True}
        print("uncaption", n, (w, h), "->", img.size)


def main():
    despill()
    man = json.load(open(MAN))
    uncaption(man)
    hut = Image.open(os.path.join(INC, "fishing_hut_winter.png")).convert("RGBA")
    save(fit(hut, 112, 105, 112, 88), "buildings/c14p1_fishing_hut_winter.png")
    man.setdefault("buildings", {})["c14p1_fishing_hut_winter"] = {"file": "buildings/c14p1_fishing_hut_winter.png", "w": 112, "h": 105}
    mill = Image.open(os.path.join(INC, "water_mill_winter.png")).convert("RGBA")
    fw = mill.width / 4.0
    strip = Image.new("RGBA", (652, 200), (0, 0, 0, 0))
    for i in range(4):
        fr = mill.crop((round(i * fw), 0, round((i + 1) * fw), mill.height))
        strip.alpha_composite(fit(fr, 163, 200, 163, 198), (163 * i, 0))
    save(strip, "buildings/c14p1_water_mill_winter.png")
    man["buildings"]["c14p1_water_mill_winter"] = {"file": "buildings/c14p1_water_mill_winter.png", "w": 652, "h": 200, "cell_w": 163, "cell_h": 200, "frames": 4}
    if os.path.exists(MAN):
        os.remove(MAN)
    with open(MAN, "w") as fh:
        json.dump(man, fh, indent=1, sort_keys=True)
    print("slice_c14p1: c14p1_fishing_hut_winter, c14p1_water_mill_winter")


if __name__ == "__main__":
    main()
