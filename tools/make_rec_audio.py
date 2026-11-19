#!/usr/bin/env python3
"""Rec Center sounds built from CC0 recordings (CONDUCT 2, c2_08).

    python3 tools/make_rec_audio.py [--src /tmp/c2_08_cc0]

Every source is a CC0 pack from OpenGameArt (listed in tools/cc0_sources.json,
credited in docs/AUDIO-CREDITS.md, recorded in audio/CC0_USED.json). The packs
are expected unpacked under --src/<pack slug>/... (see PACKS for the download
URLs). Writes (never through a hardlink: temp file, rm, move):

  audio/sfx/bowl_rumble     a 4 s ball rolling down maple (looped/faded by RecAudio)
  audio/sfx/bowl_gutter     the hollow rumble of a ball in the gutter
  audio/sfx/bowl_pit        the ball dropping into the pit
  audio/sfx/ball_return     the ball coming back up the return and clunking home
  audio/sfx/pin_tap(_2,_3)  one to three pins knocked over
  audio/sfx/pin_strike(_2)  a full rack exploding (layered clatters)
  audio/sfx/juke_needle     a record dropping onto the jukebox platter
  audio/amb/arcade_floor    bed: a room of cabinets in attract mode, murmur, coins
  audio/amb/spot_pins_far   a strike heard through the ceiling (downstairs)
  audio/amb/spot_pins_near   another lane's strike (upstairs)
  audio/amb/spot_cabinet_win  a far-off cabinet fanfare and coin rattle

Then run tools/sfx_soften.py (levels the sfx) as usual.
"""
import argparse, glob, json, os, random, subprocess, sys
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SR = 44100
PACKS = {
    "bowling-ball-rolling": "https://opengameart.org/sites/default/files/qubodup-bowling-roll.7z",
    "vinyl": "https://opengameart.org/sites/default/files/vinylstart.mp3",
    "50-cc0-retro-synth-sfx": "https://opengameart.org/sites/default/files/50-CC0-retro-synth-SFX.zip",
    "512-sound-effects-8-bit-style": "https://opengameart.org/sites/default/files/The%20Essential%20Retro%20Video%20Game%20Sound%20Effects%20Collection%20%5B512%20sounds%5D.zip",
    "68-workshop-sounds": "https://opengameart.org/sites/default/files/workshop.7z",
    "30-cc0-sfx-loops": "https://opengameart.org/sites/default/files/sfx_loops.zip",
    "35-wooden-crackshitsdestructions": "https://opengameart.org/sites/default/files/independent_nu_ljudbank-wood_crack_hit_destruction.7z",
    "crowd-shoutingspeaking-ambience": "https://opengameart.org/sites/default/files/crowd_shouting_0.ogg",
}
USED = {}


def find(src, pack, pat):
    hits = sorted(glob.glob(os.path.join(src, pack, "**", pat), recursive=True))
    if not hits:
        sys.exit("missing %s/%s under %s" % (pack, pat, src))
    return hits[0]


def load(src, pack, pat, af="", name=None):
    p = find(src, pack, pat)
    if name:
        USED.setdefault(name, []).append("%s/%s" % (pack, os.path.relpath(p, os.path.join(src, pack))))
    cmd = ["ffmpeg", "-v", "error", "-i", p, "-ac", "1", "-ar", str(SR)]
    cmd += ["-af", "aresample=%d" % SR + ("," + af if af else "")]  # filters see 44.1k (asetrate pitch shifts)
    cmd += ["-f", "f32le", "-"]
    a = np.frombuffer(subprocess.run(cmd, check=True, capture_output=True).stdout, dtype=np.float32).copy()
    return a


def trim(a, thr=0.01):
    idx = np.where(np.abs(a) > thr * max(1e-6, np.abs(a).max()))[0]
    return a[idx[0]:idx[-1] + 1] if len(idx) else a


def fade(a, fin=0.003, fout=0.05):
    a = a.copy()
    ni, no = int(fin * SR), int(fout * SR)
    if ni:
        a[:ni] *= np.linspace(0, 1, ni)
    if no and no < len(a):
        a[-no:] *= np.linspace(1, 0, no) ** 2
    return a


def peak(a, db=-1.5):
    m = np.abs(a).max()
    return a * (10 ** (db / 20) / m) if m > 0 else a


def gain(a, db):
    return a * 10 ** (db / 20)


def mix(n, parts):
    """parts: [(array, start_s, dB)] into a buffer of n seconds."""
    out = np.zeros(int(n * SR), dtype=np.float32)
    for a, t, db in parts:
        s = int(t * SR)
        e = min(len(out), s + len(a))
        if e > s:
            out[s:e] += gain(a[:e - s], db)
    return out


def ffx(a, af):
    """Run an ffmpeg filter over an array."""
    r = subprocess.run(["ffmpeg", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                        "-af", af, "-f", "f32le", "-"], input=a.astype(np.float32).tobytes(), check=True, capture_output=True)
    return np.frombuffer(r.stdout, dtype=np.float32).copy()


