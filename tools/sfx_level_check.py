#!/usr/bin/env python3
"""Level guard for audio/sfx (C13): catches brick-walled stings and late-starting impacts.

    python3 tools/sfx_level_check.py [--report]

Fails (exit 1) when
  * a file's loudest-100 ms RMS (SOFTEN_LOG after.rms) is above -8 dBFS (j_buy/j_confirm were -1.5);
  * a jingle got more than +12 dB from the softener (short clips gated to -70 LUFS got +53);
  * an impact cue (sfx_soften.IMPACT) starts more than 60 ms after its file start (haptic lag);
  * data/sfx_meta.json (len_audible per file, read by Music's jingle duck) misses a file.
Reports (no fail): take groups whose phone-proxy spread is over 4 dB, and j_* / levelup /
quest_done jingles with no _gang twin (the gang arc then hears the penguin sting).
"""
import glob, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, HERE)
import sfx_soften as S

MAX_RMS = -8.0
MAX_JINGLE_GAIN = 12.0
MAX_ONSET_MS = 60.0


def main():
    log = json.load(open(S.LOG))
    meta = json.load(open(S.META)) if os.path.exists(S.META) else {}
    names = sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(S.SFX, "*.ogg")))
    bad, notes = [], []
    for n in names:
        e = log.get(n, {})
        a = e.get("after", {})
        if a.get("rms", -99) > MAX_RMS:
            bad.append(f"{n}: loudest-100ms RMS {a['rms']} dBFS > {MAX_RMS} (brick-walled)")
        if str(e.get("mode", "")).startswith("jingle") and e.get("gain_db", 0) > MAX_JINGLE_GAIN:
            bad.append(f"{n}: jingle gain +{e['gain_db']} dB > +{MAX_JINGLE_GAIN}")
        if n not in meta:
            bad.append(f"{n}: missing from data/sfx_meta.json (run python3 tools/sfx_soften.py --meta)")
        if n.startswith(S.IMPACT):
            ms = S.onset_ms(S.decode(os.path.join(S.SFX, n + ".ogg"), 1))
            if ms > MAX_ONSET_MS:
                bad.append(f"{n}: starts {ms:.0f} ms late (> {MAX_ONSET_MS:.0f}); sfx_soften.py --force --retarget --only {n}")
    groups = {}
    for n in names:
        if not S.is_jingle(n) and "phone_loss" in log.get(n, {}).get("after", {}):
            groups.setdefault(S.base_of(n), []).append(n)
    for g, mem in sorted(groups.items()):
        if len(mem) > 1:
            ph = [log[k]["after"]["rms"] - log[k]["after"]["phone_loss"] for k in mem]
            if max(ph) - min(ph) > 4.0:
                notes.append(f"phone spread {max(ph) - min(ph):.1f} dB in {g} ({', '.join(mem)})")
    have = set(names)
    for n in names:
        if (n.startswith("j_") or n in ("levelup", "quest_done")) and not n.endswith("_gang") \
                and S.base_of(n) == n and n + "_gang" not in have:
            notes.append(f"no gang twin: {n}")
    for b in bad:
        print("sfx_level_check FAIL:", b)
    if "--report" in sys.argv or bad:
        for t in notes:
            print("sfx_level_check note:", t)
    print(f"sfx_level_check: {len(names)} files, {len(bad)} problems, {len(notes)} notes")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
