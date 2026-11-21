#!/usr/bin/env python3
"""Steam store + library art composer (CONDUCT S1, P6).

Builds every Steam graphical asset from text-free masters plus ONE swappable
logo layer, so a title change costs one logo render and a rerun:

    python3 tools/steam_capsules.py                 # default masters + logo
    python3 tools/steam_capsules.py --logo art/incoming/steam/logo_<slug>.png

Inputs  (art/incoming/steam/, rendered with dreams-image, see
         docs/src/steam-capsule-prompts.md):
    key_wide.png  3072x1024  text-free wide master (header/main/small/hero/bg)
    key_tall.png  1024x1536  same scene reframed tall (vertical/library capsule)
    logo-2.png    transparent logotype (title only; the ONLY text layer)
    icon.png      1024x1024  app icon master
Outputs (docs/steam-store/art/, docs/* is excluded from every export preset):
    one file per TARGETS entry + build.json sidecar + previews/ at Steam's
    auto sizes + contact_sheet.png.

Pixel look: every scene asset is downsampled (BOX) to a native pixel grid and
NEAREST-upscaled by an integer, so the chunky pixels stay crisp at any size.
Valve rule enforced in code: the only text an asset may carry is the logo
layer, and assets with logo=None (library hero, page background) never get it.
"""
import argparse
import hashlib
import json
import os
import sys

from PIL import Image, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "incoming", "steam")
OUT = os.path.join(ROOT, "docs", "steam-store", "art")

# Sources that carry a painted title: never usable for Steam art (double title /
# text in the hero).
BAKED_TEXT = {"title_keyart", "w180_title", "wordmark_glow", "wordmark_moon"}

# Focal box of the wide master (fractions): the crystal and the farmer with
# Pip-Pip and Nova. Library hero keeps this inside Valve's centred safe area.
FOCAL_WIDE = (0.40, 0.40, 0.62, 0.78)

# name: (w, h, src, grid_scale, focus (fx, fy), logo_box (cx, cy, w, h) or None, fmt, look)
TARGETS = {
    "header_capsule":   (920, 430, "wide", 2, (0.52, 0.50), (0.50, 0.24, 0.56, 0.36), "png", ""),
    "small_capsule":    (462, 174, "wide", 1, (0.54, 0.55), (0.50, 0.50, 0.93, 0.94), "png", "dim"),
    "main_capsule":     (1232, 706, "wide", 2, (0.52, 0.50), (0.50, 0.21, 0.52, 0.30), "png", ""),
    "vertical_capsule": (748, 896, "tall", 2, (0.50, 0.50), (0.50, 0.16, 0.86, 0.24), "png", ""),
    "page_background":  (1438, 810, "wide", 2, (0.50, 0.50), None, "png", "ambient"),
    "library_capsule":  (600, 900, "tall", 2, (0.50, 0.50), (0.50, 0.15, 0.86, 0.22), "png", ""),
    "library_header":   (920, 430, "wide", 2, (0.52, 0.50), (0.50, 0.24, 0.56, 0.36), "png", ""),
    "library_hero":     (3840, 1240, "wide", 4, (0.50, 0.50), None, "png", ""),
}
# Not scene crops: logo and icons.
EXTRA = ["library_logo", "app_icon", "shortcut_icon", "icon_256"]
# Steam's automatic downsizes, previewed for legibility.
PREVIEWS = {"small_capsule": [(120, 45), (184, 69)], "library_capsule": [(300, 450)],
            "library_hero": [(1920, 620)], "header_capsule": [(292, 136)]}
HERO_SAFE_AT_1920 = (860, 380)  # Valve's centred safe area at the 1920x620 template


def sha(path):
    with open(path, "rb") as f:
        return hashlib.sha1(f.read()).hexdigest()[:12]


def load_rgb(path):
    name = os.path.splitext(os.path.basename(path))[0]
    if name in BAKED_TEXT:
        sys.exit("steam_capsules: %s has a painted title; Steam art must use text-free masters" % name)
    return Image.open(path).convert("RGB")


def clean_logo(path):
    """Trim the logo to its alpha bbox (+4% pad) and drop near-zero alpha noise."""
    im = Image.open(path).convert("RGBA")
    a = im.getchannel("A").point(lambda v: 0 if v < 24 else (255 if v > 230 else v))
    im.putalpha(a)
    bb = a.getbbox()
    im = im.crop(bb)
    pad = int(max(im.size) * 0.04)
    out = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
    out.paste(im, (pad, pad))
    return out


def cover_box(sw, sh, w, h, focus):
    """Largest crop of aspect w:h inside sw x sh, centred on focus (clamped)."""
    ar = w / h
    if sw / sh > ar:
        ch, cw = sh, sh * ar
    else:
        cw, ch = sw, sw / ar
    cx, cy = focus[0] * sw, focus[1] * sh
    x0 = min(max(cx - cw / 2, 0), sw - cw)
    y0 = min(max(cy - ch / 2, 0), sh - ch)
    return (x0, y0, x0 + cw, y0 + ch)


def fit_into(logo, bw, bh):
    s = min(bw / logo.width, bh / logo.height)
    return logo.resize((max(1, round(logo.width * s)), max(1, round(logo.height * s))), Image.LANCZOS)


