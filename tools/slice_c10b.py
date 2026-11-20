"""CONDUCT 10b P6: outdoor/yard decor renders + catalogue art-quality fixes.

One source for the prompts, grids and names of the C10b outdoor sheets (art/incoming/c10b/out_*),
plus slicer steps that fix C10a catalogue art (crops, trims, seams, recolours, kit copies).

  python3 tools/slice_c10b.py [step ...]   steps: sheets fixes kits fences check doc  (none = all)

Writes art/gen/decor/<id>.png (outdoor pieces drawn at 0.5 like the C10a set: one ground tile =
32 source px) and upserts rows into art/gen/decor/_catalog.json with layer "outdoor" plus
"sub" (path, fence, lamp, planter, flowerbed, statue, fountain, bench, arch, garden, sign,
seasonal, yard_gang, yard_penguin, showpiece), optional "season" and "desc".
Hardlinked art: every file is removed before it is written.
After: python3 tools/art_audit.py --fix <ids>, python3 tools/set_import_lossy.py,
flock godot --headless --import.
"""
import json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import slice_c10a as A

C, U, RA, E, L, M, Q = "common", "uncommon", "rare", "epic", "legendary", "mythic", "unique"
O = "outdoor"
SRC = "c10b/"

STYLE = ("16-bit pixel art outdoor garden and yard objects, top-down 3/4 view exactly like Stardew Valley / "
         "Sun Haven farm props, light from top-left, clean 1px dark outlines, crisp hard pixels, cosy "
         "saturated palette, transparent background, NO text, letters, numbers or logos anywhere, no "
         "watermark, no ground tile, no grass under the objects, no cast shadow on the background. All ages.")
GRID8 = A.GRID8
GRID_ANIM = A.GRID_ANIM
GRID3 = ("Exactly 3 separate objects in one row, each centred in its own equal third of the image, "
         "wide empty gaps between objects, nothing touching or overlapping.")

SHEETS = []
META = {}     # id -> {"sub", "season", "desc", "words"}


def Y(i, n, r, wh, sub, glow=0, season="", desc="", words=""):
    META[i] = {"sub": sub, "season": season, "desc": desc, "words": words}
    return A.P(i, n, O, r, wh, "floor", 1, glow)


def sheet(file, set_id, arc, theme, rows, grid=GRID8, kind="pieces", size="1536x1024"):
    SHEETS.append({"file": file, "set": set_id, "arc": arc, "theme": theme, "rows": rows,
                   "grid": grid, "kind": kind, "size": size})


sheet("out_garden_both.png", "yard_garden", "both", "Cosy cottage garden pieces",
      [[Y("dc_y_sundial", "Garden Sundial", U, [1, 1], "garden", words="a stone sundial on a short pillar"),
        Y("dc_y_stepping_stones", "Stepping Stones", C, [1, 1], "path", words="three round flat stepping stones in a short row (top-down, flat)"),
        Y("dc_y_herb_box", "Herb Planter Box", C, [2, 1], "planter", words="a long wooden planter box full of green herbs"),
        Y("dc_y_wheelbarrow", "Wheelbarrow Planter", U, [1, 1], "planter", words="an old wooden wheelbarrow planted with flowers")],
       [Y("dc_y_rain_barrel", "Rain Barrel", C, [1, 1], "garden", words="a wooden rain barrel with iron hoops and a little tap"),
        Y("dc_y_wind_spinner", "Wind Spinner", U, [1, 1], "garden", words="a colourful pinwheel wind spinner on a pole"),
        Y("dc_y_arbor_swing", "Arbor Swing Seat", RA, [2, 1], "bench", words="a wooden garden arbor with a hanging bench swing and climbing roses"),
        Y("dc_y_pin_statue", "Lawn Bowling Pin", RA, [1, 1], "statue", desc="A giant lawn pin from the Rec. Strike-proof.",
          words="a giant white bowling pin with red stripes standing as a lawn statue on a round stone base")]])
sheet("out_lights_both.png", "yard_lights", "both", "Garden and yard lights, lit up warm",
      [[Y("dc_y_tiki_torch", "Tiki Torch", C, [1, 1], "lamp", 36, "summer", words="a bamboo tiki torch with a small flame"),
        Y("dc_y_path_light", "Solar Path Light", C, [1, 1], "lamp", 20, words="a short black solar path light with a glowing top"),
        Y("dc_y_paper_lantern_post", "Paper Lantern Post", U, [1, 1], "lamp", 32, words="a wooden post with a round glowing paper lantern hanging from it"),
        Y("dc_y_twin_lamp", "Twin Iron Lamp Post", RA, [1, 1], "lamp", 44, words="a tall black iron lamp post with two glowing lamps on curled arms")],
       [Y("dc_y_string_posts", "String-Light Posts", U, [2, 1], "lamp", 40, words="two wooden posts with a sagging string of glowing bulbs between them"),
        Y("dc_y_hook_lantern", "Hook Lantern Post", C, [1, 1], "lamp", 32, words="a shepherd's hook post with a glowing iron lantern"),
        Y("dc_y_firefly_jar", "Firefly Jar Post", RA, [1, 1], "lamp", 28, words="a short post with a glass jar of glowing yellow fireflies"),
        Y("dc_y_candle_stand", "Candle Lantern Stand", U, [1, 1], "lamp", 28, words="a small iron stand holding a glass lantern with a lit candle")]])
sheet("out_seasonal.png", "yard_seasonal", "both", "Seasonal yard pieces for spring, summer, fall and winter",
      [[Y("dc_y_tulip_barrow", "Tulip Barrow", U, [1, 1], "seasonal", 0, "spring", words="a small cart full of red and yellow tulips"),
        Y("dc_y_picnic_set", "Picnic Blanket Set", C, [2, 1], "seasonal", 0, "spring", words="a red gingham picnic blanket with a wicker basket and fruit (top-down)"),
        Y("dc_y_lounger", "Striped Lounger", C, [1, 1], "seasonal", 0, "summer", words="a striped wooden deck chair lounger"),
        Y("dc_y_kiddie_pool", "Kiddie Pool", U, [2, 1], "seasonal", 0, "summer", words="a round inflatable blue kiddie pool with water and a rubber duck")],
       [Y("dc_y_lemonade_stand", "Lemonade Stand", RA, [2, 1], "seasonal", 0, "summer", words="a small wooden lemonade stand with a striped awning, a jug of lemonade and cups, no sign text"),
        Y("dc_y_leaf_pile", "Leaf Pile with Rake", C, [1, 1], "seasonal", 0, "fall", words="a pile of orange autumn leaves with a rake leaning in it"),
        Y("dc_y_hay_wall", "Hay Bale Wall", C, [2, 1], "seasonal", 0, "fall", words="three stacked square hay bales with a small pumpkin on top"),
        Y("dc_y_icicle_lamp", "Icicle Lamp Post", U, [1, 1], "seasonal", 36, "winter", words="a lamp post covered in snow and icicles, its lamp glowing pale blue")]])
