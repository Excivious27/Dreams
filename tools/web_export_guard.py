#!/usr/bin/env python3
"""web_export_guard.py (S1 P1): Steam work must leave the web build exactly as it was.

  python3 tools/web_export_guard.py --static            # check.sh block: presets, ignores, project lock, lint, baseline
  python3 tools/web_export_guard.py --pck build/web/index.pck   # deploy.yml after the Web export
  python3 tools/web_export_guard.py --write-baseline    # refresh tools/web_baseline.json (only on purpose)

--static fails when:
  * the Web preset lost `addons/godotsteam/*`, `steam/*`, `steam_appid.txt`, `server/*` from its
    exclude_filter, or turned on extensions/threads, or moved its export path;
  * the Linux / Windows Desktop presets are missing, or don't exclude server/, steam/, steam_appid.txt,
    or DO exclude addons/godotsteam (desktop builds must ship it);
  * steam/ or server/ lost its .gdignore, or any *.import sits under steam/ or docs/;
  * project.godot changed config/name ("Dreams" forever: it is the user:// folder that holds every
    phone/web save), set use_custom_user_dir / custom_user_dir_name, or added a [steam] section;
  * addons/godotsteam is committed (it is staged only for desktop exports: tools/stage_godotsteam.sh);
  * any script names the GodotSteam engine singleton directly (only scripts/steam_service.gd may
    reach it, dynamically): a direct reference is a parse error on web, where the addon is absent;
  * the Web preset options, project.godot [display]/[rendering] or the key [application] values
    differ from tools/web_baseline.json.
--pck fails when the exported pack lists anything Steam (godotsteam, steam_api, steam_appid,
  .gdextension, .so/.dll, res://steam/, server/), and prints size + files per top folder.
"""
import json
import os
import re
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASELINE = os.path.join(ROOT, "tools", "web_baseline.json")
WEB_MUST_EXCLUDE = ["addons/godotsteam/*", "steam/*", "steam_appid.txt", "server/*"]
DESKTOP_PRESETS = ["Linux", "Windows Desktop"]
DESKTOP_MUST_EXCLUDE = ["server/*", "steam/*", "steam_appid.txt", ".github/*"]
FORBIDDEN_PCK = ["godotsteam", "steam_api", "steam_appid", ".gdextension", "res://steam/", "res://server/"]
APP_KEYS = ["config/name", "run/main_scene", "config/icon"]


def read(p):
    with open(os.path.join(ROOT, p), encoding="utf-8") as f:
        return f.read()


def presets():
    """{name: {"header": {k: v}, "options": {k: v}}} from export_presets.cfg."""
    out, cur, sect = {}, None, None
    idx = {}
    for line in read("export_presets.cfg").splitlines():
        m = re.match(r"^\[preset\.(\d+)(\.options)?\]$", line)
        if m:
            sect = (m.group(1), "options" if m.group(2) else "header")
            idx.setdefault(m.group(1), {"header": {}, "options": {}})
            continue
        m = re.match(r"^([^=;\[]+)=(.*)$", line)
        if m and sect:
            idx[sect[0]][sect[1]][m.group(1).strip()] = m.group(2).strip()
    for i, d in idx.items():
        name = d["header"].get("name", "").strip('"')
        out[name] = d
    return out


def excludes(p):
    return [x.strip() for x in p["header"].get("exclude_filter", "").strip('"').split(",") if x.strip()]


def project_sections():
    secs, cur = {}, ""
    for line in read("project.godot").splitlines():
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            cur = m.group(1)
            secs.setdefault(cur, {})
            continue
        m = re.match(r"^([^=;]+)=(.*)$", line)
        if m:
            secs.setdefault(cur, {})[m.group(1).strip()] = m.group(2).strip()
    return secs


