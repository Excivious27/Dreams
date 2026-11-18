#!/usr/bin/env python3
"""Generates placeholder chiptune music loops and sound effects.
Run: python3 tools/make_audio.py   (needs numpy + ffmpeg)
Outputs audio/music/<track>.ogg and audio/sfx/<name>.wav. Real tracks replace
these by using the same file names."""
import math, os, subprocess, wave, struct
import numpy as np

SR = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..", "audio")

NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}

def freq(name, octave):
    return 440.0 * 2 ** ((NOTE[name] - 9) / 12 + (octave - 4))

def square(f, t, duty=0.5):
    return np.where((t * f) % 1.0 < duty, 1.0, -1.0)

def tri(f, t):
    return 2 * np.abs(2 * ((t * f) % 1.0) - 1) - 1

def saw(f, t):
    return 2 * ((t * f) % 1.0) - 1

def env(n, a=0.01, d=0.1, s=0.6, r=0.1):
    t = np.linspace(0, 1, n)
    out = np.ones(n) * s
    na, nd, nr = int(n * a), int(n * d), int(n * r)
    if na: out[:na] = np.linspace(0, 1, na)
    if nd: out[na:na + nd] = np.linspace(1, s, nd)
    if nr: out[-nr:] = out[-nr:] * np.linspace(1, 0, nr)
    return out

def tone(f, dur, wave_fn="square", vol=0.3, duty=0.5, a=0.01, d=0.1, s=0.6, r=0.1):
    n = int(SR * dur)
    t = np.arange(n) / SR
    if wave_fn == "square": w = square(f, t, duty)
    elif wave_fn == "tri": w = tri(f, t)
    elif wave_fn == "saw": w = saw(f, t)
    elif wave_fn == "sine": w = np.sin(2 * math.pi * f * t)
    else: w = np.random.uniform(-1, 1, n)
    return w * env(n, a, d, s, r) * vol

def noise(dur, vol=0.2, decay=0.08):
    n = int(SR * dur)
    w = np.random.uniform(-1, 1, n)
    return w * np.exp(-np.arange(n) / (SR * decay)) * vol

def mix_into(buf, start, sig):
    s = int(start * SR)
    e = min(len(buf), s + len(sig))
    if e > s:
        buf[s:e] += sig[:e - s]

CHORDS = {
    "C": ["C", "E", "G"], "Am": ["A", "C", "E"], "F": ["F", "A", "C"], "G": ["G", "B", "D"],
    "Dm": ["D", "F", "A"], "Em": ["E", "G", "B"], "Bb": ["A#", "D", "F"], "Gm": ["G", "A#", "D"],
    "Cm": ["C", "D#", "G"], "Fm": ["F", "G#", "C"], "Ab": ["G#", "C", "D#"], "Eb": ["D#", "G", "A#"],
}

def compose(name, bpm, prog, scale, seed, bass_wave="tri", lead_wave="square", drums=True, arp=True,
            lead_vol=0.16, dark=False, bars_per_chord=1, duty=0.5):
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    total = bar * len(prog) * bars_per_chord
    buf = np.zeros(int(SR * total) + SR)
    t = 0.0
    last = None
    for ci, ch in enumerate(prog):
        notes = CHORDS[ch]
        for b in range(bars_per_chord):
            # Bass: root on 1 and 3, fifth on 2 and 4.
            for k in range(4):
                nm = notes[0] if k % 2 == 0 else notes[2]
                mix_into(buf, t + k * beat, tone(freq(nm, 2), beat * 0.9, bass_wave, 0.22, a=0.005, d=0.2, s=0.5, r=0.2))
            # Arp
            if arp:
                for k in range(8):
                    nm = notes[k % 3]
                    mix_into(buf, t + k * beat / 2, tone(freq(nm, 4), beat * 0.45, "tri", 0.08, a=0.005, d=0.3, s=0.3, r=0.3))
            # Lead melody: stepwise random walk on the scale, mostly chord tones.
            pos = t
            while pos < t + bar - 1e-6:
                dur = beat * rng.choice([0.5, 0.5, 1.0, 1.0, 1.5, 2.0])
                dur = min(dur, t + bar - pos)
                if rng.random() < 0.18:
                    pos += dur
                    continue
                if last is None or rng.random() < 0.4:
                    nm = notes[int(rng.integers(0, 3))]
                else:
                    i = scale.index(last) if last in scale else 0
                    i = max(0, min(len(scale) - 1, i + int(rng.integers(-2, 3))))
                    nm = scale[i]
                last = nm
                mix_into(buf, pos, tone(freq(nm, 5), dur * 0.9, lead_wave, lead_vol, duty=duty, a=0.01, d=0.2, s=0.5, r=0.2))
                pos += dur
            # Drums
            if drums:
                for k in range(4):
                    mix_into(buf, t + k * beat, tone(55, 0.12, "sine", 0.35, a=0.001, d=0.5, s=0.0, r=0.4))
                    if k % 2 == 1:
                        mix_into(buf, t + k * beat, noise(0.12, 0.18, 0.04))
                for k in range(8):
                    mix_into(buf, t + k * beat / 2, noise(0.04, 0.07, 0.01))
            t += bar
    buf = buf[:int(SR * total)]
    if dark:
        # Low-pass-ish smoothing for darker tracks.
        kernel = np.ones(6) / 6
        buf = np.convolve(buf, kernel, mode="same")
    buf = np.tanh(buf * 1.2) * 0.8
    write_track(name, buf)

