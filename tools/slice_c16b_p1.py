#!/usr/bin/env python3
"""C16b P1: the MEND and BARRAGE battle button icons (art/incoming/c16bp1/c16bp1_cmd_icons.png,
two icons on magenta, left = mend, right = barrage) -> art/gen/ui/c16bp1_mend.png and
c16bp1_barrage.png (28 px; the buttons draw them at 12 px). rm-then-write (art is hardlinked).
    python3 tools/slice_c16b_p1.py
"""
import json, os, sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "incoming", "c16bp1", "c16bp1_cmd_icons.png")
MAN = os.path.join(ROOT, "art", "gen", "manifest.json")

rgba = S.key_magenta(Image.open(SRC))
h, w = rgba.shape[0], rgba.shape[1]
man = json.load(open(MAN))
for i, name in enumerate(["c16bp1_mend", "c16bp1_barrage"]):
    half = rgba[:, i * w // 2:(i + 1) * w // 2]
    box = S.bbox(half[..., 3] > 0)
    img = S.scale_to(S.crop(half, box), width=28, height=28)
    out = os.path.join(ROOT, "art", "gen", "ui", name + ".png")
    if os.path.exists(out):
        os.remove(out)
    img.save(out)
    man.setdefault("ui", {})[name] = {"file": "ui/%s.png" % name, "w": img.width, "h": img.height}
    print("slice_c16b_p1: ui/%s %dx%d" % ((name,) + img.size))
json.dump(man, open(MAN, "w"), indent=1, ensure_ascii=False)
open(MAN, "a").write("\n")
