#!/usr/bin/env bash
# ci_run.sh <label> [days] [focus] [--shards 1,3] [--bots] [--bots-only] [--no-bots] [--playtest-only] [--branch <b>] [--relay|--no-relay]
# Run check.sh (6 shards) + 20 bots + the scripted playtest on GitHub Actions for HEAD,
# wait for the results on branch ci-results/<sha>/, print summary.txt, exit 0 on pass / 1 on fail.
#   --shards 1,3     only these check shards (+ the playtest; bots off unless --bots). Fix agents' pre-merge
#                    runs: e.g. --shards "$(python3 tools/conduct/check_shard.py --for-files a.gd b.py | tr ' ' ,)"
#   --bots           keep the 20 bots on with --shards (R4: required pre-merge for any fix branch that
#                    touches scripts/*.gd UI/menu/screen/map code)
#   --bots-only      only the 20 bots (no check shards, no playtest)
#   --no-bots        skip the 20 bots
#   --playtest-only  only the playtest (plus --shards if given)
#   --branch <b>     test origin/<b> merged onto current origin/main (temp worktree) instead of HEAD.
#                    Always refetches +refs/heads/<b> and main (deepening main in a shallow clone) and
#                    REFUSES (exit 2) when a local branch <b> exists and its head != origin/<b>: push first.
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
POS=(); SHARDS=""; BOTS=1; PTONLY=0; BRANCH=""; RELAY=auto; KEEPBOTS=0; BOTSONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --shards) SHARDS="$2"; shift 2 ;;
    --shards=*) SHARDS="${1#*=}"; shift ;;
    --no-bots) BOTS=0; shift ;;
    --bots) KEEPBOTS=1; shift ;;
    --bots-only) BOTSONLY=1; shift ;;
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
  SJSON="[$SHARDS]"; [ "$KEEPBOTS" = 1 ] || BOTS=0
elif [ "$PTONLY" = 1 ] || [ "$BOTSONLY" = 1 ]; then SJSON="[]"
else SJSON="[1,2,3,4,5,6]"; fi
[ "$PTONLY" = 1 ] && BOTS=0
PT=1
if [ "$BOTSONLY" = 1 ]; then BOTS=1; PT=0; SJSON="[]"; fi
NJOBS=$(( $(python3 -c "import json;print(len(json.loads('$SJSON')))") + PT + BOTS * 20 ))
if [ "$BOTS" = 0 ] && [ "$NJOBS" -gt 3 ] && [ -n "$SHARDS" ]; then
  echo "note: $NJOBS jobs (pre-merge runs should stay at 3: pick at most 2 shards)"
fi
cd "$(git rev-parse --show-toplevel)"
# Fresh refs (R4): explicit refspecs so origin/<b> is never stale; deepen main in a shallow clone.
DEEP=""; [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = true ] && DEEP="--deepen=300"
git fetch -q $DEEP origin "+refs/heads/main:refs/remotes/origin/main" || { echo "fetch of main failed"; exit 3; }
TMP=$(mktemp -d)
if [ -n "$BRANCH" ]; then
  git fetch -q origin "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH" || { echo "fetch of $BRANCH failed (pushed?)"; rm -rf "$TMP"; exit 3; }
  RHEAD=$(git rev-parse "refs/remotes/origin/$BRANCH")
  if git show-ref -q --verify "refs/heads/$BRANCH"; then
    LHEAD=$(git rev-parse "refs/heads/$BRANCH")
    if [ "$LHEAD" != "$RHEAD" ]; then
      echo "REFUSED: local $BRANCH is ${LHEAD:0:10} but origin/$BRANCH is ${RHEAD:0:10}: commit and push first (git push origin $BRANCH)"
      rm -rf "$TMP"; exit 2
    fi
  fi
  MAIN=$(git rev-parse origin/main)
  echo "testing $BRANCH@${RHEAD:0:10} merged onto main@${MAIN:0:10}"
  # R4: merge in the object store (git merge-tree), no checkout: a temp worktree cost ~2 GB of disk.
  MT=$(git merge-tree --write-tree --name-only "$MAIN" "refs/remotes/origin/$BRANCH" 2>/dev/null); MRC=$?
  if [ $MRC -ne 0 ]; then
    echo "origin/$BRANCH does not merge cleanly onto origin/main:"; echo "$MT" | sed -n '2,/^$/p' | grep -v '^$' | sed 's/^/  /'
    rm -rf "$TMP"; exit 2
  fi
  MTREE=$(echo "$MT" | head -1)
  BASE=$(git -c user.name=conduct -c user.email=conduct@local commit-tree "$MTREE" -p "$MAIN" -p "$RHEAD" -m "Merge origin/$BRANCH onto main (ci_run)")
