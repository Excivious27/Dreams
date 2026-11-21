#!/usr/bin/env python3
"""C14b P2 (c14b_04-02): register a mis-registered animation strip.

Fire/cook strips were drawn as separate renders, so the static base (stones,
barrel, pot) changes size and position every frame and the whole prop jitters.
For each frame this finds the base (opaque pixels in the lower 40 % of the
cell), scales the frame so the base has the median width, and pastes it with
the base bottom-centre on the cell's bottom-centre. The cell grows in height
if a scaled frame needs it (bottom-anchored props keep their feet). The strip
is rewritten rm-then-write and its manifest cell_h/h updated.

  python3 tools/register_strip.py props/bonfire props/fire_barrel2 ...
  python3 tools/register_strip.py --check props/bonfire   (exit 1 if base width/x differ > 1 px)
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAN = os.path.join(ROOT, "art", "gen", "manifest.json")
DEFAULT = ["props/bonfire", "furniture/bubbling_pot"]  # fire_barrel2/lamp_mechanism frames are different drawings: art queue


def base_box(cell):
    w, h = cell.size
    y0 = int(h * 0.6)
    a = cell.split()[3].crop((0, y0, w, h)).point(lambda v: 255 if v > 128 else 0)
    bb = a.getbbox()
    if not bb:
        return None
    return bb[0], bb[2], bb[3] + y0  # x0, x1, bottom


def frames_of(e, im):
    cw, ch, n = e["cell_w"], e["cell_h"], e.get("frames", 1)
    return [im.crop((f * cw, 0, (f + 1) * cw, ch)) for f in range(n)]


def spread(cells):
    bs = [base_box(c) for c in cells]
    bs = [b for b in bs if b]
    if not bs:
        return 0, 0
    ws = [b[1] - b[0] for b in bs]
    cs = [(b[0] + b[1]) / 2 for b in bs]
    return max(ws) - min(ws), max(cs) - min(cs)


def register(gid, man, write=True):
    g, n = gid.split("/", 1)
    e = man[g][n]
    path = os.path.join(ROOT, "art", "gen", e["file"])
    im = Image.open(path).convert("RGBA")
    cells = frames_of(e, im)
    boxes = [base_box(c) for c in cells]
    widths = sorted(b[1] - b[0] for b in boxes if b)
    target = widths[len(widths) // 2]
    cw, ch = e["cell_w"], e["cell_h"]
    out_cells = []
    need_h = ch
    for c, b in zip(cells, boxes):
        if not b:
            out_cells.append((c, 0, 0))
            continue
        s = target / max(1, b[1] - b[0])
        if abs(s - 1.0) < 0.02:
            s = 1.0
        sc = c if s == 1.0 else c.resize((max(1, round(cw * s)), max(1, round(ch * s))), Image.LANCZOS)
        bx = ((b[0] + b[1]) / 2) * s
        by = b[2] * s
        need_h = max(need_h, int(round(by)) + 0)
        out_cells.append((sc, bx, by))
    cw2 = cw
    ch2 = max(ch, need_h)
    strip = Image.new("RGBA", (cw2 * len(cells), ch2), (0, 0, 0, 0))
    for i, (sc, bx, by) in enumerate(out_cells):
        if bx == 0 and by == 0:
            strip.alpha_composite(sc, (i * cw2, ch2 - sc.height))
            continue
        x = int(round(cw2 / 2 - bx))
        y = int(round(ch2 - by))
        tile = Image.new("RGBA", (cw2, ch2), (0, 0, 0, 0))
        tile.alpha_composite(sc, (0, 0)) if False else tile.paste(sc, (x, y), sc)
        # clean LANCZOS halos: hard alpha like the rest of the art
        a = tile.split()[3].point(lambda v: 255 if v > 110 else 0)
        tile.putalpha(a)
        strip.alpha_composite(tile, (i * cw2, 0))
    if write:
        os.remove(path)  # art files are hardlinked across worktrees: never write in place
        strip.save(path)
        e["cell_h"] = ch2
        e["h"] = ch2
        e["registered"] = True
    return spread(frames_of(e, strip) if write else [strip.crop((i * cw2, 0, (i + 1) * cw2, ch2)) for i in range(len(cells))])


def main():
    args = sys.argv[1:]
    check = "--check" in args
    ids = [a for a in args if not a.startswith("--")] or DEFAULT
    man = json.load(open(MAN))
    bad = 0
    for gid in ids:
        g, n = gid.split("/", 1)
        e = man[g][n]
        if check:
            im = Image.open(os.path.join(ROOT, "art", "gen", e["file"])).convert("RGBA")
            dw, dx = spread(frames_of(e, im))
            ok = dw <= 2 and dx <= 1.5
            bad += 0 if ok else 1
            print("%s base width spread %d px, centre spread %.1f px %s" % (gid, dw, dx, "ok" if ok else "BAD"))
            continue
        if e.get("registered"):
            print(gid, "already registered")
            continue
        dw, dx = register(gid, man)
        print("%s registered: base width spread %d px, centre spread %.1f px, cell_h %d" % (gid, dw, dx, e["cell_h"]))
    if not check:
        txt = json.dumps(man, indent=1) + "\n"  # keep the manifest's own key order (no reshuffle diff)
        os.remove(MAN)  # rm-then-write, like every art file
        with open(MAN, "w") as f:
            f.write(txt)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
