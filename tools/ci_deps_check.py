#!/usr/bin/env python3
"""ci_deps_check.py: fail fast when a Python package or system tool CI needs is missing.

    python3 tools/ci_deps_check.py               check everything, list what is missing (exit 1)
    python3 tools/ci_deps_check.py --godot       also require godot ($GODOT or on PATH)
    python3 tools/ci_deps_check.py --apt-missing print the apt packages to install (the ONE apt line), nothing else

Python packages come from tools/ci-requirements.txt; system tools from BINARIES below
(the apt line). A new import or tool goes into one of them in the same commit.
Uses only the standard library, so it runs before anything is installed.
"""
import importlib, os, shutil, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
REQS = os.path.join(ROOT, "tools", "ci-requirements.txt")
# pip name -> import name, where they differ
IMPORT_AS = {"pillow": "PIL", "fonttools": "fontTools", "pyyaml": "yaml"}
# binary check.sh/tests/workflows call -> apt package that provides it
BINARIES = {
    "ffmpeg": "ffmpeg",      # sfx/music audits, ace/cc0 import
    "ffprobe": "ffmpeg",
    "xvfb-run": "xvfb",      # playtest + screenshot tools
    "git": "git",            # data_sync_check, ci_run
    "curl": "curl",          # Godot download, deploy checks
    "unzip": "unzip",        # Godot + export templates
    "timeout": "coreutils",  # bots, playtest
    "node": "nodejs",        # tools/relay_test.js (check.sh), CI relay job (preinstalled on ubuntu-latest)
}


def requirements():
    out = []
    for ln in open(REQS):
        ln = ln.split("#", 1)[0].strip()
        if ln:
            out.append(ln.split("==")[0].split(">=")[0].split("[")[0].strip())
    return out


def missing_bins(godot=False):
    miss = [b for b in BINARIES if not shutil.which(b)]
    if godot:
        g = os.environ.get("GODOT", "godot")
        if not (shutil.which(g) or os.access(g, os.X_OK)):
            miss.append("godot")
    return miss


def main():
    args = sys.argv[1:]
    if "--apt-missing" in args:
        pkgs = sorted({BINARIES[b] for b in missing_bins() if b in BINARIES})
        print(" ".join(pkgs))
        return 0
    bad = []
    for req in requirements():
        mod = IMPORT_AS.get(req.lower(), req)
        try:
            importlib.import_module(mod)
        except Exception as e:  # ImportError, or a broken native wheel
            bad.append("python package %s (import %s): %s" % (req, mod, str(e).splitlines()[0][:100]))
    for b in missing_bins("--godot" in args):
        bad.append("system tool %s (apt: %s)" % (b, BINARIES.get(b, "see workflow Godot step")))
    if bad:
        print("ci_deps_check: %d missing" % len(bad))
        for x in bad:
            print("  MISSING " + x)
        print("fix: pip install -r tools/ci-requirements.txt; sudo apt-get install -y $(python3 tools/ci_deps_check.py --apt-missing)")
        return 1
    print("ci_deps_check: OK (%d python packages, %d tools)" % (len(requirements()), len(BINARIES) + ("--godot" in args)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
