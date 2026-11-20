#!/usr/bin/env python3
"""CONDUCT 11b art (exotic, fantastic and lab-strain ranching): `python3 tools/slice_c11b.py [step ...]`.

Run after tools/slice_c11a.py (it reuses its helpers). Renders live in art/incoming/c11b/;
SHEETS below is the render list (`doc` writes docs/src/c11b-render-list.md).

Steps
  animals   c11b_<family>_adult/_baby (C11a layout: 8 rows x 16 cells, side view facing right)
            -> animals/<kind>/{idle,walk,eat,sleep,sad,happy,produce,icon}; babies are <species>_baby;
            c11b_uniques -> one-of-a-kind show winners (animals/<unique>)
  team      c11b_team_* (C11a team layout, 2 rows per species) -> walk_down, walk_up, run, attack,
            downed, getup, guard, special, idle_down, idle_up, hurt, cheer
  buildings c11b_bld_r3/r4/r5/lab (+ _snow/_night edits) -> buildings/<home>_<tier>(_snow|_night)
  items     c11b_items_raw / _made (3x8) -> items/<id> (ids already in the manifest are skipped)
  stations  c11b_stations (2 rows x 4 stations x 4 frames) -> stations/<id>
  interior  c11b_int_pieces (3x8) -> furniture/rn_<id>; c11b_int_tex (2x3) -> seamless/rn_<id>
  ui        c11b_ui (4x8 badges) -> ui/<id>
  variants  hue-shifted common colour variants (body pixels only) -> animals/<species>_<variant>
  meta      art/gen/animals/_ranch_art_c11b.json (same shape as _ranch_art.json) for gen_ranch.py
  check     every kind has the C11 anims, team kinds the team anims, every building look, icon,
            station and piece exists; no keyed-out holes inside bodies (violet guard); exit 1 on a miss
  doc       docs/src/c11b-render-list.md
Colour key: only magenta connected to near-pure #FF00FF is cut, so violet glows inside the art stay.
Never writes an existing art/gen file in place (rm first: hardlinks). Afterwards: art_audit --fix <ids>,
set_import_lossy.py, godot --import.
"""
import colorsys, json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import slice_c11a as A
from slice_comp import blobs, rows_of

ROOT = A.ROOT
GEN = A.GEN
MAN = A.MAN
INC = os.path.join(ROOT, "art", "incoming", "c11b")

# ---------------------------------------------------------------- render list / tables

ANIMAL_ROWS = {  # sheet -> kinds, top to bottom (species ids as the C11b code packages name them)
    "c11b_exotics_adult.png": ["ostrich", "emu", "alpaca", "komodo", "snow_yak", "peacock", "tortoise", "buffalo"],
    "c11b_fantastic_a_adult.png": ["moon_hare", "moon_cow", "star_jelly", "glow_gecko", "coral_seahorse", "kelp_calf", "frost_otter", "ember_newt"],
    "c11b_fantastic_b_adult.png": ["cloud_sheep", "storm_roc", "lantern_moth", "frost_wyrmling", "deep_glowworm", "crystal_hen", "star_sheep", "aurora_fox"],
    "c11b_lab_adult.png": ["chrome_hen", "glow_sheep", "circuit_goat", "turbo_bunny", "circuit_cow", "drone_hog", "volt_gecko", "chrome_runner"],
}
BABY_SHEETS = {k.replace("_adult", "_baby"): v for k, v in ANIMAL_ROWS.items()}
UNIQUES = {"c11b_uniques.png": ["peacock_albino", "star_sheep_rainbow", "ostrich_crystal", "chrome_hen_gold",
                                "komodo_gold", "alpaca_midnight", "aurora_fox_sunfire", "circuit_cow_gold"]}
UNIQUE_OF = {"peacock_albino": "peacock", "star_sheep_rainbow": "star_sheep", "ostrich_crystal": "ostrich", "chrome_hen_gold": "chrome_hen",
             "komodo_gold": "komodo", "alpaca_midnight": "alpaca", "aurora_fox_sunfire": "aurora_fox", "circuit_cow_gold": "circuit_cow"}
