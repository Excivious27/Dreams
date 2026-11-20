#!/usr/bin/env python3
"""cluster.py <reports dir> <conduct number> [--packages N] [--out path]

Read every auditor findings file (<id>.jsonl, one JSON object per line:
id, area, severity blocker|major|minor|polish, title, files[], repro, fix,
art_needed, audio_needed, needs_tom), dedupe by (files, title), and group the
findings into N (default 6) file-disjoint fix packages:

  - every file belongs to exactly one package;
  - the big shared files (game_map.gd, game_state.gd, hud.gd, region.gd) each get
    a single owner (the package that holds most findings touching it);
  - packages are grown greedily from the files with the most severe findings,
    pulling in every file that co-occurs with them in a finding (union-find),
    then balanced by weight (blocker 8, major 4, minor 2, polish 1).

Writes cN_packages_draft.md next to the reports (or --out): per package its owned
files, findings sorted by severity, art/audio asks and needs_tom items, plus a
list of findings with no files (to assign by hand). The main chat reviews it,
adds open work and Tom's notes, then launches the fix agents.
"""
import glob, json, os, re, sys
from collections import defaultdict

SEV = {"blocker": 8, "major": 4, "minor": 2, "polish": 1}
BIG = ("scripts/game_map.gd", "scripts/game_state.gd", "scripts/hud.gd", "scripts/region.gd")


def norm_file(f):
    f = f.strip().split(":")[0].split(" ")[0]
    if f and "/" not in f:
        if f.endswith(".gd"):
            f = "scripts/" + f
        elif f.endswith(".py"):
            f = "tools/" + f
        elif f.endswith(".json"):
            f = "data/" + f
    return f


def load(d):
    items, seen = [], {}
    for p in sorted(glob.glob(os.path.join(d, "*.jsonl"))):
        for ln in open(p, errors="replace"):
            ln = ln.strip()
            if not ln:
                continue
            try:
                j = json.loads(ln)
            except ValueError:
                continue
            j["files"] = sorted({norm_file(f) for f in j.get("files", []) if norm_file(f)})
            j["severity"] = j.get("severity", "minor") if j.get("severity") in SEV else "minor"
            key = (tuple(j["files"]), re.sub(r"\W+", " ", str(j.get("title", ""))).strip().lower()[:60])
            if key in seen:
                seen[key].setdefault("also", []).append(j.get("id", "?"))
                if SEV[j["severity"]] > SEV[seen[key]["severity"]]:
                    seen[key]["severity"] = j["severity"]
                continue
            seen[key] = j
            items.append(j)
    return items


def main():
    a = sys.argv[1:]
    d = a[0]
    n_c = a[1] if len(a) > 1 else "?"
    npk = int(a[a.index("--packages") + 1]) if "--packages" in a else 6
    out = a[a.index("--out") + 1] if "--out" in a else os.path.join(d, "c%s_packages_draft.md" % n_c)
    items = load(d)
    # union-find over files that share a finding (big shared files excluded from linking)
    parent = {}

    def find(x):
        parent.setdefault(x, x)
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(x, y):
        parent[find(x)] = find(y)

    for it in items:
        fs = [f for f in it["files"] if f not in BIG]
        for f in fs:
            find(f)
        for f in fs[1:]:
            union(fs[0], f)
    groups = defaultdict(lambda: {"files": set(), "w": 0, "items": []})
    nofile = []
    for it in items:
        fs = [f for f in it["files"] if f not in BIG]
        if not fs:
            if it["files"]:
                fs = it["files"][:1]  # only big files: anchor on the first, owner fixed later
                find(fs[0])
            else:
                nofile.append(it)
                continue
        g = groups[find(fs[0])]
        g["files"].update(it["files"])
        g["w"] += SEV[it["severity"]]
        g["items"].append(it)
    # balance: biggest groups first into the lightest package
    pk = [{"files": set(), "w": 0, "items": []} for _ in range(npk)]
    for g in sorted(groups.values(), key=lambda g: -g["w"]):
        p = min(pk, key=lambda p: p["w"])
        p["files"] |= g["files"]
        p["w"] += g["w"]
        p["items"] += g["items"]
    # single owner per big shared file: the package with the most weight on it
    owner = {}
    for b in BIG:
        best = max(range(npk), key=lambda i: sum(SEV[x["severity"]] for x in pk[i]["items"] if b in x["files"]))
        if any(b in x["files"] for p in pk for x in p["items"]):
            owner[b] = best
    for i, p in enumerate(pk):
        p["own"] = sorted(f for f in p["files"] if f not in BIG or owner.get(f) == i)
        p["hooks"] = sorted(f for f in p["files"] if f in BIG and owner.get(f) != i)
    # every non-big file in exactly one package (asserted)
    allf = defaultdict(list)
    for i, p in enumerate(pk):
        for f in p["own"]:
            allf[f].append(i)
    clash = {f: v for f, v in allf.items() if len(v) > 1}
    L = ["# CONDUCT %s fix packages (draft from cluster.py: %d findings, %d deduped files)" % (n_c, len(items), len(allf)), ""]
    if clash:
        L.append("WARNING file in more than one package: %s" % clash)
    L.append("Big shared files, one owner each: " + ", ".join("%s -> P%d" % (os.path.basename(b), owner[b] + 1) for b in owner))
    L.append("")
    for i, p in enumerate(pk, 1):
        its = sorted(p["items"], key=lambda x: -SEV[x["severity"]])
        L.append("## P%d (weight %d, %d findings)" % (i, p["w"], len(its)))
        L.append("OWNS: " + ", ".join(p["own"]))
        if p["hooks"]:
            L.append("TINY HOOKS ONLY (owned elsewhere): " + ", ".join(p["hooks"]))
        for x in its:
            extra = "".join([" [also %s]" % ",".join(x["also"]) if x.get("also") else "",
                             " ART: %s" % x["art_needed"] if x.get("art_needed") else "",
                             " AUDIO: %s" % x["audio_needed"] if x.get("audio_needed") else "",
                             " TOM: %s" % x["needs_tom"] if x.get("needs_tom") else ""])
            L.append("- [%s] %s (%s; %s) fix: %s%s" % (x["severity"], x.get("title", ""), x.get("id", "?"),
                     ", ".join(x["files"]), str(x.get("fix", ""))[:220], extra))
        L.append("")
    if nofile:
        L.append("## No files named (assign by hand)")
        for x in nofile:
            L.append("- [%s] %s (%s) fix: %s" % (x["severity"], x.get("title", ""), x.get("id", "?"), str(x.get("fix", ""))[:200]))
    open(out, "w").write("\n".join(L) + "\n")
    print("wrote", out, "-", len(items), "findings,", npk, "packages", "(CLASH)" if clash else "")
    return 1 if clash else 0


if __name__ == "__main__":
    sys.exit(main())
