#!/usr/bin/env python3
"""Soften and level the sound effects for a phone speaker.

    python3 tools/sfx_soften.py [--dry] [--only a,b] [--force] [--report]

Every file goes through this once, from its source (cc0_import.py, ace_kits.py,
make_rec_audio.py write the raw take; this pass finishes it):

  * trims dead air: leading audio under -45 dB of the peak (3 ms pre-roll kept)
    and trailing audio under -50 dB; footsteps (step_*) are capped at 0.28 s so
    a new step never has to wait for the last one;
  * filters: 50 Hz high-pass, a high shelf and a low-pass whose strength follows
    the harshness; still bright after that (> 50 % of the energy above 4 kHz) gets
    a second, stronger pass (6.5 kHz low-pass, -8 dB shelf at 3.5 kHz);
  * phone translation: a sound whose energy sits under 350 Hz (or that loses
    > 8 dB through a 300 Hz high-pass, i.e. on a phone speaker) gets a 90 Hz
    high-pass and a +5 dB presence lift at 1.8 kHz;
  * levels by K-weighted loudness (BS.1770 pre-filter, loudest 100 ms), which
    reads 2-8 kHz the way the ear does, moving each file 75 % toward its
    group target (a boom stays bigger than a click), never boosting a bright
    sound, never more than +6 dB, peaks at or under -1.5 dBFS;
  * matches takes: name, name_2, name_3 end within +-1.5 dB of their median, so
    the random take Music.sfx picks never jumps in level;
  * jingles (j_*, levelup, quest_done, craft_done) are only loudness-matched:
    -17 LUFS integrated, peaks <= -1.5 dBFS, no filtering;
  * ambience spot one-shots (audio/amb/spot_*) get the same chain with their
    own target, so a chirp no longer jumps 25-35 dB over the bed.

audio/sfx/SOFTEN_LOG.json keeps, per file, the source md5, before/after
figures and the output md5. A file whose md5 matches its log entry is done.
--force on a done file only re-levels it (gain, never another filter pass), so
filters never stack; to redo the filters, re-import the source first.
--report prints take spreads and phone losses without writing anything.
"""
import argparse, glob, hashlib, json, os, subprocess, sys
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SFX = os.path.join(ROOT, "audio", "sfx")
AMB = os.path.join(ROOT, "audio", "amb")
LOG = os.path.join(SFX, "SOFTEN_LOG.json")
JINGLES = ("j_",)
JINGLE_NAMES = {"levelup", "quest_done", "craft_done", "sleep"}
JINGLE_LUFS = -17.0
# K-weighted loudest-100ms targets by name prefix; Music.GROUP_DB sits on top in game.
TARGETS = [("step_", -21.0), ("ui_", -20.0), ("menu_", -20.0), ("talk_blip", -20.0), ("keypress", -19.0),
           ("scroll_tick", -21.0), ("tab", -20.0), ("nope", -19.0),
           ("page", -19.0), ("equip", -19.0), ("coin", -18.0), ("pickup", -18.0), ("cash_pickup", -19.0),
           ("cash_register", -18.0), ("cash", -19.0), ("reel", -21.0), ("tools", -19.0), ("rock_break", -18.0),
           ("servo", -21.0), ("bowl_roll", -20.0), ("heartbeat", -17.0), ("hoof", -20.0), ("beat_tick", -18.0),
           ("spot_", -22.0)]
DEFAULT_TARGET = -16.0
STEP_CAP = 0.28
TAKE_BAND = 1.5
SR = 44100
KW = "highpass=f=38:p=2,highshelf=f=1681:g=4:t=q:w=0.707"  # BS.1770 K-weighting (close enough at 44.1 kHz)


def md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()


def decode(p, ch=1, af=""):
    cmd = ["ffmpeg", "-v", "quiet", "-i", p]
    if af:
        cmd += ["-af", af]
    cmd += ["-ac", str(ch), "-ar", str(SR), "-f", "f32le", "-"]
    x = np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, np.float32).copy()
    return x.reshape(-1, ch) if ch > 1 else x


def filt(x, af, ch):
    """Run a numpy signal through an ffmpeg filter chain."""
    r = subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ac", str(ch), "-ar", str(SR), "-i", "-",
                        "-af", af, "-ac", str(ch), "-ar", str(SR), "-f", "f32le", "-"],
                       input=np.ascontiguousarray(x, np.float32).tobytes(), capture_output=True, check=True).stdout
    y = np.frombuffer(r, np.float32).copy()
    return y.reshape(-1, ch) if ch > 1 else y


def mono(x):
    return x.mean(axis=1) if x.ndim > 1 else x


def loud100(m):
    m = m.astype(np.float64)
    w = int(SR * 0.1)
    if len(m) > w:
        c = np.convolve(m ** 2, np.ones(w) / w, "valid")
        v = float(np.sqrt(c.max()))
    else:
        v = float(np.sqrt(np.mean(m ** 2))) if len(m) else 0.0
    return 20 * np.log10(v + 1e-9)


