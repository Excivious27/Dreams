#!/usr/bin/env python3
"""Keep the web download small: most music streams on demand.

    python3 tools/music_stream.py           # rewrite data/music_stream.json + the Web preset excludes
    python3 tools/music_stream.py --check   # fail if either is stale (deploy + CI)

Every audio/music/*.ogg except the few needed at once (EMBED) is listed in
data/music_stream.json and excluded from the WEB export only (the preset named
"Web" in export_presets.cfg; native presets such as Linux bundle every song,
since a native build has no stream URL). The deploy workflow copies those files
next to index.html under music/, and Music fetches each the first time it
plays, then keeps it in user://mcache. Each song carries a content version
("ver", sha1[:8]) and its size: Music caches <name>.<ver>.ogg and asks for
<name>.ogg?v=<ver>, so a re-imported song is fetched again on every phone that
had the old one.

EMBED keeps one fight loop per arc (combat_light / combat_light_gang) so a
fight is never scored with the calm farm song while offline or before the real
track arrives (Music._standin, C9 P4).
"""
import glob, hashlib, json, os, re, sys
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
EMBED = {"title", "farm", "house", "title_musicbox", "combat_light", "combat_light_gang"}
WEB_PRESET = "Web"


def build():
    names = sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(ROOT, "audio", "music", "*.ogg")))
    stream = [n for n in names if n not in EMBED]

    def _ver(n):
        with open(os.path.join(ROOT, "audio", "music", n + ".ogg"), "rb") as f:
            return hashlib.sha1(f.read()).hexdigest()[:8]
    out = {"stream": stream, "embed": sorted(set(names) & EMBED),
           "ver": {n: _ver(n) for n in stream},
           "size": {n: os.path.getsize(os.path.join(ROOT, "audio", "music", n + ".ogg")) for n in stream}}
    return names, stream, out


def preset_blocks(s):
    """[(index, start, end, name)] for every [preset.N] block (options excluded)."""
    heads = [(m.start(), m.group(1)) for m in re.finditer(r'^\[preset\.(\d+)\]\s*$', s, re.M)]
    res = []
    for i, (st, idx) in enumerate(heads):
        nxt = re.compile(r'^\[preset\.%s\.options\]' % idx, re.M).search(s, st)
        en = nxt.start() if nxt else (heads[i + 1][0] if i + 1 < len(heads) else len(s))
        nm = re.search(r'^name="([^"]*)"', s[st:en], re.M)
        res.append((idx, st, en, nm.group(1) if nm else ""))
    return res


def patch_presets(s, stream):
    blocks = preset_blocks(s)
    web = [b for b in blocks if b[3] == WEB_PRESET]
    assert web, "export_presets.cfg has no preset named Web"
    for idx, st, en, name in blocks:
        m = re.search(r'^exclude_filter="([^"]*)"', s[st:en], re.M)
        if not m:
            continue
        if name != WEB_PRESET:
            bad = [x for x in m.group(1).split(",") if x.strip().startswith("audio/music/")]
            assert not bad, f"preset {name} excludes songs {bad[:3]}: native builds must bundle all music"
    idx, st, en, name = web[0]
    blk = s[st:en]
    m = re.search(r'^exclude_filter="([^"]*)"', blk, re.M)
    parts = [x.strip() for x in m.group(1).split(",") if x.strip() and not x.strip().startswith("audio/music/")]
    parts += [f"audio/music/{n}.ogg" for n in stream]
    blk = blk[:m.start()] + 'exclude_filter="' + ", ".join(parts) + '"' + blk[m.end():]
    return s[:st] + blk + s[en:]


def main():
    check = "--check" in sys.argv
    names, stream, out = build()
    jp = os.path.join(ROOT, "data", "music_stream.json")
    p = os.path.join(ROOT, "export_presets.cfg")
    s = open(p).read()
    s2 = patch_presets(s, stream)
    js = json.dumps(out, indent=1)
    if check:
        cur = open(jp).read() if os.path.exists(jp) else ""
        ok = True
        if json.loads(cur or "{}") != out:
            print("music_stream: data/music_stream.json is stale: run python3 tools/music_stream.py"); ok = False
        if s2 != s:
            print("music_stream: Web preset exclude_filter is stale: run python3 tools/music_stream.py"); ok = False
        print("music_stream check:", "ok" if ok else "FAIL")
        sys.exit(0 if ok else 1)
    open(jp, "w").write(js)
    open(p, "w").write(s2)
    print(f"{len(stream)} streamed, {len(names) - len(stream)} embedded")


if __name__ == "__main__":
    main()
