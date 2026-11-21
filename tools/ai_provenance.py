#!/usr/bin/env python3
"""ai_provenance.py: the counts behind docs/steam-store/ai-disclosure.md (s1_13-05). Report only.

    python3 tools/ai_provenance.py          print art / music / sound counts by source
    python3 tools/ai_provenance.py --strict exit 1 if a shipped song or sound has no provenance row

Art: art/gen/manifest.json entries (every sliced piece came from a dreams-image / ChatGPT render or Tom's
upload in art/incoming/). Audio: audio/ACE_LOG.json (ACE Music songs) and audio/CC0_USED.json (CC0 sounds);
anything else under audio/ (e.g. tools/make_audio.py jingles, older imports) is listed as "no provenance row". stdlib only.
"""
import glob, json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def main():
    man = json.load(open(os.path.join(ROOT, "art", "gen", "manifest.json")))
    ace = json.load(open(os.path.join(ROOT, "audio", "ACE_LOG.json")))
    cc0 = json.load(open(os.path.join(ROOT, "audio", "CC0_USED.json")))
    known = set(ace) | set(cc0)
    files = [p for p in glob.glob(os.path.join(ROOT, "audio", "*", "*.ogg")) if "/incoming/" not in p]
    names = {os.path.splitext(os.path.basename(p))[0] for p in files}
    # variants like shot_2 share the base name's row
    orphan = sorted(n for n in names if n not in known and n.rsplit("_", 1)[0] not in known)
    pieces = sum(len(v) if isinstance(v, dict) and not v.get("file") else 1 for v in man.values())
    print("ai_provenance: art pieces %d in %d groups (generated renders + uploads, art/gen/manifest.json)" % (pieces, len(man)))
    print("ai_provenance: ACE Music rows %d, CC0 sound rows %d, shipped audio files %d" % (len(ace), len(cc0), len(files)))
    print("ai_provenance: audio files with no provenance row: %d%s" % (len(orphan), (" (" + ", ".join(orphan[:12]) + ")") if orphan else ""))
    return 1 if ("--strict" in sys.argv and orphan) else 0


if __name__ == "__main__":
    sys.exit(main())
