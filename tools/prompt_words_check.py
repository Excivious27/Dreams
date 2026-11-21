#!/usr/bin/env python3
"""S1 P3 (s1_08-06): no touch words ("Tap ...", "arrow keys") shown to pad
players. Every string literal in scripts/*.gd that says "tap"/"Tap " or
"arrow keys" must reach the screen through PadInput.words (directly, or through
a helper that runs it: Hud.toast, GameMenu._line, CharSheet._lab/_card,
title/decor_catalogue _label, decor_mode._say, dialogue lines and choices) or
sit in a touch-only branch. Lines that are known fine are listed in
tools/prompt_words_allow.txt ("file:text-fragment"); a new unlisted one fails.
  python3 tools/prompt_words_check.py [--baseline]   (--baseline rewrites the allow list)"""
import glob, re, sys, os

HELPERS = ("PadInput.words(", "toast(", "_line(", "_lab(", "_card(", "_label(", "_say(", "_tip(", "say(", "line(")
LIT = re.compile(r'"((?:[^"\\]|\\.)*)"')
WORD = re.compile(r'(\b[Tt]ap (?!dance)|arrow keys)')
ALLOW = os.path.join(os.path.dirname(__file__), "prompt_words_allow.txt")


def offenders():
    out = []
    for f in sorted(glob.glob("scripts/*.gd")):
        for n, line in enumerate(open(f, encoding="utf-8"), 1):
            st = line.strip()
            if st.startswith("#") or st.startswith("##"):
                continue
            code = line.split(" #")[0]
            if any(h in code for h in HELPERS):
                continue
            for m in LIT.finditer(code):
                if WORD.search(m.group(1)):
                    out.append("%s:%s" % (os.path.basename(f), m.group(1)[:60]))
    return out


def main():
    found = offenders()
    if "--baseline" in sys.argv:
        open(ALLOW, "w", encoding="utf-8").write("\n".join(sorted(set(found))) + "\n")
        print("prompt_words_check: baseline %d" % len(set(found)))
        return 0
    allow = set()
    if os.path.exists(ALLOW):
        allow = {l.rstrip("\n") for l in open(ALLOW, encoding="utf-8") if l.strip()}
    new = [f for f in found if f not in allow]
    for f in new:
        print("  touch words not through PadInput.words: " + f)
    print("prompt_words_check: %d new (allow list %d)" % (len(new), len(allow)))
    return 1 if new else 0


if __name__ == "__main__":
    sys.exit(main())
