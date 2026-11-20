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
for fn in ["spell_sound", "_death_sound", "station_sound", "_gun_sound", "gun_sound"]:
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
# Rec Center rooms (scripts/rec_audio.gd BEDS / SPOTS / RECORDS).
rec = src.get(os.path.join(ROOT, "scripts", "rec_audio.gd"), "")
for blk in re.findall(r'const BEDS := \{(.*?)\n\}', rec, re.S):
    beds |= set(re.findall(r'"([a-z_0-9]+)": -', blk))
for blk in re.findall(r'const SPOTS := \{(.*?)\n\}', rec, re.S):
    spots |= set(re.findall(r'\["([a-z_0-9]+)", ', blk))
for blk in re.findall(r'const RECORDS := \{(.*?)\n\}', rec, re.S):
    for t in re.findall(r'"([a-z_0-9]+)": "', blk):
        if not os.path.exists(os.path.join(A, "music", t + ".ogg")):
            bad.append(f"jukebox record {t}")
for b in beds:
    if not os.path.exists(os.path.join(A, "amb", b + ".ogg")):
        bad.append(f"bed {b}")
for s in spots:
    if not have("amb", "spot_" + s):
        bad.append(f"spot {s}")
for v in json.load(open(os.path.join(ROOT, "data", "regions.json"))).values():  # regions' own beds ("amb")
    for b in (v.get("amb", {}) if isinstance(v, dict) else {}):
        if not os.path.exists(os.path.join(A, "amb", b + ".ogg")):
            bad.append(f"region bed {b}")

# C6: every playable effect went through tools/sfx_soften.py (log md5 = file md5), takes of one name
# sit within TAKE_MAX dB of each other, and every bed is long enough and on the bed loudness target.
TAKE_MAX = 4.0
slog_p = os.path.join(A, "sfx", "SOFTEN_LOG.json")
slog = json.load(open(slog_p)) if os.path.exists(slog_p) else {}
import hashlib
def _md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()
unsoft = []
for p in sorted(glob.glob(os.path.join(A, "sfx", "*.ogg"))) + sorted(glob.glob(os.path.join(A, "amb", "spot_*.ogg"))):
    k = ("amb/" if os.sep + "amb" + os.sep in p else "") + os.path.basename(p)[:-4]
    if slog.get(k, {}).get("md5") != _md5(p):
        unsoft.append(k)
if unsoft:
    bad.append("not softened (run tools/sfx_soften.py): " + " ".join(unsoft))
groups = {}
for k, v in slog.items():
    if v.get("mode") == "jingle" or "after" not in v or "lk" not in v["after"]:
        continue
    b, _, n = k.rpartition("_")
    groups.setdefault(b if n in ("2", "3") and b else k, []).append(v["after"]["lk"])
for g, lks in sorted(groups.items()):
    if len(lks) > 1 and max(lks) - min(lks) > TAKE_MAX:
        bad.append(f"takes of {g} spread {max(lks) - min(lks):.1f} dB (> {TAKE_MAX})")
blog_p = os.path.join(A, "amb", "BED_LOG.json")
blog = json.load(open(blog_p)) if os.path.exists(blog_p) else {}
for b, v in sorted(blog.items()):
    if v.get("secs", 99) < 8.0:
        bad.append(f"bed {b} only {v['secs']} s (needs >= 8 s)")
    if abs(v.get("lufs", -26.0) - v.get("target", -26.0)) > 1.5:
        bad.append(f"bed {b} at {v['lufs']} LUFS (target {v.get('target')})")
# loop seams: the bed's last sample must flow into its first (no click each loop). Needs ffmpeg + numpy;
# skipped with a note where they are missing.
try:
    import shutil, subprocess
    import numpy as np
    if not shutil.which("ffmpeg"):
        raise ImportError("ffmpeg")
    for b in sorted(blog):
        p = os.path.join(A, "amb", b + ".ogg")
        if not os.path.exists(p):
            continue
        raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", p, "-ac", "1", "-f", "f32le", "-"], capture_output=True).stdout
        x = np.frombuffer(raw, np.float32)
        if len(x) < 1000:
            continue
        step = np.abs(np.diff(x))
        ref = float(np.percentile(step, 99)) + 1e-6
        jump = abs(float(x[0]) - float(x[-1]))
        if jump > max(3.0 * ref, 0.02):
            bad.append(f"bed {b} loop seam jumps {jump:.3f} (99th pct step {ref:.3f})")
except ImportError as e:
    print(f"loop seam check skipped ({e})")
# sounds nothing plays (warning only): step_* and takes are built at runtime
allcode = allsrc + "\n".join(open(f).read() for f in glob.glob(os.path.join(ROOT, "data", "*.json")))
unused = sorted(n for n in {os.path.basename(p)[:-4] for p in glob.glob(os.path.join(A, "sfx", "*.ogg"))}
                if not re.search(r"_[23]$", n) and not n.startswith("step_") and not re.search(r'"%s"' % re.escape(n), allcode))
if unused:
    print(f"unused sfx ({len(unused)}, warning): " + " ".join(unused))

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
