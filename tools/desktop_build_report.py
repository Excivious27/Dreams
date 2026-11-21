#!/usr/bin/env python3
"""desktop_build_report.py (S1 P1): check and measure one exported desktop build.

  python3 tools/desktop_build_report.py <build_dir> <linux|windows> [--boot-log <file>] [--load-log <file>]
        [--json out.json] [--summary $GITHUB_STEP_SUMMARY] [--steam]

Fails (exit 1) when:
  * the binary is missing (Dreams.x86_64 / Dreams.exe) or the Linux binary is not executable;
  * any denied file is in the build: steam_appid.txt (dev/test only, never shipped), *.pdb,
    *.console.exe, *.import, loose *.gd;
  * --steam (the GodotSteam addon was staged) and the libraries Steam needs are not beside the
    binary (names from steam/godotsteam/godotsteam.gdextension);
  * the build is over SIZE_CEILING_MB (~2x the 390-420 MB measured baseline, S1 audit 01-12);
  * --boot-log is given and lacks "DREAMS BOOT OK" (scripts/boot_probe.gd), or first launch
    (title ms) is over 3x the 3 s baseline.
Records raw + gzip size, file list, title/farm ms and the Steam backend line into --json and
a markdown table into --summary (GitHub step summary).
"""
import gzip
import json
import os
import re
import sys

SIZE_CEILING_MB = 850
TITLE_MS_ALERT = 9000
BIN = {"linux": "Dreams.x86_64", "windows": "Dreams.exe"}
STEAM_LIBS = {
    "linux": ["libgodotsteam.linux.template_release.x86_64.so", "libsteam_api.so"],
    "windows": ["libgodotsteam.windows.template_release.x86_64.dll", "steam_api64.dll"],
}
DENY_NAMES = {"steam_appid.txt"}
DENY_SUFFIX = (".pdb", ".console.exe", ".import", ".gd")


def gz_size(path):
    total = 0
    with open(path, "rb") as f:
        class Counter:
            def write(self, b):
                nonlocal total
                total += len(b)
                return len(b)
        with gzip.GzipFile(fileobj=Counter(), mode="wb", compresslevel=6) as g:
            while True:
                b = f.read(1 << 20)
                if not b:
                    break
                g.write(b)
    return total


def parse_boot(text):
    out = {}
    for key in ["title", "farm"]:
        m = re.search(r"DREAMS BOOT %s ms=(\d+)" % key, text)
        if m:
            out[key + "_ms"] = int(m.group(1))
    m = re.search(r"DREAMS BOOT steam backend=(\S+) reason=(.*)", text)
    if m:
        out["steam_backend"] = m.group(1)
        out["steam_reason"] = m.group(2).strip()
    out["ok"] = "DREAMS BOOT OK" in text
    return out


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    d, plat = argv[0], argv[1]
    opt = lambda k: argv[argv.index(k) + 1] if k in argv else None
    errs, rep = [], {"platform": plat, "dir": d}
    files = []
    for dp, _dn, fn in os.walk(d):
        for f in fn:
            files.append(os.path.relpath(os.path.join(dp, f), d))
    rep["files"] = sorted(files)
    b = os.path.join(d, BIN.get(plat, "?"))
    if not os.path.isfile(b):
        errs.append("binary missing: %s" % b)
    else:
        if plat == "linux" and not os.access(b, os.X_OK):
            errs.append("Linux binary not executable")
        rep["binary_mb"] = round(os.path.getsize(b) / 1048576.0, 1)
    total = sum(os.path.getsize(os.path.join(d, f)) for f in files)
    rep["total_mb"] = round(total / 1048576.0, 1)
    if os.path.isfile(b):
        rep["binary_gzip_mb"] = round(gz_size(b) / 1048576.0, 1)
    if rep["total_mb"] > SIZE_CEILING_MB:
        errs.append("build is %.0f MB, over the %d MB ceiling" % (rep["total_mb"], SIZE_CEILING_MB))
    for f in files:
        base = os.path.basename(f)
        if base in DENY_NAMES or base.endswith(DENY_SUFFIX):
            errs.append("denied file in build: %s" % f)
    if "--steam" in argv:
        for lib in STEAM_LIBS.get(plat, []):
            if lib not in [os.path.basename(f) for f in files]:
                errs.append("Steam library missing beside the binary: %s" % lib)
    rep["steam_libs"] = [f for f in files if "steam" in f.lower()]
    if opt("--boot-log"):
        with open(opt("--boot-log"), encoding="utf-8", errors="replace") as f:
            txt = f.read()
        boot = parse_boot(txt)
        rep["boot"] = boot
        if not boot["ok"]:
            errs.append("boot probe did not reach DREAMS BOOT OK")
        if boot.get("title_ms", 0) > TITLE_MS_ALERT:
            errs.append("first launch to title %d ms (> %d)" % (boot["title_ms"], TITLE_MS_ALERT))
        if re.search(r"SCRIPT ERROR|Parse Error", txt):
            errs.append("script errors in the boot log")
    if opt("--load-log"):
        with open(opt("--load-log"), encoding="utf-8", errors="replace") as f:
            m = re.search(r"STEAM LOAD: (.*)", f.read())
        rep["steam_load"] = m.group(1).strip() if m else "no result"
    rep["errors"] = errs
    if opt("--json"):
        with open(opt("--json"), "w") as f:
            json.dump(rep, f, indent=1)
    lines = ["### %s build: %s" % (plat.capitalize(), "ok" if not errs else "FAIL"),
             "| what | value |", "|---|---|",
             "| binary | %s MB (gzip %s MB) |" % (rep.get("binary_mb", "?"), rep.get("binary_gzip_mb", "?")),
             "| folder total | %s MB, %d files |" % (rep["total_mb"], len(files)),
             "| Steam libs | %s |" % (", ".join(rep["steam_libs"]) or "none")]
    if "boot" in rep:
        bt = rep["boot"]
        lines.append("| first launch | title %s ms, farm (600 frames) %s ms |" % (bt.get("title_ms", "?"), bt.get("farm_ms", "?")))
        lines.append("| Steam backend | %s (%s) |" % (bt.get("steam_backend", "?"), bt.get("steam_reason", "")))
    if "steam_load" in rep:
        lines.append("| GodotSteam load | %s |" % rep["steam_load"])
    for e in errs:
        lines.append("| FAIL | %s |" % e)
    md = "\n".join(lines) + "\n"
    print(md)
    if opt("--summary"):
        with open(opt("--summary"), "a") as f:
            f.write(md)
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
