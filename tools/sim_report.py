#!/usr/bin/env python3
"""C16a P2: builds the 3-year simulator workbook from tools/sim.gd CSVs.
    python3 tools/sim_report.py <csv_dir> [out.xlsx]      (default docs/reports/sim/C16A-SIM.xlsx)
Tabs: Summary (per style/arc/day length: income per year, end purse, spend, levels, deepest floor, hearts),
Seasons (income by source per season), Energy (bedtime bar %, days energy-bound, max energy by season),
Skills (main levels at day 28/56/112/224/336), Unlocks (first day per key, one column per run), Notes.
Arial, frozen headers, banded rows; numbers are what the sim measured (never typed in).
"""
import csv, glob, os, sys
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.utils import get_column_letter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = sys.argv[1] if len(sys.argv) > 1 else '/tmp/sim3y'
out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'docs', 'reports', 'sim', 'C16A-SIM.xlsx')
SEASONS = ['spring', 'summer', 'fall', 'winter']
SKILLS = ['farming', 'fishing', 'mining', 'combat', 'foraging', 'building']
ORDER = {'farmer': 0, 'explorer': 1, 'social': 2, 'hustler': 3}

runs = []
for p in sorted(glob.glob(os.path.join(src, '*.csv'))):
    if p.endswith('_unlocks.csv'):
        continue
    rows = list(csv.DictReader(open(p)))
    if not rows:
        continue
    up = p[:-4] + '_unlocks.csv'
    ul = {r['key']: int(r['day']) for r in csv.DictReader(open(up))} if os.path.exists(up) else {}
    r0 = rows[0]
    runs.append({'style': r0['style'], 'arc': r0['arc'], 'len': int(r0['day_len']), 'rows': rows, 'ul': ul})
runs.sort(key=lambda r: (r['len'], ORDER.get(r['style'], 9), r['arc']))
if not runs:
    sys.exit('sim_report: no CSVs in %s' % src)

HF = Font(name='Arial', bold=True, color='FFFFFF')
HFILL = PatternFill('solid', fgColor='000000')
BAND = PatternFill('solid', fgColor='EEEEEE')
NF = Font(name='Arial')
TF = Font(name='Arial', bold=True, size=13)
wb = Workbook()


def sheet(title, head, data, note=''):
    ws = wb.active if wb.active.title == 'Sheet' else wb.create_sheet()
    ws.title = title
    ws['A1'] = 'Dreams C16a 3-year simulator: ' + title
    ws['A1'].font = TF
    ws['A2'] = note
    ws['A2'].font = Font(name='Arial', italic=True, color='666666')
    for c, h in enumerate(head, 1):
        cell = ws.cell(row=3, column=c, value=h)
        cell.font, cell.fill = HF, HFILL
        cell.alignment = Alignment(wrap_text=True, vertical='top')
    for i, row in enumerate(data):
        for c, v in enumerate(row, 1):
            cell = ws.cell(row=4 + i, column=c, value=v)
            cell.font = NF
            if i % 2:
                cell.fill = BAND
            if isinstance(v, float):
                cell.number_format = '0.0%' if abs(v) <= 1.5 else '#,##0.0'
            elif isinstance(v, int):
                cell.number_format = '#,##0'
    for c in range(1, len(head) + 1):
        w = max([len(str(head[c - 1]))] + [len(str(r[c - 1])) for r in data if c - 1 < len(r)])
        ws.column_dimensions[get_column_letter(c)].width = min(34, max(9, w + 2))
    ws.freeze_panes = 'B4' if title == 'Unlocks' else 'A4'
    return ws


def ival(x, k):
    return int(float(x[k]))


def name(r):
    return '%s %s %dm' % (r['style'], r['arc'][:4], r['len'])


# Summary
head = ['Style', 'Arc', 'Day (min)', 'Income Y1', 'Income Y2', 'Income Y3', 'Y3 / Y1', 'Purse end', 'Spent (3 y)',
        'Buildings spend', 'Main skill', 'Main lv d112', 'Main lv d336', 'Deepest floor', 'Hearts d336', 'Chapter d336', 'Unlock keys']
data = []
MAIN = {'farmer': 'farming', 'explorer': 'mining', 'social': 'farming', 'hustler': 'farming'}
for r in runs:
    rows = r['rows']
    yi = [sum(ival(x, 'earned_today') for x in rows if x['year'] == str(y)) for y in (1, 2, 3)]
    m = MAIN.get(r['style'], 'farming')
    at = lambda d, k: ival(rows[min(d, len(rows)) - 1], k)
    data.append([r['style'], r['arc'], r['len'], yi[0], yi[1], yi[2], round(yi[2] / yi[0], 2) if yi[0] else 0,
                 at(len(rows), 'purse'), at(len(rows), 'spent_total'), None, m, at(112, 'lv_' + m), at(len(rows), 'lv_' + m),
                 at(len(rows), 'mine_deepest'), at(len(rows), 'hearts_total'), at(len(rows), 'chapter'), len(r['ul'])])
    data[-1][9] = sum(1 for k in r['ul'] if k.startswith('build:'))
