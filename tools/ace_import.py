#!/usr/bin/env python3
"""Bring an ACE Music render into the game.

    python3 tools/ace_import.py <name> <file.mp3|wav> [--kind music|jingle] [--trim START:END]
                                [--loop-xfade 2.0] [--dry OUTDIR]

music  : trims leading/trailing silence and a false ending (render stopped, a fragment
         restarted), phone-masters (low shelf on bass-heavy songs, -16 LUFS / -1.5 dBTP,
         clamped trim toward PHONE_TARGET through a 300 Hz proxy), makes the end flow back
         into the loop point with a sample-accurate equal-power crossfade (numpy; the old
         ffmpeg acrossfade graph silently dropped the join), keeps a quiet intro once by
         writing its end to data/music_loops.json ("track": loop_offset seconds, read by
         Music), checks the seam, writes audio/music/<name>.ogg (Vorbis q3, 48 kHz stereo)
         and adds <name> to audio/music/REAL.txt so the placeholder generators never
         overwrite it.
jingle : takes --trim START:END seconds (a short phrase from a 30 s render), fades the
         tail, normalises to -14 LUFS, writes audio/sfx/<name>.ogg and lists it in
         audio/sfx/REAL.txt.

Originals are not copied into the repo; audio/ACE_LOG.json records each track's ACE song ids.
Needs ffmpeg/ffprobe. Run `godot --headless --path . --import` afterwards.
"""
import argparse, json, os, re, shutil, subprocess, sys, tempfile
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
AUD = os.path.join(ROOT, "audio")


def run(*a):
    return subprocess.run(a, check=True, capture_output=True, text=True)


