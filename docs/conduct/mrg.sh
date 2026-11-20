#!/bin/bash
# mrg.sh branch : merge one fix branch with the standard resolutions; prints LEFT: files needing hand resolution
cd /home/claude/dreams
b=$1
for f in $(git ls-tree -r --name-only $b | grep '\.uid$'); do [ -f "$f" ] && ! git ls-files --error-unmatch "$f" >/dev/null 2>&1 && rm -f "$f"; done
rm -rf tools/conduct/__pycache__
timeout 200 git merge -q --no-edit $b </dev/null >/tmp/mrg_out.txt 2>&1
if grep -q "would be overwritten\|Aborting\|not something we can merge" /tmp/mrg_out.txt; then echo "LEFT: merge refused: $(head -3 /tmp/mrg_out.txt | tr '\n' ' ')"; exit 1; fi
U=$(git diff --name-only --diff-filter=U)
[ -z "$U" ] && { echo "$b merged clean"; exit 0; }
for f in $U; do case $f in *.json) timeout 60 python3 tools/conduct/json_merge.py $f </dev/null >/dev/null;; CLAUDE.md|docs/STATUS.md) python3 /home/claude/wt/resolve_docs.py $f </dev/null;; esac; done
git add $U
L=$( (git diff --name-only --diff-filter=U; grep -l '<<<<<<<' $U </dev/null) | sort -u)
if [ -n "$L" ]; then echo "LEFT: $L"; exit 1; fi
bash -n tools/check.sh || { echo "LEFT: tools/check.sh (syntax)"; exit 1; }
git commit -qm "Merge branch '$b'

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_013g54opDJbSzBZ1hF4NWyGa"
echo "$b merged (auto-resolved)"
