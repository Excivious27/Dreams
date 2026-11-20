#!/usr/bin/env python3
"""Loop-seam check for every looping song (check.sh step, < 60 s).

For each audio/music/*.ogg that is not a play-once track (Music.ONCE), decode the
last second and the second after the loop point (data/music_loops.json, default 0)
and fail when
  - the join (last sample -> loop point) steps more than STEP_X x the 99.9th pct
    sample step around it (an audible click / hard splice), or
  - the level jumps across the join (1 s RMS before vs after) by more than LEVEL_DB
    or than the song's own 98th-pct second-to-second change + 1 dB, whichever is
    larger (a song that drops to a soft intro or out of a fade every loop).
    python3 tools/music_loop_check.py [-v] [names...]
"""
import json, os, re, subprocess, sys
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MUSIC = os.path.join(ROOT, "audio", "music")
SR = 48000
STEP_X = 4.0
LEVEL_DB = 4.0


def once_tracks():
    src = open(os.path.join(ROOT, "scripts", "music.gd")).read()
    m = re.search(r"const ONCE := \[([^\]]*)\]", src)
    return set(re.findall(r'"([^"]+)"', m.group(1))) if m else set()


def dec(path, start=None, sseof=None, dur=1.0):
    a = ["ffmpeg", "-v", "error"]
    if sseof is not None:
        a += ["-sseof", str(-sseof)]
    a += ["-i", path]
    if start is not None:
        a += ["-ss", f"{start:.4f}"]
    a += ["-t", str(dur), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"]
    return np.frombuffer(subprocess.run(a, capture_output=True, check=True).stdout, np.float32)


def check(path, offset):
    tail = dec(path, sseof=1.0)
    head = dec(path, start=offset, dur=1.0)
    if len(tail) < SR // 2 or len(head) < SR // 2:
        return False, "too short to check"
    join = np.concatenate([tail, head])
    d = np.abs(np.diff(join))
    j = len(tail) - 1
    ref = float(np.percentile(np.delete(d, j), 99.9)) + 1e-4
    step = float(d[j]) / ref
    w = SR
    lv = lambda x: 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)
    jump = lv(head[:w]) - lv(tail[-w:])
    # A song may itself change level from one second to the next (a new section on a
    # downbeat): allow what the song does anyway (98th pct of its own 1 s steps).
    allow = LEVEL_DB if abs(jump) <= LEVEL_DB else max(LEVEL_DB, own_steps(path) + 1.0)
    ok = step <= STEP_X and abs(jump) <= allow
    return ok, f"step {step:.2f}x, level {jump:+.1f} dB (allowed {allow:.1f})"


def own_steps(path, sr=8000):
    a = ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(sr), "-f", "f32le", "-"]
    m = np.frombuffer(subprocess.run(a, capture_output=True, check=True).stdout, np.float32)
    k = len(m) // sr
    if k < 4:
        return 0.0
    db = 20 * np.log10(np.sqrt(np.mean(m[:k * sr].reshape(k, sr) ** 2, axis=1)) + 1e-9)
    return float(np.percentile(np.abs(np.diff(db)), 98))


def main():
    verbose = "-v" in sys.argv
    names = [a for a in sys.argv[1:] if not a.startswith("-")]
    loops_f = os.path.join(ROOT, "data", "music_loops.json")
    loops = json.load(open(loops_f)) if os.path.exists(loops_f) else {}
    once = once_tracks()
    files = sorted(f[:-4] for f in os.listdir(MUSIC) if f.endswith(".ogg"))
    bad = []
    for n in files:
        if n in once or (names and n not in names):
            continue
        ok, why = check(os.path.join(MUSIC, n + ".ogg"), float(loops.get(n, 0.0)))
        if verbose or not ok:
            print(("ok   " if ok else "FAIL ") + n + ": " + why)
        if not ok:
            bad.append(n)
    for n in loops:
        if n not in files:
            bad.append(n)
            print(f"FAIL {n}: in data/music_loops.json but no audio/music/{n}.ogg")
    print(f"music_loop_check: {len(bad)} bad of {len([f for f in files if f not in once])}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
