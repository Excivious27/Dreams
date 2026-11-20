#!/usr/bin/env bash
# ci_run.sh <label> [days] [focus]
# Run the full check.sh (6 shards) + 20 bots on GitHub Actions for HEAD, wait for
# the results on branch ci-results/<sha>/, print summary.txt, exit 0 on pass / 1 on fail.
#   - writes ci/params.json in a throwaway commit on top of HEAD (HEAD itself is untouched)
#   - pushes it to ci/<label>-<shortsha> (conduct-ci.yml runs on ci/**), deletes it afterwards
#   - polls `git fetch origin ci-results` every 60 s, 45 min timeout
# Fallbacks: if results never appear on ci-results, tries `gh run view/download`;
# if that fails too, exits 3 so the caller runs check.sh + bots.sh locally.
# Results land in /tmp/ci_<sha>/ (summary.txt, summary.json, logs).
set -uo pipefail
LABEL="${1:-run}"; DAYS="${2:-3}"; FOCUS="${3:-}"
cd "$(git rev-parse --show-toplevel)"
BASE=$(git rev-parse HEAD)
TMP=$(mktemp -d)
git worktree add -q --detach "$TMP" "$BASE" 2>/dev/null || { echo "worktree failed"; exit 3; }
mkdir -p "$TMP/ci"
printf '{"days": %s, "focus": "%s", "base": "%s", "label": "%s"}\n' "$DAYS" "$FOCUS" "$BASE" "$LABEL" > "$TMP/ci/params.json"
(cd "$TMP" && git add ci/params.json && git -c user.name=conduct -c user.email=conduct@local commit -qm "CI params: $LABEL ($DAYS days)")
SHA=$(git -C "$TMP" rev-parse HEAD)
BR="ci/${LABEL}-${BASE:0:8}"
git -C "$TMP" push -q -f origin "HEAD:refs/heads/$BR" 2>&1 | grep -v -i "moved\|new location" || true
git worktree remove --force "$TMP" 2>/dev/null
echo "pushed $BR ($SHA) at $(date +%H:%M:%S); waiting for ci-results/$SHA ..."
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
    python3 tools/conduct/ci_summary.py "$OUT" "$SHA" "$BR" "$RID" >/dev/null && got=gh
  fi
fi
git push -q origin --delete "$BR" 2>/dev/null || true
if [ -z "$got" ]; then
  echo "CI results unavailable after $(( ($(date +%s) - T0) / 60 )) min: run tools/check.sh + tools/bots.sh locally"; exit 3
fi
echo "results via $got after $(( ($(date +%s) - T0) / 60 )) min in $OUT"
cat "$OUT/summary.txt"
python3 -c "import json,sys;sys.exit(0 if json.load(open('$OUT/summary.json'))['pass'] else 1)"