SHORN = {"c11b_shorn.png": ["alpaca_shorn", "glow_sheep_shorn", "star_sheep_shorn", "cloud_sheep_shorn", "snow_yak_shorn"]}  # 5 rows
SHORN_OF = {k.rsplit("_shorn", 1)[0]: k for k in SHORN["c11b_shorn.png"]}
FAMILY = {}
for _sheet, _kinds in ANIMAL_ROWS.items():
    for _k in _kinds:
        FAMILY[_k] = _sheet.split("_")[1]  # exotics / fantastic / lab
ARC = {"exotics": "", "fantastic": "penguins", "lab": "gangsters"}

# hue shift (degrees) and value scale per common variant; body pixels only
VARIANTS = {
    "ostrich": {"tawny": (30, 1.15)}, "emu": {"blueneck": (-40, 1.0)}, "alpaca": {"brown": (-15, 0.7), "white": (0, 1.2)},
    "komodo": {"teal": (60, 1.0)}, "snow_yak": {"brown": (25, 0.75)}, "peacock": {"emerald": (-50, 1.0)},
    "tortoise": {"olive": (40, 0.95)}, "buffalo": {"umber": (25, 1.2)},
    "moon_hare": {"rose": (-140, 1.0)}, "moon_cow": {"mint": (-70, 1.0)}, "star_jelly": {"amber": (160, 1.0)},
    "glow_gecko": {"aqua": (60, 1.0)}, "coral_seahorse": {"sunny": (30, 1.05)}, "kelp_calf": {"teal": (40, 1.0)},
    "frost_otter": {"sable": (25, 0.7)}, "ember_newt": {"gold": (20, 1.1)},
    "cloud_sheep": {"dusk": (-160, 0.95)}, "storm_roc": {"sunset": (150, 1.0)}, "lantern_moth": {"mint": (80, 1.0)},
    "frost_wyrmling": {"jade": (-60, 1.0)}, "deep_glowworm": {"lime": (-60, 1.0)}, "crystal_hen": {"rose": (130, 1.0)},
    "star_sheep": {"mint": (110, 1.0)}, "aurora_fox": {"amber": (-150, 1.0)},
    "chrome_hen": {"amber": (40, 1.0)}, "glow_sheep": {"amber": (-120, 1.0)}, "circuit_goat": {"teal": (150, 1.0)},
    "turbo_bunny": {"lime": (-80, 1.0)}, "circuit_cow": {"amber": (-140, 1.0)}, "drone_hog": {"teal": (150, 0.95)},
    "volt_gecko": {"cyan": (160, 1.0)}, "chrome_runner": {"amber": (-150, 1.0)},
}

HEIGHT = {"ostrich": 34, "chrome_runner": 34, "emu": 30, "alpaca": 26, "snow_yak": 28, "buffalo": 28, "circuit_cow": 28, "moon_cow": 26,
          "komodo": 14, "volt_gecko": 13, "peacock": 18, "tortoise": 14, "crystal_hen": 12, "chrome_hen": 12, "star_sheep": 20,
          "glow_sheep": 20, "cloud_sheep": 20, "moon_hare": 10, "turbo_bunny": 10, "star_jelly": 14, "glow_gecko": 9,
          "coral_seahorse": 18, "kelp_calf": 18, "frost_otter": 12, "ember_newt": 10, "storm_roc": 26, "lantern_moth": 14,
          "frost_wyrmling": 18, "deep_glowworm": 9, "aurora_fox": 15, "circuit_goat": 20, "drone_hog": 17}
LONG_LOW = {"komodo", "volt_gecko", "ember_newt", "glow_gecko", "deep_glowworm", "tortoise"}

TEAM_ROWS = {"c11b_team_exotic.png": ["ostrich", "emu", "alpaca", "komodo"],
             "c11b_team_fantastic.png": ["storm_roc", "frost_wyrmling", "frost_otter", "coral_seahorse"],
             "c11b_team_lab.png": ["drone_hog", "volt_gecko", "circuit_goat", "chrome_runner"]}
