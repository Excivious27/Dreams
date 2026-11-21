#!/usr/bin/env python3
"""Download ACE versions, pick the best per track, import it, log it.

stdin lines:  <name> <kind music|jingle|kit|raw> <song_id> <download_url> [song_page]
Raw files go to $ACE_RAW (default /home/claude/work/ace_raw). audio/ACE_LOG.json keeps
every version id, the chosen one and its score, so any track can be swapped later:
    python3 tools/ace_batch.py --swap <name>   (imports the other version)
    python3 tools/ace_batch.py --alt <src> <new>  (imports src's NON-chosen version as <new>;
        logs {kind, chosen, versions, alt_of: src}; prints the id to re-download if the raw is gone)
    ... | python3 tools/ace_batch.py --pair [--suffix _2]   (stdin import; when the second take
        also passes the accept rule it becomes <name>_2 with alt_of: <name>)
Accept rule for a second take: score >= ACCEPT (60) and within 15 of the chosen take.
"""
import json, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
RAW = os.environ.get("ACE_RAW", "/home/claude/work/ace_raw")
LOG = os.path.join(ROOT, "audio", "ACE_LOG.json")
sys.path.insert(0, HERE)
import ace_pick

ACCEPT = 60.0      # minimum ace_pick score for a non-chosen take to become a rotation partner
ACCEPT_GAP = 15.0  # ... and no more than this far below the chosen take


def accept_alt(best, other):
    b = best.get("score", {}).get("score", 0.0)
    o = other.get("score", {}).get("score", -1e9)
    return o >= ACCEPT and o >= b - ACCEPT_GAP


def alt_entry(log, src, new, other):
    """ACE_LOG row for <new> = the non-chosen take <other> of <src>."""
    e = log[src]
    return {"kind": e["kind"], "chosen": other["id"], "versions": [dict(other)],
            "alt_of": src, "note": f"second take of {src}"}


def do_alt(log, src, new):
    e = log.get(src)
    if not e:
        print(f"--alt: {src} is not in ACE_LOG"); return 2
    others = [v for v in e["versions"] if v["id"] != e["chosen"]]
    if not others:
        print(f"--alt: {src} has no other version"); return 2
    other = max(others, key=lambda v: v.get("score", {}).get("score", -1e9))
    if not os.path.exists(other["file"]):
        print(f"--alt: raw gone, re-download {other['id']} with download_song to {other['file']}"); return 3
    if "score" not in other:
        other["score"] = ace_pick.score(other["file"])
    imp(new, e["kind"], other["file"])
    log[new] = alt_entry(log, src, new, other)
    save_log(log)
    print(f"{new}: imported {other['id']} (alt_of {src}, score {other['score']['score']})")
    return 0

def load_log():
    return json.load(open(LOG)) if os.path.exists(LOG) else {}

def save_log(l):
    # audio/ may be hardlinked to another checkout: never rewrite a file in place.
    json.dump(l, open(LOG + ".tmp", "w"), indent=1, sort_keys=True, default=float)
    if os.path.exists(LOG):
        os.remove(LOG)
    os.rename(LOG + ".tmp", LOG)

def imp(name, kind, path, extra=()):
    if not os.path.isabs(path):
        path = os.path.join(ROOT, path)  # Tom's uploads are logged repo-relative
    if kind in ("music", "once"):
        subprocess.run([sys.executable, os.path.join(HERE, "ace_import.py"), name, path] + (["--once"] if kind == "once" else []) + list(extra), check=True)

def main():
    os.makedirs(RAW, exist_ok=True)
    log = load_log()
    if len(sys.argv) > 1 and sys.argv[1] == "--reimport-all":
        # --reimport-all [--jobs N] [names...]: re-run the chosen raw of every song
        # through ace_import (raws missing from $ACE_RAW are listed: re-download them
        # by id with download_song first).
        from concurrent.futures import ThreadPoolExecutor
        args = sys.argv[2:]
        jobs = 1
        if "--jobs" in args:
            i = args.index("--jobs"); jobs = int(args[i + 1]); del args[i:i + 2]
        todo, missing = [], []
        for nm, e in sorted(log.items()):
            if e["kind"] not in ("music", "once") or (args and nm not in args):
                continue
            v = [x for x in e["versions"] if x["id"] == e["chosen"]][0]
            # an entry may carry "no_offset": true (loop to 0: its intro point clicks)
            ex = ("--no-offset",) if e.get("no_offset") else ()
            (todo if os.path.exists(v["file"]) else missing).append((nm, e["kind"], v["file"], ex))
        failed = []
        def one(t):
            try:
                imp(*t)
            except subprocess.CalledProcessError:
                failed.append(t[0])
        with ThreadPoolExecutor(jobs) as ex:
            list(ex.map(one, todo))
        print(f"reimported {len(todo) - len(failed)}; failed {failed}; raw missing {[m[0] for m in missing]}")
        return
    if len(sys.argv) > 2 and sys.argv[1] == "--swap":
        e = log[sys.argv[2]]
        other = [v for v in e["versions"] if v["id"] != e["chosen"]][0]
        e["chosen"] = other["id"]; imp(sys.argv[2], e["kind"], other["file"]); save_log(log); return
    if len(sys.argv) > 3 and sys.argv[1] == "--alt":
        sys.exit(do_alt(log, sys.argv[2], sys.argv[3]))
    pair = "--pair" in sys.argv
    suffix = sys.argv[sys.argv.index("--suffix") + 1] if "--suffix" in sys.argv else "_2"
    groups = {}
    for line in sys.stdin:
        p = line.split()
        if len(p) < 4: continue
        name, kind, sid, url = p[:4]
        page = p[4] if len(p) > 4 else ""
        f = os.path.join(RAW, f"{name}__{sid}.mp3")
        if not os.path.exists(f) or os.path.getsize(f) < 10000:
            subprocess.run(["curl", "-sS", "-L", "-m", "300", "-o", f, url], check=True)
        groups.setdefault((name, kind), []).append({"id": sid, "file": f, "page": page})
    for (name, kind), vers in groups.items():
        scored = {r["file"]: r for r in (ace_pick.score(v["file"]) for v in vers)}
        for v in vers: v["score"] = scored[v["file"]]
        best = max(vers, key=lambda v: v["score"]["score"])
        old = log.get(name, {})
        prev = old.get("previous", [])
        if old.get("versions") and old.get("chosen") != best["id"] and not any(v["id"] == best["id"] for v in old["versions"]):
            prev = prev + [{"chosen": old.get("chosen"), "versions": [v["id"] for v in old["versions"]]}]
        log[name] = {"kind": kind, "chosen": best["id"], "versions": vers,
                     "note": old.get("note", "")}
        if prev:
            log[name]["previous"] = prev
        imp(name, kind, best["file"])
        if pair:
            rest = [v for v in vers if v is not best]
            if rest and accept_alt(best, max(rest, key=lambda v: v["score"]["score"])):
                other = max(rest, key=lambda v: v["score"]["score"])
                imp(name + suffix, kind, other["file"])
                log[name + suffix] = alt_entry(log, name, name + suffix, other)
                print(f"{name + suffix}: second take {other['id']} score {other['score']['score']}")
        print(f"{name}: chose {best['id']} score {best['score']['score']} (others: " +
              ", ".join(str(v['score']['score']) for v in vers if v is not best) + ")")
    save_log(log)

if __name__ == "__main__":
    main()
