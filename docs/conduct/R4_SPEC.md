# OPTIMIZATION ROUND 4 (Tom 2026-11-20 22:48): <1.5 h per CONDUCT, lower usage, same quality
Measured (C11b, S1): ~3.5 h between ships. Time sinks, in order:
 a) final CI failing then fix+rerun (bot softlocks, playtest timing, commons race): 30-60 min each, 2-3 per CONDUCT
 b) integration agent 60-90 min (cross-package hooks left for "integration")
 c) one shared godot lock on 2 CPUs: auditors' play probes queue 40-60 deep; most never run (quality loss + wasted wall time)
 d) ci_run --branch tests a stale head unless origin/<branch> is refetched; --shards disables bots
 e) server restarts (3 today) stop agents
 f) disk fills (worktrees with real .godot copies, /tmp shots), class cache stale in worktrees (game won't compile)
 g) my own orchestration: a reply per agent notification; long briefs re-read by every agent
Changes (implement all):
 1 SHARED SHOTS: tools/conduct/shots_sweep.sh <N> runs ONCE at audit start (one godot session per arc, all scenes + key screens/menus/dialogue/festival/battle-drill states) into /home/claude/wt/shots_<N>/ with an index.md; auditors VIEW those instead of running godot; at most 1 targeted godot run each, only if their scope's state isn't in the sweep. AUDIT_BRIEF updated.
 2 BOT PREFLIGHT ON EVERY FIX BRANCH: ci_run gets --bots (bots on with --shards) and --bots-only; fix agents that touch any scripts/*.gd UI/menu/screen/map file run shards + all 20 bots + playtest pre-merge. Rolling merges into an integration branch get a full CI as soon as 3 packages are in, not only at the end.
 3 ci_run.sh fixes: always `git fetch origin +refs/heads/<b>:refs/remotes/origin/<b>` and deepen main itself; refuse if remote head != local branch head; print the sha tested.
 4 NO INTEGRATION PHASE AS A SEPARATE 90-MIN AGENT: packages get a shared CONTRACT file at launch (APIs/ids/hooks each package provides, written by me from the findings before launch); fix agents must implement the other side of hooks that touch their files when the contract names them; integration = me merging + one 30-min hook agent only if the merge leaves gaps. Fix-agent cap 60 min.
 5 LOCKS: godot lock with 2 slots for fix agents (tools/conduct/glock.sh: flock on /tmp/godot.lock.0 or .1, whichever free); auditors use shots (no lock). Kill Xvfb with any xvfb-run killed (glock wraps xvfb-run with -a and cleanup trap).
 6 WORKTREES: mkwt.sh copies the fresh .godot/global_script_class_cache.cfg (main reimported once per CONDUCT); tools/conduct/wt_clean.sh removes merged/finished worktrees and /tmp dirs older than 2 h; run at each stage boundary; disk check (abort launch under 4 GB free).
 7 RESTART RESILIENCE: agents commit+push WIP every ~20 min (brief rule) so a restart loses little; watchdog resumes by SendMessage.
 8 AUDITORS: 20 stay (Tom's rule); scope lines tighter, 30-min cap, medium effort, shots-based depth floor (view >=8 sweep shots in scope, both arcs) + verified_clean list.
 9 BRIEFS: FIX_BRIEF and AUDIT_BRIEF slimmed to the essentials (<1.5 KB each); one shared template per stage (auditor/fix) so prompts are one line.
10 ORCHESTRATION: I reply to Tom only at stage boundaries + hourly check-ins (not per agent); watchdog every 20 min in fix phase.
11 DOCS IN PARALLEL: report/guide/docs agent starts when the final CI starts (from the reports), build_package runs right after green.
12 TIMING TABLE: record audit/fix/merge/CI/package per CONDUCT in the report and the Baton.
Verify: ci_run on main with --bots and --branch on a test branch; shots_sweep produces index for both arcs in < 10 min; glock two slots work; record times. Then HANDOFF "CONDUCT operating rules" section updated (round 4), CLAUDE.md pointer unchanged, push.
