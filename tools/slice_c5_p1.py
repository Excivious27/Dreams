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


def bridge_dry():
    for nm in ["bridge3_ns_3", "foot3_ns_a"]:
        _dry(nm)


def _dry(nm):
    """The stone bridge with the pond patch painted into its art keyed out (it showed as a
    hard blue box round the base over the farm river): props/bridge3_ns_3_dry."""
    import numpy as np
    from PIL import Image
    from scipy import ndimage
    src = os.path.join(S.OUT, "props", nm + ".png")
    a = np.array(Image.open(src).convert("RGBA")).astype(int)
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    water = (b > r + 35) & (b > g + 5) & (al > 0)
    water = ndimage.binary_closing(water, iterations=1)
    # Dark rims round the water (outline pixels touching it) go too.
    rim = ndimage.binary_dilation(water, iterations=1) & (r + g + b < 200) & ~water
    out = a.copy()
    out[..., 3] = np.where(water | rim, 0, al)
    dst = os.path.join(S.OUT, "props", nm + "_dry.png")
    if os.path.exists(dst):
        os.remove(dst)
    S.save(Image.fromarray(out.astype(np.uint8)), "props", nm + "_dry")


STEPS = [interior, bridge_dry]

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
