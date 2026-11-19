#!/usr/bin/env python3
"""Re-slice the rock golem (floor 1-25 mine keeper) from art/incoming/enemies.png.

slice_art.enemies() cuts that sheet on an even 5-row grid, but the golem row
starts ~37 px above its grid cell, so every golem frame lost the top of its
head (and a few px of feet). This crops each golem cell between the sheet's
own rule lines (y 505..670), trims to the sprite, and rewrites
art/gen/enemies/golem/{idle,walk,hurt}.png plus their manifest entries.

Run after slice_art.py (idempotent). Then: godot --headless --path . --import
"""
import json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402
import slice_art as S  # noqa: E402

H = 84            # strip height (2x detail; drawn at 0.5 scale = 42 px tall)
ROW_Y = (505, 671)  # between the rule lines above and below the golem row


def main():
    rgba = S.remove_thin_lines(S.load("enemies.png"), 3)
    grid = S.cells_by_grid(rgba, 10, 5, region=(180, 68, 1774, 850), trim=False, inset=6)
    frames = []
    for b in grid[3]:
        x0, _, x1, _ = b
        sub = rgba[ROW_Y[0]:ROW_Y[1], x0:x1]
        bb = S.bbox(S.fg_mask(sub))
        if bb is None:
            frames.append(None)
            continue
        bx0, by0, bx1, by1 = bb
        frames.append(Image.fromarray(sub[by0:by1, bx0:bx1]))
    assert sum(1 for f in frames if f is not None) == 10, "golem row: expected 10 frames"
    tallest = max(f.height for f in frames)
    k = H / tallest   # one scale for every frame: no size pop between anims
    out = {}
    for name, sl in [("idle", slice(0, 4)), ("walk", slice(4, 8)), ("hurt", slice(8, 10))]:
        fs = [f.resize((max(1, round(f.width * k)), max(1, round(f.height * k))), Image.LANCZOS) for f in frames[sl]]
        cw = max(f.width for f in fs) + 2
        strip = Image.new("RGBA", (cw * len(fs), H), (0, 0, 0, 0))
        for i, f in enumerate(fs):
            a = np.asarray(f).copy()
            a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
            strip.alpha_composite(Image.fromarray(a), (i * cw + (cw - f.width) // 2, H - f.height))
        path = os.path.join(S.OUT, "enemies", "golem", name + ".png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        strip.save(path)
        out[name] = {"file": "enemies/golem/%s.png" % name, "w": strip.width, "h": H, "cell_w": cw, "cell_h": H, "frames": len(fs)}
    mp = os.path.join(S.OUT, "manifest.json")
    with open(mp) as fh:
        man = json.load(fh)
    man.setdefault("enemies/golem", {}).update(out)
    with open(mp, "w") as fh:
        json.dump(man, fh, indent=1, sort_keys=True)
    print("golem re-sliced:", {k2: (v["cell_w"], v["cell_h"]) for k2, v in out.items()})


if __name__ == "__main__":
    main()