sheet("out_gang_a.png", "yard_gang", "gangsters", "Friendly city-crew yard and street pieces (all ages, no weapons)",
      [[Y("dc_y_lowrider_teal", "Teal Lowrider", E, [3, 1], "yard_gang", desc="Parked for show. Polished to a mirror shine.", words="a long teal lowrider classic car seen from the side, chrome wire wheels"),
        Y("dc_y_lowrider_purple", "Purple Lowrider", E, [2, 2], "yard_gang", desc="Parked for show. Polished to a mirror shine.", words="a purple lowrider classic car seen from the front at 3/4, chrome grille, gold flake paint"),
        Y("dc_y_hydrant", "Fire Hydrant", C, [1, 1], "yard_gang", words="a red city fire hydrant"),
        Y("dc_y_cones", "Cones and Barricade", C, [2, 1], "yard_gang", words="a striped orange and white road barricade with two traffic cones")],
       [Y("dc_y_speakers", "Speaker Stack", U, [1, 1], "yard_gang", words="a stack of two big black loudspeakers"),
        Y("dc_y_grill", "Charcoal Grill", C, [1, 1], "yard_gang", words="a round black kettle charcoal grill on legs with a little smoke"),
        Y("dc_y_hoop", "Basketball Hoop", U, [1, 1], "yard_gang", words="a street basketball hoop on a pole with a chain net and a ball beside it"),
        Y("dc_y_vending", "Street Snack Machine", U, [1, 1], "yard_gang", 28, words="a glowing outdoor snack vending machine with chips and candy behind glass")]])
sheet("out_gang_b.png", "yard_gang", "gangsters", "Neon city-crew yard pieces (all ages)",
      [[Y("dc_y_neon_arrow", "Neon Arrow Pole Sign", U, [1, 1], "yard_gang", 36, words="a tall pole with a hot pink neon arrow sign pointing down, no letters"),
        Y("dc_y_neon_palm", "Neon Palm Pole", RA, [1, 1], "yard_gang", 40, words="a tall palm tree shape outlined in glowing cyan and green neon tubes"),
        Y("dc_y_neon_arch", "Neon Arch", E, [2, 1], "arch", 44, words="a garden arch made of glowing magenta and cyan neon tubes on black posts"),
        Y("dc_y_bulb_poles", "Bulb-String Poles", U, [2, 1], "yard_gang", 40, words="two metal poles with a string of big warm round light bulbs")],
       [Y("dc_y_tyre_stack", "Tyre Stack", C, [1, 1], "yard_gang", words="a stack of four black car tyres"),
        Y("dc_y_car_lift", "Car on a Lift", E, [2, 1], "yard_gang", desc="Parked for show. Polished to a mirror shine.", words="a small red classic car raised on a yellow garage lift"),
        Y("dc_y_tag_wall", "Tagged Brick Wall", C, [2, 1], "yard_gang", words="a freestanding short brick wall panel with colourful abstract stars, crowns and arrows painted on it, no letters"),
        Y("dc_y_neon_frame", "Neon Sign Frame", U, [2, 1], "sign", 36, words="a black metal sign frame on two posts with a glowing pink and blue neon star and crown inside, no letters")]])
sheet("out_penguin.png", "yard_penguin", "penguins", "Cute penguin-village snowy yard pieces",
      [[Y("dc_y_penguin_statue", "Penguin Garden Statue", RA, [1, 1], "yard_penguin", words="a stone statue of a cute penguin on a round plinth"),
        Y("dc_y_penguin_topiary", "Penguin Topiary", U, [1, 1], "yard_penguin", words="a green hedge clipped into the shape of a penguin in a pot"),
        Y("dc_y_fish_vane", "Fish Weathervane", U, [1, 1], "yard_penguin", words="a tall copper weathervane topped with a fish"),
        Y("dc_y_igloo_lantern", "Igloo Lantern", U, [1, 1], "yard_penguin", 32, words="a small snow-block igloo lantern glowing warm from inside")],
       [Y("dc_y_snow_fort", "Snow Fort Wall", C, [2, 1], "yard_penguin", 0, "winter", words="a low wall of packed snow blocks with a stack of snowballs"),
        Y("dc_y_shell_bed", "Shell and Coral Bed", C, [2, 1], "flowerbed", words="a garden bed edged with seashells holding pink coral and sea flowers"),
        Y("dc_y_ice_slide", "Penguin Ice Slide", E, [2, 2], "yard_penguin", words="a small curved ice slide with steps, for penguins to play on"),
        Y("dc_y_star_planter", "Star-Crystal Planter", U, [1, 1], "planter", 28, words="a stone planter with glowing aqua star-shaped crystals growing in it")]])
sheet("out_show_a.png", "yard_show", "both", "Animated yard showpieces",
      [[Y("dc_y_koi_pond", "Koi Pond", L, [2, 2], "fountain", 0, words="a round stone-edged garden pond with lily pads and orange and white koi swimming around")],
       [Y("dc_y_lowrider_bounce", "Lowrider Bounce", L, [3, 1], "showpiece", 0, words="a shiny candy-red lowrider car seen from the side, bouncing up and down on its hydraulics (the wheels stay on the ground line)")],
       [Y("dc_y_neon_chase_arch", "Neon Chase Arch", E, [2, 1], "arch", 44, words="a neon tube garden arch whose magenta and cyan lights chase along it")]],
      grid=GRID_ANIM, kind="anim")
sheet("out_show_b.png", "yard_show", "penguins", "Animated yard showpieces",
      [[Y("dc_y_crystal_fountain", "Crystal Plaza Fountain", M, [2, 2], "fountain", 48, words="a tiered fountain carved from pale blue crystal, water sparkling with light motes")],
       [Y("dc_y_aurora_lamp", "Northern-Lights Lamp", L, [1, 1], "lamp", 48, words="a tall silver lamp post whose glass lamp swirls with green and violet northern lights")],
       [Y("dc_y_star_well", "Wishing-Star Well", M, [2, 2], "garden", 40, words="a round stone wishing well with a little roof, a glowing star twinkling above the water")]],
      grid=GRID_ANIM, kind="anim")
sheet("out_uniques.png", "yard_unique", "both", "Three one-of-a-kind yard showpieces",
      [[Y("dc_y_u_star_shrine", "Star Crystal Shrine", Q, [2, 2], "showpiece", 48, desc="Raised where the story's star came home.",
          words="a small stone shrine with a glowing star-shaped crystal on top, little penguin carvings and blue lanterns"),
        Y("dc_y_u_gold_lowrider", "Golden Lowrider", Q, [3, 1], "showpiece", desc="The crew's pride. Nobody drives it; everybody polishes it.",
          words="a gold-plated chrome lowrider classic car seen from the side, sparkling"),
        Y("dc_y_u_bell_tower", "Bell Tower Miniature", Q, [1, 1], "showpiece", desc="A tiny copy of the valley's old bell tower.",
          words="a miniature stone village bell tower with a bronze bell, about waist high")]],
      grid=GRID3)
sheet("out_fences.png", "yard_fence", "both", "Garden fence pieces seen from the top-down 3/4 view",
      [[Y("dc_y_fence_wood_v", "Wood Fence (side)", C, [1, 1], "fence", words="a wooden rail fence section running away from the viewer (vertical on screen, seen end-on)"),
        Y("dc_y_fence_iron_v", "Iron Fence (side)", U, [1, 1], "fence", words="a black iron railing section running away from the viewer (vertical on screen)"),
        Y("dc_y_fence_stone_v", "Stone Wall (side)", U, [1, 1], "fence", words="a low grey stone wall section running away from the viewer (vertical on screen)"),
        Y("dc_y_fence_picket_v", "Picket Fence (side)", C, [1, 1], "fence", words="a white picket fence section running away from the viewer (vertical on screen)")],
       [Y("dc_y_fence_neon", "Neon-Trim Fence", RA, [1, 1], "fence", 24, words="a short black metal fence section running left to right with a glowing magenta neon tube along its top"),
        Y("dc_y_fence_neon_v", "Neon-Trim Fence (side)", RA, [1, 1], "fence", 24, words="the same neon-trimmed black fence running away from the viewer (vertical on screen)"),
        Y("dc_y_fence_ice", "Ice-Brick Fence", U, [1, 1], "fence", words="a low fence of pale blue ice bricks running left to right"),
        Y("dc_y_fence_ice_v", "Ice-Brick Fence (side)", U, [1, 1], "fence", words="the same ice-brick fence running away from the viewer (vertical on screen)")]])