TEAM_ROW1 = dict(A.TEAM_ROW1)
TEAM_ROW2 = {"downed": (0, 2), "getup": (2, 4), "guard": (4, 6), "special": (6, 8), "idle_down": (8, 10), "idle_up": (10, 12), "hurt": (12, 14), "cheer": (14, 16)}
TEAM_ANIMS = list(TEAM_ROW1) + list(TEAM_ROW2)
SPECIAL = {"ostrich": "kick", "emu": "kick", "alpaca": "spit", "komodo": "tail_swipe", "storm_roc": "wing_gust", "frost_wyrmling": "frost_breath",
           "frost_otter": "pounce", "coral_seahorse": "bubble_shot", "drone_hog": "charge", "volt_gecko": "zap", "circuit_goat": "headbutt",
           "chrome_runner": "dash_kick"}

BUILDINGS = {  # name -> (sheet key, quadrant 0 TL, 1 TR, 2 BL, 3 BR)
    "enclosure_1": ("r3", 0), "enclosure_2": ("r3", 1), "aviary_1": ("r3", 2), "aviary_2": ("r3", 3),
    "terrarium_1": ("r4", 0), "terrarium_2": ("r4", 1), "barn_4": ("r4", 2), "ranch_hut_1": ("r4", 3),
    "ranch_hut_2": ("r5", 0), "tide_pool_1": ("r5", 1), "ember_pit_1": ("r5", 2), "star_dome_1": ("r5", 3),
    "bio_dome_1": ("lab", 0), "drone_loft_1": ("lab", 1), "grow_tank_1": ("lab", 2), "lab_barn_4": ("lab", 3),
}
BLD_FILES = {k: (f"c11b_bld_{k}.png", f"c11b_bld_{k}_snow.png", f"c11b_bld_{k}_night.png") for k in ("r3", "r4", "r5", "lab")}
# gangster-arc look of a penguin/both habitat (gen_ranch.py picks by arc)
GANG_LOOK = {"enclosure": "bio_dome", "aviary": "drone_loft", "terrarium": "grow_tank", "barn_4": "lab_barn_4"}

ITEMS_RAW = ["ostrich_egg", "emu_egg", "plume", "alpaca_fleece", "shed_scale", "yak_wool", "peacock_feather", "shell_moss",
             "buffalo_milk", "moon_fluff", "moon_milk", "sea_milk", "ember_scale", "roc_egg", "roc_feather", "glow_silk",
             "crystal_egg", "star_wool", "aurora_tuft", "circuit_egg", "glow_wool", "coolant", "static_fluff", "alloy_egg"]
ITEMS_MADE = ["grand_omelette", "fine_yarn", "scale_charm", "plume_hat", "drake_chow", "moon_cheese", "glow_yarn", "yak_cheese",
              "buffalo_mozzarella", "star_yarn", "cloud_yarn", "ember_charm", "pearl_necklace", "feather_fan", "synth_milk", "giant_egg_custard",
              "moss_tea_blend", "exotic_feed", "lab_pod", "chrome_hen_pod", "tune_up_kit", "heat_lamp_bulb", "scale_brush", "static_scale"]
ITEMS = ITEMS_RAW + ITEMS_MADE
STATIONS = ["exotic_hatchery", "carding_mill", "star_loom", "gene_splicer", "cheese_vat", "scale_polisher", "pearl_tumbler", "feed_mixer"]
PIECES = ["perch_tree", "nest_ledge", "seed_tray", "bird_bath", "heat_rock", "basking_lamp", "sand_patch", "little_pool",
          "hay_rack_big", "mineral_lick", "hand_bunk", "tool_board", "chore_board", "lunch_table", "boot_rack", "lantern_hook",
          "coral_rock", "ember_vent", "moon_rock", "lab_pod", "cable_crate", "nutrient_dispenser", "steel_feeder", "server_rack"]
TEXTURES = ["sand_floor", "aviary_floor", "terrarium_moss", "lab_steel", "hut_planks", "tide_tile"]
UI = ["ribbon_1st", "ribbon_2nd", "ribbon_3rd", "rosette_champion", "trophy_best_in_show", "ribbon_participant", "show_badge", "judge_card",
      "ab_kick", "ab_spit", "ab_tail_swipe", "ab_pounce", "ab_ember_puff", "ab_headbutt", "ab_bubble_shot", "ab_charge",
      "ab_zap", "ab_shell_guard", "ab_dash_kick", "call_whistle", "task_water", "task_harvest", "task_feed", "task_pet",
      "task_forage", "task_guard", "task_haul", "task_rest", "add_tide_pool", "add_moon_lamp", "add_perch", "add_terrarium"]

