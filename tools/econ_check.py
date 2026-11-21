#!/usr/bin/env python3
"""Economy value check (C8 P2): fails on money loops and value outliers in crops, recipes and the keg.
    python3 tools/econ_check.py [-v]
Rules (numbers live in the tables below, in tools/gen_stations.py ECON and buildings.json keg.brew):
 - a seed's tier is its crop's tier; a yield's tier is the lowest tier of the crops that give it
 - profit per tile per day (27-day season, seed bought at 1.5x value, one plant for regrowers) sits under
   its tier band's ceiling x SLACK (trees, which live for years, are skipped)
 - nothing made only from shop-bought goods sells for more than loop_cap x them (no buy-craft-sell loop)
 - no intermediate (craft/material/bar) sells for less than its inputs
 - every keg brew is worth at most cap x its produce and at least as much as the produce
"""
import json, math, os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, 'data')
I = json.load(open(os.path.join(D, 'items.json'))); C = json.load(open(os.path.join(D, 'crops.json')))
R = json.load(open(os.path.join(D, 'recipes.json'))); B = json.load(open(os.path.join(D, 'buildings.json')))
V = '-v' in sys.argv
BANDS = {1: (2, 4), 2: (3, 7), 3: (6, 10), 4: (12, 18), 5: (25, 45)}   # profit/tile/day per crop tier (c8_01)
SLACK = 1.3       # a crop may beat its band ceiling by this much before it fails
SEASON = 27
LOOP_CAP = 1.1
# Mirror of GameState.buy_price / sell_price (C8): buy_multiplier floor 0.4 x Specs 0.9, the 1.15 x sell floor,
# and the top sell multiplier (sell_bonus + Alder + bartering 20% + Deuce 15%) applied to both sides.
BUY_MIN = 0.4 * 0.9
BUY_OF_SELL = 1.15
SELL_MAX = 1.0
fails, warns = [], []

def val(k): return int(I.get(k, {}).get('value', 0))

# 1) tiers
for sid, it in I.items():
    if it.get('type') == 'seed' and it.get('crop') in C and int(it.get('tier', 1)) != int(C[it['crop']]['tier']):
        fails.append('seed tier: %s is %s, its crop %s' % (sid, it.get('tier'), C[it['crop']]['tier']))
ytier = {}
for cid, c in C.items():
    ytier[c['yield']] = min(ytier.get(c['yield'], 99), int(c['tier']))
for y, t in ytier.items():
    if y in I and int(I[y].get('tier', 1)) != t:
        fails.append('yield tier: %s is %s, lowest crop tier %d' % (y, I[y].get('tier'), t))

