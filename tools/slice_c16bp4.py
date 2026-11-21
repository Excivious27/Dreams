#!/usr/bin/env python3
"""C16b P4 chest icons: art/incoming/c16bp4/c16bp4_chests.png (2 rows of 4: penguin supply,
field, war, commander; gangster supply, field, war, kingpin) -> ui/c16bp4_chest_<kind>_<arc>
(32 px tall; BattleRewards.chest_icon(kind) draws them on the board, brief and results).
rm-then-write (art files are hardlinked); never overwrites another id.
    python3 tools/slice_c16bp4.py [check]
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
import slice_comp as C

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAN = os.path.join(ROOT, "art", "gen", "manifest.json")
KINDS = ["supply", "field", "war", "commander"]
ARCS = ["pen", "gang"]
IDS = ["c16bp4_chest_%s_%s" % (k, a) for a in ARCS for k in KINDS]
SRC = "c16bp4/c16bp4_chests.png"


def check(man):
    miss = [i for i in IDS if i not in man.get("ui", {}) or not os.path.exists(os.path.join(ROOT, "art", "gen", "ui", i + ".png"))]
    if miss:
        print("slice_c16bp4: missing", miss)
    return not miss


def main():
    man = json.load(open(MAN))
    if sys.argv[1:] == ["check"]:
        sys.exit(0 if check(man) else 1)
    rgba, rows = C.sheet_rows(SRC, merge=12, min_area=400)
    rows = [r for r in rows if len(r) == 4]
    if len(rows) != 2:
        sys.exit("slice_c16bp4: found rows %s, want two rows of 4" % [len(r) for r in rows])
    for a, row in zip(ARCS, rows):
        for k, b in zip(KINDS, row):
            iid = "c16bp4_chest_%s_%s" % (k, a)
            p = os.path.join(ROOT, "art", "gen", "ui", iid + ".png")
            if os.path.exists(p):
                os.remove(p)
            S.save(C.piece(rgba, b, h=32), "ui", iid)
    man.setdefault("ui", {}).update(S.manifest.get("ui", {}))
    os.remove(MAN)
    with open(MAN, "w") as fh:
        fh.write(json.dumps(man, indent=1) + "\n")  # keep the manifest key order (small diffs)
    print("slice_c16bp4: %d icons" % len(IDS))


if __name__ == "__main__":
    main()
