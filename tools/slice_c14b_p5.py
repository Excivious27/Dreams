#!/usr/bin/env python3
"""C14b P5: blink frames for character idles.

dreams-image edits an existing idle strip ("same image, eyes closed"); this
tool takes only the eyes from the render: it scales the render to the strip,
aligns each frame on the body, finds the changed pixels in the face band and
pastes just those onto the original frame. The result is pixel-identical to
the drawn idle except the closed eyes, so the blink never flickers the body.

Writes art/gen/characters/<id>/c14bp5_blink_<anim>.png (same cells as the
source strip) and appends manifest entries (group characters/<id>, anim
c14bp5_blink_<anim>). CharacterLibrary weaves the blink into the idle loop.

  python3 tools/slice_c14b_p5.py <id> <anim> <render.png> [--face 0.12:0.5]
  python3 tools/slice_c14b_p5.py --all      (every entry in JOBS below)
"""
import json
import os
import sys

from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "art", "gen")
INC = os.path.join(ROOT, "art", "incoming", "c14b_p5")
MANIFEST = os.path.join(GEN, "manifest.json")

# id, anim, render file (art/incoming/c14b_p5/), face band (share of cell height)
JOBS = []
JOBS_FILE = os.path.join(INC, "jobs.json")


def _align(src, ren):
    """Best (dx, dy) of `ren` over `src` by masked colour difference."""
    best = None
    w, h = src.size
    for dy in range(-3, 4):
        for dx in range(-3, 4):
            sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            sh.paste(ren, (dx, dy))
            d = ImageChops.difference(src.convert("RGB"), sh.convert("RGB")).convert("L")
            a = src.split()[3]
            s = sum(p for p, m in zip(d.tobytes(), a.tobytes()) if m > 128)
            if best is None or s < best[0]:
                best = (s, dx, dy, sh)
    return best[3]


def blink(gid, anim, render, face=(0.12, 0.55), thr=60):
    src_path = os.path.join(GEN, "characters", gid, anim + ".png")
    man = json.load(open(MANIFEST))
    inf = man["characters/" + gid][anim]
    src = Image.open(src_path).convert("RGBA")
    n = int(inf.get("frames", 1))
    cw, ch = int(inf["cell_w"]), int(inf["cell_h"])
    ren = Image.open(render).convert("RGBA").resize(src.size, Image.LANCZOS)
    out = src.copy()
    changed = 0
    for i in range(n):
        box = (i * cw, 0, (i + 1) * cw, ch)
        s = src.crop(box)
        r = _align(s, ren.crop(box))
        y0, y1 = int(ch * face[0]), int(ch * face[1])
        d = ImageChops.difference(s.convert("RGB"), r.convert("RGB")).convert("L")
        px = out.load()
        rp = r.load()
        sp = s.load()
        dp = d.load()
        # eye pixels: big change, inside the body (opaque in the source), in the face band
        pts = [(x, y) for y in range(y0, y1) for x in range(cw) if dp[x, y] > thr and sp[x, y][3] > 200]
        if not pts:
            continue
        # keep only the eyes: the first run of rows (top down) with real change,
        # so a smile or a hair edge the render also touched is left as drawn
        rows = {}
        for x, y in pts:
            rows[y] = rows.get(y, 0) + 1
        dense = [y for y in sorted(rows) if rows[y] >= 3]
        if not dense:
            continue
        runs = [[dense[0]]]
        for y in dense[1:]:
            if y - runs[-1][-1] <= 2:
                runs[-1].append(y)
            else:
                runs.append([y])
        # the eyes are the strongest change (a smile or hair fringe is smaller)
        run = max(runs, key=lambda r: sum(rows[y] for y in r))
        ylo, yhi = run[0], run[-1]
        win = max(4, int(ch * 0.1))  # an eye is at most ~10% of the body tall
        if yhi - ylo + 1 > win:
            best = max(range(ylo, yhi - win + 2), key=lambda t: sum(rows.get(y, 0) for y in range(t, t + win)))
            ylo, yhi = best, best + win - 1
        pts = [(x, y) for x, y in pts if ylo <= y <= yhi]
        for x, y in pts:
            c = rp[x, y]
            px[i * cw + x, y] = (c[0], c[1], c[2], 255)
            changed += 1
    dst_dir = os.path.join(GEN, "characters", gid)
    name = "c14bp5_blink_" + anim
    dst = os.path.join(dst_dir, name + ".png")
    if os.path.exists(dst):
        os.remove(dst)  # hardlinked art: never write in place
    out.save(dst)
    ent = dict(inf)
    ent["file"] = "characters/%s/%s.png" % (gid, name)
    man["characters/" + gid][name] = ent
    tmp = MANIFEST + ".tmp"
    with open(tmp, "w") as f:
        json.dump(man, f, indent=1)
        f.write("\n")
    os.replace(tmp, MANIFEST)
    print("%s/%s: %d px changed -> %s" % (gid, anim, changed, ent["file"]))
    return changed


def main():
    if sys.argv[1:2] == ["--all"]:
        jobs = json.load(open(JOBS_FILE)) if os.path.exists(JOBS_FILE) else JOBS
        for j in jobs:
            blink(j[0], j[1], os.path.join(INC, j[2]), tuple(j[3]) if len(j) > 3 else (0.12, 0.55))
        return
    gid, anim, render = sys.argv[1:4]
    face = (0.12, 0.55)
    if "--face" in sys.argv:
        a, b = sys.argv[sys.argv.index("--face") + 1].split(":")
        face = (float(a), float(b))
    blink(gid, anim, render, face)


if __name__ == "__main__":
    main()
