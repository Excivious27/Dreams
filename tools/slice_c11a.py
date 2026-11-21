#!/usr/bin/env python3
"""CONDUCT 11a art (ranching): `python3 tools/slice_c11a.py [step ...]`.

Run after the other slicers (after slice_c10b.py). Renders live in art/incoming/c11a/
(SHEETS below is the render list; `doc` writes docs/src/c11a-render-list.md).

Steps
  animals   c11_animals_a/b/c (w175 layout: 8 rows x 16 cells, side view facing right)
            -> animals/<kind>/{idle,walk,eat,sleep,sad,happy,produce,icon}
            (bee row: animals/bee_swarm/{hover,fly,enter,queen,icon})
  buildings c11_bld_r1/r2 (+ _snow/_night edits) and w517 (+ c11 snow/night edits)
            -> buildings/<home>_<tier>, _snow, _night (night/snow fitted to the day size)
  items     c11_items (3x8 icons) -> items/<id>
  stations  c11_stations (2 rows x 4 stations x 4 frames) -> stations/<id>
  interior  c11_int_pieces (3x8) -> furniture/rn_<id>; c11_int_tex (2x3) -> seamless/rn_<id>
  team      c11_team_a/b -> follower poses walk_down/up, run, attack, downed, getup, guard, fetch,
            idle_down/up, sit, cheer for goat/llama/donkey/pig/lamb/hen/rabbit/duck; c11_team_ui -> ui/cmd_* etc.
  nodes     nodes_<tree>.png -> ui/node_<skill>_<id> (NODE_SHEETS, grid order)
  fixes     -02 drop the adult-drawn 'baby' strips (cow_brown, cow_bw, sheep_woolly),
            -11 clear neighbour-row slivers on goat2 idle/walk, pig_a idle, pig_b idle
  meta      art/gen/animals/_ranch_art.json (species -> kinds/anims/variants/baby, plus
            _buildings/_items/_stations/_interior tables) read by tools/gen_ranch.py
  check     every species kind has the C11 anims, every building tier day/snow/night,
            every icon, no slivers (exit 1 on a miss)
  doc       docs/src/c11a-render-list.md
Never writes an existing art/gen file in place (rm first: hardlinks). Afterwards:
(the rn_ textures get make_seamless's wrap blend here: never run make_seamless.py
without --check), set_import_lossy.py, godot --import.
"""
import json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slice_comp import blobs, rows_of