def write(rel, a, q=4):
    path = os.path.join(ROOT, rel)
    tmp = path + ".tmp.ogg"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), tmp], input=a.astype(np.float32).tobytes(), check=True)
    if os.path.exists(path):
        os.remove(path)
    os.rename(tmp, path)
    print("wrote %s (%.2f s)" % (rel, len(a) / SR))


def seamless(a, xf=3.0):
    """Fold the last xf seconds over the start so the file loops without a seam."""
    n = int(xf * SR)
    body, tail = a[:-n].copy(), a[-n:]
    w = np.linspace(0, 1, n)
    body[:n] = body[:n] * np.sqrt(w) + tail * np.sqrt(1 - w)
    return body


def build(src):
    random.seed(8)
    W = "68-workshop-sounds"
    # --- the ball ---------------------------------------------------------------
    roll = load(src, "bowling-ball-rolling", "*nofadeout*.ogg", "highpass=f=40,lowpass=f=6000", "bowl_rumble")
    write("audio/sfx/bowl_rumble.ogg", peak(fade(trim(roll), 0.02, 0.3), -2.0))
    gut = load(src, "bowling-ball-rolling", "*nofadeout*.ogg", "asetrate=%d,aresample=%d,lowpass=f=900,aecho=0.8:0.6:18:0.35" % (int(SR * 0.82), SR), "bowl_gutter")
    write("audio/sfx/bowl_gutter.ogg", peak(fade(trim(gut)[:int(2.6 * SR)], 0.02, 0.8), -4.0))
    thump = load(src, "35-wooden-crackshitsdestructions", "impactwood05*", "lowpass=f=700", "bowl_pit")
    rolltail = load(src, "30-cc0-sfx-loops", "rolling.ogg", "lowpass=f=500", "bowl_pit")
    pit = mix(1.1, [(trim(thump), 0.0, 0.0), (fade(rolltail[:int(0.9 * SR)], 0.05, 0.5), 0.05, -8.0)])
    write("audio/sfx/bowl_pit.ogg", peak(fade(pit, 0.003, 0.4), -3.0))
    ret = load(src, "bowling-ball-rolling", "*nofadeout*.ogg", "asetrate=%d,aresample=%d,lowpass=f=650" % (int(SR * 0.9), SR), "ball_return")[int(0.8 * SR):int(2.4 * SR)]
    ret = ret * np.linspace(0.15, 1.0, len(ret))  # rumbling closer up the return
    clunk = load(src, W, "workshop - wood on concrete.wav", "lowpass=f=1800", "ball_return")
    clunk = trim(clunk)[:int(0.35 * SR)]
    bret = mix(2.0, [(fade(ret, 0.1, 0.2), 0.0, 0.0), (fade(clunk, 0.002, 0.15), 1.45, -2.0)])
    write("audio/sfx/ball_return.ogg", peak(fade(bret, 0.05, 0.2), -3.0))
    # --- the pins -----------------------------------------------------------------
    clap = load(src, W, "workshop - wood clap.wav", "", "pin_tap")
    clat = load(src, W, "workshop - clatter.wav", "", "pin_tap")
    woodclat = load(src, W, "workshop - wood clatter.wav", "", "pin_strike")
    loud = load(src, W, "workshop - loud clatter.wav", "", "pin_strike")
    knock = load(src, "35-wooden-crackshitsdestructions", "impactwood01*", "", "pin_strike")
    knock2 = load(src, "35-wooden-crackshitsdestructions", "impactwood09*", "", "pin_tap")
    write("audio/sfx/pin_tap.ogg", peak(fade(trim(clap)[:int(0.5 * SR)], 0.002, 0.15), -3.0))
    write("audio/sfx/pin_tap_2.ogg", peak(fade(trim(clat), 0.002, 0.15), -3.0))
    tap3 = mix(0.6, [(trim(knock2), 0.0, -4.0), (trim(clap)[:int(0.4 * SR)], 0.05, 0.0)])
    write("audio/sfx/pin_tap_3.ogg", peak(fade(tap3, 0.002, 0.15), -3.0))
    s1 = mix(1.8, [(trim(knock), 0.0, -3.0), (trim(loud), 0.02, 0.0), (trim(woodclat), 0.12, -3.0), (trim(clat), 0.42, -8.0)])
    write("audio/sfx/pin_strike.ogg", peak(fade(s1, 0.002, 0.4), -1.5))
    s2 = mix(1.8, [(trim(knock2), 0.0, -3.0), (trim(woodclat), 0.01, 0.0), (trim(loud), 0.09, -2.0), (trim(clap)[:int(0.4 * SR)], 0.55, -9.0)])
    write("audio/sfx/pin_strike_2.ogg", peak(fade(s2, 0.002, 0.4), -1.5))
    # --- the jukebox ----------------------------------------------------------------
    nd = load(src, "vinyl", "vinylstart.mp3", "highpass=f=60", "juke_needle")
    nd = ffx(peak(trim(nd)[:int(2.4 * SR)], -1.0), "acompressor=threshold=-36dB:ratio=6:attack=2:release=120:makeup=4")  # bring the crackle up under the drop
    write("audio/sfx/juke_needle.ogg", peak(fade(nd, 0.005, 0.7), -3.0))
    # --- ambience: downstairs arcade floor --------------------------------------------
    L = 52.0
    crowd = load(src, "crowd-shoutingspeaking-ambience", "crowd_shouting_0.ogg", "lowpass=f=1100,highpass=f=120", "arcade_floor")
    crowd = np.concatenate([crowd, crowd[::-1], crowd])[:int(L * SR)]  # long enough; reversed murmur is still murmur
    G = "512-sound-effects-8-bit-style"
    chips = []
    for pat in ["sfx_coin_single1.wav", "sfx_coin_single4.wav", "sfx_coin_double2.wav", "sfx_coin_cluster3.wav",
                "sfx_sounds_powerup3.wav", "sfx_sounds_powerup7.wav", "sfx_sounds_powerup12.wav",
                "sfx_sounds_Blip2.wav", "sfx_sounds_Blip5.wav", "sfx_sounds_Blip9.wav",
                "sfx_sounds_interaction4.wav", "sfx_sounds_interaction11.wav", "sfx_sounds_interaction19.wav",
                "sfx_menu_move2.wav", "sfx_menu_select3.wav", "sfx_sounds_fanfare2.wav"]:
        chips.append(trim(load(src, G, pat, "lowpass=f=3200,aecho=0.7:0.5:35|70:0.3|0.18", "arcade_floor")))
    for pat in ["retro_coin_01.ogg", "retro_misc_02.ogg", "retro_misc_04.ogg", "power_up_02.ogg", "synth_beep_01.ogg", "synth_misc_05.ogg"]:
        chips.append(trim(load(src, "50-cc0-retro-synth-sfx", pat, "lowpass=f=3000,aecho=0.7:0.5:40|80:0.3|0.15", "arcade_floor")))
    parts = [(crowd, 0.0, -14.0)]
    t = 0.6
    while t < L - 5.0:
        c = random.choice(chips)
        parts.append((c / max(1e-6, np.abs(c).max()), t, random.uniform(-30.0, -22.0)))
        t += random.uniform(0.5, 2.2)
    floor = seamless(mix(L, parts), 4.0)
    write("audio/amb/arcade_floor.ogg", peak(floor, -6.0), q=3)
    # --- spots ------------------------------------------------------------------------
    far = ffx(s1, "lowpass=f=650,aecho=0.8:0.7:60|120:0.35|0.2")
    write("audio/amb/spot_pins_far.ogg", peak(fade(far[:int(2.2 * SR)], 0.01, 0.8), -6.0))
    near = ffx(s2, "lowpass=f=3500,aecho=0.8:0.5:30|70:0.25|0.12")
    write("audio/amb/spot_pins_near.ogg", peak(fade(near[:int(2.0 * SR)], 0.005, 0.6), -4.0))
    fan = trim(load(src, G, "sfx_sounds_fanfare1.wav", "lowpass=f=2600,aecho=0.8:0.6:45|90:0.35|0.2", "spot_cabinet_win"))
    coins = trim(load(src, G, "sfx_coin_cluster6.wav", "lowpass=f=3000", "spot_cabinet_win"))
    win = mix(2.4, [(fan / np.abs(fan).max(), 0.0, 0.0), (coins / np.abs(coins).max(), 0.55, -6.0)])
    write("audio/amb/spot_cabinet_win.ogg", peak(fade(win, 0.005, 0.5), -6.0))


def record():
    p = os.path.join(ROOT, "audio", "CC0_USED.json")
    d = json.load(open(p))
    for k, v in USED.items():
        d[k] = sorted(set(v))
    tmp = p + ".tmp"
    json.dump(d, open(tmp, "w"), indent=1, sort_keys=True)
    os.remove(p)
    os.rename(tmp, p)
    for real, names in [("audio/sfx/REAL.txt", ["bowl_rumble", "bowl_gutter", "bowl_pit", "ball_return", "pin_tap", "pin_tap_2", "pin_tap_3", "pin_strike", "pin_strike_2", "juke_needle"]),
                        ("audio/amb/REAL.txt", ["arcade_floor", "spot_pins_far", "spot_pins_near", "spot_cabinet_win"])]:
        rp = os.path.join(ROOT, real)
        have = open(rp).read().split()
        add = [n for n in names if n not in have]
        if add:
            txt = open(rp).read().rstrip("\n") + "\n" + "\n".join(add) + "\n"
            os.remove(rp)
            open(rp, "w").write(txt)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="/tmp/c2_08_cc0")
    a = ap.parse_args()
    build(a.src)
    record()
