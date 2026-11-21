#!/usr/bin/env python3
"""ci_summary.py <results dir> <sha> <ref> <run id> [params.json]: write summary.txt + summary.json
from the downloaded shard-*/, bot-*/ and playtest/ artifacts (conduct-ci.yml report job).

params.json (ci/params.json, written by ci_run.sh) says which shards/bots were asked for;
only those count. A bot or the playtest that failed once and passed on its retry is
FLAKY (green, listed in summary.json "flaky"); two failures in a row are red.
The live relay check (relay/relay.json from tools/conduct/relay_live_check.py, when params
"relay") adds "RELAY: ok, Xms" (and "NET E2E: ...") lines; it fails the run only when that
check says so (a server/ change that is live and broken, or never deployed)."""
import glob, json, os, re, sys, time
from collections import Counter

d, sha, ref, run = sys.argv[1:5]
pp = sys.argv[5] if len(sys.argv) > 5 else "ci/params.json"
try:
    params = json.load(open(pp))
except (OSError, ValueError):
    params = {}
want_shards = params.get("shards", [1, 2, 3, 4, 5, 6])
want_bots = list(range(1, 21)) if params.get("bots", True) else []
want_pt = params.get("playtest", True)
flaky = []
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
    if j.get("attempts", 1) > 1 and j["done"] and not j["fails"] and not j["script_errors"]:
        j["flaky"] = True
        flaky.append({"job": "bot%d" % j["bot"], "spec": j.get("spec", ""), "first_rc": j.get("first_rc"),
                      "first": j.get("first_line", "")})
    for m in re.findall(r"(BOT FAIL.{0,140}|BOT WARN.{0,140}|SCRIPT ERROR.{0,140}|paused with nothing on screen.{0,140})", txt):
        errs[re.sub(r"\[\d+ [a-z]+\] ", "", m)[:160]] += 1
    bots.append(j)
pt = {"rc": -1, "secs": 0, "shots": 0, "fails": []}
pj = glob.glob(os.path.join(d, "playtest", "playtest.json"))
if pj:
    pt.update(json.load(open(pj[0])))
    pl = os.path.join(d, "playtest", "playtest.log")
    if os.path.exists(pl):
        pt["fails"] = re.findall(r"(?:FAIL|SCRIPT ERROR).{0,140}", open(pl, errors="replace").read())[:20]
ok_pt = pt["rc"] == 0 or not want_pt
if want_pt and pt["rc"] == 0 and pt.get("attempts", 1) > 1:
    pt["flaky"] = True
    flaky.append({"job": "playtest", "first_rc": pt.get("first_rc"), "first": pt.get("first_fail", "")})
want_relay = bool(params.get("relay", False))
relay = {}
rj = glob.glob(os.path.join(d, "relay", "relay.json"))
if rj:
    try:
        relay = json.load(open(rj[0]))
    except ValueError:
        relay = {"line": "RELAY: result unreadable", "fail": False}
elif want_relay:
    relay = {"line": "RELAY: MISSING (the relay job left no result; not blocking)", "fail": False}
ok_rl = not relay.get("fail", False)
ok_sh = sorted(s["shard"] for s in shards) == sorted(want_shards) and all(s["rc"] == 0 for s in shards)
ok_bt = sorted(b["bot"] for b in bots) == want_bots and all(b["done"] and b["fails"] == 0 and b["script_errors"] == 0 for b in bots)
wall = max([s["secs"] for s in shards] + [b["secs"] for b in bots] + [0])
res = {"sha": sha, "ref": ref, "run": run, "finished": time.time(), "pass": ok_sh and ok_bt and ok_pt and ok_rl, "relay": relay, "relay_pass": ok_rl, "playtest": pt, "playtest_pass": ok_pt,
       "check_pass": ok_sh, "bots_pass": ok_bt, "flaky": flaky, "params": params, "max_job_secs": wall, "shards": shards, "bots": bots,
       "errors": errs.most_common(40), "slowest_steps": sorted(times, key=lambda t: -t["secs"])[:15]}
json.dump(res, open(os.path.join(d, "summary.json"), "w"), indent=1)
L = ["CONDUCT CI %s  %s  (%s, run %s)" % ("PASS" if res["pass"] else "FAIL", sha[:10], ref, run), ""]
if flaky:
    for f in flaky:
        L.insert(1, "FLAKY: passed on retry: %s%s (first try rc=%s%s)" % (f["job"], (" " + f["spec"]) if f.get("spec") else "",
                 f.get("first_rc"), (": " + f["first"][:80]) if f.get("first") else ""))
if len(want_shards) < 6 or not want_bots:
    L.append("subset run: shards %s, bots %s, playtest %s" % (want_shards or "none", "20" if want_bots else "off", "on" if want_pt else "off"))
L.append("check shards (%d/%d):" % (len(shards), len(want_shards)))
for s in shards:
    L.append("  shard %s: %s  %ss%s" % (s["shard"], "PASS" if s["rc"] == 0 else "FAIL", s["secs"],
             ("  failed: " + ", ".join(s["failed_steps"])) if s["failed_steps"] else ""))
if want_bots or bots:
    L.append("bots (%d/%d, finished %d):" % (len(bots), len(want_bots), sum(b["done"] for b in bots)))
for b in bots:
    L.append("  bot%-2s %-36s %s errors=%d fails=%d warns=%d pauses=%d %ss  %s" % (b["bot"], b.get("spec", ""),
             ("FLAKY" if b.get("flaky") else "OK  ") if b["done"] and not b["fails"] and not b["script_errors"] else "FAIL",
             b["script_errors"], b["fails"], b["warns"], b["pauses"], b["secs"], b["line"]))
L.append("playtest: %s  %ss  %s screenshots (results playtest/shots/)" % (
    ("PASS (FLAKY: passed on retry)" if pt.get("flaky") else "PASS") if pt["rc"] == 0 else ("SKIPPED" if not want_pt else ("MISSING" if pt["rc"] == -1 else ("FAIL (twice in a row)" if pt.get("attempts", 1) > 1 else "FAIL"))),
    pt["secs"], pt["shots"]))
for f in pt["fails"]:
    L.append("  " + f)
if relay:
    L.append(relay.get("line", "RELAY: ?"))
    if relay.get("e2e"):
        L.append(relay["e2e"])
    for n in relay.get("notes", []):
        L.append("  relay note: " + n)
L.append("")
L.append("longest job: %ss" % wall)
if res["slowest_steps"]:
    L.append("slowest check steps: " + "; ".join("%s %ss" % (t["name"], t["secs"]) for t in res["slowest_steps"][:8]))
L.append("distinct errors/fails/warns:")
for e, n in res["errors"]:
    L.append("  %3d  %s" % (n, e))
open(os.path.join(d, "summary.txt"), "w").write("\n".join(L) + "\n")
print("summary written:", "PASS" if res["pass"] else "FAIL")
