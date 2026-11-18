#!/usr/bin/env python3
"""Placeholder ambience beds (audio/amb/<bed>.ogg) and spot sounds
(audio/amb/spot_<name>.wav), plus extra action sfx (audio/sfx/<name>.wav).

Everything is synthesised with numpy and is deterministic. Real recordings can
replace any file under the same name: list the file name in audio/amb/REAL.txt
(or audio/sfx/REAL.txt) and this script will never overwrite it.
"""
import os, subprocess, wave, zlib
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
SR = 22050
AMB = os.path.join(ROOT, "amb")
SFX = os.path.join(ROOT, "sfx")
os.makedirs(AMB, exist_ok=True)


def real(folder):
    p = os.path.join(folder, "REAL.txt")
    return set(open(p).read().split()) if os.path.exists(p) else set()


def rng(name):
    return np.random.default_rng(zlib.crc32(name.encode()))


def lowpass(x, a):
    """One-pole low-pass; a in (0,1], smaller = darker. a may be an array."""
    y = np.empty_like(x)
    acc = 0.0
    a = np.broadcast_to(np.asarray(a, dtype=float), x.shape)
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def fast_lp(x, k):
    """Cheap moving-average low-pass (k samples)."""
    if k <= 1:
        return x
    c = np.cumsum(np.concatenate([[0.0], x]))
    out = (c[k:] - c[:-k]) / k
    return np.concatenate([out, np.full(k - 1, out[-1])])


def norm(x, peak=0.6):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def loopify(x, xf=1.5):
    n = int(xf * SR)
    head, body, tail = x[:n], x[n:-n] if len(x) > 2 * n else x, x[-n:]
    t = np.linspace(0, 1, n)
    mixed = tail * np.cos(t * np.pi / 2) + head * np.sin(t * np.pi / 2)
    return np.concatenate([mixed, x[n:-n]])


def write_wav(path, x):
    x = np.clip(x, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def write_ogg(path, x):
    tmp = path + ".tmp.wav"
    write_wav(tmp, x)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "1", path], check=True)
    os.remove(tmp)