_COMMON = ("dreams-image edit, n=1, 1536x1024, opaque flat #FF00FF magenta; never magenta or saturated violet inside the art "
           "(glows cyan/teal/lime/amber/warm pink); all ages")
SHEETS = [(f, "edit art/incoming/c11a/c11_animals_c.png", "adults: " + ", ".join(k)) for f, k in ANIMAL_ROWS.items()] + \
    [(f, "edit the matching _adult sheet", "babies (~55%): " + ", ".join(k)) for f, k in BABY_SHEETS.items()] + \
    [("c11b_shorn.png", "edit exotics/fantastic_b/lab adult sheets", "5 rows shorn: " + ", ".join(SHORN["c11b_shorn.png"]))] + \
    [("c11b_uniques.png", "edit exotics/fantastic_b/lab adult sheets", "show winners: " + ", ".join(UNIQUES["c11b_uniques.png"]))] + \
    [(f, "edit art/incoming/c11a/c11_team_a.png + adult sheet", "team rows (walk_down4 walk_up4 run4 attack4 / downed getup guard special idle_down idle_up hurt cheer): " + ", ".join(k)) for f, k in TEAM_ROWS.items()] + \
    [(BLD_FILES[k][0], "edit art/incoming/c11a/c11_bld_r1.png" + (" + w311_cyber_stations.png" if k == "lab" else ""),
      "2x2: " + ", ".join(n for n, (s, _) in BUILDINGS.items() if s == k)) for k in BLD_FILES] + \
    [(BLD_FILES[k][1], f"edit {BLD_FILES[k][0]}", "same picture, deep winter snow, magenta kept") for k in BLD_FILES] + \
    [(BLD_FILES[k][2], f"edit {BLD_FILES[k][0]}", "same picture at night, warm lit windows, magenta kept") for k in BLD_FILES] + \
    [("c11b_items_raw.png", "edit art/incoming/c11a/c11_items.png", "3x8 icons: " + ", ".join(ITEMS_RAW)),
     ("c11b_items_made.png", "edit art/incoming/c11a/c11_items.png", "3x8 icons: " + ", ".join(ITEMS_MADE)),
     ("c11b_stations.png", "edit art/incoming/c11a/c11_stations.png", "2 rows x 4 stations x 4 frames: " + ", ".join(STATIONS)),
     ("c11b_int_pieces.png", "edit art/incoming/c11a/c11_int_pieces.png", "3x8 pieces: " + ", ".join(PIECES)),
     ("c11b_int_tex.png", "edit art/incoming/c11a/c11_int_tex.png", "2x3 seamless: " + ", ".join(TEXTURES)),
     ("c11b_ui.png", "edit art/incoming/c11a/c11_team_ui.png", "4x8 gold badges: " + ", ".join(UI))]


# ---------------------------------------------------------------- helpers

def load(name):
    """Magenta key that keeps violet: cut magenta-ish pixels only in regions holding near-pure #FF00FF."""
    a = np.array(Image.open(os.path.join(INC, name)).convert("RGBA"))
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    loose = (r > 150) & (g < 110) & (b > 150) & (r - g > 80) & (b - g > 80)
    strict = (r > 215) & (b > 215) & (g < 60)
    lab, k = ndimage.label(loose)
    hit = np.unique(lab[strict & loose])
    a[np.isin(lab, hit[hit > 0]), 3] = 0
    return a


A.load = load  # A's helpers (and its INC) read our sheets


def _kinds_all():
    out = []
    for kinds in ANIMAL_ROWS.values():
        out += kinds + [k + "_baby" for k in kinds]
    for kinds in list(UNIQUES.values()) + list(SHORN.values()):
        out += kinds
    return out


def _variant_kinds():
    return [f"{sp}_{v}" for sp, vs in VARIANTS.items() for v in vs]


