#!/bin/bash
# mkwt.sh <name> <branch> : worktree at /home/claude/wt/<name>, heavy dirs hardlinked from main.
# R4: refuses under 4 GB free disk (run tools/conduct/wt_clean.sh first); copies main's fresh
# .godot/global_script_class_cache.cfg (rm-then-copy, never a hardlink) so new classes compile.
# Reimport main once per CONDUCT before launching (godot --headless --path . --import under glock.sh).
set -e
M=/home/claude/dreams; W=/home/claude/wt/$1
FREE=$(df -Pk /home/claude | awk 'NR==2{print int($4/1048576)}')
if [ "$FREE" -lt 4 ]; then echo "mkwt: only ${FREE} GB free (< 4 GB): run bash $M/tools/conduct/wt_clean.sh first"; exit 1; fi
cd $M
git worktree add -q --no-checkout -b $2 $W HEAD
cd $W
for d in art audio reference build .godot; do [ -e $M/$d ] && cp -al $M/$d $W/$d; done
tar -C $M --exclude=./.git --exclude=./art --exclude=./audio --exclude=./reference --exclude=./build --exclude=./.godot -cf - . | tar -xf -
git reset -q
for f in art/gen/manifest.json audio/music/REAL.txt audio/sfx/REAL.txt audio/CC0_USED.json audio/ACE_LOG.json audio/sfx/ACE.txt audio/sfx/SOFTEN_LOG.json; do [ -f $f ] && cp --remove-destination $M/$f $f; done
CC=.godot/global_script_class_cache.cfg
if [ -f $M/$CC ]; then rm -f $W/$CC; cp $M/$CC $W/$CC; fi
git status --short | head -3