def chirp(r, f0, f1, dur, amp=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = np.linspace(f0, f1, n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.sin(np.linspace(0, np.pi, n)) ** 2
    return np.sin(ph) * env * amp


def place(buf, snd, at):
    i = int(at * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(snd))
    buf[i:j] += snd[: j - i]


# ---------------------------------------------------------------- beds
def bed(name, L=18.0):
    r = rng(name)
    n = int((L + 1.5) * SR)
    t = np.arange(n) / SR
    w = r.standard_normal(n)
    x = np.zeros(n)
    if name in ("wind_soft", "wind_strong"):
        lfo = 0.5 + 0.5 * np.sin(2 * np.pi * 0.07 * t + r.random() * 6) * np.sin(2 * np.pi * 0.023 * t)
        k = 40 if name == "wind_soft" else 18
        x = fast_lp(w, k) * (0.35 + 0.65 * lfo)
        x = x - fast_lp(x, 400)
    elif name in ("rain_light", "rain_heavy", "rain_roof"):
        x = fast_lp(w, 3) - fast_lp(w, 30)
        clicks = np.zeros(n)
        cnt = {"rain_light": 900, "rain_heavy": 2600, "rain_roof": 1400}[name]
        for _ in range(int(cnt * L / 18)):
            place(clicks, r.standard_normal(40) * np.exp(-np.arange(40) / 8), r.random() * L)
        x = x * (1.0 if name != "rain_light" else 0.5) + clicks * 0.6
        if name == "rain_heavy":
            x += fast_lp(w, 300) * 6
        if name == "rain_roof":
            x = fast_lp(x, 10)
    elif name in ("waves", "water_lap"):
        env = np.zeros(n)
        tt = 0.0
        while tt < L + 1.5:
            per = r.uniform(6, 9) if name == "waves" else r.uniform(2.5, 4)
            seg = np.sin(np.linspace(0, np.pi, int(per * SR))) ** 3
            place(env, seg, tt)
            tt += per * 0.8
        x = fast_lp(w, 25 if name == "waves" else 12) * (0.15 + env)
    elif name in ("birds_dawn", "birds_day"):
        dens = 3.0 if name == "birds_dawn" else 1.0
        tt = 0.0
        while tt < L:
            tt += r.exponential(1.6 / dens)
            f = r.uniform(2200, 4800)
            for k in range(r.integers(2, 6)):
                d = r.uniform(0.04, 0.12)
                place(x, chirp(r, f, f * r.uniform(0.7, 1.4), d, r.uniform(0.3, 1.0)), tt + k * d * 1.3)
        x += fast_lp(w, 60) * 0.02
    elif name == "crickets":
        for v in range(3):
            f = 4500 + v * 120
            gate = (np.sin(2 * np.pi * 30 * t) > 0).astype(float)
            burst = (np.sin(2 * np.pi * (1 / (0.8 + v * 0.13)) * t + v) > 0.2).astype(float)
            x += np.sin(2 * np.pi * f * t) * gate * fast_lp(burst, 200) * 0.3
    elif name == "frogs":
        tt = 0.0
        while tt < L:
            tt += r.exponential(0.7)
            f = r.uniform(300, 500)
            d = r.uniform(0.15, 0.3)
            m = int(d * SR)
            tm = np.arange(m) / SR
            snd = np.sin(2 * np.pi * f * tm) * (np.sin(2 * np.pi * 25 * tm) > 0) * np.sin(np.linspace(0, np.pi, m))
            place(x, snd * r.uniform(0.3, 1), tt)
    elif name == "hearth":
        x = fast_lp(np.cumsum(w) * 0.01, 50)
        x = x - fast_lp(x, 2000)
        for _ in range(int(220 * L / 18)):
            place(x, r.standard_normal(60) * np.exp(-np.arange(60) / 10) * r.uniform(0.5, 3), r.random() * L)
    elif name == "cave":
        x = fast_lp(w, 200) + 0.3 * np.sin(2 * np.pi * 55 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.05 * t))
    elif name == "lava":
        x = fast_lp(w, 120)
        for _ in range(int(40 * L / 18)):
            place(x, chirp(r, 120, 60, r.uniform(0.1, 0.25), 2.0), r.random() * L)
    elif name == "crystal_hum":
        x = sum(np.sin(2 * np.pi * f * t + r.random() * 6) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.1 * t * (i + 1))) for i, f in enumerate([523, 659, 784, 1046]))
    elif name == "city_hum":
        x = np.sin(2 * np.pi * 60 * t) * 0.4 + np.sin(2 * np.pi * 120 * t) * 0.2 + fast_lp(w, 80) * 3
        for _ in range(int(6 * L / 18)):
            place(x, chirp(r, 400, 380, r.uniform(0.6, 1.5), 0.3), r.random() * L)
    elif name in ("town_day", "crowd"):
        voices = 6 if name == "town_day" else 16
        for v in range(voices):
            f = r.uniform(180, 600)
            band = fast_lp(r.standard_normal(n), 6) - fast_lp(r.standard_normal(n), 40)
            amp = np.clip(np.sin(2 * np.pi * r.uniform(0.2, 0.6) * t + r.random() * 6), 0, 1)
            x += band * amp * np.sin(2 * np.pi * f * t) * 0.5
    elif name == "space":
        x = np.sin(2 * np.pi * 55 * t) + np.sin(2 * np.pi * 55.7 * t) + 0.5 * np.sin(2 * np.pi * 82.4 * t)
    elif name == "leaves":
        x = (fast_lp(w, 4) - fast_lp(w, 20)) * (0.3 + 0.7 * np.clip(np.sin(2 * np.pi * 0.12 * t), 0, 1) ** 2)
    x = loopify(x)
    return norm(x, 0.55)


BEDS = ["wind_soft", "wind_strong", "rain_light", "rain_heavy", "rain_roof", "waves", "water_lap", "birds_dawn",
        "birds_day", "crickets", "frogs", "hearth", "cave", "lava", "crystal_hum", "city_hum", "town_day", "crowd",
        "space", "leaves"]


# ---------------------------------------------------------------- spots / sfx
def env(n, a=0.005, d=0.2):
    t = np.arange(n) / SR
    return np.minimum(1, t / a) * np.exp(-t / d)


