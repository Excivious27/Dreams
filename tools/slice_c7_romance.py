#!/usr/bin/env python3
"""CONDUCT 7 P1 art (dating and marriage), from image-tool renders in art/incoming/c7/:

  romance_wedding_props.png  -> props/wedding_arch, props/wedding_bench, props/wedding_heart_sign
  romance_corners_a/b/c.png  -> furniture/spouse_<id> (lumi theo finn rook | juniper posy ivy | benno tam sel)
  romance_love_faces_npc.png -> portraits/<npc_lumi|npc_theo|npc_juniper|npc_finn_normal|npc_posy_normal|npc_rook_normal>/love
  cut_wedding_penguins/gangsters.png, cut_proposal.png -> ui/cut_* (500x355 like the other panels)

Run after the other slicers:  python3 tools/slice_c7_romance.py
then art_audit.py --fix <ids> (ids only), set_import_lossy.py, godot --import.
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_art as S
from slice_comp import blobs, rows_of
import numpy as np
from PIL import Image

C7 = "c7"


def _rm(group, name):
    p = os.path.join(S.OUT, group, name + ".png")
    if os.path.exists(p):
        os.remove(p)  # hardlinked art: never write in place


def _save(img, group, name):
    _rm(group, name)
    S.save(img, group, name)


def _pieces(file, n, merge=12):
    rgba = S.load(os.path.join(C7, file))
    bs = [b for b in blobs(rgba, merge=merge, min_area=400)]
    bs.sort(key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))
    bs = sorted(bs[:n], key=lambda b: b[0])
    assert len(bs) == n, (file, len(bs))
    return rgba, bs


def _fit(rgba, b, h):
    im = S.crop(rgba, b)
    return S.scale_to(im, width=max(1, round(im.width * h / im.height)), height=h)


def props():
    rgba, bs = _pieces("romance_wedding_props.png", 3)
    for b, name, h in zip(bs, ["wedding_arch", "wedding_bench", "wedding_heart_sign"], [96, 34, 46]):
        _save(_fit(rgba, b, h), "props", name)


def corners():
    for file, ids in [("romance_corners_a.png", ["lumi", "theo", "finn", "rook"]),
                      ("romance_corners_b.png", ["juniper", "posy", "ivy"]),
                      ("romance_corners_c.png", ["benno", "tam", "sel"])]:
        rgba, bs = _pieces(file, len(ids))
        for b, cid in zip(bs, ids):
            _save(_fit(rgba, b, 60), "furniture", "spouse_" + cid)


# The portrait sets Dialogue.portrait_for really uses for the candidates without a love face.
PORTRAITS = ["npc_lumi", "npc_theo", "npc_juniper", "npc_finn_normal", "npc_posy_normal", "npc_rook_normal"]


def love():
    rgba = S.load(os.path.join(C7, "romance_love_faces_npc.png"))
    # Five portraits in one row; the little heart beside each is left out (portrait cells
    # are face-only, and Dialogue.one_face splits over-wide pictures).
    bs = blobs(rgba, merge=8, min_area=60)
    bs.sort(key=lambda b: -(b[2] - b[0]) * (b[3] - b[1]))
    faces = sorted(bs[:6], key=lambda b: b[0])
    assert len(faces) == 6, len(faces)
    bs = [tuple(f) for f in faces]
    for b, pid in zip(bs, PORTRAITS):
        ref = Image.open(os.path.join(S.OUT, "portraits", pid, "happy.png"))
        im = S.crop(rgba, b)
        im = S.scale_to(im, width=max(1, round(im.width * ref.height / im.height)), height=ref.height)
        _save(im, "portraits/" + pid, "love")


def cuts():
    for name in ["cut_wedding_penguins", "cut_wedding_gangsters", "cut_proposal"]:
        im = Image.open(os.path.join(S.INC, C7, name + ".png")).convert("RGBA")
        im = im.resize((500, 333), Image.LANCZOS)
        out = Image.new("RGBA", (500, 355), (0, 0, 0, 0))
        out.paste(im.resize((500, 355), Image.LANCZOS))
        _save(out, "ui", name)


STEPS = {"props": props, "corners": corners, "love": love, "cuts": cuts}

if __name__ == "__main__":
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    for st in (sys.argv[1:] or list(STEPS)):
        STEPS[st]()
        print("ok", st)
    data = json.dumps(S.manifest, indent=1, sort_keys=True)
    os.remove(mpath)  # hardlinked across worktrees: never write it in place
    with open(mpath, "w") as fh:
        fh.write(data)
