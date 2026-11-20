#!/usr/bin/env python3
"""C7 P3 story panels (dreams-image renders in art/incoming/c7/p3_cut_*.png):
gangster tower doors, the stone breaking on the steps, the Clean Break hand-over
to Inspector Hale, and Big Jim's tail (epilogue). Opaque paintings: resized to
372x248 into art/gen/ui/ (+ manifest). Run after the other slicers:
python3 tools/slice_c7_p3.py
"""
import json, os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import slice_art as S

PANELS = {"p3_cut_gang_doors.png": "cut_gang_doors", "p3_cut_gang_stone.png": "cut_gang_stone",
          "p3_cut_clean_break.png": "cut_clean_break", "p3_cut_big_jim_tail.png": "cut_big_jim_tail"}

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    man = json.load(open(mpath))
    for src, name in PANELS.items():
        p = os.path.join(S.INC, "c7", src)
        if not os.path.exists(p):
            print("missing", p); continue
        im = Image.open(p).convert("RGBA").resize((372, 248), Image.LANCZOS)
        out = os.path.join(S.OUT, "ui", name + ".png")
        if os.path.exists(out):
            os.remove(out)  # art is hardlinked: never write in place
        im.save(out)
        man.setdefault("ui", {})[name] = {"file": "ui/%s.png" % name, "w": im.width, "h": im.height}
        print("ok", name)
    with open(mpath, "w") as f:
        json.dump(man, f, indent=1)
