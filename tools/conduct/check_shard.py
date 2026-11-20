#!/usr/bin/env python3
"""Run tools/check.sh as named steps, optionally one shard of them.

    CHECK_SHARD=i/N bash tools/check.sh      (check.sh execs this script)
    python3 tools/conduct/check_shard.py [i/N] [--list]
    python3 tools/conduct/check_shard.py [N] --for-files a.gd tools/b.py ...   (-v: why)

check.sh stays a plain script that people edit as before: blocks separated by a
blank line (at nesting depth 0) are steps. The first step (import) runs in every
shard; the rest go round-robin (step k runs in shard (k-1) % N + 1). Each step runs
in its own bash with the check.sh preamble, so steps must not lean on variables
set by an earlier step (each test block sets its own).

Unlike the plain script, a shard keeps going after a failing step and exits 1 at
the end, so one run reports every failure. Per-step wall times go to
$CHECK_TIMES (JSON lines: step, name, rc, secs) when set.

--for-files prints the shard numbers (comma list, of N=6 by default) whose steps
run or test the given files, for fix agents' pre-merge CI runs
(ci_run.sh --shards "$(python3 tools/conduct/check_shard.py --for-files ...)").
A step "touches" a file when its own text, or a tool it runs (tools/*.gd|py|sh,
one level of preload/load/class use followed), names the file's path, basename or
class_name. Generators map through the data files they write. A file nothing
matches, or a core file most steps reach, gives every shard.
"""
import json, os, re, shlex, subprocess, sys, time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CHECK = os.path.join(ROOT, "tools", "check.sh")
OPEN = re.compile(r"^\s*(if|for|while|case|until)\b|\{\s*$|\bthen\s*$|\bdo\s*$")
CLOSE = re.compile(r"^\s*(fi|done|esac|\})\b")


def split_steps():
    lines = open(CHECK).read().split("\n")
    pre, i = [], 0
    # Preamble: everything up to the shard hook's "fi" (or up to the first "echo ==").
    while i < len(lines):
        pre.append(lines[i])
        if lines[i].startswith("cd "):
            i += 1
            break
        i += 1
    # Skip the shard hook block itself.
    if i < len(lines) and "CHECK_SHARD" in lines[i]:
        while i < len(lines) and lines[i].strip() != "fi":
            i += 1
        i += 1
    steps, cur, depth, has_cmd = [], [], 0, False
    CMD = re.compile(r'"\$GODOT"|\bpython3\s+tools/|\bbash\s+tools/|\bxvfb-run\b')
    def flush():
        nonlocal cur, has_cmd
        if any(x.strip() and not x.strip().startswith("#") for x in cur):
            steps.append(cur)
        cur, has_cmd = [], False
    for ln in lines[i:]:
        s = ln.strip()
        if depth == 0 and s:
            header = s.startswith('echo "==')
            cmd = bool(CMD.search(s)) and not s.startswith("#")
            # a new step starts at a header, or at a second command line in the same step
            if header and (has_cmd or any(x.strip().startswith('echo "==') for x in cur)):
                flush()
            elif cmd and has_cmd:
                # keep a preceding header/comments with the new command
                tail = []
                while cur and (cur[-1].strip().startswith("#") or cur[-1].strip() == "" or cur[-1].strip().startswith('echo "==')):
                    tail.insert(0, cur.pop())
                flush()
                cur = tail
            if cmd:
                has_cmd = True
        cur.append(ln)
        if s and not s.startswith("#"):
            opens = 1 if OPEN.search(s) else 0
            closes = 1 if CLOSE.search(s) else 0
            if re.search(r"\bfi\b\s*$", s) and re.match(r"^\s*if\b", s):
                opens = closes = 0
            if re.search(r"\bdone\b\s*$", s) and re.match(r"^\s*(for|while)\b", s):
                opens = closes = 0
            depth = max(0, depth + opens - closes)
    flush()
    return pre, steps


def name_of(step, k):
    for ln in step:
        m = re.match(r'\s*echo "== (.*?) =="', ln)
        if m:
            return m.group(1)[:70]
    for ln in step:
        m = re.search(r"res://tools/([a-z0-9_]+)\.gd", ln) or re.search(r"tools/([a-z0-9_]+)\.py", ln)
        if m:
            return m.group(1)
    return "step %d" % k


def shard_of(k, sn):
    return 0 if k == 1 else (k - 2) % sn + 1


TOOL_REF = re.compile(r"(?:res://)?(tools/[A-Za-z0-9_/]+\.(?:gd|py|sh))")
_src_cache = {}


def _read(rel):
    if rel not in _src_cache:
        try:
            _src_cache[rel] = open(os.path.join(ROOT, rel), errors="replace").read()
        except OSError:
            _src_cache[rel] = ""
    return _src_cache[rel]


