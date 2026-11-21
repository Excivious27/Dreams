#!/usr/bin/env python3
"""gen_steam_vdf.py: render the SteamPipe build scripts from steam/steam_config.json (s1_11).

    python3 tools/gen_steam_vdf.py --out build/steam/scripts [--preview] [--preview-dummy]

Templates: steam/templates/*.vdf.in (string.Template: ${APP_ID} ${DEPOT_WIN} ${DEPOT_LINUX}
${DESC} ${PREVIEW} ${SET_LIVE}; a missing placeholder raises). Output goes under build/ (gitignored),
so rendered VDFs are never committed. Refuses SetLive "default" (Valve: the default branch can
never be set live automatically) and app_id 0 unless --preview-dummy (Spacewar 480 / 481 / 482).
Depot ids default to app_id+1 (Windows) and app_id+2 (Linux) when steam_config.json leaves them 0.
stdlib only.
"""
import datetime, json, os, re, string, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TEMPLATES = os.path.join(ROOT, "steam", "templates")


def parse_vdf(s):
    """Tiny KeyValues reader that keeps repeated keys: a list of (key, value) pairs, value str or list."""
    toks = [a if b == "" else b for a, b in re.findall(r'"((?:[^"\\]|\\.)*)"|([{}])', s)]
    i = 0

    def obj():
        nonlocal i
        out = []
        while i < len(toks) and toks[i] != "}":
            k = toks[i]
            i += 1
            if i >= len(toks):
                raise ValueError("VDF ends after key %r" % k)
            if toks[i] == "{":
                i += 1
                v = obj()
                if i >= len(toks) or toks[i] != "}":
                    raise ValueError("VDF block %r not closed" % k)
                i += 1
            else:
                v = toks[i]
                i += 1
            out.append((k, v))
        return out

    res = obj()
    if i != len(toks):
        raise ValueError("VDF has a stray '}'")
    return res


def config():
    return json.load(open(os.path.join(ROOT, "steam", "steam_config.json")))


def version():
    try:
        for ln in open(os.path.join(ROOT, "project.godot")):
            m = re.match(r'config/version="([^"]*)"', ln.strip())
            if m:
                return m.group(1)
    except OSError:
        pass
    return "0.0.0"


def short_sha():
    try:
        return subprocess.run(["git", "-C", ROOT, "rev-parse", "--short", "HEAD"], capture_output=True,
                              text=True, timeout=10).stdout.strip() or "nosha"
    except Exception:
        return "nosha"


def describe(cfg):
    fmt = cfg.get("desc_fmt", "Dreams {version} {sha} {date}")
    d = fmt.format(version=version(), sha=short_sha(), date=datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d"))
    return re.sub(r'["\\\n\r]', "", d)[:100]


def values(cfg, preview=False, dummy=False):
    app = int(cfg.get("app_id") or 0)
    if not app:
        if not dummy:
            raise SystemExit("gen_steam_vdf: app_id is 0 in steam/steam_config.json (pass --preview-dummy for a dry run)")
        app = 480
    live = str(cfg.get("set_live", "beta"))
    if live.strip().lower() == "default":
        raise SystemExit("gen_steam_vdf: SetLive 'default' is not allowed (set the default branch live by hand in Steamworks)")
    dep = cfg.get("depots", {})
    return {
        "APP_ID": str(app),
        "DEPOT_WIN": str(int(dep.get("windows") or 0) or app + 1),
        "DEPOT_LINUX": str(int(dep.get("linux") or 0) or app + 2),
        "DESC": describe(cfg),
        "PREVIEW": "1" if (preview or dummy or cfg.get("preview", True)) else "0",
        "SET_LIVE": live,
    }


def render(out, preview=False, dummy=False, cfg=None):
    v = values(cfg or config(), preview, dummy)
    os.makedirs(out, exist_ok=True)
    for f in sorted(os.listdir(TEMPLATES)):
        if not f.endswith(".vdf.in"):
            continue
        s = string.Template(open(os.path.join(TEMPLATES, f)).read()).substitute(v)
        with open(os.path.join(out, f[:-3]), "w") as fh:
            fh.write(s)
    return v


def main():
    a = sys.argv[1:]
    out = os.path.join(ROOT, "build", "steam", "scripts")
    if "--out" in a:
        out = os.path.abspath(a[a.index("--out") + 1])
    v = render(out, "--preview" in a, "--preview-dummy" in a)
    print("gen_steam_vdf: app %s depots %s/%s SetLive %s Preview %s -> %s" % (
        v["APP_ID"], v["DEPOT_WIN"], v["DEPOT_LINUX"], v["SET_LIVE"], v["PREVIEW"], out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
