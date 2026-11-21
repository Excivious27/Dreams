#!/usr/bin/env python3
"""Renders docs/steam-store/system-requirements.md (CONDUCT S1, P6).

Reads measured desktop numbers from a metrics JSON when one exists (default
build/metrics.json, written by the desktop build CI job: pck_bytes, exe_bytes,
boot_s, peak_rss_kb, video_mem_bytes; any may be missing) and applies headroom:
  RAM     = 2 x peak RSS, rounded up to 2/4/8 GB (never below 4 GB)
  Storage = install size x 1.5, rounded up to 0.5/1 GB steps
  VRAM    = 2 x peak video memory, min 1 GB
Every value is marked measured or estimated. stdlib only.
    python3 tools/store_sysreq.py [metrics.json]
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "steam-store", "system-requirements.md")
GB = 1024 ** 3
# Estimates until CI records real numbers (S1 audit s1_12-07): web pck 124 MB +
# packed songs ~165 MB + ~70 MB engine template.
EST = {"install_bytes": 360 * 1024 ** 2, "peak_rss_kb": None, "video_mem_bytes": None}


def ram_gb(rss_kb):
    if not rss_kb:
        return 4, "estimated"
    need = 2 * rss_kb * 1024 / GB
    for g in (4, 8, 16):
        if need <= g:
            return g, "measured (peak RSS %.0f MB x2)" % (rss_kb / 1024)
    return 16, "measured"


def storage(bytes_):
    need = bytes_ * 1.5 / GB
    return max(0.5, math.ceil(need * 2) / 2) if need < 1 else math.ceil(need)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "metrics.json")
    m = json.load(open(path)) if os.path.exists(path) else {}
    inst = (m.get("pck_bytes", 0) + m.get("exe_bytes", 0)) or EST["install_bytes"]
    inst_src = "measured" if m.get("pck_bytes") else "estimated"
    ram, ram_src = ram_gb(m.get("peak_rss_kb"))
    vm = m.get("video_mem_bytes")
    vram = max(1.0, math.ceil(2 * vm / GB * 2) / 2) if vm else 1.0
    vram_src = "measured" if vm else "estimated"
    st = storage(inst)
    lines = [
        "# System requirements (draft; rendered by tools/store_sysreq.py)",
        "",
        "Renderer: gl_compatibility (OpenGL 3.3 / Direct3D 11 class GPUs). Godot 4.5 exported-project floor: x86_64 CPU with SSE4.2, OpenGL 3.3 or D3D11 GPU, Windows 10 / a Linux from 2018 or later. No macOS section (no mac preset). Steam Deck: target Verified (docs/steam/deck.md).",
        "Source: %s. Rerun after the desktop build CI job writes build/metrics.json." % (os.path.relpath(path, ROOT) if m else "no metrics yet: staged estimates"),
        "",
        "| | Minimum | Recommended | Source |",
        "|-|---------|-------------|--------|",
        "| OS | Windows 10 64-bit / SteamOS 3 or Ubuntu 22.04 64-bit | Windows 10/11 64-bit / SteamOS 3 | estimated |",
        "| Processor | 64-bit dual-core with SSE4.2 (Intel Core i3 2nd gen / AMD FX or newer) | 64-bit quad-core | estimated |",
        "| Memory | %d GB RAM | %d GB RAM | %s |" % (ram, max(8, ram), ram_src),
        "| Graphics | OpenGL 3.3 or DirectX 11 GPU with %.0f GB (Intel HD Graphics 4000 / GeForce GT 630 / Radeon HD 7000) | any GPU from 2016 or later with 2 GB | %s |" % (vram, vram_src),
        "| Storage | %s GB available | %s GB available | %s (install ~%d MB x1.5) |" % (st, st, inst_src, inst // 1024 ** 2),
        "| Additional | 1280x720 or larger display; controller recommended | 1920x1080; controller | - |",
        "",
        "Comparables: Stardew Valley min 2 GB RAM / 256 MB VRAM / 500 MB; Sun Haven 4 GB / 10 GB; Fields of Mistria 6 GB / 2 GB storage.",
    ]
    if m.get("boot_s"):
        lines.append("Measured headless boot: %.1f s." % m["boot_s"])
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("store_sysreq: wrote %s (%s)" % (os.path.relpath(OUT, ROOT), "measured" if m else "estimates"))


if __name__ == "__main__":
    main()
