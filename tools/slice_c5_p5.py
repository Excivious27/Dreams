#!/usr/bin/env python3
"""CONDUCT 5 fix package P5 art steps (villagers, animals, fuzzy art).

    python3 tools/slice_c5_p5.py [step ...]

Steps:
  wren_jr   art/incoming/c5/p5_wren_jr_walk_b.png -> characters/npc_wren_jr_base
            (her new-design walker: idle/idle_side/idle_up + 3 walks x4)
  rekey     magenta key residue post-pass on wildlife walks and pet anims
            (drops r>150, g<110, b>120 pixels) -- c5_09 #4
  blobs     ward_*/hq_* buildings: keep the main blob, drop stray specks/beams,
            then a hard outer rim (crispen's palette pass ate their glows) -- c5_05 #1 #2
Every write removes the old file first (art/gen is hardlinked to the main repo).
"""
import os, sys, json, glob
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
import slice_comp as C


def _rm(group, name):
    p = os.path.join(S.OUT, group, name + ".png")
    if os.path.exists(p):
        os.remove(p)


def _write(img, path):
    """Replace a (possibly hardlinked) file: write a temp file, rm, move."""
    tmp = path + ".tmp.png"
    img.save(tmp)
    if os.path.exists(path):
        os.remove(path)
    os.replace(tmp, path)


def _load_keep_alpha(name):
    """A render with its own alpha (transparent background): keep it, and key
    any magenta too."""
    src = Image.open(os.path.join(S.INC, name)).convert("RGBA")
    k = np.asarray(S.key_magenta(src)).copy()
    k[..., 3] = np.minimum(k[..., 3], np.asarray(src)[..., 3])
    k[k[..., 3] <= 40] = 0
    return k


def wren_jr():
    rgba = _load_keep_alpha("c5/p5_wren_jr_walk_b.png")
    rgba, rows = C.sheet_rows(None, merge=4, min_area=400, rgba=rgba)
    rows = [r for r in rows if len(r) >= 3]
    assert len(rows) == 4 and len(rows[0]) == 3 and all(len(r) == 4 for r in rows[1:]), [len(r) for r in rows]
    # Target: the other kid walkers (pip_winter, tobin_summer) are ~68-70 px.
    allb = [b for r in rows for b in r]
    f = 68.0 / C.med_h(allb)
    g = "characters/npc_wren_jr_base"
    flip = lambda im: im.transpose(Image.FLIP_LEFT_RIGHT)
    # (p5_wren_jr_walk.png, the first render, drew someone else: unused.)
    # Side poses face right like every walker (flip_h = left).
    def side(b):
        return C.piece(rgba, b, factor=f)
    for nm, b, fl in [("idle", rows[0][0], False), ("idle_side", rows[0][1], True), ("idle_up", rows[0][2], False)]:
        _rm(g, nm)
        im = side(b) if fl else C.piece(rgba, b, factor=f)
        S.save(im, g, nm)
        S.manifest[g][nm].update({"cell_w": im.width, "cell_h": im.height, "frames": 1})
    for nm, r, fl in [("walk", rows[1], True), ("walk_down", rows[2], False), ("walk_up", rows[3], False)]:
        _rm(g, nm)
        frames = [side(b) if fl else C.piece(rgba, b, factor=f) for b in r]
        S.strip(frames, g, nm)


BASE = ["maple", "gideon", "wren", "alder", "sal", "finn", "lumi", "theo", "hazel", "bram", "posy", "juniper", "rook", "pip", "tobin"]
# Side-row frames the render drew facing LEFT: mirrored to face right.
# key -> indices into [idle_side, walk0..3]
FLIP = {}


