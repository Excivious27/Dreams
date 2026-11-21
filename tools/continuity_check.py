#!/usr/bin/env python3
"""C12 P7 continuity checker: who mentions what, and when.

Builds, per arc, the order of the main story beats (data/story.json penguins,
data/story_gang.json gangsters) and finds the first beat that names each tracked
term (characters, places, story things). Then it reads every villager-facing text
source and reports:

  LEAK     a line that can show in one arc names the other arc's word
           (penguin lore in a gangster save, crew talk in a penguin save);
  SPOILER  a line names a term from a later beat, but its gate (its own "when",
           a flag:/after: talk key, a side-story chain "when") does not reach that beat.

Sources: talk.json, npcs.json (inside lines), gift_lines.json, hearts.json,
events.json, side_stories.json, quests.json (side), quest_lines.json (with
<id>@gangsters overrides). Arc of a line: an arc-named key ("penguins"/"gangsters"),
an "arc" field, a when.arc, or a *_gangsters sibling (then the base text is
penguin-only). Gate of a line: the nearest "when" dict above it, a talk key
"flag:<f>"/"after:<f>"/"chapter:<n>", or a dict entry {"text", "when"}.

Known hits live in tools/continuity_allow.txt (one key per line). --strict fails only
on hits that are not allowed, so new writing cannot add spoilers or leaks; stale
allow entries are listed (remove them). --update-allow rewrites the allow list
from the current hits (integration only, after reading every new hit).

  python3 tools/continuity_check.py            # report
  python3 tools/continuity_check.py --strict   # check.sh gate
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
ALLOW = "tools/continuity_allow.txt"
ARCS = ("penguins", "gangsters")

# Terms whose first story mention gates them. Regex (case-insensitive unless noted).
TERMS = {
    "penguins": {
        "Big Jim": r"\bBig Jim\b", "Coldy": r"\bColdy\b", "merkitties": r"\bmerkitt", "Catkins": r"\bCatkins\b",
        "Fennimore": r"\bFennimore\b", "Grandmother Brine": r"\bBrine\b", "the Commander": r"\bthe Commander\b",
        "the Sanctuary": r"\bSanctuary\b", "the Knight": r"\bthe Knight\b", "the moon": r"\bthe moon\b(?! ?(?:rose|light|lit|was|is up))",
        "the Grump truth": r"\bGrumps? (?:are|were) (?:cursed|people)",
    },
    "gangsters": {
        "the President": r"\bthe President\b", "Marlene": r"\bMarlene\b", "Specs": r"\bSpecs\b", "Ladder": r"\bLadder\b",
        "Halo": r"\bHalo\b", "Mama Rosa": r"\bMama Rosa\b", "Hale": r"\bHale\b", "Deuce": r"\bDeuce\b", "Sasha": r"\bSasha\b",
        "the manifest": r"\bmanifest\b",
    },
}
# A term met before its name is spoken in the story: the beat where the player meets it.
INTRO_BEAT = {"Coldy": "p3_coldy"}
# Words that belong to one arc only (a hit in the other arc is a LEAK).
ARC_WORDS = {
    "penguins": r"\bpenguins?\b|\bGrumps?\b|\bPip-Pip\b|\bStar Crystal\b|\bmerkitt|\bColdy\b|\bBig Jim\b|\bCatkins\b|\bSanctuary\b|\bsomething fell in the east\b",
    "gangsters": r"\bHideout\b|\bRacket\b|\bUptown\b|\bMarlene\b|\bthe President\b|\bcrew boss\b|\byour crew\b",
}
SKIP_KEYS = {"_", "id", "who", "sprite", "portrait", "giver", "scene", "color", "spot", "spot_name", "routine",
             "quest6", "flag", "role", "name", "title", "summary", "fall", "actors", "trigger", "effects", "reward"}
SOURCES = ["talk.json", "npcs.json", "gift_lines.json", "hearts.json", "events.json", "side_stories.json",
           "quests.json", "quest_lines.json"]


def load(f):
    with open(os.path.join("data", f), encoding="utf-8") as fh:
        return json.load(fh)


def beat_order():
    """Per arc: ordered beats, rank of every flag/quest a beat needs or is, rank of chapters."""
    out = {}
    for arc, f in (("penguins", "story.json"), ("gangsters", "story_gang.json")):
        d = load(f)
        chapters = d.get(arc, [])
        beats, rank, chap_rank = [], {}, {}
        for ci, ch in enumerate(chapters):
            chap_rank.setdefault(ci + 1, len(beats))
            for b in ch.get("beats", []):
                i = len(beats)
                text = " ".join(str(l.get("text", "")) if isinstance(l, dict) else str(l) for l in b.get("lines", []))
                beats.append((str(b.get("id", "")), text))
                rank.setdefault("st_" + str(b.get("id", "")), i)
                w = b.get("when", {}) or {}
                for k in ("flag", "quest"):
                    if k in w:
                        rank.setdefault(str(w[k]), i)
                for fl in w.get("flags", []):
                    rank.setdefault(str(fl), i)
                # A flag a beat sets (effects) also proves the player got that far (C12 integ).
                ef = b.get("effects", {}) or {}
                for fl in (ef.get("flags", []) if isinstance(ef, dict) else []):
                    rank.setdefault(str(fl), i)
        out[arc] = {"beats": beats, "rank": rank, "chap": chap_rank}
    return out


def term_ranks(order):
    tr = {}
    for arc in ARCS:
        tr[arc] = {}
        for term, rx in TERMS[arc].items():
            for i, (bid, text) in enumerate(order[arc]["beats"]):
                if re.search(rx, text, re.I) or INTRO_BEAT.get(term) == bid:
                    tr[arc][term] = (i, bid)
                    break
    return tr


def gate_rank(gate, arc, order):
    """How far into the story a line's gate guarantees the player is (-1 = from day 1)."""
    r = -1
    rk = order[arc]["rank"]
    for w in gate:
        for k in ("flag", "quest"):
            if k in w and str(w[k]) in rk:
                r = max(r, rk[str(w[k])])
        for fl in w.get("flags", []) or []:
            if str(fl) in rk:
                r = max(r, rk[str(fl)])
        if "chapter" in w:
            r = max(r, order[arc]["chap"].get(int(w["chapter"]), -1))
    return r


