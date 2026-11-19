#!/usr/bin/env python3
"""Every sound the game asks for exists (run by check.sh).

Checks
  * sfx("name"[, "fallback"]) literals: name or fallback has a file in audio/sfx
    (.ogg/.wav, or a _2/_3 take);
  * names returned by the sound pickers (spell_sound, _death_sound, station_sound,
    _gun_sound, boss_track) and footsteps (step_<word>);
  * music: play("x") literals, AREA_MUSIC / INTERIOR_MUSIC / BOSS_TRACKS / ONCE
    entries and data/regions.json "music" all exist in audio/music;
  * ambience beds/spots named in scripts/ambience.gd exist in audio/amb.
Prints a coverage table; exits 1 on any miss.
"""
import glob, json, os, re, sys
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
A = os.path.join(ROOT, "audio")


def have(folder, name, exts=(".ogg", ".wav")):
    return any(os.path.exists(os.path.join(A, folder, name + s + e)) for s in ("", "_2", "_3") for e in exts)


src = {f: open(f).read() for f in glob.glob(os.path.join(ROOT, "scripts", "*.gd"))}
allsrc = "\n".join(src.values())
bad = []
used_sfx = set()
for m in re.finditer(r'sfx\("([a-z_0-9]+)"(?:\s*,\s*"([a-z_0-9]+)")?\)', allsrc):
    n, fb = m.group(1), m.group(2)
    used_sfx.add(n)
    if not have("sfx", n) and not (fb and have("sfx", fb)):
        bad.append(f"sfx {n}" + (f" (fallback {fb})" if fb else ""))
for fn in ["spell_sound", "_death_sound", "station_sound", "_gun_sound"]:
    m = None
    for body in src.values():
        m = re.search(r'func %s\([^\n]*\n(.*?)(?=\n(?:static )?func |\Z)' % re.escape(fn), body, re.S)
        if m:
            break
    if not m:
        continue
    for n in set(re.findall(r'"([a-z_0-9]+)"\]', m.group(1)) + re.findall(r'return "([a-z_0-9]+)"', m.group(1))):
        used_sfx.add(n)
        if not have("sfx", n):
            bad.append(f"{fn} -> {n}")
for w in ["grass", "dirt", "sand", "stone", "wood", "snow", "water", "mud", "gravel", "leaves"]:
    if not have("sfx", "step_" + w):
        bad.append(f"step_{w}")
# music
tracks = set(re.findall(r'instance\([^()]*(?:\([^()]*\))?[^()]*\)\.play\("([a-z_0-9]+)"\)', allsrc))
for const in ["AREA_MUSIC", "INTERIOR_MUSIC"]:
    m = re.search(const + r' := \{(.*?)\}', allsrc, re.S)
    if m:
        tracks |= set(re.findall(r':\s*"([a-z_0-9]+)"', m.group(1)))
for const in ["BOSS_TRACKS", "ONCE"]:
    m = re.search(const + r' := \[(.*?)\]', allsrc, re.S)
    if m:
        tracks |= set(re.findall(r'"([a-z_0-9]+)"', m.group(1)))
for v in json.load(open(os.path.join(ROOT, "data", "regions.json"))).values():
    if isinstance(v, dict) and v.get("music"):
        tracks.add(v["music"])
for t in ["night", "rain", "winter", "farm_fall", "festival", "danger", "raid", "mine_deep", "battle_siege", "battle_escort", "shop_gang", "campaign_map", "credits"]:
    tracks.add(t)
for t in sorted(tracks):
    if not os.path.exists(os.path.join(A, "music", t + ".ogg")):
        bad.append(f"music {t}")
# ambience
amb = src.get(os.path.join(ROOT, "scripts", "ambience.gd"), "")
beds = set(re.findall(r'out\["([a-z_0-9]+)"\]', amb))
spots = set(re.findall(r'rules\.append\(\["([a-z_0-9]+)"', amb)) | set(re.findall(r'_spot\("([a-z_0-9]+)"', amb))
for b in beds:
    if not os.path.exists(os.path.join(A, "amb", b + ".ogg")):
        bad.append(f"bed {b}")
for s in spots:
    if not have("amb", "spot_" + s):
        bad.append(f"spot {s}")

real_sfx = {os.path.basename(p).rsplit(".", 1)[0] for p in glob.glob(os.path.join(A, "sfx", "*.ogg"))}
real_music = {l.strip() for l in open(os.path.join(A, "music", "REAL.txt")) if l.strip() and not l.startswith("#")}
all_music = {os.path.basename(p)[:-4] for p in glob.glob(os.path.join(A, "music", "*.ogg"))}
print(f"sfx asked for: {len(used_sfx)} names, real recordings/ACE files: {len(real_sfx)}")
print(f"music: {len(tracks)} tracks wired, {len(real_music & all_music)}/{len(all_music)} real (ACE)")
print(f"ambience: {len(beds)} beds, {len(spots)} spots")
placeholders = sorted(all_music - real_music)
if placeholders:
    print("music still placeholder:", " ".join(placeholders))
if bad:
    print("MISSING:", "; ".join(sorted(set(bad))))
    sys.exit(1)
print("sfx_audit: 0 missing")
