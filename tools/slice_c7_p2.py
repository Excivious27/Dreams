"""C7 P2 story panels: art/incoming/c7/p2_cut_*.png -> art/gen/ui/cut_*.png (500x355, like the other cut panels) + manifest."""
import json, os
from PIL import Image

PANELS = {"cut_penguins_fly": "art/incoming/c7/p2_cut_penguins_fly_b.png"}
W, H = 500, 355


def main():
    mp = "art/gen/manifest.json"
    man = json.load(open(mp))
    for name, src in PANELS.items():
        im = Image.open(src).convert("RGBA")
        sw, sh = im.size
        cw = min(sw, int(sh * W / H))
        ch = int(cw * H / W)
        x0, y0 = (sw - cw) // 2, (sh - ch) // 2
        im = im.crop((x0, y0, x0 + cw, y0 + ch)).resize((W, H), Image.LANCZOS)
        out = "art/gen/ui/%s.png" % name
        if os.path.exists(out):
            os.remove(out)  # art is hardlinked: never write in place
        im.save(out)
        man.setdefault("ui", {})[name] = {"file": "ui/%s.png" % name, "h": H, "w": W}
        print("wrote", out)
    json.dump(man, open(mp + ".tmp", "w"), indent=1)
    os.remove(mp)
    os.rename(mp + ".tmp", mp)


if __name__ == "__main__":
    main()