def tone(f, dur, kind="sine", d=0.15, a=0.004):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = np.broadcast_to(np.asarray(f, dtype=float), (n,))
    ph = 2 * np.pi * np.cumsum(f) / SR
    s = {"sine": np.sin(ph), "square": np.sign(np.sin(ph)), "saw": 2 * ((ph / (2 * np.pi)) % 1) - 1, "tri": 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1}[kind]
    return s * env(n, a, d)


def noise(name, dur, k=1, d=0.1):
    n = int(dur * SR)
    return fast_lp(rng(name).standard_normal(n), k) * env(n, 0.002, d)


def cat(*parts, gap=0.0):
    g = np.zeros(int(gap * SR))
    out = []
    for p in parts:
        out += [p, g]
    return np.concatenate(out)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def sweep(f0, f1, dur, kind="sine", d=0.2):
    return tone(np.linspace(f0, f1, int(dur * SR)), dur, kind, d)


SPOTS = {
    "owl": lambda: cat(tone(380, 0.35, d=0.25), np.zeros(int(0.15 * SR)), tone(360, 0.5, d=0.35)),
    "rooster": lambda: cat(sweep(500, 900, 0.18, "saw", 0.3), sweep(900, 1100, 0.25, "saw", 0.3), sweep(1100, 600, 0.6, "saw", 0.5)) * 0.4,
    "thunder": lambda: mix(noise("thunder", 2.8, 60, 1.0) * 3, noise("crack", 0.3, 2, 0.05)),
    "bird_chirp": lambda: cat(sweep(3200, 4200, 0.07), sweep(3600, 2800, 0.09), gap=0.05),
    "penguin_chatter": lambda: cat(tone(520, 0.08, "square", 0.06), tone(460, 0.1, "square", 0.07), tone(560, 0.07, "square", 0.05), gap=0.04) * 0.4,
    "drip": lambda: sum(np.concatenate([np.zeros(int(i * 0.09 * SR)), tone(1200 - i * 40, 0.12, d=0.03) * (0.6 ** i), np.zeros(int((3 - i) * 0.09 * SR))]) for i in range(4)),
}

