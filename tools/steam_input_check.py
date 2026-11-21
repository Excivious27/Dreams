#!/usr/bin/env python3
"""S1 P4: check steam/input/game_actions_480.vdf against scripts/input_setup.gd.
Parses the VDF with a tiny KeyValues reader (no pip dependency) and asserts:
every PAD_DEFAULTS action is in the InGame set exactly once (movement as Move),
no keyboard-only or unknown action is in it, every #token has an english string,
and the file equals the generator's output. Prints "steam_input_check: ok".
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_steam_input as gen  # noqa: E402


def parse(text: str):
    toks = re.findall(r'"((?:[^"\\]|\\.)*)"|([{}])', re.sub(r"//[^\n]*", "", text))
    pos = 0

    def block():
        nonlocal pos
        out = []
        while pos < len(toks):
            s, br = toks[pos]
            if br == "}":
                pos += 1
                return out
            key = s
            pos += 1
            s2, br2 = toks[pos]
            if br2 == "{":
                pos += 1
                out.append((key, block()))
            else:
                pos += 1
                out.append((key, s2))
        return out
    s, _ = toks[0]
    pos = 2
    return [(s, block())]


def get(kv, key):
    hits = [v for k, v in kv if k == key]
    return hits


def main() -> int:
    fails = []
    text = open(gen.OUT, encoding="utf-8").read()
    if text != gen.build():
        fails.append("VDF is stale (python3 tools/gen_steam_input.py)")
    root = parse(text)
    iga = get(root, "In Game Actions")[0]
    ingame = get(get(iga, "actions")[0], "InGame")[0]
    names = []
    for sec in ("Button", "AnalogTrigger"):
        for blk in get(ingame, sec):
            names += [k for k, _ in blk]
    pad = gen.pad_actions(open(gen.SRC, encoding="utf-8").read())
    for a in pad:
        if a in gen.MOVE:
            continue
        if names.count(a) != 1:
            fails.append("%s appears %d times in InGame" % (a, names.count(a)))
    known = set(pad) | set(gen.EXTRA_INGAME)
    for n in names:
        if n not in known or n.startswith("slot_"):
            fails.append("unknown/keyboard-only action in InGame: " + n)
    if not get(get(ingame, "StickPadGyro")[0], "Move"):
        fails.append("no Move stick")
    eng = dict(get(get(iga, "localization")[0], "english")[0])
    for t in re.findall(r'"#([A-Za-z_]+)"', text):
        if not eng.get(t):
            fails.append("no english string for #" + t)
    for f in fails:
        print("  FAIL", f)
    print("steam_input_check: %s" % ("ok" if not fails else "%d failures" % len(fails)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
