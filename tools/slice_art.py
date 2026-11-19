#!/usr/bin/env python3
"""Slices Tom's ChatGPT sheets in art/incoming/ into game-ready sprites in art/gen/.

- Keys out the flat magenta background (with soft edges and de-spill).
- Finds cells by projection (gaps of background between items), by fixed grid,
  or by "the component under this point".
- Scales every piece to the game's 2x-detail scale (drawn at 0.5 in Godot).

Run: python3 tools/slice_art.py   (needs Pillow + numpy). Safe to re-run.
Never modifies art/incoming/.
"""
import json, os, sys
import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
INC = os.path.join(ROOT, "art", "incoming")
OUT = os.path.join(ROOT, "art", "gen")
TILE2 = 32  # one 16px tile at 2x detail
manifest = {}


# ---------------------------------------------------------------- keying

def key_magenta(img):
    a = np.asarray(img.convert("RGBA")).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mag = np.minimum(r, b) - g  # how magenta a pixel is (orange has low b, so it stays opaque)
    alpha = np.clip((100 - mag) * 255 / 45, 0, 255)   # mag<=55 opaque, >=100 clear
    bright = np.minimum(r, b)
    alpha = np.where(bright < 150, 255, alpha)         # dark purples/outlines are never background
    # ...except the sheets' own darker magenta (shading of the backdrop, ~141,2,138):
    # strongly magenta with r≈b and almost no green is still background at any brightness.
    deep_bg = (mag > 100) & (np.abs(r - b) < 40) & (g < 40)
    alpha = np.where(deep_bg, 0, alpha)
    out = a.copy()
    # de-spill: pull magenta fringe toward neutral
    fringe = (alpha < 255) & (alpha > 0)
    out[..., 0] = np.where(fringe, np.minimum(r, g + 40), r)
    out[..., 2] = np.where(fringe, np.minimum(b, g + 40), b)
    out[..., 3] = alpha.astype(np.int32)
    return out.astype(np.uint8)


def remove_thin_lines(rgba, px=3):
    """Kill thin grid lines that survived keying (opening on the alpha mask)."""
    from scipy import ndimage
    m = rgba[..., 3] > 40
    opened = ndimage.binary_opening(m, iterations=px)
    out = rgba.copy()
    out[..., 3] = np.where(opened, out[..., 3], 0)
    return out


def fg_mask(rgba, thresh=40):
    return rgba[..., 3] > thresh


# ---------------------------------------------------------------- slicing

def runs(profile, min_gap=2):
    """Return (start, end) runs where profile is True, merging gaps < min_gap."""
    out, start = [], None
    for i, v in enumerate(profile):
        if v and start is None:
            start = i
        elif not v and start is not None:
            out.append((start, i)); start = None
    if start is not None:
        out.append((start, len(profile)))
    merged = []
    for s, e in out:
        if merged and s - merged[-1][1] < min_gap:
            merged[-1] = (merged[-1][0], e)
        else:
            merged.append((s, e))
    return merged


def bbox(mask):
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def cells_by_projection(rgba, region=None, row_gap=6, col_gap=6, min_size=12):
    x0, y0, x1, y1 = region or (0, 0, rgba.shape[1], rgba.shape[0])
    m = fg_mask(rgba[y0:y1, x0:x1])
    rows = []
    for rs, re in runs(m.any(axis=1), row_gap):
        if re - rs < min_size:
            continue
        band = m[rs:re]
        cols = []
        for cs, ce in runs(band.any(axis=0), col_gap):
            if ce - cs < min_size:
                continue
            sub = band[:, cs:ce]
            b = bbox(sub)
            cols.append((x0 + cs + b[0], y0 + rs + b[1], x0 + cs + b[2], y0 + rs + b[3]))
        rows.append(cols)
    return rows


def cells_by_grid(rgba, cols, rows, region=None, trim=True, inset=0):
    x0, y0, x1, y1 = region or (0, 0, rgba.shape[1], rgba.shape[0])
    cw, ch = (x1 - x0) / cols, (y1 - y0) / rows
    out = []
    for r in range(rows):
        row = []
        for c in range(cols):
            cx0, cy0 = int(x0 + c * cw) + inset, int(y0 + r * ch) + inset
            cx1, cy1 = int(x0 + (c + 1) * cw) - inset, int(y0 + (r + 1) * ch) - inset
            if trim:
                b = bbox(fg_mask(rgba[cy0:cy1, cx0:cx1]))
                if b is None:
                    row.append(None); continue
                row.append((cx0 + b[0], cy0 + b[1], cx0 + b[2], cy0 + b[3]))
            else:
                row.append((cx0, cy0, cx1, cy1))
        out.append(row)
    return out


