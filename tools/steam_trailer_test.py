#!/usr/bin/env python3
"""ffprobe check of a built Steam trailer (tools/steam_trailer.sh output).

Steam: H.264 video + AAC audio in mp4, 1920x1080 (16:9), 30 or 60 fps,
5000+ kbps; the S1 plan wants 30-60 s. Not in check.sh (the trailer is built
by a manual CI job); with no file it prints a skip and exits 0.
    python3 tools/steam_trailer_test.py [build/trailer/trailer_v1.mp4]
"""
import json
import os
import subprocess
import sys


def main():
    p = sys.argv[1] if len(sys.argv) > 1 else "build/trailer/trailer_v1.mp4"
    if not os.path.exists(p):
        print("steam_trailer_test: skip (no %s)" % p)
        return 0
    info = json.loads(subprocess.check_output(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", p]))
    v = [s for s in info["streams"] if s["codec_type"] == "video"]
    a = [s for s in info["streams"] if s["codec_type"] == "audio"]
    errs = []
    if not v or v[0]["codec_name"] != "h264":
        errs.append("video must be h264")
    elif (int(v[0]["width"]), int(v[0]["height"])) != (1920, 1080):
        errs.append("video is %sx%s" % (v[0]["width"], v[0]["height"]))
    else:
        num, den = v[0]["avg_frame_rate"].split("/")
        fps = float(num) / float(den)
        if round(fps) not in (30, 60):
            errs.append("fps %.2f" % fps)
    if not a or a[0]["codec_name"] != "aac":
        errs.append("audio must be aac")
    dur = float(info["format"]["duration"])
    if not 30 <= dur <= 60:
        errs.append("duration %.1f s (30-60)" % dur)
    kbps = int(info["format"].get("bit_rate", 0)) / 1000
    if kbps < 5000:
        errs.append("bitrate %d kbps (< 5000)" % kbps)
    for e in errs:
        print("steam_trailer_test: FAIL " + e)
    print("steam_trailer_test: %s, %.1f s, %d kbps, %d failures" % (p, dur, kbps, len(errs)))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
