#!/usr/bin/env python3
"""Prompts 17-30 sheets rendered with the image tool (Round 12 art).

The renders place pieces roughly where the prompt asked, so everything here is
found by magenta-separated components read as rows (tools/slice_comp.py).
Run after the other slicers:  python3 tools/slice_world5.py [step ...]
Merges into art/gen/manifest.json.
"""
import json, os, sys
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_art import load, crop, scale_to, save, strip, TILE2
from slice_comp import (blobs, rows_of, sheet_rows, piece, save_piece, save_strip, med_h,
                        split_wide, tight, row_n, even_grid, content_box, col_segments, bands)
from PIL import Image

MOODS12 = ["neutral", "happy", "sad", "angry", "surprised", "tired", "laughing", "worried",
           "determined", "sleepy", "sick", "love"]
MOODS6 = ["neutral", "happy", "sad", "angry", "surprised", "determined"]


def have(f):
    return os.path.exists(os.path.join(S.INC, f))


def mget(group, name, key, default):
    return S.manifest.get(group, {}).get(name, {}).get(key, default)


def row_box(row):
    return (min(b[0] for b in row), min(b[1] for b in row), max(b[2] for b in row), max(b[3] for b in row))


def big_rows(rows, frac=0.35):
    """Drop rows that are only stray specks (much shorter than the typical row)."""
    hs = [row_box(r)[3] - row_box(r)[1] for r in rows]
    if not hs:
        return rows
    m = np.median(hs)
    return [r for r, h in zip(rows, hs) if h >= frac * m]


def merge_rows(rows, gap=24):
    """Rows whose boxes overlap vertically or nearly touch become one row."""
    out = []
    for r in rows:
        if out:
            pb, rb = row_box(out[-1]), row_box(r)
            if rb[1] - pb[3] < gap and (rb[3] - rb[1]) < 0.6 * (pb[3] - pb[1]):
                out[-1] = sorted(out[-1] + r, key=lambda b: b[0]); continue
        out.append(r)
    return out


def layout(boxes, spec):
    """Hand frames out to anims in order: spec = [(anim, n), ...]. A short row
    still gives every anim at least one frame (repeats the last one)."""
    out, i = {}, 0
    total = sum(n for _, n in spec)
    if len(boxes) < total:
        # stretch: scale indices so the pieces we have cover all anims
        idx = np.linspace(0, len(boxes) - 1, total).round().astype(int) if boxes else []
        boxes = [boxes[k] for k in idx]
    for anim, n in spec:
        out[anim] = boxes[i:i + n]; i += n
    return out


# ---------------------------------------------------------------- items

ITEMS_478 = ["crystal_bloom", "strawberry_wine", "corn_ale", "berry_juice", "sprinkler_iridium", "old_collar",
             "brass_locket", "knight_shard", "manifest", "sand", "colony_light", "coral_charm", "tide_pearl",
             "kelp_wrap", "ember_glass", "starfish_snack", "shiitake", "moonwort", "backpack_1", "backpack_2",
             "backpack_3"]
ITEMS_493 = ("dark_crystal_fragment,meow_spark,light_tear,grump_king_heart,penguin_promise,storm_eye,moon_shard,star_core,"
             "president_seal,president_crown,tower_key,city_deed,first_dollar,golden_pawprint,dream_heart,space_pearl,"
             "valley_map,first_seed,great_tree_lantern,lighthouse_lens,mill_stone,shrine_bell,observatory_lens,station_core,"
             "hideout_radio,dock_bell,neon_dragon_eye,pit_belt,tower_blueprint,moon_key,jungle_idol,spire_fragment").split(",")


