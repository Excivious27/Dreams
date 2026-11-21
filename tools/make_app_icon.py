#!/usr/bin/env python3
"""make_app_icon.py (S1 P1): build art/app/icon.ico (Windows exe icon: 16..256 px) from
web/icon_512.png, the same art as the web/PWA icon. Re-run when the app icon changes.
  python3 tools/make_app_icon.py [--check]"""
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "web", "icon_512.png")
DST = os.path.join(ROOT, "art", "app", "icon.ico")
SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]

if "--check" in sys.argv:
    ok = os.path.exists(DST) and Image.open(DST).size[0] >= 16
    print("app icon:", "ok" if ok else "FAIL (run tools/make_app_icon.py)")
    sys.exit(0 if ok else 1)
os.makedirs(os.path.dirname(DST), exist_ok=True)
if os.path.exists(DST):
    os.remove(DST)  # art files are hardlinked across worktrees: rm, then write
Image.open(SRC).convert("RGBA").save(DST, sizes=SIZES)
print("wrote", os.path.relpath(DST, ROOT), os.path.getsize(DST), "bytes")
