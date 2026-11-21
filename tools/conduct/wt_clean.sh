#!/usr/bin/env bash
# wt_clean.sh [-n] [branch ...] : free disk at each CONDUCT stage boundary.
#  1. removes worktrees of /home/claude/dreams whose branch is merged into main, or named on the
#     command line (never main, never one a live process has its cwd in, never a dirty one
#     unless named); prunes stale worktree entries; deletes merged local branches it removed.
#  2. removes /tmp dirs older than 2 h (no file inside written in the last 2 h) that no live
#     process uses (/proc/*/cwd and open fds, the lsof check); keeps dot dirs, claude-*,
#     godot.lock*, and systemd/snap dirs.
#  -n  dry run: print what would go.  Prints free disk before/after.
set -uo pipefail
{ # whole body parsed before it runs: editing this file never breaks a run in progress
M=/home/claude/dreams; DRY=0
[ "${1:-}" = "-n" ] && { DRY=1; shift; }
NAMED=" $* "
free_gb() { df -Pk /home/claude | awk 'NR==2{printf "%.1f", $4/1048576}'; }
echo "free before: $(free_gb) GB"
# paths live processes use (cwd + open files), one per line
USED=$(for p in /proc/[0-9]*; do readlink "$p/cwd" 2>/dev/null; ls -l "$p/fd" 2>/dev/null | sed -n 's/.*-> \(\/.*\)/\1/p'; done | sort -u)
in_use() { printf '%s\n' "$USED" | grep -q -F -- "$1/" || printf '%s\n' "$USED" | grep -qx -F -- "$1"; }
go() { if [ "$DRY" = 1 ]; then echo "would remove: $*"; else echo "remove: $*"; fi; }

cd "$M" || exit 1
git worktree prune
MAINSHA=$(git rev-parse main)
git worktree list --porcelain | awk '/^worktree /{w=$2} /^branch /{print w" "$2}' | while read -r w ref; do
  b=${ref#refs/heads/}
  [ "$w" = "$M" ] && continue
  [ "$b" = main ] && continue
  named=0; [[ "$NAMED" == *" $b "* ]] && named=1
  merged=0; git merge-base --is-ancestor "$ref" "$MAINSHA" 2>/dev/null && merged=1
  [ $named = 0 ] && [ $merged = 0 ] && continue
  if in_use "$w"; then echo "keep $w ($b): a live process uses it"; continue; fi
  if [ $named = 0 ] && [ -n "$(git -C "$w" status --porcelain --untracked-files=no 2>/dev/null | head -1)" ]; then
    echo "keep $w ($b): uncommitted changes"; continue
  fi
  go "worktree $w ($b, $([ $merged = 1 ] && echo merged || echo named))"
  if [ "$DRY" = 0 ]; then
    git worktree remove --force "$w" 2>/dev/null || rm -rf "$w"
    [ $merged = 1 ] && git branch -q -d "$b" 2>/dev/null
  fi
done
git worktree prune

# /tmp dirs older than 2 h, unused
for d in /tmp/*/; do
  d=${d%/}; n=$(basename "$d")
  case "$n" in .*|claude-*|godot.lock*|systemd-*|snap*|tmux-*|ssh-*|pulse-*|runtime-*|*compile-cache*|initgoogle*|hsperfdata*) continue ;; esac
  [ -n "$(find "$d" -maxdepth 0 -mmin -120 2>/dev/null)" ] && continue
  [ -n "$(find "$d" -newermt '-120 minutes' -print -quit 2>/dev/null)" ] && continue
  if in_use "$d"; then continue; fi
  # a registered worktree under /tmp (ci_run temp) is removed through git
  if git worktree list --porcelain | grep -qx "worktree $d"; then
    go "tmp worktree $d"; [ "$DRY" = 0 ] && git worktree remove --force "$d" 2>/dev/null
    continue
  fi
  go "$d"; [ "$DRY" = 0 ] && rm -rf "$d"
done
git worktree prune
echo "free after: $(free_gb) GB"
}