def compose(name, spec, masters, logo):
    w, h, src, k, focus, lbox, fmt, look = spec
    im = masters[src]
    box = cover_box(im.width, im.height, w, h, focus)
    gw, gh = w // k, h // k
    assert gw * k == w and gh * k == h, name
    grid = im.crop(tuple(round(v) for v in box)).resize((gw, gh), Image.BOX)
    if look == "dim":
        grid = ImageEnhance.Brightness(grid.filter(ImageFilter.GaussianBlur(1.2))).enhance(0.65)
    elif look == "ambient":
        grid = grid.filter(ImageFilter.GaussianBlur(10))
        grid = ImageEnhance.Color(ImageEnhance.Brightness(grid).enhance(0.6)).enhance(0.6)
    info = {"size": [w, h], "src": src, "grid": [gw, gh], "scale": k, "crop": [round(v) for v in box],
            "logo": False}
    if lbox is not None:
        cx, cy, bw, bh = lbox
        lg = fit_into(logo, bw * gw, bh * gh)
        x, y = round(cx * gw - lg.width / 2), round(cy * gh - lg.height / 2)
        grid = grid.convert("RGBA")
        grid.alpha_composite(lg, (x, y))
        grid = grid.convert("RGB")
        info["logo"] = True
        info["logo_rect"] = [x * k, y * k, lg.width * k, lg.height * k]
    if name == "library_hero":
        x0, y0, x1, y1 = box
        sx, sy = w / (x1 - x0), h / (y1 - y0)
        fx0, fy0, fx1, fy1 = FOCAL_WIDE
        info["focal"] = [round((fx0 * im.width - x0) * sx), round((fy0 * im.height - y0) * sy),
                         round((fx1 * im.width - x0) * sx), round((fy1 * im.height - y0) * sy)]
    out = grid.resize((w, h), Image.NEAREST)
    return out, info


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--wide", default=os.path.join(SRC, "key_wide.png"))
    ap.add_argument("--tall", default=os.path.join(SRC, "key_tall.png"))
    ap.add_argument("--logo", default=os.path.join(SRC, "logo-2.png"))
    ap.add_argument("--icon", default=os.path.join(SRC, "icon.png"))
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    os.makedirs(os.path.join(a.out, "previews"), exist_ok=True)
    masters = {"wide": load_rgb(a.wide), "tall": load_rgb(a.tall)}
    logo = clean_logo(a.logo)
    build = {"_sources": {k: os.path.relpath(v, ROOT) for k, v in
                          (("wide", a.wide), ("tall", a.tall), ("logo", a.logo), ("icon", a.icon))},
             "_hero_safe_full": [HERO_SAFE_AT_1920[0] * 2, HERO_SAFE_AT_1920[1] * 2]}
    sheet_items = []
    for name, spec in TARGETS.items():
        img, info = compose(name, spec, masters, logo)
        path = os.path.join(a.out, name + "." + spec[6])
        img.save(path, optimize=True)
        info["file"] = os.path.basename(path)
        info["sha"] = sha(path)
        build[name] = info
        sheet_items.append((name, img))
        for pw, ph in PREVIEWS.get(name, []):
            img.resize((pw, ph), Image.LANCZOS).save(
                os.path.join(a.out, "previews", "%s_%dx%d.png" % (name, pw, ph)))
    # Library logo: transparent PNG, logotype only, fit 1280 wide / 720 tall.
    ll = fit_into(logo, 1280, 720)
    p = os.path.join(a.out, "library_logo.png")
    ll.save(p, optimize=True)
    build["library_logo"] = {"size": list(ll.size), "file": "library_logo.png", "sha": sha(p), "logo": True}
    # Icons: flatten on the icon's own background colour (Steam turns alpha black).
    ic = Image.open(a.icon).convert("RGBA")
    bg = ic.getpixel((4, 4))[:3]
    flat = Image.new("RGB", ic.size, bg)
    flat.paste(ic, (0, 0), ic)
    for name, size, fn, kw in (("app_icon", 184, "app_icon.jpg", {"quality": 92}),
                               ("shortcut_icon", 512, "shortcut_icon.png", {}),
                               ("icon_256", 256, "icon_256.ico", {})):
        p = os.path.join(a.out, fn)
        small = flat.resize((size, size), Image.LANCZOS)
        if fn.endswith(".ico"):
            small.save(p, sizes=[(256, 256), (64, 64), (32, 32), (16, 16)])
        else:
            small.save(p, **kw)
        build[name] = {"size": [size, size], "file": fn, "sha": sha(p), "logo": False, "bg": list(bg)}
    flat.resize((32, 32), Image.LANCZOS).save(os.path.join(a.out, "previews", "app_icon_32x32.png"))
    # Contact sheet: every scene asset scaled to 360 px wide.
    thumbs = [im.resize((360, max(1, round(im.height * 360 / im.width))), Image.LANCZOS) for _, im in sheet_items]
    cols = 4
    rows = (len(thumbs) + cols - 1) // cols
    rh = [max(t.height for t in thumbs[r * cols:(r + 1) * cols]) for r in range(rows)]
    sheet = Image.new("RGB", (cols * 370 + 10, sum(rh) + 10 * (rows + 1)), (20, 16, 32))
    y = 10
    for r in range(rows):
        for c, t in enumerate(thumbs[r * cols:(r + 1) * cols]):
            sheet.paste(t, (10 + c * 370, y))
        y += rh[r] + 10
    sheet.save(os.path.join(a.out, "contact_sheet.png"), optimize=True)
    with open(os.path.join(a.out, "build.json"), "w") as f:
        json.dump(build, f, indent=1, sort_keys=True)
        f.write("\n")
    print("steam_capsules: wrote %d assets to %s" % (len(TARGETS) + len(EXTRA), os.path.relpath(a.out, ROOT)))


if __name__ == "__main__":
    main()