def _talk_part_gate(part):
    m = re.match(r"(flag|after|chapter|f|if|q):(.+)$", part)
    if not m:
        return None
    if m.group(1) == "chapter":
        return {"chapter": int(m.group(2))}
    if m.group(1) == "q":
        return {"quest": m.group(2)}
    return {"flag": m.group(2)}


def talk_key_gate(key):
    """The first gate in a talk.json pool key; compound keys ("penguins&f:told_town", C12 P3) too."""
    for part in key.split("&"):
        g = _talk_part_gate(part)
        if g:
            return g
    return None


def talk_key_arcs(key):
    """Arc parts of a compound talk key ("penguins&if:x" -> ("penguins",)), or None."""
    arcs = tuple(p for p in key.split("&") if p in ARCS)
    return arcs if "&" in key and arcs else None


def lines(src, o, path, arcs, gate, out):
    """Yield (path, text, arcs, gate list) for every player-facing sentence."""
    if isinstance(o, dict):
        local_arcs, local_gate = arcs, gate
        w = o.get("when")
        if isinstance(w, dict):
            local_gate = gate + [w]
            if w.get("arc") in ARCS:
                local_arcs = (w["arc"],)
        if o.get("arc") in ARCS:
            local_arcs = (o["arc"],)
        gang_keys = {k[:-len("_gangsters")] for k in o if k.endswith("_gangsters")}
        for k, v in o.items():
            if k in SKIP_KEYS or k == "when":
                continue
            a, g = local_arcs, local_gate
            if k in ARCS:
                a = (k,) if k in local_arcs else ()
            elif k.endswith("_gangsters"):
                a = ("gangsters",) if "gangsters" in local_arcs else ()
            elif k in gang_keys:
                a = tuple(x for x in local_arcs if x != "gangsters")
            if src == "talk.json":
                ka = talk_key_arcs(k)
                if ka is not None:
                    a = tuple(x for x in local_arcs if x in ka)
                tg = talk_key_gate(k)
                if tg:
                    g = g + [tg]
            if a:
                lines(src, v, "%s/%s" % (path, k), a, g, out)
    elif isinstance(o, list):
        for i, v in enumerate(o):
            lines(src, v, "%s[%d]" % (path, i), arcs, gate, out)
    elif isinstance(o, str) and len(o.split()) >= 3:
        out.append((src, path, o, arcs, gate))


