#!/usr/bin/env python3
"""Steam store name search (CONDUCT S1, P6): how crowded is a title on Steam?

Uses the public store search API (no account): prints the total and the top 10
names per title. Network tool, NOT in check.sh; rerun before Tom's pick is
entered in Steamworks and paste the table into docs/steam-store/NAME-CHECK.md.
    python3 tools/steam_name_search.py "Hushfield" "Crowns & Crews" ...
stdlib only.
"""
import json
import sys
import urllib.parse
import urllib.request

URL = "https://store.steampowered.com/api/storesearch/?term=%s&l=english&cc=US"


def search(term):
    req = urllib.request.Request(URL % urllib.parse.quote(term), headers={"User-Agent": "name-check/1.0"})
    with urllib.request.urlopen(req, timeout=20) as r:
        d = json.load(r)
    return int(d.get("total", 0)), [i.get("name", "") for i in d.get("items", [])][:10]


def main():
    terms = sys.argv[1:] or ["dreams", "hushfield", "moonseed", "crowns & crews", "two too powerful",
                             "pillowfield", "penguins & pinstripes", "dreamfold"]
    print("| term | Steam results | top names |")
    print("|------|---------------|-----------|")
    for t in terms:
        try:
            n, names = search(t)
            print("| %s | %d | %s |" % (t, n, "; ".join(names) or "-"))
        except Exception as e:  # network tool: report and go on
            print("| %s | error | %s |" % (t, e))
    return 0


if __name__ == "__main__":
    sys.exit(main())
