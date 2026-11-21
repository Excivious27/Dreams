#!/usr/bin/env bash
# ci_run.sh <label> [days] [focus] [--shards 1,3] [--no-bots] [--playtest-only] [--branch <b>] [--relay|--no-relay]
# Run check.sh (6 shards) + 20 bots + the scripted playtest on GitHub Actions for HEAD,
# wait for the results on branch ci-results/<sha>/, print summary.txt, exit 0 on pass / 1 on fail.
#   --shards 1,3     only these check shards (+ the playtest; bots off). Fix agents' pre-merge
#                    runs: at most 3 jobs, e.g. --shards "$(python3 tools/conduct/check_shard.py --for-files a.gd b.py)"
#   --no-bots        skip the 20 bots
#   --playtest-only  only the playtest (plus --shards if given)
#   --branch <b>     test origin/<b> merged onto current origin/main (temp worktree) instead of HEAD
#   --relay / --no-relay  force the live relay check on/off. Default: on for full runs (bots on,
#                    i.e. post-merge) and whenever the diff vs origin/main touches server/,
#                    scripts/net.gd or the relay tests; the Godot NET E2E runs when net.gd or
#                    server/ changed (tools/conduct/relay_live_check.py)
#   - writes ci/params.json in a throwaway commit on top of the base (HEAD itself is untouched)
#   - pushes it to ci/<label>-<shortsha> (conduct-ci.yml runs on ci/**), deletes it afterwards
#   - polls `git fetch origin ci-results` every 60 s, 45 min timeout
# Fallbacks: if results never appear on ci-results, tries `gh run view/download`;
# if that fails too, exits 3 so the caller runs check.sh + bots.sh locally.
# Results land in /tmp/ci_<sha>/ (summary.txt, summary.json, logs).
set -uo pipefail
POS=(); SHARDS=""; BOTS=1; PTONLY=0; BRANCH=""; RELAY=auto
while [ $# -gt 0 ]; do
  case "$1" in
    --shards) SHARDS="$2"; shift 2 ;;
    --shards=*) SHARDS="${1#*=}"; shift ;;
    --no-bots) BOTS=0; shift ;;
    --playtest-only) PTONLY=1; shift ;;
    --relay) RELAY=1; shift ;;
    --no-relay) RELAY=0; shift ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --branch=*) BRANCH="${1#*=}"; shift ;;
    -*) echo "unknown option $1"; exit 2 ;;
    *) POS+=("$1"); shift ;;
  esac
done
LABEL="${POS[0]:-run}"; DAYS="${POS[1]:-3}"; FOCUS="${POS[2]:-}"
# shard list -> JSON array; "all" = 1..6
if [ -n "$SHARDS" ]; then
  SHARDS=$(echo "$SHARDS" | tr -c '0-9,\n' ',' | tr -s ',' | sed 's/^,//; s/,$//')
  [ -n "$SHARDS" ] || { echo "--shards needs numbers 1-6"; exit 2; }
  SJSON="[$SHARDS]"; BOTS=0
elif [ "$PTONLY" = 1 ]; then SJSON="[]"
else SJSON="[1,2,3,4,5,6]"; fi
[ "$PTONLY" = 1 ] && BOTS=0
NJOBS=$(( $(python3 -c "import json;print(len(json.loads('$SJSON')))") + 1 + BOTS * 20 ))
if [ "$BOTS" = 0 ] && [ "$NJOBS" -gt 3 ]; then
  echo "note: $NJOBS jobs (pre-merge runs should stay at 3: pick at most 2 shards)"
fi
cd "$(git rev-parse --show-toplevel)"
TMP=$(mktemp -d)
if [ -n "$BRANCH" ]; then
  git fetch -q origin main "$BRANCH" || { echo "fetch of main/$BRANCH failed"; exit 3; }
  MAIN=$(git rev-parse origin/main)
  git worktree add -q --detach "$TMP" "$MAIN" 2>/dev/null || { echo "worktree failed"; exit 3; }
  if ! git -C "$TMP" -c user.name=conduct -c user.email=conduct@local merge -q --no-edit "origin/$BRANCH" >/dev/null 2>&1; then
    echo "origin/$BRANCH does not merge cleanly onto origin/main:"; git -C "$TMP" diff --name-only --diff-filter=U | sed 's/^/  /'
    git worktree remove --force "$TMP"; exit 2
  fi
  BASE=$(git -C "$TMP" rev-parse HEAD)
