#!/bin/bash
# merge_c.sh branch... : merges, auto-resolves only CLAUDE.md/docs/STATUS.md/HANDOFF conflicts, stops otherwise
cd /home/claude/dreams
resolve() {
  local c=$(git diff --name-only --diff-filter=U)
  local other=$(echo "$c" | grep -v -E '^(CLAUDE.md|docs/STATUS.md|docs/HANDOFF.md)$')
  if [ -n "$other" ]; then echo "STOP manual: $other"; return 1; fi
  python3 /home/claude/wt/resolve_docs.py $c && git add $c && git commit -q --no-edit && echo "resolved docs"
}
if git diff --name-only --diff-filter=U | grep -q .; then resolve || exit 1; fi
for b in "$@"; do
  git checkout -q -- tools/__pycache__/ 2>/dev/null
  echo "== $b"
  if ! git merge -q --no-edit $b >/dev/null 2>&1; then resolve || exit 1; fi
  bash -n tools/check.sh || { echo "check.sh broken after $b"; exit 1; }
done
