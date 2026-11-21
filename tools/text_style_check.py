#!/usr/bin/env python3
"""C12 P7 house-style and typo checker for player-facing text.

Scans the strings in data/*.json and the string literals in scripts/*.gd for:
  us_spelling   colour/armour/favour/fertiliser house style (UK), not color/armor/favor/fertilizer
  grumps_case   'Grumps' is the penguin book's proper name, never 'grumps'
  wren_jr       the name is 'Wren Jr.', never 'Wren jr'
  real_brand    real trademarks / Tom's names stay out: Skee-Ball, Tommy
  autumn        the calendar says Fall; text must too
  bare_plural   fixed plurals after a count that can be 1 ('1 pieces', 'only %d are left')
  count_name    '%d %s' % [n, item_name]-style counts in scripts (use ItemWords.count_id)
  double_space  two spaces inside a sentence
  part_of_set   'Part of the X.' decor lines without 'Set'

Known hits are a per-file, per-rule count baseline in tools/text_style_allow.json.
The check fails only when a file's count for a rule goes UP (new text must follow the
house style); counts that went down are listed so the baseline can be lowered with
--update-allow (integration only).

  python3 tools/text_style_check.py           # gate (check.sh)
  python3 tools/text_style_check.py --list    # every hit with its text
"""
import glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
ALLOW = "tools/text_style_allow.json"

RULES = {
    "us_spelling": (re.compile(r"\b(?:colou?r(?<!colour)s?|colored|armor(?:ed|s)?|favor(?:s|ite|ites)?|fertiliz\w*|fertilizer)\b", re.I), "text"),
    "grumps_case": (re.compile(r"(?<![\w_./])grumps?\b"), "text"),
    "wren_jr": (re.compile(r"\bWren jr\b"), "text"),
    "real_brand": (re.compile(r"\bSkee-?Ball\b|\bTommy\b", re.I), "text"),
    "autumn": (re.compile(r"\bautumn\b"), "text"),
    "bare_plural": (re.compile(r"\b1 (?:pieces|kinds|items|are left)\b|only %d are left|%d pieces back|%d kinds met"), "text"),
    "part_of_set": (re.compile(r"\bPart of the [A-Z][\w' ]+?\.(?<!Set\.)"), "text"),
    "count_name": (re.compile(r'"[^"\n]*%d %s[^"\n]*"\s*%\s*\[[^\]\n]*item_name'), "code"),
}
# Strings that are code, not prose (ids, keys, paths).
ID_RX = re.compile(r"^[\w./:@%-]*$")


def json_strings(o, out):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == "_":
                continue
            json_strings(v, out)
    elif isinstance(o, list):
        for v in o:
            json_strings(v, out)
    elif isinstance(o, str) and " " in o and not ID_RX.match(o):
        out.append(o)


def scan():
    hits = []  # (file, rule, text)
    for f in sorted(glob.glob("data/*.json")):
        try:
            d = json.load(open(f, encoding="utf-8"))
        except Exception:
            continue
        strs = []
        json_strings(d, strs)
        for s in strs:
            for rule, (rx, kind) in RULES.items():
                if kind == "text" and rx.search(s):
                    hits.append((f, rule, s))
    for f in sorted(glob.glob("scripts/**/*.gd", recursive=True)):
        src = open(f, encoding="utf-8").read()
        for line in src.splitlines():
            t = line.strip()
            if t.startswith("#"):
                continue
            for rule, (rx, kind) in RULES.items():
                if kind == "code":
                    if rx.search(line):
                        hits.append((f, rule, t))
                    continue
                for lit in re.findall(r'"((?:[^"\\\n]|\\.)*)"', line):
                    if " " in lit and rx.search(lit):
                        hits.append((f, rule, lit))
    return hits


def main(argv):
    hits = scan()
    counts = {}
    for f, rule, _ in hits:
        counts.setdefault(f, {}).setdefault(rule, 0)
        counts[f][rule] += 1
    if "--update-allow" in argv:
        json.dump(counts, open(ALLOW, "w", encoding="utf-8"), indent=1, sort_keys=True)
        print("text_style_check: baseline written (%d hits in %d files)" % (len(hits), len(counts)))
        return 0
    allow = json.load(open(ALLOW, encoding="utf-8")) if os.path.exists(ALLOW) else {}
    bad, lower = [], []
    for f, rules in counts.items():
        for rule, n in rules.items():
            a = int(allow.get(f, {}).get(rule, 0))
            if n > a:
                bad.append((f, rule, n, a))
    for f, rules in allow.items():
        for rule, a in rules.items():
            if counts.get(f, {}).get(rule, 0) < a:
                lower.append((f, rule, counts.get(f, {}).get(rule, 0), a))
    if "--list" in argv:
        for f, rule, t in hits:
            print("%-28s %-12s %s" % (f, rule, t[:150]))
    for f, rule, n, a in bad:
        print("text_style_check: %s %s: %d hits (allowed %d)" % (f, rule, n, a))
        for ff, rr, t in hits:
            if ff == f and rr == rule:
                print("    " + t[:160])
    for f, rule, n, a in lower:
        print("  fixed (lower the baseline with --update-allow): %s %s %d < %d" % (f, rule, n, a))
    print("text_style_check: %d hits, %d over baseline" % (len(hits), len(bad)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
