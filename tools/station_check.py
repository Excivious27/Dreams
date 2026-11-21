#!/usr/bin/env python3
"""The workshop has no dead ends: starting from what the world gives you,
every station tier can be built and every recipe made, in both arcs.
    python3 tools/station_check.py
"""
import json, re, glob, os, sys
D = os.path.join(os.path.dirname(__file__), '..', 'data') + '/'
I = json.load(open(D + 'items.json')); R = json.load(open(D + 'recipes.json')); B = json.load(open(D + 'buildings.json')); C = json.load(open(D + 'crops.json'))
B.pop('_', None)
made = {r['give'] for l in R.values() if isinstance(l, list) for r in l}
txt = ''.join(open(D + f).read() for f in ('forage.json', 'season_goods.json', 'enemies.json', 'regions.json', 'interiors.json'))
for f in glob.glob(os.path.join(D, '..', 'scripts', '*.gd')): txt += open(f).read()
raw = {k for k in I if k not in made and re.search(r'"%s"' % re.escape(k), txt)}
raw |= {c['yield'] for c in C.values()} | {k for k, v in I.items() if v.get('type') in ('fish', 'seed')}
raw |= {'coal', 'copper_bar', 'iron_bar', 'glass', 'leather', 'cloth', 'rope'} & {k for k in I if re.search(r'"%s"' % k, open(os.path.join(D, '..', 'scripts', 'shops.gd')).read())}
FAM = {v.get('family') for v in I.values()} | {'fruit'}
fails = 0
# C11b: animal goods come from the ranch (data/ranch.json): what each arc's creatures make is in hand.
RJ = json.load(open(D + 'ranch.json')) if os.path.exists(D + 'ranch.json') else {}
def ranch_goods(arc):
    out = set()
    for sid, sp in RJ.get('species', {}).items():
        if str(sp.get('arc', '') or '') not in ('', 'both', arc): continue
        p = sp.get('product', {})
        out.add(p.get('id'))
        if p.get('extra'): out.add(p['extra'][0])
        for v in (sp.get('art', {}) or {}).get('variants', []) or []:
            if isinstance(v, dict):
                if v.get('product'): out.add(v['product'])
                if v.get('product_extra'): out.add(v['product_extra'][0])
        egg = (sp.get('breed', {}) or {}).get('egg')
        if egg: out.add(egg)
    for raw_id, made_ids in RJ.get('processing', {}).items():
        if raw_id in out: out |= set(made_ids)
    return {k for k in out if k in I}
for arc in ('penguins', 'gangsters'):
    have = set(raw) | ranch_goods(arc); tiers = {}
    def ok(k): return (k[1:] in FAM) if k.startswith('#') else k in have
    changed = True
    while changed:
        changed = False
        for bid, b in B.items():
            if b.get('arc', arc) != arc: continue
            t = tiers.get(bid, 0)
            nd = next((x for x in b.get('tiers', []) if x['tier'] == t + 1), None)
            if nd and all(ok(k) for k in nd.get('cost', {})):
                tiers[bid] = t + 1; changed = True
        for bid, b in B.items():
            if 'station' not in b or tiers.get(bid, 0) == 0: continue
            for r in R.get(b['station']['book'], []):
                if r.get('arc', arc) != arc or r['give'] in have: continue
                if r.get('tier', 1) <= min(5, tiers[bid] + 1) and all(ok(k) for k in r['need']):
                    have.add(r['give']); changed = True
    for bid, b in B.items():
        if b.get('arc', arc) != arc: continue
        if tiers.get(bid, 0) < len(b.get('tiers', [])):
            nd = b['tiers'][tiers.get(bid, 0)]
            print('  FAIL %s: %s tier %d (%s) can never be built; missing %s' % (arc, bid, nd['tier'], nd['name'], [k for k in nd.get('cost', {}) if not ok(k)])); fails += 1
        if 'station' in b:
            for r in R.get(b['station']['book'], []):
                if r.get('arc', arc) == arc and r['give'] not in have:
                    print('  FAIL %s: recipe %s at %s can never be made; missing %s' % (arc, r['id'], bid, [k for k in r['need'] if not ok(k)])); fails += 1
                if r['give'] not in I: print('  FAIL recipe %s gives unknown item' % r['id']); fails += 1
                if r.get('tier', 1) > len(b['tiers']) + 1: print('  FAIL recipe %s tier is above what %s can reach' % (r['id'], bid)); fails += 1
books = {b['station']['book'] for b in B.values() if 'station' in b}
for k, l in R.items():
    if isinstance(l, list) and k not in books: print('  FAIL recipe book %s has no station' % k); fails += 1
print('station_check: %d failures' % fails)
sys.exit(1 if fails else 0)