def component_at(rgba, px, py, dilate=3):
    """Bounding box of the connected foreground blob containing (px, py)."""
    from scipy import ndimage
    m = fg_mask(rgba)
    if dilate:
        m = ndimage.binary_dilation(m, iterations=dilate)
    labels, _ = ndimage.label(m)
    lab = labels[py, px]
    if lab == 0:
        return None
    b = bbox(labels == lab)
    return b


# ---------------------------------------------------------------- output

def crop(rgba, box):
    x0, y0, x1, y1 = box
    return Image.fromarray(rgba[y0:y1, x0:x1])


def scale_to(img, width=None, height=None, cover=False):
    """Fit inside width x height (keeps aspect). cover=True: fill it, cropping the overflow."""
    w, h = img.size
    if cover and width and height:
        f = max(width / w, height / h)
        nw, nh = max(1, round(w * f)), max(1, round(h * f))
        out = img.resize((nw, nh), Image.LANCZOS)
        x0, y0 = (nw - width) // 2, (nh - height) // 2
        out = out.crop((x0, y0, x0 + width, y0 + height))
        a = np.asarray(out).copy()
        a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
        return Image.fromarray(a)
    if width and not height:
        f = width / w
    elif height and not width:
        f = height / h
    else:
        f = min(width / w, height / h)
    nw, nh = max(1, round(w * f)), max(1, round(h * f))
    out = img.resize((nw, nh), Image.LANCZOS)
    a = np.asarray(out).copy()
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)  # hard alpha
    return Image.fromarray(a)


def save(img, group, name):
    d = os.path.join(OUT, group)
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, name + ".png")
    img.save(path)
    manifest.setdefault(group, {})[name] = {"file": f"{group}/{name}.png", "w": img.width, "h": img.height}
    return path


def load(name):
    return key_magenta(Image.open(os.path.join(INC, name)))


def strip(frames, group, name):
    """Pack same-height frames into a horizontal strip anchored bottom-center."""
    cw = max(f.width for f in frames)
    ch = max(f.height for f in frames)
    out = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * cw + (cw - f.width) // 2, ch - f.height))
    save(out, group, name)
    manifest[group][name].update({"cell_w": cw, "cell_h": ch, "frames": len(frames)})


# ---------------------------------------------------------------- sheets

def char_updown(file, char_id, target_h):
    """4x4 sheet: walk toward, walk away, run toward, run away."""
    rgba = load(file)
    grid = cells_by_grid(rgba, 4, 4, inset=4)
    names = ["walk_down", "walk_up", "run_down", "run_up"]
    for r, name in enumerate(names):
        frames = [scale_to(crop(rgba, b), height=target_h) for b in grid[r] if b]
        strip(frames, "characters/" + char_id, name)


def dog_extra():
    rgba = load("dog_extra.png")
    grid = cells_by_grid(rgba, 4, 4, inset=4)
    for r, name in enumerate(["walk_down", "walk_up", "sit", "dig"]):
        frames = [scale_to(crop(rgba, b), height=40 if name != "dig" else 44) for b in grid[r] if b]
        strip(frames, "characters/dog", name)


def penguin():
    rgba = load("penguin_sheet.png")
    rows = cells_by_projection(rgba, region=(232, 0, 1536, 1024), row_gap=10, col_gap=14, min_size=40)
    rows = [r for r in rows if len(r) >= 4]
    assert len(rows) >= 6, len(rows)
    H = 64
    views = rows[0][:4]  # front, right, left, back
    for i, nm in enumerate(["view_front", "view_right", "view_left", "view_back"]):
        save(scale_to(crop(rgba, views[i]), height=H), "characters/penguin", nm)
    for r, name in zip(rows[1:6], ["idle", "walk", "run", "attack", "powerup"]):
        frames = [scale_to(crop(rgba, b), height=H if name != "powerup" else 76) for b in r[:4]]
        strip(frames, "characters/penguin", name)


