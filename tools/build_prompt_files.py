#!/usr/bin/env python3
"""Rebuilds docs/ART-PROMPTS-16.md and -17.md from their sources in docs/src/
so that every copy-paste prompt asks for at most 3 images, carries every rule
it depends on (it works pasted into a fresh chat), and labels each image in its
own clearly separated section. Images already uploaded (found in art/incoming/)
are listed as received instead.   Run: python3 tools/build_prompt_files.py
"""
import os, re
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = f"{R}/docs"
have = {f.split(".")[0] for f in os.listdir(f"{R}/art/incoming")}
# An upload under another name still counts by its wNNN prefix (w267_penguin_cutscenes = w267_cutscene_panels_a).
have |= {m.group(0) for m in (re.match(r"w\d+[a-z]?(?=_)", f) for f in os.listdir(f"{R}/art/incoming")) if m}
WORDS = ["ZERO", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX"]


def para(text, start):
    for p in text.split("\n\n"):
        if p.strip().startswith(start):
            return p.strip()
    return ""


p13 = open(f"{D}/ART-PROMPTS-13.md").read()
p12 = open(f"{D}/ART-PROMPTS-12.md").read()
p15 = open(f"{D}/ART-PROMPTS-15.md").read()
p16raw = open(f"{D}/src/ART-PROMPTS-16-raw.md").read()
grid_rule = re.search(r"Character sheets use the GRID RULE:.*?(?=Save every image|$)", para(p13, "RULES"), re.S).group(0).strip()
DEFS = {
    "SEAMLESS": para(p16raw, "SEAMLESS RULE"),
    "STATION GRID": para(p15, "STATION GRID"),
    "GRID RULE": "GRID RULE (character sheets): " + grid_rule.replace("Character sheets use the GRID RULE: ", ""),
}
WHO = para(p13, "WHO IS WHO") + "\n\n" + para(p13, "Attach the penguin-arc")
m = re.search(r"THE SEVEN.*?(?=\n\nHERO SHEET|\n---)", p12, re.S)
SEVEN = m.group(0).strip() if m else ""
PENGUIN_FILES = re.compile(r"w26[2-9]|w27[01]|w251b|w253b")


def parse(raw):
    """[(title, notes, shared_paragraphs, [(file, text)])] per batch, plus header paragraphs."""
    head, _, rest = raw.partition("\n## BATCH")
    rest = re.split(r"\n={20,}\n", rest)[0]  # coverage table / left-out notes are for Claude, not for the paste
    batches = []
    for chunk in ("## BATCH" + rest).split("\n## BATCH")[0:]:
        chunk = chunk if chunk.startswith("## BATCH") else "## BATCH" + chunk
        lines = chunk.strip("\n-").splitlines()
        title = re.sub(r"^## BATCH \d+ — ", "", lines[0]).strip()
        title = re.sub(r"\s*\([^)]*images?[^)]*\)", "", title)
        title = re.sub(r":\s*\d+ images,\s*", ": ", title)
        notes, qlines = [], []
        for ln in lines[1:]:
            if ln.startswith(">"):
                qlines.append(ln[1:].strip())
            elif ln.strip() and ln.strip() != "---":
                notes.append(ln.strip())
        paras, cur = [], []
        for ln in qlines + [""]:
            if ln == "":
                if cur:
                    paras.append(" ".join(cur)); cur = []
            elif ln.startswith("IMAGE") and cur:
                paras.append(" ".join(cur)); cur = [ln]
            else:
                cur.append(ln)
        shared, images = [], []
        for p in paras:
            mm = re.match(r'IMAGE\s*\d*\s*"([^"]+)"\s*[:,]?\s*(.*)', p, re.S)
            if mm:
                images.append((mm.group(1), mm.group(2).strip()))
            else:
                shared.append(p)
        batches.append((title, notes, shared, images))
    return head, batches


def chunks(n):
    k = (n + 2) // 3  # Tom: ChatGPT copes with 2-3 images per prompt, no more
    base, extra = divmod(n, k)
    out, i = [], 0
    for j in range(k):
        size = base + (1 if j < extra else 0)
        out.append((i, i + size)); i += size
    return out


def build(raw, num, out_path, title, intro):
    head, batches = parse(raw)
    rules = para(head, "RULES")
    skill_grid = para(head, "SKILL ICON GRID")
    # The file's own rules (ICON RULE, PROP RULE...) and its own SEAMLESS RULE travel with its prompts.
    defs = dict(DEFS)
    for hp in head.split("\n\n"):
        mm = re.match(r"([A-Z][A-Z ]*? RULE)\b", hp.strip())
        if mm and not hp.strip().startswith("RULES"):
            k = mm.group(1).replace(" RULE", "") if mm.group(1).replace(" RULE", "") in DEFS else mm.group(1)
            if k not in DEFS or k == "SEAMLESS":
                defs[k] = hp.strip()
    L = [f"# Dreams — Art Prompts {num}: {title}\n", intro + "\n",
         "HOW TO USE: each PROMPT below is one copy-paste into ChatGPT. It asks for at most 3 images and carries every rule it needs, so you can paste it into a fresh chat. Ask for the images one at a time if ChatGPT stops early (\"now image 2\"). Save each image under its exact file name and upload it here.\n"]
    received, n_prompt, n_img = [], 0, 0
    for title_b, notes, shared, images in batches:
        todo = [im for im in images if not (im[0].split(".")[0] in have or im[0].split("_")[0] in have)]
        received += [im[0] for im in images if (im[0].split(".")[0] in have or im[0].split("_")[0] in have)]
        if not todo:
            continue
        parts = chunks(len(todo))
        for pi, (a, b) in enumerate(parts):
            n_prompt += 1
            group = todo[a:b]
            n_img += len(group)
            text = " ".join(shared) + " " + " ".join(t for _, t in group)
            label = f"{num}-{n_prompt}"
            sub = f" (part {pi + 1} of {len(parts)})" if len(parts) > 1 else ""
            L.append("\n---\n")
            L.append(f"## PROMPT {label} — {title_b}{sub} · {len(group)} image{'s' if len(group) > 1 else ''}\n")
            for nt in notes:
                if not nt.startswith("STATUS"):
                    L.append(nt + "\n")
            q = [f"PROMPT {label}. Make {WORDS[len(group)]} SEPARATE IMAGE{'S' if len(group) > 1 else ''}, each one its own picture, saved under the exact file name given.", "",
                 "RULES FOR EVERY IMAGE: " + rules.replace("RULES THAT APPLY TO EVERY IMAGE: ", "")]
            for key, d in defs.items():
                if key in text and d:
                    q += ["", d]
            if "SKILL ICON GRID" in text and skill_grid:
                q += ["", skill_grid]
            if any(PENGUIN_FILES.search(f) for f, _ in group):
                q += ["", WHO.replace("\n\n", " ").replace("\n", " ")]
                if SEVEN:
                    q += ["", SEVEN.replace("\n", " ")]
            for sp in shared:
                sp2 = re.sub(r"Make [A-Z]+ SEPARATE IMAGES,?", "For every image in this prompt:", sp)
                q += ["", "FOR THIS PROMPT: " + sp2]
            for i, (f, t) in enumerate(group, 1):
                q += ["", f"■■■ IMAGE {i} of {len(group)} — FILE NAME: \"{f}\" ■■■", t]
            q += ["", f"(End of PROMPT {label}: {len(group)} image{'s' if len(group) > 1 else ''}.)"]
            L.append("\n".join("> " + x if x else ">" for x in q) + "\n")
    if received:
        L.append("\n---\n")
        L.append("## Already received (thank you)\n")
        L.append(", ".join(received) + "\n")
    open(out_path, "w").write("\n".join(L))
    return n_prompt, n_img


a = build(p16raw, "16", f"{D}/ART-PROMPTS-16.md", "clean ground, cliffs and stairs, the beach, the mines, battles, colonies, the lieutenants",
          "WHAT THIS COVERS, most important first: big one-piece cliffs, ramps and stair sets; the beach and the marsh; organic mine caves; the conquest battles; the four merkitty colonies; the President's eight lieutenants; the two town projects; everything still owed from Prompts 15 (Marisol and Bo, the Marked, Gift effects, the chrome); missing portraits.")
p17raw = open(f"{D}/src/ART-PROMPTS-17-raw.md").read()
b = build(p17raw, "17", f"{D}/ART-PROMPTS-17.md", "skill trees, the last stand-ins, and Prompts 13",
          "WHAT THIS COVERS, most important first: icons for all 520 skill-tree nodes and the Sun Haven-style skills screen; Prompts 13 again (the penguin book's creatures and places, never came back); the last item icons; the new screens; the four ending paintings; the President's new look; the app icon.")
print("16:", a, "17:", b)
p18raw = open(f"{D}/src/ART-PROMPTS-18-raw.md").read()
c = build(p18raw, "18", f"{D}/ART-PROMPTS-18.md", "the pup, moving colony bosses, last icons, night lights, the Hollow Heart, fixes",
          "WHAT THIS COVERS, most important first: one clean pup sheet and gear that sits on it; moving bosses for three colonies; the last icons (new items, spells, mail and goal-line marks); night glow for lamps and windows; the Hollow Heart's landmarks and people; small fixes; the hidden chests, caches and journal pages.")
print("18:", c)
p19raw = open(f"{D}/src/ART-PROMPTS-19-raw.md").read()
DEFS["SEAMLESS"] = para(p19raw, "SEAMLESS RULE")
DEFS["BLOB RULE"] = para(p19raw, "BLOB RULE")
d = build(p19raw, "19", f"{D}/ART-PROMPTS-19.md", "clean edges everywhere, interiors, and the last stand-ins",
          "WHAT THIS COVERS, most important first: water edges (rivers, ponds, lakes, the beach, bog and cave water); ground-to-ground edges (grass to sand, dirt, snow, dry grass, mud); cliffs and stairs in every material; paths and paving; the farm (tilled soil, pond bank, fences); house and shop interiors; colony, moon and battle ground; the last stand-ins (gangster walk cycles, the President, enemy attacks, partner ability effects, ore nodes, icons, props).")
print("19:", d)
p20raw = open(f"{D}/src/ART-PROMPTS-20-raw.md").read()
e = build(p20raw, "20", f"{D}/ART-PROMPTS-20.md", "what the loop-1 audit found",
          "WHAT THIS COVERS, most important first: farm fixes (clean sprinklers, tall orchard trees, incubator and silo); the ferry and Pip the ferry-cat; the lookout, the crystal pylon and crystal trees; small screen pieces (rally icons, keeper pointer, bite meter, quality stars, close button, glints); story panels for both arcs and Grandfather Auk's ghost; two hero cards; the villagers' own walking sheets and winter portraits.")
print("20:", e)
p21raw = open(f"{D}/src/ART-PROMPTS-21-raw.md").read()
f21 = build(p21raw, "21", f"{D}/ART-PROMPTS-21.md", "what the loop-2 audit found",
            "WHAT THIS COVERS, most important first: rooms that look finished (wall tops, night windows, props for each shop); water buildings without painted water; Biscuit the old dog, the gangster opening panel and an arcade ticket booth; withered plants and wind-up warning icons.")
print("21:", f21)
p22raw = open(f"{D}/src/ART-PROMPTS-22-raw.md").read()
f22 = build(p22raw, "22", f"{D}/ART-PROMPTS-22.md", "what the loop-3 audit found",
            "WHAT THIS COVERS: room pieces that came back with words painted on them (tables) or under the wrong name (the barrels that were a life ring), redrawn clean.")
print("22:", f22)
p23raw = open(f"{D}/src/ART-PROMPTS-23-raw.md").read()
f23 = build(p23raw, "23", f"{D}/ART-PROMPTS-23.md", "what the loop-4 audit found",
            "WHAT THIS COVERS, most important first: boss banners for the seven bosses that show no card; the five boss Gifts with no effect strip; party cards for the fifteen partners who show a plain list row; the six new clothes; headgear that vanishes when worn; portraits for twelve speakers; small leftovers; Mabel's own walking sheet.")
print("23:", f23)
p24raw = open(f"{D}/src/ART-PROMPTS-24-raw.md").read()
f24 = build(p24raw, "24", f"{D}/ART-PROMPTS-24.md", "what the loop-5 audit found",
            "WHAT THIS COVERS, most important first: faces for Big Grump and the Grump Commander; the hero's dialogue face in the six new outfits; missing pet poses for five dog breeds and three cats; attack frames for the golem and the shard.")
print("24:", f24)
p25raw = open(f"{D}/src/ART-PROMPTS-25-raw.md").read()
f25 = build(p25raw, "25", f"{D}/ART-PROMPTS-25.md", "what the loop-6 audit found",
            "WHAT THIS COVERS, most important first: the hero's face in the Neon Jacket and Ceremony Coat; a proper Big Grump boss sheet; ability button icons for 19 partners; icons for the 15 special skill unlocks.")
print("25:", f25)
p26raw = open(f"{D}/src/ART-PROMPTS-26-raw.md").read()
f26 = build(p26raw, "26", f"{D}/ART-PROMPTS-26.md", "what the loop-7 audit found",
            "WHAT THIS COVERS: seamless glowing ground (teal moss and violet soil) for the Hollow Heart, Jungle and Kelp colony; storm puddles.")
print("26:", f26)
p27raw = open(f"{D}/src/ART-PROMPTS-27-raw.md").read()
f27 = build(p27raw, "27", f"{D}/ART-PROMPTS-27.md", "what the loop-8 audit found",
            "WHAT THIS COVERS: seamless ground and path squares for the Wastes, Sky and Jungle (soft patches and paths); one sheet of the last 21 item icons, which replaces three older icon sheets (17 w354, 18 w369, 19 w421).")
print("27:", f27)
p28raw = open(f"{D}/src/ART-PROMPTS-28-raw.md").read()
f28 = build(p28raw, "28", f"{D}/ART-PROMPTS-28.md", "what the loop-9 audit found",
            "WHAT THIS COVERS, most important first: dialogue faces for six villagers whose portrait is a different person from their walking sprite; fight poses for three dog breeds, so a pet stays the same dog in a fight.")
print("28:", f28)
p29raw = open(f"{D}/src/ART-PROMPTS-29-raw.md").read()
f29 = build(p29raw, "29", f"{D}/ART-PROMPTS-29.md", "what the loop-10 audit found",
            "WHAT THIS COVERS, most important first: everyday poses (sit, sleep, eat, dance, umbrella...) for 15 villagers so they stay the same person as their face; seasonal outfits for 10 villagers drawn in their new look; then three optional sheets (Marlowe and Benno with their hats, lamps for the deep mines, snowy groves) and a fallback for two cut-off icon rows.")
print("29:", f29)
