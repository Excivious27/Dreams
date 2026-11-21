#!/usr/bin/env python3
"""Checks the Steam store screenshots (tools/steam_shots.gd output; no Godot).

docs/steam-store/screenshots/ must hold >= 5 JPGs, each exactly 1920x1080
(Steam: 16:9, at least 5 gameplay shots), both arcs must be present, and
docs/steam-store/screenshots.md must list every file with at least 4 marked
all-ages (Steam's 'suitable for all ages' flag).
"""
import os
import re
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "docs", "steam-store", "screenshots")
MD = os.path.join(ROOT, "docs", "steam-store", "screenshots.md")


def main():
    errs = []
    pngs = sorted(f for f in os.listdir(DIR) if f.endswith(".jpg")) if os.path.isdir(DIR) else []
    if len(pngs) < 5:
        errs.append("%d screenshots, Steam needs at least 5" % len(pngs))
    for f in pngs:
        sz = Image.open(os.path.join(DIR, f)).size
        if sz != (1920, 1080):
            errs.append("%s is %dx%d, needs 1920x1080" % (f, sz[0], sz[1]))
    md = open(MD).read() if os.path.exists(MD) else ""
    rows = re.findall(r"^\|\s*(\d\d_[a-z_]+)\s*\|([^|]*)\|\s*(penguins|gangsters)\s*\|\s*(yes|no)\s*\|", md, re.M)
    names = {r[0] for r in rows}
    for f in pngs:
        if f[:-4] not in names:
            errs.append("%s is not listed in screenshots.md" % f)
    if {r[2] for r in rows if r[0] + ".jpg" in pngs} != {"penguins", "gangsters"}:
        errs.append("both arcs need a screenshot")
    if sum(1 for r in rows if r[3] == "yes" and r[0] + ".jpg" in pngs) < 4:
        errs.append("at least 4 screenshots must be marked all-ages")
    for e in errs:
        print("steam_shots_test: FAIL " + e)
    print("steam_shots_test: %d shots, %d failures" % (len(pngs), len(errs)))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