def write_wav(path, buf):
    buf = np.clip(buf, -1, 1)
    with wave.open(path, "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((buf * 32767).astype("<i2").tobytes())

# Tracks Tom has replaced with real music. Never overwrite these with placeholders.
REAL_TRACKS = {"title", "arc_gangsters", "arc_penguins"}  # title.ogg = "Dreams" (ACE Music), original in audio/incoming/title-dreams.mp3

def write_track(name, buf):
    if name in REAL_TRACKS:
        print("kept real track", name)
        return
    os.makedirs(os.path.join(ROOT, "music"), exist_ok=True)
    tmp = f"/tmp/{name}.wav"
    write_wav(tmp, buf)
    out = os.path.join(ROOT, "music", f"{name}.ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3", out], check=True)
    print("wrote", out, f"{len(buf)/SR:.1f}s")

MAJ = ["C", "D", "E", "F", "G", "A", "B"]
AMIN = ["A", "B", "C", "D", "E", "F", "G"]
CMIN = ["C", "D", "D#", "F", "G", "G#", "A#"]

def add(*sigs):
    n = max(len(x) for x in sigs)
    out = np.zeros(n)
    for x in sigs:
        out[:len(x)] += x
    return out

def sfx(name, sig):
    os.makedirs(os.path.join(ROOT, "sfx"), exist_ok=True)
    write_wav(os.path.join(ROOT, "sfx", f"{name}.wav"), np.tanh(sig * 1.5))

def sweep(f0, f1, dur, wave_fn="square", vol=0.3):
    n = int(SR * dur); t = np.arange(n) / SR
    f = f0 + (f1 - f0) * t / dur
    ph = np.cumsum(f) / SR
    w = np.where(ph % 1.0 < 0.5, 1.0, -1.0) if wave_fn == "square" else np.sin(2 * math.pi * ph)
    return w * env(n, 0.005, 0.1, 0.6, 0.3) * vol