def duration(path):
    return float(run("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path).stdout.strip())


def loudnorm(src, dst, target, extra_filters=""):
    """Two-pass EBU R128 normalisation (accurate, no pumping)."""
    pre = (extra_filters + ",") if extra_filters else ""
    p = subprocess.run(["ffmpeg", "-hide_banner", "-y", "-i", src, "-af",
                        f"{pre}loudnorm=I={target}:TP=-1.5:LRA=11:print_format=json", "-f", "null", "-"],
                       capture_output=True, text=True)
    js = p.stderr[p.stderr.rindex("{"):p.stderr.rindex("}") + 1]
    m = json.loads(js)
    af = (f"{pre}loudnorm=I={target}:TP=-1.5:LRA=11:measured_I={m['input_i']}:measured_TP={m['input_tp']}:"
          f"measured_LRA={m['input_lra']}:measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true")
    run("ffmpeg", "-hide_banner", "-y", "-i", src, "-af", af, "-ar", "48000", "-ac", "2", dst)


SR = 48000


def decode(path, sr=SR):
    """Float32 stereo samples (n, 2)."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "2", "-ar", str(sr), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2).copy()


def write_wav(path, x, sr=SR):
    p = subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(sr), "-ac", "2", "-i", "-",
                        "-c:a", "pcm_f32le", path], input=np.ascontiguousarray(x, np.float32).tobytes(),
                       capture_output=True)
    if p.returncode:
        raise RuntimeError(p.stderr.decode())


def win_db(x, sr=SR, w=0.5):
    m = x.mean(axis=1) if x.ndim == 2 else x
    n = int(w * sr)
    k = len(m) // n
    r = np.sqrt(np.mean(m[:k * n].reshape(k, n) ** 2, axis=1) + 1e-12)
    return 20 * np.log10(r)


def false_end(x, sr=SR, drop=18.0):
    """A render that stopped and then restarted a fragment: the last >= 0.5 s hole
    (median - drop dB) in the final 25 % is the real ending. Returns the cut sample or None."""
    db = win_db(x, sr)
    med = np.median(db)
    n = len(db)
    for i in range(n - 2, int(n * 0.75) - 1, -1):
        if db[i] < med - drop:
            j = i
            while j > 0 and db[j - 1] < med - drop:
                j -= 1
            # end on the hole start, but keep at least the window before it at level
            return int(j * 0.5 * sr)
    return None


def soft_tail(x, sr=SR, max_s=10.0):
    """A loop shouldn't end on a soft last bar: drop up to max_s of trailing 0.5 s
    windows more than 3.5 dB under the median. Returns the new length in samples."""
    db = win_db(x, sr)
    med = np.median(db)
    j, lim = len(db), max(0, len(db) - int(max_s / 0.5))
    while j > lim and db[j - 1] < med - 3.5:
        j -= 1
    return min(len(x), int(j * 0.5 * sr)) if j < len(db) else len(x)


def onset_near(x, t, sr=SR, span=0.5):
    """Strongest onset (rise in 20 ms energy) within +-span s of sample t."""
    m = np.abs(x.mean(axis=1) if x.ndim == 2 else x)
    h = int(0.02 * sr)
    a, b = max(h, t - int(span * sr)), min(len(m) - h, t + int(span * sr))
    if b - a < 4 * h:
        return t
    e = np.array([m[i:i + h].mean() for i in range(a, b, h)])
    d = np.diff(e, prepend=e[0])
    return a + int(np.argmax(d)) * h


def intro_end(x, sr=SR, xfade=3.0):
    """Where a quiet intro has built up to the body level. A classic loop lands at
    t = xfade; when the 1 s there sits more than 3 dB under the song's level (the
    lower of its median and its last 2 s, which is what plays into the loop), the loop
    point moves to the first 0.5 s window back within 3 dB of that level (snapped to an
    onset), and the intro before it plays once. 0 = classic loop."""
    db = win_db(x, sr)
    if len(db) < 16:
        return 0
    tail = float(np.mean(db[-2:]))
    ref = min(float(np.median(db)), tail)
    k = int(round(xfade / 0.5))
    # the loop's crossfade passes through the 2 s before the loop point: a quiet
    # bar there (hit, then silence, then the band) dips every loop too
    at = min(float(np.mean(db[k:k + 2])), float(np.mean(db[max(0, k - 4):k + 2])))
    if at >= ref - 3.0 and at >= tail - 3.5:
        return 0
    goal = ref - (1.5 if at >= ref - 3.0 else 3.0)
    i = k
    while i < len(db) // 3 and db[i] < goal:
        i += 1
    if i >= len(db) // 3:
        return 0
    return onset_near(x, int(i * 0.5 * sr), sr)


def seamless_np(x, xfade, offset=0, sr=SR):
    """Sample-accurate equal-power loop seam: the last xfade s fade out while the music
    from the loop point fades in, and Godot loops to the end of that fade-in, so
    end -> loop point is continuous and at level.
    offset 0: classic loop (the file starts xfade s in; loop_offset 0).
    offset > 0: the intro before `offset` is kept and plays once; loop_offset =
    offset + xfade (written to data/music_loops.json, read by Music).
    Returns (samples, loop_offset_seconds)."""
    n = len(x)
    X = int(max(0.2, min(xfade, n / sr / 4)) * sr)
    t = np.linspace(0, np.pi / 2, X, dtype=np.float32)[:, None]
    fo, fi = np.cos(t), np.sin(t)
    if offset <= 0:
        y = np.concatenate([x[X:n - X], x[n - X:] * fo + x[:X] * fi])
        assert len(y) == n - X, (len(y), n, X)
        return y, 0.0
    y = np.concatenate([x[:n - X], x[n - X:] * fo + x[offset:offset + X] * fi])
    assert len(y) == n, (len(y), n)
    return y, (offset + X) / sr


def seam_ok(y, offset_s=0.0, sr=SR):
    """The join (last sample -> loop point) steps no more than 3x the 99th pct step."""
    m = y.mean(axis=1)
    o = int(round(offset_s * sr))
    step = abs(float(m[-1] - m[o]))
    p99 = float(np.percentile(np.abs(np.diff(m)), 99))
    return step <= 3 * p99 + 1e-4, step, p99


def seamless(src, dst, xfade, offset=0):
    """File version (kept for tools that call it): returns loop_offset seconds."""
    x = decode(src)
    y, lo = seamless_np(x, xfade, offset)
    write_wav(dst, y)
    return lo


def measure(path, hp=0):
    """Integrated loudness (LUFS) and true peak (dBTP); hp > 0 measures through a
    hp Hz 4-pole high-pass (phone-speaker proxy)."""
    pre = f"highpass=f={hp}:poles=2,highpass=f={hp}:poles=2," if hp else ""
    p = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", pre + "ebur128=peak=true",
                        "-f", "null", "-"], capture_output=True, text=True)
    tail = p.stderr[p.stderr.rindex("Summary:"):]
    i = float(re.search(r"I:\s+(-?[\d.]+|-inf) LUFS", tail).group(1))
    tp = re.search(r"Peak:\s+(-?[\d.]+|-inf) dBFS", tail)
    return i, (float(tp.group(1)) if tp else 0.0)


def low_share(x, sr=SR, cut=120.0):
    m = x.mean(axis=1)[: sr * 90]
    f = np.abs(np.fft.rfft(m)) ** 2
    fr = np.fft.rfftfreq(len(m), 1 / sr)
    return float(f[fr < cut].sum() / (f.sum() + 1e-12))


PHONE_TARGET = -20.0   # loudness through the 300 Hz proxy (bright songs at -16 LUFS read about -19.5)
PHONE_CUT, PHONE_LIFT = -1.5, 3.0  # clamp: integrated loudness stays within -17.5..-13 LUFS


def phone_master(src, dst, target=-16.0):
    """Game master: bass-heavy songs get a low shelf + presence lift so they survive a
    phone speaker, then loudnorm to -16 LUFS / -1.5 dBTP, then a clamped phone-proxy trim
    (-1.5..+3 dB) under a true-peak limiter."""
    x = decode(src)
    eq = ""
    if low_share(x) > 0.45:
        eq = "bass=g=-4:f=120:w=0.7,equalizer=f=3000:t=q:w=1.0:g=1.5"
    loudnorm(src, dst + ".n.wav", target, eq)
    ph, _ = measure(dst + ".n.wav", hp=300)
    g = max(PHONE_CUT, min(PHONE_LIFT, PHONE_TARGET - ph))
    if abs(g) < 0.3:
        os.replace(dst + ".n.wav", dst)
    else:
        run("ffmpeg", "-hide_banner", "-y", "-i", dst + ".n.wav", "-af",
            f"volume={g:.2f}dB,alimiter=limit=0.84:attack=2:release=60:level=disabled", "-ar", "48000", dst)
        os.remove(dst + ".n.wav")
    return g


LOOPS = os.path.join(ROOT, "data", "music_loops.json")


def set_loop(name, sec):
    import fcntl
    with open(LOOPS + ".lock", "w") as lk:
        fcntl.flock(lk, fcntl.LOCK_EX)
        _set_loop(name, sec)


def _set_loop(name, sec):
    d = json.load(open(LOOPS)) if os.path.exists(LOOPS) else {}
    if sec > 0:
        d[name] = round(sec, 3)
    else:
        d.pop(name, None)
    tmp = LOOPS + ".tmp"
    with open(tmp, "w") as f:
        json.dump(d, f, indent=1, sort_keys=True)
        f.write("\n")
    os.replace(tmp, LOOPS)


def add_real(listfile, name):
    os.makedirs(os.path.dirname(listfile), exist_ok=True)
    have = set()
    if os.path.exists(listfile):
        have = {l.strip() for l in open(listfile) if l.strip() and not l.startswith("#")}
    if name not in have:
        old = open(listfile).read() if os.path.exists(listfile) else ""
        if os.path.exists(listfile):
            os.remove(listfile)  # audio/ is hardlinked across worktrees: never append in place
        with open(listfile, "w") as f:
            f.write(old + ("" if old.endswith("\n") or not old else "\n") + name + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("src")
    ap.add_argument("--kind", default="music", choices=["music", "jingle"])
    ap.add_argument("--trim", default="")
    ap.add_argument("--loop-xfade", type=float, default=3.0)
    ap.add_argument("--once", action="store_true", help="plays once (endings, credits): keep the natural ending, no loop seam")
    ap.add_argument("--no-offset", action="store_true", help="loop to 0 even after a quiet intro")
    ap.add_argument("--dry", default="", help="write here instead of the repo (testing)")
    a = ap.parse_args()
    tmp = tempfile.mkdtemp(prefix="ace_")
    ext = os.path.splitext(a.src)[1] or ".mp3"
    # Originals stay outside the repo (they are re-downloadable from ACE by song id,
    # logged in audio/ACE_LOG.json); only the game-ready .ogg is committed.
    if a.kind == "music":
        t1 = os.path.join(tmp, "t1.wav")
        # cut silence and any fade-out tail so the loop never dips (see ace_pick.trim_quiet)
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import ace_pick
        x, sr = ace_pick.load(a.src)
        s0, s1 = ace_pick.trim_quiet(x, sr, tail_db=40.0 if a.once else 9.0)
        if not a.once:
            fe = false_end(x[s0:s1], sr)
            if fe is not None and fe > 0.5 * (s1 - s0):
                print(f"  false ending at {(s0 + fe) / sr:.1f} s: cut there")
                s1 = s0 + fe
            s1 = s0 + soft_tail(x[s0:s1], sr)
        run("ffmpeg", "-hide_banner", "-y", "-i", a.src, "-af",
            f"atrim={s0 / sr}:{s1 / sr},asetpts=PTS-STARTPTS", t1)
        t2 = os.path.join(tmp, "t2.wav")
        g = phone_master(t1, t2)
        t3 = os.path.join(tmp, "t3.wav")
        lo = 0.0
        if a.once:
            d = duration(t2)
            run("ffmpeg", "-hide_banner", "-y", "-i", t2, "-af", f"afade=t=out:st={max(0.0, d - 2.5)}:d=2.5", t3)
        else:
            xs = decode(t2)
            off = 0 if a.no_offset else intro_end(xs, SR, a.loop_xfade)
            y, lo = seamless_np(xs, a.loop_xfade, off)
            write_wav(t3, y)
        outdir = a.dry or os.path.join(AUD, "music")
        out = os.path.join(outdir, a.name + ".ogg")
        if os.path.exists(out):
            os.remove(out)  # audio/ is hardlinked across worktrees: never write through the link
        run("ffmpeg", "-hide_banner", "-y", "-i", t3, "-c:a", "libvorbis", "-q:a", "3", out)
        if not a.once:
            ok, step, p99 = seam_ok(decode(out), lo)
            exp = duration(t3)
            if not ok or abs(duration(out) - exp) > 0.05:
                sys.exit(f"seam check failed for {out}: step {step:.4f} vs p99 {p99:.4f}, "
                         f"dur {duration(out):.2f} vs {exp:.2f}")
        if not a.dry:
            add_real(os.path.join(AUD, "music", "REAL.txt"), a.name)
            set_loop(a.name, lo)
        print(f"  phone trim {g:+.1f} dB, loop_offset {lo:.2f} s")
    else:
        if not a.trim:
            sys.exit("--trim START:END is required for a jingle")
        s, e = (float(v) for v in a.trim.split(":"))
        t1 = os.path.join(tmp, "t1.wav")
        fade = min(0.6, (e - s) / 3)
        run("ffmpeg", "-hide_banner", "-y", "-i", a.src, "-af",
            f"atrim={s}:{e},asetpts=PTS-STARTPTS,afade=t=in:d=0.02,afade=t=out:st={e - s - fade}:d={fade}", t1)
        outdir = a.dry or os.path.join(AUD, "sfx")
        out = os.path.join(outdir, a.name + ".ogg")
        t2 = os.path.join(tmp, "t2.wav")
        loudnorm(t1, t2, -14)
        run("ffmpeg", "-hide_banner", "-y", "-i", t2, "-c:a", "libvorbis", "-q:a", "5", out)
        if not a.dry:
            add_real(os.path.join(AUD, "sfx", "REAL.txt"), a.name)
    shutil.rmtree(tmp, ignore_errors=True)
    print(f"wrote {out} ({duration(out):.1f} s)")


if __name__ == "__main__":
    main()
