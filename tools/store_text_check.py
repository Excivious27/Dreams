#!/usr/bin/env python3
"""Checks the Steam store text drafts in docs/steam-store/ (CONDUCT S1, P6).

Fields are marked in the drafts:
    <!-- field:short --> ... <!-- /field -->   short description (plain text)
    <!-- field:long -->  ... <!-- /field -->   About This Game (Steam BBCode)
    <!-- field:bullets --> ... <!-- /field --> feature bullets, one "- " line each
Rules (fail = exit 1):
  * docs/steam-store/facts.json is current (tools/store_facts.py --check logic)
  * every {token} in a field exists in facts.json
  * the title is only ever the {title} token (rename = one line in store_facts.py)
  * short: <= 300 characters rendered (warn > 250), one paragraph, no URL
  * no time-based words, prices, other game titles, review/superlative words
  * banned marketing words (casino, gun, blood, wine, 'AI', ...): those topics
    live only in the IARC / content-descriptor / AI-disclosure drafts
  * no hand-typed number >= 20 in a field (counts must come from tokens)
  * bullets <= 70 characters rendered
  * claims.md: every marketed claim maps to a docs/inventory.csv row; a
    'missing' row fails, a 'rough' row warns and forces 'page_ready: false'
stdlib only; no Godot.
"""
import csv
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, "docs", "steam-store")
sys.path.insert(0, os.path.join(ROOT, "tools"))

FIELD_RE = re.compile(r"<!--\s*field:(\w+)\s*-->(.*?)<!--\s*/field\s*-->", re.S)
TOKEN_RE = re.compile(r"\{(\w+)\}")
BANNED = ["casino", "gamble", "gambling", "betting", " bet ", "slots", "roulette", "poker", "blackjack",
          "gun", "guns", "shoot", "shooting", "kill", "blood", "gore", "drunk", "wine", "ale ", "ales",
          "beer", "alcohol", " ai ", "a.i.", "artificial intelligence", "best ", "#1", "award",
          "goty", "masterpiece", "general store"]
TIME_WORDS = ["now available", "available now", "coming soon", "pre-order", "preorder", "today",
              "this week", "on sale", "launch discount", "% off"]
OTHER_GAMES = ["stardew", "sun haven", "coral island", "mistria", "pacha", "moonstone",
               "media molecule", "dreamlight", "harvest moon", "story of seasons"]


def strip_tags(s):
    return re.sub(r"\[/?[a-z0-9*=]+\]", " ", s)


def main():
    errs, warns = [], []
    import store_facts
    facts = store_facts.build()
    fp = os.path.join(STORE, "facts.json")
    on_disk = json.load(open(fp)) if os.path.exists(fp) else {}
    if on_disk != facts:
        errs.append("facts.json is stale: run python3 tools/store_facts.py")
    fields = []
    for fn in sorted(os.listdir(STORE)):
        if fn.endswith(".md"):
            text = open(os.path.join(STORE, fn)).read()
            for m in FIELD_RE.finditer(text):
                fields.append((fn, m.group(1), m.group(2).strip()))
    kinds = {k for _, k, _ in fields}
    for need in ("short", "long", "bullets"):
        if need not in kinds:
            errs.append("no <!-- field:%s --> block in docs/steam-store/*.md" % need)
    for fn, kind, raw in fields:
        where = "%s [%s]" % (fn, kind)
        for t in TOKEN_RE.findall(raw):
            if t not in facts:
                errs.append("%s: unknown token {%s}" % (where, t))
        if re.search(r"\bdreams\b", TOKEN_RE.sub("", raw), re.I):
            errs.append("%s: literal 'Dreams' outside the {title} token" % where)
        rendered = TOKEN_RE.sub(lambda m: str(facts.get(m.group(1), m.group(0))), raw)
        plain = " " + strip_tags(rendered).lower().replace("\n", " ") + " "
        for w in BANNED:
            if re.search(r"(?<![a-z])" + re.escape(w.strip()) + r"(?![a-z])", plain):
                errs.append("%s: banned marketing word '%s'" % (where, w.strip()))
        for w in TIME_WORDS:
            if w in plain:
                errs.append("%s: time-based wording '%s'" % (where, w))
        for g in OTHER_GAMES:
            if g in plain:
                errs.append("%s: names another game '%s'" % (where, g))
        if re.search(r"https?://|www\.", plain) or "$" in plain:
            errs.append("%s: no links or prices in store text" % where)
        for n in re.findall(r"(?<![\w{])\d[\d,]*", TOKEN_RE.sub("", raw)):
            if int(n.replace(",", "")) >= 20:
                errs.append("%s: hand-typed number %s (use a facts.json token)" % (where, n))
        if kind == "short":
            s = " ".join(rendered.split())
            if len(s) > 300:
                errs.append("%s: %d chars, Steam allows 300" % (where, len(s)))
            elif len(s) > 250:
                warns.append("%s: %d chars (> 250 leaves little room for translations)" % (where, len(s)))
            if "\n\n" in rendered.strip():
                errs.append("%s: short description must be one paragraph" % where)
        if kind == "bullets":
            for line in rendered.splitlines():
                line = re.sub(r"\s*\[sys:[^\]]*\]\s*$", "", line.strip())
                if line.startswith("- ") and len(line) - 2 > 70:
                    errs.append("%s: bullet over 70 chars: %s" % (where, line[:40]))
    # Claims gate.
    inv = list(csv.reader(open(os.path.join(ROOT, "docs", "inventory.csv"))))
    cpath = os.path.join(STORE, "claims.md")
    if not os.path.exists(cpath):
        errs.append("docs/steam-store/claims.md missing")
    else:
        ctext = open(cpath).read()
        page_ready = re.search(r"page_ready:\s*(true|false)", ctext)
        rough = 0
        claims = re.findall(r"^\|\s*(c\d+)\s*\|([^|]*)\|([^|]*)\|", ctext, re.M)
        if not claims:
            errs.append("claims.md has no claim rows")
        for cid, claim, sysname in claims:
            key = sysname.strip().lower()
            rows = [r for r in inv if len(r) > 2 and key and key in r[1].lower()]
            if not rows:
                errs.append("claims.md %s: no inventory.csv row matches '%s'" % (cid, sysname.strip()))
                continue
            st = rows[0][2].strip().lower()
            if st == "missing":
                errs.append("claims.md %s: '%s' is missing in inventory.csv; do not market it" % (cid, claim.strip()))
            elif st in ("rough", "partial"):
                rough += 1
                warns.append("claims.md %s: '%s' is %s; review before the page goes live" % (cid, claim.strip(), st))
        if rough and (not page_ready or page_ready.group(1) == "true"):
            errs.append("claims.md: page_ready must stay false while %d marketed systems are rough" % rough)
    for w in warns:
        print("store_text_check: warn " + w)
    for e in errs:
        print("store_text_check: FAIL " + e)
    print("store_text_check: %d fields, %d failures" % (len(fields), len(errs)))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
