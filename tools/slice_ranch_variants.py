#!/usr/bin/env python3
"""CONDUCT 11b P2 art: Harvest Fair show ribbons/trophy and rare ranch variant strips.

    python3 tools/slice_ranch_variants.py [ribbons] [variants]

Renders (art/incoming/c11b/):
  p2_show_ribbons.png  one row: blue, red, yellow show rosettes (wall plaques) and the gold Best in Show trophy
                       -> props/show_ribbon_blue|red|yellow, props/show_trophy
  p2_rare_*.png        rare variant sheets (when rendered): rows idle(4) walk(4) and a baby row
                       -> animals/<species>_<variant>/{idle,walk,baby}
Then: tools/art_audit.py --fix <ids>, tools/set_import_lossy.py, godot --import.
Hardlinked art: every file is removed before it is written (never overwritten in place).
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_comp import blobs, rows_of, tight, piece
import numpy as np
from PIL import Image

SRC = "c11b/"


def _rm(group, name):
    p = os.path.join(S.OUT, group, name + ".png")
    if os.path.exists(p):
        os.remove(p)


def save(img, group, name):
    _rm(group, name)
    return S.save(img, group, name)


def rgba_of(file):
    src = Image.open(os.path.join(S.INC, SRC + file)).convert("RGBA")
    a = S.key_magenta(src)
    a = np.asarray(a).copy() if not isinstance(a, np.ndarray) else a
    sa = np.asarray(src)[..., 3]
    a[..., 3] = np.minimum(a[..., 3], sa)
    return a


# name, target width in art px (2x detail: 32 = one 16-px cell)
RIBBONS = [("show_ribbon_blue", 20), ("show_ribbon_red", 20), ("show_ribbon_yellow", 20), ("show_trophy", 26)]


def ribbons():
    f = "p2_show_ribbons.png"
    if not os.path.exists(os.path.join(S.INC, SRC + f)):
        print("skip ribbons: no render"); return
    a = rgba_of(f)
    bx = blobs(a, merge=14, min_area=1500)
    row = max(rows_of(bx), key=lambda r: len(r))
    row = sorted(sorted(row, key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))[:4], key=lambda b: b[0])
    assert len(row) == 4, len(row)
    for (name, w), b in zip(RIBBONS, row):
        save(piece(a, tight(a, b), w=w), "props", name)


# Rare looks (c11b_11-01): their own strips, recoloured from the common strip by luminance so a white
# llama really is paler than cream and a snow duck is white (a modulate multiply can only darken).
# species, variant, base group, target RGB, mode: "colour" (re-hue, keep shading) | "pale" (lift to white) |
# "dark" (deep coat). Outlines (very dark pixels) and tiny bright eyes keep their colour.
RARES = [
    ("chicken", "golden", "chicken2", (242, 190, 70), "colour"),
    ("duck", "snow", "duck2", (236, 242, 250), "pale"),
    ("cow", "highland", "cow_brown", (200, 110, 50), "colour"),
    ("sheep", "black", "sheep_woolly", (70, 64, 80), "dark"),
    ("goat", "chocolate", "goat2", (122, 74, 46), "colour"),
    ("llama", "white", "llama", (248, 246, 242), "pale"),
    ("pig", "ginger", "pig_a", (214, 116, 60), "colour"),
    ("rabbit", "silver", "rabbit_white", (176, 184, 204), "colour"),
]
RARE_JSON = os.path.join(S.OUT, "animals", "_ranch_art_rare.json")


def _recolour(img, rgb, mode):
    a = np.asarray(img.convert("RGBA")).astype(np.float32)
    c = a[..., :3]
    lum = (0.299 * c[..., 0] + 0.587 * c[..., 1] + 0.114 * c[..., 2]) / 255.0
    body = (a[..., 3] > 20) & (lum > 0.16)
    t = np.array(rgb, dtype=np.float32)
    if mode == "pale":
        sh = 0.55 + 0.45 * np.clip(lum / max(1e-3, float(np.percentile(lum[body], 90)) if body.any() else 1.0), 0, 1)
        new = t[None, None, :] * sh[..., None]
    elif mode == "dark":
        new = t[None, None, :] * (0.55 + 0.9 * lum[..., None])
    else:
        ref = float(np.percentile(lum[body], 70)) if body.any() else 0.6
        new = t[None, None, :] * np.clip(lum / max(1e-3, ref), 0.25, 1.35)[..., None]
    out = a.copy()
    out[..., :3] = np.where(body[..., None], np.clip(new, 0, 255), c)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def variants():
    man = S.manifest
    table = {}
    for sid, vid, base, rgb, mode in RARES:
        src = man.get("animals/" + base, {})
        name = "%s_%s" % (sid, vid)
        g = "animals/" + name
        if "idle" in man.get(g, {}) and not os.path.exists(os.path.join(S.OUT, "animals", name, ".p2_recolour")):
            table.setdefault(sid, {"variants": []})["variants"].append({"id": vid, "art": name})  # a real render exists
            print("  %s: existing art" % name)
            continue
        got = []
        for strip in ("idle", "walk", "eat", "baby", "sleep"):
            if strip not in src:
                continue
            fp = os.path.join(S.OUT, "animals", base, strip + ".png")
            if not os.path.exists(fp):
                continue
            img = _recolour(Image.open(fp), rgb, mode)
            d = os.path.join(S.OUT, "animals", name)
            os.makedirs(d, exist_ok=True)
            out = os.path.join(d, strip + ".png")
            if os.path.exists(out):
                os.remove(out)
            img.save(out)
            ent = dict(src[strip])
            ent["file"] = "animals/%s/%s.png" % (name, strip)
            man.setdefault(g, {})[strip] = ent
            got.append(strip)
        open(os.path.join(S.OUT, "animals", name, ".p2_recolour"), "w").close()  # ours: safe to re-cut
        row = {"id": vid, "art": name}
        if "baby" in got:
            row["baby"] = [name, "baby"]
        table.setdefault(sid, {"variants": []})["variants"].append(row)
        print("  %s: %s" % (name, ",".join(got)))
    if os.path.exists(RARE_JSON):
        os.remove(RARE_JSON)
    with open(RARE_JSON, "w") as fh:
        json.dump(table, fh, indent=1, sort_keys=True)


STEPS = [ribbons, variants]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    only = sys.argv[1:]
    for fn in STEPS:
        if only and fn.__name__ not in only:
            continue
        fn(); print("ok", fn.__name__)
    data = json.dumps(S.manifest, indent=1, sort_keys=True)
    os.remove(mpath)
    with open(mpath, "w") as fh:
        fh.write(data)
