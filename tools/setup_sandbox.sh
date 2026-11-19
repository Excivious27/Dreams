#!/bin/bash
# One-time setup for a fresh Claude sandbox (either account): Godot 4.5.1 headless + Python deps.
# Run from the repo root:  bash tools/setup_sandbox.sh   then  export PATH=$PATH:/home/claude/tools
set -e
T=/home/claude/tools
mkdir -p $T
if ! [ -x $T/godot ]; then
  V=4.5.1-stable
  curl -fsSL -o $T/godot.zip "https://github.com/godotengine/godot/releases/download/$V/Godot_v${V}_linux.x86_64.zip"
  (cd $T && unzip -oq godot.zip && mv -f Godot_v${V}_linux.x86_64 godot && chmod +x godot)
fi
$T/godot --version
pip install -q --break-system-packages fonttools pillow numpy scipy openpyxl 2>/dev/null || true
command -v xvfb-run >/dev/null || (apt-get install -y -q xvfb >/dev/null 2>&1 || echo "WARN: xvfb-run missing (screenshot tools need it)")
command -v ffmpeg >/dev/null || echo "WARN: ffmpeg missing (audio import tools need it)"
# First import builds .godot (class cache, imported art); takes several minutes.
cd "$(dirname "$0")/.." && XDG_DATA_HOME=$(mktemp -d) $T/godot --headless --path . --import > /tmp/first_import.log 2>&1 || true
echo "setup done: export PATH=\$PATH:$T ; then bash tools/check.sh"
