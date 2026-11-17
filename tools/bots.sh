#!/usr/bin/env bash
# Run 20 play bots in parallel, each with its own user:// dir, then summarise.
#   bash tools/bots.sh [days] [outdir]
set -uo pipefail
GODOT="${GODOT:-godot}"
DAYS="${1:-5}"
OUT="${2:-/tmp/bots}"
cd "$(dirname "$0")/.."
rm -rf "$OUT"; mkdir -p "$OUT"
# seed arc playable style progress
BOTS=(
 "1 penguins kairi wander 0"      "2 penguins penguin_f story 1"   "3 penguins penguin_m fighter 2"  "4 penguins merry farmer 0"
 "5 penguins coco menus 1"        "6 penguins mer story 3"         "7 penguins coldy fighter 4"      "8 penguins big_jim wander 5"
 "9 penguins custom farmer 2"     "10 penguins pax story 5"        "11 gangsters dad wander 0"       "12 gangsters mom story 1"
 "13 gangsters june fighter 2"    "14 gangsters rafe farmer 0"     "15 gangsters nia menus 3"        "16 gangsters ollie story 4"
 "17 gangsters marisol fighter 5" "18 gangsters bo wander 3"       "19 gangsters custom story 2"     "20 gangsters pax menus 5"
)
pids=()
for b in "${BOTS[@]}"; do
  set -- $b
  mkdir -p "$OUT/data$1"
  XDG_DATA_HOME="$OUT/data$1" timeout 1500 "$GODOT" --headless --path . -s res://tools/bot.gd -- $1 $2 $3 $4 $5 "$DAYS" > "$OUT/bot$1.log" 2>&1 &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done
echo "== summary =="
for b in "${BOTS[@]}"; do
  set -- $b
  f="$OUT/bot$1.log"
  errs=$(grep -c "SCRIPT ERROR" "$f" || true)
  fails=$(grep -c "BOT FAIL" "$f" || true)
  warns=$(grep -c "BOT WARN" "$f" || true)
  done_line=$(grep -m1 "BOT $1 done" "$f" || echo "DID NOT FINISH")
  printf "bot%-2s %-9s %-10s %-8s p%s  errors=%-4s fails=%-3s warns=%-3s %s\n" "$1" "$2" "$3" "$4" "$5" "$errs" "$fails" "$warns" "$(echo "$done_line" | cut -c1-60)"
done
echo "== distinct script errors =="
grep -h -A1 "SCRIPT ERROR" "$OUT"/bot*.log | grep -v '^--$' | paste - - | sed 's/  */ /g' | sort | uniq -c | sort -rn | head -40
echo "== distinct fails/warns =="
grep -h "BOT FAIL\|BOT WARN" "$OUT"/bot*.log | sed 's/\[[0-9]* [a-z]*\] //' | sort | uniq -c | sort -rn | head -40