def _slice_rows(man, sheet, names):
    a = load(sheet)
    bs, rows = A.bands(a, len(names))
    assert len(bs) == len(names), (sheet, len(bs))
    for name, band, row in zip(names, bs, rows):
        assert "animals/" + name not in man or name in _kinds_all(), name
        frames = []
        for b in A.cells16(a, band, row):
            if b is None:
                frames.append(Image.new("RGBA", (8, 8)))
                continue
            c = A.keep_main(a, b)
            frames.append(Image.fromarray(c[b[1]:b[3], b[0]:b[2]]))
        g = "animals/" + name
        gdir = os.path.join(GEN, g)
        if os.path.isdir(gdir):
            for f in os.listdir(gdir):
                os.remove(os.path.join(gdir, f))
        man[g] = {}
        for anim, (i0, i1) in A.C11_LAYOUT.items():
            man[g][anim] = A.pack(frames[i0:i1], f"{g}/{anim}.png")
        man[g]["icon"] = A.single(frames[0], f"{g}/icon.png")
        print(name, man[g]["idle"]["cell_h"])


def _icon_grid(man, group, sheet, ids, nrows, ncols, size=32, merge=4, min_area=300):
    a = load(sheet)
    for name, b in zip(ids, A._grid(a, nrows, ncols, merge=merge, min_area=min_area)):
        if name in _SKIP.get(group, set()):
            continue
        im = Image.fromarray(a[b[1]:b[3], b[0]:b[2]])
        s = size / max(im.width, im.height)
        im = A.hard(im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS))
        man.setdefault(group, {})[name] = A.single(im, f"{group}/{name}.png")


_SKIP = {}  # filled in main: ids that already existed before C11b (never overwritten)


# ---------------------------------------------------------------- steps

def animals(man):
    for sheet, names in ANIMAL_ROWS.items():
        _slice_rows(man, sheet, names)
    for sheet, names in BABY_SHEETS.items():
        _slice_rows(man, sheet, [n + "_baby" for n in names])
    for sheet, names in list(UNIQUES.items()) + list(SHORN.items()):
        _slice_rows(man, sheet, names)


def team(man):
    for sheet, kinds in TEAM_ROWS.items():
        a = load(sheet)
        bs, rows = A.bands(a, 8)
        assert len(bs) == 8, (sheet, len(bs))
        for i, kind in enumerate(kinds):
            g = "animals/" + kind
            fr = []
            for band, row in ((bs[2 * i], rows[2 * i]), (bs[2 * i + 1], rows[2 * i + 1])):
                for b in A.cells16(a, band, row):
                    c = A.keep_main(a, b) if b else None
                    fr.append(Image.fromarray(c[b[1]:b[3], b[0]:b[2]]) if b else Image.new("RGBA", (8, 8)))
            walk = Image.open(os.path.join(GEN, man[g]["walk"]["file"]))
            wa = np.array(walk)[..., 3] > 40
            ys = np.nonzero(wa.any(1))[0]
            ref = float(ys.max() - ys.min() + 1)
            tall = float(np.median([f.height for f in fr[8:12]]))
            sc = ref / max(1, tall)
            fr = [A.hard(f.resize((max(1, round(f.width * sc)), max(1, round(f.height * sc))), Image.LANCZOS)) for f in fr]
            for anim, (i0, i1) in TEAM_ROW1.items():
                man[g][anim] = A.pack(fr[i0:i1], f"{g}/{anim}.png")
            for anim, (i0, i1) in TEAM_ROW2.items():
                man[g][anim] = A.pack(fr[16 + i0:16 + i1], f"{g}/{anim}.png")
            print("team", kind, round(sc, 2))


def _quads(a):
    """Quadrant boxes split at the emptiest column/row near the middle (blobs of two
    pieces can touch through soft shadows, so no blob-merge here)."""
    H, W = a.shape[:2]
    m = a[..., 3] > 40
    xc = W // 4 + int(np.argmin(m[:, W // 4: 3 * W // 4].sum(0)[W // 8: -W // 8 or None])) + W // 8
    q = {}
    for side, (x0, x1) in enumerate(((0, xc), (xc, W))):
        col = m[:, x0:x1].sum(1)
        yc = H // 3 + int(np.argmin(col[H // 3: 2 * H // 3]))
        for half, (y0, y1) in enumerate(((0, yc), (yc, H))):
            b = A.bbox(a, (x0, y0, x1, y1))
            c = A.keep_main(a, b)
            q[side + 2 * half] = A.bbox(c, b)
    return q