def seamless(a, band=48):
    """make_seamless.py's wrap blend (copied: importing that tool runs it over every texture)."""
    n, m = a.shape[:2]
    r = np.roll(a, (n // 2, m // 2), (0, 1))
    dy = np.minimum(np.arange(n), n - 1 - np.arange(n)).astype(float)
    dx = np.minimum(np.arange(m), m - 1 - np.arange(m)).astype(float)
    wy = np.clip(dy / band, 0, 1); wy = wy * wy * (3 - 2 * wy)
    wx = np.clip(dx / band, 0, 1); wx = wx * wx * (3 - 2 * wx)
    w = np.minimum.outer(wy, wx)[..., None]
    return a * w + r * (1 - w)


ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GEN = os.environ.get("ART_GEN") or os.path.join(ROOT, "art", "gen")
INC = os.path.join(ROOT, "art", "incoming", "c11a")
MAN = os.path.join(GEN, "manifest.json")

C11_LAYOUT = {"idle": (0, 2), "walk": (2, 6), "eat": (6, 8), "sleep": (8, 10), "sad": (10, 11), "happy": (11, 14), "produce": (14, 16)}
BEE_LAYOUT = {"hover": (0, 4), "fly": (4, 8), "enter": (8, 12), "queen": (12, 16), "idle": (0, 4)}  # idle = hover (gen_ranch/FarmAnimal need idle)
ANIMAL_ROWS = {
    "c11_animals_a.png": ["chicken_white", "chicken_brown", "chicken_rooster", "duck_white", "chick", "duckling", "chicken_golden", "chicken_blue"],
    "c11_animals_b.png": ["cow_jersey", "cow_holstein", "cow_calf", "pig", "piglet", "pig_spotted", "sheep_shorn", "sheep_black"],
    "c11_animals_c.png": ["rabbit_white", "rabbit_brown", "bunny", "rabbit_angora", "cow_highland", "pig_kunekune", "duck_pekin", "bee_swarm"],
}
C11_ANIMS = list(C11_LAYOUT)
# w175 families (goat/sheep/llama/donkey) have hurt/idle_b instead of sad/produce.
W175_ALIAS = {"sad": "hurt", "produce": "happy"}

# Species table for gen_ranch.py: main kind, variants (rare ones flagged), baby kind.
SPECIES = {
    "chicken": {"kind": "chicken_white", "variants": ["chicken_brown", "chicken_rooster"], "rare": ["chicken_golden", "chicken_blue"], "baby": "chick"},
    "duck": {"kind": "duck_white", "variants": ["duck_pekin"], "rare": [], "baby": "duckling"},
    "cow": {"kind": "cow_jersey", "variants": ["cow_holstein"], "rare": ["cow_highland"], "baby": "cow_calf"},
    "sheep": {"kind": "sheep", "variants": [], "rare": ["sheep_black"], "baby": "lamb", "shorn": "sheep_shorn"},
    "goat": {"kind": "goat", "variants": [], "rare": [], "baby": "goat_kid"},
    "llama": {"kind": "llama", "variants": [], "rare": [], "baby": "llama_cria"},
    "pig": {"kind": "pig", "variants": ["pig_kunekune"], "rare": ["pig_spotted"], "baby": "piglet"},
    "rabbit": {"kind": "rabbit_white", "variants": ["rabbit_brown"], "rare": ["rabbit_angora"], "baby": "bunny"},
    "bees": {"kind": "bee_swarm", "variants": [], "rare": [], "baby": ""},
}
# Suggested draw heights at 270x480 (c11a_12-12); FarmAnimal scales strips to these.
HEIGHT = {"chicken_white": 12, "chicken_brown": 12, "chicken_golden": 12, "chicken_blue": 12, "chicken_rooster": 14, "chick": 7,
          "duck_white": 12, "duck_pekin": 12, "duckling": 7, "cow_jersey": 28, "cow_holstein": 28, "cow_highland": 28, "cow_calf": 17,
          "sheep": 20, "sheep_black": 20, "sheep_shorn": 18, "lamb": 12, "goat": 20, "goat_kid": 12, "llama": 30, "llama_cria": 17,
          "pig": 17, "pig_spotted": 17, "pig_kunekune": 15, "piglet": 9, "rabbit_white": 10, "rabbit_brown": 10, "rabbit_angora": 11,
          "bunny": 6, "bee_swarm": 8}

# Buildings: (sheet, quadrant 0 TL 1 TR 2 BL 3 BR) -> buildings/<home>_<tier>; snow/night edits share the quadrant.
BUILDINGS = {
    "coop_1": ("w517", 0), "coop_2": ("w517", 1), "barn_1": ("w517", 2), "barn_2": ("w517", 3),
    "coop_3": ("r1", 0), "barn_3": ("r1", 1), "hutch_1": ("r1", 2), "hutch_2": ("r1", 3),
    "sty_1": ("r2", 0), "sty_2": ("r2", 1), "apiary_1": ("r2", 2), "apiary_2": ("r2", 3),
}
BLD_FILES = {"w517": ("../w517_farm_coop_barn.png", "c11_bld_w517_snow.png", "c11_bld_w517_night.png"),
             "r1": ("c11_bld_r1.png", "c11_bld_r1_snow.png", "c11_bld_r1_night.png"),
             "r2": ("c11_bld_r2.png", "c11_bld_r2_snow.png", "c11_bld_r2_night.png")}
TIER3_BOOST = 1.12  # deluxe buildings read a little bigger than tier 2

ITEMS = ["egg_brown", "egg_large", "egg_brown_large", "egg_blue_plain", "egg_golden", "milk_large", "goat_milk_large", "duck_feather",
         "rabbit_fur", "rabbit_foot", "truffle_oil", "duck_mayonnaise", "animal_treat", "coop_heater", "auto_grabber", "hay_hopper",
         "animal_bell", "show_ribbon", "name_tag", "honey_wildflower", "honey_clover", "salt_lick", "mixed_feed", "wool_black"]
STATIONS = ["mayo_machine_1", "mayo_machine_2", "creamery", "incubator_deluxe", "wool_carder", "truffle_press", "cheese_rack", "egg_sorter"]
PIECES = ["nest_box", "nest_box_eggs", "perch", "feed_bench", "feed_bench_hay", "water_bowl", "coop_heater", "auto_grabber",
          "egg_crate", "stall_divider", "milking_stool", "hay_hopper", "hutch_box", "hutch_box_double", "mud_wallow", "bee_frame_rack",
          "salt_lick", "brush_hook", "pitchfork_bale", "feed_sacks", "water_trough", "lantern_post", "hay_round", "barn_gate"]
TEXTURES = ["straw_bed", "coop_plank", "barn_timber", "hay_floor", "mud_patch", "barn_cobble"]

TEAM_UI = ["cmd_fetch", "cmd_train", "cmd_guard_pet", "cmd_stay_pet", "bond_heart", "team_badge", "animal_brush", "feed_scoop"]
NODE_SHEETS = {  # render -> ui/node_<skill>_<id> in grid order (c11a_07: icons for the 7 trees that had none)
    "nodes_bartering.png": ["bartering_trader", "bartering_bartering_0_1", "bartering_bartering_0_3", "bartering_appraiser", "bartering_bartering_0_5", "bartering_monopolist", "bartering_bartering_0_7", "bartering_bartering_0_8", "bartering_bartering_0_9", "bartering_haggler", "bartering_bartering_1_1", "bartering_stall_plans", "bartering_bartering_1_3", "bartering_tycoon", "bartering_bartering_1_5", "bartering_bartering_1_6", "bartering_bartering_1_7", "bartering_bartering_1_8", "bartering_bartering_2_0", "bartering_bartering_2_1", "bartering_smooth_talker", "bartering_bartering_2_3", "bartering_festival_favorite", "bartering_patron", "bartering_bartering_2_7", "bartering_bartering_2_8", "bartering_bartering_2_9", "bartering_bartering_3_0", "bartering_bartering_3_1", "bartering_networker", "bartering_bartering_3_3", "bartering_bartering_3_4", "bartering_bartering_3_5", "bartering_crystal_baron", "bartering_bartering_3_7", "bartering_magnate", "bartering_bartering_3_9"],
    "nodes_building.png": ["building_carpenter", "building_engineer", "building_building_0_3", "building_building_0_4", "building_building_0_5", "building_bridgewright", "building_building_0_7", "building_building_0_8", "building_building_0_9", "building_mason", "building_building_1_1", "building_architect", "building_building_1_4", "building_building_1_5", "building_grand_architect", "building_building_1_7", "building_building_1_8", "building_building_1_9", "building_building_2_0", "building_tinkerer", "building_building_2_3", "building_decorator", "building_building_2_5", "building_homemaker", "building_building_2_7", "building_building_2_8", "building_building_2_9", "building_building_3_0", "building_building_3_1", "building_building_3_2", "building_building_3_3", "building_foreman", "building_master_builder", "building_building_3_6", "building_building_3_7", "building_city_planner"],
    "nodes_harmony.png": ["harmony_harmony_0_0", "harmony_harmony_0_1", "harmony_harmony_0_3", "harmony_harmony_0_4", "harmony_harmony_0_5", "harmony_harmony_0_6", "harmony_harmony_0_7", "harmony_harmony_0_8", "harmony_harmony_0_9", "harmony_harmony_1_0", "harmony_harmony_1_1", "harmony_harmony_1_2", "harmony_harmony_1_3", "harmony_harmony_1_5", "harmony_harmony_1_6", "harmony_harmony_1_7", "harmony_harmony_1_8", "harmony_harmony_1_9", "harmony_harmony_2_0", "harmony_harmony_2_1", "harmony_harmony_2_2", "harmony_harmony_2_3", "harmony_harmony_2_4", "harmony_harmony_2_5", "harmony_harmony_2_6", "harmony_harmony_2_8", "harmony_harmony_2_9", "harmony_harmony_3_0", "harmony_harmony_3_1", "harmony_harmony_3_2", "harmony_harmony_3_3", "harmony_harmony_3_4", "harmony_harmony_3_5", "harmony_harmony_3_6", "harmony_harmony_3_7", "harmony_harmony_3_8", "harmony_harmony_3_9"],
    "nodes_hustle.png": ["hustle_hustle_0_0", "hustle_hustle_0_2", "hustle_hustle_0_3", "hustle_hustle_0_4", "hustle_hustle_0_6", "hustle_hustle_0_7", "hustle_hustle_0_8", "hustle_hustle_0_9", "hustle_hustle_1_0", "hustle_hustle_1_1", "hustle_hustle_1_2", "hustle_hustle_1_4", "hustle_hustle_1_5", "hustle_hustle_1_6", "hustle_hustle_1_7", "hustle_hustle_1_8", "hustle_hustle_1_9", "hustle_hustle_2_0", "hustle_hustle_2_1", "hustle_hustle_2_2", "hustle_hustle_2_3", "hustle_hustle_2_5", "hustle_hustle_2_6", "hustle_hustle_2_8", "hustle_hustle_2_9", "hustle_hustle_3_0", "hustle_hustle_3_1", "hustle_hustle_3_3", "hustle_hustle_3_4", "hustle_hustle_3_5", "hustle_hustle_3_6", "hustle_hustle_3_7", "hustle_hustle_3_8", "hustle_hustle_3_9"],
    "nodes_leadership.png": ["leadership_leadership_0_0", "leadership_leadership_0_1", "leadership_leadership_0_3", "leadership_leadership_0_4", "leadership_leadership_0_5", "leadership_leadership_0_6", "leadership_leadership_0_7", "leadership_leadership_0_8", "leadership_leadership_0_9", "leadership_leadership_1_0", "leadership_leadership_1_1", "leadership_leadership_1_2", "leadership_leadership_1_4", "leadership_leadership_1_5", "leadership_leadership_1_6", "leadership_leadership_1_7", "leadership_leadership_1_8", "leadership_leadership_1_9", "leadership_leadership_2_0", "leadership_leadership_2_1", "leadership_leadership_2_2", "leadership_leadership_2_3", "leadership_leadership_2_4", "leadership_leadership_2_5", "leadership_leadership_2_7", "leadership_leadership_2_8", "leadership_leadership_2_9", "leadership_leadership_3_0", "leadership_leadership_3_1", "leadership_leadership_3_2", "leadership_leadership_3_3", "leadership_leadership_3_4", "leadership_leadership_3_5", "leadership_leadership_3_6", "leadership_leadership_3_7", "leadership_leadership_3_8", "leadership_leadership_3_9"],
    "nodes_strategist.png": ["strategist_strategist_0_0", "strategist_strategist_0_1", "strategist_strategist_0_3", "strategist_strategist_0_4", "strategist_strategist_0_5", "strategist_strategist_0_6", "strategist_strategist_0_7", "strategist_strategist_0_8", "strategist_strategist_0_9", "strategist_strategist_1_0", "strategist_strategist_1_1", "strategist_strategist_1_2", "strategist_strategist_1_4", "strategist_strategist_1_5", "strategist_strategist_1_6", "strategist_strategist_1_7", "strategist_strategist_1_8", "strategist_strategist_1_9", "strategist_strategist_2_0", "strategist_strategist_2_1", "strategist_strategist_2_2", "strategist_strategist_2_3", "strategist_strategist_2_4", "strategist_strategist_2_6", "strategist_strategist_2_7", "strategist_strategist_2_8", "strategist_strategist_2_9", "strategist_strategist_3_0", "strategist_strategist_3_1", "strategist_strategist_3_2", "strategist_strategist_3_3", "strategist_strategist_3_4", "strategist_strategist_3_5", "strategist_strategist_3_6", "strategist_strategist_3_7", "strategist_strategist_3_8", "strategist_strategist_3_9"],
    "nodes_magic_pup.png": ["magic_magic_0_1", "magic_magic_0_9", "magic_magic_1_0", "magic_magic_1_1", "magic_magic_1_9", "magic_magic_2_0", "magic_magic_2_9", "magic_magic_3_2", "magic_magic_3_3", "magic_magic_3_4", "magic_magic_3_5", "magic_magic_3_6", "magic_magic_3_7", "pup_pup_0_1", "pup_pup_0_2", "pup_pup_0_3", "pup_pup_0_5", "pup_pup_0_6", "pup_pup_0_7", "pup_pup_0_9", "pup_pup_1_0", "pup_pup_1_1", "pup_pup_1_3", "pup_pup_1_5", "pup_pup_1_8", "pup_pup_1_9", "pup_pup_2_0", "pup_pup_2_1", "pup_pup_2_5", "pup_pup_2_6", "pup_pup_2_7", "pup_pup_2_9", "pup_pup_3_3", "pup_pup_3_8", "pup_pup_3_9"],
}

SHEETS = [  # the render list (dreams-image connector, n=1, 1536x1024, magenta)
    ("c11_animals_a.png", "edit art/incoming/w175_animals_c.png", "birds: white/brown hen, rooster, duck, chick, duckling, golden hen, blue hen; cells idle2 walk4 eat2 sleep2 sad1 happy3 produce2"),
    ("c11_animals_b.png", "edit art/incoming/w175_animals_c.png", "brown cow, black-white cow, calf, pig, piglet, spotted pig, sheared sheep, black sheep; same cells"),
    ("c11_animals_c.png", "edit art/incoming/w175_animals_c.png", "white/brown rabbit, bunny kit, angora, highland cow, kunekune pig, pekin duck, bee row (hover4 fly4 enter4 queen4)"),
    ("c11_bld_r1.png", "edit art/incoming/w517_farm_coop_barn.png", "2x2: deluxe coop, deluxe barn (silo), small hutch, big hutch"),
    ("c11_bld_r2.png", "edit art/incoming/w517_farm_coop_barn.png", "2x2: small pigsty, big pigsty, apiary, big apiary"),
    ("c11_items.png", "generate", "3x8 icons: " + ", ".join(ITEMS)),
    ("c11_stations.png", "edit art/incoming/w177_stations_anim.png", "2 rows x 4 stations x 4 frames: " + ", ".join(STATIONS)),
    ("c11_int_pieces.png", "generate", "3x8 interior pieces: " + ", ".join(PIECES)),
    ("c11_int_tex.png", "generate", "2x3 seamless squares: " + ", ".join(TEXTURES)),
    ("c11_bld_r1_snow.png", "edit c11_bld_r1.png", "same picture, deep winter snow"),
    ("c11_bld_r2_snow.png", "edit c11_bld_r2.png", "same picture, deep winter snow"),
    ("c11_bld_w517_snow.png", "edit art/incoming/w517_farm_coop_barn.png", "same picture, deep winter snow"),
    ("c11_bld_r1_night.png", "edit c11_bld_r1.png", "same picture at night, warm lit windows, magenta kept"),
    ("c11_bld_r2_night.png", "edit c11_bld_r2.png", "same picture at night, warm lit windows, magenta kept"),
    ("c11_bld_w517_night.png", "edit art/incoming/w517_farm_coop_barn.png", "same picture at night, warm lit windows, magenta kept"),
    ("c11_team_a.png", "edit art/incoming/w175_animals_c.png", "follower poses: goat, llama, donkey, pig (2 rows each)"),
    ("c11_team_b.png", "edit c11_animals_a.png", "follower poses: lamb, hen, rabbit, duck (2 rows each)"),
    ("c11_team_ui.png", "generate", "8 icons: " + ", ".join(TEAM_UI)),
] + [(f, "generate", "skill node badges, 8 columns, gold-framed rounded squares: " + ", ".join(ids)) for f, ids in NODE_SHEETS.items()]


# ---------------------------------------------------------------- helpers

def load(name):
    a = np.array(Image.open(os.path.join(INC, name)).convert("RGBA"))
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    a[(r > 150) & (g < 110) & (b > 150) & (r - g > 80) & (b - g > 80), 3] = 0
    return a


def save(img, rel):
    p = os.path.join(GEN, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if os.path.exists(p):
        os.remove(p)
    img.save(p)


def hard(im):
    a = np.array(im)
    a[..., 3] = np.where(a[..., 3] > 110, 255, 0)
    return Image.fromarray(a)


def bbox(a, reg):
    x0, y0, x1, y1 = reg
    m = a[y0:y1, x0:x1, 3] > 40
    if not m.any():
        return None
    ys, xs = np.nonzero(m)
    return (x0 + xs.min(), y0 + ys.min(), x0 + xs.max() + 1, y0 + ys.max() + 1)


def scaled(a, b, f):
    im = Image.fromarray(a[b[1]:b[3], b[0]:b[2]])
    if abs(f - 1) > 1e-3:
        im = hard(im.resize((max(1, round(im.width * f)), max(1, round(im.height * f))), Image.LANCZOS))
    return im


def pack(frames, rel, pad=2):
    cw = max(f.width for f in frames) + pad
    ch = max(f.height for f in frames)
    out = Image.new("RGBA", (cw * len(frames), ch), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, (i * cw + (cw - f.width) // 2, ch - f.height), f)
    save(out, rel)
    return {"file": rel, "w": out.width, "h": ch, "cell_w": cw, "cell_h": ch, "frames": len(frames)}


def single(im, rel):
    save(im, rel)
    return {"file": rel, "w": im.width, "h": im.height}


def bands(a, n, min_body=600):
    """n row bands (y0, y1) from the big blobs; small blobs (hearts, tufts) join the band they touch."""
    big = [b for b in blobs(a, merge=3, min_area=min_body)]
    rows = rows_of(big)
    rows = sorted(rows, key=lambda r: -len(r))[:n]
    rows.sort(key=lambda r: min(b[1] for b in r))
    out = [[min(b[1] for b in r), max(b[3] for b in r)] for r in rows]
    for i in range(len(out)):  # reach up halfway to the row above (hearts float above heads)
        top = out[i - 1][1] if i else 0
        out[i][0] = max(top + 2, out[i][0] - min(40, (out[i][0] - top) // 2))
    return [tuple(o) for o in out], rows


def cells16(a, band, body_row, n=16):
    """16 cell boxes in a band: split at midpoints between body centres (fallback: equal cells)."""
    y0, y1 = band
    bodies = sorted(body_row, key=lambda b: b[0])
    if len(bodies) == n:
        cx = [(b[0] + b[2]) / 2 for b in bodies]
        cuts = [0] + [int((cx[i] + cx[i + 1]) / 2) for i in range(n - 1)] + [a.shape[1]]
    else:
        xs = np.nonzero((a[y0:y1, :, 3] > 40).any(0))[0]
        lo, hi = xs.min(), xs.max() + 1
        w = (hi - lo) / n
        cuts = [int(lo + i * w) for i in range(n + 1)]
    return [bbox(a, (cuts[i], y0, cuts[i + 1], y1)) for i in range(n)]


def keep_main(a, b):
    """Drop stray specks in a cell: keep components with >= 3% of the biggest one's area."""
    sub = a[b[1]:b[3], b[0]:b[2]].copy()
    m = sub[..., 3] > 40
    lab, k = ndimage.label(ndimage.binary_dilation(m, iterations=2))
    if k > 1:
        sizes = ndimage.sum(m, lab, range(1, k + 1))
        keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= 0.03 * sizes.max()])
        sub[~keep, 3] = 0
    out = np.zeros_like(a)
    out[b[1]:b[3], b[0]:b[2]] = sub
    return out


# ---------------------------------------------------------------- steps

def animals(man):
    for sheet, names in ANIMAL_ROWS.items():
        a = load(sheet)
        bs, rows = bands(a, 8)
        assert len(bs) == 8, (sheet, len(bs))
        for name, band, row in zip(names, bs, rows):
            boxes = cells16(a, band, row)
            frames = []
            for b in boxes:
                if b is None:
                    frames.append(Image.new("RGBA", (8, 8)))
                    continue
                c = keep_main(a, b)
                frames.append(Image.fromarray(c[b[1]:b[3], b[0]:b[2]]))
            g = "animals/" + name
            gdir = os.path.join(GEN, g)
            if os.path.isdir(gdir):  # replace the whole kind (scrap strips go)
                for f in os.listdir(gdir):
                    os.remove(os.path.join(gdir, f))
            man[g] = {}
            layout = BEE_LAYOUT if name == "bee_swarm" else C11_LAYOUT
            for anim, (i0, i1) in layout.items():
                man[g][anim] = pack(frames[i0:i1], f"{g}/{anim}.png")
            man[g]["icon"] = single(frames[0], f"{g}/icon.png")
            print(name, {k: v["frames"] for k, v in man[g].items() if "frames" in v}, man[g][list(layout)[0]]["cell_h"])


def _quads(a):
    """One box per quadrant: the union of every blob whose centre lies in it."""
    H, W = a.shape[:2]
    q = {}
    for b in blobs(a, merge=3, min_area=800):
        cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
        k = (1 if cx > W / 2 else 0) + (2 if cy > H / 2 else 0)
        o = q.get(k)
        q[k] = b if o is None else (min(o[0], b[0]), min(o[1], b[1]), max(o[2], b[2]), max(o[3], b[3]))
    assert len(q) == 4, q
    return q


def buildings(man):
    # Scale: the w517 small coop crop maps to the live props/coop_small width (78 px).
    w517 = load(BLD_FILES["w517"][0])
    qw = _quads(w517)
    f = man["props"]["coop_small"]["w"] / (qw[0][2] - qw[0][0])
    sheets = {}
    for key, files in BLD_FILES.items():
        sheets[key] = [_quads(load(fn)) for fn in files]
        sheets[key + "_a"] = [load(fn) for fn in files]
    man.setdefault("buildings", {})
    for name, (key, qi) in sorted(BUILDINGS.items()):
        day_a, snow_a, night_a = sheets[key + "_a"]
        dq, sq, nq = sheets[key]
        fx = f * (TIER3_BOOST if name.endswith("_3") else 1.0)
        day = scaled(day_a, dq[qi], fx)
        man["buildings"][name] = single(day, f"buildings/{name}.png")
        for look, arr, qq in (("snow", snow_a, sq), ("night", night_a, nq)):
            im = Image.fromarray(arr[qq[qi][1]:qq[qi][3], qq[qi][0]:qq[qi][2]])
            im = hard(im.resize(day.size, Image.LANCZOS))  # fitted to the day footprint
            man["buildings"][f"{name}_{look}"] = single(im, f"buildings/{name}_{look}.png")
        print(name, day.size)


# C11b P6 (c11b_05-09): gangster looks of the C11a homes, same 2x2 quadrants as BUILDINGS, fitted to the day
# size: buildings/<name>_gang (Builds._arc_words picks them). Key only near-pure magenta: neon pinks stay.
GANG_FILES = {"w517": "../c11b/p6_gang_w517.png", "r1": "../c11b/p6_gang_r1.png", "r2": "../c11b/p6_gang_r2.png"}


def _load_gang(name):
    a = np.array(Image.open(os.path.join(INC, name)).convert("RGBA"))
    r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
    a[(r > 190) & (g < 90) & (b > 190) & (np.abs(r - b) < 60), 3] = 0
    from scipy import ndimage  # magenta fringe on the outline: pinkish pixels touching the backdrop go too
    for _ in range(2):
        edge = ndimage.binary_dilation(a[..., 3] == 0) & (a[..., 3] > 0)
        a[edge & (r > 150) & (b > 130) & (g < 120) & (r - g > 70) & (b - g > 50), 3] = 0
    return a


def gang(man):
    sheets = {k: _load_gang(f) for k, f in GANG_FILES.items() if os.path.exists(os.path.join(INC, f))}
    quads = {k: _quads(a) for k, a in sheets.items()}
    for name, (key, qi) in sorted(BUILDINGS.items()):
        if key not in sheets or name not in man.get("buildings", {}):
            continue
        day = man["buildings"][name]
        b = quads[key][qi]
        im = Image.fromarray(sheets[key][b[1]:b[3], b[0]:b[2]])
        im = hard(im.resize((int(day["w"]), int(day["h"])), Image.LANCZOS))
        man["buildings"][name + "_gang"] = single(im, f"buildings/{name}_gang.png")
        print(name + "_gang", im.size)


def _grid(a, nrows, ncols, merge=4, min_area=300):
    rows = rows_of(blobs(a, merge=merge, min_area=min_area))
    rows = [r for r in rows if len(r) >= ncols // 2]
    assert len(rows) == nrows and all(len(r) == ncols for r in rows), [len(r) for r in rows]
    return [b for r in rows for b in r]


def items(man):
    a = load("c11_items.png")
    for name, b in zip(ITEMS, _grid(a, 3, 8)):
        im = Image.fromarray(a[b[1]:b[3], b[0]:b[2]])
        s = 32 / max(im.width, im.height)
        im = hard(im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS))
        man["items"][name] = single(im, f"items/{name}.png")
    print("items", len(ITEMS))


def _col_runs(a, y0, y1, n):
    col = (a[y0:y1, :, 3] > 40).any(0)
    runs, x = [], 0
    W = len(col)
    while x < W:
        if col[x]:
            s = x
            while x < W and col[x]:
                x += 1
            runs.append([s, x])
        x += 1
    # merge runs separated by tiny gaps until n remain
    while len(runs) > n:
        gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
        i = int(np.argmin(gaps))
        runs[i][1] = runs[i + 1][1]
        del runs[i + 1]
    return runs


def stations(man):
    a = load("c11_stations.png")
    rows = rows_of(blobs(a, merge=2, min_area=200))
    rows = [r for r in rows if len(r) >= 4]
    assert len(rows) == 2, [len(r) for r in rows]
    tgt = man["stations"]["cheese_press"]["cell_h"]
    for ri, r in enumerate(rows):
        y0, y1 = min(b[1] for b in r), max(b[3] for b in r)
        runs = _col_runs(a, y0, y1, 64)  # raw column runs; the 3 widest gaps part the 4 stations
        gaps = sorted(range(len(runs) - 1), key=lambda i: runs[i][1] - runs[i + 1][0])[:3]
        cuts = sorted(gaps)
        groups, s0 = [], 0
        for c in cuts + [len(runs) - 1]:
            groups.append((runs[s0][0], runs[c][1])); s0 = c + 1
        assert len(groups) == 4, groups
        boxes = []
        for gx0, gx1 in groups:
            w = (gx1 - gx0) / 4
            boxes += [bbox(a, (int(gx0 + i * w), y0, int(gx0 + (i + 1) * w), y1)) for i in range(4)]
        tall = max(b[3] - b[1] for b in boxes)
        for si in range(4):
            name = STATIONS[ri * 4 + si]
            fr = [scaled(a, b, tgt / tall) for b in boxes[si * 4: si * 4 + 4]]
            man["stations"][name] = pack(fr, f"stations/{name}.png")
            print(name, man["stations"][name]["cell_w"], man["stations"][name]["cell_h"])


def interior(man):
    a = load("c11_int_pieces.png")
    f = 0.42  # nest box row ~2 cells wide at 2x detail (32 px per 16-px cell)
    for name, b in zip(PIECES, _grid(a, 3, 8)):
        man["furniture"]["rn_" + name] = single(scaled(a, b, f), f"furniture/rn_{name}.png")
    t = load("c11_int_tex.png")
    sq = _grid(t, 2, 3, merge=2, min_area=2000)
    man.setdefault("seamless", {})
    for name, b in zip(TEXTURES, sq):
        x0, y0, x1, y1 = b
        m = 6  # inset off any soft edge
        im = Image.fromarray(t[y0 + m:y1 - m, x0 + m:x1 - m]).convert("RGBA").resize((256, 256), Image.LANCZOS)
        arr = seamless(np.array(im).astype(float)).round().clip(0, 255).astype(np.uint8)  # make_seamless.py's wrap blend, on our textures only
        arr[..., 3] = 255
        man["seamless"]["rn_" + name] = single(Image.fromarray(arr), f"seamless/rn_{name}.png")
    print("interior", len(PIECES), "pieces,", len(TEXTURES), "textures")


def _sliver_clean(path):
    """Remove alpha blobs < 40 px touching the top or bottom 3 rows of each frame cell."""
    im = np.array(Image.open(path).convert("RGBA"))
    m = im[..., 3] > 40
    lab, k = ndimage.label(m)
    H = m.shape[0]
    changed = 0
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if sl is None:
            continue
        sub = lab[sl] == i + 1
        if sub.sum() < 40 and (sl[0].start < 3 or sl[0].stop > H - 3):
            im[sl][sub, 3] = 0
            changed += 1
    return im, changed


def nodes(man):
    tgt = man["ui"]["node_combat_acrobat"]["h"]
    for sheet, ids in NODE_SHEETS.items():
        a = load(sheet)
        rows = rows_of(blobs(a, merge=3, min_area=2000))
        boxes = [b for r in rows for b in r]
        assert len(boxes) == len(ids), (sheet, len(boxes), len(ids), [len(r) for r in rows])
        for nid, b in zip(ids, boxes):
            im = Image.fromarray(a[b[1]:b[3], b[0]:b[2]])
            s = tgt / im.height
            im = hard(im.resize((max(1, round(im.width * s)), tgt), Image.LANCZOS))
            man["ui"]["node_" + nid] = single(im, f"ui/node_{nid}.png")
        print(sheet, len(ids))


TEAM_ROWS = {"c11_team_a.png": ["goat", "llama", "donkey", "pig"], "c11_team_b.png": ["lamb", "chicken_white", "rabbit_white", "duck_white"]}
TEAM_ROW1 = {"walk_down": (0, 4), "walk_up": (4, 8), "run": (8, 12), "attack": (12, 16)}
TEAM_ROW2 = {"downed": (0, 2), "getup": (2, 4), "guard": (4, 6), "fetch": (6, 8), "idle_down": (8, 10), "idle_up": (10, 12), "sit": (12, 14), "cheer": (14, 16)}


def bee_idle(man):
    """animals/bee_swarm/idle: a NEW file copied from hover (Ranch art needs an idle strip for every kind)."""
    g = man.get("animals/bee_swarm", {})
    if "hover" not in g:
        return
    src = os.path.join(GEN, g["hover"]["file"])
    rel = "animals/bee_swarm/idle.png"
    dst = os.path.join(GEN, rel)
    if os.path.exists(dst):
        os.remove(dst)  # hardlinked art: never write in place
    with open(src, "rb") as fi, open(dst, "wb") as fo:
        fo.write(fi.read())
    g["idle"] = dict(g["hover"], file=rel)
    print("bee idle", g["idle"])


NODE_ALIAS = {"node_farming_farming_2_4": "node_foraging_foraging_1_7"}  # Farming's new "Experience" filler (C11a P3 row move)


def node_alias(man):
    """New skill-node icons that reuse an existing node's picture (written as NEW files)."""
    for new, src in NODE_ALIAS.items():
        if src not in man.get("ui", {}):
            continue
        rel = f"ui/{new}.png"
        dst = os.path.join(GEN, rel)
        if os.path.exists(dst):
            os.remove(dst)
        with open(os.path.join(GEN, man["ui"][src]["file"]), "rb") as fi, open(dst, "wb") as fo:
            fo.write(fi.read())
        man["ui"][new] = dict(man["ui"][src], file=rel)
        print("node alias", new, "<-", src)


def team(man):
    """Follower poses for trainable animals (c11a_09/-18): pup-style strip names, scaled so idle_down
    runs as tall as the kind's side walk. Run after `animals` (it rebuilds the C11 kinds)."""
    for sheet, kinds in TEAM_ROWS.items():
        a = load(sheet)
        bs, rows = bands(a, 8)
        assert len(bs) == 8, (sheet, len(bs))
        for i, kind in enumerate(kinds):
            g = "animals/" + kind
            fr = []
            for band, row in ((bs[2 * i], rows[2 * i]), (bs[2 * i + 1], rows[2 * i + 1])):
                for b in cells16(a, band, row):
                    c = keep_main(a, b) if b else None
                    fr.append(Image.fromarray(c[b[1]:b[3], b[0]:b[2]]) if b else Image.new("RGBA", (8, 8)))
            # side-view run frames match the kind's side-view walk height
            walk = Image.open(os.path.join(GEN, man[g]["walk"]["file"]))
            wa = np.array(walk)[..., 3] > 40
            ys = np.nonzero(wa.any(1))[0]; ref = float(ys.max() - ys.min() + 1)
            tall = float(np.median([f.height for f in fr[8:12]]))
            sc = ref / max(1, tall)
            fr = [hard(f.resize((max(1, round(f.width * sc)), max(1, round(f.height * sc))), Image.LANCZOS)) for f in fr]
            for anim, (i0, i1) in TEAM_ROW1.items():
                man[g][anim] = pack(fr[i0:i1], f"{g}/{anim}.png")
            for anim, (i0, i1) in TEAM_ROW2.items():
                man[g][anim] = pack(fr[16 + i0:16 + i1], f"{g}/{anim}.png")
            print("team", kind, round(sc, 2))
    a = load("c11_team_ui.png")
    bs = sorted(blobs(a, merge=4, min_area=300), key=lambda b: b[0])
    assert len(bs) == len(TEAM_UI), len(bs)
    for name, b in zip(TEAM_UI, bs):
        im = Image.fromarray(a[b[1]:b[3], b[0]:b[2]])
        s = 32 / max(im.width, im.height)
        im = hard(im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS))
        man["ui"][name] = single(im, f"ui/{name}.png")
    print("team ui", len(TEAM_UI))


def fixes(man):
    for kind in ("cow_brown", "cow_bw", "sheep_woolly"):  # -02: these 'baby' strips are adults
        g = "animals/" + kind
        if g in man and "baby" in man[g]:
            p = os.path.join(GEN, man[g]["baby"]["file"])
            for q in (p, p + ".import"):
                if os.path.exists(q):
                    os.remove(q)
            del man[g]["baby"]
            print("dropped", g + "/baby")
    for kind, anim in (("goat2", "idle"), ("goat2", "walk"), ("pig_a", "idle"), ("pig_b", "idle")):  # -11
        g = "animals/" + kind
        if g not in man or anim not in man[g]:
            continue
        p = os.path.join(GEN, man[g][anim]["file"])
        im, n = _sliver_clean(p)
        if n:
            save(Image.fromarray(im), man[g][anim]["file"])
        print("slivers", kind, anim, n)


def meta(man):
    out = {}
    for sp, d in SPECIES.items():
        kinds = [d["kind"]] + d["variants"] + d["rare"] + ([d["shorn"]] if d.get("shorn") else []) + ([d["baby"]] if d["baby"] else [])
        anims = {}
        for k in kinds:
            g = man.get("animals/" + k, {})
            anims[k] = sorted(x for x in g if x != "icon")
        out[sp] = {"kind": d["kind"], "anims": anims[d["kind"]], "kind_anims": anims, "variants": d["variants"], "rare": d["rare"],
                   "baby": d["baby"], "shorn": d.get("shorn", ""), "height": {k: HEIGHT.get(k, 16) for k in kinds},
                   "alias": W175_ALIAS if "hurt" in anims[d["kind"]] else {}}
    out["_buildings"] = {}
    for name in sorted(BUILDINGS):
        home, tier = name.rsplit("_", 1)
        out["_buildings"].setdefault(home, {})[tier] = {"sprite": name, "group": "buildings", "snow": name + "_snow", "night": name + "_night"}
    out["_items"] = ITEMS
    out["_stations"] = STATIONS
    out["_interior"] = {"furniture": ["rn_" + p for p in PIECES], "seamless": ["rn_" + t for t in TEXTURES]}
    p = os.path.join(GEN, "animals", "_ranch_art.json")
    if os.path.exists(p):
        os.remove(p)
    with open(p, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
    print("wrote", p)


def check(man):
    bad = []
    for sp, d in SPECIES.items():
        kinds = [d["kind"]] + d["variants"] + d["rare"] + ([d["shorn"]] if d.get("shorn") else []) + ([d["baby"]] if d["baby"] else [])
        for k in kinds:
            g = man.get("animals/" + k)
            if not g:
                bad.append(f"animals/{k} missing")
                continue
            need = list(BEE_LAYOUT) if k == "bee_swarm" else C11_ANIMS
            for an in need:
                if an not in g and W175_ALIAS.get(an, "") not in g:
                    bad.append(f"animals/{k}/{an}")
                elif an in g:
                    f = os.path.join(GEN, g[an]["file"])
                    if not os.path.exists(f):
                        bad.append(f"file {f}")
    for name in BUILDINGS:
        for look in ("", "_snow", "_night"):
            e = man.get("buildings", {}).get(name + look)
            if not e or not os.path.exists(os.path.join(GEN, e["file"])):
                bad.append(f"buildings/{name}{look}")
            elif look:
                d = man["buildings"][name]
                if (e["w"], e["h"]) != (d["w"], d["h"]):
                    bad.append(f"buildings/{name}{look} size differs from day")
    for i in ITEMS:
        if i not in man.get("items", {}):
            bad.append("items/" + i)
    for s in STATIONS:
        if s not in man.get("stations", {}):
            bad.append("stations/" + s)
    for p in PIECES:
        if "rn_" + p not in man.get("furniture", {}):
            bad.append("furniture/rn_" + p)
    for t in TEXTURES:
        if "rn_" + t not in man.get("seamless", {}):
            bad.append("seamless/rn_" + t)
    if not os.path.exists(os.path.join(GEN, "animals", "_ranch_art.json")):
        bad.append("animals/_ranch_art.json")
    for kind, anim in (("goat2", "idle"), ("goat2", "walk"), ("pig_a", "idle"), ("pig_b", "idle")):
        e = man.get("animals/" + kind, {}).get(anim)
        if e and _sliver_clean(os.path.join(GEN, e["file"]))[1]:
            bad.append(f"slivers animals/{kind}/{anim}")
    print("slice_c11a check:", "ok" if not bad else "%d problems" % len(bad))
    for b in bad:
        print("  -", b)
    return not bad


def doc():
    p = os.path.join(ROOT, "docs", "src", "c11a-render-list.md")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as fh:
        fh.write("# C11a render list (generated by tools/slice_c11a.py doc)\n\n"
                 "All renders: dreams-image connector, n=1, 1536x1024, opaque flat #FF00FF magenta, at most 3 per call. "
                 "Files in art/incoming/c11a/. Slice with `python3 tools/slice_c11a.py`.\n\n| file | how | contents |\n|---|---|---|\n")
        for f, how, what in SHEETS:
            fh.write(f"| {f} | {how} | {what} |\n")
    print("wrote", p)


STEPS = ["animals", "bee_idle", "team", "buildings", "gang", "items", "stations", "interior", "nodes", "node_alias", "fixes", "meta"]

if __name__ == "__main__":
    man = json.load(open(MAN))
    steps = sys.argv[1:] or STEPS
    if steps == ["doc"]:
        doc(); sys.exit(0)
    if steps == ["check"]:
        sys.exit(0 if check(man) else 1)
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
