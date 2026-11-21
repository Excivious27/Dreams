#!/usr/bin/env bash
# wip_push.sh [message] : fix agents call this every ~20 min (R4 restart resilience).
# Commits everything in the current worktree as "WIP <branch> HH:MM: <message>" (skipped when
# nothing changed) and pushes the branch to origin/<branch>, so a server restart loses little and
# ci_run --branch sees the head. Refuses on main/detached HEAD. Never merges, never force-pushes.
set -uo pipefail
{ # whole body parsed before it runs: editing this file never breaks a run in progress
cd "$(git rev-parse --show-toplevel)" || exit 1
B=$(git rev-parse --abbrev-ref HEAD)
case "$B" in main|HEAD) echo "wip_push: refusing on '$B' (work on your own branch)"; exit 2 ;; esac
rm -rf tools/conduct/__pycache__
git add -A
if ! git diff --cached --quiet; then
  git commit -q --no-verify -m "WIP $B $(TZ=America/Los_Angeles date +%H:%M): ${1:-checkpoint}

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" || { echo "wip_push: commit failed"; exit 1; }
fi
if git push -q origin "HEAD:refs/heads/$B" 2>&1 | grep -v "^remote:"; then :; fi
L=$(git rev-parse HEAD); R=$(git ls-remote origin "refs/heads/$B" | cut -c1-40)
if [ "$L" = "$R" ]; then echo "wip_push: $B @ ${L:0:10} pushed"; else echo "wip_push: push of $B failed (local ${L:0:10}, remote ${R:0:10})"; exit 1; fi
}