def base_walker(vid, flips=None):
    """art/incoming/c5/p5_walk_<vid>.png -> characters/npc_<vid>_base, scaled
    so a standing figure matches their pose sheet's standing height."""
    rgba = _load_keep_alpha("c5/p5_walk_%s.png" % vid)
    rgba, rows = C.sheet_rows(None, merge=4, min_area=400, rgba=rgba)
    rows = [r for r in rows if len(r) >= 3]
    assert len(rows) == 4 and len(rows[0]) == 3 and all(len(r) == 4 for r in rows[1:]), (vid, [len(r) for r in rows])
    pg = "characters/npc_" + vid
    hs = sorted(int(S.manifest[pg][p]["cell_h"]) for p in ("talk", "wave", "talk_2", "laugh") if p in S.manifest.get(pg, {}))
    target = hs[len(hs) // 2] if hs else 100
    f = target / C.med_h(rows[0] + rows[2])
    flips = set(FLIP.get(vid, []) if flips is None else flips)
    g = "characters/npc_%s_base" % vid
    fl = lambda im: im.transpose(Image.FLIP_LEFT_RIGHT)
    def pc(b, k=None):
        im = C.piece(rgba, b, factor=f)
        return fl(im) if k is not None and k in flips else im
    for nm, b, k in [("idle", rows[0][0], None), ("idle_side", rows[0][1], 0), ("idle_up", rows[0][2], None)]:
        _rm(g, nm)
        im = pc(b, k)
        S.save(im, g, nm)
        S.manifest[g][nm].update({"cell_w": im.width, "cell_h": im.height, "frames": 1})
    for nm, r, side in [("walk", rows[1], True), ("walk_down", rows[2], False), ("walk_up", rows[3], False)]:
        _rm(g, nm)
        S.strip([pc(b, i + 1 if side else None) for i, b in enumerate(r)], g, nm)


def bases():
    for v in (sys.argv[2:] if len(sys.argv) > 2 and sys.argv[1] == "bases" else BASE):
        base_walker(v)
        print("base", v)


PORTS = ["maple", "gideon", "wren", "alder", "finn", "hazel", "posy", "rook"]
MOODS = ["neutral", "happy", "sad", "angry", "surprised", "worried"]


def portraits():
    """c5/p5_port_<id>.png (2 rows x 3 moods, matching the new design) ->
    portraits/npc_<id>_normal/<mood>. Their seasonal portraits were a third,
    older design: they leave the manifest so Dialogue uses _normal all year
    (the files stay on disk)."""
    for v in PORTS:
        rgba = _load_keep_alpha("c5/p5_port_%s.png" % v)
        rgba, rows = C.sheet_rows(None, merge=6, min_area=2000, rgba=rgba)
        rows = [r for r in rows if len(r) >= 3]
        assert len(rows) == 2 and all(len(r) == 3 for r in rows), (v, [len(r) for r in rows])
        boxes = rows[0] + rows[1]
        g = "portraits/npc_%s_normal" % v
        old = os.path.join(S.OUT, g)
        if os.path.isdir(old):
            for fn in os.listdir(old):
                if fn.endswith(".png"):
                    os.remove(os.path.join(old, fn))
        S.manifest[g] = {}
        f = 96.0 / C.med_h(boxes)
        for mood, b in zip(MOODS, boxes):
            S.save(C.piece(rgba, b, factor=f), g, mood)
        for se in ("spring", "summer", "fall", "winter", "festival"):
            S.manifest.pop("portraits/npc_%s_%s" % (v, se), None)
        print("portraits", v)


def _stand_h(rgba, b):
    """Head-top-to-feet height of a figure, read over the columns its feet
    stand on (a raised rod or umbrella off to the side doesn't count)."""
    a = rgba[b[1]:b[3], b[0]:b[2], 3] > 40
    ys = np.nonzero(a.any(axis=1))[0]
    low = a[ys.max() - max(2, (ys.max() - ys.min()) // 12): ys.max() + 1].any(axis=0)
    xs = np.nonzero(low)[0]
    cols = a[:, xs.min(): xs.max() + 1]
    top = np.nonzero(cols.any(axis=1))[0].min()
    return ys.max() + 1 - top


# (render, sheet, [pose per figure, left to right], figure whose head-to-feet
# height is scaled to the sheet's standing height, or None = use its bbox)
POSE_FIX = [
    ("c5/p5_pose_mabel.png", "npc_mabel", ["idle"], 0),
    ("c5/p5_pose_bram_festival.png", "npc_bram_festival", ["idle_up"], 0),
    ("c5/p5_pose_juniper_winter.png", "npc_juniper_winter", ["idle_side"], 0),
]


# w490_life_poses_hats.png has 17 figures a row (an extra standing pose
# between fish and counter), which shifted every pose after "sleep" by one cell
# for Marlowe (row 1) and Benno (row 2) in slice_world5.life_sheet.
W490_X = [60, 151, 240, 320, 411, 498, 578, 666, 760, 848, 935, 1022, 1116, 1211, 1290, 1388, 1472]
W490_POSE = ["work", "work_2", "sit", "talk", "talk_2", "laugh", "wave", "sleep", "carry", "eat", "dance", "dance_2",
             "umbrella", "shiver", "fish", None, "counter"]


def w490_fix():
    """Reslice Marlowe's and Benno's life poses from w490 by figure slots
    (cuts halfway between figure centres; touching figures are split there).
    The fisher's slot also takes the extra figure's slot (his rod reaches
    over it) minus that figure's own body."""
    rgba = S.load("w490_life_poses_hats.png")
    X = W490_X
    cuts = [0] + [(X[i] + X[i + 1]) // 2 for i in range(len(X) - 1)] + [rgba.shape[1]]
    for who, (y0, y1) in [("marlowe", (150, 400)), ("benno", (540, 790))]:
        band = rgba[y0:y1]
        pieces = {}
        for k, pose in enumerate(W490_POSE):
            if pose is None:
                continue
            x0, x1 = cuts[k], cuts[k + 2] if pose == "fish" else cuts[k + 1]
            sub = band[:, x0:x1].copy()
            m = sub[..., 3] > 40
            lab, n = ndimage.label(m)
            if n:
                sizes = ndimage.sum(m, lab, range(1, n + 1))
                cms = ndimage.center_of_mass(m, lab, range(1, n + 1))
                big = int(np.argmax(sizes))
                for i in range(n):
                    far = pose == "fish" and cms[i][1] + x0 > cuts[k + 1] and sizes[i] > 1500
                    tiny_edge = sizes[i] < 0.03 * sizes[big]
                    if far or (tiny_edge and i != big):
                        sub[lab == i + 1] = 0
            if not (sub[..., 3] > 40).any():  # fisher and the extra figure touch: plain slot
                sub = band[:, cuts[k]:cuts[k + 1]].copy()
            ys, xs = np.nonzero(sub[..., 3] > 40)
            pieces[pose] = Image.fromarray(sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
        stand = sorted(pieces[p].height for p in ("talk", "talk_2", "wave"))
        f = 100.0 / stand[1]
        g = "characters/npc_" + who
        for pose, im in pieces.items():
            im = S.scale_to(im, width=max(1, round(im.width * f)), height=max(1, round(im.height * f)))
            _rm(g, pose)
            S.save(im, g, pose)
            S.manifest[g][pose].update({"cell_w": im.width, "cell_h": im.height, "frames": 1})
        print("w490", who, len(pieces))


def sheep():
    """sheep_woolly redrawn with whole legs (c5_09 #8): idle 4, walk 5, eat 2;
    baby = the idle (the farm scales babies down)."""
    rgba = _load_keep_alpha("c5/p5_sheep_woolly.png")
    rgba, rows = C.sheet_rows(None, merge=4, min_area=1500, rgba=rgba)
    rows = [r for r in rows if len(r) >= 2]
    assert [len(r) for r in rows] == [4, 5, 2], [len(r) for r in rows]
    g = "animals/sheep_woolly"
    f = 36.0 / C.med_h(rows[0] + rows[1])
    for nm, r in [("idle", rows[0]), ("walk", rows[1]), ("eat", rows[2]), ("baby", rows[0])]:
        _rm(g, nm)
        S.strip([C.piece(rgba, b, factor=f) for b in r], g, nm)
    print("sheep_woolly")


def _line_px(a):
    """Pink (magenta rule) or bright-green (sheet grid) pixels."""
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    op = a[..., 3] > 0
    return op & (((r - g > 50) & (b - g > 30)) | ((g - r > 35) & (g - b > 25)))


def tile_lines(pattern=("path2_cobble*", "path_cobble*")):
    """Town plaza grid lines (c5_05 #5): the cobble path tiles carry pink and
    green sheet-rule pixels in their 3-px border; paint them over with their
    clean neighbours' colour (the stones have no pink or bright green)."""
    n_files = 0
    for pat in pattern:
        for path in sorted(glob.glob(os.path.join(S.OUT, "tiles", pat + ".png"))):
            a = np.asarray(Image.open(path).convert("RGBA")).copy()
            bad = _line_px(a)
            edge = np.zeros(bad.shape, bool)
            edge[:3] = edge[-3:] = True
            edge[:, :3] = edge[:, -3:] = True
            bad &= edge
            if not bad.any():
                continue
            good = (a[..., 3] > 0) & ~_line_px(a)
            for _ in range(6):
                if not bad.any():
                    break
                acc = np.zeros(a.shape[:2] + (3,), float)
                cnt = np.zeros(a.shape[:2], float)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if dy == 0 and dx == 0:
                            continue
                        sh = np.roll(np.roll(a[..., :3].astype(float), dy, 0), dx, 1)
                        gm = np.roll(np.roll(good, dy, 0), dx, 1)
                        acc += sh * gm[..., None]
                        cnt += gm
                fill = bad & (cnt > 0)
                a[..., :3][fill] = (acc[fill] / cnt[fill][:, None]).astype(np.uint8)
                good |= fill
                bad &= ~fill
            _write(Image.fromarray(a), path)
            n_files += 1
    print("tile lines cleaned in", n_files, "tiles")


def poses():
    """Redraws of the cells Npc.BAD_CELLS used to hide (c5_08 #2)."""
    for src, sheet, names, ref in POSE_FIX:
        rgba = _load_keep_alpha(src)
        rgba, rows = C.sheet_rows(None, merge=6, min_area=3000, rgba=rgba)
        boxes = sorted([b for r in rows for b in r], key=lambda b: b[0])
        assert len(boxes) == len(names), (src, len(boxes))
        g = "characters/" + sheet
        m = S.manifest[g]
        stand = [int(m[p]["cell_h"]) for p in ("talk", "wave", "talk_2", "idle", "walk_down") if p in m and p not in names]
        stand.sort()
        target = stand[len(stand) // 2]
        f = target / float(_stand_h(rgba, boxes[ref]))
        for nm, b in zip(names, boxes):
            _rm(g, nm)
            im = C.piece(rgba, b, factor=f)
            S.save(im, g, nm)
            S.manifest[g][nm].update({"cell_w": im.width, "cell_h": im.height, "frames": 1})
        print("poses", sheet, names, "target", target)


def _rekey_arr(a):
    """Leftover magenta key under the feet: pixels in the bottom band of a
    frame whose hue sits near magenta (red and blue well above green, blue
    not far under red). Hot-pink bows (mid-frame) and pink noses stay."""
    r, gg, b, al = [a[..., i].astype(int) for i in range(4)]
    bad = (al > 0) & (r - gg > 35) & (b - gg > 25) & (b > 0.55 * r)
    h = a.shape[0]
    bad[: int(h * 0.78)] = False
    return bad


def _rekey_fix(a, bad):
    """Recolour key residue as a soft brown ground shadow (keeps the shape the
    artist meant as the shadow; no pink)."""
    a = a.copy()
    lum = (0.3 * a[..., 0] + 0.45 * a[..., 1] + 0.25 * a[..., 2]).astype(int)
    lum = np.clip(lum, 20, 120)
    a[..., 0] = np.where(bad, lum * 0.95, a[..., 0])
    a[..., 1] = np.where(bad, lum * 0.78, a[..., 1])
    a[..., 2] = np.where(bad, lum * 0.62, a[..., 2])
    return a


REKEY = {
    "wildlife": ["boar", "otter", "rabbit", "mouse", "crab", "raccoon", "badger", "beaver", "hedgehog", "snake", "goat"],
    "animals": ["cat_grey", "dog_corgi", "dog_white", "pup", "goat", "goat2", "goat_kid", "kid_goat", "sheep_woolly"],
}


def rekey(report=False):
    total = 0
    for group, names in REKEY.items():
        for nm in names:
            for path in sorted(glob.glob(os.path.join(S.OUT, group, nm, "*.png"))):
                im = Image.open(path).convert("RGBA")
                a = np.asarray(im).copy()
                bad = _rekey_arr(a)
                n = int(bad.sum())
                if not n:
                    continue
                total += n
                print(f"  {group}/{nm}/{os.path.basename(path)}: {n}")
                if not report:
                    _write(Image.fromarray(_rekey_fix(a, bad).astype(np.uint8)), path)
    print("rekey pixels", total)


def _keep_main(a):
    """Drop stray islands: specks (< 1.5% of the main piece), a cut-off
    neighbour touching the left/right edge (< 20%), and anything floating
    wholly below the main piece (a beam that fell off the art). Then the
    caller trims the empty bottom rows."""
    m = a[..., 3] > 100
    lab, n = ndimage.label(m)
    if n <= 1:
        return a, 0
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    objs = ndimage.find_objects(lab)
    big = int(np.argmax(sizes))
    main_bottom = objs[big][0].stop
    w = a.shape[1]
    drop = []
    for i, sl in enumerate(objs):
        if i == big:
            continue
        s = sizes[i] / sizes[big]
        at_edge = sl[1].start == 0 or sl[1].stop >= w
        if s < 0.015 or (at_edge and s < 0.2) or sl[0].start >= main_bottom - 4:
            drop.append(i + 1)
    gone = np.isin(lab, drop)
    # take the soft fringe around dropped islands too
    gone = ndimage.binary_dilation(gone, iterations=2) & ~ndimage.binary_dilation(m & ~gone, iterations=1)
    a = a.copy()
    dropped = int((gone & (a[..., 3] > 0)).sum())
    a[gone] = 0
    return a, dropped


def _hard_rim(a, depth=2):
    """Half-transparent pixels within `depth` px of the outside go fully
    opaque or fully clear; inner translucency (beams, glass) stays."""
    a = a.copy()
    al = a[..., 3]
    outside = al < 20
    near = ndimage.binary_dilation(outside, iterations=depth) & ~outside
    soft = near & (al < 255)
    a[..., 3] = np.where(soft, np.where(al >= 120, 255, 0), al)
    a[a[..., 3] == 0] = 0
    return a


def blobs(names=None):
    names = names or [f"{p}_{i}" for p in ("ward", "hq") for i in range(1, 7)]
    for nm in names:
        for group in ("buildings", "props"):
            info = S.manifest.get(group, {}).get(nm)
            if not info:
                continue
            path = os.path.join(S.OUT, info["file"])
            a = np.asarray(Image.open(path).convert("RGBA"))
            a2, dropped = _keep_main(a)
            # A floating piece below the art had stretched the canvas down (the
            # building stood high above its feet): cut empty rows off the bottom
            # only, so the width and the x anchor stay.
            a2 = _hard_rim(a2)
            a2[a2[..., 3] < 20] = 0
            rows = np.nonzero((a2[..., 3] > 0).any(axis=1))[0]
            if len(rows) and rows[-1] < a2.shape[0] - 1:
                a2 = a2[: rows[-1] + 1]
            im = Image.fromarray(a2)
            _write(im, path)
            info["w"], info["h"] = im.width, im.height
            print(group, nm, "dropped", dropped, "size", im.size)


STEPS = [wren_jr, rekey, blobs, bases, portraits, poses, w490_fix, sheep, tile_lines]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    only = sys.argv[1:2] if sys.argv[1:2] == ["bases"] else sys.argv[1:]
    for fn in STEPS:
        if only and fn.__name__ not in only:
            continue
        fn(); print("ok", fn.__name__)
    tmp = mpath + ".tmp"
    with open(tmp, "w") as f:
        json.dump(S.manifest, f, indent=1, sort_keys=True)
    if os.path.exists(mpath):
        os.remove(mpath)
    os.replace(tmp, mpath)