def icon(rgba, b, size=32):
    im = piece(rgba, b, w=size, h=size)
    out = Image.new("RGBA", (size, size))
    out.alpha_composite(im, ((size - im.width) // 2, (size - im.height) // 2))
    return out


def icons_in_order(file, names, group="items", size=32, merge=4):
    rgba = load(file)
    boxes = [b for r in big_rows(rows_of(blobs(rgba, merge=merge, min_area=400))) for b in r]
    for nm, b in zip(names, boxes):
        save(icon(rgba, b, size), group, nm)
    return len(boxes)


def w478():
    n = icons_in_order("w478_item_icons_last.png", ITEMS_478)
    print("   items", n)


def w493():
    n = icons_in_order("w493_drops_minerals_last_rows.png", [x for x in ITEMS_493 if x != "moon_shard"] and ITEMS_493)
    print("   items", n)


# ---------------------------------------------------------------- props

def w422():
    rgba, rows = sheet_rows("w422_last_props.png", merge=3, min_area=200)
    rows = big_rows(rows, 0.1)
    # row 0: fountain x4
    save_strip(rgba, rows[0][:4], "props", "fountain", 128 / med_h(rows[0][:4]) * 0.5 * 1.0)
    # row 1: horse side x2, front x2, back x2, saddled side x2
    r1 = rows[1]
    f = 64 / med_h(r1)
    save_strip(rgba, r1[0:2], "animals", "horse_tame_side", f)
    save_strip(rgba, r1[2:4], "animals", "horse_tame_front", f)
    save_strip(rgba, r1[4:6], "animals", "horse_tame_back", f)
    save_strip(rgba, r1[6:8], "animals", "horse_tame_saddle", f)
    # row 2: dirt puff x6, moth x4, robot x4 (the robot sits at the right)
    r2 = rows[2]
    if len(r2) >= 14:
        save_strip(rgba, r2[0:6], "fx", "dirt_puff", 0.5)
        save_strip(rgba, r2[6:10], "fx", "glow_moth", 24 / med_h(r2[6:10]))
        save_strip(rgba, r2[10:14], "props", "helper_bot", 32 / med_h(r2[10:14]))
    for r in rows[3:]:
        for b in r:
            w, h = b[2] - b[0], b[3] - b[1]
            if w > 900:
                save_piece(rgba, b, "backdrops", "space_strip" if b[1] > 700 else "city_strip", w=512, h=128)
            elif w > 700 and h < 60:
                save_piece(rgba, b, "ui", "boss_bar_fill", w=200, h=24)
            elif w > 700:
                save_piece(rgba, b, "ui", "boss_bar_frame2", w=220, h=40)
    # drones and the charging pad: small pieces in the right column
    small = [b for r in rows[3:] for b in r if b[0] > 1000 and (b[2] - b[0]) < 200]
    drones = sorted([b for b in small if b[3] - b[1] < 60], key=lambda b: b[0])[:4]
    if len(drones) == 4:
        save_strip(rgba, drones, "props", "helper_drone", 24 / med_h(drones))
    pads = [b for r in rows[3:] for b in r if b[0] > 1100 and b[3] - b[1] > 120]
    if pads:
        save_piece(rgba, pads[0], "props", "charge_pad", w=40, h=44)


def w476():
    rgba, rows = sheet_rows("w476_storm_puddles.png", merge=3, min_area=500)
    rows = big_rows(rows)
    for i, r in enumerate(rows[:4]):
        b3 = r[:3]
        w = max(b[2] - b[0] for b in b3)
        save_strip(rgba, b3, "props", "puddle_storm_%d" % i, 120 / w)


# ---------------------------------------------------------------- portraits

def clear_group(group):
    """Drop a group's old files (a redraw replaces the whole person)."""
    for nm, d in list(S.manifest.get(group, {}).items()):
        f = os.path.join(S.OUT, d["file"])
        if os.path.exists(f):
            os.remove(f)
        if os.path.exists(f + ".import"):
            os.remove(f + ".import")
    S.manifest[group] = {}


def portrait_row(rgba, row, n, group, moods, h=96, fresh=True):
    if fresh and len(moods) >= 6:
        clear_group(group)
    segs = row_n(rgba, row, n)
    for m, b in zip(moods, segs):
        save(piece(rgba, b, h=h, w=int(h * 1.3)), group, m)


def w479():
    rgba, rows = sheet_rows("w479_villager_faces_a.png", merge=2, min_area=2000)
    rows = big_rows(rows)
    for who, r in zip(["npc_marlowe", "npc_orla", "npc_ivy"], rows):
        portrait_row(rgba, r, 12, "portraits/" + who, MOODS12)


def w480():
    rgba, rows = sheet_rows("w480_villager_faces_b.png", merge=2, min_area=2000)
    rows = big_rows(rows)
    for who, r in zip(["npc_tam", "npc_benno", "npc_sel"], rows):
        if who == "npc_tam" and have("w480b_tam_faces.png"):
            continue
        portrait_row(rgba, r, 12, "portraits/" + who, MOODS12)
    if have("w480b_tam_faces.png"):
        rgba, rows = sheet_rows("w480b_tam_faces.png", merge=2, min_area=2000)
        portrait_row(rgba, big_rows(rows)[0], 12, "portraits/npc_tam", MOODS12)


def w442():
    rgba, rows = sheet_rows("w442_winter_portraits.png", merge=2, min_area=3000)
    who = ["sal", "lumi", "theo", "bram", "juniper", "pip", "tobin", "wren_jr", "mabel"]
    groups = [b for r in big_rows(rows) for b in r]
    for w, g in zip(who, groups):
        portrait_row(rgba, [g], 3, "portraits/npc_%s_winter" % w, ["neutral", "happy", "sad"])


MINOR = ["crystal_knight", "smuggler", "alien_trader", "hitchhiker", "motel_clerk", "doorman", "guard",
         "karaoke_host", "ring_announcer", "diner_cook", "noodle_vendor", "fish_seller"]


def w463():
    rgba, rows = sheet_rows("w463_minor_portraits.png", merge=1, min_area=3000)
    rows = big_rows(rows)
    k = 0
    for r in rows[:3]:
        segs = row_n(rgba, r, 8)
        for j in range(0, 8, 2):
            if k < len(MINOR):
                for m, b in zip(["neutral", "happy"], segs[j:j + 2]):
                    save(piece(rgba, b, h=96, w=124), "portraits/" + MINOR[k], m)
            k += 1


def w466():
    rgba, rows = sheet_rows("w466_villain_portraits.png", merge=1, min_area=3000)
    for who, r in zip(["big_grump", "commander"], big_rows(rows)):
        for m, b in zip(["neutral", "happy", "worried"], row_n(rgba, r, 3)):
            save(piece(rgba, b, h=96, w=96), "portraits/" + who, m)


def hero_rows(file, names):
    rgba, rows = sheet_rows(file, merge=1, min_area=3000)
    for who, r in zip(names, big_rows(rows)):
        for m, b in zip(MOODS6, row_n(rgba, r, 6)):
            save(piece(rgba, b, h=96, w=124), "portraits/" + who, m)


def w467():
    hero_rows("w467_hero_costume_portraits_gang.png", ["hero_outfit_pinstripe", "hero_outfit_vest", "hero_outfit_armored"])


def w468():
    hero_rows("w468_hero_costume_portraits_penguin.png", ["hero_outfit_parka", "hero_outfit_crystal_parka", "hero_outfit_starlight"])


def w471():
    hero_rows("w471_hero_portraits_neon_ceremony.png", ["hero_outfit_neon", "hero_outfit_penguin"])


# ---------------------------------------------------------------- characters

def char_rows(file, merge=3, min_area=300, frac=0.4):
    rgba, rows = sheet_rows(file, merge=merge, min_area=min_area)
    return rgba, big_rows(rows, frac)


def emit(rgba, group, anims, factor):
    for a, bs in anims.items():
        if bs:
            save_strip(rgba, bs, group, a, factor)


def factor_for(group, anim, boxes, default_h):
    h = mget(group, anim, "cell_h", default_h)
    return h / max(1.0, med_h(boxes))


WALK_A = [("idle", 1), ("idle_x", 1), ("idle_up", 1), ("idle_up_x", 1), ("idle_side", 1), ("idle_side_x", 1),
          ("walk_down", 4), ("walk_up", 4), ("walk_a", 2)]


def villager_pair(rgba, ra, rb, group, rowb_spec, h=100):
    """Row A: idle d/u/s x2, walk down/up x4, side x2. Row B: side x2 more + extras."""
    a = layout(row_fix(rgba, ra, 16), WALK_A)
    b = layout(row_fix(rgba, rb, sum(n for _, n in rowb_spec)), rowb_spec)
    f = h / max(1.0, med_h(a["idle"] + a["walk_down"]))
    anims = {"idle": a["idle"], "idle_up": a["idle_up"], "idle_side": a["idle_side"],
             "walk_down": a["walk_down"], "walk_up": a["walk_up"], "walk": a["walk_a"] + b.pop("walk_b", [])}
    anims.update({k: v for k, v in b.items()})
    emit(rgba, group, anims, f)


def row_fix(rgba, row, n):
    return row_n(rgba, row, n, min_gap=2)


ROWB_TALK = [("walk_b", 2), ("talk", 4), ("work", 4), ("wave", 2)]


def villager_sheet(file, groups, kid=()):
    rgba, rows = char_rows(file)
    for i, g in enumerate(groups):
        if 2 * i + 1 >= len(rows):
            break
        villager_pair(rgba, rows[2 * i], rows[2 * i + 1], g, ROWB_TALK, 70 if g in kid else 100)


def w465():
    villager_sheet("w465_mabel_walk.png", ["characters/npc_mabel"], kid=["characters/npc_mabel"])


def w376():
    rgba, rows = char_rows("w376_hollow_heart_people.png")
    who = ["wick", "lumen", "delve"]
    for i, w in enumerate(who):
        villager_pair(rgba, rows[2 * i], rows[2 * i + 1], "characters/npc_" + w, ROWB_TALK)
    if len(rows) > 6:
        segs = row_n(rgba, rows[6], 9, min_gap=3)
        for i, w in enumerate(who):
            for m, b in zip(["neutral", "happy", "surprised"], segs[3 * i:3 * i + 3]):
                save(piece(rgba, b, h=96, w=124), "portraits/npc_" + w, m)


SEASON = [("idle", 1), ("idle_up", 1), ("idle_side", 1), ("walk", 4), ("walk_down", 4), ("walk_up", 4)]


def season_sheet(file, groups, kid=()):
    rgba, rows = char_rows(file)
    for g, r in zip(groups, rows):
        a = layout(row_fix(rgba, r, 15), SEASON)
        f = (70 if g in kid else 100) / max(1.0, med_h(a["idle"] + a["walk_down"]))
        emit(rgba, g, a, f)


def w487():
    season_sheet("w487_seasonal_walks_a.png", ["characters/npc_maple_winter", "characters/npc_finn_winter",
                                                "characters/npc_posy_winter", "characters/npc_lumi_winter"])


def w488():
    season_sheet("w488_seasonal_walks_b.png", ["characters/npc_bram_festival", "characters/npc_juniper_winter",
                                                "characters/npc_rook_winter", "characters/npc_sal_winter"])


def w489():
    season_sheet("w489_seasonal_walks_kids.png", ["characters/npc_pip_winter", "characters/npc_tobin_summer"],
                 kid=["characters/npc_pip_winter", "characters/npc_tobin_summer"])


LIFE = ["work", "work_2", "sit", "talk", "talk_2", "laugh", "wave", "sleep", "carry", "eat", "dance", "dance_2",
        "umbrella", "shiver", "fish", "counter"]


KIDS = ["pip", "wren_jr", "tobin", "mabel"]


def life_sheet(file, ids):
    rgba, rows = char_rows(file, merge=2, min_area=400, frac=0.5)
    for who, r in zip(ids, rows):
        g = "characters/npc_" + who
        segs = row_fix(rgba, r, 16)
        # height from the walker this villager wears, so poses match it
        stand = [segs[i] for i in (3, 4, 6) if i < len(segs)]
        f = (70 if who in KIDS else 100) / max(1.0, med_h(stand))
        for pose, b in zip(LIFE, segs):
            save(piece(rgba, b, factor=f), g, pose)
            S.manifest[g][pose].update({"cell_w": S.manifest[g][pose]["w"], "cell_h": S.manifest[g][pose]["h"], "frames": 1})


def w482(): life_sheet("w482_life_poses_a.png", ["maple", "finn", "lumi"])
def w483(): life_sheet("w483_life_poses_b.png", ["bram", "posy", "juniper"])
def w484(): life_sheet("w484_life_poses_c.png", ["rook", "sal", "tobin"])
def w485(): life_sheet("w485_life_poses_kids.png", ["pip", "wren_jr", "mabel"])
def w486():
    life_sheet("w486_life_poses_d.png", ["ivy", "tam"])
    # Old Moss's row came out overlapped (hat brims touch): keep his walker for now
    g = "characters/npc_old_moss"
    for pose in LIFE:
        if pose != "work" and pose in S.manifest.get(g, {}):
            f = os.path.join(S.OUT, S.manifest[g][pose]["file"])
            if os.path.exists(f): os.remove(f)
            S.manifest[g].pop(pose)
def w490(): life_sheet("w490_life_poses_hats.png", ["marlowe", "benno"])


# ---------------------------------------------------------------- thugs and foes

THUG_A = [("idle", 2), ("idle_up", 2), ("idle_side", 2), ("walk_down", 4), ("walk_up", 4), ("walk_a", 2)]
THUG_B = [("walk_b", 2), ("attack", 4), ("hurt", 2), ("die", 2)]


def thug_sheet(file, ids):
    rgba, rows = char_rows(file, merge=2, min_area=300, frac=0.5)
    for i, who in enumerate(ids):
        if 2 * i + 1 >= len(rows):
            break
        g = "characters/" + who
        a = layout(row_fix(rgba, rows[2 * i], 16), THUG_A)
        b = layout(row_fix(rgba, rows[2 * i + 1], 10), THUG_B)
        f = 54 / max(1.0, med_h(a["idle"]))
        anims = {"idle": a["idle"], "idle_up": a["idle_up"], "idle_side": a["idle_side"], "walk_down": a["walk_down"],
                 "walk_up": a["walk_up"], "walk": a["walk_a"] + b["walk_b"], "attack": b["attack"], "hurt": b["hurt"], "die": b["die"]}
        emit(rgba, g, anims, f)
        # face views for the menus that show them
        for v, src in (("view_front", a["idle"][:1]), ("view_back", a["idle_up"][:1]), ("view_right", a["idle_side"][:1])):
            if src:
                save(piece(rgba, src[0], factor=f), g, v)
        if a["idle_side"]:
            save(piece(rgba, a["idle_side"][0], factor=f).transpose(Image.FLIP_LEFT_RIGHT), g, "view_left")


def w414(): thug_sheet("w414_thug_walks_a.png", ["cyber", "brute", "flame"])
def w415(): thug_sheet("w415_thug_walks_b.png", ["speedster", "gambler", "enforcer"])
def w428(): thug_sheet("w428_lookout.png", ["lookout"])


def w417():
    f_ = "w417b_enemy_attacks.png" if have("w417b_enemy_attacks.png") else None
    if not f_:
        return  # the first render (no references) didn't match the game's foes
    rgba = load(f_)
    rows = bands(rgba, 7)
    names = ["slime", "bat", "hill_wolf", "rock_crab", "wisp", "mud_slime", "grump"]
    for nm, r in zip(names, rows):
        segs = row_n(rgba, r, 6)
        g = "enemies/" + nm
        f = mget(g, "idle", "cell_h", 40) / max(1.0, med_h(segs[:1]))
        save_strip(rgba, segs[1:5], g, "attack", f)


def w470():
    rgba, rows = char_rows("w470_enemy_attacks_2.png", merge=2, min_area=200, frac=0.1)
    gol = row_fix(rgba, rows[0], 6)
    save_strip(rgba, gol[1:5], "enemies/golem", "attack", factor_for("enemies/golem", "idle", gol[:1], 84))
    sh = [b for b in rows[1] if b[3] - b[1] > 60]
    sh = row_fix(rgba, sh, 6)
    save_strip(rgba, sh[1:5], "enemies/shard", "attack", factor_for("enemies/shard", "idle", sh[:1], 56))
    spl = [b for r in rows[2:] for b in r][:2]
    if spl:
        save_strip(rgba, spl, "fx", "shot_shard", 24 / med_h(spl))


def boss_rows(file, group, spec, h, merge=3):
    rgba, rows = char_rows(file, merge=merge, min_area=800, frac=0.5)
    out = {}
    for (names, n), r in zip(spec, rows):
        segs = row_fix(rgba, r, n)
        out.update(layout(segs, names))
    f = h / max(1.0, med_h(out.get("idle", [])))
    emit(rgba, group, out, f)


def w472():
    boss_rows("w472_big_grump_boss.png", "enemies/big_grump",
              [([("idle", 4)], 4), ([("walk", 4)], 4), ([("attack", 6)], 6), ([("hurt", 2)], 2), ([("die", 4)], 4)], 92)


def w366():
    boss_rows("w366_cboss_kelp.png", "enemies/cboss_kelp",
              [([("idle", 4)], 4), ([("walk", 4)], 4), ([("attack", 4)], 4), ([("hurt", 2), ("die", 4)], 6)], 96)


def w367():
    boss_rows("w367_cboss_ice.png", "enemies/cboss_ice",
              [([("idle", 4)], 4), ([("walk", 4)], 4), ([("attack", 4)], 4), ([("split", 4), ("hurt", 2)], 6), ([("die", 4)], 4)], 96)


def w368():
    boss_rows("w368_cboss_ember.png", "enemies/cboss_ember",
              [([("idle", 4)], 4), ([("walk", 4)], 4), ([("attack", 4)], 4), ([("hurt", 2), ("smoke", 2)], 4), ([("die", 4)], 4)], 96)


# ---------------------------------------------------------------- animals

DOG_FIGHT = [("bite", 4), ("bark2", 2), ("hurt", 2), ("limp", 4), ("guard", 2), ("howl", 2)]


def w481():
    rgba, rows = char_rows("w481_dog_fight_match.png", merge=2, min_area=150, frac=0.4)
    for who, r in zip(["dog_golden", "dog_collie", "dog_husky"], rows):
        segs = row_fix(rgba, r, 16)
        g = "animals/" + who
        f = 30 / max(1.0, med_h(segs))
        emit(rgba, g, layout(segs, DOG_FIGHT), f)


def w469():
    rgba, rows = char_rows("w469_pet_poses.png", merge=2, min_area=150, frac=0.4)
    who = ["dog_collie", "dog_golden", "dog_husky", "dog_hound", "dog_white", "cat_orange", "cat_grey", "cat_calico"]
    for i, (w, r) in enumerate(zip(who, rows)):
        g = "animals/" + w
        if i < 3:
            segs = row_fix(rgba, r, 8)
            spec = [("play", 2), ("fetch", 4), ("beg", 2)]
        else:
            segs = row_fix(rgba, r, 12)
            spec = [("dig", 6), ("fetch", 4), ("beg", 2)]
        f = mget(g, "idle", "cell_h", 30) / max(1.0, med_h(segs))
        emit(rgba, g, layout(segs, spec), f)


PUP = [[("idle", 2), ("idle_down", 2), ("idle_up", 2), ("walk", 4), ("walk_down", 4), ("walk_up_a", 2)],
       [("walk_up_b", 2), ("run", 4), ("sit", 2), ("lie", 2), ("sleep", 2), ("bark", 2), ("play", 2)],
       [("bite", 4), ("hurt", 2), ("limp", 4), ("guard", 2), ("howl", 2), ("beg", 2)],
       [("dig", 6), ("fetch", 4), ("roll", 2), ("jump", 4)],
       [("downed", 2), ("getup", 4), ("eat", 4), ("shake", 6)]]


def w364():
    rgba = load("w364_pup_classic.png")
    rows = bands(rgba, 5)
    out = {}
    for spec, r in zip(PUP, rows):
        out.update(layout(row_fix(rgba, r, sum(n for _, n in spec)), spec))
    out["walk_up"] = out.pop("walk_up_a", []) + out.pop("walk_up_b", [])
    f = 49 / max(1.0, med_h(out["idle"]))
    # the render's rows drift by a frame in places: keep only the strips that read right
    keep = ["walk", "walk_down", "walk_up", "idle", "idle_down", "idle_up", "dig", "jump", "lie", "roll", "getup",
            "downed", "bite", "howl", "hurt", "guard", "limp", "beg"]
    emit(rgba, "animals/pup", {k: v for k, v in out.items() if k in keep}, f)


def w448c():
    f_ = "w448c_biscuit_old_dog.png" if have("w448c_biscuit_old_dog.png") else "w448_biscuit_old_dog.png"
    rgba, rows = char_rows(f_, merge=3, min_area=200, frac=0.3)
    small = [r for r in rows if row_box(r)[3] - row_box(r)[1] < 200]
    out = {}
    if small:
        out.update(layout(row_fix(rgba, small[0], 16), [("idle", 2), ("idle_down", 2), ("walk", 4), ("walk_down", 4), ("sit", 2), ("wag", 2)]))
    if len(small) > 1:
        out.update(layout(row_fix(rgba, small[1], 10), [("lie", 2), ("sleep", 2), ("jump", 4), ("bark", 2)]))
    emit(rgba, "animals/biscuit", out, 49 / max(1.0, med_h(out.get("idle", []))))
    big = [b for r in rows for b in r if b[3] - b[1] > 300]
    if big:
        for m in ("neutral", "happy"):
            save(piece(rgba, big[0], h=96, w=110), "portraits/biscuit", m)


def w365():
    rgba, rows = char_rows("w365_pup_gear_overlays.png", merge=2, min_area=100, frac=0.2)
    pieces = [b for r in rows for b in r if b[0] < 860]  # skip the grey reference dogs at the right
    names = ["collar_leather", "collar_iron", "collar_crystal", "pack_small", "pack_large", "pack_trail", "boots", "bandana"]
    for i, nm in enumerate(names):
        trio = pieces[3 * i:3 * i + 3]
        for v, b in zip(["side", "front", "back"], trio):
            save(piece(rgba, b, factor=0.32), "animals/pet_gear", "%s_%s" % (nm, v))


# ---------------------------------------------------------------- president

def w362():
    rgba = load("w362_president.png")
    left = blobs(rgba, (0, 0, 1130, 1024), merge=2, min_area=500)
    rows = big_rows(rows_of(left), 0.5)
    g = "characters/president"
    if len(rows) >= 4:
        r0 = row_fix(rgba, rows[0], 4); r1 = row_fix(rgba, rows[1], 12)
        r2 = row_fix(rgba, rows[2], 12); r3 = row_fix(rgba, rows[3], 6)
        f = mget(g, "idle", "cell_h", 82) / max(1.0, med_h(r0[2:4]))
        emit(rgba, g, {"seated": r0[0:2], "idle": r0[2:4], "walk_down": r1[0:4], "walk_up": r1[4:8], "walk": r1[8:12],
                       "attack": r2[0:6], "charge": r2[6:10], "hurt": r2[10:12], "defeated": r3[0:3], "freed": r3[3:6]}, f)
    right = blobs(rgba, (1130, 0, 1536, 1024), merge=1, min_area=3000)
    ports = sorted([b for b in right if b[3] - b[1] < 250], key=lambda b: (b[1] // 80, b[0]))
    if len(ports) == 1:
        ports = [c for row in even_grid(rgba, ports[0], 2, 3) for c in row]
    clear_group("portraits/president")
    for m, b in zip(["warm", "cold", "angry", "pleading", "broken", "freed"], ports):
        save(piece(rgba, b, h=96, w=110), "portraits/president", m)
    alias = {"neutral": 1, "happy": 0, "kind": 0, "sad": 4, "worried": 3, "surprised": 3, "sly": 1}
    for m, i in alias.items():
        if i < len(ports):
            save(piece(rgba, ports[i], h=96, w=110), "portraits/president", m)
    cards = [b for b in right if b[3] - b[1] >= 250]
    if cards:
        save_piece(rgba, cards[0], "ui", "card_president_tall", w=300, h=420)


# ---------------------------------------------------------------- cards, cuts, icons

def split_rows_even(rgba, n_rows, n_cols):
    return even_grid(rgba, content_box(rgba), n_cols, n_rows)


def w455():
    rgba = load("w455_boss_cards_story.png")
    for nm, row in zip(["card_commander", "card_knight", "card_light_eater"], split_rows_even(rgba, 3, 1)):
        save_piece(rgba, row[0], "ui", nm, w=764, h=322)


def w456():
    rgba, rows = sheet_rows("w456_boss_cards_colonies.png", merge=1, min_area=5000)
    bs = [b for r in rows for b in r]
    for nm, b in zip(["card_cboss_coral", "card_cboss_kelp", "card_cboss_ice", "card_cboss_ember"], bs):
        save_piece(rgba, b, "ui", nm, w=600, h=400)


def party_cards(file, sprites, per_row):
    rgba, rows = sheet_rows(file, merge=1, min_area=3000)
    cards = []
    for r in big_rows(rows):
        cards += row_n(rgba, r, per_row, min_gap=6)
    if len(cards) < 2 * len(sprites):  # rows came out as one blob: even grid
        cards = [c for row in split_rows_even(rgba, len(sprites) * 2 // per_row, per_row) for c in row]
    for i, sp in enumerate(sprites):
        if 2 * i + 1 < len(cards):
            save_piece(rgba, cards[2 * i], "ui", "party_card_" + sp, w=146, h=60)
            save_piece(rgba, cards[2 * i + 1], "ui", "party_card_%s_sel" % sp, w=170, h=60)


def w458(): party_cards("w458_party_cards_family.png", ["man", "woman", "son", "girl", "npc_drifter"], 2)
def w459(): party_cards("w459_party_cards_marked.png", ["mk_kit", "mk_ember", "mk_dahlia", "mk_juno", "mk_rio", "mk_mei",
                                                        "mk_bruno", "mk_tomas", "mk_sable", "mk_atlas"], 4)


def w436():
    rgba, rows = sheet_rows("w436_hero_cards.png", merge=1, min_area=5000)
    segs = row_n(rgba, big_rows(rows)[0], 4, min_gap=6)
    for nm, b in zip(["card_hero_coldy", "card_hero_coldy_sel", "card_hero_big_jim", "card_hero_big_jim_sel"], segs):
        save_piece(rgba, b, "ui", nm, w=120, h=160)


def w251b():
    rgba, rows = sheet_rows("w251b_portraits_cards_b.png", merge=1, min_area=1500)
    rows = big_rows(rows, 0.1)
    # top: four groups of 6 moods (2 rows of 3)
    tops = [b for b in blobs(rgba, (0, 0, 1536, 330), merge=1, min_area=1500)]
    tops = rows_of(tops)
    sprites = ["coldy", "big_jim", "penguin_king", "penguin_wizard"]
    if len(tops) >= 2:
        for r_i, r in enumerate(tops[:2]):
            segs = row_n(rgba, r, 12, min_gap=3)
            for k in range(12):
                who = sprites[k // 3]
                m = ["neutral", "happy", "sad", "angry", "surprised", "sly"][r_i * 3 + k % 3]
                if not S.manifest.get("portraits/" + who, {}).get(m):
                    save(piece(rgba, segs[k], h=96, w=110), "portraits/" + who, m)
    cards = [b for b in blobs(rgba, (0, 330, 1536, 720), merge=1, min_area=5000)]
    for who, b in zip(sprites, sorted(cards, key=lambda b: b[0])):
        if not S.manifest.get("ui", {}).get("card_hero_" + who):
            save_piece(rgba, b, "ui", "card_hero_" + who, w=120, h=160)
    icons = sorted(blobs(rgba, (0, 720, 1536, 850), merge=1, min_area=1500), key=lambda b: b[0])
    for who, b in zip(sprites, icons):
        save_piece(rgba, b, "ui", "icon_party_" + who, w=32, h=32)


def w253c():
    rgba, rows = sheet_rows("w253c_gate_scenes.png", merge=1, min_area=5000)
    bs = [c for row in split_rows_even(rgba, 2, 2) for c in row]
    for who, b in zip(["coldy", "big_jim", "penguin_king", "penguin_wizard"], bs):
        save_piece(rgba, b, "ui", "gate_" + who, w=320, h=160)


def cuts(file, names, rows_, cols):
    rgba = load(file)
    for nm, b in zip(names, [c for row in split_rows_even(rgba, rows_, cols) for c in row]):
        save_piece(rgba, b, "ui", nm, w=267, h=180)


def w433(): cuts("w433_cut_penguin.png", ["cut_two_crystals", "cut_quiet_mountain"], 1, 2)
def w434(): cuts("w434_cut_gangster.png", ["cut_letter", "cut_tower_doors", "cut_president_chair", "cut_stone_break"], 2, 2)
def w449(): cuts("w449_cut_rain_road.png", ["cut_rain_road", "cut_old_dog"], 1, 2)
def w271(): cuts("w271_cutscene_panels_b.png", ["cut_crystal_prison", "cut_uphill_stream", "cut_merkitty_ring", "cut_prismatica_top"], 2, 2)


def w361():
    im = Image.open(os.path.join(S.INC, "w361_endings.png")).convert("RGBA")
    W, H = im.size
    boxes = [(0, 0, W // 2 - 8, H // 2 - 8), (W // 2 + 8, 0, W, H // 2 - 8), (0, H // 2 + 8, W // 2 - 8, H), (W // 2 + 8, H // 2 + 8, W, H)]
    for nm, b in zip(["ending_two_crystals", "ending_quiet_mountain", "ending_tired_man", "ending_the_chair"], boxes):
        save(im.crop(b).resize((372, 244), Image.LANCZOS), "ui", nm)


def w363():
    im = Image.open(os.path.join(S.INC, "w363_app_icon.png")).convert("RGBA")
    d = os.path.join(S.ROOT, "art", "app")
    os.makedirs(d, exist_ok=True)
    for s in (1024, 512, 192, 180, 128, 64, 48, 32):
        im.resize((s, s), Image.LANCZOS).save(os.path.join(d, "icon_%d.png" % s))
    save(im.resize((128, 128), Image.LANCZOS), "ui", "app_icon")


ABIL = ["penguin_king", "penguin_wizard", "man", "woman", "son", "girl", "coldy", "big_jim", "npc_drifter",
        "mk_kit", "mk_ember", "mk_dahlia", "mk_juno", "mk_rio", "mk_mei", "mk_bruno", "mk_tomas", "mk_sable", "mk_atlas", "pup"]


def w473():
    rgba, rows = sheet_rows("w473_partner_ability_icons.png", merge=1, min_area=3000)
    bs = [b for r in big_rows(rows) for b in row_n(rgba, r, 5, min_gap=6)]
    for nm, b in zip(ABIL, bs):
        save_piece(rgba, b, "ui", "icon_ability_" + nm, w=48, h=48)


UNLOCK_474 = ["wide spout", "tremor", "domino fall", "tidecall", "iron gut", "not today", "lucky day", "quick build",
              "twin cast", "quartermaster", "drill sergeant", "rally cry", "field medic", "hot loads", "heavy hitter"]


def w474():
    sk = json.load(open(os.path.join(S.ROOT, "data", "skills.json")))["skills"]
    by = {}
    for s, d in sk.items():
        for n in d["nodes"]:
            if n.get("unlock"):
                by.setdefault(str(n["name"]).lower(), []).append((s, n["id"]))
    rgba, rows = sheet_rows("w474_unlock_node_icons.png", merge=1, min_area=3000)
    bs = [b for r in big_rows(rows) for b in row_n(rgba, r, 5, min_gap=6)]
    hit = 0
    for nm, b in zip(UNLOCK_474, bs):
        for s, nid in by.get(nm, []):
            save_piece(rgba, b, "ui", "node_%s_%s" % (s, nid), w=48, h=48); hit += 1
    print("   unlock icons matched", hit)


# ---------------------------------------------------------------- buildings (replace in place, same canvas)

def fit_canvas(im, W, H):
    im = scale_to(im, width=W, height=H)
    out = Image.new("RGBA", (W, H))
    out.alpha_composite(im, ((W - im.width) // 2, H - im.height))
    return out


def replace(rgba, b, group, name, night=None):
    info = S.manifest.get(group, {}).get(name)
    if not info:
        print("   (no original for %s/%s)" % (group, name)); return
    W, H = info["w"], info["h"]
    fr = info.get("frames")
    im = fit_canvas(crop(rgba, b), W, H)
    save(im, group, name)
    if night is not None:
        save(fit_canvas(crop(rgba, night), W, H), group, name + "_night")


def replace_anim(rgba, boxes, group, name):
    info = S.manifest.get(group, {}).get(name)
    if not info:
        return
    cw, ch, n = info.get("cell_w", info["w"]), info.get("cell_h", info["h"]), info.get("frames", 1)
    frames = [fit_canvas(crop(rgba, b), cw, ch) for b in boxes[:n]]
    while len(frames) < n:
        frames.append(frames[-1])
    out = Image.new("RGBA", (cw * n, ch))
    for i, f in enumerate(frames):
        out.alpha_composite(f, (i * cw, 0))
    save(out, group, name)
    S.manifest[group][name].update({"cell_w": cw, "cell_h": ch, "frames": n})


def day_night(file, names):
    rgba, rows = sheet_rows(file, merge=4, min_area=5000)
    rows = big_rows(rows, 0.3)
    for (g, nm), r in zip(names, rows):
        if len(r) >= 2:
            replace(rgba, r[0], g, nm, night=r[1])
        elif r:
            replace(rgba, r[0], g, nm)


B = "buildings"
def w494(): day_night("w494_town_store_smith.png", [(B, "store"), (B, "smith")])
def w495(): day_night("w495_town_potions_bakery.png", [(B, "potions"), (B, "bakery")])
def w496(): day_night("w496_town_inn_library.png", [(B, "inn"), (B, "library")])
def w497(): day_night("w497_town_clinic_chapel.png", [(B, "clinic"), (B, "chapel")])
def w498(): day_night("w498_town_hall_bank.png", [(B, "hall"), (B, "bank")])
def w499(): day_night("w499_town_mansion_school.png", [(B, "mansion"), (B, "school")])
def w500(): day_night("w500_town_cottages.png", [(B, "cottage_a"), (B, "cottage_b"), (B, "cottage_c")])
def w501(): day_night("w501_town_hazel_stable.png", [(B, "hazel_house"), (B, "stable")])
def w502(): day_night("w502_town_lodge_warehouse.png", [(B, "woodcutter_hut"), (B, "warehouse_a")])
def w503(): day_night("w503_town_clock_bandstand.png", [(B, "clock_tower"), (B, "bandstand")])
def w513(): day_night("w513_lake_bait_shop.png", [(B, "fishing_hut")])


def w516():
    rgba, rows = sheet_rows("w516_farmhouse_tiers.png", merge=4, min_area=5000)
    rows = big_rows(rows, 0.3)
    for nm, r in zip(["house", "house_2", "house_3"], rows):
        if nm == "house":
            replace(rgba, r[0], B, nm, night=r[1] if len(r) > 1 else None)
        else:  # upgrades: new art, scaled like tier 1
            s = S.manifest[B]["house"]["w"] / max(1, rows[0][0][2] - rows[0][0][0])
            save(piece(rgba, r[0], factor=s), B, nm)
            if len(r) > 1:
                save(piece(rgba, r[1], factor=s), B, nm + "_night")


def w517():
    rgba, rows = sheet_rows("w517_farm_coop_barn.png", merge=4, min_area=5000)
    bs = [b for r in big_rows(rows, 0.3) for b in r]
    for nm, b in zip(["coop_small", "coop_big", "barn_small", "barn_big"], bs):
        replace(rgba, b, "props", nm)


def w518():
    rgba, rows = sheet_rows("w518_farm_shed_stable.png", merge=4, min_area=5000)
    bs = [b for r in big_rows(rows, 0.3) for b in r]
    for nm, b in zip(["shed", "workshop", "stable2"], bs):
        if nm == "workshop":
            s = S.manifest["props"]["shed"]["w"] / max(1, bs[0][2] - bs[0][0])
            save(piece(rgba, b, factor=s), "props", nm)
        else:
            replace(rgba, b, "props", nm)


def w514():
    rgba, rows = sheet_rows("w514_lake_water_mill.png", merge=4, min_area=5000)
    replace_anim(rgba, [b for r in big_rows(rows, 0.3) for b in r], B, "water_mill")


def w515():
    rgba, rows = sheet_rows("w515_lake_lighthouse.png", merge=4, min_area=5000)
    rows = big_rows(rows, 0.2)
    replace_anim(rgba, row_fix(rgba, rows[0], 4), B, "lighthouse")
    if len(rows) > 1:
        lamps = row_fix(rgba, rows[1], 4)
        save_strip(rgba, lamps, "props", "lighthouse_lamp", 48 / med_h(lamps))


def w519():
    rgba, rows = sheet_rows("w519_neon_arcade_noodles.png", merge=4, min_area=5000)
    rows = big_rows(rows, 0.3)
    replace_anim(rgba, rows[0], B, "arcade")
    if len(rows) > 1:
        replace_anim(rgba, rows[1], B, "noodle_stand")


def w520():
    rgba, rows = sheet_rows("w520_neon_dragon.png", merge=4, min_area=5000)
    replace_anim(rgba, [b for r in big_rows(rows, 0.3) for b in r], B, "neon_dragon")


def w521():
    rgba, rows = sheet_rows("w521_neon_hotel_ramen_karaoke.png", merge=4, min_area=5000)
    bs = [b for r in big_rows(rows, 0.3) for b in r]
    for (g, nm), b in zip([(B, "neon_hotel"), (B, "ramen_shop"), (B, "karaoke"), ("props", "diner_cyan")], bs):
        replace(rgba, b, g, nm)


def w522():
    rgba, rows = sheet_rows("w522_docks_uptown_buildings.png", merge=4, min_area=5000)
    bs = [b for r in big_rows(rows, 0.3) for b in r]
    for (g, nm), b in zip([(B, "warehouse_b"), (B, "warehouse_c"), ("props", "fish_market"), ("props", "guard_booth"), (B, "penthouse")], bs):
        replace(rgba, b, g, nm)


def w523():
    rgba, rows = sheet_rows("w523_hideout_roadside.png", merge=4, min_area=5000)
    bs = [b for r in big_rows(rows, 0.3) for b in r]
    for nm, b in zip(["gas_station", "diner_pink", "motel_cyan", "motel_pink"], bs):
        replace(rgba, b, "props", nm)


def w504():
    rgba, rows = sheet_rows("w504_mine_entrance.png", merge=4, min_area=5000)
    bs = [b for r in big_rows(rows, 0.3) for b in r]
    for i, b in enumerate(bs[:4]):
        save(piece(rgba, b, w=128, h=112), "props", "mine_hill_%d" % i)


def w446():
    rgba, rows = sheet_rows("w446_water_buildings.png", merge=4, min_area=5000)
    bs = [b for r in big_rows(rows, 0.3) for b in r]
    for nm, b in zip(["fishing_hut_stilts", "beaver_dam2", "fishing_hut_stilts_winter", "beaver_dam2_winter"], bs):
        save(piece(rgba, b, factor=0.3), "props", nm)


def w450():
    rgba, rows = sheet_rows("w450_ticket_booth.png", merge=4, min_area=5000)
    bs = [b for r in big_rows(rows, 0.3) for b in r]
    for nm, b in zip(["ticket_booth", "ticket_booth_closed", "prize_counter", "snack_cart"], bs):
        save(piece(rgba, b, factor=0.25), "props", nm)


def w435():
    rgba = load("w435_auk_ghost_tower.png")
    left = rows_of(blobs(rgba, (0, 0, 860, 1024), merge=3, min_area=1000))
    left = big_rows(left, 0.4)
    g = "characters/auk_ghost"
    spr = [r for r in left if row_box(r)[3] - row_box(r)[1] < 230]
    if len(spr) >= 4:
        f = 60 / max(1.0, med_h(spr[0]))
        emit(rgba, g, {"idle": row_fix(rgba, spr[0], 4), "talk": row_fix(rgba, spr[1], 4),
                       "bless": row_fix(rgba, spr[2], 4), "fade": row_fix(rgba, spr[3], 4)}, f)
    big = [r for r in left if row_box(r)[3] - row_box(r)[1] >= 230]
    if big:
        for m, b in zip(["kind", "sad", "proud"], row_n(rgba, big[0], 3)):
            save(piece(rgba, b, h=96, w=110), "portraits/auk_ghost", m)
        save(piece(rgba, row_n(rgba, big[0], 3)[0], h=96, w=110), "portraits/auk_ghost", "neutral")
    tower = blobs(rgba, (860, 0, 1536, 1024), merge=3, min_area=5000)
    if tower:
        b = max(tower, key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))
        replace(rgba, b, B, "president_tower_open") if S.manifest[B].get("president_tower_open") else \
            save(fit_canvas(crop(rgba, b), S.manifest[B]["president_tower"]["w"], S.manifest[B]["president_tower"]["h"]), B, "president_tower_open")


# ---------------------------------------------------------------- farm and mine props

STAGES = ["seed", "sprout", "young", "growing", "mature", "ready"]


def orchard(file, ids):
    rgba, rows = sheet_rows(file, merge=3, min_area=150)
    rows = big_rows(rows, 0.15)
    allb = sorted([b for r in rows for b in r], key=lambda b: b[1])
    # rows by baseline (trunk bottoms line up)
    groups = rows_of(allb, overlap=0.05)
    by_base = []
    for b in allb:
        for g in by_base:
            if abs(g[0][3] - b[3]) < 40:
                g.append(b); break
        else:
            by_base.append([b])
    by_base = [sorted(g, key=lambda b: b[0]) for g in sorted(by_base, key=lambda g: g[0][3]) if len(g) >= 4]
    for tid, r in zip(ids, by_base):
        r = r[:6] if len(r) >= 6 else r
        ready = S.manifest["crops"].get(tid + "_ready", {"w": 114, "h": 118})
        f = min(ready["w"] / max(1, r[-1][2] - r[-1][0]), ready["h"] / max(1, r[-1][3] - r[-1][1]))
        for st, b in zip(STAGES[-len(r):] if len(r) < 6 else STAGES, r):
            save(piece(rgba, b, factor=f), "crops", "%s_%s" % (tid, st))


def w424(): orchard("w424_orchard_trees_a.png", ["apple", "peach", "orange", "lemon"])
def w425(): orchard("w425_orchard_trees_b.png", ["cherry", "pomegranate", "celestial_apple", "mango"])


def w420():
    rgba, rows = sheet_rows("w420_ore_nodes.png", merge=2, min_area=300)
    names = ["coal", "copper", "iron", "silver", "gold", "crystal", "amethyst", "emerald", "fossil", "dark"]
    for nm, r in zip(names, big_rows(rows)):
        for i, b in enumerate(r[:3]):
            key = "ore_" + nm + ("" if i == 0 else "_%d" % i)
            save(piece(rgba, b, w=36, h=34), "props", key)


def w423():
    rgba, rows = sheet_rows("w423_sprinklers.png", merge=10, min_area=500)
    rows = big_rows(rows, 0.3)
    for nm, r in zip(["sprinkler_basic", "sprinkler_quality", "sprinkler_iridium"], rows[:3]):
        segs = row_fix(rgba, r, 4)
        info = S.manifest["props"].get(nm, {})
        frames = [fit_canvas(crop(rgba, b), 40, 40) for b in segs]
        strip(frames, "props", nm + "_spray")
    if len(rows) > 3:
        for nm, b in zip(["sprinkler", "sprinkler_quality", "sprinkler_iridium"], row_fix(rgba, rows[3], 3)):
            save(icon(rgba, b, 32), "items", nm)


def w430():
    rgba, rows = sheet_rows("w430_crystal_trees.png", merge=3, min_area=800)
    rows = big_rows(rows, 0.3)
    allb = [b for r in rows for b in r]
    big = [b for b in allb if b[3] - b[1] > 200]
    if big:
        replace(rgba, big[0], "props", "crystal_tree")
        f = S.manifest["props"]["crystal_tree"]["h"] / max(1, big[0][3] - big[0][1])
        if len(big) >= 5:
            save_strip(rgba, big[1:5], "props", "crystal_tree_sway", f)
        tail = sorted(big, key=lambda b: (b[1] // 150, b[0]))[-2:]
        for nm, b in zip(["crystal_tree_pink", "crystal_tree_frost"], tail):
            save(piece(rgba, b, factor=f), "props", nm)
        stumps = [b for b in allb if 60 < b[3] - b[1] < 200 and b[1] > 600]
        if stumps:
            save(piece(rgba, stumps[0], factor=f), "props", "crystal_stump")


def w429():
    rgba, rows = sheet_rows("w429_crystal_pylon.png", merge=3, min_area=2000)
    allb = sorted([b for r in big_rows(rows, 0.3) for b in r], key=lambda b: (b[1] // 200, b[0]))
    tall = [b for b in allb if b[3] - b[1] > 150]
    if len(tall) >= 16:
        f = S.manifest["battle"]["pylon"]["h"] / max(1, med_h(tall[:4]))
        save(piece(rgba, tall[0], factor=f), "battle", "pylon")
        emit(rgba, "battle/pylon_anim", {"idle": tall[0:4], "fire": tall[4:8], "hurt": tall[8:10], "cracked": tall[10:12],
                                          "lv2": tall[12:14], "lv3": tall[14:16]}, f)


def w426():
    rgba, rows = sheet_rows("w426_incubator_silo.png", merge=4, min_area=800)
    allb = [b for r in big_rows(rows, 0.1) for b in r]
    inc = [b for b in allb if b[1] < 300][:4]
    if inc:
        save_strip(rgba, inc[:3], "props", "incubator", 64 / med_h(inc))
        save(piece(rgba, inc[-1], factor=64 / med_h(inc)), "props", "incubator_hatched")
    silos = sorted([b for b in allb if b[3] - b[1] > 300], key=lambda b: b[0])
    if silos:
        replace(rgba, silos[0], B, "silo")
        if len(silos) > 1:
            replace(rgba, silos[1], B, "silo2") if S.manifest[B].get("silo2") else save(fit_canvas(crop(rgba, silos[1]), S.manifest[B]["silo"]["w"], S.manifest[B]["silo"]["h"]), B, "silo_open")
    em = sorted([b for b in allb if b[0] > 900 and b[3] - b[1] < 150], key=lambda b: (b[1] // 100, b[0]))
    if len(em) >= 4:
        save_strip(rgba, em[0:2], "emotes", "hungry", 24 / med_h(em))
        save_strip(rgba, em[2:4], "emotes", "happy_heart", 24 / med_h(em))


def w427():
    rgba, rows = char_rows("w427_ferry_and_pip.png", merge=3, min_area=500, frac=0.2)
    boats = rows[0][:6]
    save_strip(rgba, boats[:3], "props", "ferry_moored", 112 / med_h(boats))
    save_strip(rgba, boats[3:6], "props", "ferry_sailing", 112 / med_h(boats))
    if len(rows) >= 3:
        villager_pair(rgba, rows[1], rows[2], "characters/pip_cat",
                      [("walk_b", 2), ("wave", 4), ("row", 4), ("yawn", 2), ("sit", 2)], 70)
    port = [b for r in rows[3:] for b in r if b[3] - b[1] > 150]
    for m, b in zip(["neutral", "happy"], port):
        save(piece(rgba, b, h=96, w=96), "portraits/pip_cat", m)


def w462():
    rgba, rows = char_rows("w462_headgear_poses.png", merge=2, min_area=40, frac=0.2)
    names = ["fedora", "shades", "snow_goggles", "aurora_hood", "crystal_helm", "moon_helm", "gold_helm", "silver_helm"]
    order = ["idle_down", "idle_up", "idle_side", "walk_side_1", "walk_side_2", "walk_side_3", "walk_side_4",
             "walk_down_1", "walk_down_2", "walk_down_3", "walk_down_4", "walk_up_1", "walk_up_2", "walk_up_3", "walk_up_4", "run_side"]
    for nm, r in zip(names, rows):
        segs = row_fix(rgba, r, 16)
        frames = [piece(rgba, b, factor=0.5) for b in segs]
        strip(frames, "hats_poses", nm)


def costume(file, kind):
    rgba, rows = char_rows(file, merge=2, min_area=200, frac=0.5)
    names = ["pinstripe", "vest", "armored", "parka", "crystal_parka", "starlight"]
    for nm, r in zip(names, rows):
        segs = row_fix(rgba, r, 16)
        f = 52 / max(1.0, med_h(segs[:3]))
        strip([piece(rgba, b, factor=f) for b in segs], "body", "outfit_%s%s" % (nm, "" if kind == "walk" else "_act"))


def w460(): costume("w460_costume_new_walk.png", "walk")
def w461(): costume("w461_costume_new_action.png", "act")


# ---------------------------------------------------------------- effects

def fx_rows(file, names, frames=6, size=96, merge=6):
    rgba = load(file)
    # effects are loose clouds of particles: cut each row into equal frames
    m = rgba[..., 3] > 40
    ys = np.where(m.any(axis=1))[0]
    bands, start, prev = [], None, None
    for y in ys:
        if start is None: start = y
        elif y - prev > 10:
            bands.append((start, prev + 1)); start = y
        prev = y
    if start is not None: bands.append((start, prev + 1))
    bands = [b for b in bands if b[1] - b[0] > 12]
    for nm, (y0, y1) in zip(names, bands):
        xs = np.where(m[y0:y1].any(axis=0))[0]
        x0, x1 = xs.min(), xs.max() + 1
        w = (x1 - x0) / frames
        fr = []
        for i in range(frames):
            sub = Image.fromarray(rgba[y0:y1, int(x0 + i * w):int(x0 + (i + 1) * w)])
            c = Image.new("RGBA", (size, size))
            s = scale_to(sub, width=size, height=size)
            c.alpha_composite(s, ((size - s.width) // 2, (size - s.height) // 2))
            fr.append(c)
        strip(fr, "fx", nm)


def w418():
    fx_rows("w418_ability_fx_a.png", ["ab_paw_burst", "ab_leaf_heal", "ab_fish_wave", "ab_crystal_shield", "ab_sleep_cloud",
                                       "ab_whirlwind", "ab_seed_ring", "ab_lantern_flash", "ab_snow_burst"])


def w419():
    fx_rows("w419_ability_fx_b.png", ["ab_bubbles", "ab_thunder", "ab_petals", "ab_music_ring", "ab_rock_pillar",
                                       "ab_heart_pulse", "ab_dash", "ab_star_shower", "ab_glow_net"])


def w457():
    fx_rows("w457_boss_gift_fx.png", ["gift_grudge", "gift_marching", "gift_heart_of_stone", "gift_long_watch", "gift_hunger"], frames=8)


def w373():
    im = np.asarray(Image.open(os.path.join(S.INC, "w373_night_lights.png")).convert("RGBA")).copy()
    # black background: brightness becomes alpha (glows are added on top of darkness)
    lum = im[..., :3].max(axis=2).astype(np.float32)
    im[..., 3] = np.clip(lum * 1.4, 0, 255).astype(np.uint8)
    rgba = im
    rows = big_rows(rows_of(blobs(rgba, merge=6, min_area=200, alpha=25)), 0.2)
    names = [["glow_lamp"], ["glow_crystal"]]
    flat = [b for r in rows for b in r]
    flat.sort(key=lambda b: (b[1] // 120, b[0]))
    groups = {"glow_lamp": flat[0:4], "glow_crystal": flat[4:8], "glow_lantern": flat[8:12], "glow_campfire": flat[12:16],
              "glow_neon_pink": flat[16:18], "glow_neon_cyan": flat[18:20], "glow_neon_green": flat[20:22], "firefly": flat[22:26]}
    for nm, bs in groups.items():
        if bs:
            save_strip(rgba, bs, "fx", nm, 0.6)
    if len(flat) > 26:
        save_piece(rgba, flat[-1], "fx", "glow_window_pool", factor=0.5)


# ---------------------------------------------------------------- seamless squares

def seamless_squares(file, names, min_side=180, group="seamless", size=256):
    rgba, rows = sheet_rows(file, merge=1, min_area=20000)
    sq = [b for r in rows for b in r if (b[2] - b[0]) >= min_side and (b[3] - b[1]) >= min_side]
    for nm, b in zip(names, sq):
        inset = 8
        save(piece(rgba, (b[0] + inset, b[1] + inset, b[2] - inset, b[3] - inset), w=size, h=size, cover=True), group, nm)
    return [b for r in rows for b in r if b not in sq], rgba


def w475(): seamless_squares("w475_glow_ground_seamless.png", ["teal_moss", "teal_moss_dense", "teal_moss_wet", "violet_soil", "violet_moss"])
def w477(): seamless_squares("w477_region_ground_seamless.png", ["corrupt_soil", "starry_cloud", "jungle_path", "cracked_road", "float_stone"])
def w381(): seamless_squares("w381_river_flow_seamless.png", ["river_flow_0", "river_flow_1", "river_flow_2", "river_flow_3", "river_shallow",
                                                               "river_deep_0", "river_deep_1", "river_deep_2", "river_deep_3", "river_night"])
def w408(): seamless_squares("w408_interior_floors.png", ["floor_oak", "floor_dark", "floor_light", "floor_worn", "floor_stone_tiles",
                                                           "floor_checker", "floor_terracotta", "floor_parquet", "floor_flagstone", "floor_clinic",
                                                           "floor_bakery", "floor_smithy", "floor_shop", "floor_barn", "floor_carpet"])


def w392():
    rest, rgba = seamless_squares("w392_winter_seamless.png", ["snow_smooth", "snow_trodden", "snow_packed", "ice", "frozen_dirt",
                                                                "frost_grass", "snow_paving", "slush"])
    for i, b in enumerate(sorted(rest, key=lambda b: b[0])[:6]):
        save(piece(rgba, b, w=64, h=64), "tiles", "snow_shelf_%d" % i)


def w403():
    rest, rgba = seamless_squares("w403_paving_seamless.png", ["cobble_grey", "cobble_warm", "brick_herring", "flagstone", "plaza_tiles",
                                                                "boardwalk", "old_stone", "city_pavement", "asphalt", "cobble_moss"])
    names = ["plaza_ring_0", "plaza_ring_1", "plaza_ring_2", "plaza_ring_3", "path_mouth_n", "path_mouth_s", "path_mouth_e", "path_mouth_w"]
    for nm, b in zip(names, sorted(rest, key=lambda b: b[0])):
        save(piece(rgba, b, w=TILE2 * 2, h=TILE2 * 2, cover=True), "tiles", nm)


def w412():
    rest, rgba = seamless_squares("w412_special_seamless.png", ["moon_dust", "moon_craters", "cloud_top", "crystal_grass", "pale_stone",
                                                                 "ash2", "frost2", "coral_sand2", "pier_concrete2", "lake_deep2"])
    roles = ["top", "bottom", "left", "right", "tl", "tr", "bl", "br", "itl", "itr", "ibl", "ibr"]
    for r, b in zip(roles, sorted(rest, key=lambda b: b[0])):
        save(piece(rgba, b, w=TILE2, h=TILE2, cover=True), "tiles", "moon_rim_%s_0" % r)


def w413():
    rest, rgba = seamless_squares("w413_battle_ground.png", ["ballast", "dock_concrete", "snow_trampled", "scorched", "mud_field"])
    names = ["rail_h", "rail_v", "rail_curve_ne", "rail_curve_nw", "rail_curve_se", "rail_curve_sw", "rail_cross", "rail_stop_0", "rail_stop_1"]
    for nm, b in zip(names, sorted(rest, key=lambda b: (b[1] // 150, b[0]))):
        save(piece(rgba, b, w=TILE2 * 2, h=TILE2 * 2, cover=True), "tiles", nm)


# ---------------------------------------------------------------- blob edge sets (16-piece BLOB RULE)

BLOB_MAP = {(0, 0): "tl", (0, 1): "top", (0, 2): "tr", (0, 3): "itl", (0, 4): "itr", (0, 5): "fill", (0, 6): "fillb", (0, 7): "top",
            (1, 0): "left", (1, 2): "right", (1, 3): "ibl", (1, 4): "ibr", (1, 5): "fill", (1, 6): "fill",
            (2, 0): "bl", (2, 1): "bottom", (2, 2): "br", (2, 3): "left", (2, 4): "right", (2, 5): "bottom"}


def blob_set(rgba, rows3, name, overlay=False):
    xs = sorted(b[0] for b in rows3[0])
    pitch = np.median(np.diff(xs)) if len(xs) > 1 else 100
    x0 = min(b[0] for r in rows3 for b in r)
    counts = {}
    for ri, r in enumerate(rows3[:3]):
        for b in r:
            col = int(round((b[0] - x0) / pitch))
            role = BLOB_MAP.get((ri, col))
            if not role:
                continue
            if role == "fillb":
                save(piece(rgba, b, w=TILE2, h=TILE2, cover=True), "tiles", name + "_outside_0"); continue
            v = counts.get(role, 0); counts[role] = v + 1
            save(piece(rgba, (b[0] + 2, b[1] + 2, b[2] - 2, b[3] - 2), w=TILE2, h=TILE2, cover=True), "tiles", "%s_%s_%d" % (name, role, v))
    return counts


def blob_sheet(file, names, sets_rows=3, extra=None):
    rgba, rows = sheet_rows(file, merge=1, min_area=1500)
    rows = big_rows(rows, 0.5)
    tile_rows = [r for r in rows if 60 < np.median([b[3] - b[1] for b in r]) < 200]
    for k, nm in enumerate(names):
        part = tile_rows[k * sets_rows:(k + 1) * sets_rows]
        if len(part) >= 3:
            blob_set(rgba, part, nm)
    return rgba, [r for r in rows if r not in tile_rows[:len(names) * sets_rows]]


def w380(): blob_sheet("w380_river_bank_overlay.png", ["river_bank", "river_bank_fall"])
def w383(): blob_sheet("w383_pond_shore_overlay.png", ["pond_shore", "lake_shore"])
def w385(): blob_sheet("w385_sand_sea_overlay.png", ["sand_sea_f0", "sand_sea_f1"])
def w386(): blob_sheet("w386_grass_sand_blob.png", ["grass_sand", "grass_wetsand"])
def w388(): blob_sheet("w388_grass_dirt_blob.png", ["grass_dirt", "grass_dirt_fall"])
def w389(): blob_sheet("w389_grass_deadgrass_blob.png", ["grass_dry", "grass_mud"])
def w391(): blob_sheet("w391_grass_snow_blob.png", ["grass_snow", "snow_water"])
def w394(): blob_sheet("w394_bog_water_overlay.png", ["bog_water2", "grass_bogmud"])
def w396(): blob_sheet("w396_cave_water_edges.png", ["cave_water", "cave_lava"])
def w402(): blob_sheet("w402_path_dirt_dualgrid.png", ["path_dirt3", "path_gravel"])
def w404(): blob_sheet("w404_paving_edges.png", ["grass_cobble", "curb_road"])
def w405(): blob_sheet("w405_tilled_soil_blob.png", ["tilled_dry", "tilled_wet"])
def w406(): blob_sheet("w406_farm_pond_fence.png", ["farm_pond"])
def w393(): blob_sheet("w393_snow_sea_shelf.png", ["snow_sea"])


def w397():
    blob_sheet("w397_cave_chasm_ice.png", ["", "cave_ice"][1:] and ["cave_chasm_old", "cave_ice"])
    if have("w397b_cave_chasm.png"):
        rgba, rows = sheet_rows("w397b_cave_chasm.png", merge=1, min_area=5000)
        names = [["tl", "top", "tr", "drop"], ["left", "fill", "right", "itl"], ["bl", "bottom", "br", "itr"], ["ibl", "ibr", "tb", "lr"]]
        for rn, r in zip(names, big_rows(rows)):
            for role, b in zip(rn, r):
                save(piece(rgba, (b[0] + 3, b[1] + 3, b[2] - 3, b[3] - 3), w=TILE2, h=TILE2, cover=True), "tiles", "cave_chasm_%s_0" % role)


def w411():
    rgba, rows = sheet_rows("w411_colony_shores.png", merge=1, min_area=1500)
    rows = big_rows(rows, 0.5)
    for half, (top, bottom) in enumerate([(rows[0:3], None), (rows[3:6], None)]):
        for r3 in [top]:
            left = [[b for b in r if b[0] < 760] for r in r3]
            right = [[b for b in r if b[0] >= 760] for r in r3]
            names = [["coral_shore", "kelp_shore"], ["ice_shore", "ember_shore"]][half]
            blob_set(rgba, left, names[0]); blob_set(rgba, right, names[1])


def w398():
    rgba, rows = sheet_rows("w398_cave_walls.png", merge=1, min_area=1500)
    kinds = ["earth", "stone", "crystal", "void", "ice"]
    roles = ["otl", "otr", "obl", "obr", "n", "s", "e", "w", "itl", "itr", "ibl", "ibr", "fill", "fill2"]
    for k, r in zip(kinds, big_rows(rows)):
        for role, b in zip(roles, row_fix(rgba, r, 14)):
            save(piece(rgba, b, w=TILE2, h=int(TILE2 * 1.3)), "tiles", "cavewall_%s_%s" % (k, role))


def w443b():
    rgba, rows = sheet_rows("w443b_wall_tops.png", merge=1, min_area=300)
    kinds = ["wood", "plaster", "stone", "brick", "tile", "paper"]
    roles = ["left", "right", "front", "back", "tl", "tr", "bl", "br", "door"]
    for k, r in zip(kinds, big_rows(rows)):
        for role, b in zip(roles, row_fix(rgba, r, 9)):
            save(piece(rgba, b, factor=TILE2 / 96), "furniture", "walltop_%s_%s" % (k, role))


def w409():
    rgba, rows = sheet_rows("w409_interior_walls.png", merge=1, min_area=800)
    kinds = ["wallpaper", "panel", "plaster", "stone", "brick", "tile"]
    roles = ["face_0", "face_1", "face_2", "window", "shelf", "picture", "side_l", "side_r", "corner_0", "corner_1", "door"]
    allrows = big_rows(rows)
    # the last row sometimes merges two styles: split by y
    for k, r in zip(kinds, allrows):
        for role, b in zip(roles, r[:11]):
            save(piece(rgba, b, factor=TILE2 / 64), "furniture", "wall_%s_%s" % (k, role))


def w444():
    rgba, rows = sheet_rows("w444_night_windows.png", merge=2, min_area=1500)
    kinds = ["square", "arched", "porthole", "shop", "cottage"]
    for k, r in zip(kinds, big_rows(rows)):
        if len(r) >= 2:
            save(piece(rgba, r[0], factor=0.28), "furniture", "win_%s_day" % k)
            save(piece(rgba, r[1], factor=0.28), "furniture", "win_%s_night" % k)


# ---------------------------------------------------------------- generic kits (pieces in reading order)
# Kept under art/gen/kits/ (left out of the web export until a map uses them).

KITS = {
    "w382_river_dressing.png": ("props", "river_dress", 0.5),
    "w384_pond_extras.png": ("props", "pond_extra", 0.5),
    "w387_beach_rocks.png": ("props", "beach_rock", 0.5),
    "w390_edge_fringe_decals.png": ("props", "fringe", 0.35),
    "w395_marsh_kit.png": ("props", "marsh_kit", 0.5),
    "w399_cliffkit_grass.png": ("cliffs", "kit_grass", 0.32),
    "w400_cliffkit_sand_stone.png": ("cliffs", "kit_sand_stone", 0.42),
    "w401_cliff_crystal_iron.png": ("cliffs", "kit_crystal_iron", 0.42),
    "w407_yard_kit.png": ("props", "yard_kit", 0.3),
    "w410_rugs_and_props.png": ("furniture", "room_kit", 0.3),
    "w445_shop_props.png": ("furniture", "shop_kit", 0.3),
    "w447_pier_pilings.png": ("props", "pier_kit", 0.3),
    "w451_withered_plants.png": ("crops", "withered_kit", 0.3),
    "w453_tables_clean.png": ("furniture", "table_kit", 0.3),
    "w454_barrels_and_ring.png": ("props", "storage_kit", 0.3),
    "w505_border_forest_summer.png": ("nature", "forest_wall_summer", 0.5),
    "w506_border_forest_seasons.png": ("nature", "forest_wall_seasons", 0.5),
    "w507_border_distance.png": ("backdrops", "distance", 0.5),
    "w508_cliff_curves.png": ("cliffs", "curve", 0.5),
    "w509_cliff_two_tier.png": ("cliffs", "two_tier", 0.5),
    "w510_cliff_city_tiers.png": ("cliffs", "city", 0.5),
    "w511_river_bridges.png": ("props", "bridge_kit", 0.5),
    "w512_river_falls.png": ("props", "falls_kit", 0.5),
    "w268_cattopia_cave.png": ("props", "cattopia_kit", 0.4),
    "w269_prismatica_summit.png": ("props", "prismatica_kit", 0.4),
    "w270_penguin_items_ui.png": ("ui", "penguin_kit", 0.35),
    "w353_skills_ui.png": ("ui", "skills_kit", 0.5),
    "w359_screens_a.png": ("ui", "screens_a_kit", 0.5),
    "w360_screens_b.png": ("ui", "screens_b_kit", 0.5),
    "w372_ui_marks.png": ("ui", "marks_kit", 0.2),
    "w375_hollow_heart_kit.png": ("props", "hollow_kit", 0.4),
    "w377_dark_spire_fix.png": ("props", "spire_kit", 0.4),
    "w379_secrets_kit.png": ("props", "secrets_kit", 0.25),
    "w431_ui_small_a.png": ("ui", "small_a_kit", 0.15),
    "w432_ui_small_b.png": ("ui", "small_b_kit", 0.2),
    "w464_small_leftovers.png": ("ui", "leftover_kit", 0.25),
    "w374_lit_windows.png": ("buildings", "lit_kit", 0.5),
}


def kits():
    for f, (g, pre, fac) in KITS.items():
        if not have(f):
            continue
        rgba, rows = sheet_rows(f, merge=3, min_area=150)
        flat = [b for r in big_rows(rows, 0.12) for b in r]
        for i, b in enumerate(flat):
            save(piece(rgba, b, factor=fac), "kits/" + g, "%s_%02d" % (pre, i))
        print("   kit", pre, len(flat))


def w524():
    icons_in_order("w524_seed_icons_fill.png", ["rice_seed", "dill_seed", "cantaloupe_seed", "chia_seed", "kumquat_seed",
                                                "rainbow_beet_seed", "prism_tomato_seed", "truffle_spore", "glowcap_spore2",
                                                "glowcap_spore3", "worldseed2", "worldseed3", "void_pepper_seed2", "flame_core"])


def w525():
    rgba = load("w525_hound_strips.png")
    rows = bands(rgba, 5)
    spec = [[("bite", 4)], [("bark2", 2), ("hurt", 2), ("guard", 2)], [("limp", 4), ("howl", 2)], [("dig", 6)], [("fetch", 4), ("beg", 2)]]
    out = {}
    for sp, r in zip(spec, rows):
        out.update(layout(row_n(rgba, r, sum(n for _, n in sp)), sp))
    g = "animals/dog_hound"
    f = mget(g, "idle", "cell_h", 32) / max(1.0, med_h(out["bite"][:1] + out["limp"][:1]))
    emit(rgba, g, out, f)


def w526():
    rgba = load("w526_orla_moss_life.png")
    rows = bands(rgba, 4)
    for who, (ra, rb) in zip(["orla", "old_moss"], [(rows[0], rows[1]), (rows[2], rows[3])]):
        g = "characters/npc_" + who
        segs = row_n(rgba, ra, 8) + row_n(rgba, rb, 8)
        order = ["work", "work_2", "sit", "talk", "talk_2", "laugh", "wave", "sleep", "carry", "eat", "dance", "dance_2", "umbrella", "shiver", "fish", "counter"]
        stand = [segs[i] for i in (3, 4, 6)]
        f = mget(g, "idle", "cell_h", 100) / max(1.0, med_h(stand))
        for pose, b in zip(order, segs):
            save(piece(rgba, b, factor=f), g, pose)
            S.manifest[g][pose].update({"cell_w": S.manifest[g][pose]["w"], "cell_h": S.manifest[g][pose]["h"], "frames": 1})


# ---- Round 13: tool poses for the six gritty gang heroes (w295-w300) ---------
# The full sheets drew hoe/axe/pickaxe/water rows, but the sprites wander off the
# prompt's grid and order (and some face left), so each frame is picked by hand:
# (row, sprite centre x, flip). Rows are the sheet's own sprite bands.
def _gang_bands(rgba):
    H = rgba.shape[0]
    on = (rgba[:, :340, 3] > 40).any(axis=1)
    runs, st = [], None
    for y in range(H + 1):
        v = y < H and on[y]
        if v and st is None: st = y
        if not v and st is not None:
            if runs and st - runs[-1][1] < 7: runs[-1][1] = y
            else: runs.append([st, y])
            st = None
    runs = [r for r in runs if r[1] - r[0] > 30]
    return [(max(0, a - 3), min(H, b + 3)) for a, b in runs]

GANG_TOOL_ROWS = {
    "man_gang": ("w295_hero_dad_gang_full.png", {
        3: [60, 185, 290, 400, 520, 610, 725, 835, 950, 1060, 1165, 1270, 1385, 1480],
        4: [65, 180, 295, 405, 525, 630, 740, 855, 960, 1070, 1165, 1270, 1380, 1480]}, {
        "hoe_down": [(3, 0), (3, 3), (3, 6)], "hoe_right": [(3, 1), (3, 4)], "hoe_up": [(3, 2), (3, 10)],
        "axe_down": [(3, 7), (3, 13)], "axe_right": [(3, 12), (3, 8), (4, 1)],
        "pickaxe_right": [(4, 3), (4, 4), (4, 2)], "pickaxe_up": [(4, 5), (4, 6)],
        "water_down": [(4, 7)], "water_right": [(4, 8), (4, 9), (4, 10)], "hold_down": [(4, 12)], "eat_down": [(4, 13)]}),
    "son_gang": ("w296_hero_pax_gang_full.png", {
        3: [65, 185, 280, 390, 490, 580, 690, 815, 920, 1015, 1120, 1235, 1335, 1455],
        4: [55, 160, 295, 390, 490, 590, 710, 840, 940, 1030, 1160, 1250, 1370, 1470]}, {
        "hoe_down": [(3, 0), (3, 3)], "hoe_right": [(3, 1), (3, 4)], "axe_right": [(3, 8), (3, 10), (3, 11)],
        "pickaxe_right": [(4, 2), (4, 1, True)], "pickaxe_down": [(4, 4), (4, 3)], "pickaxe_up": [(4, 6), (4, 5)],
        "water_down": [(4, 7)], "water_right": [(4, 8)], "hold_down": [(4, 12)], "eat_down": [(4, 13)]}),
    "june_gang": ("w297_hero_june_gang_full.png", {
        3: [55, 165, 265, 360, 465, 575, 670, 775, 880, 985, 1085, 1195, 1295, 1390, 1480],
        4: [55, 160, 265, 370, 480, 585, 680, 785, 890, 990, 1115, 1235, 1350, 1460]}, {
        "hoe_right": [(3, 1), (3, 3), (3, 5)], "axe_right": [(4, 0), (4, 1), (4, 2)],
        "pickaxe_right": [(4, 5), (4, 6), (4, 3)],
        "water_down": [(4, 11)], "water_right": [(4, 8), (4, 9), (4, 10)], "hold_down": [(4, 12)], "eat_down": [(4, 13)]}),
    "rafe_gang": ("w298_hero_rafe_gang_full.png", {
        3: [50, 160, 255, 365, 470, 575, 680, 790, 905, 1010, 1135, 1235, 1345, 1460],
        4: [55, 160, 270, 380, 480, 590, 700, 830, 960, 1100, 1230, 1350, 1470]}, {
        "hoe_right": [(3, 1, True), (3, 3, True), (3, 5, True)], "axe_right": [(3, 13, True), (3, 10, True), (3, 11, True)], "axe_down": [(4, 0)],
        "pickaxe_right": [(4, 3), (4, 6)], "pickaxe_down": [(4, 5), (4, 2)],
        "water_down": [(4, 7)], "water_right": [(4, 8), (4, 9)], "hold_down": [(4, 11)], "eat_down": [(4, 12)]}),
    "nia_gang": ("w299_hero_nia_gang_full.png", {
        3: [45, 130, 190, 280, 370, 430, 520, 590, 660, 750, 830, 880, 975, 1060, 1145, 1215, 1295, 1375, 1460],
        4: [50, 140, 240, 320, 410, 500, 570, 650, 745, 800, 880, 990, 1090, 1210, 1320, 1440]}, {
        "hoe_right": [(3, 3), (3, 4)], "axe_right": [(3, 12), (3, 17), (3, 18)],
        "pickaxe_right": [(4, 6), (4, 7)], "pickaxe_up": [(4, 9), (4, 10)],
        "water_down": [(4, 11)], "water_right": [(4, 12), (4, 13)], "hold_down": [(4, 14)], "eat_down": [(4, 15)]}),
    "ollie_gang": ("w300_hero_ollie_gang_full.png", {
        3: [40, 140, 230, 320, 400, 500, 590, 680, 770, 860, 950, 1040, 1150, 1240, 1320, 1400, 1480],
        4: [45, 140, 230, 320, 410, 490, 580, 660, 750, 850, 940, 1020, 1110, 1200, 1300, 1400, 1480]}, {
        "hoe_down": [(3, 0), (3, 1), (3, 2)], "hoe_right": [(3, 3), (3, 4), (3, 5)], "axe_right": [(3, 6), (3, 15), (3, 16)],
        "pickaxe_right": [(3, 12), (3, 13)], "pickaxe_down": [(4, 0), (4, 1), (4, 2)], "pickaxe_up": [(3, 7), (3, 8)],
        "cast_right": [(4, 5), (4, 6), (4, 7)], "water_right": [(4, 10)], "hold_down": [(4, 15)], "eat_down": [(4, 16)]}),
}


def _gang_frame(rgba, band, centres, i, flip=False):
    """The sprite whose centre is centres[i]: the window between its neighbours'
    midpoints, keeping only blobs whose middle sits inside it (no borrowed
    pickaxe heads from the next frame)."""
    from scipy import ndimage
    y0, y1 = band
    Wd = rgba.shape[1]
    c = centres[i]
    a = (centres[i - 1] + c) // 2 if i > 0 else max(0, c - 60)
    b = (centres[i + 1] + c) // 2 if i + 1 < len(centres) else min(Wd, c + 60)
    pad = 14
    x0, x1 = max(0, a - pad), min(Wd, b + pad)
    sub = rgba[y0:y1, x0:x1].copy()
    mask = sub[..., 3] > 40
    lab, n = ndimage.label(ndimage.binary_dilation(mask, iterations=1))
    keep = np.zeros(n + 1, bool)
    for k, sl in enumerate(ndimage.find_objects(lab), 1):
        if sl is None: continue
        mx = x0 + (sl[1].start + sl[1].stop) / 2.0
        if a <= mx <= b: keep[k] = True
    sub[~keep[lab]] = 0
    ys, xs = np.where(sub[..., 3] > 40)
    if not len(ys): return None
    im = Image.fromarray(sub[ys.min():ys.max() + 1, xs.min():xs.max() + 1].astype(np.uint8))
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im


R13_HEROES = {"man_gang": "r13/w295d_hero_dad_gang_dark.png", "son_gang": "r13/w296d_hero_pax_gang_dark.png",
              "june_gang": "r13/w297d_hero_june_gang_dark.png", "rafe_gang": "r13/w298d_hero_rafe_gang_dark.png",
              "nia_gang": "r13/w299d_hero_nia_gang_dark.png", "ollie_gang": "r13/w300d_hero_ollie_gang_dark.png",
              "marisol_gang": "r13/w301d_hero_marisol_gang_dark.png", "bo_gang": "r13/w302d_hero_bo_gang_dark.png"}


def r13_heroes():
    """The eight gang heroes redrawn darker (same sheet layout as w295-w302):
    the w295 slicer cuts them, then gang_tools re-adds the hand-picked tool poses."""
    import slice_world as W
    for cid, f in R13_HEROES.items():
        if have(f):
            W.GRIT[f] = cid
            W._grit(f)
            # The w295 slicer's tool rows come from even fractions of a row
            # (mixed-up frames): gang_tools hand-picks those; drop the rest.
            if cid in GANG_TOOL_ROWS:
                keep = GANG_TOOL_ROWS[cid][2]
                g = S.manifest.get("characters/" + cid, {})
                for k in list(g):
                    if k.split("_")[0] in ("hoe", "axe", "pickaxe", "water", "hold", "eat") and k not in keep:
                        del g[k]
            pg = S.manifest.get("portraits/" + cid, {})
            for want, sub in (("worried", "sad"), ("sly", "neutral"), ("embarrassed", "sad")):
                if want not in pg and sub in pg:
                    pg[want] = dict(pg[sub])
    gang_tools()


def gang_tools():
    for cid, (file, rows, anims) in GANG_TOOL_ROWS.items():
        if have(R13_HEROES.get(cid, "-")):
            file = R13_HEROES[cid]  # the redraw keeps every sprite where it was
        if not have(file): continue
        rgba = _hue(file)
        bs = _gang_bands(rgba)
        G = "characters/" + cid
        for name, picks in anims.items():
            ims = []
            for pk in picks:
                im = _gang_frame(rgba, bs[pk[0]], rows[pk[0]], pk[1], len(pk) > 2 and pk[2])
                if im is not None:
                    ims.append(scale_to(im, height=min(110, max(40, int(im.height * 0.96)))))
            if ims:
                strip(ims, G, name)
        print("   %s: %d tool strips" % (cid, len(anims)))


def _hue(file):
    import slice_world as W
    return W.load_hue(file)



# ---- Round 13: darker, cyberpunk underworld redraws (image tool, same layouts) --
# Each render keeps its original sheet's layout, so the original slicers cut it.
R13_THUGS = [("r13/w414d_thug_walks_a_dark.png", ["cyber", "brute", "flame"]),
             ("r13/w415d_thug_walks_b_dark.png", ["speedster", "gambler", "enforcer"]),
             ("r13/w428d_lookout_dark.png", ["lookout"])]
R13_LTS = {"r13/w330d_lt_vance_lucia_dark.png": ("lt_vance", "lt_lucia"), "r13/w331d_lt_brock_silas_dark.png": ("lt_brock", "lt_silas"),
           "r13/w332d_lt_mags_surveyor_dark.png": ("lt_mags", "lt_surveyor"), "r13/w333d_lt_pike_ostrova_dark.png": ("lt_pike", "lt_ostrova")}
R13_CREW = [("r13/w213d_gang_deuce_rosa_dark.png", "deuce", "mama_rosa"), ("r13/w214d_gang_specs_ladder_dark.png", "specs", "ladder"),
            ("r13/w215d_gang_twins_dark.png", "vic", "val"), ("r13/w216d_gang_halo_dice_dark.png", "halo", "dice"),
            ("r13/w217d_gang_marlene_kid_dark.png", "marlene", "the_kid"), ("r13/w218d_gang_doc_sasha_dark.png", "doc", "sasha")]


def r13_dark():
    import slice_world as W
    for f, ids in R13_THUGS:
        if have(f):
            thug_sheet(f, ids)
    for f, ids in R13_LTS.items():
        if have(f):
            W.LTS[f] = ids
            W._lt_sheet(f)
    for f, a, b in R13_CREW:
        if have(f):
            W._crew_sheet(f, a, b)



def r13_cash():
    """Gangster-arc money art: ui/cash (HUD) and ui/cash_bundle (cash flying to you)."""
    f = "r13/cash_icons.png"
    if not have(f):
        return
    rgba = load(f)
    bs = sorted([b for b in blobs(rgba, merge=6, min_area=2000)], key=lambda b: b[0])
    if len(bs) < 2:
        raise RuntimeError("r13_cash: %d pieces" % len(bs))
    save(piece(rgba, bs[0], h=36), "ui", "cash")
    save(piece(rgba, bs[1], h=40), "ui", "cash_bundle")



R13_MARKED = {"r13/w304d_marked_kit_ember_dark.png": "w304_marked_kit_ember.png", "r13/w305d_marked_dahlia_juno_dark.png": "w305_marked_dahlia_juno.png",
              "r13/w306d_marked_rio_mei_dark.png": "w306_marked_rio_mei.png", "r13/w307d_marked_bruno_tomas_dark.png": "w307_marked_bruno_tomas.png",
              "r13/w308d_marked_sable_atlas_dark.png": "w308_marked_sable_atlas.png"}


def r13_marked():
    """The Marked redrawn darker (same layouts as w304-w308)."""
    import slice_world as W, tempfile
    for f, orig in R13_MARKED.items():
        if not have(f):
            continue
        # A raised arm can bridge two sprite rows into one band: open a one-pixel
        # gap at the emptiest line of any band twice the usual height (copy in /tmp).
        img = Image.open(os.path.join(S.INC, f)).convert("RGBA")
        rgba = W.load_hue(f)
        on = (rgba[:, :, 3] > 40).sum(axis=1)
        runs, st = [], None
        for y in range(len(on) + 1):
            v = y < len(on) and on[y] > 0
            if v and st is None: st = y
            if not v and st is not None:
                if runs and st - runs[-1][1] < 6: runs[-1][1] = y
                else: runs.append([st, y])
                st = None
        runs = [r for r in runs if r[1] - r[0] > 30]
        med = float(np.median([b - a for a, b in runs]))
        src = f
        for a, b in runs:
            if b - a > 1.8 * med:
                lo, hi = a + int(0.3 * (b - a)), a + int(0.7 * (b - a))
                y = lo + int(np.argmin(on[lo:hi]))
                for yy in range(y - 3, y + 4):  # a 7-px backdrop seam (the band merge gap is 6)
                    for x in range(img.width):
                        img.putpixel((x, yy), (255, 0, 255, 255))
                print("   %s: split a merged band at y=%d (%d px of sprite cut)" % (f, y, int(on[y - 3:y + 4].sum())))
                src = os.path.join(tempfile.mkdtemp(prefix="r13mk_"), os.path.basename(f))
        if src != f:
            img.save(src)
        W.MKS[src] = W.MKS[orig]
        W._mk_sheet(src)


STEPS = [w478, w493, w422, w476, w479, w480, w442, w463, w466, w467, w468, w471,
         w465, w376, w487, w488, w489, w482, w483, w484, w485, w486, w490,
         w414, w415, w428, w417, w470, w472, w366, w367, w368,
         w481, w469, w364, w448c, w365, w362,
         w455, w456, w458, w459, w436, w251b, w253c, w433, w434, w449, w271, w361, w363, w473, w474,
         w494, w495, w496, w497, w498, w499, w500, w501, w502, w503, w513, w516, w517, w518, w514, w515,
         w519, w520, w521, w522, w523, w504, w446, w450, w435,
         w424, w425, w420, w423, w430, w429, w426, w427, w462, w460, w461, w418, w419, w457, w373,
         w475, w477, w381, w408, w392, w403, w412, w413,
         w380, w383, w385, w386, w388, w389, w391, w394, w396, w402, w404, w405, w406, w393, w397, w411, w398, w443b, w409, w444,
         w524, w525, w526, kits, r13_heroes, r13_dark, r13_marked, r13_cash]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    only = sys.argv[1:]
    for fn in STEPS:
        if only and fn.__name__ not in only:
            continue
        try:
            fn(); print("ok", fn.__name__)
        except Exception as e:
            import traceback; traceback.print_exc(); print("FAIL", fn.__name__, repr(e))
    with open(mpath, "w") as f:
        json.dump(S.manifest, f, indent=1, sort_keys=True)
