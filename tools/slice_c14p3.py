#!/usr/bin/env python3
"""C14 P3 marina art: transparent one-row renders in art/incoming/c14p3/ ->
props/c14p3_* (marina_people: hollis, roz, ines at 96 px; marina_boats: sailboat,
speedboat, charter at 128 px; 2x detail, beach.gd draws them at 0.3-0.4). rm-then-write (art files are hardlinked).
    python3 tools/slice_c14p3.py [check]
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
import slice_comp as C
import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAN = os.path.join(ROOT, "art", "gen", "manifest.json")
SHEETS = [("c14p3/marina_people.png", ["c14p3_hollis", "c14p3_roz", "c14p3_ines"], 96),
          ("c14p3/marina_boats.png", ["c14p3_sailboat", "c14p3_speedboat", "c14p3_charter"], 128)]
IDS = [i for _, ids, _ in SHEETS for i in ids]


def check(man):
    miss = [i for i in IDS if i not in man.get("props", {}) or not os.path.exists(os.path.join(ROOT, "art", "gen", "props", i + ".png"))]
    if miss:
        print("slice_c14p3: missing", miss)
    return not miss


def main():
    man = json.load(open(MAN))
    if sys.argv[1:] == ["check"]:
        sys.exit(0 if check(man) else 1)
    for src, ids, h in SHEETS:
        # A transparent render: keep its own alpha (slice_art.load keys magenta and drops it).
        rgba = np.array(Image.open(os.path.join(ROOT, "art", "incoming", src)).convert("RGBA"))
        rgba, rows = C.sheet_rows(src, merge=8, min_area=4000, rgba=rgba)
        row = max(rows, key=len)
        if len(row) != len(ids):
            sys.exit(f"slice_c14p3: {src}: found {len(row)} pieces, want {len(ids)}")
        for nid, bx in zip(ids, row):
            p = os.path.join(ROOT, "art", "gen", "props", nid + ".png")
            if os.path.exists(p):
                os.remove(p)
            S.save(C.piece(rgba, bx, h=h), "props", nid)
    man.setdefault("props", {}).update({k: v for k, v in S.manifest.get("props", {}).items() if k in IDS})
    os.remove(MAN)
    with open(MAN, "w") as fh:
        json.dump(man, fh, indent=1, sort_keys=True)
    print("slice_c14p3: %d pieces" % len(IDS))


if __name__ == "__main__":
    main()
