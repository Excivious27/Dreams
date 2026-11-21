#!/usr/bin/env python3
"""C16a P2: guards the simulator's short run (check.sh block "sim smoke").
    python3 tools/sim_bands.py <csv> [<csv> ...]
Each CSV is a tools/sim.gd run (one season or longer). Fails when a band breaks; prints warnings for the
bands other packages tune (energy: P3, gates: P1) so the numbers show up in CI logs.
Bands (season 1, day length 15; numbers from c16a_17-07 / c16a_16-13, loosened to the sim's measured spread):
  farmer   day-28 purse 1,000..20,000; farming level at day 28 10..35; season-1 income 5,000..60,000
  explorer day-28 mining level 10..40; season-1 income 5,000..120,000 (fishing+ore)
  every run: 28+ rows, no day where the purse goes negative, chapter <= 2 by day 28, no skill at 100 by day 28
"""
import csv, sys

fails, warns = [], []
BANDS = {
    'farmer': {'purse28': (1000, 20000), 'lv28': ('lv_farming', 10, 35), 'inc': (5000, 60000)},
    'explorer': {'lv28': ('lv_mining', 10, 40), 'inc': (5000, 120000)},
}
for p in sys.argv[1:]:
    rows = list(csv.DictReader(open(p)))
    if len(rows) < 28:
        fails.append('%s: only %d days' % (p, len(rows)))
        continue
    st = rows[0]['style']
    tag = '%s %s %sm' % (st, rows[0]['arc'], rows[0]['day_len'])
    d28 = rows[27]
    inc = sum(int(r['earned_today']) for r in rows[:28])
    used3 = sum((int(r['energy_start']) - int(r['energy_end'])) / max(1, int(r['energy_max'])) for r in rows[:3]) / 3
    print('sim bands %s: d28 purse %s, income s1 %d, d1-3 energy used %.0f%%, chapter %s, levels f%s/fi%s/m%s' % (
        tag, d28['purse'], inc, used3 * 100, d28['chapter'], d28['lv_farming'], d28['lv_fishing'], d28['lv_mining']))
    if any(int(r['purse']) < 0 for r in rows):
        fails.append('%s: purse went negative' % tag)
    if int(d28['chapter']) > 2:
        fails.append('%s: story chapter %s by day 28' % (tag, d28['chapter']))
    for sk in ('farming', 'fishing', 'mining', 'combat', 'foraging'):
        if int(d28['lv_' + sk]) >= 100:
            fails.append('%s: %s at 100 by day 28' % (tag, sk))
    b = BANDS.get(st, {})
    if 'purse28' in b and not (b['purse28'][0] <= int(d28['purse']) <= b['purse28'][1]):
        fails.append('%s: day-28 purse %s outside %d..%d' % (tag, d28['purse'], *b['purse28']))
    if 'lv28' in b:
        k, lo, hi = b['lv28']
        if not (lo <= int(d28[k]) <= hi):
            fails.append('%s: day-28 %s %s outside %d..%d' % (tag, k, d28[k], lo, hi))
    if 'inc' in b and not (b['inc'][0] <= inc <= b['inc'][1]):
        fails.append('%s: season-1 income %d outside %d..%d' % (tag, inc, *b['inc']))
    if used3 > 0.40:
        warns.append('%s: days 1-3 use %.0f%% of the bar (P3 target <= 35-40%%)' % (tag, used3 * 100))
for w in warns:
    print('warn:', w)
print('sim bands: %d runs, %d warnings, %d failures' % (len(sys.argv) - 1, len(warns), len(fails)))
for f in fails:
    print('FAIL', f)
sys.exit(1 if fails else 0)