def measure(x):
    m = mono(x)
    if len(m) < 64:
        return {"lk": -90.0, "rms": -90.0, "peak": -90.0, "hf": 0.0, "low": 0.0, "phone_loss": 0.0, "dur": 0.0}
    X = np.abs(np.fft.rfft(m * np.hanning(len(m)))) ** 2
    f = np.fft.rfftfreq(len(m), 1 / SR)
    tot = X.sum() + 1e-12
    lk = loud100(filt(m, KW, 1))
    ph = loud100(filt(m, "highpass=f=300:p=2,highpass=f=300:p=2", 1))
    return {"lk": round(lk, 1), "rms": round(loud100(m), 1), "peak": round(20 * np.log10(float(np.max(np.abs(m))) + 1e-9), 1),
            "hf": round(float(X[f > 4000].sum() / tot), 3), "low": round(float(X[f < 350].sum() / tot), 3),
            "phone_loss": round(loud100(m) - ph, 1), "dur": round(len(m) / SR, 3)}


def lufs_i(x, ch):
    tmp = "/tmp/_soften_lufs.wav"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", str(ch), "-ar", str(SR), "-i", "-", tmp],
                   input=np.ascontiguousarray(x, np.float32).tobytes(), check=True)
    e = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", tmp, "-af", "ebur128", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    os.remove(tmp)
    v = -70.0
    for line in e.splitlines():
        line = line.strip()
        if line.startswith("I:") and "LUFS" in line:
            v = float(line.split()[1])
    return v


def target(name):
    for k, t in TARGETS:
        if name.startswith(k):
            return t
    return DEFAULT_TARGET


def is_jingle(name):
    return name.startswith(JINGLES) or name in JINGLE_NAMES


def trim(x, name):
    m = np.abs(mono(x))
    if not len(m):
        return x
    pk = m.max() + 1e-9
    on = np.nonzero(m > pk * 10 ** (-45 / 20))[0]
    off = np.nonzero(m > pk * 10 ** (-50 / 20))[0]
    if not len(on):
        return x
    a = max(0, on[0] - int(0.003 * SR))
    b = min(len(m), off[-1] + int(0.01 * SR))
    if name.startswith("step_"):
        b = min(b, a + int(STEP_CAP * SR))
    return x[a:b]


def fades(x, name):
    x = x.copy()
    n = len(x)
    fi = min(n // 4, int(0.003 * SR))
    fo = min(n // 4, int((0.03 if name.startswith("step_") else 0.003) * SR))
    shape = (lambda v: v[:, None]) if x.ndim > 1 else (lambda v: v)
    if fi:
        x[:fi] *= shape(np.linspace(0, 1, fi))
    if fo:
        x[-fo:] *= shape(np.linspace(1, 0, fo))
    return x


def chain(hf, name):
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


def soft_limit(x, ceil_db=-1.5):
    c = 10 ** (ceil_db / 20)
    m = float(np.max(np.abs(x))) + 1e-9
    if m <= c:
        return x
    k = 0.8 * c  # linear up to 80 % of the ceiling, then a tanh knee
    y = x.copy()
    big = np.abs(y) > k
    y[big] = np.sign(y[big]) * (k + (c - k) * np.tanh((np.abs(y[big]) - k) / (c - k)))
    return y


def full_pass(x, name, before):
    """Trim, filter, phone presence, level. Returns (signal, record)."""
    ch = x.shape[1] if x.ndim > 1 else 1
    x = trim(x, name)
    lp, shelf, af = chain(before["hf"], name)
    extra = []
    phone = before["low"] > 0.75 or before["phone_loss"] > 8.0
    if phone and not name.startswith("step_"):
        af += ",highpass=f=90,equalizer=f=1800:t=o:w=1.5:g=5"
        extra.append("presence")
    y = filt(x, af, ch)
    mid = measure(y)
    if mid["hf"] > 0.5:
        y = filt(y, "lowpass=f=6500:p=2,treble=g=-8:f=3500:t=s:w=0.7", ch)
        mid = measure(y)
        extra.append("bright2")
    t = target(name) - (3.0 if mid["hf"] > 0.4 else 0.0)  # bright sounds read louder than any meter says
    gain = max(-16.0, min(6.0, (t - mid["lk"]) * 0.75))
    if mid["hf"] > 0.5:
        gain = min(gain, 0.0)  # never boost a bright sound
    y = y * 10 ** (gain / 20)
    y = soft_limit(y)
    y = fades(y, name)
    return y, {"gain_db": round(gain, 2), "lowpass": lp, "shelf_db": shelf, "extra": extra}


def jingle_pass(x, name):
    ch = x.shape[1] if x.ndim > 1 else 1
    g = JINGLE_LUFS - lufs_i(x, ch)
    y = soft_limit(x * 10 ** (g / 20))
    return y, {"gain_db": round(g, 2), "mode": "jingle"}


def write(path, x, ch):
    out = path + ".soft.ogg"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", str(ch), "-ar", str(SR), "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "4", out],
                   input=np.ascontiguousarray(x, np.float32).tobytes(), check=True)
    os.remove(path)  # hardlinked: never write through
    os.rename(out, path)