ARC_ROW = {"out_gang_a.png": "gangsters", "out_gang_b.png": "gangsters", "out_penguin.png": "penguins"}
PIECE_ARC = {"dc_y_koi_pond": "both", "dc_y_lowrider_bounce": "gangsters", "dc_y_neon_chase_arch": "gangsters",
             "dc_y_u_star_shrine": "penguins", "dc_y_u_gold_lowrider": "gangsters", "dc_y_u_bell_tower": "both",
             "dc_y_fence_neon": "gangsters", "dc_y_fence_neon_v": "gangsters", "dc_y_fence_ice": "penguins",
             "dc_y_fence_ice_v": "penguins", "dc_y_aurora_lamp": "penguins", "dc_y_crystal_fountain": "penguins",
             "dc_y_star_well": "both"}

PATHS = [("dc_y_path_neon_asphalt", "Neon Fleck Asphalt", U, "gangsters", "dark charcoal asphalt with small sparse glowing magenta and cyan glitter flecks evenly scattered"),
         ("dc_y_path_checker", "Checker Plate Path", C, "gangsters", "grey diamond-pattern steel checker plate"),
         ("dc_y_path_ice_brick", "Ice Brick Path", C, "penguins", "pale blue ice bricks laid in a running bond"),
         ("dc_y_path_pebble", "Pebble Mosaic Path", U, "both", "a mosaic of small round grey and cream river pebbles")]


def prompt(s):
    if s["file"] == "out_paths.png":
        return "%s %s." % (A.TEX4, "; ".join("%s: %s" % (["top-left", "top-right", "bottom-left", "bottom-right"][k], p[4])
                                              for k, p in enumerate(PATHS)) + ". Outdoor ground paving for a game, seen from straight above")
    lines = [STYLE, s["grid"], "Theme: %s." % s["theme"]]
    for k, row in enumerate(s["rows"]):
        if s["kind"] == "anim":
            lines.append("Row %d: %s (%s)." % (k + 1, META[row[0][0]]["words"], row[0][1]))
        else:
            lines.append("Row %d left to right: %s." % (k + 1, "; ".join(META[p[0]]["words"] for p in row)))
    if s["kind"] == "anim":
        lines.append("Each object is drawn large and fills most of its cell; every row is one object only.")
    else:
        lines.append("Keep every object the same pixel scale (one ground tile = 32 pixels) and the same art style.")
    return " ".join(lines)




# =====================================================================================
# Slicer
# =====================================================================================
GROUP = A.GROUP
CELL, FILL = A.CELL, A.FILL
ROWS = {}     # id -> catalogue row written by this slicer


def _S():
    return A._S()


def rgba(file):
    """Renders with a real transparent background keep their own alpha: keying magenta would eat the
    magenta neon tubes (neon arch, chase arch)."""
    import numpy as np
    from PIL import Image
    src = np.asarray(Image.open(os.path.join(_S().INC, SRC + file)).convert("RGBA")).copy()
    if (src[..., 3] == 0).mean() > 0.2:
        src[src[..., 3] < 16] = 0
        return src
    A.SRC = SRC
    try:
        return A.rgba_of(file)
    finally:
        A.SRC = "c10/"


def _row(p, s, **extra):
    i, n, cat, r, wh, layer, rot, glow = p
    m = META.get(i, {})
    e = {"id": i, "name": n, "cat": cat, "rarity": r, "arc": PIECE_ARC.get(i, s["arc"]), "layer": "outdoor",
         "size": list(wh), "rot": 1, "glow": glow, "set": s["set"], "sheet": s["file"], "sub": m.get("sub", "")}
    if m.get("season"):
        e["season"] = m["season"]
    if m.get("desc"):
        e["desc"] = m["desc"]
    e.update(extra)
    ROWS[i] = e
    return e


HMAX = {"dc_y_tiki_torch": 2.3, "dc_y_wind_spinner": 1.9, "dc_y_path_light": 1.0, "dc_y_hydrant": 1.3,
        "dc_y_fish_vane": 2.2, "dc_y_neon_arrow": 2.4, "dc_y_neon_palm": 2.4, "dc_y_firefly_jar": 1.8,
        "dc_y_candle_stand": 1.7, "dc_y_hook_lantern": 2.0, "dc_y_icicle_lamp": 2.5, "dc_y_aurora_lamp": 2.6}


def fit(p, im):
    """Outdoor scale: footprint width (32 src px per cell, drawn at 0.5), capped by a height per piece:
    vertical fence runs 1.6 cells, lamps 2.6, other one-cell pieces 2.8, wider pieces footprint+1.8."""
    w, h = p[4]
    f = CELL * w * FILL / im.width
    if p[0].endswith("_v"):
        cap = 1.6
    else:
        cap = HMAX.get(p[0]) or (2.6 if META.get(p[0], {}).get("sub") == "lamp" else 2.8 if w == 1 else h + 1.8)
    return min(f, CELL * cap / im.height)


def sheet_pieces(s):
    a = rgba(s["file"])
    rows = s["rows"]
    boxes = A.cells(a, len(rows), len(rows[0]))
    for r, row in enumerate(rows):
        for c, p in enumerate(row):
            im = A._crop(a, boxes[r][c])
            out = A._scaled(im, fit(p, im))
            A.save(out, p[0])
            _row(p, s, px=list(out.size))