if __name__ == "__main__":
    compose("title", 92, ["C", "Am", "F", "G", "C", "Em", "F", "G"], MAJ, 1, lead_wave="tri", lead_vol=0.2, drums=False)
    compose("farm", 112, ["C", "F", "Am", "G", "C", "F", "Dm", "G"], MAJ, 2, duty=0.25)
    compose("town", 124, ["F", "C", "Dm", "Bb", "F", "C", "Gm", "C"], MAJ, 3, duty=0.5)
    compose("meadow", 118, ["Am", "F", "C", "G", "Am", "F", "Dm", "Em"], AMIN, 4, duty=0.3)
    compose("mine", 96, ["Cm", "Ab", "Fm", "G", "Cm", "Eb", "Fm", "G"], CMIN, 5, lead_wave="tri", dark=True, lead_vol=0.14)
    compose("boss", 150, ["Cm", "Cm", "Ab", "G", "Cm", "Fm", "Ab", "G"], CMIN, 6, lead_wave="saw", lead_vol=0.14, duty=0.5)
    compose("house", 80, ["C", "Am", "F", "G"], MAJ, 7, lead_wave="sine", drums=False, lead_vol=0.18, bars_per_chord=2)
    compose("lake", 84, ["F", "Am", "Dm", "C", "F", "Gm", "Bb", "C"], MAJ, 9, lead_wave="sine", drums=False, lead_vol=0.16, bars_per_chord=2)
    compose("mountain", 100, ["Am", "C", "G", "Em", "Am", "F", "G", "Em"], AMIN, 10, lead_wave="tri", lead_vol=0.14, duty=0.3)
    compose("beach", 108, ["C", "G", "Am", "F", "C", "G", "F", "G"], MAJ, 11, lead_wave="tri", duty=0.25, lead_vol=0.16)
    compose("sky", 72, ["Am", "Em", "F", "C", "Am", "Em", "Dm", "E" if "E" in CHORDS else "Em"], AMIN, 12, lead_wave="sine", drums=False, lead_vol=0.14, bars_per_chord=2, dark=True)
    compose("cattopia", 104, ["F", "C", "Dm", "Bb", "F", "Am", "Bb", "C"], MAJ, 13, lead_wave="square", duty=0.5, lead_vol=0.15)
    compose("rain", 76, ["Am", "Em", "F", "Em", "Am", "Dm", "F", "E" if "E" in CHORDS else "Em"], AMIN, 8, lead_wave="tri", drums=False, dark=True, lead_vol=0.12)

    sfx("swing", sweep(900, 300, 0.12, "square", 0.25))
    sfx("hit", add(noise(0.12, 0.5, 0.03), tone(180, 0.1, "square", 0.3, a=0.001, d=0.5, s=0.1, r=0.4)))
    sfx("hurt", sweep(400, 120, 0.25, "square", 0.3))
    sfx("die", add(sweep(300, 60, 0.4, "square", 0.25), noise(0.3, 0.2, 0.1)))
    sfx("pickup", np.concatenate([tone(freq("E", 5), 0.06, "square", 0.25, a=0.001, d=0.2, s=0.5, r=0.3), tone(freq("B", 5), 0.12, "square", 0.25, a=0.001, d=0.2, s=0.5, r=0.5)]))
    sfx("dig", noise(0.15, 0.4, 0.05))
    sfx("water", noise(0.35, 0.25, 0.15) * np.sin(np.linspace(0, 8 * math.pi, int(SR * 0.35))))
    sfx("plant", tone(freq("G", 4), 0.1, "tri", 0.3, a=0.001, d=0.3, s=0.3, r=0.5))
    sfx("chop", add(noise(0.08, 0.5, 0.02), tone(120, 0.08, "square", 0.3, a=0.001, d=0.5, s=0.1, r=0.5)))
    sfx("bite", np.concatenate([tone(freq("C", 6), 0.08, "square", 0.3), tone(freq("C", 6), 0.08, "square", 0.0), tone(freq("C", 6), 0.08, "square", 0.3)]))
    sfx("levelup", np.concatenate([tone(freq(n, 5), 0.09, "square", 0.25, a=0.001, d=0.2, s=0.6, r=0.3) for n in ["C", "E", "G"]] + [tone(freq("C", 6), 0.3, "square", 0.25, a=0.001, d=0.2, s=0.6, r=0.6)]))
    sfx("thud", add(sweep(140, 50, 0.18, "square", 0.3), noise(0.15, 0.35, 0.05)))
    sfx("boss_down", add(sweep(220, 40, 0.7, "square", 0.3), noise(0.6, 0.3, 0.2), tone(55, 0.6, "sine", 0.3, a=0.01, d=0.3, s=0.5, r=0.5)))
    sfx("crit", np.concatenate([tone(freq("G", 5), 0.05, "square", 0.3, a=0.001, d=0.2, s=0.5, r=0.2), tone(freq("D", 6), 0.1, "square", 0.3, a=0.001, d=0.2, s=0.5, r=0.5)]))
    sfx("stun", add(sweep(600, 900, 0.15, "tri", 0.2), noise(0.1, 0.15, 0.05)))
    sfx("stink", add(noise(0.4, 0.2, 0.2), sweep(300, 90, 0.4, "tri", 0.2)))
    print("done")
