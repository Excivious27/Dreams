#!/usr/bin/env python3
"""Bring an ACE Music render into the game.

    python3 tools/ace_import.py <name> <file.mp3|wav> [--kind music|jingle] [--trim START:END]
                                [--loop-xfade 2.0] [--dry OUTDIR]

music  : trims leading/trailing silence, loudness-normalises to -16 LUFS (EBU R128),
         makes the end flow back into the start (crossfades the tail over the head so
         Godot's loop is seamless), writes audio/music/<name>.ogg (Vorbis q4, 48 kHz stereo)
         and adds <name> to audio/music/REAL.txt so the placeholder generators never
         overwrite it.
jingle : takes --trim START:END seconds (a short phrase from a 30 s render), fades the
         tail, normalises to -14 LUFS, writes audio/sfx/<name>.ogg and lists it in
         audio/sfx/REAL.txt.

Originals are not copied into the repo; audio/ACE_LOG.json records each track's ACE song ids.
Needs ffmpeg/ffprobe. Run `godot --headless --path . --import` afterwards.
"""
import argparse, json, os, shutil, subprocess, sys, tempfile

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


def seamless(src, dst, xfade):
    """Crossfade the last `xfade` s over the first `xfade` s, so end -> start is continuous."""
    d = duration(src)
    x = max(0.2, min(xfade, d / 4))
    flt = (f"[0:a]atrim=0:{x},asetpts=PTS-STARTPTS[head];"
           f"[0:a]atrim={x}:{d - x},asetpts=PTS-STARTPTS[body];"
           f"[0:a]atrim={d - x}:{d},asetpts=PTS-STARTPTS[tail];"
           f"[tail][head]acrossfade=d={x}:c1=tri:c2=tri[join];"
           f"[body][join]concat=n=2:v=0:a=1[out]")
    run("ffmpeg", "-hide_banner", "-y", "-i", src, "-filter_complex", flt, "-map", "[out]", dst)


def add_real(listfile, name):
    os.makedirs(os.path.dirname(listfile), exist_ok=True)
    have = set()
    if os.path.exists(listfile):
        have = {l.strip() for l in open(listfile) if l.strip() and not l.startswith("#")}
    if name not in have:
        with open(listfile, "a") as f:
            f.write(name + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("src")
    ap.add_argument("--kind", default="music", choices=["music", "jingle"])
    ap.add_argument("--trim", default="")
    ap.add_argument("--loop-xfade", type=float, default=3.0)
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
        s0, s1 = ace_pick.trim_quiet(x, sr)
        run("ffmpeg", "-hide_banner", "-y", "-i", a.src, "-af",
            f"atrim={s0 / sr}:{s1 / sr},asetpts=PTS-STARTPTS", t1)
        t2 = os.path.join(tmp, "t2.wav")
        loudnorm(t1, t2, -16)
        t3 = os.path.join(tmp, "t3.wav")
        seamless(t2, t3, a.loop_xfade)
        outdir = a.dry or os.path.join(AUD, "music")
        out = os.path.join(outdir, a.name + ".ogg")
        run("ffmpeg", "-hide_banner", "-y", "-i", t3, "-c:a", "libvorbis", "-q:a", "4", out)
        if not a.dry:
            add_real(os.path.join(AUD, "music", "REAL.txt"), a.name)
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
