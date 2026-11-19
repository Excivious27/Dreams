#!/usr/bin/env python3
"""Build fonts/symbols.ttf: the symbols the game prints (◆ ♥ ★ ✓ ▶ ⚔ ☂ ...) cut
from DejaVu Sans into a small fallback font.

Why: the default Godot font (Open Sans) has none of them. Desktop builds borrow
them from system fonts, but the web build Tom plays has no system fonts, so they
showed as empty boxes. SymbolFont (scripts/symbol_font.gd) adds this file as a
fallback of the default font at start-up.

Scans scripts/*.gd and data/*.json (plus EXTRA, for symbols likely to be used
later) and keeps every non-ASCII character DejaVu Sans has. Run it after adding
a new symbol; tools/phone_ui_test.gd fails if a used character has no glyph.
  python3 tools/make_symbol_font.py [path/to/DejaVuSans.ttf]
"""
import glob
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
OUT = os.path.join(ROOT, "fonts", "symbols.ttf")
EXTRA = "←↑→↓↔↕↖↗↘↙⇐⇒✓✔✗✘✕✖★☆✦✧◆◇♦♢♥♡♠♣●○◉◎■□▪▫▲△▼▽▶▷◀◁▸▹◂◃▾▴◷◴◔◑⊘⊗☀☁☂☃☼❄⚡♪♫✿❀❧⚑⚐⚔✉✎✏☒☑☐∞≈≠≤≥±×÷°·•…—–−‹›«»€£¥¢§¶©®™"


def used_chars() -> set:
    chars = set(EXTRA)
    for pat in ("scripts/*.gd", "data/*.json", "scenes/*.gd"):
        for p in glob.glob(os.path.join(ROOT, pat)):
            with open(p, encoding="utf-8") as f:
                chars.update(c for c in f.read() if ord(c) > 127)
    return chars


def main() -> None:
    font = TTFont(SRC)
    cmap = font.getBestCmap()
    want = sorted(c for c in used_chars() if ord(c) in cmap)
    missing = sorted(c for c in used_chars() if ord(c) not in cmap and ord(c) > 0x2000 and c not in EXTRA)
    opts = subset.Options()
    opts.layout_features = []
    opts.name_IDs = [0, 1, 2, 3, 4, 5, 6]
    opts.notdef_outline = False
    opts.hinting = False
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=[ord(c) for c in want])
    sub.subset(font)
    # A cut-down copy may not carry the original name (Bitstream Vera licence).
    for rec in font["name"].names:
        if rec.nameID in (1, 4, 16):
            rec.string = "Dreams Symbols"
        elif rec.nameID == 6:
            rec.string = "DreamsSymbols"
        elif rec.nameID == 3:
            rec.string = "Dreams Symbols (from DejaVu Sans)"
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    font.save(OUT)
    print("wrote %s: %d glyphs, %d bytes" % (OUT, len(want), os.path.getsize(OUT)))
    if missing:
        print("not in DejaVu Sans (pick another symbol):", " ".join(missing))


if __name__ == "__main__":
    main()
