#!/usr/bin/env bash
# fetch_godotsteam.sh: download the pinned GodotSteam GDExtension (MIT, Codeberg),
# verify its sha256 and keep ONLY the desktop x86_64 libraries in steam/godotsteam/
# (a .gdignore'd folder: the editor, tools/check.sh and the Web export never see it).
# Desktop builds copy it into addons/godotsteam with tools/stage_godotsteam.sh first.
#   bash tools/fetch_godotsteam.sh            # refresh steam/godotsteam (commit the result)
#   bash tools/fetch_godotsteam.sh --check    # verify committed files against VERSION
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="4.24-gde"
URL="https://codeberg.org/godotsteam/godotsteam/releases/download/v4.24-gde/godotsteam-4.24-gdextension-plugin-4.4.zip"
SHA="d4358888959a03f4df0c71aafbcdca8f34b8cb9d4522aa5c8454f0e9e3debbf7"
DEST="$ROOT/steam/godotsteam"
FILES="linux64/libgodotsteam.linux.template_debug.x86_64.so linux64/libgodotsteam.linux.template_release.x86_64.so linux64/libsteam_api.so win64/libgodotsteam.windows.template_debug.x86_64.dll win64/libgodotsteam.windows.template_release.x86_64.dll win64/steam_api64.dll license.md"

if [ "${1:-}" = "--check" ]; then
  cd "$DEST" && sha256sum -c --quiet SHA256SUMS && echo "godotsteam: $VERSION ok" && exit 0
  echo "godotsteam: files differ from SHA256SUMS: rerun tools/fetch_godotsteam.sh"; exit 1
fi
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/gs.zip" "$URL"
echo "$SHA  $tmp/gs.zip" | sha256sum -c --quiet || { echo "godotsteam: sha256 mismatch"; exit 1; }
unzip -q "$tmp/gs.zip" -d "$tmp/x"
src="$tmp/x/addons/godotsteam"
mkdir -p "$DEST/linux64" "$DEST/win64"
for f in $FILES; do rm -f "$DEST/$f"; cp "$src/$f" "$DEST/$f"; done
cat > "$DEST/godotsteam.gdextension" <<'GDE'
[configuration]
entry_symbol = "godotsteam_init"
compatibility_minimum = "4.4"

[libraries]
linux.debug.x86_64 = "res://addons/godotsteam/linux64/libgodotsteam.linux.template_debug.x86_64.so"
linux.release.x86_64 = "res://addons/godotsteam/linux64/libgodotsteam.linux.template_release.x86_64.so"
windows.debug.x86_64 = "res://addons/godotsteam/win64/libgodotsteam.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://addons/godotsteam/win64/libgodotsteam.windows.template_release.x86_64.dll"

[dependencies]
linux.x86_64 = { "res://addons/godotsteam/linux64/libsteam_api.so": "" }
windows.x86_64 = { "res://addons/godotsteam/win64/steam_api64.dll": "" }
GDE
echo "GodotSteam GDExtension $VERSION (Steamworks SDK 1.65, MIT) from $URL sha256 $SHA" > "$DEST/VERSION"
(cd "$DEST" && sha256sum $FILES godotsteam.gdextension > SHA256SUMS)
echo "godotsteam: $VERSION staged in steam/godotsteam ($(du -sh "$DEST" | cut -f1))"
