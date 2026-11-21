#!/usr/bin/env bash
# Run 20 play bots in parallel, each with its own user:// dir, then summarise.
#   bash tools/bots.sh [days] [outdir]
set -uo pipefail
GODOT="${GODOT:-godot}"
DAYS="${1:-5}"
OUT="${2:-/tmp/bots}"
cd "$(dirname "$0")/.."
rm -rf "$OUT"; mkdir -p "$OUT"
# seed arc playable style progress difficulty(0 Very easy..3 Hard) day_len(real minutes)
BOTS=(
 "1 penguins kairi wander 0 0 15" "2 penguins penguin_f story 1 2 20" "3 penguins penguin_m fighter 2 3 40" "4 penguins merry farmer 0 2 30"
 "5 penguins coco menus 1 1 15" "6 penguins mer story 3 2 20" "7 penguins coldy fighter 4 3 40" "8 penguins big_jim nowin 5 2 30"
 "9 penguins custom farmer 2 1 20" "10 penguins pax story 5 2 15" "11 gangsters dad wander 0 0 15" "12 gangsters mom story 1 2 30"
 "13 gangsters june fighter 2 3 40" "14 gangsters rafe farmer 0 1 20" "15 gangsters nia menus 3 2 15" "16 gangsters ollie story 4 2 30"
 "17 gangsters marisol fighter 5 3 40" "18 gangsters bo nowin 3 2 20" "19 gangsters custom story 2 1 30" "20 gangsters pax menus 5 2 15"
)
pids=()
for b in "${BOTS[@]}"; do
  set -- $b
  mkdir -p "$OUT/data$1"
  XDG_DATA_HOME="$OUT/data$1" timeout 1500 "$GODOT" --headless --path . -s res://tools/bot.gd -- $1 $2 $3 $4 $5 $6 $7 "$DAYS" > "$OUT/bot$1.log" 2>&1 &
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
  pauses=$(grep -c "paused with nothing on screen" "$f" || true)
  done_line=$(grep -m1 "BOT $1 done" "$f" || echo "DID NOT FINISH")
  printf "bot%-2s %-9s %-10s %-8s p%s d%s %2sm errors=%-4s fails=%-3s warns=%-3s pauses=%-3s %s\n" "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$errs" "$fails" "$warns" "$pauses" "$(echo "$done_line" | cut -c1-60)"
done
echo "== end-of-day energy (C16a P3: mean % left by style/arc, from BOT ENERGY lines) =="
for b in "${BOTS[@]}"; do set -- $b; grep -h "BOT ENERGY" "$OUT/bot$1.log" | sed "s/^/$2 /"; done | awk '{st=""; l=0; m=1; for(i=1;i<=NF;i++){split($i,kv,"="); if(kv[1]=="style")st=kv[2]; if(kv[1]=="left")l=kv[2]; if(kv[1]=="max")m=kv[2]}; k=$1" "st; s[k]+=100*l/(m>0?m:1); n[k]++; if(l==0)z[k]++} END{for(k in s) printf "  %-22s days=%-3d mean_left=%3.0f%% empty_days=%d\n", k, n[k], s[k]/n[k], z[k]+0}' | sort
echo "== nowin bots (C16b P3: regions reached by the long way, never a win) =="
grep -h "BOT NOWIN reached" "$OUT"/bot*.log | tail -4
echo "== distinct script errors =="
grep -h -A1 "SCRIPT ERROR" "$OUT"/bot*.log | grep -v '^--$' | paste - - | sed 's/  */ /g' | sort | uniq -c | sort -rn | head -40
echo "== distinct fails/warns =="
grep -h "BOT FAIL\|BOT WARN\|paused with nothing on screen" "$OUT"/bot*.log | sed 's/\[[0-9]* [a-z]*\] //' | sort | uniq -c | sort -rn | head -40