else
  BASE=$(git rev-parse HEAD)
  git worktree add -q --detach "$TMP" "$BASE" 2>/dev/null || { echo "worktree failed"; exit 3; }
fi
mkdir -p "$TMP/ci"
# Live relay check: what changed against origin/main decides it (relay_live_check.py).
git fetch -q origin main 2>/dev/null || true
CHANGED=$(git diff --name-only "$(git rev-parse origin/main 2>/dev/null || echo "$BASE")" "$BASE" 2>/dev/null)
SRV=0; NETC=0; RTOOLS=0
echo "$CHANGED" | grep -q '^server/' && SRV=1
echo "$CHANGED" | grep -qE '^scripts/net(_api|_transport[a-z_]*|_relay_room)?\.gd$' && NETC=1
echo "$CHANGED" | grep -qE '^tools/(relay_test\.js|net_e2e|conduct/relay_live_check\.py)' && RTOOLS=1
if [ "$RELAY" = auto ]; then RELAY=0; { [ "$BOTS" = 1 ] || [ $SRV = 1 ] || [ $NETC = 1 ] || [ $RTOOLS = 1 ]; } && RELAY=1; fi
E2E=0; { [ $SRV = 1 ] || [ $NETC = 1 ] || [ $RTOOLS = 1 ]; } && E2E=$RELAY
python3 - "$TMP/ci/params.json" <<PY
import json, sys
json.dump({"days": int("$DAYS"), "focus": "$FOCUS", "base": "$BASE", "label": "$LABEL", "branch": "$BRANCH",
           "shards": json.loads("$SJSON"), "bots": bool($BOTS), "playtest": True,
           "relay": bool($RELAY), "server_changed": bool($SRV), "e2e": bool($E2E), "e2e_strict": bool($NETC)}, open(sys.argv[1], "w"))
PY
(cd "$TMP" && git add ci/params.json && git -c user.name=conduct -c user.email=conduct@local commit -qm "CI params: $LABEL ($DAYS days, shards $SJSON, bots $BOTS)")
SHA=$(git -C "$TMP" rev-parse HEAD)
BR="ci/${LABEL}-${BASE:0:8}"
git -C "$TMP" push -q -f origin "HEAD:refs/heads/$BR" 2>&1 | grep -v -i "moved\|new location" || true
git worktree remove --force "$TMP" 2>/dev/null
echo "pushed $BR ($SHA; shards $SJSON, bots $BOTS, playtest 1, relay $RELAY e2e $E2E) at $(date +%H:%M:%S); waiting for ci-results/$SHA ..."
OUT="/tmp/ci_$SHA"; rm -rf "$OUT"; mkdir -p "$OUT"
T0=$(date +%s); got=""
while [ $(( $(date +%s) - T0 )) -lt 2700 ]; do
  sleep 60
  if git fetch -q origin ci-results 2>/dev/null && git cat-file -e "FETCH_HEAD:$SHA/summary.txt" 2>/dev/null; then
    got=branch; break
  fi
  printf "."
done
echo
if [ "$got" = branch ]; then
  git archive FETCH_HEAD "$SHA" | tar -x -C "$OUT" --strip-components=1
elif command -v gh >/dev/null; then
  echo "no results on ci-results; trying gh run download"
  RID=$(gh run list --branch "$BR" --json databaseId -q '.[0].databaseId' 2>/dev/null)
  if [ -n "$RID" ] && gh run download "$RID" -D "$OUT" 2>/dev/null; then
    git show "$SHA:ci/params.json" > "$OUT/params.json" 2>/dev/null
    python3 tools/conduct/ci_summary.py "$OUT" "$SHA" "$BR" "$RID" "$OUT/params.json" >/dev/null && got=gh
  fi
fi
git push -q origin --delete "$BR" 2>/dev/null || true
if [ -z "$got" ]; then
  echo "CI results unavailable after $(( ($(date +%s) - T0) / 60 )) min: run tools/check.sh + tools/bots.sh locally"; exit 3
fi
echo "results via $got after $(( ($(date +%s) - T0) / 60 )) min in $OUT"
cat "$OUT/summary.txt"
python3 -c "import json,sys;sys.exit(0 if json.load(open('$OUT/summary.json'))['pass'] else 1)"