def buildings(man):
    w517 = load("../w517_farm_coop_barn.png")
    qw = A._quads(w517)
    f = man["props"]["coop_small"]["w"] / (qw[0][2] - qw[0][0])
    sheets = {k: ([load(fn) for fn in files]) for k, files in BLD_FILES.items()}
    quads = {k: [_quads(x) for x in arrs] for k, arrs in sheets.items()}
    for name, (key, qi) in sorted(BUILDINGS.items()):
        day_a, snow_a, night_a = sheets[key]
        dq, sq, nq = quads[key]
        fx = f * (A.TIER3_BOOST if name.endswith("_4") else 1.0)
        day = A.scaled(day_a, dq[qi], fx)
        man["buildings"][name] = A.single(day, f"buildings/{name}.png")
        for look, arr, qq in (("snow", snow_a, sq), ("night", night_a, nq)):
            im = Image.fromarray(arr[qq[qi][1]:qq[qi][3], qq[qi][0]:qq[qi][2]])
            im = A.hard(im.resize(day.size, Image.LANCZOS))
            man["buildings"][f"{name}_{look}"] = A.single(im, f"buildings/{name}_{look}.png")
        print(name, day.size)


def items(man):
    _icon_grid(man, "items", "c11b_items_raw.png", ITEMS_RAW, 3, 8)
    _icon_grid(man, "items", "c11b_items_made.png", ITEMS_MADE, 3, 8)
    print("items", len(ITEMS) - len(_SKIP.get("items", ())), "new; kept existing:", sorted(_SKIP.get("items", ())))


def stations(man):
    a = load("c11b_stations.png")
    rows = rows_of(blobs(a, merge=2, min_area=200))
    rows = [r for r in rows if len(r) >= 4]
    assert len(rows) == 2, [len(r) for r in rows]
    tgt = man["stations"]["cheese_press"]["cell_h"]
    for ri, r in enumerate(rows):
        y0, y1 = min(b[1] for b in r), max(b[3] for b in r)
        runs = A._col_runs(a, y0, y1, 64)
        gaps = sorted(range(len(runs) - 1), key=lambda i: runs[i][1] - runs[i + 1][0])[:3]
        groups, s0 = [], 0
        for c in sorted(gaps) + [len(runs) - 1]:
            groups.append((runs[s0][0], runs[c][1])); s0 = c + 1
        assert len(groups) == 4, groups
        boxes = []
        for gx0, gx1 in groups:
            w = (gx1 - gx0) / 4
            boxes += [A.bbox(a, (int(gx0 + i * w), y0, int(gx0 + (i + 1) * w), y1)) for i in range(4)]
        tall = max(b[3] - b[1] for b in boxes)
        for si in range(4):
            name = STATIONS[ri * 4 + si]
            fr = [A.scaled(a, b, tgt / tall) for b in boxes[si * 4: si * 4 + 4]]
            man["stations"][name] = A.pack(fr, f"stations/{name}.png")
            print(name, man["stations"][name]["cell_w"], man["stations"][name]["cell_h"])


def interior(man):
    a = load("c11b_int_pieces.png")
    for name, b in zip(PIECES, A._grid(a, 3, 8)):
        man["furniture"]["rn_" + name] = A.single(A.scaled(a, b, 0.42), f"furniture/rn_{name}.png")
    t = load("c11b_int_tex.png")
    for name, b in zip(TEXTURES, A._grid(t, 2, 3, merge=2, min_area=2000)):
        x0, y0, x1, y1 = b
        m = 6
        im = Image.fromarray(t[y0 + m:y1 - m, x0 + m:x1 - m]).convert("RGBA").resize((256, 256), Image.LANCZOS)
        arr = A.seamless(np.array(im).astype(float)).round().clip(0, 255).astype(np.uint8)
        arr[..., 3] = 255
        man["seamless"]["rn_" + name] = A.single(Image.fromarray(arr), f"seamless/rn_{name}.png")
    print("interior", len(PIECES), "pieces,", len(TEXTURES), "textures")


def ui(man):
    _icon_grid(man, "ui", "c11b_ui.png", UI, 4, 8, merge=3, min_area=2000)
    print("ui", len(UI))