def enemies():
    rgba = remove_thin_lines(load("enemies.png"), 3)
    # Each row has a dark label cell at the left; items in cells to its right.
    names = ["grump", "slime", "bat", "golem", "shard"]
    rows = cells_by_grid(rgba, 10, 5, region=(180, 68, 1774, 850), inset=12)
    heights = {"grump": 40, "slime": 30, "bat": 34, "golem": 70, "shard": 56}
    for r, nm in enumerate(names):
        cells = [b for b in rows[r] if b]
        h = heights[nm]
        strip([scale_to(crop(rgba, b), height=h) for b in cells[0:4]], "enemies/" + nm, "idle")
        strip([scale_to(crop(rgba, b), height=h) for b in cells[4:8]], "enemies/" + nm, "walk")
        strip([scale_to(crop(rgba, b), height=h) for b in cells[8:10]], "enemies/" + nm, "hurt")


def items():
    rgba = load("items.png")
    grid = cells_by_grid(rgba, 7, 4)
    ids = [
        "hoe", "can", "axe", "pickaxe", "rod", "iron_sword", "sword",
        "bow", "potion", "energy_tea", "green_potion", "crystal", "shard", "copper",
        "iron", "gold", "wood", "stone", "fiber", "seeds",
        "fish", "bread", "apple", "gift_pie", "letter", "key", "map",
    ]
    i = 0
    for row in grid:
        for b in row:
            if b is None or i >= len(ids):
                continue
            save(scale_to(crop(rgba, b), width=32, height=32), "items", ids[i]); i += 1


def crops():
    rgba = load("crops.png")
    names = ["turnip", "strawberry", "corn", "blueberry", "pumpkin", "dreamflower"]
    # Rows have different heights (corn is tall): use projection for rows, grid for columns.
    m = fg_mask(rgba)
    bands = [b for b in runs(m.any(axis=1), 8) if b[1] - b[0] > 40]
    assert len(bands) == 6, len(bands)
    for (rs, re), nm in zip(bands, names):
        cells = cells_by_grid(rgba, 6, 1, region=(0, rs, rgba.shape[1], re), inset=3)[0]
        tall = nm == "corn"
        frames = []
        for b in cells[:5]:
            frames.append(scale_to(crop(rgba, b), width=TILE2 - 2, height=(TILE2 * 2 - 4) if tall else TILE2 - 2))
        strip(frames, "crops", nm)
        if cells[5]:
            save(scale_to(crop(rgba, cells[5]), width=32, height=32), "items", nm)


def water():
    rgba = load("water_anim.png")
    rows = cells_by_projection(rgba, row_gap=4, col_gap=4, min_size=100)
    frames = [scale_to(crop(rgba, (b[0] + 6, b[1] + 6, b[2] - 6, b[3] - 6)), width=TILE2, height=TILE2, cover=True) for b in rows[0][:4]]
    strip(frames, "tiles", "water")
    frames = [scale_to(crop(rgba, (b[0] + 6, b[1] + 6, b[2] - 6, b[3] - 6)), width=TILE2, height=TILE2, cover=True) for b in rows[1][:4]]
    strip(frames, "tiles", "shore")


