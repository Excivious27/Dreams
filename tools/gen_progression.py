#!/usr/bin/env python3
"""C16a P1: compile the unlock table in docs/PROGRESSION.md into data/progression.json.

Rows of the '## Unlock table' markdown table: | id | day | arc | status | what opens | gate |.
Progression.unlock_day(id) (scripts/progression.gd) reads the result; tools/progression_test.gd
checks the 'enforced' rows against the game data. Run by tools/regen_data.sh."""
import json
import os

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def parse(text):
    rows, on = {}, False
    for line in text.splitlines():
        if line.startswith("## "):
            on = line.strip() == "## Unlock table"
            continue
        if not on or not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 6 or cells[0] in ("id", "") or set(cells[0]) <= {"-"}:
            continue
        rid, day, arc, status, what, gate = cells[:6]
        assert rid not in rows, "duplicate progression id " + rid
        assert status in ("enforced", "planned"), (rid, status)
        assert arc in ("both", "penguins", "gangsters"), (rid, arc)
        rows[rid] = {"day": int(day), "arc": arc, "status": status, "what": what, "gate": gate}
    assert rows, "no rows in the PROGRESSION.md unlock table"
    return rows


def main():
    rows = parse(open(os.path.join(D, "docs", "PROGRESSION.md"), encoding="utf-8").read())
    out = {"_": "Written by tools/gen_progression.py from docs/PROGRESSION.md (edit the doc's table, not this).", "unlocks": rows}
    with open(os.path.join(D, "data", "progression.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1, sort_keys=True, ensure_ascii=False)
        f.write("\n")
    print("gen_progression: %d unlocks" % len(rows))


if __name__ == "__main__":
    main()