def snapshot():
    ps = presets()
    secs = project_sections()
    web = dict(ps.get("Web", {}).get("options", {}))
    web.pop("html/head_include", None)  # guarded by tools/web_head.py
    return {
        "web_options": web,
        "web_export_path": ps.get("Web", {}).get("header", {}).get("export_path", ""),
        "display": secs.get("display", {}),
        "rendering": secs.get("rendering", {}),
        "application": {k: secs.get("application", {}).get(k, "") for k in APP_KEYS},
    }


SINGLETON_RE = re.compile(r'(?<![\w.])Steam\s*\.\s*[A-Za-z_]|get_singleton\(\s*"Steam"\s*\)')


def lint_singleton():
    bad = []
    for d in ["scripts", "tools", "scenes"]:
        for dp, _dn, fn in os.walk(os.path.join(ROOT, d)):
            for f in fn:
                if not f.endswith((".gd", ".tscn")):
                    continue
                rel = os.path.relpath(os.path.join(dp, f), ROOT)
                if rel in ("scripts/steam_service.gd", "tools/steam_load_probe.gd"):
                    continue
                with open(os.path.join(dp, f), encoding="utf-8", errors="replace") as fh:
                    for n, line in enumerate(fh, 1):
                        code = re.sub(r'"(?:\\.|[^"\\])*"', '""', line)
                        code = re.sub(r"'(?:\\.|[^'\\])*'", "''", code).split("#", 1)[0]
                        if SINGLETON_RE.search(code) or 'get_singleton("Steam")' in line:
                            bad.append("%s:%d" % (rel, n))
    return bad


def static():
    errs = []
    ps = presets()
    web = ps.get("Web")
    if not web:
        errs.append("no Web preset")
    else:
        ex = excludes(web)
        for e in WEB_MUST_EXCLUDE:
            if e not in ex:
                errs.append("Web preset exclude_filter lacks %s" % e)
        o = web["options"]
        for k, v in [("variant/extensions_support", "false"), ("variant/thread_support", "false")]:
            if o.get(k, "false") != v:
                errs.append("Web preset %s must stay %s" % (k, v))
        if web["header"].get("export_path") != '"build/web/index.html"':
            errs.append("Web preset export_path moved")
    for name in DESKTOP_PRESETS:
        p = ps.get(name)
        if not p:
            errs.append("missing desktop preset %s" % name)
            continue
        ex = excludes(p)
        for e in DESKTOP_MUST_EXCLUDE:
            if e not in ex:
                errs.append("%s preset exclude_filter lacks %s" % (name, e))
        if any("godotsteam" in e for e in ex):
            errs.append("%s preset must NOT exclude addons/godotsteam" % name)
        if p["options"].get("binary_format/architecture") != '"x86_64"':
            errs.append("%s preset must be x86_64" % name)
    for d in ["steam", "server"]:
        if os.path.isdir(os.path.join(ROOT, d)) and not os.path.exists(os.path.join(ROOT, d, ".gdignore")):
            errs.append("%s/ has no .gdignore (Godot would import and export it)" % d)
    for d in ["steam", "docs"]:
        for dp, _dn, fn in os.walk(os.path.join(ROOT, d)):
            for f in fn:
                if f.endswith(".import"):
                    errs.append("stray import file %s" % os.path.relpath(os.path.join(dp, f), ROOT))
    secs = project_sections()
    app = secs.get("application", {})
    if app.get("config/name") != '"Dreams"':
        errs.append('project.godot config/name must stay "Dreams" (user:// folder of every save; rename the store name, not this)')
    for k in ["config/use_custom_user_dir", "config/custom_user_dir_name"]:
        if k in app:
            errs.append("project.godot must not set %s (moves user:// and loses every save)" % k)
    if "steam" in secs or "steam/initialization" in read("project.godot"):
        errs.append("project.godot must not carry Steam settings (SteamSvc starts Steam in code)")
    if 'SteamSvc="*res://scripts/steam_service.gd"' not in read("project.godot"):
        errs.append("SteamSvc autoload missing")
    try:
        tracked = subprocess.run(["git", "-C", ROOT, "ls-files", "addons/godotsteam", "steam_appid.txt"],
                                 capture_output=True, text=True).stdout.split()
        tracked += [t for t in subprocess.run(["git", "-C", ROOT, "ls-files"], capture_output=True,
                                              text=True).stdout.split() if t.endswith("steam_appid.txt")]
        if tracked:
            errs.append("committed files that must never be committed: %s" % sorted(set(tracked)))
    except OSError:
        pass
    for b in lint_singleton():
        errs.append("direct GodotSteam singleton reference (use SteamApi): %s" % b)
    if os.path.exists(BASELINE):
        with open(BASELINE) as f:
            base = json.load(f)
        now = snapshot()
        for k, want in base.items():
            got = now.get(k)
            if got != want:
                if isinstance(want, dict) and isinstance(got, dict):
                    diff = sorted(set(want) ^ set(got) | {x for x in want if x in got and want[x] != got[x]})
                    errs.append("web baseline changed in %s: %s" % (k, diff[:8]))
                else:
                    errs.append("web baseline changed: %s" % k)
    else:
        errs.append("tools/web_baseline.json missing (run --write-baseline)")
    for e in errs:
        print("web_export_guard: FAIL", e)
    print("web_export_guard static: %s (%d problems)" % ("ok" if not errs else "FAIL", len(errs)))
    return 1 if errs else 0