def sheet_anim(s):
    from PIL import Image
    a = rgba(s["file"])
    boxes = A.cells(a, 3, 4)
    for r, row in enumerate(s["rows"]):
        p = row[0]
        crops = [A._crop(a, b) for b in boxes[r]]
        W = max(im.width for im in crops); H = max(im.height for im in crops)
        f = fit(p, Image.new("RGBA", (W, H)))
        frames = [A._scaled(im, f) for im in crops]
        fw, fh = max(x.width for x in frames), max(x.height for x in frames)
        padded = []
        for x in frames:      # bottom-centred on one canvas so the base never jumps
            o = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
            o.alpha_composite(x, ((fw - x.width) // 2, fh - x.height))
            padded.append(o)
        A.save_strip(padded, p[0])
        A.save(padded[0], p[0] + "_icon")
        _row(p, s, frames=4, fps=A.FPS, px=[fw, fh], icon=p[0] + "_icon")


def sheet_three(s):
    a = rgba(s["file"])
    boxes = A.cells(a, 1, 3)
    for c, p in enumerate(s["rows"][0]):
        im = A._crop(a, boxes[0][c])
        out = A._scaled(im, fit(p, im))
        A.save(out, p[0])
        _row(p, s, px=list(out.size))


def paths():
    import numpy as np
    from PIL import Image
    S = _S()
    a = np.asarray(Image.open(os.path.join(S.INC, SRC + "out_paths.png")).convert("RGBA")).astype(np.int32)
    s = {"set": "yard_path", "file": "out_paths.png"}
    for (i, n, r, arc, _), b in zip(PATHS, A.swatch_boxes(a)):
        im, how = A.tile_from(a[b[1]:b[3], b[0]:b[2]])
        A.save(im, i)
        A.save(_round_icon(im), i + "_icon")
        META[i] = {"sub": "path"}
        _row(A.P(i, n, O, r, [1, 1], "floor"), dict(s, arc=arc), px=[256, 256], period_cells=8, tile=how, icon=i + "_icon")


def _round_icon(im):
    """32x32 rounded crop of a seamless tile (catalogue icon for a path)."""
    from PIL import Image, ImageDraw
    ic = im.resize((128, 128), Image.LANCZOS).crop((32, 32, 96, 96)).resize((32, 32), Image.NEAREST).convert("RGBA")
    m = Image.new("L", (32, 32), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 31, 31), radius=7, fill=255)
    ic.putalpha(m)
    return ic


# Existing fence/hedge runs normalised to whole cells (c10b_03: gaps at grid steps).
FENCE_RUNS = [  # (id, name, rarity, arc, source art, cells wide)
    ("dc_y_fence_wood", "Wood Rail Fence", C, "both", "props/fence2_wood_h", 1),
    ("dc_y_fence_iron", "Iron Railing", U, "both", "props/fence2_iron_h", 1),
    ("dc_y_fence_stone", "Low Stone Wall", U, "both", "props/fence2_stone_h", 1),
    ("dc_y_fence_picket", "White Picket Fence", C, "both", "props/picket2_h", 2),
    ("dc_y_fence_gold", "Gilded Fence", E, "gangsters", "props/gold_fence_a", 2),
    ("dc_y_hedge_run", "Clipped Hedge Run", C, "both", "props/hedge2_h", 2),
]


def fences():
    from PIL import Image
    S = _S()
    s = {"set": "yard_fence", "file": "existing props"}
    for i, n, r, arc, src, w in FENCE_RUNS:
        f = os.path.join(S.OUT, src + ".png")
        if not os.path.exists(f):
            print("skip fence", src); continue
        im = Image.open(f).convert("RGBA")
        im = im.crop(im.getbbox())
        tw = CELL * w
        out = _S().scale_to(im, width=tw, height=max(1, round(im.height * tw / im.width)))
        A.save(out, i)
        META[i] = {"sub": "fence"}
        _row(A.P(i, n, O, r, [w, 1], "floor"), dict(s, arc=arc), px=list(out.size), joins=True)


# Kit pieces copied out of art/gen/kits (excluded from the web export) - c10b_03.
KITS = [  # (id, name, rarity, arc, kit file, cells, sub, glow)
    ("dc_y_camp_tent", "Camping Tent", RA, "both", "props/prismatica_kit_14", [2, 2], "garden", 0),
    ("dc_y_fire_pit", "Stone Fire Pit", U, "both", "props/prismatica_kit_11", [1, 1], "garden", 32),
    ("dc_y_sleeping_bag", "Sleeping Bag", C, "both", "props/prismatica_kit_15", [1, 1], "garden", 0),
    ("dc_y_sleeping_bag_b", "Striped Sleeping Bag", C, "both", "props/prismatica_kit_16", [1, 1], "garden", 0),
    ("dc_y_crystal_cluster", "Yard Crystal Cluster", U, "penguins", "props/prismatica_kit_19", [1, 1], "yard_penguin", 24),
    ("dc_y_crystal_cluster_b", "Glowing Crystal Spire", RA, "penguins", "props/prismatica_kit_23", [1, 1], "yard_penguin", 28),
    ("dc_y_cat_tower", "Garden Cat Tower", U, "penguins", "props/cattopia_kit_20", [1, 1], "yard_penguin", 0),
    ("dc_y_cat_tower_b", "Tall Cat Tower", RA, "penguins", "props/cattopia_kit_21", [1, 1], "yard_penguin", 0),
    ("dc_y_lantern_post_kit", "Cat Lantern Post", U, "both", "props/cattopia_kit_27", [1, 1], "lamp", 32),
    ("dc_y_cairn", "Trail Cairn", C, "both", "props/secrets_kit_14", [1, 1], "garden", 0),
    ("dc_y_boulder", "Mossy Boulder", C, "both", "props/secrets_kit_36", [1, 1], "garden", 0),
    ("dc_y_boulder_b", "Mossy Boulder Pair", C, "both", "props/secrets_kit_37", [2, 1], "garden", 0),
]


def kits():
    from PIL import Image
    S = _S()
    s = {"set": "yard_kit", "file": "kits"}
    for i, n, r, arc, src, wh, sub, glow in KITS:
        f = os.path.join(S.OUT, "kits", src + ".png")
        if not os.path.exists(f):
            print("skip kit", src); continue
        im = Image.open(f).convert("RGBA")
        im = im.crop(im.getbbox())
        p = A.P(i, n, O, r, wh, "floor", 1, glow)
        out = A._scaled(im, min(1.0, fit(p, im)))      # never upscale kit art
        A.save(out, i)
        META[i] = {"sub": sub}
        _row(p, dict(s, arc=arc), px=list(out.size))


# =====================================================================================
# C10a catalogue art fixes (c10b_08)
# =====================================================================================
def _out(group, name):
    return os.path.join(_S().OUT, group, name + ".png")


def _write(img, group, name):
    """Replace art/gen/<group>/<name>.png (hardlinked art: remove first) and its manifest size."""
    S = _S()
    p = _out(group, name)
    old = dict(S.manifest.get(group, {}).get(name, {}))
    if os.path.exists(p):
        os.remove(p)
    S.save(img, group, name)
    fr = int(old.get("frames", 1) or 1)
    if fr > 1:
        S.manifest[group][name].update({k: v for k, v in old.items() if k not in ("w", "h", "file", "cell_w", "cell_h")})
        S.manifest[group][name].update({"frames": fr, "cell_w": img.width // fr, "cell_h": img.height})


def _open(group, name):
    from PIL import Image
    return Image.open(_out(group, name)).convert("RGBA")


ORIG_REV = "bfe8a6c34"    # C10b base: crop/trim fixes always start from the art as it was (re-runnable)


def _orig(group, name):
    import io, subprocess
    from PIL import Image
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    try:
        b = subprocess.run(["git", "-C", root, "show", "%s:art/gen/%s/%s.png" % (ORIG_REV, group, name)],
                           capture_output=True, check=True).stdout
        return Image.open(io.BytesIO(b)).convert("RGBA")
    except Exception:
        return _open(group, name)


def fix_tex():
    """Periodic redraws of seamless pieces with cross-fade ghosts (c10b_08-01/02/03/16)."""
    import numpy as np
    from PIL import Image
    S = _S()
    a = np.asarray(Image.open(os.path.join(S.INC, SRC + "out_fix_tex.png")).convert("RGBA")).astype(np.int32)
    boxes = A.swatch_boxes(a)
    hows = {}
    for nm, b in zip(["dc_wp_penguin_print", "dc_fl_tatami", "dc_fl_casino_carpet", "fl_carpet_purple"], boxes):
        sw = a[b[1]:b[3], b[0]:b[2]]
        if nm in ("dc_wp_penguin_print", "dc_fl_tatami"):
            im, how = _exact_tile(sw)
        else:
            im, how = A.tile_from(sw)
        hows[nm] = how
        if nm == "dc_wp_penguin_print":
            # the wall shows rows 0-63: roll (exact wrap) so the quietest row is the top edge,
            # so no penguin is cut at the top of the wall strip
            l = np.asarray(im.convert("L")).astype(float)
            per = 64
            v = [l[y].std() for y in range(per)]
            im = Image.fromarray(np.roll(np.asarray(im), -int(np.argmin(v)), 0))
        if nm == "fl_carpet_purple":
            ref = _open("tiles", nm)
            _write(im.resize(ref.size, Image.LANCZOS), "tiles", nm)
            continue
        A.save(im, nm)
        A.save(im.crop((112, 112, 144, 144)), nm + "_icon")
    return hows


def _exact_tile(sw):
    """Two pattern periods on axes with a short period, one period between the dark border lines on
    long ones (tatami mats): the 256 output wraps exactly and the wall's 64-px band holds whole rows."""
    import numpy as np
    from PIL import Image
    l = sw[..., :3].mean(2)
    out = []
    for axis in (1, 0):
        pr = A._period(l, axis)
        if pr:
            out.append((0, 2 * pr, pr))
            continue
        prof = l.mean(0 if axis == 1 else 1)
        dark = np.where(prof < prof.mean() - 25)[0]
        starts = [int(d) for k, d in enumerate(dark) if k == 0 or d != dark[k - 1] + 1]
        out.append((starts[0], starts[1], starts[1] - starts[0]) if len(starts) > 1 else (0, len(prof), 0))
    (x0, x1, px), (y0, y1, py) = out
    crop = sw[y0:y1, x0:x1].astype(np.uint8)
    im = Image.fromarray(crop).resize((256, 256), Image.LANCZOS).convert("RGBA")
    a = np.asarray(im).copy(); a[..., 3] = 255
    return Image.fromarray(a), "exact x:%d y:%d" % (px, py)


# piece fixes from out_fix_pieces.png: (cell, id, how, box)  how: wall/top/floor
FIX_PIECES = [((0, 0), "dc_catkins_bell", "wall", (30, 44)), ((0, 1), "dc_top_hourglass", "top", (30, 30)),
              ((0, 2), "dc_top_ice_crystal", "top", (30, 30)), ((0, 3), "dc_koi_scroll", "wall", (40, 48)),
              ((1, 0), "dc_founders_orrery", "floor", (30, 64)), ((1, 1), "dc_master_hearth", "floor", (60, 64)),
              ((1, 2), "dc_collectors_shelf", "floor", (30, 64)), ((1, 3), "dc_lucky_cat_gold", "floor", (30, 40))]


def fix_pieces(cat):
    a = rgba("out_fix_pieces.png")
    boxes = A.cells(a, 2, 4)
    for (r, c), i, how, (bw, bh) in FIX_PIECES:
        im = A._crop(a, boxes[r][c])
        f = min(bw / im.width, bh / im.height) if how != "floor" else min(bw * FILL / im.width, bh / im.height)
        out = A._scaled(im, f)
        A.save(out, i)
        if i in cat:
            cat[i]["px"] = list(out.size)
    if "dc_lucky_cat_gold" not in cat:
        cat["dc_lucky_cat_gold"] = {"id": "dc_lucky_cat_gold", "name": "Golden Lucky Cat", "cat": "decor", "rarity": "rare",
                                    "arc": "both", "layer": "floor", "size": [1, 1], "rot": 1, "glow": 0, "set": "",
                                    "sheet": "out_fix_pieces.png", "px": list(_open(GROUP, "dc_lucky_cat_gold").size)}


def fix_table_sides(cat):
    """Side views at the front's scale, cushions kept (c10b_08-30)."""
    from PIL import ImageOps
    S = _S()
    a = rgba("out_fix_table_sides.png")
    boxes = A.cells(a, 1, 4)[0]
    for b, base in zip(boxes, ["dc_catkins_table", "dc_coral_table", "dc_ice_table", "dc_grotto_table"]):
        im = A._crop(a, b)
        front = _open(GROUP, base)
        f = min(front.height * 0.8 / im.height, 46 / im.width)
        out = A._scaled(im, f)
        A.save(out, base + "_r1")
        A.save(ImageOps.mirror(out), base + "_r3")


def _strict_recolour(img, target, lo_sat=0.4):
    """Fabric recolour that never touches wood browns or creams (c10b_08-14)."""
    import numpy as np
    from PIL import Image
    hsv = np.asarray(img.convert("RGB").convert("HSV")).astype(float)
    h, sat, val = hsv[..., 0] * 360 / 255, hsv[..., 1] / 255, hsv[..., 2] / 255
    al = np.asarray(img.convert("RGBA"))[..., 3]
    m = (al > 0) & (sat > lo_sat) & (val > 0.2) & ~((h >= 12) & (h <= 55))
    if m.sum() < 30:
        return None
    hist, _ = np.histogram(h[m], bins=36, range=(0, 360))
    base = (np.argmax(hist) + 0.5) * 10
    d = (h - base + 180) % 360 - 180
    sel = m & (np.abs(d) < 18)
    out = hsv.copy()
    out[..., 0] = np.where(sel, ((target + d) % 360) * 255 / 360, hsv[..., 0])
    rgb2 = np.asarray(Image.fromarray(out.astype(np.uint8), "HSV").convert("RGB"))
    o = np.asarray(img.convert("RGBA")).copy()
    o[..., :3] = np.where(sel[..., None], rgb2, o[..., :3])
    return Image.fromarray(o)


def fix_tent_mid():
    """wl_tent_m had a transparent right band and an outline column: a black gap between every wall
    column (c10b_08-17). New mid = the outline-free drape of wl_tent_l, wrapped with a 3-px blend."""
    import numpy as np
    from PIL import Image
    src = np.asarray(_orig("tiles", "wl_tent_l")).astype(float)[:, 3:]
    w = src.shape[1]
    k = 3
    out = src.copy()
    for i in range(k):      # blend the last k columns toward the first ones so the run wraps
        t = (i + 1) / (k + 1)
        out[:, w - k + i] = src[:, w - k + i] * (1 - t) + src[:, i] * t
    im = Image.fromarray(out.clip(0, 255).astype(np.uint8)).resize((32, 64), Image.NEAREST)
    _write(im, "tiles", "wl_tent_m")


WINTER_TWINS = {"out_winter_twins.png": ["flowerbed_pink", "hedge2_h", "topiary_a", "hedge2_ball",
                                         "bench2_wood_a", "statue", "trellis", "stone_arch"],
                "out_winter_twins_b.png": ["flowerbed_blue", "flowerbed_red", "flowerbed_yellow", "topiary_b",
                                           "bench2_iron_a", "wedding_arch", "cat_statue", "statue_cane"],
                "out_winter_twins_c.png": ["picket2_h", "fence2_wood_h", "fence2_iron_h", "fence2_stone_h",
                                           "bench2_green_a", "well_stone", "birdbath", "scarecrow_knight"]}


def winter_twins():
    """props/<name>_winter for garden props that stayed summer-green in snow (c10b_03); WorldGen.WINTER_LOOKS
    lists them (P2 hook). Each twin is drawn at its summer piece's exact size so footprints never change."""
    for file, names in WINTER_TWINS.items():
        a = rgba(file)
        boxes = A.cells(a, 2, 4)
        for k, nm in enumerate(names):
            ref = _open("props", nm)
            im = A._crop(a, boxes[k // 4][k % 4])
            out = _S().scale_to(im, width=ref.width, height=ref.height)
            _write(out, "props", nm + "_winter")


def wall_rules():
    """Magenta key rules left on the edge rows of tile-kit wall pieces (c10b_08-29): a top/bottom row
    that is mostly key-pink takes the colour of the nearest clean row. Interior detail is untouched."""
    import glob
    import numpy as np
    from PIL import Image
    fixed = []
    for f in sorted(glob.glob(os.path.join(_S().OUT, "tiles", "wl_*.png"))):
        nm = os.path.basename(f)[:-4]
        if nm == "wl_tent_m":       # rebuilt by fix_tent_mid
            continue
        a = np.asarray(_orig("tiles", nm)).astype(int).copy()
        H = a.shape[0]
        r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
        pink = (al > 0) & (r - g > 60) & (b - g > 40)
        frac = pink.sum(1) / np.maximum(1, (al > 0).sum(1))
        rule = [y for y in list(range(3)) + list(range(H - 3, H)) if frac[y] > 0.4]
        if not rule:
            continue
        clean = [y for y in range(H) if y not in rule and frac[y] < 0.05]
        for y in rule:
            src = min(clean, key=lambda c: abs(c - y))
            a[y] = a[src]
        _write(Image.fromarray(a.astype(np.uint8)), "tiles", nm)
        fixed.append(nm)
    return fixed


GLINT = ["trophy_fish_a", "cat_figurine", "fossil_shell", "candle"]   # c10b_08-32


def tabletop_copies():
    """decor/dc_tt_<icon>: the bag icon without its floating inventory glint, for the placed piece
    (gen_decor uses it as art when it exists; the bag icon stays as the icon)."""
    import numpy as np
    from PIL import Image
    from scipy import ndimage
    for nm in GLINT:
        if not os.path.exists(_out("items", nm)):
            continue
        a = np.asarray(_orig("items", nm)).copy()
        r, g, b = (a[..., k].astype(int) for k in range(3))
        box = np.zeros(a.shape[:2], bool)
        box[:14, :14] = True                 # the inventory glint sits at the top-left
        blue = ((b >= r - 5) & (b >= g) & ((b - np.minimum(r, g) > 25) | (r + g + b > 700))) | ((b > g + 30) & (r > g + 30))
        if nm != "snow_heart":
            a[box & blue, 3] = 0
        lab, n = ndimage.label(a[..., 3] > 0, structure=np.ones((3, 3)))
        if n > 1:
            sizes = ndimage.sum(np.ones(lab.shape), lab, range(1, n + 1))
            for k in range(1, n + 1):
                if sizes[k - 1] < 0.06 * sizes.max():
                    a[lab == k, 3] = 0
        im = Image.fromarray(a)
        A.save(im.crop(im.getbbox()), "dc_tt_" + nm)


def fix_colourways():
    for base, cols in (("dc_rustic_bed", ["forest", "navy"]), ("dc_rug_persian", ["navy"])):
        for c in cols:
            hue = A.HUES[c][0]
            for suf in ("", "_r1", "_r2", "_r3"):
                if os.path.exists(_out(GROUP, base + suf)):
                    im = _strict_recolour(_open(GROUP, base + suf), hue)
                    if im is not None:
                        A.save(im, "%s_%s%s" % (base, c, suf))


def _trim_rows(group, name, top=0, bottom=0):
    im = _orig(group, name)
    im = im.crop((0, top, im.width, im.height - bottom))
    bb = im.getbbox()
    _write(im.crop(bb) if bb else im, group, name)


def _band_top(im):
    """First opaque row after a fully transparent gap below a top band (baked caption plates)."""
    import numpy as np
    al = np.asarray(im)[..., 3] > 0
    rows = al.any(1)
    y = 0
    while y < len(rows) and rows[y]:
        y += 1
    if 0 < y < len(rows) * 0.3:
        while y < len(rows) and not rows[y]:
            y += 1
        return y
    return 0


def fix_crops(cat):
    """Captions, uncut pairs, pads, slivers (c10b_08-04/05/12/31/32)."""
    import numpy as np
    from PIL import Image
    # caption plates baked into catalogue furniture
    for nm, top, bottom in (("table2_long4", 9, 0), ("table2_round", 9, 0), ("dog_bed", 3, 0)):
        im = _orig("furniture", nm)
        t = _band_top(im) or top
        _trim_rows("furniture", nm, top=t)
    im = _orig("furniture", "library_ladder")       # 'Library Ladder' text rows 51-55
    a = np.asarray(im).copy()
    a[50:, :, 3] = 0
    _write(Image.fromarray(a).crop(Image.fromarray(a).getbbox()), "furniture", "library_ladder")
    # two stacked plates: red keeps the id, navy becomes a colourway
    im = _orig(GROUP, "dc_gart_car_plate")
    al = np.asarray(im)[..., 3] > 0
    rows = np.where(~al.any(1))[0]
    gap = [y for y in rows if 8 < y < im.height - 8]
    cut = gap[0] if gap else 22
    red, navy = im.crop((0, 0, im.width, cut)), im.crop((0, cut, im.width, im.height))
    A.save(red.crop(red.getbbox()), "dc_gart_car_plate")
    A.save(navy.crop(navy.getbbox()), "dc_gart_car_plate_navy")
    e = cat.get("dc_gart_car_plate")
    if e:
        cat["dc_gart_car_plate_navy"] = dict(e, id="dc_gart_car_plate_navy", name="Navy Licence Plate", colourway_of="dc_gart_car_plate")
        e["name"] = e["name"] if "Plate" in e["name"] else "Red Licence Plate"
    # reed mats: one uncut sheet for two pieces
    src = _orig("furniture", "reed_mat_b")
    a = np.asarray(src)
    cols = a[..., 3].max(0) > 0
    mid = src.width // 2
    gaps = [x for x in range(src.width // 3, 2 * src.width // 3) if not cols[x]]
    cut = gaps[len(gaps) // 2] if gaps else 125
    left, right = src.crop((0, 0, cut, src.height)), src.crop((cut, 0, src.width, src.height))
    _write(left.crop(left.getbbox()), "furniture", "reed_mat_b")
    _write(right.crop(right.getbbox()), "furniture", "reed_mat_round")
    # echo shell: drop the neighbour sliced into its left third
    im = _orig("items", "echo_shell")
    from slice_comp import blobs
    bl = blobs(np.asarray(im), merge=1, min_area=4)
    if len(bl) > 1:
        big = max(bl, key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))
        a = np.asarray(im).copy()
        keep = np.zeros(a.shape[:2], bool)
        keep[big[1]:big[3], big[0]:big[2]] = True
        a[~keep, 3] = 0
        _write(Image.fromarray(a), "items", "echo_shell")


PAD_TRIM = ["armchair_a", "armchair_b", "barrels3", "bookcase_a", "bookcase_b", "bookcase_c", "books_scrolls",
            "bookshelf_ivy", "cattail_pot", "chandelier", "clock_tall", "crystal_cage", "desk_a", "desk_b", "desk_c",
            "desk_d", "easel2", "filing_cabinet", "flower_jug", "globe2", "globe3", "ink_brushes", "ivy_pot", "jug",
            "kettle_stand", "lantern2", "lantern3", "lantern4", "low_table", "safe", "shelf_jars", "spiral_stair",
            "stool2", "statue2_crystal", "vault_closed", "vault_open"]
DEFRINGE = ["globe2", "globe3", "barrels3", "flower_jug", "pelt_wolf", "pelt_bear", "pelt_leopard", "ivy_pot",
            "bookshelf_ivy", "easel2", "telescope2", "lantern4", "crystal_cage", "stool2", "round_rug_stone",
            "statue2_horse", "cat_figurine"]


def _defringe(im):
    """Edge pixels tinted by the magenta key -> the nearest opaque non-pink neighbour colour."""
    import numpy as np
    from PIL import Image
    a = np.asarray(im).astype(int).copy()
    r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    op = al > 0
    pad = np.pad(op, 1)
    edge = op & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    pink = edge & (r - g > 40) & (b - g > 30)
    ys, xs = np.where(pink)
    n = 0
    for y, x in zip(ys, xs):
        best = None
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                yy, xx = y + dy, x + dx
                if 0 <= yy < a.shape[0] and 0 <= xx < a.shape[1] and op[yy, xx] and not pink[yy, xx]:
                    c = a[yy, xx, :3]
                    if best is None or c.sum() < best.sum():
                        best = c
        if best is not None:
            a[y, x, :3] = best
        else:
            a[y, x, 3] = 0
        n += 1
    return Image.fromarray(a.astype(np.uint8)), n


SLIVERS = ["cattail_pot", "telescope2", "shelf_misc", "chandelier"]   # c10b_08-15/20


def _drop_slivers(im):
    """Clear small separate pieces touching the image edge (neighbour slivers from the sheet)."""
    import numpy as np
    from PIL import Image
    from scipy import ndimage
    a = np.asarray(im).copy()
    lab, n = ndimage.label(a[..., 3] > 0, structure=np.ones((3, 3)))
    if n < 2:
        return im
    sizes = ndimage.sum(np.ones(lab.shape), lab, range(1, n + 1))
    big = sizes.max()
    for k in range(1, n + 1):
        ys, xs = np.where(lab == k)
        edge = xs.min() <= 1 or ys.min() <= 1 or xs.max() >= a.shape[1] - 2
        if edge and sizes[k - 1] < 0.03 * big:
            a[lab == k, 3] = 0
    return Image.fromarray(a)


def fix_furniture():
    """Clear magenta key halos and trim the 9-px pads (pieces float above their cell) (c10b_08-23/31).
    Interiors fit these by size and ART_CROP lists none of them. Starts from the original art."""
    from PIL import Image
    S = _S()
    for nm in sorted(set(DEFRINGE) | set(PAD_TRIM) | set(SLIVERS)):
        if not os.path.exists(_out("furniture", nm)):
            continue
        im = _orig("furniture", nm)
        if nm in SLIVERS:
            im = _drop_slivers(im)
        if nm in DEFRINGE:
            im, _ = _defringe(im)
        if nm in PAD_TRIM:
            fr = int(S.manifest.get("furniture", {}).get(nm, {}).get("frames", 1) or 1)
            fw = im.width // fr
            boxes = [b for b in (im.crop((k * fw, 0, (k + 1) * fw, im.height)).getbbox() for k in range(fr)) if b]
            if boxes:   # one box across all frames
                x0, y0 = min(b[0] for b in boxes), min(b[1] for b in boxes)
                x1, y1 = max(b[2] for b in boxes), max(b[3] for b in boxes)
                out = Image.new("RGBA", ((x1 - x0) * fr, y1 - y0))
                for k in range(fr):
                    out.paste(im.crop((k * fw + x0, y0, k * fw + x1, y1)), (k * (x1 - x0), 0))
                im = out
        _write(im, "furniture", nm)


# =====================================================================================
# Names/arcs (c10b_13_01/03/04/08/09): all-ages lounge words for the gangster lounge set,
# penguin pieces kept in the penguin arc, gangster words kept out of the penguin arc, no "II".
# Applied to every catalogue write (slice_c10a.write_catalog calls merge_into too).
# =====================================================================================
RENAME = {
    "dc_casino_table": "Velvet Game Table", "dc_casino_roulette": "Lucky Prize Wheel",
    "dc_casino_slot": "Neon Fruit Machine", "dc_casino_chips": "Token Tower",
    "dc_casino_cards_art": "Playing Card Art", "dc_casino_stool": "Velvet Bar Stool",
    "dc_casino_chip_frame": "Framed Lucky Token", "dc_top_dice_cup": "Dice Cup",
    "dc_top_snow_globe": "Snowy Village Globe", "dc_show_crystal_tree": "Glow Glass Tree",
    "dc_top_ice_crystal": "Ice Cube Paperweight", "dc_stat_trophy": "Champion's Cup",
    "dc_glight_streetlamp": "Mini Street Lamp", "dc_ice_snowman": "Igloo Snowman",
    # names gen_decor already uses (its merge would append " II")
    "dc_arc_pinball": "Arcade Pinball Table", "dc_art_round_mirror": "Gilt Round Mirror", "dc_kit_dining": "Family Dining Table",
    "dc_light_candelabra": "Five-Candle Candelabra", "dc_light_fireplace": "Hearthstone Fireplace",
    "dc_moon_telescope": "Moonlit Telescope", "dc_safe_bunk": "Safehouse Bunk Bed", "dc_stat_bust": "Gallery Marble Bust",
    "dc_top_globe": "Little Desk Globe",
}
SET_RENAME = {"casino": "velvet_lounge"}
REARC = {"dc_top_penguin_plush": "penguins", "dc_rug_penguin": "penguins", "dc_stat_penguin_gold": "penguins"}


def _fix_names(rows):
    names = {r["name"].lower() for r in rows}
    for r in rows:
        if r["id"] in RENAME:
            r["name"] = RENAME[r["id"]]
        if r.get("set") in SET_RENAME:
            r["set"] = SET_RENAME[r["set"]]
        if r["id"] in REARC:
            r["arc"] = REARC[r["id"]]
    for r in rows:      # numeral fallbacks -> set word
        if r["name"].endswith(" II"):
            word = (r.get("set") or r.get("sub") or "").split("_")[0].title()
            nm = ("%s %s" % (word, r["name"][:-3]))[:22] if word else r["name"]
            if nm.lower() not in names:
                names.add(nm.lower())
                r["name"] = nm
    return rows


def merge_into(rows, old=None):
    """Keep the C10b rows (outdoor pieces and fix extras) when slice_c10a rewrites the catalogue."""
    have = {r["id"] for r in rows}
    for r in old or []:
        if r["id"] not in have and (r.get("layer") == "outdoor" or r.get("c10b")):
            rows.append(r)
    return sorted(_fix_names(rows), key=lambda e: e["id"])


def write_catalog(extra):
    S = _S()
    path = os.path.join(S.OUT, GROUP, "_catalog.json")
    cur = json.load(open(path)) if os.path.exists(path) else []
    byid = {r["id"]: r for r in cur}
    for i, r in extra.items():
        r = dict(r)
        r.setdefault("c10b", True)
        byid[i] = r
    rows = merge_into(list(byid.values()))
    if os.path.exists(path):
        os.remove(path)
    with open(path, "w") as fh:
        json.dump(rows, fh, indent=1, sort_keys=True)
    return rows


# outdoor scaled-height bands per sub (cells at 0.5): a new render can't land at the wrong size
HEIGHT_BAND = {"bench": (0.6, 2.6), "planter": (0.5, 2.0), "lamp": (0.8, 3.5), "statue": (0.8, 3.5),
               "fence": (0.4, 3.5), "yard_gang": (0.4, 3.5), "yard_penguin": (0.4, 3.5)}


GANG_BAD = re.compile(r"(?i)casino|roulette|slot machine|poker|high.?roller|royal flush|gambl|crystal|penguin")
PEN_BAD = re.compile(r"(?i)\bcrew\b|vault|casino")


def _quality(cat):
    """Seams wrap exactly, the penguin wall band holds whole penguins, the tent mid has no gap,
    arc words stay in their arc (c10b_08-01/02/03/17, c10b_13)."""
    import numpy as np
    from PIL import Image
    bad = []
    for nm in ("dc_wp_penguin_print", "dc_fl_tatami", "dc_fl_casino_carpet"):
        l = np.asarray(Image.open(_out(GROUP, nm)).convert("L")).astype(float)
        # the jump across the wrap may be no bigger than the biggest jump inside (pattern lines)
        step = max(np.abs(np.diff(l, axis=1)).mean(0).max(), np.abs(np.diff(l, axis=0)).mean(1).max())
        wrap = max(np.abs(l[:, 0] - l[:, -1]).mean(), np.abs(l[0] - l[-1]).mean())
        if wrap > 1.1 * step + 2:
            bad.append("seam %s wrap %.1f step %.1f" % (nm, wrap, step))
    l = np.asarray(Image.open(_out(GROUP, "dc_wp_penguin_print")).convert("L")).astype(float)
    if max(l[0].std(), l[63].std()) > 0.5 * np.median(l[:64].std(1)):
        bad.append("penguin print: wall band edge cuts a penguin row")
    al = np.asarray(_open("tiles", "wl_tent_m"))[..., 3]
    if (al[8:].max(0) == 0).any():
        bad.append("wl_tent_m has an empty column")
    for e in cat:
        if e.get("arc") == "gangsters" and GANG_BAD.search(e["name"]):
            bad.append("gang word in %s %r" % (e["id"], e["name"]))
        if e.get("set") == "casino":
            bad.append("set casino on " + e["id"])
        if e.get("arc") in ("both", "") and (re.search(r"(?i)penguin", e["name"]) or PEN_BAD.search(e["name"])):
            bad.append("arc word in both-arc %s %r" % (e["id"], e["name"]))
    return bad


def check():
    """C10b art check (c10b_14_20): every outdoor piece has art at its catalogue size, anims have
    their icon + strip, glow pieces carry a glow radius, names unique and <= 22, ids dc_.
    Also runs the C10a check."""
    S = _S()
    cat = json.load(open(os.path.join(S.OUT, GROUP, "_catalog.json")))
    man = json.load(open(os.path.join(S.OUT, "manifest.json"))).get(GROUP, {})
    bad = []
    out = [e for e in cat if e.get("layer") == "outdoor"]
    for e in out:
        f = os.path.join(S.OUT, GROUP, e["id"] + ".png")
        if not os.path.exists(f) or e["id"] not in man:
            bad.append("no art " + e["id"]); continue
        m = man[e["id"]]
        w = m.get("cell_w", m["w"]); h = m.get("cell_h", m["h"])
        if e.get("sub") != "path" and w > e["size"][0] * CELL + 2:
            bad.append("too wide %s %d > %d" % (e["id"], w, e["size"][0] * CELL))
        lo, hi = (8, 8) if e.get("tile") else HEIGHT_BAND.get(e.get("sub"), (0.2, 4.5))
        if not lo <= h / CELL <= hi + 0.01:
            bad.append("height %s %.2f cells not in %s" % (e["id"], h / CELL, (lo, hi)))
        if int(e.get("frames", 1) or 1) > 1 and not os.path.exists(os.path.join(S.OUT, GROUP, e["id"] + "_icon.png")):
            bad.append("no icon " + e["id"])
        if e["id"] in META and META[e["id"]]["sub"] == "lamp" and not e.get("glow"):
            bad.append("lamp without glow " + e["id"])
        if not e.get("sub"):
            bad.append("no sub " + e["id"])
    bad += _quality(cat)
    assert not bad, bad
    for e in cat:
        if e["name"].endswith(" II"):
            print("note: numeral name", e["id"], e["name"])
    print("c10b check ok: %d outdoor pieces" % len(out))
    A.check()


def doc():
    out = ["# C10b outdoor decor render list (CONDUCT 10b P6)", "",
           "Generated by `python3 tools/slice_c10b.py doc` from the SHEETS table in tools/slice_c10b.py. "
           "Renders: art/incoming/c10b/out_*.png (dreams-image, transparent background, one image per sheet). "
           "Slice: `python3 tools/slice_c10b.py` -> art/gen/decor/ + _catalog.json rows with layer `outdoor`.", ""]
    for s in SHEETS:
        out += ["## %s (%s, %s, arc %s)" % (s["file"], s["size"], s["kind"], s["arc"]), "",
                "Pieces: " + ", ".join("%s (%s, %s)" % (p[0], p[3], META[p[0]]["sub"]) for r in s["rows"] for p in r), "",
                "Prompt:", "", "> " + prompt(s), ""]
    out += ["## out_paths.png (1024x1024 textures)", "", "> " + prompt({"file": "out_paths.png"}), "",
            "## Fix renders", "", "- out_fix_pieces.png: catkins bell, hourglass, ice crystal, koi scroll, orrery, master hearth, "
            "collector's cabinet, lucky cat (C10a style preamble).",
            "- out_fix_table_sides.png: edit_image of the four C10a set sheets, table side views.",
            "- out_fix_tex.png: penguin print, tatami, lounge carpet, purple carpet as exact-period swatches.", ""]
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "src", "c10b-render-list.md")
    with open(p, "w") as fh:
        fh.write("\n".join(out))
    print("wrote", os.path.normpath(p))


def main(only):
    S = _S()
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    if only == ["doc"]:
        return doc()
    if only == ["check"]:
        return check()
    if only == ["prompts"]:
        for s in SHEETS:
            print("###", s["file"], s["size"]); print(prompt(s)); print()
        return
    cp = os.path.join(S.OUT, GROUP, "_catalog.json")
    cat = {e["id"]: e for e in json.load(open(cp))}
    extra = {}
    if not only or "sheets" in only:
        for s in SHEETS:
            {"pieces": sheet_pieces, "anim": sheet_anim}.get(s["kind"], sheet_pieces)(s) if s["grid"] is not GRID3 else sheet_three(s)
            print("ok", s["file"])
        paths()
    if not only or "fences" in only:
        fences()
    if not only or "kits" in only:
        kits()
    if not only or "fixes" in only:
        print("tex", fix_tex())
        fix_pieces(cat)
        fix_table_sides(cat)
        fix_colourways()
        fix_tent_mid()
        winter_twins()
        tabletop_copies()
        print("wall rules", wall_rules())
        fix_crops(cat)
        fix_furniture()
        for i in ("dc_lucky_cat_gold", "dc_gart_car_plate_navy"):
            if i in cat:
                extra[i] = cat[i]
        for i in ("dc_catkins_bell", "dc_top_hourglass", "dc_top_ice_crystal", "dc_gart_car_plate"):
            if i in cat:
                extra[i] = dict(cat[i], c10b=False)
    extra.update(ROWS)
    rows = write_catalog(extra)
    data = json.dumps(S.manifest, indent=1, sort_keys=True)
    os.remove(mpath)
    with open(mpath, "w") as fh:
        fh.write(data)
    print("catalogue:", len(rows))
    check()


if __name__ == "__main__":
    main(sys.argv[1:])
