#!/usr/bin/env python3
"""relay_live_check.py <out dir> [params.json]: CI's live relay check (conduct-ci.yml "relay" job).

Connects two clients to the live relay (node tools/relay_test.js --live: create a room, join by
code, late-join world, 5 round trips; median latency) and, when params "e2e" is set, runs the
two-instance Godot test tools/net_e2e.sh against it. Writes <out>/relay.json + relay.log for
tools/conduct/ci_summary.py ("RELAY: ok, 81ms" in summary.txt).

Which server is live: GET /version answers {"code": sha1(server.js + package-lock.json)[:12],
"commit": ...}. This checkout's code hash is computed the same way, so no git is needed on the box.

Strict (may fail the run) only when params "server_changed" (this run changes server/):
  - this checkout's server/ is already on origin/main (pushed): wait up to 15 min (WAIT_S) for
    /version to show it (the box pulls every 10 min), then test; not deployed in time = FAIL;
  - not on main yet (pre-push run): the live box can't have it, so the live result is reported
    only (tools/relay_test.js in check.sh tests the new server locally).
Otherwise an outage is reported ("RELAY: DOWN ... not blocking") and never fails the run.
A NET E2E failure fails the run when the relay itself answered and params "e2e_strict" is set
(scripts/net.gd changed, or the new server is the one live).
"""
import hashlib, json, os, subprocess, sys, time, urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LIVE = os.environ.get("RELAY_URL", "wss://dreams-64-23-239-63.sslip.io")
HTTP = LIVE.replace("wss://", "https://").replace("ws://", "http://")
WAIT_S = int(os.environ.get("RELAY_WAIT_S", "900"))
FILES = ("server/server.js", "server/package-lock.json")


def code_of(read):
    h = hashlib.sha1()
    for f in FILES:
        try:
            h.update(read(f))
        except Exception:
            h.update(b"")
    return h.hexdigest()[:12]


def local_code():
    return code_of(lambda f: open(os.path.join(ROOT, f), "rb").read())


def main_code():
    try:
        subprocess.run(["git", "fetch", "-q", "--depth", "1", "origin", "main"], cwd=ROOT, timeout=120, check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        return ""
    return code_of(lambda f: subprocess.run(["git", "show", "FETCH_HEAD:" + f], cwd=ROOT, capture_output=True, check=True).stdout)


def version():
    try:
        with urllib.request.urlopen(HTTP + "/version", timeout=15) as r:
            body = r.read().decode("utf8", "replace")
        try:
            return json.loads(body)
        except ValueError:
            return {"code": "", "commit": "none (server predates /version)", "health": body.strip()[:40]}
    except Exception as e:
        return {"code": "", "commit": "", "error": str(e)[:120]}


def run(cmd, log, timeout):
    t0 = time.time()
    try:
        p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
        out, rc = p.stdout + p.stderr, p.returncode
    except subprocess.TimeoutExpired as e:
        out, rc = (e.stdout or "") if isinstance(e.stdout, str) else "", 124
    log.write("$ %s  (rc=%s, %.0fs)\n%s\n" % (" ".join(cmd), rc, time.time() - t0, out))
    return rc, out


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "relay"
    pp = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "ci", "params.json")
    try:
        params = json.load(open(pp))
    except (OSError, ValueError):
        params = {}
    os.makedirs(out, exist_ok=True)
    log = open(os.path.join(out, "relay.log"), "w")
    res = {"url": LIVE, "strict": bool(params.get("server_changed")), "notes": [], "fail": False}
    loc, mc = local_code(), main_code()
    v = version()
    res.update(local_code=loc, main_code=mc, live_before=v)
    log.write("local server/ code %s, origin/main %s, live %s\n" % (loc, mc or "?", json.dumps(v)))
    has_version = '"/version"' in open(os.path.join(ROOT, "server/server.js")).read()
    if res["strict"]:
        if mc == loc and v.get("code") != loc and has_version:
            res["notes"].append("waited for the deploy")
            t0 = time.time()
            while time.time() - t0 < WAIT_S and v.get("code") != loc:
                time.sleep(30)
                v = version()
            res["waited_s"] = int(time.time() - t0)
            if v.get("code") != loc:
                res["fail"] = True
                res["notes"].append("server/ %s not live after %d min (live code %s): check the box's update timer" % (loc, WAIT_S // 60, v.get("code") or "none"))
        elif mc != loc:
            res["strict"] = False
            res["notes"].append("server/ change not on main yet: live result is the current server's (relay_test.js tests the new one)")
    res["live"] = v
    res["deployed"] = v.get("code") == loc
    rc, txt = run(["node", "tools/relay_test.js", "--url", LIVE], log, 120)
    line = [l for l in txt.splitlines() if l.startswith("RELAY LIVE:")]
    ms = None
    if rc == 0 and line and "ok," in line[0]:
        try:
            ms = int(line[0].split("ok,")[1].strip().rstrip("ms"))
        except ValueError:
            ms = -1
    res["ms"] = ms
    res["live_ok"] = ms is not None
    if not res["live_ok"] and res["strict"] and res["deployed"]:
        res["fail"] = True
    if params.get("e2e"):
        rc2, txt2 = run(["bash", "tools/net_e2e.sh", LIVE], log, 420)
        l2 = [l for l in txt2.splitlines() if l.startswith("NET E2E:")]
        res["e2e"] = l2[-1] if l2 else "NET E2E: FAIL (no result, rc=%s)" % rc2
        res["e2e_ok"] = rc2 == 0
        if not res["e2e_ok"] and res["live_ok"] and (params.get("e2e_strict") or (res["strict"] and res["deployed"])):
            res["fail"] = True
    if res["live_ok"]:
        res["line"] = "RELAY: ok, %dms (live code %s%s)" % (ms, v.get("code") or "pre-/version", ", this server/" if res["deployed"] else "")
    else:
        why = (line[0] if line else ((txt.strip().splitlines() or ["no output"])[-1]))[:100]
        tag = "RELAY: FAIL" if res["fail"] else "RELAY: DOWN (not blocking: %s)" % ("server/ unchanged" if not params.get("server_changed") else "new server not live yet")
        res["line"] = "%s (%s)" % (tag, why)
    if res["fail"] and res["live_ok"]:
        res["line"] = "RELAY: FAIL, %dms (%s)" % (ms, "; ".join(res["notes"]) or res.get("e2e", ""))
    json.dump(res, open(os.path.join(out, "relay.json"), "w"), indent=1)
    print(res["line"])
    if "e2e" in res:
        print(res["e2e"])
    for n in res["notes"]:
        print("  note: " + n)
    return 1 if res["fail"] else 0


if __name__ == "__main__":
    sys.exit(main())