def _body_mask(arr):
    """Pixels a recolour may touch: opaque, not outline-dark, not near-white eyes, not red hearts."""
    rgb = arr[..., :3].astype(float) / 255
    mx, mn = rgb.max(-1), rgb.min(-1)
    lum = rgb @ [0.299, 0.587, 0.114]
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    heart = (r > 0.7) & (g < 0.45) & (b < 0.5) & (sat > 0.5)
    return (arr[..., 3] > 40) & (lum > 40 / 255) & ~((lum > 0.93) & (sat < 0.08)) & ~heart


def _shift(arr, deg, vmul, mask):
    out = arr.copy()
    px = arr[mask][:, :3].astype(float) / 255
    hsv = np.array([colorsys.rgb_to_hsv(*p) for p in px]) if len(px) else np.zeros((0, 3))
    if len(hsv):
        hsv[:, 0] = (hsv[:, 0] + deg / 360.0) % 1.0
        hsv[:, 2] = np.clip(hsv[:, 2] * vmul, 0, 1)
        lowsat = hsv[:, 1] < 0.12  # greys/whites: tint a little so the variant reads
        hsv[lowsat, 1] = np.where(vmul != 1.0, hsv[lowsat, 1], np.minimum(0.25, hsv[lowsat, 1] + 0.18))
        rgb = np.array([colorsys.hsv_to_rgb(*h) for h in hsv])
        out[mask, :3] = (rgb * 255).round().clip(0, 255).astype(np.uint8)
    return out


def variants(man):
    for sp, vs in VARIANTS.items():
        base = man["animals/" + sp]
        for v, (deg, vmul) in vs.items():
            k = f"{sp}_{v}"
            g = "animals/" + k
            assert g not in man or k in _variant_kinds(), k
            man[g] = {}
            for anim, e in base.items():
                arr = np.array(Image.open(os.path.join(GEN, e["file"])).convert("RGBA"))
                mask = _body_mask(arr)
                if anim == "produce":  # keep the product colour: only shift the left (animal) part of each cell
                    cw = e.get("cell_w", arr.shape[1])
                    xs = np.arange(arr.shape[1]) % cw
                    mask &= (xs < cw * 0.62)[None, :]
                rel = f"{g}/{anim}.png"
                A.save(Image.fromarray(_shift(arr, deg, vmul, mask)), rel)
                man[g][anim] = dict(e, file=rel)
        print("variants", sp, list(vs))


