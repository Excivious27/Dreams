#!/usr/bin/env python3
"""Import art/gen as lossy WebP so the web pack stays small (tiles/ stay lossless).
Re-runnable. After running: godot --headless --path . --import
    python3 tools/set_import_lossy.py          # per-group quality (QUALITY table)
    python3 tools/set_import_lossy.py 0.9      # one quality for every group
    python3 tools/set_import_lossy.py --check  # list .import files off the table

QUALITY (C9 P4, web download): art that is drawn scaled down or is busy painted
detail (characters at 0.5 scale, portraits, props, buildings, furniture...) goes
to 0.8 (measured -24% WebP size, no visible change at phone zoom); UI glyphs,
item icons, seamless ground and the arcade (drawn 1:1, flat colour) keep 0.9.
.import files are hardlinked across worktrees: each is removed and rewritten,
never edited in place.
"""
import os, sys, re
DEFAULT_Q = "0.8"
QUALITY = {"ui": "0.9", "ui_creator": "0.9", "ui_creator2": "0.9", "items": "0.9", "icons_hair": "0.9",
           "seamless": "0.9", "decor": "0.9", "arcade": "0.9", "emotes": "0.9", "cliffs": "0.9", "edges": "0.9", "stairs": "0.9"}
LOSSLESS = {"tiles"}
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "art", "gen")
one = next((a for a in sys.argv[1:] if not a.startswith("-")), None)
check = "--check" in sys.argv
n = bad = 0
for d, _, files in os.walk(root):
    rel = os.path.relpath(d, root).split(os.sep)
    grp = rel[0] if rel[0] != "." else ""
    if grp in LOSSLESS:
        continue
    q = one or QUALITY.get(grp, DEFAULT_Q)
    for f in files:
        if not f.endswith(".png.import"):
            continue
        p = os.path.join(d, f)
        s = open(p).read()
        t = re.sub(r"compress/mode=\d", "compress/mode=1", s)
        t = re.sub(r"compress/lossy_quality=[\d.]+", "compress/lossy_quality=" + q, t)
        if t != s:
            if check:
                bad += 1
                continue
            os.remove(p)  # hardlinked: never write through
            with open(p, "w") as fh:
                fh.write(t)
            n += 1
if check:
    print("set_import_lossy check:", "ok" if bad == 0 else "%d files off the table" % bad)
    sys.exit(1 if bad else 0)
print("lossy:", n)
