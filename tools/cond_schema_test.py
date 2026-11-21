#!/usr/bin/env python3
"""C12 P7: guard the 'when' condition schema (GameState._cond_ok silently passes unknown keys).

Walks every data/*.json and checks every dict under a "when" key:
  * every key is one GameState._cond_ok (or Collections/Tickets/Epilogue.cond_ok) reads;
    the allowed list is extracted from the scripts by regex, so it cannot drift;
    'hours' is allowed in events.json only (events.gd reads it itself);
  * values have the right shape: friend=[npc id, 1..10], skill=[skill, int], season,
    arc, decision=[key, int], quest/not_quest a real quest id, item ids real items,
    flags referenced somewhere besides conditions (catches typos).
Fails with file + JSON path. Run: python3 tools/cond_schema_test.py
"""
import glob, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

COND_SCRIPTS = ["scripts/game_state.gd", "scripts/collections.gd", "scripts/tickets.gd", "scripts/epilogue.gd"]
EXTRA = {"events.json": {"hours"}}
SEASONS = {"spring", "summer", "fall", "winter"}
ARCS = {"penguins", "gangsters"}


def allowed_keys():
    keys = set()
    for f in COND_SCRIPTS:
        src = open(f, encoding="utf-8").read()
        keys |= set(re.findall(r'when\.has\("(\w+)"\)', src))
        keys |= set(re.findall(r'when\.get\("(\w+)"', src))
    return keys


def walk(o, path, out):
    if isinstance(o, dict):
        for k, v in o.items():
            p = "%s/%s" % (path, k)
            if k == "when" and isinstance(v, dict):
                out.append((p, v))
            walk(v, p, out)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            walk(v, "%s[%d]" % (path, i), out)


def all_ids():
    ids = set()
    for f in glob.glob("data/*.json"):
        ids |= set(re.findall(r'"id"\s*:\s*"([\w@.-]+)"', open(f, encoding="utf-8").read()))
    return ids


def main():
    keys = allowed_keys()
    if len(keys) < 20:
        print("cond_schema_test FAIL: only %d keys extracted from %s" % (len(keys), COND_SCRIPTS))
        return 1
    npcs = set(json.load(open("data/npcs.json", encoding="utf-8")))
    items = set(json.load(open("data/items.json", encoding="utf-8")))
    ids = all_ids()
    scripts_src = "\n".join(open(f, encoding="utf-8").read() for f in glob.glob("scripts/**/*.gd", recursive=True))
    data_src = {f: open(f, encoding="utf-8").read() for f in glob.glob("data/*.json")}
    # story beat ids give st_<id> flags
    beat_flags = set()
    for f in ("data/story.json", "data/story_gang.json"):
        beat_flags |= {"st_" + b for b in re.findall(r'"id"\s*:\s*"(\w+)"', data_src.get(f, ""))}
    skills = set(re.findall(r'"(fishing|foraging|mining|farming|combat|ranching|cooking|crafting)"', scripts_src))
    errs, n = [], 0
    all_conds = []
    for f in sorted(data_src):
        try:
            d = json.loads(data_src[f])
        except Exception as e:
            errs.append("%s: bad JSON %s" % (f, e))
            continue
        out = []
        walk(d, "", out)
        for p, w in out:
            all_conds.append((f, p, w))
    # every string a flag could be set from: data values outside "when" dicts, script literals
    known = set()

    def strings(o, in_when=False):
        if isinstance(o, dict):
            for k, v in o.items():
                if k == "when":
                    continue
                known.add(str(k))
                strings(v)
        elif isinstance(o, list):
            for v in o:
                strings(v)
        elif isinstance(o, str):
            known.add(o)
    for f in data_src:
        try:
            strings(json.loads(data_src[f]))
        except Exception:
            pass
    lits = set(re.findall(r'"([^"\n]{1,60})"', scripts_src))
    known |= lits
    prefixes = {l.split("%")[0] for l in lits if "%" in l and l.split("%")[0]} | {l for l in lits if l.endswith("_")}

    suffixes = {l for l in lits if l.startswith("_") and 3 <= len(l) <= 12 and l[1:].isidentifier()}

    def flag_known(fl):
        if fl in known or fl in beat_flags:
            return True
        if any(fl.startswith(pr) and len(pr) >= 3 for pr in prefixes):
            return True
        return any(fl.endswith(sx) and fl[:-len(sx)] in known for sx in suffixes)  # reg + "_seen"
    for f, p, w in all_conds:
        n += 1
        base = os.path.basename(f)
        ok_keys = keys | EXTRA.get(base, set())
        where = "%s %s" % (f, p)
        for k, v in w.items():
            if k not in ok_keys:
                errs.append("%s: unknown condition key '%s' (GameState._cond_ok ignores it)" % (where, k))
                continue
            if k in ("day", "crops", "crystals", "chapter", "mine_floor", "hearts_total", "heat_min", "heat_max", "tickets_won", "museum_n") \
                    and not isinstance(v, (int, float, list)):
                errs.append("%s: '%s' should be a number, got %r" % (where, k, v))
            if k == "friend":
                if not (isinstance(v, list) and len(v) == 2 and str(v[0]) in npcs and 1 <= int(v[1]) <= 10):
                    errs.append("%s: friend should be [npc id, 1..10], got %r" % (where, v))
            if k == "skill" and not (isinstance(v, list) and len(v) == 2 and isinstance(v[1], int)):
                errs.append("%s: skill should be [skill, level], got %r" % (where, v))
            if k == "season" and v not in SEASONS:
                errs.append("%s: season %r" % (where, v))
            if k == "arc" and v not in ARCS:
                errs.append("%s: arc %r" % (where, v))
            if k == "decision" and not (isinstance(v, list) and len(v) == 2 and isinstance(v[1], int)):
                errs.append("%s: decision should be [key, int], got %r" % (where, v))
            if k in ("quest", "not_quest") and str(v) not in ids:
                errs.append("%s: %s '%s' is not an id in data/*.json" % (where, k, v))
            if k in ("item", "pup_gear") and str(v) not in items:
                errs.append("%s: %s '%s' is not in items.json" % (where, k, v))
            if k == "items":
                for pair in v:
                    if str(pair[0]) not in items:
                        errs.append("%s: items id '%s' is not in items.json" % (where, pair[0]))
            if k in ("flag", "not_flag") and not flag_known(str(v)):
                errs.append("%s: %s '%s' is never set or read anywhere else (typo?)" % (where, k, v))
            if k in ("flags", "not_flags"):
                if not isinstance(v, list):
                    errs.append("%s: %s should be a list" % (where, k))
                else:
                    for fl in v:
                        if not flag_known(str(fl)):
                            errs.append("%s: %s '%s' is never set or read anywhere else (typo?)" % (where, k, fl))
    if errs:
        print("cond_schema_test FAIL (%d):" % len(errs))
        for e in errs:
            print("  " + e)
        return 1
    print("cond_schema_test OK: %d when-conditions, %d keys allowed" % (n, len(keys)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
