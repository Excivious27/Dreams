#!/usr/bin/env python3
"""Rebuilds docs/INVENTORY.md from docs/inventory.csv (the csv is the source; C5 P6).

Also refreshes the live counts in the csv's Art / Audio / QA rows (sliced pieces and groups,
music tracks, sfx files, ambience beds, *_test.gd files and how many check.sh runs) and
marks each named test that check.sh does not run. Run after editing the csv:
    python3 tools/inventory_md.py
"""
import csv, datetime, glob, json, os, re

D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV = os.path.join(D, "docs", "inventory.csv")
MD = os.path.join(D, "docs", "INVENTORY.md")


def counts():
    man = json.load(open(os.path.join(D, "art", "gen", "manifest.json")))
    pieces = sum(len(v) if isinstance(v, dict) else 1 for v in man.values())
    music = len(glob.glob(os.path.join(D, "audio", "music", "*.ogg")))
    sfx = len([f for f in os.listdir(os.path.join(D, "audio", "sfx")) if f.endswith((".wav", ".ogg"))])
    amb = len([f for f in os.listdir(os.path.join(D, "audio", "amb")) if f.endswith((".wav", ".ogg"))])
    tests = sorted(os.path.basename(p)[:-3] for p in glob.glob(os.path.join(D, "tools", "*_test.gd")))
    check = open(os.path.join(D, "tools", "check.sh")).read()
    in_check = [t for t in tests if t + ".gd" in check]
    return {"groups": len(man), "pieces": pieces, "music": music, "sfx": sfx, "amb": amb,
            "tests": tests, "in_check": in_check, "check": check}


def main():
    rows = list(csv.reader(open(CSV)))
    c = counts()
    for r in rows:
        if len(r) < 6:
            continue
        if r[0] == "Art" and re.match(r"[\d,]+ sliced pieces", r[1]):
            r[1] = re.sub(r"^[\d,]+ sliced pieces in \d+ groups", "{:,} sliced pieces in {} groups".format(c["pieces"], c["groups"]), r[1])
        if r[0] == "Audio" and re.match(r"\d+ music tracks", r[1]):
            r[1] = "%d music tracks (ACE), %d sfx files, %d ambience beds" % (c["music"], c["sfx"], c["amb"])
        if r[0] == "QA" and r[1].startswith("Headless tests"):
            r[4] = "%d *_test.gd; %d run in check.sh" % (len(c["tests"]), len(c["in_check"]))
        # Tests column: mark only what check.sh really skips.
        if r[0] not in ("Outstanding", "Needs Tom", "Tom", "Area") and r[4]:
            parts = []
            for t in [x.strip() for x in r[4].split(",")]:
                name = re.sub(r"\s*\(.*\)$", "", t)
                if name.endswith("_test") and name in c["tests"]:
                    t = name if name in c["in_check"] else name + " (not in check.sh)"
                parts.append(t)
            r[4] = ", ".join(parts)
    with open(CSV + ".tmp", "w", newline="") as fh:
        csv.writer(fh, lineterminator="\n").writerows(rows)
    os.replace(CSV + ".tmp", CSV)

    hdr = rows[0]
    i_out = next(i for i, r in enumerate(rows) if r and r[0] == "Outstanding")
    i_tom = next(i for i, r in enumerate(rows) if r and r[0] == "Needs Tom")
    systems = [r for r in rows[1:i_out] if len(r) >= 4]
    by = {}
    for r in systems:
        by[r[2]] = by.get(r[2], 0) + 1
    avg = sum(int(r[3] or 0) for r in systems) / max(1, len(systems))
    today = datetime.date.today().isoformat()
    L = ["# Dreams: inventory (regenerated %s by tools/inventory_md.py)" % today, "",
         "Every system in the game with its state, what is still outstanding, test coverage, and what Claude needs from Tom. "
         "`docs/inventory.csv` is the source (edit it, then run `python3 tools/inventory_md.py`). Percentages are estimates against "
         "Tom's bar (\"100% = Stardew-grade commercial release\").", "",
         "**Summary:** %d systems: %s. Average %d%%." % (len(systems), ", ".join("%d %s" % (by[k], k) for k in ("done", "rough", "missing") if k in by), round(avg)), "",
         "**Live counts:** {:,} sliced art pieces in {} groups; {} music tracks, {} sfx files, {} ambience beds; {} headless tests, {} in check.sh.".format(
             c["pieces"], c["groups"], c["music"], c["sfx"], c["amb"], len(c["tests"]), len(c["in_check"])), "",
         "## Systems", "",
         "Status: **done** = built, tested, only polish left; **rough** = playable but content or features are still missing; **missing** = not started.", "",
         "| " + " | ".join(hdr[:6]) + " |", "|" + "---|" * 6]
    for r in sorted(systems, key=lambda r: (r[0], -int(r[3] or 0))):
        L.append("| " + " | ".join(x.replace("|", "/") for x in (r + [""] * 6)[:6]) + " |")
    L += ["", "## Outstanding", ""]
    for r in rows[i_out + 1:i_tom]:
        if len(r) >= 5:
            L.append("- %s: %s = %s (checked by %s, %s)" % (r[0], r[1], r[2], r[4], r[5] if len(r) > 5 else ""))
    L += ["", "## What Claude needs from Tom", ""]
    n = 0
    for r in rows[i_tom + 1:]:
        if len(r) >= 3 and r[0] == "Tom":
            n += 1
            L.append("%d. **%s** (blocks: %s). %s" % (n, r[1], r[2], r[5] if len(r) > 5 else ""))
    not_run = [t for t in c["tests"] if t not in c["in_check"]]
    L += ["", "## Tests outside check.sh", "", ", ".join(not_run) if not_run else "none", ""]
    open(MD + ".tmp", "w").write("\n".join(L))
    os.replace(MD + ".tmp", MD)
    print("inventory: %d systems, avg %d%%, %d tests (%d in check.sh)" % (len(systems), round(avg), len(c["tests"]), len(c["in_check"])))


if __name__ == "__main__":
    main()