def step_text(step):
    """The step's own text plus every tool it runs, and the tools those name (one level)."""
    text = "\n".join(step)
    seen = set()
    todo = TOOL_REF.findall(text)
    depth = {t: 0 for t in todo}
    parts = [text]
    while todo:
        t = todo.pop()
        if t in seen:
            continue
        seen.add(t)
        s = _read(t)
        parts.append(s)
        if depth.get(t, 0) < 1:
            for u in TOOL_REF.findall(s):
                if u not in depth:
                    depth[u] = depth[t] + 1
                    todo.append(u)
    return "\n".join(parts)


def keys_for(rel):
    """Words that show a step reaches this file."""
    rel = rel.replace("\\", "/").lstrip("./")
    if rel.startswith(ROOT + "/"):
        rel = rel[len(ROOT) + 1:]
    base = os.path.basename(rel)
    stem = os.path.splitext(base)[0]
    keys = {rel, base}
    src = _read(rel)
    m = re.search(r"^class_name\s+(\w+)", src, re.M)
    if m:
        keys.add(m.group(1))
    if rel.endswith(".py") and "/gen_" in "/" + base:
        # a generator reaches whatever reads the data it writes
        for out in re.findall(r"data/[A-Za-z0-9_]+\.json", src):
            keys.add(out)
    if rel.endswith(".tscn"):
        keys.add(stem)
    return {k for k in keys if len(k) > 3}


def for_files(files, sn, verbose=False):
    _, steps = split_steps()
    texts = [step_text(st) for st in steps]
    hit, why = set(), []
    for f in files:
        keys = keys_for(f)
        found = []
        for k, t in enumerate(texts, 1):
            if k == 1:
                continue  # import runs everywhere
            for key in keys:
                pat = re.escape(key) if ("/" in key or "." in key) else r"\b%s\b" % re.escape(key)
                if re.search(pat, t):
                    found.append((k, key))
                    break
        if not found or len(found) > 0.6 * (len(steps) - 1):
            why.append("%s: %s -> every shard" % (f, "no step reaches it" if not found else "core file (%d steps)" % len(found)))
            return list(range(1, sn + 1)), why
        for k, key in found:
            hit.add(shard_of(k, sn))
            why.append("%s: step %d %s (%s) shard %d" % (f, k, name_of(steps[k - 1], k), key, shard_of(k, sn)))
    return sorted(hit) or list(range(1, sn + 1)), why


def main():
    if "--for-files" in sys.argv:
        i = sys.argv.index("--for-files")
        pre = [a for a in sys.argv[1:i] if not a.startswith("-")]
        sn = int(pre[0].split("/")[-1]) if pre else 6
        files = [a for a in sys.argv[i + 1:] if not a.startswith("-")]
        if not files:
            print(",".join(str(x) for x in range(1, sn + 1)))
            return 0
        shards, why = for_files(files, sn, "-v" in sys.argv)
        if "-v" in sys.argv:
            for w in why:
                print("  " + w, file=sys.stderr)
        print(",".join(str(x) for x in shards))
        return 0
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    spec = args[0] if args else os.environ.get("CHECK_SHARD", "1/1")
    si, sn = (int(x) for x in spec.split("/"))
    pre, steps = split_steps()
    if "--list" in sys.argv:
        for k, st in enumerate(steps, 1):
            sh = shard_of(k, sn)
            print("%3d shard %s  %s" % (k, "all" if sh == 0 else sh, name_of(st, k)))
        return 0
    # check.sh's own "cd $(dirname $0)/.." means nothing under bash -c ($0 = bash): cd to the repo root instead.
    head = "\n".join(("cd %s" % shlex.quote(str(ROOT))) if l.startswith("cd ") else l
                     for l in pre if not l.startswith("#!")) + "\n"
    times = os.environ.get("CHECK_TIMES", "")
    failed = []
    t_all = time.time()
    for k, st in enumerate(steps, 1):
        mine = k == 1 or (k - 2) % sn + 1 == si
        if not mine:
            continue
        nm = name_of(st, k)
        print("\n#### step %d: %s (shard %d/%d)" % (k, nm, si, sn), flush=True)
        t0 = time.time()
        rc = subprocess.call(["bash", "-c", head + "\n".join(st) + "\n"], cwd=ROOT,
                             env=dict(os.environ, CHECK_SHARD_CHILD="1"))
        dt = time.time() - t0
        print("#### step %d %s: %s in %.1fs" % (k, nm, "PASS" if rc == 0 else "FAIL rc=%d" % rc, dt), flush=True)
        if times:
            with open(times, "a") as f:
                f.write(json.dumps({"step": k, "name": nm, "rc": rc, "secs": round(dt, 1)}) + "\n")
        if rc != 0:
            failed.append(nm)
            if k == 1:
                break  # import failed: nothing else can run
    print("\n#### shard %d/%d done in %.0fs: %s" % (si, sn, time.time() - t_all,
          "PASS" if not failed else "FAIL (%s)" % ", ".join(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
