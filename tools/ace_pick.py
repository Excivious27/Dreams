#!/usr/bin/env python3
"""Score ACE versions for game use and print the best one.

    python3 tools/ace_pick.py a.mp3 b.mp3 [--kind music]

Checks: length, clipping, long silences inside, and how well the end joins the
start (loop seam: loudness + spectral match of last vs first 3 s). Higher is better.
"""
import subprocess, sys, json
import numpy as np

def load(p, sr=22050):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-ac", "1", "-ar", str(sr), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32), sr

def spec(x):
    f = np.abs(np.fft.rfft(x * np.hanning(len(x))))
    bands = np.array_split(f, 24)
    v = np.log1p(np.array([b.mean() for b in bands]))
    return v / (np.linalg.norm(v) + 1e-9)

def trim_quiet(x, sr, tail_db=9.0, head_db=20.0):
    """Cut digital silence and a fade-out tail (game loops shouldn't dip).
    Returns (start, end) sample indices."""
    win = int(0.25 * sr)
    n = len(x) // win
    if n < 8:
        return 0, len(x)
    rms = np.sqrt(np.mean(x[:n * win].reshape(n, win) ** 2, axis=1) + 1e-12)
    db = 20 * np.log10(rms)
    med = np.median(db)
    i = 0
    while i < n - 1 and db[i] < med - head_db:
        i += 1
    j = n - 1
    while j > i and db[j] < med - tail_db:
        j -= 1
    return i * win, (j + 1) * win


def score(p):
    x, sr = load(p)
    a, b = trim_quiet(x, sr)
    x = x[a:b]
    d = len(x) / sr
    peak = float(np.max(np.abs(x)))
    win = int(0.5 * sr)
    rms = np.array([np.sqrt(np.mean(x[i:i + win] ** 2) + 1e-12) for i in range(0, len(x) - win, win)])
    db = 20 * np.log10(rms)
    med = np.median(db)
    holes = int(np.sum(db[4:-4] < med - 30))  # dropouts inside the piece
    n = 3 * sr
    head, tail = x[:n], x[-n:]
    seam_spec = float(np.dot(spec(head), spec(tail)))
    lvl = abs(20 * np.log10(np.sqrt(np.mean(head ** 2)) + 1e-9) - 20 * np.log10(np.sqrt(np.mean(tail ** 2)) + 1e-9))
    fade = max(0.0, float(med - db[-4:].mean()) - 6)  # a fade-out ending hurts a loop
    s = 100 * seam_spec - 1.5 * lvl - 2 * fade - 6 * holes - (20 if d < 60 else 0)
    return {"file": p, "score": round(float(s), 2), "dur": round(d, 1), "seam": round(seam_spec, 3),
            "lvl_diff": round(lvl, 1), "fade": round(fade, 1), "holes": holes, "peak": round(peak, 3)}

if __name__ == "__main__":
    files = [a for a in sys.argv[1:] if not a.startswith("--")]
    res = sorted((score(f) for f in files), key=lambda r: -r["score"])
    print(json.dumps(res, indent=1, default=float))
