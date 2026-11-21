#!/usr/bin/env python3
"""C15 P1 calendar art (art/incoming/c15p1/*.png, magenta key) -> art/gen/ui/:
  calendar_icons.png      -> c15p1_ic_<name> (16 icons, 8x2 grid, 32x32)
  calendar_panel_pen.png  -> c15p1_cal_frame_pen (9-patch frame, interior filled with the board
                             colour; manifest "patch" = margin px), c15p1_cell_pen
  calendar_panel_gang.png -> c15p1_cal_frame_gang, c15p1_cell_gang
Only edge-connected magenta is keyed (the gang board's magenta neon trim stays).
rm-then-write (art files are hardlinked).   python3 tools/slice_c15_p1.py [check]
"""
import json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INC = os.path.join(ROOT, "art", "incoming", "c15p1")
MAN = os.path.join(ROOT, "art", "gen", "manifest.json")
ICONS = ["egg", "lantern", "wheat", "star", "cake", "fish", "boat", "flower",
         "firework", "snow", "pumpkin", "kite", "moon", "market", "music", "face"]
# Measured on the renders (1024 px): frame bbox margins (l, t, r, b) in source px, a day cell
# and a header tab box (x0, y0, x1, y1), and the screen width the frame is scaled to.
PANELS = {
    "pen": {"src": "calendar_panel_pen.png", "margin": (50, 66, 50, 66), "cell": (195, 400, 312, 553), "tab": (197, 149, 315, 203)},
    "gang": {"src": "calendar_panel_gang.png", "margin": (40, 46, 40, 56), "cell": (197, 391, 312, 540), "tab": (197, 133, 312, 195)},
}
FRAME_W = 262
IDS = ["c15p1_ic_" + n for n in ICONS] + ["c15p1_%s_%s" % (k, a) for a in PANELS for k in ("cal_frame", "cell")]


def _rm(nid):
    p = os.path.join(ROOT, "art", "gen", "ui", nid + ".png")
    if os.path.exists(p):
        os.remove(p)


def key_edge(path):
    """Magenta key, but only the background connected to the image border."""
    rgba = S.key_magenta(Image.open(path))
    clear = rgba[..., 3] < 128
    lab, _ = ndimage.label(clear)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    src = np.asarray(Image.open(path).convert("RGBA")).copy()
    out = rgba.copy()
    keep = ~bg & (rgba[..., 3] < 255)
    out[keep] = src[keep]
    out[..., 3] = np.where(keep, 255, out[..., 3])
    return out


def bbox(rgba):
    ys, xs = np.nonzero(rgba[..., 3] > 40)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def save(img, nid, extra=None):
    _rm(nid)
    S.save(img, "ui", nid)
    if extra:
        S.manifest["ui"][nid].update(extra)


def icons():
    rgba = S.key_magenta(Image.open(os.path.join(INC, "calendar_icons.png")))
    h, w = rgba.shape[:2]
    for i, n in enumerate(ICONS):
        cx, cy = i % 8, i // 8
        cell = rgba[cy * h // 2:(cy + 1) * h // 2, cx * w // 8:(cx + 1) * w // 8]
        x0, y0, x1, y1 = bbox(cell)
        piece = Image.fromarray(cell[y0:y1, x0:x1])
        side = max(piece.width, piece.height)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(piece, ((side - piece.width) // 2, (side - piece.height) // 2))
        save(S.scale_to(sq, 32, 32), "c15p1_ic_" + n)


def panel(arc, p):
    rgba = key_edge(os.path.join(INC, p["src"]))
    x0, y0, x1, y1 = bbox(rgba)
    l, t, r, b = p["margin"]
    fr = rgba[y0:y1, x0:x1].copy()
    inner = fr[t:-b, l:-r]
    col = np.median(inner[..., :3].reshape(-1, 3), axis=0).astype(np.uint8)
    fr[t:-b, l:-r, :3] = col
    fr[t:-b, l:-r, 3] = 255
    f = FRAME_W / float(fr.shape[1])
    img = Image.fromarray(fr).resize((FRAME_W, max(1, round(fr.shape[0] * f))), Image.LANCZOS)
    a = np.asarray(img).copy()
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    img = Image.fromarray(a)
    patch = [max(4, round(l * f)), max(4, round(t * f)), max(4, round(r * f)), max(4, round(b * f))]
    save(img, "c15p1_cal_frame_" + arc, {"patch": patch, "fill": "#%02x%02x%02x" % tuple(int(c) for c in col)})
    for k, h in (("cell", 48),):
        bx = p[k]
        save(S.scale_to(Image.fromarray(rgba[bx[1]:bx[3], bx[0]:bx[2]]), height=h * 2), "c15p1_%s_%s" % (k, arc))


def main():
    man = json.load(open(MAN))
    if sys.argv[1:] == ["check"]:
        miss = [i for i in IDS if i not in man.get("ui", {}) or not os.path.exists(os.path.join(ROOT, "art", "gen", "ui", i + ".png"))]
        print("slice_c15_p1: missing", miss) if miss else None
        sys.exit(1 if miss else 0)
    icons()
    for arc, p in PANELS.items():
        panel(arc, p)
    for i in IDS:
        man.setdefault("ui", {})[i] = S.manifest["ui"][i]
    os.remove(MAN)
    with open(MAN, "w") as fh:
        json.dump(man, fh, indent=1, sort_keys=True)
    print("slice_c15_p1: %d pieces" % len(IDS))


if __name__ == "__main__":
    main()
