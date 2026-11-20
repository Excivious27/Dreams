#!/usr/bin/env python3
"""CONDUCT 5 P3 art (art/incoming/c5p3/): winter looks and critter side walks.

  winter: buildings/house_snow, house_2_snow, house_3_snow, woodcutter_hut_snow,
          buildings/fountain_frozen, props/fountain2_frozen (1 frame, fountain2 cell),
          props/planter2_N_winter (N 0-3), nature/log_snow
          -> each fitted to its summer sprite's exact size (same footprint).
  petal:  fx/petal_pink (4-frame tumbling petal for the petals weather).
  walks:  wildlife/<raccoon|beaver|badger|otter>/walk (4-frame side walk, replaces
          the front-facing 2-frame strip), wildlife/duck/waddle (4 frames; the duck's
          walk strip stays its flight).
Run after the other slicers; then art_audit.py --fix <ids> and godot --import.
Never writes an existing art/gen file in place (rm first: hardlinks)."""
import json, os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slice_comp import blobs, rows_of

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
GEN = os.environ.get("ART_GEN") or os.path.join(ROOT, "art", "gen")
INC = os.path.join(ROOT, "art", "incoming", "c5p3")
MAN = os.path.join(GEN, "manifest.json")


def load(name):
    im = Image.open(os.path.join(INC, name)).convert("RGBA")
    a = np.array(im)
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    key = (r > 180) & (g < 90) & (b > 180)
    a[key, 3] = 0
    # Soft magenta fringe: pull pink-purple edge pixels toward their neighbours' dark outline.
    fringe = (a[..., 3] > 0) & (r - g > 90) & (b - g > 90)
    a[fringe, 3] = 0
    return a


def save(img, rel):
    p = os.path.join(GEN, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if os.path.exists(p):
        os.remove(p)
    img.save(p)


def fit(a, box, w, h):
    """Crop a piece and scale it to exactly w x h (the summer sprite's size)."""
    x0, y0, x1, y1 = box
    im = Image.fromarray(a[y0:y1, x0:x1])
    im = im.resize((w, h), Image.LANCZOS)
    arr = np.array(im)
    arr[..., 3] = np.where(arr[..., 3] > 110, 255, 0)
    return Image.fromarray(arr)


def biggest(a):
    bs = blobs(a, merge=6, min_area=400)
    return max(bs, key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))


def winter(man):
    for src, out, grp in [("house_snow.png", "house_snow", "buildings"), ("house_2_snow.png", "house_2_snow", "buildings"),
                          ("house_3_snow.png", "house_3_snow", "buildings"), ("woodcutter_hut_snow.png", "woodcutter_hut_snow", "buildings"),
                          ("log_snow.png", "log_snow", "nature")]:
        base = man[grp][out.replace("_snow", "")]
        a = load(src)
        im = fit(a, biggest(a), base["w"], base["h"])
        save(im, f"{grp}/{out}.png")
        man[grp][out] = {"file": f"{grp}/{out}.png", "w": base["w"], "h": base["h"]}
    a = load("fountain_frozen.png")
    box = biggest(a)
    fb = man["buildings"]["fountain"]
    save(fit(a, box, fb["w"], fb["h"]), "buildings/fountain_frozen.png")
    man["buildings"]["fountain_frozen"] = {"file": "buildings/fountain_frozen.png", "w": fb["w"], "h": fb["h"]}
    f2 = man["props"].get("fountain2")
    if f2:
        im = fit(a, box, f2["cell_w"], f2["cell_h"])
        save(im, "props/fountain2_frozen.png")
        man["props"]["fountain2_frozen"] = {"file": "props/fountain2_frozen.png", "w": f2["cell_w"], "h": f2["cell_h"]}
    a = load("planters_winter.png")
    bs = sorted(blobs(a, merge=6, min_area=400), key=lambda b: b[0])
    bs = sorted(bs, key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))[:4]
    bs.sort(key=lambda b: b[0])
    for i, b in enumerate(bs):
        base = man["props"][f"planter2_{i}"]
        save(fit(a, b, base["w"], base["h"]), f"props/planter2_{i}_winter.png")
        man["props"][f"planter2_{i}_winter"] = {"file": f"props/planter2_{i}_winter.png", "w": base["w"], "h": base["h"]}
    print("winter looks done")


def strip(a, boxes, height, rel):
    """Frames scaled to `height` (tallest frame), padded to one cell, feet on one line."""
    tall = max(b[3] - b[1] for b in boxes)
    s = height / tall
    frames = []
    for b in boxes:
        im = Image.fromarray(a[b[1]:b[3], b[0]:b[2]])
        im = im.resize((max(1, round((b[2] - b[0]) * s)), max(1, round((b[3] - b[1]) * s))), Image.LANCZOS)
        arr = np.array(im)
        arr[..., 3] = np.where(arr[..., 3] > 110, 255, 0)
        frames.append(Image.fromarray(arr))
    cw = max(f.width for f in frames) + 2
    ch = max(f.height for f in frames)
    out = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * cw + (cw - f.width) // 2, ch - f.height), f)
    save(out, rel)
    return {"file": rel, "w": out.width, "h": ch, "cell_w": cw, "cell_h": ch, "frames": len(frames)}


def walks(man):
    for src, kinds in [("walk_raccoon_beaver.png", ["raccoon", "beaver"]), ("walk_badger_otter.png", ["badger", "otter"]), ("walk_duck.png", ["duck"])]:
        a = load(src)
        rows = rows_of(sorted(blobs(a, merge=4, min_area=300), key=lambda b: b[1]))
        rows = [sorted(r, key=lambda b: b[0]) for r in rows if len(r) >= 3]
        assert len(rows) == len(kinds), (src, [len(r) for r in rows])
        for k, row in zip(kinds, rows):
            g = "wildlife/" + k
            idle_h = man[g]["idle"]["h"]
            name = "waddle" if k == "duck" else "walk"
            man[g][name] = strip(a, row[:4], idle_h, f"{g}/{name}.png")
            print(k, name, man[g][name])


def petal(man):
    a = load("petal_pink.png")
    row = sorted(blobs(a, merge=4, min_area=200), key=lambda b: b[0])[:4]
    info = strip(a, row, 18, "fx/petal_pink.png")
    man["fx"]["petal_pink"] = info
    print("petal_pink", info)


if __name__ == "__main__":
    man = json.load(open(MAN))
    steps = sys.argv[1:] or ["winter", "walks", "petal"]
    if "winter" in steps:
        winter(man)
    if "walks" in steps:
        walks(man)
    if "petal" in steps:
        petal(man)
    tmp = MAN + ".tmp"
    json.dump(man, open(tmp, "w"), indent=1, sort_keys=True)
    os.remove(MAN)
    os.rename(tmp, MAN)
