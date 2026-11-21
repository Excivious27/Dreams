#!/usr/bin/env bash
# Steam trailer build (CONDUCT S1, P6). Heavy: run in CI (manual job), not in check.sh.
#   bash tools/steam_trailer.sh [out_dir]      (default build/trailer; build/* never ships)
#   TRAILER_BEATS="b01_gloam_open b17_pullback" bash tools/steam_trailer.sh /tmp/t   (a short test cut)
# 1) tools/steam_trailer.gd records the beats in docs/steam-store/trailer_shots.json
#    with Godot Movie Maker at 30 fps (game music muted, sfx kept);
# 2) an end card (library hero + library logo + one line) is drawn with PIL;
# 3) ffmpeg scales 1919->1920 with nearest (the wide view is 853 px x2.25), appends
#    the end card, lays audio/music/title.ogg over the cut with a 2 s fade-out under
#    the game sfx, and encodes Steam's spec: H.264/AAC mp4, 1920x1080, 30 fps,
#    5-12 Mbps, faststart. Also writes a text-free thumbnail from 0:04.
# tools/steam_trailer_test.py checks the result with ffprobe.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-build/trailer}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"  # absolute: Godot runs from the project root
GODOT="${GODOT:-godot}"
export TRAILER_SEGMENTS="$OUT/segments.json"
[ "${SKIP_CAPTURE:-0}" = 1 ] && [ -s "$OUT/raw.avi" ] || timeout "${TRAILER_TIMEOUT:-1800}" xvfb-run -a "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 \
  --write-movie "$OUT/raw.avi" -s res://tools/steam_trailer.gd -- ${TRAILER_BEATS:-} 2>&1 | grep -E "steam_trailer|SCRIPT ERROR" || true
test -s "$OUT/raw.avi" || { echo "steam_trailer: no movie recorded"; exit 1; }
python3 - "$OUT/endcard.png" <<'PY'
import json, sys
from PIL import Image, ImageDraw, ImageFont
spec = json.load(open("docs/steam-store/trailer_shots.json"))["end_card"]
card = Image.new("RGB", (1920, 1080), (12, 8, 24))
hero = Image.open(spec["background"]).convert("RGB").resize((1920, 620), Image.LANCZOS)
card.paste(hero, (0, 160))
logo = Image.open(spec["logo"]).convert("RGBA")
s = min(900 / logo.width, 300 / logo.height)
logo = logo.resize((round(logo.width * s), round(logo.height * s)), Image.LANCZOS)
card.paste(logo, ((1920 - logo.width) // 2, 200), logo)
d = ImageDraw.Draw(card)
f = ImageFont.load_default(size=56)
w = d.textlength(spec["line"], font=f)
d.text(((1920 - w) / 2, 860), spec["line"], font=f, fill=(255, 240, 210))
card.save(sys.argv[1])
PY
SEC=$(python3 -c "import json;print(json.load(open('docs/steam-store/trailer_shots.json'))['end_card']['seconds'])")
# Keep only the beat frames (scene loads between beats are cut), video and audio alike.
read -r VSEL ASEL RAW < <(python3 -c "
import json; d=json.load(open('$OUT/segments.json')); f=d['fps']; s=d['segments']
print('+'.join('between(n,%d,%d)' % (a, b) for a, b in s), '+'.join('between(t,%.4f,%.4f)' % (a / f, (b + 1) / f) for a, b in s), sum(b - a + 1 for a, b in s) / f)")
DUR=$(python3 -c "print($RAW + $SEC)")
FADE=$(python3 -c "print(max(0.0, $DUR - 2.0))")
ffmpeg -y -loglevel error -i "$OUT/raw.avi" -loop 1 -t "$SEC" -framerate 30 -i "$OUT/endcard.png" \
  -f lavfi -t "$SEC" -i anullsrc=r=48000:cl=stereo -i audio/music/title.ogg \
  -filter_complex "[0:v]select='$VSEL',setpts=N/30/TB,scale=1920:1080:flags=neighbor,setsar=1,fps=30,format=yuv420p[v0];[1:v]setsar=1,fps=30,format=yuv420p[v1];[0:a]aselect='$ASEL',asetpts=N/SR/TB,aresample=48000[a0];[2:a]aresample=48000[a1];[v0][a0][v1][a1]concat=n=2:v=1:a=1[v][ga];[ga]volume=0.45[sfx];[3:a]aresample=48000,atrim=0:$DUR,afade=t=out:st=$FADE:d=2[m];[m][sfx]amix=inputs=2:duration=first:normalize=0[a]" \
  -map "[v]" -map "[a]" -r 30 -c:v libx264 -preset slow -crf 18 -maxrate 12M -bufsize 24M \
  -c:a aac -ar 48000 -b:a 192k -movflags +faststart "$OUT/trailer_v1.mp4"
rm -f "$OUT/raw.avi"
ffmpeg -y -loglevel error -ss 4 -i "$OUT/trailer_v1.mp4" -frames:v 1 "$OUT/thumbnail.png"
python3 tools/steam_trailer_test.py "$OUT/trailer_v1.mp4"
