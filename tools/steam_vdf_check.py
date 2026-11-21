#!/usr/bin/env python3
"""steam_vdf_check.py: keep the staged SteamPipe scripts and depot content safe (s1_11).

    python3 tools/steam_vdf_check.py --templates         check.sh block: render with dummy app 480 into a temp dir and check
    python3 tools/steam_vdf_check.py --scripts DIR [--content DIR]   CI before steamcmd: check rendered scripts (+ content)
    python3 tools/steam_vdf_check.py --dry CONTENT       render dummy scripts, check content, print the would-upload list (no network)

Checks: SetLive never "default"; each Depots key resolves to a depot file whose DepotID matches;
every depot excludes steam_appid.txt, *.pdb, *.debug, *.console.exe/sh; ContentRoot is relative;
config preview stays on while enabled is false; steam/.gdignore keeps steam/ out of every pck.
Content: Dreams.exe (windows/), Dreams.x86_64 (+x, linux/), no steam_appid.txt anywhere,
Steam API libs (steam_api64.dll / libsteam_api.so) required once addons/godotsteam exists,
GLIBC floor of Linux ELFs <= 2.31 (Steam Linux Runtime 3.0 sniper) when objdump is available.
stdlib only.
"""
import json, os, re, shutil, subprocess, sys, tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_steam_vdf as G  # noqa: E402

ROOT = G.ROOT
REQ_EX = {"steam_appid.txt", "*.pdb", "*.debug", "*.console.exe", "*.console.sh"}
GLIBC_MAX = (2, 31)


def check_scripts(d):
    errs = []
    a = G.parse_vdf(open(os.path.join(d, "app_build.vdf")).read())
    if not a or a[0][0] != "AppBuild":
        return ["app_build.vdf: no AppBuild block"]
    app = a[0][1]
    ad = dict(app)
    if str(ad.get("SetLive", "")).strip().lower() == "default":
        errs.append("app_build.vdf: SetLive is 'default'")
    if not ad.get("AppID", "0").isdigit() or ad.get("AppID") == "0":
        errs.append("app_build.vdf: AppID %r" % ad.get("AppID"))
    depots = ad.get("Depots")
    if not isinstance(depots, list) or not depots:
        return errs + ["app_build.vdf: no Depots"]
    for did, fn in depots:
        p = os.path.join(d, fn)
        if not os.path.isfile(p):
            errs.append("depot %s: file %s missing" % (did, fn))
            continue
        dep = G.parse_vdf(open(p).read())[0][1]
        dd = dict(dep)
        if dd.get("DepotID") != did:
            errs.append("%s: DepotID %s != %s" % (fn, dd.get("DepotID"), did))
        ex = {v for k, v in dep if k == "FileExclusion"}
        if not REQ_EX <= ex:
            errs.append("%s: missing FileExclusion %s" % (fn, sorted(REQ_EX - ex)))
        cr = dd.get("ContentRoot", "")
        if not cr or os.path.isabs(cr):
            errs.append("%s: ContentRoot must be relative (%r)" % (fn, cr))
    return errs


def check_config():
    errs = []
    cfg = G.config()
    if not cfg.get("enabled") and not cfg.get("preview", True):
        errs.append("steam_config.json: preview must stay true while enabled is false")
    if cfg.get("enabled") and not int(cfg.get("app_id") or 0):
        errs.append("steam_config.json: enabled with app_id 0")
    if str(cfg.get("set_live", "")).lower() == "default":
        errs.append("steam_config.json: set_live 'default'")
    if not os.path.isfile(os.path.join(ROOT, "steam", ".gdignore")):
        errs.append("steam/.gdignore missing (templates would reach a pck)")
    for n in os.listdir(os.path.join(ROOT, "steam", "templates")):
        if n.endswith(".vdf.in") and "steam_appid" in open(os.path.join(ROOT, "steam", "templates", n)).read() \
                and "FileExclusion" not in open(os.path.join(ROOT, "steam", "templates", n)).read():
            errs.append("%s mentions steam_appid outside an exclusion" % n)
    gi = open(os.path.join(ROOT, ".gitignore")).read()
    if "steam_appid.txt" not in gi:
        errs.append(".gitignore lacks steam_appid.txt")
    return errs


