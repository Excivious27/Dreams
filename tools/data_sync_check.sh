#!/usr/bin/env bash
# Fails when committed data/ differs from what the generators write (c9_17).
# Run on a clean checkout (CI): it rewrites data/ in place.
set -e
cd "$(dirname "$0")/.."
bash tools/regen_data.sh
if ! git diff --quiet -- data scenes; then
  git diff --stat -- data scenes
  echo "data_sync_check: committed data is out of step with the generators: run bash tools/regen_data.sh and commit data/"
  exit 1
fi
echo "data_sync_check: 0 failures"
