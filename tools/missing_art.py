#!/usr/bin/env python3
"""Lists everything the game refers to that has no art yet (it falls back to a
stand-in): item icons, enemy sprites, villager/crew portraits, character strips,
station tiers, and literal Art.tex/Art.has names in scripts. Writes docs/MISSING-ART.md.
"""
import json, re, glob, os
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
man = json.load(open(f"{R}/art/gen/manifest.json"))
def has(g, n):
    # manifest entry, or a loose file (casino/arcade art loads straight from art/gen/<group>/<name>.png)
    return (g in man and n in man[g]) or os.path.exists(f"{R}/art/gen/{g}/{n}.png")
def J(p): return json.load(open(f"{R}/data/{p}"))
items = J("items.json"); enemies = J("enemies.json").get("enemies", {}); npcs = J("npcs.json")
crew = J("crew.json")["members"]; builds = J("buildings.json")
out = {}
# items: icon by id or the item's own "icon" alias (as Hud.icon_for does; seeds share "seeds"; tools have tier icons)
miss = [i for i, d in items.items() if not has("items", i) and not has("items", str(d.get("icon", ""))) and not has(*(str(d.get("icon", "")).rsplit("/", 1) + [""])[:2]) and not i.endswith("_seed") and d.get("type") not in ("tool",)]
out["Item icons"] = miss
# enemies: characters/<sprite or kind>
miss = []
for k, d in enemies.items():
    art = str(d.get("art", "grump" if k == "big_grump" else k))
    grp = f"characters/{d['char']}" if d.get("char") else (f"characters/{k[5:]}" if k.startswith("thug_") else ("characters/president" if k == "president" else f"enemies/{art}"))
    if grp not in man:
        miss.append(f"{k} ({d.get('name', k)})")
out["Enemy sprites"] = miss
# portraits
miss = []
for k, d in npcs.items():
    # The game also looks for their own painting: npc_<id>, npc_<id>_normal, npc_<id>_<season>.
    cands = [f"portraits/{d.get('portrait', k)}", f"portraits/npc_{k}", f"portraits/npc_{k}_normal"]
    if not any(pg in man and "neutral" in man[pg] for pg in cands):
        miss.append(f"{k} ({d['name']})")
for k, d in crew.items():
    pg = f"portraits/{d.get('sprite', k)}"
    if pg not in man:
        miss.append(f"{k} ({d['name']}, crew)")
out["Dialogue portraits"] = miss
# station tiers: buildings/<id>_<tier> or <id>
miss = []
for bid, b in builds.items():
    if not isinstance(b, dict): continue
    for t, td in enumerate(b.get("tiers", []), 1):
        spr = str(td.get("sprite", f"{bid}_{t}")) if isinstance(td, dict) else f"{bid}_{t}"
        grp = str(b.get("group", "buildings"))
        if not has(grp, spr) and not has("buildings", spr) and not has("stations", spr) and not has("props", spr):
            miss.append(f"{bid} tier {t}")
out["Stations and buildings"] = miss
# literal Art lookups in code
lit = set()
for f in glob.glob(f"{R}/scripts/*.gd"):
    for g, n in re.findall(r'Art\.(?:tex|has)\("([a-z_/0-9]+)", "([a-z_0-9]+)"\)', open(f).read()):
        if not has(g, n): lit.add(f"{g}/{n}")
out["Named art the code asks for"] = sorted(lit)
# skill-tree node icons: ui/node_<skill>_<id> for every non-unlock node (unlock nodes draw what they unlock)
miss = []
try:
    skills = J("skills.json").get("skills", {})
except Exception:
    skills = {}
for sk, sd in sorted(skills.items()):
    if not isinstance(sd, dict):
        continue
    gone = [str(n.get("id")) for n in sd.get("nodes", []) if isinstance(n, dict) and not n.get("unlock") and not has("ui", f"node_{sk}_{n.get('id')}")]
    if gone:
        miss.append(f"{sk}: {len(gone)} node icons (item-icon fallback) - " + ", ".join(gone))
out["Skill node icons"] = miss
# ranch (C11a): every species kind's strips, building tier looks, product/station/interior art.
# Reads data/ranch.json (tools/gen_ranch.py) when it lists species, else art/gen/animals/_ranch_art.json.
miss = []
RANCH_ANIMS = ["idle", "walk", "eat", "sleep", "sad", "happy", "produce"]
ALIAS = {"sad": "hurt", "produce": "happy"}  # w175 families (goat/sheep/llama) draw these poses
try:
    ranch = J("ranch.json")
except Exception:
    ranch = {}
art_meta = {}
if os.path.exists(f"{R}/art/gen/animals/_ranch_art.json"):
    art_meta = json.load(open(f"{R}/art/gen/animals/_ranch_art.json"))
