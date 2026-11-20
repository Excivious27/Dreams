#!/usr/bin/env python3
"""Write web/head_include.html into the Web export preset (html/head_include).

    python3 tools/web_head.py           # write
    python3 tools/web_head.py --check   # fail if the preset is stale (deploy + CI)

Edit web/head_include.html (readable HTML/JS), never the escaped string in
export_presets.cfg (C9 P4).
"""
import os, re, sys
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
src = open(os.path.join(ROOT, "web", "head_include.html")).read()
esc = src.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
p = os.path.join(ROOT, "export_presets.cfg")
s = open(p).read()
m = re.search(r'^html/head_include="((?:[^"\\]|\\.)*)"', s, re.M)
assert m, "no html/head_include in export_presets.cfg"
s2 = s[:m.start()] + 'html/head_include="' + esc + '"' + s[m.end():]
if "--check" in sys.argv:
    ok = s2 == s
    print("web_head check:", "ok" if ok else "FAIL: run python3 tools/web_head.py")
    sys.exit(0 if ok else 1)
open(p, "w").write(s2)
print("head_include written (%d chars)" % len(src))
