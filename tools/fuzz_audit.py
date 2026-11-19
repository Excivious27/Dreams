#!/usr/bin/env python3
"""Score every art/gen image for blur and list the worst by group -> docs/FUZZY-ART.md.

  python3 tools/fuzz_audit.py [--top N] [--group G] [--print]

Per image (opaque pixels only):
  soft_edge  share of the silhouette rim that is half-transparent (soft alpha = an
             upscaled or LANCZOS-shrunk render; crisp pixel art has 0)
  detail     how much the picture changes under a 2x shrink-and-grow, relative to its
             contrast (low = no real pixel-level detail: blurred / upscaled)
  grad       mean neighbour step on the opaque interior / contrast (low = mushy)
  colors     unique colours per 100 opaque pixels (very high = painterly anti-aliasing)
fuzz = 0..100, higher is fuzzier. Groups are ranked buildings first, then props,
nature, characters/enemies, the rest. kits/ (not shipped) and seamless/ are skipped.
Crispened files (tools/crispen.py) score low on soft_edge by construction; the
detail/grad terms still flag art that is blurry inside.
"""
import os, sys, json, argparse
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "art", "gen")
ORDER = ["buildings", "props", "nature", "furniture", "stations", "enemies", "characters", "animals", "wildlife", "tiles", "cliffs", "ui", "items"]
SKIP = {"kits", "seamless", "ui_creator", "ui_creator2", "backdrops", "arcade"}


def score(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.float32)
    al = a[..., 3]
    op = al > 200
    n = int(op.sum())
    if n < 64:
        return None
    from scipy import ndimage
    solid = al > 0
    rim = solid & ~ndimage.binary_erosion(solid, iterations=1, border_value=0)
    rim2 = ndimage.binary_dilation(rim, iterations=1) & solid
    soft = float(((al > 0) & (al < 250) & rim2).sum()) / max(1.0, float(rim.sum()))
    g = a[..., :3].mean(-1)
    inner = ndimage.binary_erosion(op, iterations=2)
    if inner.sum() < 32:
        inner = op
    contrast = float(g[inner].std()) + 4.0
    h, w = g.shape
    small = np.asarray(Image.fromarray(g.astype(np.uint8)).resize((max(1, w // 2), max(1, h // 2)), Image.BOX).resize((w, h), Image.BILINEAR)).astype(np.float32)
    detail = float(np.abs(g - small)[inner].mean()) / contrast
    dx = np.abs(np.diff(g, axis=1))[inner[:, 1:] & inner[:, :-1]]
    dy = np.abs(np.diff(g, axis=0))[inner[1:, :] & inner[:-1, :]]
    grad = float(np.concatenate([dx, dy]).mean()) / contrast if len(dx) + len(dy) else 0.0
    cols = len(np.unique(a[op][:, :3].astype(np.uint8).view(np.dtype((np.void, 3)))))
    cpp = cols * 100.0 / n
    # weights tuned on known-bad (mine rocks, old LANCZOS buildings) vs crisp (hand-picked hero strips)
    f = 0.0
    f += min(1.0, soft / 0.6) * 35
    f += max(0.0, 1.0 - detail / 0.35) * 30
    f += max(0.0, 1.0 - grad / 0.45) * 20
    f += min(1.0, cpp / 60.0) * 15
    return {"fuzz": round(f, 1), "soft_edge": round(soft, 2), "detail": round(detail, 3), "grad": round(grad, 3),
            "colors": round(cpp, 1), "w": im.width, "h": im.height}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", type=int, default=40)
    ap.add_argument("--group")
    ap.add_argument("--print", action="store_true")
    ap.add_argument("--out", default=os.path.join(ROOT, "docs", "FUZZY-ART.md"))
    args = ap.parse_args()
    res = {}
    for dp, dn, fn in os.walk(GEN):
        rel = os.path.relpath(dp, GEN)
        top = rel.split(os.sep)[0]
        if top in SKIP or rel == ".":
            continue
        if args.group and top != args.group:
            continue
        for f in fn:
            if not f.endswith(".png"):
                continue
            s = score(os.path.join(dp, f))
            if s:
                res.setdefault(top, []).append((os.path.join(rel, f), s))
    groups = sorted(res, key=lambda g: (ORDER.index(g) if g in ORDER else 99, g))
    lines = ["# Fuzzy art audit (tools/fuzz_audit.py)", "",
             "Ranked to-do of blurry/low-quality art: worst first per group, buildings first.",
             "fuzz 0..100 (higher = fuzzier): soft alpha rim, little pixel detail under a 2x",
             "shrink, mushy neighbour steps, painterly colour counts. Re-run after every fix:",
             "`python3 tools/fuzz_audit.py` (rewrites this file).", "",
             "How to fix an entry: re-render with the image tool (edit_image, old art as reference,",
             "same footprint, crisp 16-bit pixel art, magenta bg) and slice in place (rm first), or",
             "for mild cases run it through `tools/crispen.py` (see tools/slice_r13_c2_p7.py).",
             "Code side: sprites placed with GameMap.building() and mine rocks use the",
             "sharp-pixel material (`CrispArt`, shaders/sharp_pixel.gdshader) so phone-size",
             "magnification of 2x-detail art stays crisp instead of bilinear-soft.", ""]
    summary = []
    for g in groups:
        items = sorted(res[g], key=lambda t: -t[1]["fuzz"])
        bad = sum(1 for _, s in items if s["fuzz"] >= 55)
        summary.append(f"| {g} | {len(items)} | {bad} | {items[0][1]['fuzz'] if items else 0} |")
    lines += ["| group | images | fuzz >= 55 | worst |", "|---|---|---|---|"] + summary + [""]
    for g in groups:
        items = sorted(res[g], key=lambda t: -t[1]["fuzz"])[: args.top]
        lines += [f"## {g}", "", "| fuzz | file | size | soft rim | detail | grad | colours/100px |", "|---|---|---|---|---|---|---|"]
        for p, s in items:
            lines.append(f"| {s['fuzz']} | {p} | {s['w']}x{s['h']} | {s['soft_edge']} | {s['detail']} | {s['grad']} | {s['colors']} |")
        lines.append("")
    with open(args.out, "w") as fh:
        fh.write("\n".join(lines))
    if args.print:
        for g in groups:
            items = sorted(res[g], key=lambda t: -t[1]["fuzz"])[:10]
            print(g, [(p, s["fuzz"]) for p, s in items])
    json.dump({g: {p: s for p, s in v} for g, v in res.items()}, open("/tmp/fuzz_audit.json", "w"))


if __name__ == "__main__":
    main()
