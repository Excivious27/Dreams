#!/usr/bin/env python3
"""C16b P5 art: boss cards for the named gang captains (gcap_g_<region>).

No render needed: each card is composed like tools/slice_c5_p6.py cards() (the shared
ornate frame ui/card_big_grump, a dark panel, the boss on the left with a soft glow),
from the captain's thug character strip (characters/<char>/idle frame 0) recoloured
with the captain's tint, exactly as Enemy draws it. GameMap.boss_card(kind) finds
ui/card_<kind> on its own.   python3 tools/slice_c16b_p5.py
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import slice_art as S
import slice_c5_p6 as C5
from PIL import Image

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def char_frame(ch, tint):
    info = S.manifest["characters/" + ch]["idle"]
    im = Image.open(os.path.join(S.OUT, info["file"])).convert("RGBA")
    im = im.crop((0, 0, info["cell_w"], info["cell_h"]))
    t = tint.lstrip("#")
    r, g, b = int(t[0:2], 16), int(t[2:4], 16), int(t[4:6], 16)
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            pr, pg, pb, pa = px[x, y]
            if pa:
                px[x, y] = (pr * r // 255, pg * g // 255, pb * b // 255, pa)  # self_modulate
    return im


def cards():
    E = json.load(open(os.path.join(D, "data", "enemies.json")))["enemies"]
    n = 0
    for k, e in sorted(E.items()):
        if k.startswith("gcap_g_") and e.get("char"):
            C5.card(k, char_frame(e["char"], e.get("tint", "#ffffff")))
            n += 1
    return n


if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    keep = json.load(open(mpath))  # keep its key order: only the new card entries change
    S.manifest.update(json.load(open(mpath)))
    print("ok cards", cards())
    for k, v in S.manifest.get("ui", {}).items():
        keep.setdefault("ui", {})[k] = v
    data = json.dumps(keep, indent=1) + "\n"
    os.remove(mpath)  # hardlinked across worktrees: never write it in place
    with open(mpath, "w") as fh:
        fh.write(data)