def ground():
    rgba = load("ground_tiles.png")
    # Four 3x3 sets on the top row, three on the second, six decorations on the third.
    top = [("grass", (18, 18, 380, 388)), ("dirt", (398, 18, 758, 388)),
           ("tilled_dry", (778, 18, 1140, 388)), ("tilled_wet", (1158, 18, 1520, 388))]
    mid = [("shore_set", (18, 420, 380, 792)), ("stone", (398, 420, 758, 792)), ("dock", (778, 420, 1140, 792))]
    for nm, reg in top + mid:
        grid = cells_by_projection(rgba, region=reg, row_gap=3, col_gap=3, min_size=60)
        tiles = [scale_to(crop(rgba, (b[0] + 4, b[1] + 4, b[2] - 4, b[3] - 4)), width=TILE2, height=TILE2, cover=True) for row in grid[:3] for b in row[:3]]
        sheet = Image.new("RGBA", (TILE2 * 3, TILE2 * 3))
        for i, t in enumerate(tiles):
            sheet.alpha_composite(t, ((i % 3) * TILE2, (i // 3) * TILE2))
        save(sheet, "tiles", nm)
    deco = cells_by_projection(rgba, region=(30, 830, 1000, 990), row_gap=3, col_gap=6, min_size=60)[0]
    for i, b in enumerate(deco[:6]):
        save(scale_to(crop(rgba, (b[0] + 3, b[1] + 3, b[2] - 3, b[3] - 3)), width=TILE2, height=TILE2), "tiles", f"deco_{i}")


def nature():
    rgba = load("nature.png")
    # Top row: oak, autumn oak, pine (tall), then a column of bush, berry bush, stump.
    boxes = {
        "oak": (0, 0, 440, 680), "oak_autumn": (440, 0, 870, 680), "pine": (870, 0, 1290, 680),
        "bush": (1290, 0, 1536, 230), "berry_bush": (1290, 230, 1536, 460), "stump": (1290, 460, 1536, 680),
        "rock_s": (0, 680, 200, 1024), "rock_m": (200, 680, 510, 1024), "rock_l": (510, 680, 860, 1024),
        "log": (860, 680, 1290, 1024), "flowers": (1290, 680, 1536, 1024),
    }
    sizes = {"oak": (96, 128), "oak_autumn": (96, 128), "pine": (80, 140), "bush": (40, 40), "berry_bush": (40, 40),
             "stump": (36, 36), "rock_s": (28, 28), "rock_m": (48, 48), "rock_l": (60, 60), "log": (64, 36), "flowers": (40, 40)}
    for nm, reg in boxes.items():
        b = bbox(fg_mask(rgba[reg[1]:reg[3], reg[0]:reg[2]]))
        box = (reg[0] + b[0], reg[1] + b[1], reg[0] + b[2], reg[1] + b[3])
        save(scale_to(crop(rgba, box), width=sizes[nm][0], height=sizes[nm][1]), "nature", nm)


def farmhouse():
    rgba = load("farmhouse.png")
    pick = {"house": (540, 520), "sellbox": (1150, 330), "mailbox": (1370, 330), "fence_post": (1070, 600),
            "fence_h": (1220, 600), "fence_v": (1400, 600), "sign": (1220, 820)}
    sizes = {"house": (6 * TILE2, 5 * TILE2 + 16), "sellbox": (40, 40), "mailbox": (24, 40), "fence_post": (16, 32),
             "fence_h": (32, 32), "fence_v": (16, 40), "sign": (28, 40)}
    for nm, (px, py) in pick.items():
        b = component_at(rgba, px, py)
        save(scale_to(crop(rgba, b), width=sizes[nm][0], height=sizes[nm][1]), "buildings", nm)


def town():
    rgba = load("town_buildings.png")
    pick = {"store": (250, 220), "smith": (770, 220), "potions": (1270, 220), "hall": (260, 720),
            "cottage_a": (850, 600), "cottage_b": (1290, 600), "well": (770, 880), "fountain": (1150, 880)}
    sizes = {"store": (6 * TILE2, 5 * TILE2 + 24), "smith": (6 * TILE2, 5 * TILE2 + 24), "potions": (5 * TILE2, 5 * TILE2 + 24),
             "hall": (8 * TILE2, 6 * TILE2 + 24), "cottage_a": (4 * TILE2, 4 * TILE2), "cottage_b": (4 * TILE2, 4 * TILE2),
             "well": (2 * TILE2, 2 * TILE2 + 16), "fountain": (3 * TILE2, 3 * TILE2)}
    for nm, (px, py) in pick.items():
        b = component_at(rgba, px, py, dilate=4)
        save(scale_to(crop(rgba, b), width=sizes[nm][0], height=sizes[nm][1]), "buildings", nm)


def farm_mixed():
    rgba = load("farm_mixed.png")
    pick = {"barn": (1010, 170), "greenhouse": (1225, 170), "windmill": (1430, 160), "scarecrow": (780, 830),
            "lamp": (640, 520), "stall": (960, 520), "cow": (1300, 830), "sheep": (1460, 830), "coop": (1100, 830),
            "well2": (1440, 520), "pine2": (655, 680), "beehive": (1000, 830), "arch": (850, 660), "oven": (990, 660), "anvil": (1240, 660), "workbench": (1420, 660),
            "signpost": (720, 520), "board": (820, 520), "crystal_rock": (1095, 950)}
    sizes = {"barn": (6 * TILE2, 6 * TILE2), "greenhouse": (5 * TILE2, 6 * TILE2), "windmill": (4 * TILE2, 7 * TILE2),
             "scarecrow": (32, 56), "lamp": (24, 56), "stall": (80, 64), "cow": (56, 44), "sheep": (48, 40), "coop": (72, 64),
             "well2": (48, 56), "pine2": (72, 120), "beehive": (36, 48),
             "arch": (72, 80), "oven": (56, 64), "anvil": (40, 32), "workbench": (72, 48), "signpost": (36, 56),
             "board": (60, 56), "crystal_rock": (40, 40)}
    for nm, (px, py) in pick.items():
        b = component_at(rgba, px, py, dilate=3)
        if b is None:
            print("  (farm_mixed: nothing at", nm, ")"); continue
        save(scale_to(crop(rgba, b), width=sizes[nm][0], height=sizes[nm][1]), "props", nm)


def ui():
    rgba = load("ui_kit.png")
    wood = cells_by_grid(rgba, 3, 3, region=(30, 112, 612, 745), trim=False)
    parch = cells_by_grid(rgba, 3, 3, region=(658, 112, 1216, 745), trim=False)
    for nm, grid in [("panel_wood", wood), ("panel_parchment", parch)]:
        tiles = [scale_to(crop(rgba, b), width=24, height=24) for row in grid for b in row]
        sheet = Image.new("RGBA", (72, 72))
        for i, t in enumerate(tiles):
            sheet.alpha_composite(t, ((i % 3) * 24, (i // 3) * 24))
        save(sheet, "ui", nm)
    pick = {"button": (1360, 230), "button_pressed": (1620, 230), "heart_full": (1290, 430), "heart_half": (1395, 430),
            "heart_empty": (1495, 430), "bolt_full": (1620, 430), "bolt_empty": (1710, 430), "crystal": (1325, 570),
            "bubble": (1490, 570), "arrow_up": (1300, 700), "arrow_down": (1425, 700), "arrow_left": (1550, 700), "arrow_right": (1690, 700)}
    sizes = {"button": (64, 64), "button_pressed": (64, 64)}
    for nm, (px, py) in pick.items():
        b = component_at(rgba, px, py, dilate=2)
        if b is None:
            print("  (ui: nothing at", nm, ")"); continue
        w, h = sizes.get(nm, (32, 32))
        save(scale_to(crop(rgba, b), width=w, height=h), "ui", nm)


def title():
    img = Image.open(os.path.join(INC, "title_key_art.png")).convert("RGBA")
    # Cover 270x480 at 2x = 540x960.
    w, h = img.size
    f = max(540 / w, 960 / h)
    img = img.resize((round(w * f), round(h * f)), Image.LANCZOS)
    cx, cy = img.width // 2, img.height // 2
    img = img.crop((cx - 270, cy - 480, cx + 270, cy + 480))
    save(img, "ui", "title_bg")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    mpath = os.path.join(OUT, "manifest.json")
    if os.path.exists(mpath):
        manifest.update(json.load(open(mpath)))
    steps = [
        ("dad", lambda: char_updown("dad_updown.png", "man", 74)),
        ("mom", lambda: char_updown("mom_updown.png", "woman", 78)),
        ("pax", lambda: char_updown("pax_updown.png", "son", 64)),
        ("kairi", lambda: char_updown("kairi_updown.png", "girl", 59)),
        ("dog", dog_extra), ("penguin", penguin), ("enemies", enemies), ("items", items), ("crops", crops),
        ("water", water), ("ground", ground), ("nature", nature), ("farmhouse", farmhouse), ("town", town),
        ("farm_mixed", farm_mixed), ("ui", ui), ("title", title),
    ]
    only = sys.argv[1:]
    for name, fn in steps:
        if only and name not in only:
            continue
        try:
            fn(); print("ok", name)
        except Exception as e:
            print("FAIL", name, repr(e))
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)
    # The golem row sits off the sheet's even grid: re-cut it between its own rule
    # lines, or every reslice brings back the keeper's cut-off head.
    if not only or "enemies" in only:
        try:
            import fix_keeper_art
            fix_keeper_art.main()
        except Exception as e:
            print("FAIL golem fix", repr(e))