# 2) crop profit bands
seed_of = {it['crop']: sid for sid, it in I.items() if it.get('type') == 'seed' and it.get('crop')}
for cid, c in C.items():
    if c.get('tree') or cid not in seed_of:
        continue
    days, rg = int(c['days']), int(c.get('regrow', 0))
    picks = (1 + max(0, (SEASON - days) // rg)) if rg else max(1, SEASON // days)
    if c.get('season') != 'any' and days > SEASON:
        picks = 0
    buys = 1 if rg else picks
    profit = picks * val(c['yield']) - buys * 1.5 * val(seed_of[cid])
    pd = profit / SEASON
    lo, hi = BANDS[int(c['tier'])]
    if pd > hi * SLACK:
        fails.append('crop outlier: %s (tier %d) %.1f/day > band %d x %.1f' % (cid, int(c['tier']), pd, hi, SLACK))
    elif pd < lo * 0.5:
        warns.append('weak crop: %s (tier %d) %.1f/day (band %d-%d)' % (cid, int(c['tier']), pd, lo, hi))

# 3) recipes: loops and losing intermediates
src = open(os.path.join(ROOT, 'scripts', 'shops.gd')).read()
a = src.index('static func offers'); b = src.index('static func run', a); body = src[a:b]
SHOP = set()
DEC = json.load(open(os.path.join(D, 'decor.json'))) if os.path.exists(os.path.join(D, 'decor.json')) else {}
SHOP |= {k for rows in DEC.get('shops', {}).values() for _, ids in rows for k in ids if k in I}
for m in re.finditer(r'\[([^\[\]]*)\]', body):
    if body[:m.start()].rstrip().endswith(' in'):
        continue
    SHOP |= {w for w in re.findall(r'"([a-z0-9_]+)"', m.group(1)) if w in I}
NO_FLOOR = {'bills_crude', 'bills_passable', 'bills_fine', 'bills_perfect', 'forged_permit', 'rounds'}
def fval(k):
    if k.startswith('#'):
        vs = [int(v.get('value', 5)) for v in I.values() if v.get('family') == k[1:] or (k == '#fruit' and v.get('family') in ('tree', 'berry'))]
        return min(vs) if vs else 5
    return int(I.get(k, {}).get('value', 5))
for bk, rs in R.items():
    if not isinstance(rs, list):
        continue
    for r in rs:
        g = r['give']; n = int(r.get('n', 1)); it = I.get(g)
        if not it or g in NO_FLOOR:
            continue
        cost = sum(fval(k) * q for k, q in r['need'].items())
        out = int(it.get('value', 0)) * n
        if all((not k.startswith('#')) and k in SHOP for k in r['need']):
            if out > LOOP_CAP * cost + n:
                fails.append('loop: %s/%s makes %d from %d of shop goods (> %.2fx)' % (bk, r['id'], out, cost, LOOP_CAP))
            # Buy price vs sell value, every perk on both sides: the cheapest a shop sells an input for is
            # max(1.5 x value x BUY_MIN, BUY_OF_SELL x its sell price); the output sells for value x SELL_MAX.
            buy_min = sum(max(1.5 * BUY_MIN * fval(k), BUY_OF_SELL * fval(k) * SELL_MAX) * q for k, q in r['need'].items())
            if out * SELL_MAX > buy_min + n:
                fails.append('buy-sell loop: %s/%s sells for %d with every perk, inputs bought for %d' % (bk, r['id'], int(out * SELL_MAX), int(buy_min)))
        if it.get('type') in ('craft', 'material', 'bar') and not r.get('tool') and out + n < cost:
            # several recipes may make one good: only the cheapest has to pay
            cheapest = min(sum(fval(k) * q for k, q in o['need'].items()) / float(o.get('n', 1)) for b2 in R.values() if isinstance(b2, list) for o in b2 if o['give'] == g)
            if int(it.get('value', 0)) + 1 < cheapest:
                fails.append('loses value: %s/%s %d from %d' % (bk, r['id'], out, cost))

# 3a) decor and wearables (C10a): a money sink. Mirror of Decor.buy_price / Decor.sell_value:
#  the cheapest a decor piece is ever bought for is price x DECOR_BUY_MIN; it sells back flat at its value
#  (no perks, no demand), so value < price x DECOR_BUY_MIN always; crafted decor sells below its inputs;
#  re-order fee >= 0; rarity price bands from decor.json; uniques worth 0 and never stocked.
DECOR_BUY_MIN = 0.8 * 0.9
if DEC:
    bands = {r['id']: r['band'] for r in DEC.get('rarity', [])}
    stocked = {k for rows in DEC.get('shops', {}).values() for _, ids in rows for k in ids}
    for k, e in DEC.get('items', {}).items():
        if e.get('ext'):
            continue
        v = val(k) if k in I else int(e.get('sell', 0))
        p = int(e.get('price', 0))
        if e.get('order') is False and not p:
            if v or k in stocked:
                fails.append('decor keepsake priced/stocked: %s' % k)
            continue
        if e['rarity'] == 'unique':
            if p or v or k in stocked:
                fails.append('decor unique priced/stocked: %s' % k)
            continue
        if v >= p * DECOR_BUY_MIN:
            fails.append('decor buy-sell loop: %s sells %d, bought for %d' % (k, v, int(p * DECOR_BUY_MIN)))
        lo, hi = bands.get(e['rarity'], [0, 1e12])
        if not lo <= p <= hi:
            fails.append('decor price out of band: %s %s %d' % (k, e['rarity'], p))
        if e['rarity'] == 'mythic' and k in stocked:
            fails.append('decor mythic in a shop: %s' % k)
    for rs in R.values():
        if not isinstance(rs, list):
            continue
        for r in rs:
            if r['give'] in DEC.get('items', {}) and r['give'] in I:
                cost = sum(fval(q) * n for q, n in r['need'].items())
                if val(r['give']) * int(r.get('n', 1)) > cost:
                    fails.append('decor craft earns: %s %d from %d' % (r['id'], val(r['give']), cost))
    if float(DEC.get('reorder_fee', 0)) < 0:
        fails.append('decor re-order fee below 0')
    # C10b (c10b_10_15): the decor economy itself, not just per-piece loops.
    # (a) a real price ladder: each shop rarity has many price points, not four.
    from collections import defaultdict
    pts = defaultdict(set)
    for k, e in DEC.get('items', {}).items():
        if e.get('price') and not e.get('ext'):
            pts[e['rarity']].add(int(e['price']))
    for r, need in (('common', 15), ('uncommon', 15), ('rare', 15), ('epic', 15)):
        if len(pts[r]) < need:
            fails.append('decor price ladder: %s has only %d price points' % (r, len(pts[r])))
    # (b) re-order always costs more than the shelf (fee > 0) and the fee is flat-ish (<= 10% + min).
    if int(DEC.get('reorder_min', 0)) < 1 or not 0 < float(DEC.get('reorder_fee', 0)) <= 0.25:
        fails.append('decor re-order fee/min out of range')
    # (c) every shelf a counter/stall opens exists, and no shelf list is dead weight (only listed keys).
    import re as _re
    src_ds = open(os.path.join(ROOT, 'scripts', 'decor_sources.gd')).read()
    shelf_keys = set(_re.findall(r'"[a-z_]+": "([a-z_]+)"', src_ds.split('const SHELF := {', 1)[1].split('}', 1)[0]))
    for k in shelf_keys:
        if k not in DEC.get('shops', {}):
            fails.append('decor shelf %s (DecorSources.SHELF) missing in decor.json' % k)
    # (d) late-game sink: some legendary pieces are buyable (hub stalls) and none cost more than the cap.
    leg = [k for rows in [v for kk, v in DEC.get('shops', {}).items() if kk.startswith('stall:')] for _, ids in rows for k in ids
           if DEC['items'][k]['rarity'] == 'legendary']
    if not leg:
        fails.append('decor: no legendary piece on any stall (late-game sink)')
    # (e) set claims pay less than the pieces' sell-back + 15% of their price (never a reason to buy a set to flip it).
    for sid, st in DEC.get('sets', {}).items():
        pay = int((st.get('reward') or {}).get('money', 0))
        cost = sum(int(DEC['items'][p].get('price', 0)) for p in st.get('pieces', []))
        if pay and cost and pay > cost * 0.5:
            fails.append('decor set %s pays %d for pieces costing %d' % (sid, pay, cost))
    # (f) 3-year spend sim: buying one of every shelf piece (lists, not stock) at the minimum discount must cost
    # more than a mid-game player earns from decor sell-back of the same pieces (sink, not source).
    spend = sum(int(DEC['items'][k]['price'] * DECOR_BUY_MIN) for k in stocked if DEC['items'][k].get('price'))
    back = sum((val(k) if k in I else int(DEC['items'][k].get('sell', 0))) for k in stocked)
    if back >= spend * 0.5:
        fails.append('decor sink: sell-back %d vs spend %d' % (back, spend))

# 3c) a tempered piece is worth more than its base (c10_07)
for rs in R.values():
    if isinstance(rs, list):
        for r in rs:
            if r['id'].startswith('temper_') and r['id'][7:] in I and r['give'] in I and val(r['give']) <= val(r['id'][7:]):
                fails.append('temper worth less: %s %d <= %d' % (r['give'], val(r['give']), val(r['id'][7:])))

# 3b) animal goods are never a dead end: each one goes into at least one recipe (directly or by family)
RANCH = json.load(open(os.path.join(D, 'ranch.json'))) if os.path.exists(os.path.join(D, 'ranch.json')) else {}
ANIMAL_GOODS = sorted(g for g in RANCH.get('products', {}) if I.get(g, {}).get('ranch')) or ['egg', 'duck_egg', 'milk', 'goat_milk', 'sheep_wool']
# c11b_12-07: the C11a goods have their loom/extractor recipes now, so a dead end fails like the classics
OLD_GOODS = {'egg', 'duck_egg', 'milk', 'goat_milk', 'sheep_wool', 'truffle', 'honey', 'feather', 'rabbit_fur', 'beeswax'}
for g in ANIMAL_GOODS:
    keys = {g} | ({'#' + I[g]['family']} if I.get(g, {}).get('family') else set())
    if not any(k in r['need'] for rs in R.values() if isinstance(rs, list) for r in rs for k in keys):
        # newer creature goods warn until their recipes exist (gen_stations.py; ranch.json "processing")
        (fails if g in OLD_GOODS else warns).append('dead end: %s goes into no recipe' % g)

# 3d) ranch (C11a, tables in tools/gen_ranch.py): feeding always pays, no hay buy-sell loop, rehome can't loop,
#     and each grown animal's goods per day sit in a band per home (warn outside it).
HAY_BUY = 1.5 * val('hay')
HAY_MIN_BUY = max(HAY_BUY * BUY_MIN, val('hay') * BUY_OF_SELL * SELL_MAX)
if HAY_MIN_BUY <= val('hay') * SELL_MAX:
    fails.append('hay: cheapest buy %.1f <= sell %d (loop)' % (HAY_MIN_BUY, val('hay')))
# c11b_12-02/-03/-04: one value ladder (tools/gen_ranch.py TIER_LADDER, written to ranch.json "ladder"):
#   bought animals pay back in payback[0]..payback[1] days net of a day's bought hay (fail outside);
#   goods per pen cell per day sit in their class band (warn outside; unique one-per-save creatures may go higher);
#   hay eaters keep >= 25% of their goods after hay (fail); lab strains stay within +-20% of the classic beside them.
LAD = RANCH.get('ladder', {}) or {'classic': (10, 40), 'exotic': (20, 75), 'fantastic': (25, 90), 'lab': (10, 80), 'payback': (20, 60), 'lab_vs_classic': 0.2}
HAY_DAY = float(RANCH.get('rules', {}).get('hay_buy', 8))
FAMILY_CLASS = {'': 'classic', 'exotics': 'exotic', 'fantastic': 'fantastic', 'lab': 'lab'}
SP = RANCH.get('species', {})
def goods_day(sp):
    pr = sp['product']
    d = val(pr['id']) / max(1, pr['every_days'])
    if pr.get('extra'):
        d += val(pr['extra'][0]) * float(pr['extra'][1]) / max(1, pr['every_days'])
    return d
LAB_PAIR = {'chrome_hen': 'chicken', 'glow_sheep': 'sheep', 'circuit_goat': 'goat', 'turbo_bunny': 'rabbit', 'circuit_cow': 'cow',
            'drone_hog': 'pig', 'volt_gecko': 'tortoise', 'chrome_runner': 'ostrich'}
for sid, sp in SP.items():
    pr = sp['product']
    per_day = goods_day(sp)
    hay = HAY_DAY if sp.get('feed') == 'hay' else 0.0
    if hay and per_day - hay < 0.25 * per_day:
        fails.append('ranch: %s goods %.1f/day barely pay for its hay (%.0f/day)' % (sid, per_day, hay))
    price = int(sp['buy']['price'])
    if price > 0:
        pb = price / max(0.1, per_day - hay)
        if not LAD['payback'][0] <= pb <= LAD['payback'][1]:
            fails.append('ranch: %s pays back in %.0f days (ladder %d-%d)' % (sid, pb, LAD['payback'][0], LAD['payback'][1]))
    cls = FAMILY_CLASS.get(sp.get('family', ''), 'classic')
    lo, hi = LAD[cls]
    cell = per_day / max(0.5, float(sp.get('space', 1)))
    if not lo <= cell <= hi and not (sp.get('unique') and cell <= LAD.get('unique_cap', 200)):
        warns.append('ranch: %s %.1f/cell/day outside the %s band %d-%d' % (sid, cell, cls, lo, hi))
    if sid in LAB_PAIR and LAB_PAIR[sid] in SP:
        base = goods_day(SP[LAB_PAIR[sid]])
        if abs(per_day - base) > LAD['lab_vs_classic'] * base + 0.01:
            fails.append('ranch: lab %s %.1f/day strays over %d%% from %s %.1f' % (sid, per_day, LAD['lab_vs_classic'] * 100, LAB_PAIR[sid], base))
    if int(sp.get('rehome_pay', 0)) > 0.25 * price:
        fails.append('ranch: %s rehome pays %d > 25%% of its price' % (sid, sp['rehome_pay']))
    if V: print('ranch %-14s %6.1f/day %5.1f/cell payback %s rehome %d' % (sid, per_day, cell, ('%.0f d' % (price / max(0.1, per_day - hay))) if price else 'earned', int(sp.get('rehome_pay', 0))))
# End-game multiplier, printed so the caps are reviewed with the ladder: (1 + animal_yield cap) x (1 + ranch_value cap) x gold 1.5
if V:
    try:
        ST = json.load(open(os.path.join(D, 'skill_trees.json')))
        caps = ST.get('caps', {}) if isinstance(ST, dict) else {}
        ay, rv = float(caps.get('animal_yield', 1.0)), float(caps.get('ranch_value', 0.35))
    except Exception:
        ay, rv = 1.0, 0.35
    print('ranch end-game multiplier: x%.2f (animal_yield %.2f, ranch_value %.2f, gold 1.5)' % ((1 + ay) * (1 + rv) * 1.5, ay, rv))

# 4) keg (mirror of Crafting.keg_plan)
tb = B['keg']['brew']
SPECIAL = {"strawberry": "strawberry_wine", "corn": "corn_ale", "berry": "berry_juice", "dreamflower": "dream_tonic", "grape": "wine", "apple": "cider", "tea": "herbal_tea", "honey": "flower_mead"}
def family(i):
    it = I.get(i, {})
    if it.get('family'): return it['family']
    b2 = {"wild_herb": "herb", "berry": "berry", "flower": "flower"}.get(i, "")
    if b2: return b2
    return it.get('type') if it.get('type') in ('herb', 'flower', 'fruit') else ''
def brew_of(i):
    if i in SPECIAL: return SPECIAL[i]
    t = int(I.get(i, {}).get('tier', 1)); f = family(i)
    if f in ('berry', 'fruit', 'tree'): return 'fruit_wine' if t <= 2 else ('fine_wine' if t == 3 else 'starlight_wine')
    return {'veg': 'pickles', 'herb': 'herbal_tea', 'grain': 'harvest_ale', 'mushroom': 'mushroom_broth', 'flower': 'flower_mead', 'magic': 'wonder_elixir'}.get(f, '')
for y in sorted(set(c['yield'] for c in C.values()) | {'flower', 'wild_herb', 'berry', 'honey'}):
    br = brew_of(y)
    if not br: continue
    v = max(1.0, float(val(y)))
    if v >= tb['premium_at'] and family(y) in tb['premium']: br = tb['premium'][family(y)]
    d = max(1.0, float(val(br)))
    if d >= tb['mult'] * v:
        k, n = max(1, math.ceil(d / (tb['cap'] * v))), 1
    else:
        k, n = 1, min(tb['max_out'], max(1, round(tb['mult'] * v / d)))
    ratio = d * n / (v * k)
    if V: print('keg %-16s %3d x%d -> %d %s (%.2fx)' % (y, v, k, n, br, ratio))
    if ratio > tb['cap'] + 0.01:
        fails.append('keg: %s -> %s pays %.2fx (> cap %.1f)' % (y, br, ratio, tb['cap']))
    if ratio < 1.0 and n < tb['max_out']:
        fails.append('keg: %s -> %s loses value (%.2fx)' % (y, br, ratio))

# 5) money routing (C16a P2, c16a_16-01): every payout goes through GameState.add_money(n, source) so
#    run.earned_by (the per-source income ledger the 3-year sim reads) sees it. Only game_state.gd itself
#    and the bank withdrawal (interior.gd, not earnings) may add to the purse directly.
MONEY_DIRECT_OK = {'game_state.gd', 'interior.gd'}
SD = os.path.join(ROOT, 'scripts')
for fn in sorted(os.listdir(SD)):
    if not fn.endswith('.gd') or fn in MONEY_DIRECT_OK:
        continue
    for ln, line in enumerate(open(os.path.join(SD, fn)), 1):
        if re.search(r'run\["crystals"\]\s*=\s*int\(GameState\.run\["crystals"\]\)\s*\+', line):
            fails.append('money route: scripts/%s:%d adds to the purse without GameState.add_money' % (fn, ln))
for fn in sorted(os.listdir(SD)):
    if fn.endswith('.gd'):
        for ln, line in enumerate(open(os.path.join(SD, fn)), 1):
            if re.search(r'add_money\([^)]*"quests"\)', line):
                fails.append('money route: scripts/%s:%d uses source "quests" (the key is "quest")' % (fn, ln))

for w in warns if V else []:
    print('warn:', w)
print('econ check: %d crops, %d recipes, %d warnings, %d failures' % (len(C), sum(len(x) for x in R.values() if isinstance(x, list)), len(warns), len(fails)))
for f in fails:
    print('FAIL', f)
sys.exit(1 if fails else 0)
