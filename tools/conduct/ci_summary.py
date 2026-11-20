#!/usr/bin/env python3
"""ci_summary.py <results dir> <sha> <ref> <run id>: write summary.txt + summary.json
from the downloaded shard-*/ and bot-*/ artifacts (conduct-ci.yml report job)."""
import glob, json, os, re, sys, time
from collections import Counter

d, sha, ref, run = sys.argv[1:5]
shards, bots, errs, times = [], [], Counter(), []
for f in sorted(glob.glob(os.path.join(d, "shard-*", "shard_*.json"))):
    j = json.load(open(f))
    log = f.replace(".json", ".log")
    txt = open(log, errors="replace").read() if os.path.exists(log) else ""
    j["failed_steps"] = re.findall(r"#### step \d+ (.*?): FAIL", txt)
    for m in re.findall(r"^\s*(?:FAIL|SCRIPT ERROR).{0,160}", txt, re.M):
        errs[m.strip()[:160]] += 1
    shards.append(j)
for f in sorted(glob.glob(os.path.join(d, "shard-*", "times_*.jsonl"))):
    for ln in open(f):
        try:
            times.append(json.loads(ln))
        except ValueError:
            pass
for f in sorted(glob.glob(os.path.join(d, "bot-*", "bot*.json")), key=lambda p: int(re.findall(r"bot(\d+)\.json", p)[0])):
    j = json.load(open(f))
    log = f.replace(".json", ".log")
    txt = open(log, errors="replace").read() if os.path.exists(log) else ""
    j["done"] = bool(re.search(r"BOT %d done" % j["bot"], txt))
    j["script_errors"] = txt.count("SCRIPT ERROR")
    j["fails"] = txt.count("BOT FAIL")
    j["warns"] = txt.count("BOT WARN")
    j["pauses"] = txt.count("paused with nothing on screen")
    m = re.search(r"BOT \d+ done: (.*)", txt)
    j["line"] = (m.group(1)[:90] if m else "DID NOT FINISH")
    for m in re.findall(r"(BOT FAIL.{0,140}|BOT WARN.{0,140}|SCRIPT ERROR.{0,140}|paused with nothing on screen.{0,140})", txt):
        errs[re.sub(r"\[\d+ [a-z]+\] ", "", m)[:160]] += 1
    bots.append(j)
ok_sh = len(shards) == 6 and all(s["rc"] == 0 for s in shards)
ok_bt = len(bots) == 20 and all(b["done"] and b["fails"] == 0 and b["script_errors"] == 0 for b in bots)
wall = max([s["secs"] for s in shards] + [b["secs"] for b in bots] + [0])
res = {"sha": sha, "ref": ref, "run": run, "finished": time.time(), "pass": ok_sh and ok_bt,
       "check_pass": ok_sh, "bots_pass": ok_bt, "max_job_secs": wall, "shards": shards, "bots": bots,
       "errors": errs.most_common(40), "slowest_steps": sorted(times, key=lambda t: -t["secs"])[:15]}
json.dump(res, open(os.path.join(d, "summary.json"), "w"), indent=1)
L = ["CONDUCT CI %s  %s  (%s, run %s)" % ("PASS" if res["pass"] else "FAIL", sha[:10], ref, run), ""]
L.append("check shards (%d/6):" % len(shards))
for s in shards:
    L.append("  shard %s: %s  %ss%s" % (s["shard"], "PASS" if s["rc"] == 0 else "FAIL", s["secs"],
             ("  failed: " + ", ".join(s["failed_steps"])) if s["failed_steps"] else ""))
L.append("bots (%d/20, finished %d):" % (len(bots), sum(b["done"] for b in bots)))
for b in bots:
    L.append("  bot%-2s %-36s %s errors=%d fails=%d warns=%d pauses=%d %ss  %s" % (b["bot"], b.get("spec", ""),
             "OK  " if b["done"] and not b["fails"] and not b["script_errors"] else "FAIL",
             b["script_errors"], b["fails"], b["warns"], b["pauses"], b["secs"], b["line"]))
L.append("")
L.append("longest job: %ss" % wall)
if res["slowest_steps"]:
    L.append("slowest check steps: " + "; ".join("%s %ss" % (t["name"], t["secs"]) for t in res["slowest_steps"][:8]))
L.append("distinct errors/fails/warns:")
for e, n in res["errors"]:
    L.append("  %3d  %s" % (n, e))
open(os.path.join(d, "summary.txt"), "w").write("\n".join(L) + "\n")
print("summary written:", "PASS" if res["pass"] else "FAIL")
