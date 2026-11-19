#!/usr/bin/env python3
"""Stitch tools/map_mosaic_c2.gd shots into <scene>_map.png (exits outlined
cyan, travel points/gates magenta). Usage: python3 tools/map_mosaic_c2.py DIR [scale]"""
import json, sys, glob, os
from PIL import Image, ImageDraw

d = sys.argv[1]
scale = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
for jf in sorted(glob.glob(os.path.join(d, "*.json"))):
    info = json.load(open(jf))
    W, H = int(info["w"]), int(info["h"])
    img = Image.new("RGB", (W, H), (0, 0, 0))
    for t in info["tiles"]:
        tile = Image.open(os.path.join(d, t["file"])).convert("RGB")
        if tile.size != (270, 480):
            tile = tile.resize((270, 480), Image.NEAREST)
        img.paste(tile, (int(round(t["x"])), int(round(t["y"]))))
    dr = ImageDraw.Draw(img)
    ox, oy = info["off"]
    for e in info["exits"]:
        x, y, w, h = e["rect"]
        dr.rectangle([ox + x * 16, oy + y * 16, ox + (x + w) * 16 - 1, oy + (y + h) * 16 - 1], outline=(0, 255, 255))
        dr.text((ox + x * 16 + 2, oy + y * 16 + 2), e["to"], fill=(0, 255, 255))
    for g in info["gates"]:
        x, y = g["cell"]
        dr.rectangle([ox + x * 16, oy + y * 16, ox + x * 16 + 15, oy + y * 16 + 15], outline=(255, 0, 255))
    if scale != 1.0:
        img = img.resize((int(W * scale), int(H * scale)), Image.LANCZOS)
    img.save(os.path.join(d, info["scene"] + "_map.png"))
    print(info["scene"], W, H, "track", info.get("track"), "exits", [e["to"] for e in info["exits"]])
