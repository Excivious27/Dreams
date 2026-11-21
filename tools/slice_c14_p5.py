#!/usr/bin/env python3
"""C14 P5 slicer: desert scatter, winter tufts, Glass Canyon stone head (art/incoming/c14p5/).

Cuts each sheet by connected components (magenta key or the sheet's own alpha), orders the
pieces in reading order, scales each to its target width and writes nature/c14p5_* (scatter)
or props/c14p5_* (landmarks) into art/gen + manifest.json. Never touches existing files.
Run: python3 tools/slice_c14_p5.py
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage

D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INC = os.path.join(D, "art/incoming/c14p5")
GEN = os.path.join(D, "art/gen")

# sheet -> (group, [(id, target width)...]) in reading order (rows top to bottom, left to right)
SHEETS = {
    "c14p5_desert_scatter.png": ("nature", [
        ("c14p5_desert_tuft_a", 40), ("c14p5_desert_tuft_b", 30), ("c14p5_desert_tuft_c", 40), ("c14p5_desert_log", 56),
        ("c14p5_desert_coral", 44), ("c14p5_desert_rock_flowers_a", 44), ("c14p5_desert_rock_flowers_b", 52), ("c14p5_desert_cairn", 30)]),
    "c14p5_winter_tufts.png": ("nature", [
        ("c14p5_frost_tuft_s", 30), ("c14p5_frost_tuft_m", 38), ("c14p5_frost_tuft_w", 50), ("c14p5_frost_reeds_a", 40),
        ("c14p5_frost_reeds_b", 40), ("c14p5_frost_thistle", 38), ("c14p5_snow_stone_s", 34), ("c14p5_snow_stone_m", 46)]),
    "c14p5_stone_head.png": ("props", [("c14p5_gc_stone_head", 240)]),
    "c14p5_frozen_falls.png": ("props", [("c14p5_waterfall_frozen", 160)]),
    "c14p5_hot_spring_snow.png": ("props", [("c14p5_hot_spring_snow", 104)]),
}


def load(name):
    a = np.array(Image.open(os.path.join(INC, name)).convert("RGBA"))
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    if (a[..., 3] < 10).mean() > 0.05:
        return a  # the render came back with real transparency: no magenta key (it would eat pink neon)
    loose = (r > 150) & (g < 120) & (b > 150) & (r - g > 70) & (b - g > 70)
    strict = (r > 215) & (b > 215) & (g < 60)
    lab, _ = ndimage.label(loose)
    hit = np.unique(lab[strict & loose])
    a[np.isin(lab, hit[hit > 0]), 3] = 0
    # magenta fringe: pull pinkish edge pixels toward neutral
    edge = (a[..., 3] > 0) & ndimage.binary_dilation(a[..., 3] == 0, iterations=4) & (r - g > 40) & (b - g > 30) & (b > 90)
    a[edge, 3] = 0
    a[~ndimage.binary_erosion(a[..., 3] > 0, iterations=4), 3] = 0  # drop the pink anti-alias rim
    # the drawn ground shadow picked up the magenta: near the outline, purple-tinted pixels in the
    # bottom of the sheet become a warm dark shadow (glass veins sit higher up and stay)
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    rim = ndimage.binary_dilation(a[..., 3] == 0, iterations=18) & (a[..., 3] > 0)
    rim[: int(a.shape[0] * 0.6)] = False
    if "stone_head" not in name:
        rim[:] = False
    if "hot_spring" in name:  # the steam wisps came out magenta-tinted: make them pale steam
        st = (a[..., 3] > 0) & (r - g > 40) & (b - g > 30) & (r > 150)
        a[st, 0], a[st, 1], a[st, 2] = 236, 240, 246
    pur = rim & (b - g > 20) & (r - g > 20)
    a[pur, 0], a[pur, 1], a[pur, 2] = 96, 52, 34
    return a


def pieces(a, n):
    solid = a[..., 3] > 40
    lab, k = ndimage.label(ndimage.binary_dilation(solid, iterations=10))
    boxes = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        ys, xs = sl
        area = int(solid[sl].sum())
        if area < 1500:
            continue
        boxes.append((xs.start, ys.start, xs.stop, ys.stop, area))
    boxes.sort(key=lambda b: -b[4])
    boxes = boxes[:n]
    hmed = np.median([b[3] - b[1] for b in boxes])
    boxes.sort(key=lambda b: (int(((b[1] + b[3]) / 2) // (hmed * 1.1)), b[0]))
    return boxes


# c14_06-05: night twins of the Neon/Uptown buildings (edit_image repaints of the day sprite),
# scaled to the day size, plus their window/neon glow masks <name>_lit for NightGlow. The mask is
# neon-aware (make_window_glow.py keeps only warm light; Neon's pink and cyan tubes count here).
NIGHTS = ["karaoke", "neon_hotel", "ramen_shop", "president_tower"]


def _lum(a):
    return (0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]) / 255.0


def nights(man):
    b = man.setdefault("buildings", {})
    for name in NIGHTS:
        src = os.path.join(INC, f"c14p5_night_{name}.png")
        if not os.path.exists(src):
            continue
        day = Image.open(os.path.join(GEN, "buildings", name + ".png")).convert("RGBA")
        a = load(os.path.basename(src))
        im = Image.fromarray(a)
        im = im.crop(im.getbbox())
        dbox = day.getbbox()
        dw, dh = dbox[2] - dbox[0], dbox[3] - dbox[1]
        im = im.convert("RGBa").resize((dw, dh), Image.LANCZOS).convert("RGBA")
        night = Image.new("RGBA", day.size, (0, 0, 0, 0))
        night.paste(im, (dbox[0], dbox[1]))
        na = np.array(night)
        na[..., 3] = np.where(na[..., 3] > 110, 255, 0)
        night = Image.fromarray(na)
        out = os.path.join(GEN, "buildings", name + "_night.png")
        if os.path.exists(out):
            os.remove(out)
        night.save(out)
        b[name + "_night"] = {"file": f"buildings/{name}_night.png", "w": day.width, "h": day.height}
        da = np.array(day).astype(float)
        nf = na.astype(float)
        ln, ld = _lum(nf), _lum(da)
        mx, mn = nf[..., :3].max(-1), nf[..., :3].min(-1)
        sat = (mx - mn) / np.maximum(mx, 1)
        ok = (nf[..., 3] > 128) & (da[..., 3] > 128) & (((ln > 0.42) & ((sat > 0.45) | (nf[..., 0] > 200))) | ((ln > 0.22) & (sat > 0.7))) & (ln - ld * 0.6 > 0.08)
        alpha = np.clip((ln - 0.2) / 0.3, 0, 1) * ok
        lit = np.zeros_like(na)
        lit[..., :3] = na[..., :3]
        lit[..., 3] = (alpha * 255).astype(np.uint8)
        li = Image.fromarray(lit)
        halo = ndimage.maximum_filter(lit[..., 3], size=3) // 3
        base = np.zeros_like(na)
        base[..., :3] = lit[..., :3]
        base[..., 3] = halo
        li = Image.alpha_composite(Image.fromarray(base), li)
        out = os.path.join(GEN, "buildings", name + "_lit.png")
        if os.path.exists(out):
            os.remove(out)
        li.save(out)
        b[name + "_lit"] = {"file": f"buildings/{name}_lit.png", "glow_mask": True, "w": day.width, "h": day.height}
        print("night", name, day.size, int(ok.sum()), "lit px")


def seams(man):
    """c14_06-15: Neon's wet asphalt as a true seamless ground (seamless/c14p5_wet_asphalt, 256 px)."""
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from make_seamless import seamless
    src = os.path.join(INC, "c14p5_wet_asphalt.png")
    if not os.path.exists(src):
        return
    im = Image.open(src).convert("RGB").resize((256, 256), Image.LANCZOS)
    a = seamless(np.array(im).astype(float))
    rel = "seamless/c14p5_wet_asphalt.png"
    out = os.path.join(GEN, rel)
    if os.path.exists(out):
        os.remove(out)
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(out)
    man.setdefault("seamless", {})["c14p5_wet_asphalt"] = {"file": rel, "w": 256, "h": 256}
    print(rel)


