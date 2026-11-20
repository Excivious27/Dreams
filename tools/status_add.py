#!/usr/bin/env python3
"""docs/STATUS.md helper (streams the file; never needs an agent to read it).

  python3 tools/status_add.py "one line"      add a dated entry at the top
  python3 tools/status_add.py --rotate DAYS   move entries older than DAYS days
                                              (dated '## YYYY-MM-DD' headings) to
                                              docs/STATUS-ARCHIVE.md (appended, order kept)
"""
import datetime, os, re, sys, tempfile
D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATUS = os.path.join(D, "docs", "STATUS.md")
ARCHIVE = os.path.join(D, "docs", "STATUS-ARCHIVE.md")
HEAD = re.compile(r"^## (\d{4}-\d\d-\d\d)")

def _replace(path, write):
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
    with os.fdopen(fd, "w") as out:
        write(out)
    os.chmod(tmp, os.stat(path).st_mode & 0o777 if os.path.exists(path) else 0o644)
    os.replace(tmp, path)

def add(line, today=None):
    today = today or datetime.date.today().isoformat()
    entry = f"## {today} — {line.strip()}\n\n"
    def w(out):
        placed = False
        with open(STATUS) as f:
            for l in f:
                if not placed and l.startswith("## "):
                    out.write(entry); placed = True
                out.write(l)
        if not placed:
            out.write("\n" + entry)
    _replace(STATUS, w)

def rotate(days, today=None):
    today = today or datetime.date.today()
    cut = (today - datetime.timedelta(days=days - 1)).isoformat()  # keep `days` dated days
    keep, old, cur_old, moved = [], [], False, 0
    with open(STATUS) as f:
        for l in f:
            m = HEAD.match(l)
            if m:
                cur_old = m.group(1) < cut
                moved += cur_old
            elif l.startswith("## "):
                pass  # undated heading: stays with the block it sits in
            (old if cur_old else keep).append(l)
    if not old:
        print("nothing to rotate"); return
    new_archive = not os.path.exists(ARCHIVE)
    with open(ARCHIVE, "a") as a:
        if new_archive:
            a.write("# Dreams: Status archive\n\nOlder STATUS.md entries (moved by tools/status_add.py --rotate).\n\n")
        a.writelines(old)
    _replace(STATUS, lambda out: out.writelines(keep))
    print(f"moved {moved} entries older than {cut} to docs/STATUS-ARCHIVE.md")

if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) == 2 and a[0] == "--rotate":
        rotate(int(a[1]))
    elif len(a) == 1 and not a[0].startswith("--"):
        add(a[0])
    else:
        sys.exit(__doc__)