def key_of(path):
    return ("amb/" if os.path.dirname(os.path.abspath(path)) == os.path.abspath(AMB) else "") + os.path.basename(path)[:-4]


def base_of(name):
    b, _, n = name.rpartition("_")
    return b if n in ("2", "3", "4") and b else name


def channels(p):
    info = json.loads(subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                                      "stream=channels", "-of", "json", p], capture_output=True, text=True).stdout)
    return min(2, int(info["streams"][0].get("channels", 1)))


def all_files():
    return sorted(glob.glob(os.path.join(SFX, "*.ogg"))) + sorted(glob.glob(os.path.join(AMB, "spot_*.ogg")))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true", help="re-level done files (gain only, no new filter pass)")
    ap.add_argument("--report", action="store_true")
    a = ap.parse_args()
    log = json.load(open(LOG)) if os.path.exists(LOG) else {}
    only = set(x for x in a.only.split(",") if x)
    files = all_files()
    sig, chs, touched = {}, {}, set()
    n = 0
    for p in files:
        k = key_of(p)
        name = os.path.basename(p)[:-4]
        if only and name not in only and base_of(name) not in only and k not in only:
            continue
        done = k in log and log[k].get("md5") == md5(p)
        if a.report:
            continue
        if done and not a.force:
            continue
        ch = channels(p)
        x = decode(p, ch)
        before = measure(x)
        if is_jingle(name):
            y, rec = jingle_pass(x, name)
        elif done:
            y, rec = x, {"gain_db": 0.0, "mode": "relevel"}
            rec.update({kk: log[k].get(kk) for kk in ("lowpass", "shelf_db", "extra") if kk in log[k]})
        else:
            y, rec = full_pass(x, name, before)
        rec["before"] = log[k]["before"] if done and "before" in log[k] else before
        rec["src_md5"] = log[k].get("src_md5") if done else md5(p)
        sig[k], chs[k] = y, ch
        log[k] = rec
        touched.add(k)
        n += 1
    # take matching: every group with a touched member is pulled to its median
    groups = {}
    for p in files:
        k = key_of(p)
        if is_jingle(os.path.basename(p)[:-4]):
            continue
        groups.setdefault(base_of(k), []).append((k, p))
    if a.report:
        for g, mem in sorted(groups.items()):
            if len(mem) < 2:
                continue
            lks = [log.get(k, {}).get("after", {}).get("lk") for k, _ in mem]
            if None in lks:
                print(f"{g:24s} (not measured)")
                continue
            print(f"{g:24s} spread {max(lks) - min(lks):4.1f} dB  {lks}")
        return
    for g, mem in groups.items():
        if len(mem) < 2 or not any(k in touched for k, _ in mem):
            continue
        for k, p in mem:
            if k not in sig:
                chs[k] = channels(p)
                sig[k] = decode(p, chs[k])
                if k not in log:
                    log[k] = {}
                log[k].setdefault("mode", "relevel")
                touched.add(k)
        lks = {k: measure(sig[k])["lk"] for k, _ in mem}
        med = float(np.median(list(lks.values())))
        for k, _ in mem:
            d = lks[k] - med
            if abs(d) > TAKE_BAND:
                adj = -(d - np.sign(d) * TAKE_BAND * 0.5)
                adj = max(-18.0, min(12.0, adj))
                sig[k] = soft_limit(sig[k] * 10 ** (adj / 20))
                log[k]["take_adj_db"] = round(float(adj), 2)
    for p in files:
        k = key_of(p)
        if k not in touched:
            continue
        after = measure(sig[k])
        log[k]["after"] = after
        b = log[k].get("before", after)
        name = k.split("/")[-1]
        print(f"{k:28s} lk {b.get('lk', b.get('rms', 0)):6.1f} -> {after['lk']:6.1f}  peak {after['peak']:5.1f}  "
              f"hf {b.get('hf', 0):.2f} -> {after['hf']:.2f}  low {after['low']:.2f}  {log[k].get('mode', '')} "
              f"{' '.join(log[k].get('extra', []))} {('take ' + str(log[k]['take_adj_db'])) if 'take_adj_db' in log[k] else ''}")
        if not a.dry:
            write(p, sig[k], chs[k])
            log[k]["md5"] = md5(p)
    if not a.dry:
        with open(LOG + ".new", "w") as fh:
            json.dump(log, fh, indent=1, sort_keys=True)
        if os.path.exists(LOG):
            os.remove(LOG)
        os.rename(LOG + ".new", LOG)
    print(f"processed {n} files, wrote {len(touched)}" + (" (dry run)" if a.dry else ""))


if __name__ == "__main__":
    main()
