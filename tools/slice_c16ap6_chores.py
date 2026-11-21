#!/usr/bin/env python3
"""C16a P6 chore icons: art/incoming/c16ap6/c16ap6_chore_icons.png (one row of 2) -> ui/chore_<id> (16 px tall).

Order: fish, mine (the Chores page draws them on its rows via
Chores.icon(cid)). rm-then-write (art files are hardlinked); never overwrites another id.
    python3 tools/slice_c16ap6_chores.py [check]
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
import slice_comp as C

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAN = os.path.join(ROOT, "art", "gen", "manifest.json")
IDS = ["fish", "mine"]
SRC = "c16ap6/c16ap6_chore_icons.png"


def check(man):
    miss = [i for i in IDS if "chore_" + i not in man.get("ui", {}) or not os.path.exists(os.path.join(ROOT, "art", "gen", "ui", f"chore_{i}.png"))]
    if miss:
        print("slice_c16ap6_chores: missing", miss)
    return not miss


def main():
    man = json.load(open(MAN))
    if sys.argv[1:] == ["check"]:
        sys.exit(0 if check(man) else 1)
    rgba, rows = C.sheet_rows(SRC, merge=12, min_area=400)
    row = max(rows, key=len)
    if len(row) != len(IDS):
        sys.exit(f"slice_c16ap6_chores: found {len(row)} icons, want {len(IDS)}")
    for cid, b in zip(IDS, row):
        p = os.path.join(ROOT, "art", "gen", "ui", f"chore_{cid}.png")
        if os.path.exists(p):
            os.remove(p)
        im = C.piece(rgba, b, h=16)
        S.save(im, "ui", "chore_" + cid)
    man.setdefault("ui", {}).update(S.manifest.get("ui", {}))
    os.remove(MAN)
    with open(MAN, "w") as fh:
        json.dump(man, fh, indent=1, sort_keys=True)
    print("slice_c16ap6_chores: 2 icons")


if __name__ == "__main__":
    main()