def main():
    man = json.load(open(os.path.join(GEN, "manifest.json")))
    nights(man)
    seams(man)
    for sheet, (group, ids) in SHEETS.items():
        a = load(sheet)
        for (nid, tw), (x0, y0, x1, y1, _) in zip(ids, pieces(a, len(ids))):
            im = Image.fromarray(a[y0:y1, x0:x1])
            bb = im.getbbox()
            im = im.crop(bb)
            th = max(4, round(im.height * tw / im.width))
            im = im.convert("RGBa").resize((tw, th), Image.LANCZOS).convert("RGBA")  # premultiplied: no magenta bleed
            arr = np.array(im)
            arr[..., 3] = np.where(arr[..., 3] > 110, 255, 0)
            im = Image.fromarray(arr)
            rel = f"{group}/{nid}.png"
            out = os.path.join(GEN, rel)
            if os.path.exists(out):
                os.remove(out)  # hardlinked across worktrees: rm first, never write in place
            im.save(out)
            man.setdefault(group, {})[nid] = {"file": rel, "w": im.width, "h": im.height}
            print(rel, im.size)
    with open(os.path.join(GEN, "manifest.json"), "w") as f:
        json.dump(man, f, indent=1, sort_keys=True)
        f.write("\n")


if __name__ == "__main__":
    main()
