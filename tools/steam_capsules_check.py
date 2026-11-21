#!/usr/bin/env python3
"""Checks the Steam store/library art built by tools/steam_capsules.py.

Fails (exit 1) when any asset is missing, has the wrong size/format, the
library hero or page background carries the logo (Valve: no text), the hero's
focal subjects leave the centred safe area, the small capsule logo is narrower
than 85% of the capsule, the library logo has no transparent border, the icon
is not an RGB JPG, or a scene asset is not an exact integer multiple of its
pixel grid. No Godot; runs in check.sh.
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "docs", "steam-store", "art")

REQUIRED = {  # file: (w, h) ; None = checked separately
    "header_capsule.png": (920, 430), "small_capsule.png": (462, 174),
    "main_capsule.png": (1232, 706), "vertical_capsule.png": (748, 896),
    "page_background.png": (1438, 810), "library_capsule.png": (600, 900),
    "library_header.png": (920, 430), "library_hero.png": (3840, 1240),
    "library_logo.png": None, "app_icon.jpg": (184, 184),
    "shortcut_icon.png": (512, 512), "icon_256.ico": None,
}
NO_LOGO = {"library_hero", "page_background", "app_icon", "shortcut_icon", "icon_256"}


def main():
    errs = []
    bpath = os.path.join(ART, "build.json")
    if not os.path.exists(bpath):
        print("steam_capsules_check: FAIL no build.json (run python3 tools/steam_capsules.py)")
        return 1
    build = json.load(open(bpath))
    for fn, size in REQUIRED.items():
        p = os.path.join(ART, fn)
        if not os.path.exists(p):
            errs.append("missing " + fn)
            continue
        im = Image.open(p)
        if size and im.size != size:
            errs.append("%s is %dx%d, needs %dx%d" % ((fn,) + im.size + size))
    name = lambda fn: os.path.splitext(fn)[0]
    for n in NO_LOGO:
        if build.get(n, {}).get("logo"):
            errs.append("%s must not carry the logo or any text (Valve rule)" % n)
    # Every scene asset is an integer multiple of its grid.
    for n, info in build.items():
        if n.startswith("_") or "grid" not in info:
            continue
        gw, gh = info["grid"]
        k = info["scale"]
        if [gw * k, gh * k] != info["size"]:
            errs.append("%s is not an exact %dx grid upscale" % (n, k))
    # Hero focal box inside the centred safe area.
    hero = build.get("library_hero", {})
    sw, sh = build.get("_hero_safe_full", [1720, 760])
    if "focal" in hero:
        x0, y0, x1, y1 = hero["focal"]
        W, H = hero["size"]
        sx0, sy0 = (W - sw) / 2, (H - sh) / 2
        if x0 < sx0 or y0 < sy0 or x1 > sx0 + sw or y1 > sy0 + sh:
            errs.append("library_hero focal box %s leaves the centred %dx%d safe area" % (hero["focal"], sw, sh))
    else:
        errs.append("library_hero has no focal box in build.json")
    sc = build.get("small_capsule", {})
    if sc.get("logo_rect") and sc["logo_rect"][2] < 0.85 * 462:
        errs.append("small_capsule logo is %d px wide, needs >= 85%% of 462" % sc["logo_rect"][2])
    p = os.path.join(ART, "library_logo.png")
    if os.path.exists(p):
        lg = Image.open(p)
        if lg.mode != "RGBA":
            errs.append("library_logo must be RGBA")
        else:
            a = lg.getchannel("A")
            corners = [a.getpixel(c) for c in ((0, 0), (lg.width - 1, 0), (0, lg.height - 1), (lg.width - 1, lg.height - 1))]
            if max(corners) != 0:
                errs.append("library_logo needs a transparent border")
            if lg.width != 1280 and lg.height != 720:
                errs.append("library_logo must be 1280 wide or 720 tall (is %dx%d)" % lg.size)
    p = os.path.join(ART, "app_icon.jpg")
    if os.path.exists(p):
        ic = Image.open(p)
        if ic.format != "JPEG" or ic.mode != "RGB":
            errs.append("app_icon must be an RGB JPG")
    if errs:
        for e in errs:
            print("steam_capsules_check: FAIL " + e)
        return 1
    print("steam_capsules_check: ok (%d assets)" % len(REQUIRED))
    return 0


if __name__ == "__main__":
    sys.exit(main())
