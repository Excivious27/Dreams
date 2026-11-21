#!/usr/bin/env python3
"""C13 audio tool tests (no network, no repo writes):
  * sfx_soften.jingle_pass levels a 0.3 s sting on the loudest-100 ms path (never the +53 dB
    a gated -70 LUFS reading gave j_buy/j_confirm), caps jingle gain, keeps RMS off the wall;
  * sfx_soften.len_audible ends a sting at its audible tail, not its silent padding;
  * sfx_soften.is_jingle treats <jingle>_gang arc twins as jingles;
  * sfx_soften.lead_trim lands an impact within 20 ms of its start;
  * ace_batch --alt imports the NON-chosen take under a new name with alt_of, and --pair's
    accept rule (score >= 60 and within 15 of the chosen take)."""
import json, os, sys, tempfile
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sfx_soften as S
import ace_batch as B

fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)


sr = S.SR
t = np.arange(int(0.3 * sr)) / sr
sting = (0.6 * np.sin(2 * np.pi * 880 * t) * np.exp(-t * 6)).astype(np.float32)
y, rec = S.jingle_pass(sting, "j_buy")
m = S.measure(y)
check(rec["mode"] == "jingle_short", f"short sting mode {rec['mode']}")
check(rec["gain_db"] <= 6.0, f"short sting gain {rec['gain_db']} > 6")
check(m["rms"] <= S.JINGLE_MAX_RMS + 0.2, f"short sting rms {m['rms']} above {S.JINGLE_MAX_RMS}")
check(m["peak"] - m["rms"] > 2.0, "short sting brick-walled (peak == rms)")
quiet = (sting * 0.001).astype(np.float32)  # very quiet source: never boosted past the cap
_, rq = S.jingle_pass(quiet, "j_confirm")
check(rq["gain_db"] <= 6.0, f"quiet short sting gain {rq['gain_db']}")

pad = np.concatenate([sting, np.zeros(int(1.0 * sr), np.float32)])
la = S.len_audible(pad)
check(0.15 <= la <= 0.45, f"len_audible {la} (sting 0.3 s + 1 s silence)")

check(S.is_jingle("levelup_gang") and S.is_jingle("j_victory_gang") and S.is_jingle("ach_unlock"), "gang twins are jingles")
check(not S.is_jingle("block_gang"), "block_gang is not a jingle")

hit = np.concatenate([np.zeros(int(0.2 * sr), np.float32), 1e-3 * np.ones(int(0.1 * sr), np.float32), sting])
lt = S.lead_trim(hit, "block_3")
check(S.onset_ms(lt) < 20.0 or len(hit) - len(lt) >= int(0.29 * sr), f"impact lead trim left {S.onset_ms(lt):.0f} ms")

# ace_batch --alt on a temp log, import stubbed
tmp = tempfile.mkdtemp()
raw = os.path.join(tmp, "x__b.mp3")
open(raw, "wb").write(b"0" * 20000)
B.LOG = os.path.join(tmp, "ACE_LOG.json")
log = {"x": {"kind": "music", "chosen": "a", "versions": [
    {"id": "a", "file": os.path.join(tmp, "x__a.mp3"), "score": {"score": 80}},
    {"id": "b", "file": raw, "score": {"score": 70}}]}}
seen = []
B.imp = lambda name, kind, path, extra=(): seen.append((name, kind, path))
rc = B.do_alt(log, "x", "x_2")
saved = json.load(open(B.LOG))
check(rc == 0 and seen == [("x_2", "music", raw)], f"--alt imported {seen} rc {rc}")
check(saved.get("x_2", {}).get("alt_of") == "x" and saved["x_2"]["chosen"] == "b", "--alt log row")
check(saved["x"]["chosen"] == "a", "--alt must not change the source's chosen take")
check(B.do_alt(log, "nope", "n") == 2, "--alt unknown source")
os.remove(raw)
check(B.do_alt(log, "x", "x_3") == 3, "--alt with the raw gone asks for a re-download")
check(B.accept_alt({"score": {"score": 80}}, {"score": {"score": 66}}), "accept 66 vs 80")
check(not B.accept_alt({"score": {"score": 90}}, {"score": {"score": 70}}), "reject 70 vs 90 (gap)")
check(not B.accept_alt({"score": {"score": 62}}, {"score": {"score": 55}}), "reject 55 (floor)")

for f in fails:
    print("audio_tools_test FAIL:", f)
print("audio_tools_test:", "ok" if not fails else f"{len(fails)} failures")
sys.exit(1 if fails else 0)
