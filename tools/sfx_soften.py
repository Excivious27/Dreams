#!/usr/bin/env python3
"""Soften the sound effects: even out loudness and take the edge off harsh highs.

    python3 tools/sfx_soften.py [--dry] [--only a,b] [--force]

Tom (Round 13): "lots of the sound effects still sound quite artificial and a
bit abrasive". Every CC0 effect was peak-normalised to -1 dBFS on import, so a
sustained crackle (stun, emp, spells) played ~20 dB louder than a twig snap.
For each audio/sfx/*.ogg this:

  * measures the loudest 100 ms (RMS) and how much energy sits above 4 kHz;
  * filters: 50 Hz high-pass, a gentle high shelf at 5 kHz and a low-pass whose
    strength follows the harshness (bright metal and electric sounds get more);
  * sets the level toward one target per kind (steps and UI quieter), moving
    each file 75 % of the way there (so a boom stays bigger than a click),
    never more than +6 dB up, and keeps peaks at or under -1.5 dBFS;
  * adds 3 ms fades so nothing clicks.

Jingles (j_*), ambience and music are left alone. Files are hardlinked across
worktrees: each is written to a temp file, the original removed, then moved in.
audio/sfx/SOFTEN_LOG.json records before/after per file and the output's md5,
so a second run skips files it already softened (--force redoes them).
"""
import argparse, glob, hashlib, json, os, subprocess, sys
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SFX = os.path.join(ROOT, "audio", "sfx")
LOG = os.path.join(SFX, "SOFTEN_LOG.json")
SKIP = ("j_",)
# Loudest-100ms RMS targets (dBFS) by name prefix; Music.GROUP_DB sits on top in game.
TARGETS = [("step_", -20.0), ("ui_", -20.0), ("menu_", -20.0), ("talk_blip", -20.0), ("keypress", -20.0),
           ("page", -19.0), ("equip", -19.0), ("coin", -18.0), ("pickup", -18.0)]
DEFAULT_TARGET = -16.0
SR = 44100


def md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()


def decode(p, ch=1):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", p, "-ac", str(ch), "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32)


def measure(x):
    if len(x) < 64:
        return {"rms": -90.0, "peak": -90.0, "hf": 0.0}
    w = int(SR * 0.1)
    if len(x) > w:
        c = np.convolve(x.astype(np.float64) ** 2, np.ones(w) / w, "valid")
        rms = float(np.sqrt(c.max()))
    else:
        rms = float(np.sqrt(np.mean(x.astype(np.float64) ** 2)))
    X = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1 / SR)
    hf = float(X[f > 4000].sum() / (X.sum() + 1e-12))
    return {"rms": round(20 * np.log10(rms + 1e-9), 1), "peak": round(20 * np.log10(float(np.max(np.abs(x))) + 1e-9), 1), "hf": round(hf, 3)}


def target(name):
    for k, t in TARGETS:
        if name.startswith(k):
            return t
    return DEFAULT_TARGET


def chain(hf, name):
    # Harsher sounds get a lower low-pass and a deeper shelf; everything loses a little fizz.
    if hf > 0.6:
        lp, shelf = 8500, -6.0
    elif hf > 0.35:
        lp, shelf = 10000, -4.5
    elif hf > 0.15:
        lp, shelf = 12000, -3.0
    else:
        lp, shelf = 14000, -1.5
    if name.startswith("step_grass") or name.startswith("step_leaves"):
        lp, shelf = min(lp, 6500), min(shelf, -5.0)  # soft swish, not crackle
    return lp, shelf, f"highpass=f=50,treble=g={shelf}:f=5000:t=s:w=0.7,lowpass=f={lp}:p=2"


def process(path, dry):
    name = os.path.basename(path)[:-4]
    info = json.loads(subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                                      "stream=channels,sample_rate", "-of", "json", path], capture_output=True, text=True).stdout)
    st = info["streams"][0]
    ch, sr = int(st.get("channels", 1)), int(st.get("sample_rate", SR))
    before = measure(decode(path))
    lp, shelf, af = chain(before["hf"], name)
    tmpw = path + ".soft.wav"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-af", af, "-ar", str(sr), "-ac", str(ch), "-c:a", "pcm_f32le", tmpw], check=True)
    mid = measure(decode(tmpw))
    t = target(name)
    gain = max(-16.0, min(6.0, (t - mid["rms"]) * 0.75))
    gain = min(gain, -1.5 - mid["peak"])  # peaks stay at or under -1.5 dBFS
    d = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", tmpw], capture_output=True, text=True).stdout.strip()
    dur = float(d or 0.0)
    fo = min(0.003, dur / 4)
    out = path + ".soft.ogg"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmpw, "-af",
                    f"volume={gain:.2f}dB,afade=t=in:d={fo},afade=t=out:st={max(0.0, dur - fo):.4f}:d={fo}",
                    "-c:a", "libvorbis", "-q:a", "4", out], check=True)
    os.remove(tmpw)
    after = measure(decode(out))
    rec = {"before": before, "after": after, "gain_db": round(gain, 2), "lowpass": lp, "shelf_db": shelf}
    if dry:
        os.remove(out)
        return rec
    os.remove(path)  # hardlinked: never write through
    os.rename(out, path)
    rec["md5"] = md5(path)
    return rec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    log = json.load(open(LOG)) if os.path.exists(LOG) else {}
    only = set(x for x in a.only.split(",") if x)
    n = 0
    for p in sorted(glob.glob(os.path.join(SFX, "*.ogg"))):
        name = os.path.basename(p)[:-4]
        if name.startswith(SKIP) or (only and name not in only and name.rsplit("_", 1)[0] not in only):
            continue
        if not a.force and name in log and log[name].get("md5") == md5(p):
            continue  # already softened
        rec = process(p, a.dry)
        log[name] = rec
        n += 1
        b, f = rec["before"], rec["after"]
        print(f"{name:24s} rms {b['rms']:6.1f} -> {f['rms']:6.1f}  peak {b['peak']:5.1f} -> {f['peak']:5.1f}  hf {b['hf']:.2f} -> {f['hf']:.2f}  lp {rec['lowpass']}")
    if not a.dry:
        with open(LOG + ".new", "w") as fh:
            json.dump(log, fh, indent=1, sort_keys=True)
        os.replace(LOG + ".new", LOG)
    print(f"softened {n} files" + (" (dry run)" if a.dry else ""))


if __name__ == "__main__":
    main()