def collect():
    out = []
    for src in SOURCES:
        d = load(src)
        if src == "npcs.json":
            for nid, n in d.items():
                if isinstance(n, dict):
                    lines(src, n.get("inside", []), "/%s/inside" % nid, ARCS, [], out)
            continue
        if src == "quests.json":
            lines(src, d.get("side", []), "/side", ARCS, [], out)
            continue
        if src == "quest_lines.json":
            for qid, v in d.items():
                if qid == "_":
                    continue
                if "@" in qid:
                    lines(src, v, "/" + qid, (qid.split("@")[1],), [], out)
                elif qid + "@gangsters" in d:
                    lines(src, v, "/" + qid, ("penguins",), [], out)
                else:
                    lines(src, v, "/" + qid, ARCS, [], out)
            continue
        lines(src, d, "", ARCS, [], out)
    return out


def owner(src, path, npc_names):
    """The villager who speaks a line (their own name in their own lines is no spoiler)."""
    parts = [p for p in re.split(r"[/\[\]]", path) if p]
    if src in ("talk.json", "npcs.json") and parts:
        return npc_names.get(parts[0], "")
    if src in ("hearts.json", "gift_lines.json") and len(parts) > 1:
        return npc_names.get(parts[1], "")
    if src == "quests.json" and len(parts) > 1 and parts[1].isdigit():
        side = load("quests.json").get("side", [])
        i = int(parts[1])
        return npc_names.get(str(side[i].get("giver", "")), "") if i < len(side) else ""
    if src == "quest_lines.json" and parts:
        return npc_names.get(parts[0].split("_")[0], "")
    return ""


def _key(src, path, arc, term, text):
    """Allow-list key: stable when list indexes move; changes when the sentence is rewritten."""
    head = [p for p in re.split(r"[/\[\]]", path) if p and not p.isdigit()][:2]
    return "%s:%s:%s:%s | %s" % (src, "/".join(head), arc, term, re.sub(r"\s+", " ", text)[:48].rstrip())


def check():
    order = beat_order()
    npc_names = {k: str(v.get("name", "")) for k, v in load("npcs.json").items() if isinstance(v, dict)}
    tr = term_ranks(order)
    hits = []
    for src, path, text, arcs, gate in collect():
        who = owner(src, path, npc_names)
        for arc in arcs:
            other = "gangsters" if arc == "penguins" else "penguins"
            m = re.search(ARC_WORDS[other], text)
            if m:
                hits.append(("LEAK", _key(src, path, arc, m.group(0).lower(), text), text))
            g = gate_rank(gate, arc, order)
            for term, (ti, bid) in tr[arc].items():
                if ti <= g or ti <= 2 or (who and who in term):
                    continue
                if re.search(TERMS[arc][term], text, re.I):
                    hits.append(("SPOILER", _key(src, path, arc, term, text), "%s (first in %s) | %s" % (term, bid, text)))
    return hits, tr


def main(argv):
    hits, tr = check()
    allow = set()
    if os.path.exists(ALLOW):
        allow = {l.strip() for l in open(ALLOW, encoding="utf-8") if l.strip() and not l.startswith("#")}
    keys = {"%s %s" % (k, key) for k, key, _ in hits}
    if "--update-allow" in argv:
        with open(ALLOW, "w", encoding="utf-8") as fh:
            fh.write("# continuity_check.py known hits (each one a finding to fix; remove the line when fixed)\n")
            for k in sorted(keys):
                fh.write(k + "\n")
        print("continuity_check: wrote %d allowed hits to %s" % (len(keys), ALLOW))
        return 0
    new = [(k, key, t) for k, key, t in hits if "%s %s" % (k, key) not in allow]
    stale = sorted(allow - keys)
    if "--terms" in argv:
        for arc in ARCS:
            for term, (i, bid) in sorted(tr[arc].items(), key=lambda x: x[1][0]):
                print("%s  %-20s beat %3d  %s" % (arc, term, i, bid))
    shown = new if "--strict" in argv else [(k, key, t) for k, key, t in hits]
    for k, key, t in shown:
        print("%s %s\n    %s" % (k, key, t[:220]))
    print("continuity_check: %d LEAK, %d SPOILER (%d allowed, %d new, %d stale allow lines)" % (
        sum(1 for h in hits if h[0] == "LEAK"), sum(1 for h in hits if h[0] == "SPOILER"),
        len(hits) - len(new), len(new), len(stale)))
    for s in stale:
        print("  stale allow (fixed, remove it): " + s)
    if "--strict" in argv and new:
        print("continuity_check FAIL: %d new hit(s); fix the line or gate it (talk.json flag:<f> key or a when dict)" % len(new))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