def glibc_max(path):
    if not shutil.which("objdump"):
        return None
    out = subprocess.run(["objdump", "-T", path], capture_output=True, text=True).stdout
    vs = [tuple(int(x) for x in m) for m in re.findall(r"GLIBC_(\d+)\.(\d+)", out)]
    return max(vs) if vs else (0, 0)


def check_content(c):
    errs, warns = [], []
    need_api = os.path.isdir(os.path.join(ROOT, "addons", "godotsteam"))
    w, l = os.path.join(c, "windows"), os.path.join(c, "linux")
    if not os.path.isfile(os.path.join(w, "Dreams.exe")):
        errs.append("windows/Dreams.exe missing")
    exe = os.path.join(l, "Dreams.x86_64")
    if not os.path.isfile(exe):
        errs.append("linux/Dreams.x86_64 missing")
    elif not os.access(exe, os.X_OK):
        errs.append("linux/Dreams.x86_64 is not executable (chmod +x after the artifact hop)")
    for sub, lib in (("windows", "steam_api64.dll"), ("linux", "libsteam_api.so")):
        if not os.path.isfile(os.path.join(c, sub, lib)):
            (errs if need_api else warns).append("%s/%s missing" % (sub, lib))
    for dp, _, fs in os.walk(c):
        for f in fs:
            p = os.path.join(dp, f)
            if f == "steam_appid.txt":
                errs.append("forbidden " + os.path.relpath(p, c))
            if f.endswith(".pdb"):
                warns.append("debug symbols %s (excluded by the depot)" % os.path.relpath(p, c))
            if dp.startswith(l) and (f.endswith(".so") or f.endswith(".x86_64")):
                g = glibc_max(p)
                if g and g > GLIBC_MAX:
                    errs.append("%s needs GLIBC %d.%d > %d.%d (sniper floor)" % ((os.path.relpath(p, c),) + g + GLIBC_MAX))
    return errs, warns


def main():
    a = sys.argv[1:]
    errs, warns = [], []
    if "--templates" in a or not a:
        errs += check_config()
        with tempfile.TemporaryDirectory() as t:
            G.render(t, dummy=True, cfg=dict(G.config(), app_id=0))
            errs += check_scripts(t)
            try:  # the refusals must hold
                G.values(dict(G.config(), set_live="default"), dummy=True)
                errs.append("gen_steam_vdf accepted SetLive default")
            except SystemExit:
                pass
            try:
                G.values(dict(G.config(), app_id=0))
                errs.append("gen_steam_vdf accepted app_id 0 without --preview-dummy")
            except SystemExit:
                pass
    if "--scripts" in a:
        errs += check_scripts(a[a.index("--scripts") + 1])
    if "--content" in a:
        e, w = check_content(a[a.index("--content") + 1])
        errs += e
        warns += w
    if "--dry" in a:
        c = a[a.index("--dry") + 1]
        with tempfile.TemporaryDirectory() as t:
            G.render(t, dummy=True, cfg=dict(G.config(), app_id=0))
            errs += check_scripts(t)
        e, w = check_content(c)
        errs += e
        warns += w
        for dp, _, fs in os.walk(c):
            for f in sorted(fs):
                p = os.path.join(dp, f)
                if f != "steam_appid.txt" and not f.endswith((".pdb", ".debug", ".log")):
                    print("  would upload %-50s %8.1f MB" % (os.path.relpath(p, c), os.path.getsize(p) / 1e6))
    for w in warns:
        print("steam_vdf_check: WARN " + w)
    if errs:
        for e in errs:
            print("steam_vdf_check: FAIL " + e)
        return 1
    print("steam_vdf_check: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
