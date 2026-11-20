#!/usr/bin/env bash
# bot_spec.sh <n>: print "seed arc playable style progress difficulty day_len" for bot n (same table as tools/bots.sh).
BOTS=(
 "1 penguins kairi wander 0 0 15" "2 penguins penguin_f story 1 2 20" "3 penguins penguin_m fighter 2 3 40" "4 penguins merry farmer 0 2 30"
 "5 penguins coco menus 1 1 15" "6 penguins mer story 3 2 20" "7 penguins coldy fighter 4 3 40" "8 penguins big_jim wander 5 2 30"
 "9 penguins custom farmer 2 1 20" "10 penguins pax story 5 2 15" "11 gangsters dad wander 0 0 15" "12 gangsters mom story 1 2 30"
 "13 gangsters june fighter 2 3 40" "14 gangsters rafe farmer 0 1 20" "15 gangsters nia menus 3 2 15" "16 gangsters ollie story 4 2 30"
 "17 gangsters marisol fighter 5 3 40" "18 gangsters bo wander 3 2 20" "19 gangsters custom story 2 1 30" "20 gangsters pax menus 5 2 15"
)
echo "${BOTS[$(( $1 - 1 ))]}"
