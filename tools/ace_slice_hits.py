#!/usr/bin/env python3
"""Cut an ACE "kit" or jingle render into separate one-shot sounds.

    python3 tools/ace_slice_hits.py <render.mp3> <outdir> [--min 0.08] [--max 4.0] [--gap 0.18] [--thresh 32]

Finds the quiet gaps (level below the piece's loud level minus --thresh dB for at
least --gap seconds), cuts each sounding part, trims it, adds a 5 ms fade-in and a
short fade-out, normalises its peak to -1 dBFS and writes outdir/hit_NN.wav plus
outdir/hits.json (start, length, peak, brightness) so names can be assigned.
A part longer than --max is split at its quietest point (a jingle sometimes runs on).
"""
import argparse, json, os, subprocess, wave
import numpy as np

def load(p, sr=44100):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-ac", "1", "-ar", str(sr), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).copy(), sr

def write(p, x, sr):
    x = np.clip(x, -1, 1)
    with wave.open(p, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes((x * 32767).astype(np.int16).tobytes())

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("out")
    ap.add_argument("--min", type=float, default=0.08)
    ap.add_argument("--max", type=float, default=4.0)
    ap.add_argument("--gap", type=float, default=0.18)
    ap.add_argument("--thresh", type=float, default=32.0)
    ap.add_argument("--onsets", action="store_true", help="cut at note onsets (renders played without gaps)")
    ap.add_argument("--keep", type=int, default=24, help="with --onsets: keep the N cleanest notes")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    x, sr = load(a.src)
    hop = int(0.01 * sr)
    n = len(x) // hop
    env = np.sqrt(np.mean(x[:n * hop].reshape(n, hop) ** 2, axis=1) + 1e-12)
    db = 20 * np.log10(env)
    loud = np.percentile(db, 95)
    on = db > loud - a.thresh
    gap = int(a.gap / 0.01)
    parts, i = [], 0
    while i < n:
        if not on[i]:
            i += 1; continue
        j, quiet = i, 0
        while j < n and quiet < gap:
            quiet = quiet + 1 if not on[j] else 0
            j += 1
        parts.append((i, j - quiet))
        i = j
    out, k = [], 0
    def emit(s, e):
        nonlocal k
        seg = x[s * hop:e * hop].copy()
        if len(seg) < a.min * sr:
            return
        fi = int(0.005 * sr); fo = min(int(0.06 * sr), len(seg) // 3)
        seg[:fi] *= np.linspace(0, 1, fi); seg[-fo:] *= np.linspace(1, 0, fo)
        pk = float(np.max(np.abs(seg))) or 1.0
        seg *= 0.89 / pk
        spec = np.abs(np.fft.rfft(seg[: min(len(seg), sr)]))
        fr = np.fft.rfftfreq(min(len(seg), sr), 1 / sr)
        bright = float((spec * fr).sum() / (spec.sum() + 1e-9))
        k += 1
        nm = f"hit_{k:02d}.wav"
        write(os.path.join(a.out, nm), seg, sr)
        out.append({"file": nm, "start": round(s * 0.01, 2), "len": round((e - s) * 0.01, 2),
                    "peak_db": round(20 * np.log10(pk), 1), "bright_hz": round(bright)})
    if a.onsets:
        # spectral-flux onsets on 10 ms frames
        win = 1024
        frames = [x[i:i + win] * np.hanning(win) for i in range(0, len(x) - win, hop)]
        S = np.abs(np.fft.rfft(np.array(frames), axis=1))
        flux = np.maximum(0, np.diff(np.log1p(S), axis=0)).sum(axis=1)
        flux = np.concatenate([[0], flux])
        thr = np.median(flux) + 1.5 * np.std(flux)
        ons = [i for i in range(1, len(flux) - 1) if flux[i] > thr and flux[i] >= flux[i - 1] and flux[i] >= flux[i + 1]]
        clean = []
        for k2, o in enumerate(ons):
            if clean and o - clean[-1] < 8:
                continue
            clean.append(o)
        segs = []
        for k2, o in enumerate(clean):
            e = clean[k2 + 1] if k2 + 1 < len(clean) else n
            e = min(e, o + int(a.max / 0.01))
            if (e - o) * 0.01 < a.min:
                continue
            # cleanliness: strong attack, then decay (not a smear of overlapping notes)
            seg_db = db[o:e]
            score = float(flux[o]) + 0.1 * float(seg_db[0] - seg_db[-1]) if len(seg_db) > 1 else 0
            segs.append((score, max(0, o - 1), e))
        segs.sort(key=lambda t: -t[0])
        for _, s0, e0 in sorted(segs[:a.keep], key=lambda t: t[1]):
            emit(s0, e0)
        json.dump(out, open(os.path.join(a.out, "hits.json"), "w"), indent=1)
        print(f"{len(out)} onset hits from {len(clean)} onsets")
        return
    for s, e in parts:
        while (e - s) * 0.01 > a.max:
            lo = s + int(a.min / 0.01) + 1
            hi = s + int(a.max / 0.01)
            cut = lo + int(np.argmin(db[lo:hi])) if hi > lo else hi
            emit(s, cut); s = cut
        emit(s, e)
    json.dump(out, open(os.path.join(a.out, "hits.json"), "w"), indent=1)
    print(f"{len(out)} hits from {len(parts)} parts")

if __name__ == "__main__":
    main()
