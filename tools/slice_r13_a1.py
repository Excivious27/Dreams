#!/usr/bin/env python3
"""Round 13 (agent a1): the Rec Center renders (image tool, art/incoming/r13_a1/).

  rec_center_building.png  -> buildings/rec_center (penguins)
  rec_hall_building.png    -> buildings/rec_hall (gangsters)
  arcade_cabinets.png      -> props/arcade_cab_0..5, props/claw_machine, props/skee_ball
  bowling_furniture.png    -> furniture/ball_return, ball_rack, trophy_case, shoe_counter,
                              score_console, pin_statue, trophy_shelf, snack_counter
  bowling_backwall.png     -> backdrops/bowling_wall (the bowling screen's far wall)

Run after the other slicers:  python3 tools/slice_r13_a1.py   (merges into the manifest)
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_art import load, crop, scale_to, save
from slice_comp import blobs, rows_of
from PIL import Image

D = "r13_a1/"


def biggest(rgba, merge=6):
    bs = blobs(rgba, merge=merge, min_area=2000)
    return max(bs, key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))


def buildings():
    for f, name in [("rec_center_building.png", "rec_center"), ("rec_hall_building.png", "rec_hall")]:
        rgba = load(D + f)
        save(scale_to(crop(rgba, biggest(rgba)), width=320), "buildings", name)


def cabinets():
    rgba = load(D + "arcade_cabinets.png")
    rows = [r for r in rows_of(blobs(rgba, merge=4, min_area=3000)) if r]
    top = rows[0]
    assert len(top) == 6, "expected 6 cabinets, got %d" % len(top)
    for i, b in enumerate(top):
        save(scale_to(crop(rgba, b), height=64), "props", "arcade_cab_%d" % i)
    bot = rows[1]
    save(scale_to(crop(rgba, bot[0]), height=76), "props", "claw_machine")
    save(scale_to(crop(rgba, bot[-1]), height=72), "props", "skee_ball")


def furniture():
    rgba = load(D + "bowling_furniture.png")
    rows = rows_of(blobs(rgba, merge=5, min_area=3000))
    names = [["ball_return", "ball_rack", "trophy_case", "shoe_counter"],
             ["score_console", "pin_statue", "trophy_shelf", "snack_counter"]]
    hs = [[52, 64, 72, 60], [52, 64, 40, 56]]
    for r, row in enumerate(rows[:2]):
        assert len(row) == 4, "row %d has %d pieces" % (r, len(row))
        for i, b in enumerate(row):
            save(scale_to(crop(rgba, b), height=hs[r][i]), "furniture", names[r][i])


def backwall():
    im = Image.open(os.path.join(S.INC, D + "bowling_backwall.png")).convert("RGBA")
    band = im.crop((0, 0, im.width, int(im.height * 0.555)))
    save(band.resize((540, round(540 * band.height / band.width)), Image.LANCZOS), "backdrops", "bowling_wall")


STEPS = [buildings, cabinets, furniture, backwall]

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    only = sys.argv[1:]
    for fn in STEPS:
        if only and fn.__name__ not in only:
            continue
        fn()
        print("ok", fn.__name__)
    # art/ files may be hardlinked to another checkout: never write one in place.
    with open(mpath + ".tmp", "w") as f:
        json.dump(S.manifest, f, indent=1, sort_keys=True)
    os.remove(mpath)
    os.rename(mpath + ".tmp", mpath)
