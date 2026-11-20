#!/usr/bin/env python3
"""Window-glow masks for town buildings (CONDUCT 5, c5_02 #1 / c5_10 #2).

For every art/gen/buildings/<name>_night.png beside a same-size <name>.png, keep
the pixels that the night picture lights up (warm and clearly brighter than the
day picture: windows, lanterns, shop fronts) and write them as
art/gen/buildings/<name>_lit.png (night colour, alpha = how lit) + a manifest
entry. NightGlow draws these additively over the building, faded by darkness.

    python3 tools/make_window_glow.py [--check]

Never writes over an existing file in place (rm first: art is hardlinked).
"""
import json
import os
import sys

from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "art", "gen")
BDIR = os.path.join(ROOT, "buildings")
MAN = os.path.join(ROOT, "manifest.json")


def lum(c):
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255.0


def mask_for(day, night):
    w, h = day.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dp, np_, op = day.load(), night.load(), out.load()
    lit = 0
    for y in range(h):
        for x in range(w):
            n = np_[x, y]
            d = dp[x, y]
            if n[3] < 128 or d[3] < 128:
                continue
            gain = lum(n) - lum(d)
            warm = n[0] > 150 and n[0] >= n[2] + 40 and n[1] > 90
            if gain > 0.08 and warm:
                a = min(1.0, (gain - 0.08) / 0.22) * min(1.0, (lum(n) - 0.35) / 0.3)
                if a > 0.05:
                    op[x, y] = (n[0], n[1], n[2], int(255 * a))
                    lit += 1
    # a faint halo one pixel round each lit pane, so the glow reads at phone size
    halo = out.split()[3].filter(ImageFilter.MaxFilter(3)).point(lambda v: v // 3)
    base = Image.new("RGBA", (w, h), (255, 200, 110, 0))
    base.putalpha(halo)
    return Image.alpha_composite(base, out), lit


def main():
    check = "--check" in sys.argv
    man = json.load(open(MAN))
    b = man.setdefault("buildings", {})
    made = []
    for fn in sorted(os.listdir(BDIR)):
        if not fn.endswith("_night.png"):
            continue
        name = fn[: -len("_night.png")]
        dayp = os.path.join(BDIR, name + ".png")
        if not os.path.exists(dayp):
            continue
        day = Image.open(dayp).convert("RGBA")
        night = Image.open(os.path.join(BDIR, fn)).convert("RGBA")
        if day.size != night.size:
            print("skip %s: size %s vs %s" % (name, day.size, night.size))
            continue
        img, lit = mask_for(day, night)
        if lit < 6:
            print("skip %s: nothing lit (%d px)" % (name, lit))
            continue
        made.append((name, lit))
        if check:
            continue
        out = os.path.join(BDIR, name + "_lit.png")
        if os.path.exists(out):
            os.remove(out)
        img.save(out)
        b[name + "_lit"] = {"file": "buildings/%s_lit.png" % name, "w": day.size[0], "h": day.size[1], "glow_mask": True}
    if not check:
        tmp = MAN + ".tmp"
        with open(tmp, "w") as f:
            json.dump(man, f, indent=1, sort_keys=True)
        os.remove(MAN)
        os.rename(tmp, MAN)
    for n, lit in made:
        print("%-16s %5d lit px" % (n, lit))
    print("make_window_glow: %d masks" % len(made))


if __name__ == "__main__":
    main()
