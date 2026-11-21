#!/usr/bin/env bash
# shots_sweep.sh <N> [sections] : CONDUCT shared shots, run ONCE at audit start.
# One godot session per arc (tools/conduct/shots_sweep.gd at 540x960, both under glock.sh,
# in parallel when both lock slots are free) -> /home/claude/wt/shots_<N>/<arc>/<name>.png
# + /home/claude/wt/shots_<N>/index.md (every shot: arc, section, what it shows).
# Covers: every scene and interior, title pages + achievements + Play together, game menu
# tabs (Party/Animals/Chores, Book, Options, Keys...), chest, craft, decor catalogue, prizes,
# campaign map, arcade, shops + animal counters, a dialogue sample per NPC, the four festival
# days on the plaza, night looks, the training-drill brief and first step.
# sections: comma list of title,maps,interiors,screens,shops,npcs,festival,night,battle (default all)
# Env: SWEEP_MAPS=a,b (only these maps), SWEEP_ARCS="penguins gangsters", SWEEP_T=900 (s per arc).
set -uo pipefail
{ # whole body parsed before it runs: editing this file never breaks a run in progress
N="${1:?usage: shots_sweep.sh <N> [sections]}"; SECS="${2:-all}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT=/home/claude/wt/shots_$N
ARCS="${SWEEP_ARCS:-penguins gangsters}"
mkdir -p "$OUT"
T0=$(date +%s)
pids=()
for a in $ARCS; do
  rm -rf "$OUT/$a"; mkdir -p "$OUT/$a"
  ( cd "$ROOT" && bash tools/conduct/glock.sh -x -t "${SWEEP_T:-900}" -n 10 -- \
      godot --path . --rendering-driver opengl3 --resolution 540x960 \
      -s res://tools/conduct/shots_sweep.gd -- "$OUT/$a" "$a" "$SECS" ) > "$OUT/$a.log" 2>&1 &
  pids+=($!)
  sleep 3   # let the first session take its slot first
done
rc=0
for p in "${pids[@]}"; do wait "$p" || rc=1; done
WALL=$(( $(date +%s) - T0 ))
python3 - "$OUT" "$WALL" $ARCS <<'PY'
import sys, os
out, wall, arcs = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
L = ["# Shared shots sweep (%s)" % os.path.basename(out), "",
     "Wall time %d min %02d s. View PNGs with the Read tool; paths are <arc>/<name>.png." % (wall // 60, wall % 60), ""]
for a in arcs:
    rows = []
    p = os.path.join(out, a, "index.tsv")
    if os.path.exists(p):
        rows = [l.rstrip("\n").split("\t") for l in open(p) if l.strip()]
    L.append("## %s (%d shots)" % (a, len(rows)))
    sec = None
    for r in rows:
        if len(r) < 3: continue
        if r[1] != sec:
            sec = r[1]; L.append(""); L.append("### " + sec)
        L.append("- `%s/%s.png` %s" % (a, r[0], r[2]))
    L.append("")
open(os.path.join(out, "index.md"), "w").write("\n".join(L) + "\n")
print("index:", os.path.join(out, "index.md"))
PY
for a in $ARCS; do grep -h "^shots_sweep" "$OUT/$a.log" || echo "$a: no finish line (see $OUT/$a.log)"; done
echo "shots_sweep: wall ${WALL}s"
exit $rc
}
