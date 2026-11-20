#!/bin/bash
# mkwt.sh <name> <branch> : worktree at /home/claude/wt/<name>, heavy dirs hardlinked from main
set -e
M=/home/claude/dreams; W=/home/claude/wt/$1
cd $M
git worktree add -q --no-checkout -b $2 $W HEAD
cd $W
for d in art audio reference build .godot; do [ -e $M/$d ] && cp -al $M/$d $W/$d; done
tar -C $M --exclude=./.git --exclude=./art --exclude=./audio --exclude=./reference --exclude=./build --exclude=./.godot -cf - . | tar -xf -
git reset -q
for f in art/gen/manifest.json audio/music/REAL.txt audio/sfx/REAL.txt audio/CC0_USED.json audio/ACE_LOG.json audio/sfx/ACE.txt audio/sfx/SOFTEN_LOG.json; do [ -f $f ] && cp --remove-destination $M/$f $f; done
git status --short | head -3
