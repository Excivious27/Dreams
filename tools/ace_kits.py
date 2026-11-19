#!/usr/bin/env python3
"""Turn ACE kit and jingle renders into named game sounds.

    python3 tools/ace_kits.py [--raw /home/claude/work/ace_raw] [--dry DIR]

Jingle renders (jin_*) were asked for as four short cues in a row (one per
section); each is cut into its four quarters and the strongest-starting 2-3.5 s
phrase of each quarter becomes that cue, with a clean fade. Kit renders (kit_*)
are solo instruments; tools/ace_slice_hits.py --onsets cuts them into single
notes and the cleanest are assigned by brightness (bright = up/confirm, dark =
down/cancel). The chosen ACE version of each render comes from audio/ACE_LOG.json.

Outputs audio/sfx/<name>.ogg (+ _2/_3), lists the names in audio/sfx/ACE.txt
(cc0_import.py leaves those alone) and audio/sfx/REAL.txt.
"""
import argparse, json, os, subprocess, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
import ace_pick

# render -> four cue names, in the order the prompt asked for them
JINGLES = {
    "jin_bright": ["levelup", "quest_done", "j_skill", "j_victory"],
    "jin_warm": ["j_heart", "j_gift", "j_birthday", "j_morning"],
    "jin_disc": ["j_secret", "j_page", "j_region", "j_treasure"],
    "jin_battle": ["j_battle_won", "j_battle_lost", "j_battle_start", "j_campaign_won"],
}
# extra names that reuse a cue
ALIASES = {"boss_down": "j_victory", "sleep": "j_morning", "craft_done": "j_skill"}
# kit -> list of (name, takes, rank) ; rank picks notes from bright (0.0) to dark (1.0)
KITS = {
    "kit_marimba": [("ui_tap", 3, 0.35), ("menu_open", 1, 0.1), ("menu_close", 1, 0.8), ("j_confirm", 1, 0.0),
                    ("nope", 1, 1.0), ("talk_blip", 3, 0.5), ("tab", 2, 0.25), ("scroll_tick", 2, 0.6), ("alert", 1, 0.95)],
    "kit_bells": [("sparkle", 3, 0.1), ("crop_ready", 1, 0.3), ("new_item", 2, 0.2), ("tell", 1, 0.6), ("bite", 1, 0.0),
                  ("shop_bell", 1, 0.45), ("j_buy", 1, 0.15), ("save_done", 1, 0.5)],
}


def chosen(log, name, raw):
    e = log.get(name)
    if not e:
        return None
    return os.path.join(raw, f"{name}__{e['chosen']}.mp3")


def write_ogg(x, sr, dst, q=4):
    tmp = dst + ".wav"
    import wave
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), dst], check=True)
    os.remove(tmp)


def fade(seg, sr, fi=0.005, fo=0.5):
    seg = seg.copy()
    a = int(fi * sr); b = min(int(fo * sr), len(seg) // 2)
    seg[:a] *= np.linspace(0, 1, a)
    seg[-b:] *= np.linspace(1, 0, b) ** 1.5
    pk = float(np.max(np.abs(seg))) or 1.0
    return seg * (0.89 / pk)


def cut_jingles(src, names, out_dir, done):
    x, sr = ace_pick.load(src, 44100)
    hop = int(0.02 * sr)
    n = len(x) // hop
    env = np.sqrt(np.mean(x[:n * hop].reshape(n, hop) ** 2, axis=1) + 1e-12)
    db = 20 * np.log10(env)
    q = n // 4
    for k, name in enumerate(names):
        lo, hi = k * q, (k + 1) * q
        best, bs = lo, -1e9
        for i in range(lo + 5, hi - int(2.2 / 0.02)):
            # a phrase start: louder than the moment before it, and not quieter after
            s = (db[i:i + 10].mean() - db[i - 5:i].mean()) + 0.2 * db[i:i + 50].mean()
            if s > bs:
                bs, best = s, i
        L = min(int(3.2 / 0.02), hi - best)
        # end at the quietest point in the last second, so it doesn't stop mid-note
        tail = db[best + L - 50:best + L]
        end = best + L - 50 + int(np.argmin(tail)) if len(tail) else best + L
        seg = fade(x[best * hop:end * hop], sr, fo=0.6)
        write_ogg(seg, sr, os.path.join(out_dir, name + ".ogg"))
        done.append(name)


def cut_kit(src, spec, out_dir, done, tmp):
    d = os.path.join(tmp, os.path.basename(src))
    subprocess.run([sys.executable, os.path.join(HERE, "ace_slice_hits.py"), src, d, "--onsets", "--max", "0.9", "--keep", "40"], check=True, capture_output=True)
    hits = json.load(open(os.path.join(d, "hits.json")))
    hits = [h for h in hits if h["len"] >= 0.12]
    hits.sort(key=lambda h: -h["bright_hz"])
    used = set()
    import wave
    for name, takes, rank in spec:
        idx = int(round(rank * (len(hits) - 1)))
        picks = []
        for off in [0, 1, -1, 2, -2, 3, -3, 4, -4]:
            j = idx + off
            if 0 <= j < len(hits) and j not in used:
                picks.append(j); used.add(j)
            if len(picks) >= takes:
                break
        for t, j in enumerate(picks):
            with wave.open(os.path.join(d, hits[j]["file"])) as w:
                x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32767
                sr = w.getframerate()
            x = fade(x, sr, fo=min(0.25, len(x) / sr / 2))
            nm = name if t == 0 else f"{name}_{t + 1}"
            write_ogg(x, sr, os.path.join(out_dir, nm + ".ogg"))
            done.append(nm)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", default="/home/claude/work/ace_raw")
    ap.add_argument("--dry", default="")
    a = ap.parse_args()
    log = json.load(open(os.path.join(ROOT, "audio", "ACE_LOG.json")))
    out = a.dry or os.path.join(ROOT, "audio", "sfx")
    tmp = "/tmp/ace_kits"
    os.makedirs(tmp, exist_ok=True)
    done = []
    for r, names in JINGLES.items():
        src = chosen(log, r, a.raw)
        if src and os.path.exists(src):
            cut_jingles(src, names, out, done)
    for r, spec in KITS.items():
        src = chosen(log, r, a.raw)
        if src and os.path.exists(src):
            cut_kit(src, spec, out, done, tmp)
    for al, base in ALIASES.items():
        p = os.path.join(out, base + ".ogg")
        if os.path.exists(p):
            subprocess.run(["cp", p, os.path.join(out, al + ".ogg")], check=True)
            done.append(al)
    if not a.dry:
        for lst in ("ACE.txt", "REAL.txt"):
            p = os.path.join(ROOT, "audio", "sfx", lst)
            have = set(l.strip() for l in open(p)) if os.path.exists(p) else set()
            with open(p, "a") as f:
                for n in sorted(set(done) - have):
                    f.write(n + "\n")
    print(len(done), "ACE sounds:", " ".join(sorted(done)))


if __name__ == "__main__":
    main()
