#!/usr/bin/env python3
"""Import art/gen as lossy WebP (keeps tiles/ lossless) so the web pack stays small.
Re-runnable. After running: godot --headless --path . --import
    python3 tools/set_import_lossy.py [quality]
"""
import os, sys, re
Q = sys.argv[1] if len(sys.argv) > 1 else "0.9"
root = os.path.join(os.path.dirname(__file__), "..", "art", "gen")
n = 0
for d, _, files in os.walk(root):
    if os.sep + "tiles" in d:
        continue
    for f in files:
        if not f.endswith(".png.import"):
            continue
        p = os.path.join(d, f)
        s = open(p).read()
        t = re.sub(r"compress/mode=\d", "compress/mode=1", s)
        t = re.sub(r"compress/lossy_quality=[\d.]+", "compress/lossy_quality=" + Q, t)
        if t != s:
            open(p, "w").write(t); n += 1
print("lossy:", n)