head[9] = 'Building tiers bought'
sheet('Summary', head, data, 'One row per simulated run (112-day years). Income = everything run.earned_by counted.')

# Seasons: income by source per season
head = ['Run', 'Year', 'Season', 'Income', 'Crops', 'Fish', 'Ore', 'Quests', 'Racket', 'Other', 'Spent', 'Purse end']
data = []
for r in runs:
    for y in (1, 2, 3):
        for s in SEASONS:
            rr = [x for x in r['rows'] if x['year'] == str(y) and x['season'] == s]
            if not rr:
                continue
            sm = lambda k: sum(ival(x, k) for x in rr)
            data.append([name(r), y, s, sm('earned_today'), sm('inc_crops'), sm('inc_fish'), sm('inc_ore'), sm('inc_quest'),
                         sm('inc_racket'), sm('inc_other'), sm('spent_today'), ival(rr[-1], 'purse')])
sheet('Seasons', head, data, 'Sales are split by what was shipped that day (crops / fish / ore).')

# Energy
head = ['Run', 'Year', 'Season', 'Max energy (end)', 'Bedtime bar % (avg)', 'Bedtime bar % (min)', 'Days energy-bound', 'Days time-bound', 'Day 1-3 energy used %']
data = []
for r in runs:
    first3 = [x for x in r['rows'][:3]]
    used3 = sum((ival(x, 'energy_start') - ival(x, 'energy_end')) / max(1, ival(x, 'energy_max')) for x in first3) / 3
    for y in (1, 2, 3):
        for s in SEASONS:
            rr = [x for x in r['rows'] if x['year'] == str(y) and x['season'] == s]
            if not rr:
                continue
            pct = [ival(x, 'energy_end') / max(1, ival(x, 'energy_max')) for x in rr]
            data.append([name(r), y, s, ival(rr[-1], 'energy_max'), round(sum(pct) / len(pct), 3), round(min(pct), 3),
                         sum(1 for x in rr if x['bound'] == 'energy'), sum(1 for x in rr if x['bound'] == 'time'),
                         round(used3, 3) if (y, s) == (1, 'spring') else None])
sheet('Energy', head, data, 'Bound = what ended the work day: the energy bar or the clock (day length x 60 / 6 s per action).')

# Skills
marks = [7, 28, 56, 112, 168, 224, 336]
head = ['Run', 'Skill'] + ['Lv d%d' % d for d in marks]
data = []
for r in runs:
    for sk in SKILLS:
        data.append([name(r), sk] + [ival(r['rows'][min(d, len(r['rows'])) - 1], 'lv_' + sk) for d in marks])
sheet('Skills', head, data, 'Skill levels on the given days (year 1 ends day 112, year 3 day 336).')

# Unlocks: key x run
keys = sorted({k for r in runs for k in r['ul']}, key=lambda k: (min(r['ul'].get(k, 9999) for r in runs), k))
head = ['Unlock key', 'Earliest day', 'Earliest run'] + [name(r) for r in runs]
data = []
for k in keys:
    ds = [(r['ul'][k], name(r)) for r in runs if k in r['ul']]
    e = min(ds)
    data.append([k, e[0], e[1]] + [r['ul'].get(k) for r in runs])
sheet('Unlocks', head, data, 'First day each key turned true (quest:, mega:, build:id:tier, chapter:, mine:, skill:id:level, year:). Blank = never in 3 years.')

notes = [
    ['How it plays', 'tools/sim.gd: headless, seeded, game time only. Real rules: Farm.harvest_count/quality_odds/harvest_xp, GameState.spend_for/energy_cost_f/hits_for/sleep, Fishing.pick/xp_for, Racket.risk/pass_cap, Builds gates/prices.'],
    ['Time budget', 'day length x 60 s / 6 s per action, minus walking (15 actions per area trip); swings 0.9 s, casts ~10 s.'],
    ['Story', 'Quests finish a few days after their condition holds (delay per style); asked items are paid at their value from the purse; story-beat flags cost one extra main-quest delay; chapters have an effort floor day per style.'],
    ['Spending', 'Next building tier or permit when the purse holds 1.3x its price, one a day, in a per-style order; social buys gifts daily and decor weekly.'],
    ['Not modelled yet', 'skill-tree node buys, tool upgrades, food, ranch animals and artisan goods, crafting, casino, racket note costs, battle campaigns. Read the curves as a floor for farm/ranch players and a ceiling for racket income.'],
]
sheet('Notes', ['Topic', 'Detail'], notes, '')
wb['Notes'].column_dimensions['B'].width = 120
os.makedirs(os.path.dirname(out), exist_ok=True)
wb.save(out)
print('sim_report: %d runs, %d unlock keys -> %s' % (len(runs), len(keys), out))
