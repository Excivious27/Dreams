#!/usr/bin/env python3
"""Skin masks for the paper-doll outfit sheets (C10a P5, c10_04): the costume sheets
paint one tan skin, so the creator's light/dark skin never showed. For every
body/outfit_* sheet (+ _act/_life/_water/_ride) this writes body/<sheet>_skin.png:
alpha 255 where a pixel is skin. Skin = pixels in the painted tan band (hue 4-40 deg,
sat 0.22-0.72, value > 0.48) in 8-connected blobs that touch the head (top 42% of the
figure) - face, ears, neck - plus small blobs (hands, <= 2.2% of the figure) below.
Armour sheets (helmets, leather in the same hue) get no mask: their faces stay as drawn.
shaders/doll_body.gdshader recolours the masked pixels (PaperDoll.skin_tone).
Run after the slicers; rm-before-write (art/gen is hardlinked)."""
import colorsys, json, os, sys
import numpy as np
from scipy import ndimage
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S

ROWS = ["", "_act", "_life", "_water", "_ride"]


def band(rgb):
    a = rgb.astype(float) / 255.0
    mx, mn = a.max(-1), a.min(-1)
    v = mx
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    d = np.maximum(mx - mn, 1e-6)
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    return (h >= 4) & (h <= 40) & (s >= 0.22) & (s <= 0.72) & (v > 0.48) & (r > g) & (g > b)


def mask_cell(cell):
    alpha = cell[..., 3] > 128
    out = np.zeros(alpha.shape, bool)
    if not alpha.any():
        return out
    ys, xs = np.nonzero(alpha)
    top, bot = ys.min(), ys.max()
    head_y = top + int((bot - top) * 0.42)
    m = band(cell[..., :3]) & alpha
    # Narrow to this cell's own skin palette: colours of the bald scalp (top 18%).
    scalp = m.copy()
    scalp[top + int((bot - top) * 0.18):] = False
    if scalp.sum() >= 6:
        pal = np.unique(cell[..., :3][scalp].astype(int) // 6, axis=0)
        q = cell[..., :3].astype(int) // 6
        near = np.zeros(m.shape, bool)
        for c in pal:
            near |= (np.abs(q - c).max(-1) <= 1)
        m &= near
    lab, n = ndimage.label(m, structure=np.ones((3, 3)))
    total = alpha.sum()
    for i in range(1, n + 1):
        comp = lab == i
        cy = np.nonzero(comp)[0]
        if cy.min() <= head_y or comp.sum() <= 0.022 * total:
            out |= comp
    return out


def main():
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    body = S.manifest.get("body", {})
    done = 0
    for name in sorted(body):
        if not name.startswith("outfit_") or name.endswith("_skin"):
            continue
        info = body[name]
        im = np.asarray(Image.open(os.path.join(S.OUT, info["file"])).convert("RGBA"))
        cw, ch = int(info.get("cell_w", im.shape[1])), int(info.get("cell_h", im.shape[0]))
        out = np.zeros(im.shape[:2], bool)
        for x in range(0, im.shape[1] - cw + 1, cw):
            out[:ch, x:x + cw] = mask_cell(im[:ch, x:x + cw])
        a = np.zeros(im.shape, np.uint8)
        a[out] = (255, 255, 255, 255)
        p = os.path.join(S.OUT, "body", name + "_skin.png")
        if os.path.exists(p):
            os.remove(p)
        Image.fromarray(a).save(p)
        body[name + "_skin"] = {"file": "body/%s_skin.png" % name, "w": im.shape[1], "h": im.shape[0], "mask": True}
        done += 1
    data = json.dumps(S.manifest, indent=1, sort_keys=True)
    os.remove(mpath)
    with open(mpath, "w") as f:
        f.write(data)
    print("skin masks: %d sheets" % done)


if __name__ == "__main__":
    main()
