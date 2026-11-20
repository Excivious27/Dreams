#!/usr/bin/env python3
"""C6 P7: trash can icons (ui/trash_can, ui/trash_can_open) from art/incoming/c6/p7_trash_can.png.
Keys out magenta, splits the two blobs left/right, crops, scales to 64 px tall."""
import os
from PIL import Image
import numpy as np
SRC = "art/incoming/c6/p7_trash_can.png"
OUT = "art/gen/ui"
im = Image.open(SRC).convert("RGBA")
a = np.array(im).astype(int)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
mag = (r > 180) & (b > 180) & (g < 110)
a[mag, 3] = 0
key = Image.fromarray(a.astype("uint8"), "RGBA")
w = key.width
for name, box in (("trash_can", (0, 0, w // 2, key.height)), ("trash_can_open", (w // 2, 0, w, key.height))):
    part = key.crop(box)
    bb = part.getbbox()
    part = part.crop(bb)
    h = 64
    part = part.resize((max(1, round(part.width * h / part.height)), h), Image.LANCZOS)
    al = np.array(part)
    al[..., 3] = np.where(al[..., 3] > 110, 255, 0)  # hard alpha, no magenta fringe
    p = os.path.join(OUT, name + ".png")
    if os.path.exists(p):
        os.remove(p)
    Image.fromarray(al, "RGBA").save(p)
    print(p, part.size)
