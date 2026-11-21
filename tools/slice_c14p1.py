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


def main():
    man = json.load(open(MAN))
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