if os.path.exists(f"{R}/art/gen/animals/_ranch_art_c11b.json"):  # C11b exotic/fantastic/lab table (tools/slice_c11b.py)
    for _k, _v in json.load(open(f"{R}/art/gen/animals/_ranch_art_c11b.json")).items():
        if isinstance(_v, list):
            art_meta[_k] = list(art_meta.get(_k, [])) + [x for x in _v if x not in art_meta.get(_k, [])]
        elif isinstance(_v, dict) and _k.startswith("_"):
            for _a, _b in _v.items():
                if isinstance(_b, list):
                    art_meta.setdefault(_k, {}).setdefault(_a, [])
                    art_meta[_k][_a] = list(art_meta[_k][_a]) + [x for x in _b if x not in art_meta[_k][_a]]
                else:
                    art_meta.setdefault(_k, {})[_a] = _b
        else:
            art_meta.setdefault(_k, _v)
species = {k: v for k, v in art_meta.items() if not k.startswith("_")}  # P6 kinds: the full pose set
# ranch.json species (gen_ranch schema: art.adult, art.variants[].art, art.baby [kind, strip], art.shorn): idle strips.
for sp, d in sorted((ranch.get("species") or {}).items() if isinstance(ranch.get("species"), dict) else []):
    art = d.get("art", {}) if isinstance(d, dict) else {}
    ks = [art.get("adult")] + [v.get("art") for v in art.get("variants", []) if isinstance(v, dict)] + [art.get("shorn")]
    for k in [x for x in ks if x]:
        if "idle" not in man.get(f"animals/{k}", {}):
            miss.append(f"{sp}: animals/{k} lacks idle (ranch.json)")
    b = art.get("baby")
    if isinstance(b, list) and len(b) == 2 and b[1] not in man.get(f"animals/{b[0]}", {}):
        miss.append(f"{sp}: animals/{b[0]} lacks {b[1]} (ranch.json baby)")
for sp, d in sorted(species.items()):
    kinds = [d.get("kind", sp)] + list(d.get("variants", [])) + list(d.get("rare", [])) + [d.get(k) for k in ("baby", "baby_kind", "shorn") if d.get(k)]
    for k in kinds:
        g = f"animals/{k}"
        if g not in man:
            miss.append(f"{sp}: animals/{k} (no strips)")
            continue
        need = ["hover", "fly"] if sp == "bees" else RANCH_ANIMS
        lack = [a for a in need if a not in man[g] and ALIAS.get(a, "-") not in man[g]]
        if lack:
            miss.append(f"{sp}: animals/{k} lacks " + ", ".join(lack))
blds = ranch.get("buildings") if isinstance(ranch.get("buildings"), dict) and ranch.get("buildings") else art_meta.get("_buildings", {})
for home, tiers in sorted(blds.items()):
    tl = tiers.get("tiers", tiers) if isinstance(tiers, dict) else {}
    items_ = tl.items() if isinstance(tl, dict) else enumerate(tl, 1)
    for t, td in items_:
        spr = str(td.get("sprite", f"{home}_{t}")) if isinstance(td, dict) else f"{home}_{t}"
        grp = str(td.get("group", "buildings")) if isinstance(td, dict) else "buildings"
        for look in ("", "_snow", "_night"):
            if not has(grp, spr + look) and not has("buildings", spr + look):
                miss.append(f"{home} tier {t}: {grp}/{spr}{look}")
for pid in ranch.get("products", {}) if isinstance(ranch.get("products"), dict) else []:
    d = items.get(pid, {})
    if not has("items", pid) and not has("items", str(d.get("icon", ""))):
        miss.append(f"product icon items/{pid}")
for i in art_meta.get("_items", []):
    if not has("items", i):
        miss.append(f"items/{i}")
for s in art_meta.get("_stations", []):
    if not has("stations", s):
        miss.append(f"stations/{s}")
for grp, ids in art_meta.get("_interior", {}).items():
    for i in ids:
        if not has(grp, i):
            miss.append(f"{grp}/{i}")
out["Ranch"] = miss
# art that exists but is unusable (reported by audits): redraw requests
out["Broken art to redraw"] = []  # Round 12 (image tool) redrew everything that was listed here + ([] if has("seamless", "teal_moss") else ["seamless/teal_moss (wrapping ground texture for colony_kelp)"]) + ([] if has("seamless", "violet_soil") else ["seamless/violet_soil (jungle soil patch)"])
with open(f"{R}/docs/MISSING-ART.md", "w") as fh:
    fh.write("# Missing art (generated by tools/missing_art.py)\n\nEverything below shows a code-drawn stand-in today.\n")
    for k, v in out.items():
        fh.write(f"\n## {k} ({len(v)})\n\n" + ("\n".join(f"- {x}" for x in v) if v else "- none") + "\n")
for k, v in out.items():
    print(k, len(v))
