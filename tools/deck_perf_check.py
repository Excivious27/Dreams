#!/usr/bin/env python3
"""S1 P4 (09-06): Steam Deck performance guard. Runs tools/perf_probe.gd in the
Deck view (WIDE=1, 1280x800, opengl3 under xvfb) on both arcs and fails when a
map passes a threshold below. Frame ms on a CI runner is software rendering
(llvmpipe) and says little about the Deck's GPU, so the probe runs twice per arc:
--headless (no renderer: frame ms = the game's own CPU time per frame -> cpu_med/p95;
the Deck's Zen 2 cores are in the same class as a CI runner core) and under xvfb with
opengl3 (draw calls, texture memory, load/cover times).
Target: 60 fps at 1280x800 (Deck native); Valve's Verified floor is 30 fps at 800p
(https://partner.steamgames.com/doc/steamdeck/compat). 8 ms CPU p95 = half a 60 fps frame.
Usage: python3 tools/deck_perf_check.py [--quick] [--json out.json]
Prints a table and "DECK PERF: ok" or "DECK PERF: FAIL ..." (exit 1). Needs godot + xvfb-run.
Not in check.sh (several minutes): CI's conduct job / by hand.
"""
import json
import os
import subprocess
import sys
import tempfile

# --- thresholds -------------------------------------------------------------
CPU_P95_MS = 12.0          # headless frame p95 (measured 7-12 ms on the 2-core sandbox)
DRAWS = 600
LOAD_MS = 2000.0
LOAD_FRAME_MS = 900.0      # longest load frame after the first: the farm bake (420-640 ms on llvmpipe), hidden by the arrival cover
COVER_MS = 2500.0          # arrival cover lift (farm 1.4-1.7 s on the 2-core sandbox, software GL)
TEX_MB = 256.0
MEM_MB = 600.0
# ---------------------------------------------------------------------------
SCENES = {
    "penguins": ["title", "farm", "town", "meadow", "mine", "gilt_grand_plaza", "bf_neon_block", "community_farm"],
    "gangsters": ["farm", "town", "mine", "iron_junction"],
}
QUICK = {"penguins": ["farm", "town"], "gangsters": ["farm"]}
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def probe(arc, scenes, godot, headless):
    env = dict(os.environ, WIDE="1", MACHINE="1", ARC=arc, FRAMES=os.environ.get("FRAMES", "120"),
               XDG_DATA_HOME=tempfile.mkdtemp(prefix="deckperf_"))
    if headless:
        cmd = [godot, "--headless", "--path", ROOT, "-s", "res://tools/perf_probe.gd", "--"] + scenes
    else:
        cmd = ["xvfb-run", "-a", "-s", "-screen 0 1280x800x24", godot, "--path", ROOT, "--rendering-driver", "opengl3",
               "--resolution", "1280x800", "-s", "res://tools/perf_probe.gd", "--"] + scenes
    return subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=1500).stdout


def run(arc, scenes, godot):
    cpu = {}
    for line in probe(arc, scenes, godot, True).splitlines():
        if line.startswith("PERF_JSON "):
            r = json.loads(line[len("PERF_JSON "):])
            cpu[r["scene"]] = (r["frame_med"], r["frame_p95"])
    out = probe(arc, scenes, godot, False)
    rows = []
    for line in out.splitlines():
        if line.startswith("PERF_JSON "):
            r = json.loads(line[len("PERF_JSON "):])
            r["cpu_med"], r["cpu_p95"] = cpu.get(r["scene"], (-1.0, 99.0))
            rows.append(r)
    if len(rows) != len(scenes):
        print(out[-3000:])
    return rows


def judge(r):
    bad = []
    if r["scene"] != "title" and r["cpu_p95"] > CPU_P95_MS:
        bad.append("cpu_p95 %.1f > %.0f ms" % (r["cpu_p95"], CPU_P95_MS))
    if r["draws"] > DRAWS:
        bad.append("draws %d > %d" % (r["draws"], DRAWS))
    if r["load_ms"] > LOAD_MS:
        bad.append("load %.0f > %.0f ms" % (r["load_ms"], LOAD_MS))
    if r["load_frame_max_ms"] > LOAD_FRAME_MS:
        bad.append("load frame %.0f > %.0f ms" % (r["load_frame_max_ms"], LOAD_FRAME_MS))
    if r["cover_ms"] > COVER_MS:
        bad.append("cover %.0f > %.0f ms" % (r["cover_ms"], COVER_MS))
    if r["tex_mb"] > TEX_MB:
        bad.append("tex %.0f > %.0f MB" % (r["tex_mb"], TEX_MB))
    if r["mem_mb"] > MEM_MB:
        bad.append("mem %.0f > %.0f MB" % (r["mem_mb"], MEM_MB))
    return bad


def main():
    godot = os.environ.get("GODOT", "godot")
    sets = QUICK if "--quick" in sys.argv else SCENES
    rows, fails, missing = [], [], []
    for arc, scenes in sets.items():
        got = run(arc, scenes, godot)
        seen = {r["scene"] for r in got}
        missing += ["%s/%s" % (arc, s) for s in scenes if s not in seen]
        rows += got
    print("%-10s %-20s %7s %8s %8s %8s %8s %6s %6s %6s  %s" % ("arc", "scene", "load", "ldframe", "cover", "cpu_med", "cpu_p95", "draws", "texMB", "memMB", "verdict"))
    for r in rows:
        bad = judge(r)
        if bad:
            fails.append("%s/%s: %s" % (r["arc"], r["scene"], "; ".join(bad)))
        print("%-10s %-20s %7.0f %8.0f %8.0f %8.2f %8.2f %6d %6.0f %6.0f  %s" % (r["arc"], r["scene"], r["load_ms"], r["load_frame_max_ms"], r["cover_ms"], r["cpu_med"], r["cpu_p95"], r["draws"], r["tex_mb"], r["mem_mb"], "ok" if not bad else "FAIL"))
    if "--json" in sys.argv:
        with open(sys.argv[sys.argv.index("--json") + 1], "w") as f:
            json.dump(rows, f, indent=1)
    fails += ["%s: no PERF_JSON line (probe crashed?)" % m for m in missing]
    if fails:
        print("DECK PERF: FAIL " + " | ".join(fails))
        return 1
    print("DECK PERF: ok (%d maps, both arcs, 1280x800)" % len(rows))
    return 0


if __name__ == "__main__":
    sys.exit(main())