NEW_SFX = {
    "splash": lambda: mix(noise("splash", 0.4, 3, 0.12), sweep(600, 200, 0.2, d=0.08) * 0.3),
    "shot": lambda: mix(noise("shot", 0.25, 1, 0.04) * 1.5, sweep(180, 60, 0.2, d=0.06)),
    "dry_click": lambda: tone(1800, 0.03, "square", 0.01) * 0.4,
    "pick": lambda: mix(tone(1400, 0.15, "tri", 0.05), noise("pick", 0.1, 2, 0.03) * 0.5),
    "crate_break": lambda: mix(noise("crate", 0.35, 4, 0.1), cat(tone(300, 0.05, "square", 0.02), tone(220, 0.06, "square", 0.02)) * 0.3),
    "timber": lambda: cat(noise("crk", 0.3, 6, 0.2), noise("thump", 0.4, 40, 0.15) * 3),
    "harvest": lambda: cat(tone(660, 0.07), tone(880, 0.1)) * 0.6,
    "cast": lambda: mix(noise("cast", 0.35, 2, 0.15) * 0.5, sweep(900, 1500, 0.3, d=0.2) * 0.2),
    "reel": lambda: cat(*[tone(2000, 0.02, "square", 0.01) * 0.3 for _ in range(8)], gap=0.03),
    "fish_escape": lambda: mix(noise("esc", 0.3, 3, 0.1), sweep(500, 200, 0.3, "tri") * 0.3),
    "door": lambda: mix(sweep(220, 160, 0.3, "saw", 0.12) * 0.3, noise("door", 0.15, 20, 0.05)),
    "locked": lambda: cat(tone(180, 0.06, "square", 0.03), tone(160, 0.08, "square", 0.04), gap=0.05) * 0.5,
    "ui_tap": lambda: tone(1200, 0.04, d=0.02) * 0.4,
    "menu_open": lambda: cat(tone(700, 0.05), tone(1000, 0.07)) * 0.4,
    "menu_close": lambda: cat(tone(1000, 0.05), tone(700, 0.07)) * 0.4,
    "talk_blip": lambda: tone(800, 0.03, "square", 0.015) * 0.25,
    "coin": lambda: cat(tone(1500, 0.06, "square", 0.05), tone(2000, 0.15, "square", 0.1)) * 0.3,
    "eat": lambda: cat(*[noise(f"eat{i}", 0.06, 3, 0.03) for i in range(3)], gap=0.06),
    "craft_done": lambda: cat(tone(523, 0.08), tone(659, 0.08), tone(784, 0.18)) * 0.5,
    "quest_done": lambda: cat(tone(523, 0.1, "tri"), tone(784, 0.1, "tri"), tone(1046, 0.3, "tri", 0.3)) * 0.6,
    "spell": lambda: mix(sweep(400, 1600, 0.4, "tri", 0.3) * 0.5, noise("sp", 0.4, 2, 0.2) * 0.2),
    "sleep": lambda: cat(tone(523, 0.3, d=0.3), tone(392, 0.3, d=0.3), tone(330, 0.6, d=0.5)) * 0.5,
    "mail": lambda: cat(tone(988, 0.08), tone(1319, 0.2)) * 0.4,
    "bark": lambda: cat(sweep(500, 300, 0.09, "saw", 0.05), sweep(520, 320, 0.1, "saw", 0.06), gap=0.08) * 0.5,
    "whimper": lambda: sweep(900, 600, 0.5, "sine", 0.3) * 0.4,
    "alert": lambda: cat(tone(880, 0.06, "square", 0.04), tone(1175, 0.08, "square", 0.05)) * 0.3,
    "zap": lambda: mix(noise("zap", 0.2, 1, 0.08) * 0.5, sweep(2000, 400, 0.2, "square", 0.08) * 0.3),
    "heartbeat": lambda: cat(tone(60, 0.1, d=0.06) * 2, tone(55, 0.12, d=0.07) * 1.5, gap=0.12),
    "nope": lambda: cat(tone(300, 0.07, "square", 0.04), tone(240, 0.1, "square", 0.05)) * 0.3,
    "fireworks": lambda: cat(sweep(300, 1500, 0.5, "sine", 0.4) * 0.3, noise("boom", 0.8, 8, 0.3) * 2),
    "step_grass": lambda: noise("sg", 0.07, 4, 0.025) * 0.5,
    "step_dirt": lambda: noise("sd", 0.07, 8, 0.03) * 0.6,
    "step_wood": lambda: mix(tone(220, 0.06, "tri", 0.02) * 0.5, noise("sw", 0.05, 10, 0.02) * 0.3),
    "step_stone": lambda: noise("ss", 0.05, 2, 0.015) * 0.5,
    "step_sand": lambda: noise("sa", 0.09, 3, 0.04) * 0.4,
    "step_snow": lambda: noise("sn", 0.1, 6, 0.05) * 0.5,
    # An enemy winding up a move: not the player's own "spell" sound.
    "tell": lambda: cat(sweep(1300, 500, 0.16, "saw", 0.08), tone(330, 0.14, "square", 0.08), gap=0.02),
}

# Peak per sound (x 0.55): keeps the blip/menu/nope cues under the reward jingles.
SFX_GAIN = {"talk_blip": 0.35, "ui_tap": 0.5, "dry_click": 0.45, "menu_open": 0.5, "menu_close": 0.5, "nope": 0.55,
            "alert": 0.6, "coin": 0.75, "mail": 0.8, "locked": 0.7, "harvest": 0.75, "tell": 0.7}


def main():
    ra, rs = real(AMB), real(SFX)
    for b in BEDS:
        fn = f"{b}.ogg"
        if fn in ra:
            continue
        write_ogg(os.path.join(AMB, fn), bed(b))
    for s, fnc in SPOTS.items():
        fn = f"spot_{s}.wav"
        if fn not in ra:
            write_wav(os.path.join(AMB, fn), norm(fnc(), 0.6))
    for s, fnc in NEW_SFX.items():
        fn = f"{s}.wav"
        if fn not in rs:
            write_wav(os.path.join(SFX, fn), norm(fnc(), 0.55 * SFX_GAIN.get(s, 1.0)))
    print(len(BEDS), "beds,", len(SPOTS), "spots,", len(NEW_SFX), "sfx")


if __name__ == "__main__":
    main()
