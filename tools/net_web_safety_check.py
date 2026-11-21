#!/usr/bin/env python3
"""S1 P4: the web build must never parse Steam code. The co-op scripts may reach
Steam only through a backend object (steam.call(...)) and NetNode may load the
Steam transport only by path, so a Web export without GodotSteam still compiles.
Fails on: the `Steam` singleton named in any net script, `NetTransportSteam` or
`FakeSteam` named outside their own files/tests, or a static preload of the
Steam transport. Prints "net_web_safety_check: ok".
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fails = []
for p in sorted(glob.glob(os.path.join(ROOT, "scripts", "*.gd"))):
    name = os.path.basename(p)
    src = open(p, encoding="utf-8").read()
    code = "\n".join(l.split("#", 1)[0] for l in src.splitlines())
    if name.startswith("net") and re.search(r"\bSteam\s*\.", code):
        fails.append("%s names the Steam singleton (go through the backend object)" % name)
    if name != "net_transport_steam.gd" and re.search(r"\bNetTransportSteam\b", code):
        fails.append("%s names NetTransportSteam (load it by path)" % name)
    if re.search(r"\bFakeSteam\b", code):
        fails.append("%s names the test double FakeSteam" % name)
    if re.search(r'preload\("res://scripts/net_transport_steam\.gd"\)', code):
        fails.append("%s preloads the Steam transport" % name)
net = open(os.path.join(ROOT, "scripts", "net.gd"), encoding="utf-8").read()
if 'load("res://scripts/net_transport_steam.gd")' not in net:
    fails.append("net.gd no longer loads the Steam transport by path")
for f in fails:
    print("  FAIL", f)
print("net_web_safety_check: %s" % ("ok" if not fails else "%d failures" % len(fails)))
sys.exit(1 if fails else 0)
