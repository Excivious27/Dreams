#!/usr/bin/env python3
"""Trim sheet-rule slivers: a 1-3 px line cut into the top or bottom rows of a
sprite, with an empty row between it and the body (a dark line above bushes,
under fence pieces...). Run after tools/fix_overlays.py, then godot --import.
ART_GEN=<dir> works on a copy; names on the command line limit it to those
sprites (group/name or name)."""
import glob, os, sys
from PIL import Image

GEN = os.environ.get("ART_GEN") or os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "gen")
SKIP = {"greenhouse2", "crystalarium", "grain_elevator", "r_riverlands_48"}  # flat tops / tiny specks that only look like slivers
only = set(sys.argv[1:])


def slivers(im):
    """Rows to clear (top and bottom), or []."""
    w, h = im.size
    if h < 12:
        return []
    px = im.load()
    out = []
    for rows in (list(range(0, min(4, h))), list(range(h - 1, max(h - 5, -1), -1))):
        o = [sum(1 for x in range(w) if px[x, y][3] > 100) for y in rows]
        for k in range(1, 4):
            if o[0] >= max(8, w // 4) and all(v > 0 for v in o[:k]) and o[k] == 0:
                out += rows[:k]
                break
    return out


n = 0
for f in sorted(glob.glob(os.path.join(GEN, "nature", "*.png")) + glob.glob(os.path.join(GEN, "props", "*.png")) + glob.glob(os.path.join(GEN, "buildings", "*.png"))):
    nm = os.path.basename(f)[:-4]
    grp = os.path.basename(os.path.dirname(f))
    if nm in SKIP or (only and nm not in only and "%s/%s" % (grp, nm) not in only):
        continue
    im = Image.open(f).convert("RGBA")
    rows = slivers(im)
    if not rows:
        continue
    px = im.load()
    for y in rows:
        for x in range(im.size[0]):
            px[x, y] = (0, 0, 0, 0)
    im.save(f)
    n += 1
    print("cleared", grp + "/" + nm, rows)
print("edge_slivers:", n)
