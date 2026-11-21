#!/usr/bin/env python3
"""ratings_facts_check.py: keep docs/steam-store/ratings.md and ai-disclosure.md true (s1_13-04/05/09).

Re-derives the facts the Steam Content Survey / IARC / AI-disclosure answers depend on and fails with
"ratings.md answer X is now false" when the game drifts:
  - no blood/gore in player text (allowlist: Blood Orange, Rare Bloodlines, lifeblood)
  - every alcoholic item is a trade good (drink rule) and beasts drop no animal parts (animal rule)
  - weapons named in ratings.md exist; casino tables in tools/gen_casino.py are all named in ratings.md
  - no in-app purchases / store calls in scripts; no network host other than the relay and the game's own pages
    (keeps "nothing is generated at runtime" true)
  - in-game credits (data/epilogue.json) carry the ai-disclosure key phrases and no family names
stdlib only.
"""
import json, os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
R = lambda *p: os.path.join(ROOT, *p)
TEXT_FILES = ["items.json", "npcs.json", "quest_lines.json", "quests.json", "skills.json", "epilogue.json", "hearts.json"]
BLOOD_OK = re.compile(r"blood orange|blood_orange|bloodlines|lifeblood", re.I)
HOSTS_OK = ("sslip.io", "github.io", "x.io", "localhost", "127.0.0.1")
KEY_PHRASES = ["OpenAI image models", "ACE Music", "Claude", "CC0"]
FAMILY = re.compile(r"\b(Tom|Tomorrow|Thomas|Barany|Kelsie|Miles|Bruce)\b")


def main():
    bad = []
    rat = open(R("docs", "steam-store", "ratings.md")).read()
    ai = open(R("docs", "steam-store", "ai-disclosure.md")).read()
    # blood / gore
    for f in TEXT_FILES:
        p = R("data", f)
        if not os.path.isfile(p):
            continue
        for m in re.finditer(r"[^\"]*\b(blood|gore|gory)\w*[^\"]*", open(p).read(), re.I):
            if not BLOOD_OK.search(m.group(0)):
                bad.append("ratings.md answer 'Blood and gore: none' is now false: data/%s %r" % (f, m.group(0)[:60]))
    # drink + animal rules (their own tests gate them too; here they back the answers)
    for t, ans in (("drink_rule_test.py", "Alcohol: reference only"), ("animal_rule_test.py", "Violence against animals: none")):
        r = subprocess.run([sys.executable, R("tools", t)], capture_output=True, text=True)
        if r.returncode != 0:
            bad.append("ratings.md answer '%s' is now false (%s fails)" % (ans, t))
    # weapons named in the doc exist
    items = json.load(open(R("data", "items.json")))
    for iid in ("scattergun", "tommy_gun", "gold_revolver"):
        if iid not in items:
            bad.append("ratings.md names weapon %s, which no longer exists" % iid)
    # casino tables all disclosed
    cas = open(R("tools", "gen_casino.py")).read()
    for name in re.findall(r'\{"id": "\w+", "name": "([^"]+)", "accent"', cas):
        if name not in rat:
            bad.append("ratings.md gambling answer does not name casino table %r" % name)
    # purchases / network
    for fn in sorted(os.listdir(R("scripts"))):
        if not fn.endswith(".gd"):
            continue
        s = open(R("scripts", fn)).read()
        if re.search(r"activateGameOverlayToStore|startPurchase|InAppPurchase|\bIAP\b|microtransaction", s):
            bad.append("ratings.md answer 'Digital purchases: no' is now false: scripts/%s" % fn)
        for host in re.findall(r"(?:https?|wss?)://([A-Za-z0-9.-]+)", s):
            if not host.endswith(HOSTS_OK):
                bad.append("ai-disclosure 'nothing generated at runtime' / IARC internet answer: scripts/%s talks to %s" % (fn, host))
    # credits vs disclosure
    cr = json.load(open(R("data", "epilogue.json"))).get("credits", "")
    for k in KEY_PHRASES:
        if k not in cr:
            bad.append("in-game credits lack %r (ai-disclosure.md says it)" % k)
        if k not in ai:
            bad.append("ai-disclosure.md lacks %r" % k)
    if FAMILY.search(cr):
        bad.append("in-game credits name a family member (CLAUDE.md: no family names in the game)")
    for b in bad:
        print("ratings_facts_check: FAIL " + b)
    print("ratings_facts_check: %d failures" % len(bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
