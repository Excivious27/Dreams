#!/usr/bin/env python3
"""Extra placeholder area tracks (chiptune, same engine as make_audio.py).
Only writes tracks that are missing, so real songs dropped in under the same
name are never overwritten. Run: python3 tools/make_music_extra.py [--force]"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_audio as A

TRACKS = [
    ("forest", 96, ["Am", "F", "C", "G", "Am", "Dm", "F", "Em"], A.AMIN, 21, dict(lead_wave="tri", lead_vol=0.14, duty=0.3, bars_per_chord=2)),
    ("night", 62, ["Am", "F", "C", "Em", "Am", "F", "Dm", "Em"], A.AMIN, 22, dict(lead_wave="sine", drums=False, lead_vol=0.12, bars_per_chord=2, dark=True)),
    ("danger", 132, ["Cm", "Fm", "Cm", "G", "Cm", "Ab", "Fm", "G"], A.CMIN, 23, dict(lead_wave="saw", lead_vol=0.12, duty=0.25, dark=True)),
    ("battle", 140, ["Cm", "Eb", "Ab", "G", "Cm", "Eb", "Fm", "G"], A.CMIN, 24, dict(lead_wave="square", lead_vol=0.14, duty=0.5)),
    ("neon", 118, ["Am", "Dm", "Em", "Am", "F", "G", "Em", "Am"], A.AMIN, 25, dict(lead_wave="square", lead_vol=0.13, duty=0.25, dark=True)),
    ("marsh", 70, ["Dm", "Am", "Bb", "Am", "Dm", "Gm", "Bb", "Am"], A.AMIN, 26, dict(lead_wave="tri", drums=False, lead_vol=0.12, bars_per_chord=2, dark=True)),
    ("jungle", 110, ["Em", "C", "D" if "D" in A.CHORDS else "G", "Em", "C", "G", "Am", "Em"], A.AMIN, 27, dict(lead_wave="tri", lead_vol=0.14, duty=0.3)),
    ("festival", 128, ["C", "G", "F", "C", "Am", "F", "G", "C"], A.MAJ, 28, dict(lead_wave="square", lead_vol=0.15, duty=0.5)),
    ("colony_coral", 100, ["F", "C", "Dm", "Bb", "F", "C", "Bb", "C"], A.MAJ, 31, dict(lead_wave="sine", lead_vol=0.15, duty=0.3)),
    ("colony_kelp", 84, ["Dm", "Bb", "F", "C", "Dm", "Gm", "Bb", "Am"], A.AMIN, 32, dict(lead_wave="tri", drums=False, lead_vol=0.13, bars_per_chord=2)),
    ("colony_ice", 76, ["Am", "Em", "F", "C", "Am", "Em", "Dm", "Em"], A.AMIN, 33, dict(lead_wave="sine", drums=False, lead_vol=0.13, bars_per_chord=2)),
    ("colony_ember", 112, ["Cm", "Ab", "Eb", "G", "Cm", "Fm", "Ab", "G"], A.CMIN, 34, dict(lead_wave="saw", lead_vol=0.12, duty=0.25)),
    ("hollow_heart", 66, ["Am", "F", "Dm", "Em", "Am", "C", "Dm", "Em"], A.AMIN, 35, dict(lead_wave="sine", drums=False, lead_vol=0.12, bars_per_chord=2, dark=True)),
    ("winter", 88, ["C", "Am", "F", "G", "C", "Em", "Dm", "G"], A.MAJ, 36, dict(lead_wave="tri", drums=False, lead_vol=0.14, bars_per_chord=2)),
    ("wastes", 92, ["Em", "C", "Am", "Em", "C", "G", "Am", "Em"], A.AMIN, 37, dict(lead_wave="saw", lead_vol=0.11, duty=0.25, dark=True)),
]

if __name__ == "__main__":
    force = "--force" in sys.argv
    for name, bpm, prog, scale, seed, kw in TRACKS:
        out = os.path.join(A.ROOT, "music", f"{name}.ogg")
        if os.path.exists(out) and not force:
            continue
        if name in A.REAL_TRACKS:
            continue
        A.compose(name, bpm, prog, scale, seed, **kw)