def meta(man):
    out = {}
    for sheet, kinds in ANIMAL_ROWS.items():
        for sp in kinds:
            var = [f"{sp}_{v}" for v in VARIANTS.get(sp, {})]
            rare = [u for u, s in UNIQUE_OF.items() if s == sp]
            baby = sp + "_baby"
            shorn = SHORN_OF.get(sp, "")
            kinds_all = [sp] + var + rare + [baby] + ([shorn] if shorn else [])
            anims = {k: sorted(x for x in man.get("animals/" + k, {}) if x != "icon") for k in kinds_all}
            h = HEIGHT.get(sp, 16)
            out[sp] = {"kind": sp, "anims": anims[sp], "kind_anims": anims, "variants": var, "rare": rare, "baby": baby, "shorn": shorn,
                       "height": {**{k: h for k in [sp] + var + rare + ([shorn] if shorn else [])}, baby: max(5, round(h * 0.55))},
                       "alias": {}, "family": FAMILY[sp], "arc": ARC[FAMILY[sp]], "long_low": sp in LONG_LOW,
                       "team": sp in SPECIAL, "special": SPECIAL.get(sp, "")}
    out["_buildings"] = {}
    for name in sorted(BUILDINGS):
        home, tier = name.rsplit("_", 1)
        out["_buildings"].setdefault(home, {})[tier] = {"sprite": name, "group": "buildings", "snow": name + "_snow", "night": name + "_night"}
    out["_gang_look"] = GANG_LOOK
    out["_items"] = [i for i in ITEMS]
    out["_stations"] = STATIONS
    out["_interior"] = {"furniture": ["rn_" + p for p in PIECES], "seamless": ["rn_" + t for t in TEXTURES]}
    out["_ui"] = UI
    p = os.path.join(GEN, "animals", "_ranch_art_c11b.json")
    if os.path.exists(p):
        os.remove(p)
    with open(p, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
    print("wrote", p)


HOLE_MAX = 0.03  # leg gaps, rotors and tentacles enclose up to ~2% legitimately; a keyed-out glow is far more


def _holes(path, cell_w):
    """Share of body pixels that are enclosed transparent holes (keyed-out glows), worst cell."""
    a = np.array(Image.open(path).convert("RGBA"))[..., 3] > 40
    worst = 0.0
    for x0 in range(0, a.shape[1], max(1, cell_w)):
        m = a[:, x0:x0 + cell_w]
        if m.sum() < 30:
            continue
        filled = ndimage.binary_fill_holes(m)
        worst = max(worst, (filled & ~m).sum() / float(filled.sum()))
    return worst


def check(man):
    bad = []
    for k in _kinds_all() + _variant_kinds():
        g = man.get("animals/" + k)
        if not g:
            bad.append(f"animals/{k} missing")
            continue
        for an in A.C11_ANIMS:
            if an not in g or not os.path.exists(os.path.join(GEN, g[an]["file"])):
                bad.append(f"animals/{k}/{an}")
        if k in _kinds_all() and "idle" in g:
            hr = _holes(os.path.join(GEN, g["idle"]["file"]), g["idle"].get("cell_w", 0))
            if hr > HOLE_MAX:
                bad.append(f"animals/{k}/idle has keyed-out holes ({hr:.1%}): violet inside the art?")
    for kinds in TEAM_ROWS.values():
        for k in kinds:
            for an in TEAM_ANIMS:
                if an not in man.get("animals/" + k, {}):
                    bad.append(f"animals/{k}/{an} (team)")
    for name in BUILDINGS:
        for look in ("", "_snow", "_night"):
            e = man.get("buildings", {}).get(name + look)
            if not e or not os.path.exists(os.path.join(GEN, e["file"])):
                bad.append(f"buildings/{name}{look}")
            elif look and (e["w"], e["h"]) != (man["buildings"][name]["w"], man["buildings"][name]["h"]):
                bad.append(f"buildings/{name}{look} size differs from day")
    for group, ids in (("items", ITEMS), ("stations", STATIONS), ("ui", UI)):
        for i in ids:
            if i not in man.get(group, {}):
                bad.append(f"{group}/{i}")
    for p in PIECES:
        if "rn_" + p not in man.get("furniture", {}):
            bad.append("furniture/rn_" + p)
    for t in TEXTURES:
        if "rn_" + t not in man.get("seamless", {}):
            bad.append("seamless/rn_" + t)
    if not os.path.exists(os.path.join(GEN, "animals", "_ranch_art_c11b.json")):
        bad.append("animals/_ranch_art_c11b.json")
    print("slice_c11b check:", "ok" if not bad else "%d problems" % len(bad))
    for b in bad:
        print("  -", b)
    return not bad


def doc():
    p = os.path.join(ROOT, "docs", "src", "c11b-render-list.md")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as fh:
        fh.write("# C11b render list (generated by tools/slice_c11b.py doc)\n\n"
                 "All renders: " + _COMMON + ". Files in art/incoming/c11b/. Slice with `python3 tools/slice_c11b.py` "
                 "(after slice_c11a.py).\n\n| file | how | contents |\n|---|---|---|\n")
        for f, how, what in SHEETS:
            fh.write(f"| {f} | {how} | {what} |\n")
    print("wrote", p)


STEPS = ["animals", "team", "buildings", "items", "stations", "interior", "ui", "variants", "meta"]

if __name__ == "__main__":
    man = json.load(open(MAN))
    steps = sys.argv[1:] or STEPS
    if steps == ["doc"]:
        doc(); sys.exit(0)
    if steps == ["check"]:
        sys.exit(0 if check(man) else 1)
    # ids that existed before C11b and were not made by this slicer stay untouched
    _SKIP["items"] = {"moon_milk", "pearl_necklace"}
    for s in steps:
        if s in ("check", "doc"):
            continue
        globals()[s](man)
    if os.path.exists(MAN):
        os.remove(MAN)
    with open(MAN, "w") as fh:
        json.dump(man, fh, indent=1, sort_keys=True)
    if "doc" in steps:
        doc()
    if "check" in steps:
        sys.exit(0 if check(man) else 1)
