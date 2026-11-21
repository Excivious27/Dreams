#!/usr/bin/env python3
"""C14 P4 travel art: station props + ride vehicle strips -> art/gen/c14p4/ (group "c14p4").

Sheets (dreams-image renders, magenta key) in art/incoming/c14p4/:
  c14p4_stations_pen.png   6 props in a row (cart stop, ferry kiosk, balloon mast, waystone, zip pad, cloud dock)
  c14p4_shortcuts.png      5 props (cliff stairs, log bridge, ladder, hedge gap, current pool)
  c14p4_stations_gang.png  6 props (taxi stand, bus stop, subway, airstrip, dispatch board, trolley stop)
  c14p4_veh_*.png          3 rows x 3 frames each: one vehicle per row -> a 3-frame strip
Props are drawn at 0.5 scale (2x detail); TravelScene draws strips frame by frame.
Never edits a file in place (rm first: art is hardlinked across worktrees).

    python3 tools/slice_c14_p4.py
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INC = os.path.join(ROOT, "art", "incoming", "c14p4")
GEN = os.path.join(ROOT, "art", "gen")
GROUP = "c14p4"

PROPS = {
    "c14p4_stations_pen.png": [("c14p4_cart_stop", 72), ("c14p4_ferry_kiosk", 72), ("c14p4_balloon_mast", 120), ("c14p4_waystone", 64),
                               ("c14p4_zip_pad", 96), ("c14p4_cloud_dock", 64)],
    "c14p4_shortcuts.png": [("c14p4_stairs", 64), ("c14p4_log_bridge", 56), ("c14p4_ladder", 64), ("c14p4_hedge_gap", 64), ("c14p4_current_pool", 56)],
    "c14p4_stations_gang.png": [("c14p4_taxi_stand", 72), ("c14p4_bus_stop", 64), ("c14p4_subway", 72), ("c14p4_airstrip", 64),
                                ("c14p4_dispatch", 64), ("c14p4_rail_halt", 56)],
    "c14p4_pages.png": [("c14p4_page_stone", 30), ("c14p4_page_stake", 40), ("c14p4_page_bottle", 36)],
}
# Extra ids that reuse a slice (gangster cart stop = trolley stop art).
ALIAS = {"c14p4_bus_stop": [], "c14p4_rail_halt": ["c14p4_trolley_stop"]}
VEH = {
    "c14p4_veh_pen1.png": ["c14p4_veh_cart", "c14p4_veh_train", "c14p4_veh_ferry"],
    "c14p4_veh_pen2.png": ["c14p4_veh_cloud", "c14p4_veh_balloon", "c14p4_veh_bubble"],
    "c14p4_veh_gang1.png": ["c14p4_veh_taxi", "c14p4_veh_subway", "c14p4_veh_sedan"],
    "c14p4_veh_gang2.png": ["c14p4_veh_plane", "c14p4_veh_bus", "c14p4_veh_launch"],
    "c14p4_veh_mix.png": ["c14p4_veh_caravan", "c14p4_veh_trolley", "c14p4_veh_airship"],
    "c14p4_veh_mix2.png": ["c14p4_veh_sled", "c14p4_veh_ring", "c14p4_veh_night_train"],
}
VEH_H = 48  # frame height in the strip


def load(path):
    a = np.array(Image.open(path).convert("RGBA"))
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    loose = (r > 150) & (g < 120) & (b > 150) & (r - g > 70) & (b - g > 70)
    strict = (r > 215) & (b > 215) & (g < 60)
    lab, _ = ndimage.label(loose)
    hit = np.unique(lab[strict & loose])
    a[np.isin(lab, hit[hit > 0]), 3] = 0
    # Defringe: half-key pixels at the edge lose their magenta cast.
    edge = (a[..., 3] > 0) & ndimage.binary_dilation(a[..., 3] == 0, iterations=1)
    pink = edge & (r > g + 50) & (b > g + 50)
    a[pink, 3] = 0
    return a


def fit(img, h):
    f = h / img.height
    out = img.resize((max(1, round(img.width * f)), h), Image.LANCZOS)
    arr = np.array(out)
    arr[..., 3] = np.where(arr[..., 3] > 110, 255, 0)
    return Image.fromarray(arr)


def put(man, img, name):
    d = os.path.join(GEN, GROUP)
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, name + ".png")
    if os.path.exists(p):
        os.remove(p)
    img.save(p)
    man.setdefault(GROUP, {})[name] = {"file": "%s/%s.png" % (GROUP, name), "w": img.width, "h": img.height}


def main():
    man_p = os.path.join(GEN, "manifest.json")
    man = json.load(open(man_p))
    man[GROUP] = {}
    for sheet, names in PROPS.items():
        a = load(os.path.join(INC, sheet))
        m = a[..., 3] > 40
        lab, _ = ndimage.label(ndimage.binary_dilation(m, iterations=3))
        objs = [(i + 1, sl) for i, sl in enumerate(ndimage.find_objects(lab)) if sl is not None and (m[sl] & (lab[sl] == i + 1)).sum() >= 4000]
        objs.sort(key=lambda o: o[1][1].start)
        assert len(objs) == len(names), (sheet, len(objs))
        for (name, h), (li, sl) in zip(names, objs):
            piece = a[sl].copy()
            piece[lab[sl] != li, 3] = 0  # only this prop's own pixels (a neighbour's rope or sparkle stays out)
            img = fit(Image.fromarray(piece), h)
            put(man, img, name)
            for al in ALIAS.get(name, []):
                put(man, img, al)
    for sheet, names in VEH.items():
        a = load(os.path.join(INC, sheet))
        H, W = a.shape[0], a.shape[1]
        for ri, name in enumerate(names):
            row = []
            for ci in range(3):  # the renders keep a clean 3x3 grid: each cell's own content box
                y0, y1, x0, x1 = ri * H // 3, (ri + 1) * H // 3, ci * W // 3, (ci + 1) * W // 3
                cm = a[y0:y1, x0:x1, 3] > 40
                lab, n = ndimage.label(ndimage.binary_dilation(cm, iterations=6))
                assert n > 0, (sheet, name, ci)
                sizes = ndimage.sum(cm, lab, range(1, n + 1))
                keep = lab == (int(np.argmax(sizes)) + 1)  # the vehicle, not a neighbour row's tip
                a[y0:y1, x0:x1, 3] = np.where(keep, a[y0:y1, x0:x1, 3], 0)
                ys, xs = np.nonzero(cm & keep)
                assert len(ys) > 500, (sheet, name, ci)
                row.append((x0 + xs.min(), y0 + ys.min(), x0 + xs.max() + 1, y0 + ys.max() + 1))
            fw = max(b[2] - b[0] for b in row)
            fh = max(b[3] - b[1] for b in row)
            frames = []
            for b in row:
                cell = Image.new("RGBA", (fw, fh))
                cell.paste(Image.fromarray(a[b[1]:b[3], b[0]:b[2]]), ((fw - (b[2] - b[0])) // 2, fh - (b[3] - b[1])))
                frames.append(fit(cell, VEH_H))
            w = frames[0].width
            strip = Image.new("RGBA", (w * 3, VEH_H))
            for i, f in enumerate(frames):
                strip.paste(f.resize((w, VEH_H), Image.NEAREST), (i * w, 0))
            put(man, strip, name)
            man[GROUP][name].update({"frames": 3, "cell_w": w, "cell_h": VEH_H})
    # The quarry's own gravel ground (c14_12-01): 256 px, made to wrap like make_seamless does.
    g = np.asarray(Image.open(os.path.join(INC, "c14p4_quarry_gravel.png")).convert("RGBA").resize((256, 256), Image.LANCZOS)).astype(float)
    n = 256
    r = np.roll(g, (n // 2, n // 2), (0, 1))
    d = np.minimum(np.arange(n), n - 1 - np.arange(n)).astype(float)
    w1 = np.clip(d / 48, 0, 1)
    w1 = w1 * w1 * (3 - 2 * w1)
    w = np.minimum.outer(w1, w1)[..., None]
    o = (g * w + r * (1 - w)).clip(0, 255).astype(np.uint8)
    o[..., 3] = 255
    sp = os.path.join(GEN, "seamless", "c14p4_quarry_gravel.png")
    if os.path.exists(sp):
        os.remove(sp)
    Image.fromarray(o).save(sp)
    man.setdefault("seamless", {})["c14p4_quarry_gravel"] = {"file": "seamless/c14p4_quarry_gravel.png", "w": 256, "h": 256}
    tmp = man_p + ".tmp"
    with open(tmp, "w") as f:
        json.dump(man, f, indent=1, sort_keys=True)
    os.remove(man_p)
    os.rename(tmp, man_p)
    print("slice_c14_p4: %d images" % len(man[GROUP]))


if __name__ == "__main__":
    main()