def pck_paths(path):
    """Godot PCK v2/v3 directory -> list of paths (None if the layout is unknown)."""
    with open(path, "rb") as f:
        data = f.read()
    off = data.find(b"GDPC")
    if off < 0:
        return None, data
    fmt = struct.unpack_from("<I", data, off + 4)[0]
    flags = struct.unpack_from("<I", data, off + 20)[0]
    if flags & 1:  # encrypted directory
        return None, data
    if fmt >= 3:
        p = off + struct.unpack_from("<Q", data, off + 32)[0]  # v3: relative to the pack start
    elif fmt == 2:
        p = off + 24 + 8 + 64
    else:
        return None, data
    try:
        count = struct.unpack_from("<I", data, p)[0]
        p += 4
        out = []
        for _ in range(count):
            ln = struct.unpack_from("<I", data, p)[0]
            p += 4
            out.append(data[p:p + ln].rstrip(b"\0").decode("utf-8", "replace"))
            p += ln + 8 + 8 + 16 + 4
        return out, data
    except (struct.error, UnicodeDecodeError):
        return None, data


def check_pck(path):
    errs = []
    paths, data = pck_paths(path)
    size = os.path.getsize(path)
    if paths is None:
        print("web_export_guard: pck directory not parsed; byte scan only")
        for w in ["libgodotsteam", "libsteam_api", "steam_api64.dll", "godotsteam.gdextension", "steam_appid.txt"]:
            if w.encode() in data:
                errs.append("pck contains %s" % w)
    else:
        tops = {}
        for p in paths:
            q = p.replace("res://", "")
            tops[q.split("/", 1)[0]] = tops.get(q.split("/", 1)[0], 0) + 1
            low = p.lower()
            ql = q.lower()
            if any(w in low for w in FORBIDDEN_PCK) or ql.startswith(("steam/", "server/", "addons/godotsteam")) \
                    or low.endswith((".so", ".dll", ".dylib")):
                errs.append("pck lists %s" % p)
        print("web_export_guard pck: %d files, top folders: %s" % (len(paths), json.dumps(dict(sorted(tops.items())))))
    print("web_export_guard pck: %s, %.1f MB" % (path, size / 1048576.0))
    for e in errs[:20]:
        print("web_export_guard: FAIL", e)
    print("web_export_guard pck: %s" % ("ok" if not errs else "FAIL"))
    return 1 if errs else 0


def main(argv):
    if "--write-baseline" in argv:
        with open(BASELINE, "w") as f:
            json.dump(snapshot(), f, indent=1, sort_keys=True)
            f.write("\n")
        print("wrote", os.path.relpath(BASELINE, ROOT))
        return 0
    if "--pck" in argv:
        return check_pck(argv[argv.index("--pck") + 1])
    return static()


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
