#!/usr/bin/env python3
"""C5 P1 house-interior pieces (art/incoming/c5/p1_house_interior.png, image tool render):
cellar hatch (closed / open) and a study desk -> art/gen/furniture/. Rm-before-write."""
import os, sys, json
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
import slice_comp as C


def interior():
    import numpy as np
    from PIL import Image
    raw = np.array(Image.open(os.path.join(S.INC, "c5/p1_house_interior.png")).convert("RGBA"))
    keyed = C.load("c5/p1_house_interior.png")  # magenta key; the render's own alpha wins where it has one
    keyed[..., 3] = np.minimum(keyed[..., 3], raw[..., 3])
    rgba = keyed
    boxes = sorted([b for b in C.blobs(rgba, merge=8, min_area=4000)], key=lambda b: b[0])
    assert len(boxes) == 3, boxes
    for b, name, kw in [(boxes[0], "cellar_hatch", {"w": 64}), (boxes[1], "cellar_hatch_open", {"w": 64}),
                        (boxes[2], "study_desk", {"h": 128})]:
        p = os.path.join(S.OUT, "furniture", name + ".png")
        if os.path.exists(p):
            os.remove(p)
        C.save_piece(rgba, b, "furniture", name, **kw)
        print(name, b)


STEPS = [interior]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    for fn in STEPS:
        fn(); print("ok", fn.__name__)
    data = json.dumps(S.manifest, indent=1, sort_keys=True)
    os.remove(mpath)
    with open(mpath, "w") as fh:
        fh.write(data)
