#!/usr/bin/env bash
# stage_godotsteam.sh: copy steam/godotsteam into addons/godotsteam for a DESKTOP
# export only (CI steam-builds job, or a local desktop test). Never commit
# addons/godotsteam (.gitignore) and never run this before a Web export.
#   bash tools/stage_godotsteam.sh          # stage
#   bash tools/stage_godotsteam.sh --clean  # remove addons/godotsteam again
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ "${1:-}" = "--clean" ]; then rm -rf "$ROOT/addons/godotsteam"; rmdir "$ROOT/addons" 2>/dev/null || true; exit 0; fi
bash "$ROOT/tools/fetch_godotsteam.sh" --check
mkdir -p "$ROOT/addons/godotsteam"
cp -r "$ROOT/steam/godotsteam/." "$ROOT/addons/godotsteam/"
rm -f "$ROOT/addons/godotsteam/SHA256SUMS"
echo "godotsteam staged in addons/godotsteam"
