# CONDUCT fix agent brief (R4, 2026-11-20)
Fix ONE package of Dreams. Code map in prompt; `grep -n -i <word> docs/TOOLS.md` (never whole); read line ranges. Rules: CLAUDE.md + docs/CONDUCT-BRIEF.md.
- Fix exactly your findings + what your change breaks. Owned files only; other files max 1-2 hook lines, reported.
- CONTRACT file (in prompt) is binding: provide its APIs/ids/hooks exactly and implement the other side of hooks it names in your files.
- 60 min cap (`TZ=America/Los_Angeles date`); don't stop early.
- Godot only via `bash tools/conduct/glock.sh [-x] -- godot ...`; targeted tests + --check-only on changed scripts. Never check.sh/bots.sh locally. A focused test per fix, own block in tools/check.sh; update tests your intended change breaks. New Python import/tool -> tools/ci-requirements.txt.
- `bash tools/conduct/wip_push.sh "<what>"` every ~20 min. Never push main or merge.
- PRE-MERGE CI (R4 #13): never run/poll CI or `git fetch` ci-results. When done: wip_push; report the line `ci_run.sh <pkg>-pre 3 --branch <branch> --shards <check_shard.py --for-files ... | tr ' ' ,> [--bots if UI/menu/screen/map .gd changed]`; the orchestrator runs it.
- Art: dreams-image in budget (<=3/call), slice, wire, look once; short -> docs/ART-QUEUE.md. Audio: ACE/CC0, unused 2nd takes first.
- Docs: `python3 tools/status_add.py "<line>"`; TOOLS.md line per new tool.
- Report at your report path: item -> fixed (how+test)/not (why); art/audio; CI result; NEEDS TOM. Touch <pK>.done. Final message: "done, report in <path>".
