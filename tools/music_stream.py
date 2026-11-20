#!/usr/bin/env python3
"""Keep the web download small: most music streams on demand.

    python3 tools/music_stream.py

Every audio/music/*.ogg except the few needed at once (EMBED) is listed in
data/music_stream.json and excluded from the web export (export_presets.cfg).
The deploy workflow copies those files next to index.html under music/, and
Music fetches each the first time it plays, then keeps it in user://mcache.
Each song carries a content version ("ver", sha1[:8]) and its size: Music caches
<name>.<ver>.ogg and asks for <name>.ogg?v=<ver>, so a re-imported song is
fetched again on every phone that had the old one.
"""
import glob, hashlib, json, os, re
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
EMBED = {"title", "farm", "house", "title_musicbox"}
names = sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(ROOT, "audio", "music", "*.ogg")))
stream = [n for n in names if n not in EMBED]
def _ver(n):
    with open(os.path.join(ROOT, "audio", "music", n + ".ogg"), "rb") as f:
        return hashlib.sha1(f.read()).hexdigest()[:8]
out = {"stream": stream, "embed": sorted(set(names) & EMBED),
       "ver": {n: _ver(n) for n in stream},
       "size": {n: os.path.getsize(os.path.join(ROOT, "audio", "music", n + ".ogg")) for n in stream}}
json.dump(out, open(os.path.join(ROOT, "data", "music_stream.json"), "w"), indent=1)
p = os.path.join(ROOT, "export_presets.cfg")
s = open(p).read()
m = re.search(r'^exclude_filter="([^"]*)"', s, re.M)
parts = [x.strip() for x in m.group(1).split(",") if x.strip() and not x.strip().startswith("audio/music/")]
parts += [f"audio/music/{n}.ogg" for n in stream]
s = s[:m.start()] + 'exclude_filter="' + ", ".join(parts) + '"' + s[m.end():]
open(p, "w").write(s)
print(f"{len(stream)} streamed, {len(names) - len(stream)} embedded")
