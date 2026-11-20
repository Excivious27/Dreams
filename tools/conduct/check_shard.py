#!/usr/bin/env python3
"""Run tools/check.sh as named steps, optionally one shard of them.

    CHECK_SHARD=i/N bash tools/check.sh      (check.sh execs this script)
    python3 tools/conduct/check_shard.py [i/N] [--list]

check.sh stays a plain script that people edit as before: blocks separated by a
blank line (at nesting depth 0) are steps. The first step (import) runs in every
shard; the rest go round-robin (step k runs in shard (k-1) % N + 1). Each step runs
in its own bash with the check.sh preamble, so steps must not lean on variables
set by an earlier step (each test block sets its own).

Unlike the plain script, a shard keeps going after a failing step and exits 1 at
the end, so one run reports every failure. Per-step wall times go to
$CHECK_TIMES (JSON lines: step, name, rc, secs) when set.
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


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    spec = args[0] if args else os.environ.get("CHECK_SHARD", "1/1")
    si, sn = (int(x) for x in spec.split("/"))
    pre, steps = split_steps()
    if "--list" in sys.argv:
        for k, st in enumerate(steps, 1):
            sh = 0 if k == 1 else (k - 2) % sn + 1
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
