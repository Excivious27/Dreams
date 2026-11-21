#!/usr/bin/env python3
"""C16a P3: the stamina buff HUD icon (art/incoming/c16ap3/buff_stamina.png, one icon on
magenta) -> art/gen/ui/buff2_stamina.png (32 px wide, like the other buff2_ icons; the HUD
draws buffs at 9 px). rm-then-write (art files are hardlinked).
    python3 tools/slice_c16a_p3.py
"""
import json, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "incoming", "c16ap3", "buff_stamina.png")
MAN = os.path.join(ROOT, "art", "gen", "manifest.json")
OUT = os.path.join(ROOT, "art", "gen", "ui", "buff2_stamina.png")

rgba = S.key_magenta(Image.open(SRC))
box = S.bbox(rgba[..., 3] > 0)
img = S.scale_to(S.crop(rgba, box), width=32, height=32)
if os.path.exists(OUT):
    os.remove(OUT)
img.save(OUT)
man = json.load(open(MAN))
man.setdefault("ui", {})["buff2_stamina"] = {"file": "ui/buff2_stamina.png", "w": img.width, "h": img.height}
json.dump(man, open(MAN, "w"), indent=1, ensure_ascii=False)
open(MAN, "a").write("\n")
print("slice_c16a_p3: ui/buff2_stamina %dx%d" % img.size)