else
  BASE=$(git rev-parse HEAD)
  echo "testing HEAD ${BASE:0:10} ($(git rev-parse --abbrev-ref HEAD))"
fi
# Live relay check: what changed against origin/main decides it (relay_live_check.py).
CHANGED=$(git diff --name-only "$(git rev-parse origin/main 2>/dev/null || echo "$BASE")" "$BASE" 2>/dev/null)
SRV=0; NETC=0; RTOOLS=0
echo "$CHANGED" | grep -q '^server/' && SRV=1
echo "$CHANGED" | grep -qE '^scripts/net(_api|_transport[a-z_]*|_relay_room)?\.gd$' && NETC=1
echo "$CHANGED" | grep -qE '^tools/(relay_test\.js|net_e2e|conduct/relay_live_check\.py)' && RTOOLS=1
if [ "$RELAY" = auto ]; then RELAY=0; { [ "$BOTS" = 1 ] || [ $SRV = 1 ] || [ $NETC = 1 ] || [ $RTOOLS = 1 ]; } && RELAY=1; fi
E2E=0; { [ $SRV = 1 ] || [ $NETC = 1 ] || [ $RTOOLS = 1 ]; } && E2E=$RELAY
python3 - "$TMP/params.json" <<PY
import json, sys
json.dump({"days": int("$DAYS"), "focus": "$FOCUS", "base": "$BASE", "label": "$LABEL", "branch": "$BRANCH",
           "shards": json.loads("$SJSON"), "bots": bool($BOTS), "playtest": bool($PT),
           "relay": bool($RELAY), "server_changed": bool($SRV), "e2e": bool($E2E), "e2e_strict": bool($NETC)}, open(sys.argv[1], "w"))
PY
# params commit on top of BASE, built with a private index (no checkout, no disk).
export GIT_INDEX_FILE="$TMP/index"
git read-tree "$BASE^{tree}"
git update-index --add --cacheinfo "100644,$(git hash-object -w "$TMP/params.json"),ci/params.json"
PTREE=$(git write-tree); unset GIT_INDEX_FILE
SHA=$(git -c user.name=conduct -c user.email=conduct@local commit-tree "$PTREE" -p "$BASE" -m "CI params: $LABEL ($DAYS days, shards $SJSON, bots $BOTS, playtest $PT)")
BR="ci/${LABEL}-${BASE:0:8}"
git push -q -f origin "$SHA:refs/heads/$BR" 2>&1 | grep -v -i "moved\|new location\|^remote:" || true
rm -rf "$TMP"
echo "pushed $BR ($SHA; tested sha ${BASE}; shards $SJSON, bots $BOTS, playtest $PT, relay $RELAY e2e $E2E) at $(date +%H:%M:%S); waiting for ci-results/$SHA ..."
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
echo "results via $got after $(( ($(date +%s) - T0) / 60 )) min in $OUT (tested sha $BASE)"
cat "$OUT/summary.txt"
python3 -c "import json,sys;sys.exit(0 if json.load(open('$OUT/summary.json'))['pass'] else 1)"
