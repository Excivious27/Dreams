#!/usr/bin/env bash
# bot_spec.sh <n>: print "seed arc playable style progress" for bot n (same table as tools/bots.sh).
BOTS=(
 "1 penguins kairi wander 0"      "2 penguins penguin_f story 1"   "3 penguins penguin_m fighter 2"  "4 penguins merry farmer 0"
 "5 penguins coco menus 1"        "6 penguins mer story 3"         "7 penguins coldy fighter 4"      "8 penguins big_jim wander 5"
 "9 penguins custom farmer 2"     "10 penguins pax story 5"        "11 gangsters dad wander 0"       "12 gangsters mom story 1"
 "13 gangsters june fighter 2"    "14 gangsters rafe farmer 0"     "15 gangsters nia menus 3"        "16 gangsters ollie story 4"
 "17 gangsters marisol fighter 5" "18 gangsters bo wander 3"       "19 gangsters custom story 2"     "20 gangsters pax menus 5"
)
echo "${BOTS[$(( $1 - 1 ))]}"
