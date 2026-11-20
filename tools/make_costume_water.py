#!/usr/bin/env python3
"""Water rows for the six arc costumes (C10b P5, c10b_11-18).

The arc costumes (outfit_pinstripe/vest/armored/parka/crystal_parka/starlight) were
drawn without _water sheets, so swimming fell back to the walk poses: the hero walked
on the water. This composes body/outfit_<k>_water (+ _water_skin) from the costume's
own walk/idle frames: the figure sinks to the shoulders, everything under the
waterline is cut, and the ripple/foam of the matching outfit_farmer_water cell
(blue and white pixels only, scaled to the costume's pixel size) goes on top.
Cell order = PaperDoll.WATER: swim side 1-4, down 1-4, up 1-4, float, dive, climb out x2.
Anchors are the full figure's (shifted down), so doll hair pins on the head.
Run after the other slicers; then `godot --headless --import`.
"""
import json, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "art", "gen")
COSTUMES = ["outfit_pinstripe", "outfit_vest", "outfit_armored", "outfit_parka", "outfit_crystal_parka", "outfit_starlight"]
# water cell -> (base pose, sink share of cell height, waterline share; None = no cut)
CELLS = [(3, .20, .74), (4, .20, .74), (5, .20, .74), (6, .20, .74),
         (7, .22, .72), (8, .22, .72), (9, .22, .72), (8, .22, .72),
         (11, .22, .72), (12, .22, .72), (13, .22, .72), (14, .22, .72),
         (0, .24, .72), (0, .46, .80), (3, .10, .84), (0, .0, None)]
REF = "outfit_farmer_water"


def ripple(ref, i, rw, rh, W, H):
    cell = ref.crop((i * rw, 0, (i + 1) * rw, rh))
    px = cell.load()
    out = Image.new("RGBA", cell.size, (0, 0, 0, 0))
    po = out.load()
    for y in range(int(rh * 0.66), rh):
        for x in range(rw):
            r, g, b, a = px[x, y]
            if a > 60 and ((b > r + 25 and b > 160 and g > 110) or (r > 205 and g > 205 and b > 205)):
                po[x, y] = (r, g, b, a)
    return out.resize((W, H), Image.LANCZOS)


def used(cell):
    bb = cell.getbbox()
    return bb if bb else (0, 0, cell.size[0], cell.size[1])


def main():
    mpath = os.path.join(GEN, "manifest.json")
    man = json.load(open(mpath))
    body = man["body"]
    ri = body[REF]
    ref = Image.open(os.path.join(GEN, ri["file"])).convert("RGBA")
    rw, rh = ri["cell_w"], ri["cell_h"]
    for k in COSTUMES:
        bi = body[k]
        cw, ch = bi["cell_w"], bi["cell_h"]
        sheet = Image.open(os.path.join(GEN, bi["file"])).convert("RGBA")
        skin_p = os.path.join(GEN, "body", k + "_skin.png")
        skin = Image.open(skin_p).convert("RGBA") if os.path.exists(skin_p) else None
        W, H = round(rw * ch / rh), ch
        out = Image.new("RGBA", (W * 16, H), (0, 0, 0, 0))
        out_s = Image.new("RGBA", (W * 16, H), (0, 0, 0, 0)) if skin else None
        anchors = []
        for i, (pose, sink, line) in enumerate(CELLS):
            src = sheet.crop((pose * cw, 0, (pose + 1) * cw, ch))
            l, t, r, b = used(src)
            dx = (W - cw) // 2
            dy = round(sink * H)
            for img, dst in ([(src, out)] + ([(skin.crop((pose * cw, 0, (pose + 1) * cw, ch)), out_s)] if skin else [])):
                lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                lay.paste(img, (dx, dy), img)
                if line is not None:
                    cut = round(line * H)
                    lay.paste((0, 0, 0, 0), (0, cut, W, H))
                if dst is out and line is not None:
                    rp = ripple(ref, i, rw, rh, W, H)
                    lay.alpha_composite(rp)
                dst.paste(lay, (i * W, 0), lay)
            hh = (b - t) * 96.0 / 92.0
            anchors.append([dx + (l + r) / 2.0, dy + b - hh, float(dy + b), float(r - l), hh])
        name = k + "_water"
        for nm, img in [(name, out)] + ([(name + "_skin", out_s)] if skin else []):
            p = os.path.join(GEN, "body", nm + ".png")
            if os.path.exists(p):
                os.remove(p)  # never write through a hardlink
            img.save(p)
        body[name] = {"file": "body/%s.png" % name, "cell_w": W, "cell_h": H, "frames": 16, "w": W * 16, "h": H, "anchors": anchors}
        if skin:
            body[name + "_skin"] = {"file": "body/%s_skin.png" % name, "w": W * 16, "h": H, "mask": True}
        print(name, W, H)
    tmp = mpath + ".tmp"
    with open(tmp, "w") as f:
        json.dump(man, f, indent=1, sort_keys=True)
    os.remove(mpath)
    os.rename(tmp, mpath)


if __name__ == "__main__":
    main()
