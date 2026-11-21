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
    high-pass and a +5 dB presence lift at 1.8 kHz; one that loses > 8 dB also
    gets parallel tanh harmonics above 350 Hz mixed in 6 dB under it (excite);
  * levels by K-weighted loudness (BS.1770 pre-filter, loudest 100 ms), which
    reads 2-8 kHz the way the ear does, moving each file 75 % toward its
    group target (a boom stays bigger than a click), never boosting a bright
    sound by more than +3 dB, never more than +6 dB, peaks at or under -1.5 dBFS;
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
from scipy.signal import butter, sosfilt


def _kweight_sos(fs):
    """BS.1770 K-weighting (pre-filter shelf + RLB high-pass), bilinear at fs."""
    import math
    f0, G, Q = 1681.974450955533, 3.999843853973347, 0.7071752369554196
    K = math.tan(math.pi * f0 / fs)
    Vh = 10 ** (G / 20)
    Vb = Vh ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    shelf = [(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0, 1.0, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    f0, Q = 38.13547087602444, 0.5003270373238773
    K = math.tan(math.pi * f0 / fs)
    a0 = 1 + K / Q + K * K
    hp = [1.0, -2.0, 1.0, 1.0, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    return np.array([shelf, hp])

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SFX = os.path.join(ROOT, "audio", "sfx")
AMB = os.path.join(ROOT, "audio", "amb")
LOG = os.path.join(SFX, "SOFTEN_LOG.json")
JINGLES = ("j_",)
JINGLE_NAMES = {"levelup", "quest_done", "craft_done", "sleep", "ach_unlock"}
JINGLE_LUFS = -17.0
# K-weighted loudest-100ms targets by name prefix; Music.GROUP_DB sits on top in game.
TARGETS = [("step_", -21.0), ("ui_", -20.0), ("menu_", -20.0), ("talk_blip", -20.0), ("keypress", -19.0),
           ("scroll_tick", -21.0), ("tab", -20.0), ("nope", -19.0),
           ("page", -19.0), ("equip", -19.0), ("coin", -18.0), ("pickup", -18.0), ("cash_pickup", -19.0),
           ("cash_register", -18.0), ("cash", -19.0), ("reel", -13.0), ("tools", -19.0), ("rock_break", -15.0),
           ("servo", -21.0), ("bowl_roll", -20.0), ("sparkle", -20.0), ("fairy_ring", -18.0), ("heartbeat", -17.0), ("hoof", -20.0), ("beat_tick", -18.0), ("status_tick", -23.0), ("yawn", -19.0),
           ("spot_", -22.0), ("cv_gloam", -12.0)]
DEFAULT_TARGET = -16.0
STEP_CAP = 0.28
LONG_STEPS = ("step_swim", "step_wheels")  # strokes / rolling, not footfalls: no 0.28 s cap
BRIGHT_OK = ("sparkle", "fairy_ring", "reel", "spot_cicada", "spot_insect", "spot_bird")  # meant to shimmer: level them normally
TAKE_BAND = 1.5
# C13 11-05: takes are matched on the mean of full-band (K-weighted) and phone-proxy (300 Hz HP)
# loudness, so a bass-heavy take no longer drops 7-11 dB against its siblings on a phone speaker
TAKE_PHONE_W = 0.5
# C13 11-10: impact cues must land on the haptic: lead-in trimmed to 5 ms before the point the
# sound first reaches peak-20 dB (a slow swell or near-silent lead-in no longer lags the buzz)
IMPACT = ("block", "crit", "hit", "reload", "shot", "pin_", "bat", "punch", "stomp", "smash")
LEAD_DB = 40.0  # every other non-ambient file: lead-in under peak-40 dB is cut (was 45)
# C13 11-14: functional low cues that still lose > 5 dB on a phone get (phone_loss - 3) dB, up to +6
PHONE_CUES = ("heartbeat", "stomp", "war_drum", "boss_down", "roar", "grunt", "alert", "block", "amb/spot_thunder")
RETARGET_MAX = 10.0  # --retarget: largest lift toward a (changed) group target, before the limiter
SR = 44100
_KW_SOS = _kweight_sos(SR)
_PH_SOS = butter(4, 300, "highpass", fs=SR, output="sos")  # what a phone speaker reproduces


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
    lk = loud100(sosfilt(_KW_SOS, m))
    ph = loud100(sosfilt(_PH_SOS, m))
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
    base = name[:-5] if name.endswith("_gang") else name  # arc variants (levelup_gang) are jingles too
    return name.startswith(JINGLES) or base in JINGLE_NAMES


def lead_trim(x, name):
    """Cut the lead-in only (5 ms fade kept by fades()): impact groups to 5 ms before peak-20 dB."""
    m = np.abs(mono(x))
    if not len(m):
        return x
    pk = m.max() + 1e-9
    lvl = 20.0 if name.startswith(IMPACT) else LEAD_DB
    on = np.nonzero(m > pk * 10 ** (-lvl / 20))[0]
    if not len(on):
        return x
    a = max(0, on[0] - int(0.005 * SR))
    return x[a:]


def onset_ms(x):
    m = np.abs(mono(x))
    if not len(m):
        return 0.0
    on = np.nonzero(m > (m.max() + 1e-9) * 10 ** (-40 / 20))[0]
    return 1000.0 * (on[0] / SR if len(on) else 0.0)


def phone_lk(meas):
    return (1 - TAKE_PHONE_W) * meas["lk"] + TAKE_PHONE_W * (meas["rms"] - meas["phone_loss"])


def trim(x, name):
    m = np.abs(mono(x))
    if not len(m):
        return x
    pk = m.max() + 1e-9
    on = np.nonzero(m > pk * 10 ** (-LEAD_DB / 20))[0]
    off = np.nonzero(m > pk * 10 ** (-50 / 20))[0]
    if not len(on):
        return x
    a = max(0, on[0] - int(0.003 * SR))
    b = min(len(m), off[-1] + int(0.01 * SR))
    if name.startswith("step_") and not name.startswith(LONG_STEPS):
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


_EX_SOS = butter(4, 350, "highpass", fs=SR, output="sos")


def excite(y, rel_db=-6.0):
    """Parallel saturation: tanh harmonics above 350 Hz mixed in rel_db under the sound, so a
    sub-bass thump (heartbeat, stomp, roar) still reads on a phone speaker."""
    m = mono(y)
    pk = float(np.max(np.abs(m))) + 1e-9
    h = sosfilt(_EX_SOS, np.tanh(6 * y / pk) * pk, axis=0)
    rel = loud100(mono(h)) - loud100(m)
    return (y + h * 10 ** ((rel_db - rel) / 20)).astype(np.float32)


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
    lp, shelf, af = chain(min(before["hf"], 0.3) if name.startswith(BRIGHT_OK) else before["hf"], name)
    extra = []
    phone = before["low"] > 0.75 or before["phone_loss"] > 8.0
    if phone and not name.startswith("step_"):
        af += ",highpass=f=90,equalizer=f=1800:t=o:w=1.5:g=5"
        extra.append("presence")
    y = filt(x, af, ch)
    if before["phone_loss"] > 8.0 and not name.startswith("step_"):
        y = excite(y)  # a phone speaker drops the body: give it harmonics it can play
        extra.append("exciter")
    mid = measure(y)
    if mid["hf"] > 0.5 and not name.startswith(BRIGHT_OK):
        y = filt(y, "lowpass=f=6500:p=2,treble=g=-8:f=3500:t=s:w=0.7", ch)
        mid = measure(y)
        extra.append("bright2")
    t = target(name) - (3.0 if mid["hf"] > 0.4 else 0.0)  # bright sounds read louder than any meter says
    gain = max(-16.0, min(6.0, (t - mid["lk"]) * 0.75))
    if mid["hf"] > 0.5 and not name.startswith(BRIGHT_OK):
        gain = min(gain, 3.0)  # bright: at most a small lift (already aimed 3 dB low), never the full +6
    y = y * 10 ** (gain / 20)
    y = soft_limit(y)
    y = fades(y, name)
    return y, {"gain_db": round(gain, 2), "lowpass": lp, "shelf_db": shelf, "extra": extra}


JINGLE_SHORT = 0.5      # s: ebur128 gates clips this short to -70 LUFS (its blocks are 400 ms)
JINGLE_SHORT_LK = -18.0 # short UI stings level like coin/pickup on the loudest-100 ms K-weighted path
JINGLE_MAX_GAIN = 12.0
JINGLE_MAX_RMS = -9.0   # loudest-100 ms RMS ceiling for any jingle (sfx_level_check fails above -8)  # never boost a jingle more than this (j_buy/j_confirm once got +53 dB)


def jingle_pass(x, name):
    ch = x.shape[1] if x.ndim > 1 else 1
    li = lufs_i(x, ch)
    dur = (len(x) / SR)
    if dur < JINGLE_SHORT or li <= -69.0:
        lk = measure(x)["lk"]
        g = max(-16.0, min(6.0, JINGLE_SHORT_LK - lk))
        mode = "jingle_short"
    else:
        g = JINGLE_LUFS - li
        mode = "jingle"
    g = min(g, JINGLE_MAX_GAIN)
    extra = []
    b = measure(x)
    if b["phone_loss"] > 8.0:
        # bass-led sting (upright bass, low brass): a phone speaker drops it; same presence
        # lift + exciter as full_pass, then re-measure so the level still follows the result
        x = excite(filt(x, "highpass=f=90,equalizer=f=1800:t=o:w=1.5:g=5", ch))
        extra = ["presence", "exciter"]
        if mode == "jingle":
            g = min(JINGLE_MAX_GAIN, JINGLE_LUFS - lufs_i(x, ch))
        else:
            g = max(-16.0, min(6.0, JINGLE_SHORT_LK - measure(x)["lk"]))
    y = soft_limit(x * 10 ** (g / 20))
    r = measure(y)["rms"]
    if r > JINGLE_MAX_RMS:  # dense bass-led sting: integrated LUFS under-reads it; keep it off the wall
        y = y * 10 ** ((JINGLE_MAX_RMS - r) / 20)
        g += JINGLE_MAX_RMS - r
    return y, {"gain_db": round(g, 2), "mode": mode, "extra": extra}


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


META = os.path.join(ROOT, "data", "sfx_meta.json")
AUDIBLE_DB = 35.0  # a sound "ends" at its last 50 ms window within this many dB of its loudest one


def len_audible(x):
    """Seconds from the start to the end of the last audible 50 ms window (Music ducks only that long)."""
    m = mono(x).astype(np.float64)
    w = int(0.05 * SR)
    n = len(m) // w
    if n < 1:
        return round(len(m) / SR, 3)
    db = 10 * np.log10(np.mean(m[:n * w].reshape(n, w) ** 2, axis=1) + 1e-12)
    loud = np.nonzero(db > db.max() - AUDIBLE_DB)[0]
    end = (int(loud[-1]) + 1) * w if len(loud) else len(m)
    return round(min(len(m), end) / SR, 3)


def write_meta(names=None):
    """data/sfx_meta.json {name: {len_audible, dur}} for every audio/sfx file (names: refresh only these)."""
    meta = json.load(open(META)) if os.path.exists(META) and names is not None else {}
    for p in sorted(glob.glob(os.path.join(SFX, "*.ogg"))):
        name = os.path.basename(p)[:-4]
        if names is not None and name not in names and name in meta:
            continue
        x = decode(p, 1)
        meta[name] = {"len_audible": len_audible(x), "dur": round(len(x) / SR, 3)}
    have = {os.path.basename(p)[:-4] for p in glob.glob(os.path.join(SFX, "*.ogg"))}
    meta = {k: v for k, v in sorted(meta.items()) if k in have}
    with open(META + ".new", "w") as fh:
        json.dump(meta, fh, indent=0, sort_keys=True)
    if os.path.exists(META):
        os.remove(META)
    os.rename(META + ".new", META)
    return meta


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--meta", action="store_true", help="only rebuild data/sfx_meta.json (len_audible per sfx)")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--force", action="store_true", help="re-level done files (gain only, no new filter pass)")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--retarget", action="store_true", help="with --force: re-trim the lead-in, lift lone phone cues")
    ap.add_argument("--retarget-level", action="store_true", help="with --retarget: also move toward the group target")
    a = ap.parse_args()
    if a.meta:
        print(f"sfx_meta: {len(write_meta())} files -> data/sfx_meta.json")
        return
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
            if a.retarget:
                y = fades(lead_trim(x, name), name) if not k.startswith("amb/") else x
                cur = measure(y)
                g = max(-16.0, min(RETARGET_MAX, (target(name) - cur["lk"]) * 0.75)) if a.retarget_level else 0.0
                single = not any(base_of(key_of(q)) == base_of(k) and key_of(q) != k for q in files)
                if (name.startswith(PHONE_CUES) or k.startswith(PHONE_CUES)) and cur["phone_loss"] > 5.0 and single:
                    g = max(g, min(6.0, cur["phone_loss"] - 3.0))
                    rec["phone_lift"] = True
                y = soft_limit(y * 10 ** (g / 20))
                rec.update({"gain_db": round(g, 2), "mode": "retarget"})
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
            ph = [round(phone_lk(log[k]["after"]) * 2 - log[k]["after"]["lk"], 1) for k, _ in mem]  # pure phone proxy
            print(f"{g:24s} spread {max(lks) - min(lks):4.1f} dB  phone {max(ph) - min(ph):4.1f} dB  {lks} {ph}")
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
        lks = {k: phone_lk(measure(sig[k])) for k, _ in mem}
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
        write_meta({k for k in touched if "/" not in k})
    print(f"processed {n} files, wrote {len(touched)}" + (" (dry run)" if a.dry else ""))


if __name__ == "__main__":
    main()
