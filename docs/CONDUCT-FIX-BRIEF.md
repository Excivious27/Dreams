# CONDUCT fix agent rules (new process, Tom 2026-11-19) — read with BRIEF_CONDUCT.md

You are a FIX agent with ONE package. Read /home/claude/wt/BRIEF_CONDUCT.md (common rules: worktree, hardlinked art, flock, commit footer, content rules, art/audio pipeline) but these rules OVERRIDE it:
- Time cap: about 60-75 minutes of work. Prioritise Tom's own playtest items first (marked TOM), then the rest.
- NEVER run tools/check.sh or tools/bots.sh (the main chat runs them on GitHub Actions). Run only the targeted tests for files you touch (each under `flock /tmp/godot.lock`, fresh XDG_DATA_HOME, `timeout 600`), plus `--check-only` on changed scripts. Add or extend a focused test for each fix and wire it into tools/check.sh only if it runs in < 60 s.
- Stay inside your package's files. If a fix needs a file owned by another package, make the smallest possible hook and say so in the report.
- Commit on your branch as you go (small commits). Never push or merge.
- Art: dreams-image generate/edit (budget given in your package), slice, wire, look at it. Audio: ACE (budget given) / CC0. Nothing outstanding.
- Docs: one STATUS.md entry and CLAUDE.md lines for new conventions.
- Final report: each item -> fixed (how, test) / not fixed (why, suggested fix); art/audio made; NEEDS TOM.
- The window is real clock time (check `date`): do not stop early and call it "time cap". If you have to stop (turn/tool limit), write the report with what is left; the main chat resumes you to finish.
