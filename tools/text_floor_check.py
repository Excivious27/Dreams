#!/usr/bin/env python3
"""Text size floors (C5 c5_13 #2): Godot can't measure text drawn with draw_string, so
this reads the source. Fails on
  - draw_string / draw_string_outline with a literal font size under 7 in the HUD and touch
    controls (scripts/hud.gd, scripts/touch_controls.gd: the always-on screen),
  - add_theme_font_size_override("font_size", N) with N under 7 anywhere in scripts/.
Prints file:line for each."""
import glob, os, re, sys
D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FLOOR = 7
bad = []
call = re.compile(r"draw_string(_outline)?\(")
for p in ("scripts/hud.gd", "scripts/touch_controls.gd"):
    for i, ln in enumerate(open(os.path.join(D, p)), 1):
        if not call.search(ln):
            continue
        # args after the alignment: (font, pos, text, ALIGN, width, SIZE, ...)
        m = re.search(r"HORIZONTAL_ALIGNMENT_\w+(?: if [^,]+ else HORIZONTAL_ALIGNMENT_\w+)?,\s*[^,]+,\s*(\d+)\b", ln)
        if m and int(m.group(1)) < FLOOR:
            bad.append("%s:%d drawn text size %s" % (p, i, m.group(1)))
for p in glob.glob(os.path.join(D, "scripts", "*.gd")):
    for i, ln in enumerate(open(p), 1):
        m = re.search(r'add_theme_font_size_override\("font_size",\s*(\d+)\)', ln)
        if m and int(m.group(1)) < FLOOR:
            bad.append("%s:%d label font size %s" % (os.path.relpath(p, D), i, m.group(1)))
# C16b P4 (c16b_10-07): the campaign board's own helpers, _label(text, SIZE, ...) and
# _text(cv, f, pos, text, SIZE, ...), with a literal size.
cs = os.path.join(D, "scripts", "campaign_screen.gd")
for i, ln in enumerate(open(cs), 1):
    if "_label(" in ln or "_text(cv" in ln:
        for m in re.finditer(r",\s*(\d+)\s*,\s*(?:Color|gold|dcol|mcol)", ln):
            if int(m.group(1)) < FLOOR:
                bad.append("scripts/campaign_screen.gd:%d board text size %s" % (i, m.group(1)))
print("text floors: %d under %d px" % (len(bad), FLOOR))
for b in bad:
    print("  " + b)
sys.exit(1 if bad else 0)
