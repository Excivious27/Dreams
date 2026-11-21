#!/usr/bin/env python3
"""C15 P5: seasonal twins of outdoor props and interior seasonal decor.

Each render in art/incoming/c15_p5/ holds three objects in a row on magenta.
The objects are keyed out, split on the empty columns, fitted inside the base
prop's canvas (bottom-centred, same w x h, so footprints never move) and
written as art/gen/<group>/c15p5_<base>_<season>.png. SeasonLook (scripts/
season_look.gd) maps base -> twin per look season.

  python3 tools/slice_c15_p5.py          (every job below)
"""
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEN = os.path.join(ROOT, "art", "gen")
INC = os.path.join(ROOT, "art", "incoming", "c15_p5")
MANIFEST = os.path.join(GEN, "manifest.json")

# render -> three (group, out_id, base_id or None, (w, h) when no base)
JOBS = {
	"winter_plaza_a.png": [("props", "c15p5_tree_planter_winter", "c14p2_tree_planter", None),
		("props", "c15p5_rose_arbour_winter", "c14p2_rose_arbour", None),
		("props", "c15p5_flower_kiosk_winter", "c14p2_flower_kiosk", None)],
	"winter_plaza_b.png": [("props", "c15p5_cafe_umbrella_winter", "c14p2_cafe_umbrella", None),
		("props", "c15p5_bench_curved_winter", "c14p2_bench_curved", None),
		("props", "c15p5_bench_iron_winter", "c14p2_bench_iron", None)],
	"fall_spring_plaza.png": [("props", "c15p5_tree_planter_fall", "c14p2_tree_planter", None),
		("props", "c15p5_tree_planter_spring", "c14p2_tree_planter", None),
		("props", "c15p5_flower_kiosk_fall", "c14p2_flower_kiosk", None)],
	"city_trees.png": [("props", "c15p5_city_street_tree_winter", "city_street_tree", None),
		("props", "c15p5_city_street_tree_fall", "city_street_tree", None),
		("props", "c15p5_hedge2_tree_winter", "hedge2_tree", None)],
	"fall_oak_planters.png": [("nature", "c15p5_mid_oak_fall", "mid_oak", None),
		("props", "c15p5_planter2_mums_fall", "planter2_0", None),
		("props", "c15p5_planter2_asters_fall", "planter2_1", None)],
	"winter_pots.png": [("props", "c15p5_hedge2_pot_winter", "hedge2_pot", None),
		("props", "c15p5_topiary_c_winter", "topiary_c", None),
		("props", "c15p5_hedge2_tree_s_winter", "hedge2_tree_s", None)],
	"interior_season.png": [("decor", "c15p5_winter_wreath", None, (46, 48)),
		("decor", "c15p5_harvest_table", None, (64, 54)),
		("decor", "c15p5_spring_garland", None, (64, 30))],
}


def key(img):
	img = img.convert("RGBA")
	px = img.load()
	w, h = img.size
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if r > 150 and b > 150 and g < 110 and abs(r - b) < 90:
				px[x, y] = (0, 0, 0, 0)
			elif r > 120 and b > 120 and g < r - 70 and g < b - 70:  # magenta fringe
				px[x, y] = (0, 0, 0, 0)
	return img


def segments(img, n=3):
	w, h = img.size
	a = img.split()[3].load()
	cols = [sum(1 for y in range(h) if a[x, y] > 0) > 2 for x in range(w)]
	segs = []
	x = 0
	while x < w:
		if cols[x]:
			s = x
			while x < w and cols[x]:
				x += 1
			if segs and s - segs[-1][1] < 24:  # stray leaves / small gaps join the object
				segs[-1][1] = x
			else:
				segs.append([s, x])
		x += 1
	segs.sort(key=lambda s: s[1] - s[0], reverse=True)
	segs = sorted(segs[:n])
	return segs


def fit(obj, size):
	bw, bh = size
	bb = obj.getbbox()
	obj = obj.crop(bb)
	sc = min(bw / obj.width, bh / obj.height)
	nw, nh = max(1, round(obj.width * sc)), max(1, round(obj.height * sc))
	obj = obj.resize((nw, nh), Image.LANCZOS)
	# harden alpha: pixel art has no soft edges
	px = obj.load()
	for y in range(nh):
		for x in range(nw):
			r, g, b, a = px[x, y]
			px[x, y] = (r, g, b, 255 if a >= 128 else 0)
	out = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
	out.paste(obj, ((bw - nw) // 2, bh - nh), obj)
	return out


def main():
	man = json.load(open(MANIFEST))
	for render, outs in JOBS.items():
		src = os.path.join(INC, render)
		if not os.path.exists(src):
			print("missing", src)
			continue
		img = key(Image.open(src))
		segs = segments(img, len(outs))
		for (group, oid, base, size), (x0, x1) in zip(outs, segs):
			if base:
				inf = man[group][base]
				size = (int(inf["w"]), int(inf["h"]))
			obj = img.crop((x0, 0, x1, img.height))
			out = fit(obj, size)
			rel = "%s/%s.png" % (group, oid)
			dst = os.path.join(GEN, rel)
			if os.path.exists(dst):
				os.remove(dst)  # hardlinked art: never write in place
			out.save(dst)
			man.setdefault(group, {})[oid] = {"file": rel, "h": size[1], "w": size[0]}
			print(rel, size)
	tmp = MANIFEST + ".tmp"
	with open(tmp, "w") as f:
		json.dump(man, f, indent=1)
		f.write("\n")
	os.replace(tmp, MANIFEST)


if __name__ == "__main__":
	main()
