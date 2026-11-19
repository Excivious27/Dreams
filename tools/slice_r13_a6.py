#!/usr/bin/env python3
"""Round 13 (a6) art for the new mega regions: hub/landmark props, regional villagers,
two bosses. Sources: art/incoming/r13_a6/*.png (image tool renders).
Run: python3 tools/slice_r13_a6.py   (then tools/art_audit.py --fix and godot --import)
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import slice_art as S
from slice_comp import sheet_rows, piece, row_n, tight, rows_of
import numpy as np
from scipy import ndimage
from PIL import Image

SRC = "r13_a6/"

def pieces(file, n, merge=4, min_area=2000):
    """The n biggest pieces of a sheet, each cut out by its own pixels (a neighbour's
    lantern poking into the box stays behind), in reading order."""
    rgba = S.load(SRC + file) if not isinstance(file, np.ndarray) else file
    a = rgba[..., 3] > 40
    lab, k = ndimage.label(ndimage.binary_dilation(a, iterations=merge))
    objs = ndimage.find_objects(lab)
    sizes = ndimage.sum(a, lab, range(1, k + 1))
    keep = sorted(range(k), key=lambda i: -sizes[i])[:n]
    out = []
    for i in keep:
        sl = objs[i]
        sub = rgba[sl].copy()
        sub[..., 3] = np.where((lab[sl] == i + 1) & a[sl], sub[..., 3], 0)
        ys, xs = np.nonzero(sub[..., 3] > 40)
        sub = sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        out.append(((sl[1].start + xs.min(), sl[0].start + ys.min()), sub))
    rows = rows_of([(p[0], p[1], p[0] + im.shape[1], p[1] + im.shape[0]) for p, im in out])
    order = [b for r in rows for b in r]
    return [next(im for p, im in out if (p[0], p[1]) == (b[0], b[1])) for b in order]

def props_row(file, names, heights, nrows=1):
    ims = pieces(file, len(names))
    for im, nm, h in zip(ims, names, heights):
        img = Image.fromarray(im)
        f = h / float(img.height) if h > 0 else -h / float(img.width)
        S.save(S.scale_to(img, width=max(1, round(img.width * f)), height=max(1, round(img.height * f))), "props", nm)

def gloam():
    props_row("gloam_props.png", ["gl_mush_house_a", "gl_mush_house_b", "gl_moth_shrine", "gl_lantern_posts", "gl_thorn_rose"], [170, 190, 120, 130, 110])

def desert():
    props_row("desert_props.png", ["ds_house_a", "ds_house_b", "ds_bazaar_tent", "ds_sun_obelisk", "ds_sand_caravan"], [130, 180, 160, 180, 160])

def frost():
    props_row("frost_props.png", ["fr_lodge", "fr_cabin", "fr_hearth", "fr_sled_station", "fr_bell_tower"], [170, 120, 130, 140, 200])

def wind():
    props_row("wind_props.png", ["wi_prop_cottage", "wi_wind_shrine", "wi_mooring_tower", "wi_cloud_stall", "wi_storm_vane"], [150, 140, 210, 120, 160])

def gilt_iron():
    props_row("gilt_iron_props.png", ["gc_casino", "gc_aurum_statue", "gc_vault_door", "ir_signal_tower", "ir_coal_hopper", "ir_baron_car"],
              [-300, 160, 150, 170, 130, -270], nrows=2)

NPCS = {
    "npcs_1.png": ["mg_liesl", "mg_fenn", "mg_bramble", "mg_sefa"],
    "npcs_2.png": ["mg_rahim", "mg_nadia", "mg_hollis", "mg_dot"],
    "npcs_3.png": ["mg_skip", "mg_brannoch", "mg_ingrid", "mg_tove"],
    "npcs_4.png": ["mg_zephyr", "mg_gull", "mg_nimbus", "mg_pell"],
    "npcs_5.png": ["mg_odette", "mg_cass", "mg_aurum", "mg_coalbrook"],
}
BIG = {"mg_aurum": 56, "mg_coalbrook": 56, "mg_brannoch": 50}

def villagers():
    for file, ids in NPCS.items():
        rgba, rows = sheet_rows(SRC + file, merge=4, min_area=300)
        rows = [r for r in rows if len(r) >= 2]
        assert len(rows) == 4, (file, [len(r) for r in rows])
        for cid, row in zip(ids, rows):
            fr = [tight(rgba, b) for b in row_n(rgba, row, 4, min_gap=6)]
            h = BIG.get(cid, 48)
            hs = max(b[3] - b[1] for b in fr)
            f = h / float(hs)
            P = [piece(rgba, b, factor=f) for b in fr]
            g = "characters/" + cid
            S.strip([P[0]], g, "idle")
            S.strip([P[1], P[0], P[2], P[0]], g, "walk_down")
            S.strip([P[3]], g, "idle_side")
            S.strip([P[3], P[3]], g, "walk")
            S.strip([P[0]], g, "idle_up")
            if cid in BIG and cid != "mg_brannoch":
                S.strip([P[3], P[0]], g, "attack")
                S.strip([P[0]], g, "hurt")

def bosses():
    rgba, rows = sheet_rows(SRC + "bosses.png", merge=6, min_area=600)
    rows = [r for r in rows if len(r) >= 2]
    assert len(rows) == 2, [len(r) for r in rows]
    for name, row, h in (("storm_roc", rows[0], 120), ("rime_wyrm", rows[1], 112)):
        fr = [tight(rgba, b) for b in row_n(rgba, row, 4, min_gap=8)]
        f = h / float(max(b[3] - b[1] for b in fr))
        P = [piece(rgba, b, factor=f) for b in fr]
        g = "enemies/" + name
        S.strip([P[0], P[1]], g, "idle")
        S.strip([P[0], P[1]], g, "walk")
        S.strip([P[1], P[2], P[2]], g, "attack")
        S.strip([P[3]], g, "hurt")

def maps():
    for rid in ("gloamwood", "sunscorch", "frostpeak", "windward", "giltcity"):
        img = Image.open(os.path.join(S.INC, SRC + "map_%s.png" % rid)).convert("RGBA").resize((456, 428), Image.LANCZOS)
        S.save(img, "ui", "map_" + rid)

STEPS = [maps, gloam, desert, frost, wind, gilt_iron, villagers, bosses]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    only = sys.argv[1:]
    for fn in STEPS:
        if only and fn.__name__ not in only:
            continue
        fn(); print("ok", fn.__name__)
    data = json.dumps(S.manifest, indent=1, sort_keys=True)
    os.remove(mpath)  # hardlinked across worktrees: never write it in place
    with open(mpath, "w") as f:
        f.write(data)
