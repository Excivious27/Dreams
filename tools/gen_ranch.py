#!/usr/bin/env python3
"""Ranching data (CONDUCT 11a P1): every ranch number lives in the tables below.
    python3 tools/gen_ranch.py [--check]
Writes data/ranch.json (species, buildings, products, rules, processing, legacy, names) and the ranch
product items into data/items.json (gen_stations runs later in tools/regen_data.sh and prices them; the
values here are floors it may lift). Read at runtime by Ranch (scripts/ranch.gd).
Art: species strips come from art/gen/animals/<art>/{idle,walk,eat,baby,sleep}; P6's
art/gen/animals/_ranch_art.json ({species: {anims, variants, baby}}) adds variants when present.
All ages: animals never die, are never slaughtered or sold for meat; a surplus animal is "rehomed" to
a villager's pasture (it lives on). Breeding has no gender checks: any two adults of a species in a home
whose tier has "breeding" (birds: the incubator).
Self-checks (exit 1): ids, art for every species (or a declared fallback), product items, monotonic
building tiers, a home for every species, pen space >= capacity, rehome payout can't loop, banned words.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, 'data')
ART = os.path.join(ROOT, 'art', 'gen')

# ---- species ---------------------------------------------------------------------------------------------
# home: building that houses it; group bird|beast|small|insect; space: pen cells per adult.
# art.variants: [{id, art, weight, rare, product?}] (the first is the common look); baby: strip source.
# height_px / baby_h: drawn height on the 270x480 screen (FarmAnimal scales the idle frame to it).
# product: {id, every_days, needs_mood, extra: [item, chance], dig: outdoors only (pigs), large_at}.
# feed: "hay" (hand, trough, silo feeder or pasture graze) | "forage" (bees: flowers, never hay).
# breed: {days, litter [lo, hi], min_friend, chance, egg (incubated instead of born)}.
SPECIES = {
    'chicken': dict(name='Chicken', name_gang='Hen', home='coop', group='bird', space=1, height_px=14, baby_h=8,
                    voice='cluck', grow_days=7, buy=dict(seller='hazel', price=400, tier=1),
                    art=dict(adult='chicken2', baby=['chicken2', 'baby'], variants=[
                        dict(id='white', art='chicken2', weight=60), dict(id='rooster', art='rooster', weight=25,
                        product='feather'), dict(id='golden', art='chicken2', weight=4, rare=True, tint='#f2c45a')]),
                    product=dict(id='egg', every_days=1, needs_mood=30), feed='hay',
                    breed=dict(egg='egg', days=3, litter=[1, 1], min_friend=0, chance=0.0)),
    'duck': dict(name='Duck', name_gang='Duck', home='coop', group='bird', space=1, height_px=14, baby_h=8,
                 voice='quack', grow_days=7, buy=dict(seller='hazel', price=600, tier=2),
                 art=dict(adult='duck2', baby=['duck2', 'baby'], variants=[dict(id='mallard', art='duck2', weight=90),
                      dict(id='snow', art='duck2', weight=6, rare=True, tint='#e8eef5')]),
                 product=dict(id='duck_egg', every_days=2, needs_mood=30, extra=['feather', 0.25]), feed='hay',
                 breed=dict(egg='duck_egg', days=4, litter=[1, 1], min_friend=0, chance=0.0)),
    'cow': dict(name='Cow', name_gang='Cow', home='barn', group='beast', space=2, height_px=26, baby_h=16,
                voice='moo', grow_days=10, buy=dict(seller='hazel', price=1200, tier=1),
                art=dict(adult='cow_brown', baby=['calf', 'idle'], variants=[dict(id='brown', art='cow_brown', weight=55),
                     dict(id='patched', art='cow_bw', weight=40), dict(id='highland', art='cow_brown', weight=5, rare=True, tint='#c8783c')]),
                product=dict(id='milk', every_days=1, needs_mood=40, large_at=600), feed='hay',
                breed=dict(days=10, litter=[1, 1], min_friend=300, chance=0.35)),
    'sheep': dict(name='Sheep', name_gang='Sheep', home='barn', group='beast', space=2, height_px=20, baby_h=12,
                  voice='baa', grow_days=8, buy=dict(seller='tam', price=900, tier=1),
                  art=dict(adult='sheep_woolly', shorn='sheep', baby=['lamb', 'idle'], variants=[
                      dict(id='white', art='sheep_woolly', weight=92), dict(id='black', art='sheep_woolly', weight=8, rare=True, tint='#4a4450')]),
                  product=dict(id='sheep_wool', every_days=3, needs_mood=40), feed='hay',
                  breed=dict(days=8, litter=[1, 1], min_friend=300, chance=0.35)),
    'goat': dict(name='Goat', name_gang='Goat', home='barn', group='beast', space=2, height_px=20, baby_h=12,
                 voice='bleat', grow_days=8, buy=dict(seller='tam', price=1000, tier=2),
                 art=dict(adult='goat2', baby=['goat_kid', 'idle'], variants=[dict(id='white', art='goat2', weight=60),
                      dict(id='brown', art='goat', weight=35), dict(id='chocolate', art='goat2', weight=5, rare=True, tint='#7a4a30')]),
                 product=dict(id='goat_milk', every_days=2, needs_mood=40), feed='hay',
                 breed=dict(days=7, litter=[1, 2], min_friend=300, chance=0.35)),
    'llama': dict(name='Llama', name_gang='Llama', home='barn', group='beast', space=3, height_px=30, baby_h=16,
                  voice='hum', grow_days=12, buy=dict(seller='tam', price=1800, tier=2),
                  art=dict(adult='llama', baby=['llama_cria', 'idle'], variants=[dict(id='cream', art='llama', weight=60),
                       dict(id='brown', art='llama_b', weight=35), dict(id='white', art='llama', weight=5, rare=True, tint='#f4f0ea')]),
                  product=dict(id='sheep_wool', every_days=3, needs_mood=50, extra=['sheep_wool', 0.5]), feed='hay',
                  breed=dict(days=10, litter=[1, 1], min_friend=400, chance=0.3)),
    'pig': dict(name='Pig', name_gang='Hog', home='sty', group='beast', space=2, height_px=17, baby_h=9,
                voice='oink', grow_days=10, buy=dict(seller='hazel', price=2400, tier=1),
                art=dict(adult='pig_a', baby=['piglet', 'idle'], variants=[dict(id='pink', art='pig_a', weight=60),
                     dict(id='spotted', art='pig_b', weight=35), dict(id='ginger', art='pig_a', weight=5, rare=True, tint='#d0703a')]),
                product=dict(id='truffle', every_days=1, needs_mood=50, dig=True), feed='hay',
                breed=dict(days=6, litter=[1, 3], min_friend=300, chance=0.3)),
    'rabbit': dict(name='Rabbit', name_gang='Rabbit', home='hutch', group='small', space=1, height_px=10, baby_h=6,
                   voice='squeak', grow_days=5, buy=dict(seller='posy', price=700, tier=1),
                   art=dict(adult='rabbit_brown', baby=['rabbit_brown', 'idle'], variants=[dict(id='brown', art='rabbit_brown', weight=55),
                        dict(id='white', art='rabbit_white', weight=40), dict(id='silver', art='rabbit_white', weight=5, rare=True, tint='#b8bcc8')]),
                   product=dict(id='rabbit_fur', every_days=4, needs_mood=40), feed='hay',
                   breed=dict(days=5, litter=[1, 2], min_friend=200, chance=0.3)),
    'bees': dict(name='Bee Hive', name_gang='Hive', home='apiary', group='insect', space=1, height_px=8, baby_h=8,
                 voice='buzz', grow_days=0, buy=dict(seller='posy', price=800, tier=1), pet_word='tend',
                 art=dict(adult='bee_swarm', baby=['bee_swarm', 'idle'], variants=[dict(id='honeybee', art='bee_swarm', weight=100)]),
                 product=dict(id='honey', every_days=3, needs_mood=0, extra=['beeswax', 0.35]), feed='forage',
                 breed=dict(days=7, litter=[1, 1], min_friend=200, chance=0.2)),
}

# Planned v2 rows (exotics, penguin-only moon/merkitty creatures, gangster lab strains): the schema
# carries them now so quests can point at them; they stay unbuyable (buy.price 0) until their art lands.
PLANNED = {
    'chrome_hen': dict(arc='gangsters', name='Chrome Hen', home='coop', source='Robotics Bench chain', product='circuit egg'),
    'moon_hare': dict(arc='penguins', name='Moon Hare', home='hutch', source='Moon pad quest', product='moon fluff'),
    'ostrich': dict(arc='', name='Ostrich', home='barn', source='Sunscorch hub job', product='big egg'),
}

# ---- buildings -------------------------------------------------------------------------------------------
# cap: animals housed; adds: feeder (silo feeds the grown ones each night), incubator (eggs hatch),
# auto_water (+mood), heater (winter mood), breeding (two adults may have a baby). pen: [x, y, w, h]
# cells on the farm (P2 places and may move them; capacity never exceeds pen cells / home space).
BUILDINGS = {
    'coop': [dict(tier=1, cap=4, adds=[], pen=[25, 9, 6, 4]),
             dict(tier=2, cap=8, adds=['feeder', 'incubator'], pen=[25, 9, 6, 4]),
             dict(tier=3, cap=12, adds=['feeder', 'incubator', 'auto_water', 'heater'], pen=[24, 9, 7, 4])],
    'barn': [dict(tier=1, cap=4, adds=[], pen=[31, 6, 4, 3]),
             dict(tier=2, cap=8, adds=['feeder', 'breeding'], pen=[31, 5, 4, 4]),
             dict(tier=3, cap=12, adds=['feeder', 'breeding', 'auto_water', 'heater'], pen=[30, 5, 6, 4])],
    'hutch': [dict(tier=1, cap=4, adds=['breeding'], pen=[20, 9, 3, 2]),
              dict(tier=2, cap=8, adds=['breeding', 'feeder', 'heater'], pen=[20, 9, 4, 2])],
    'sty': [dict(tier=1, cap=2, adds=[], pen=[20, 5, 3, 2]),
            dict(tier=2, cap=4, adds=['breeding', 'feeder'], pen=[20, 5, 4, 2])],
    'apiary': [dict(tier=1, cap=2, adds=[], pen=[16, 5, 2, 1]),
               dict(tier=2, cap=4, adds=['breeding'], pen=[16, 5, 4, 1]),
               dict(tier=3, cap=6, adds=['breeding'], pen=[16, 5, 6, 1])],
}
HOME_SPACE = {'coop': 1, 'barn': 1.5, 'hutch': 0.75, 'sty': 1.5, 'apiary': 1}  # min cells per animal (pen check)

# ---- products (items written into items.json; existing items keep their values) --------------------------
NEW_ITEMS = {
    'feather': dict(name='Feather', type='material', value=30, rarity='common', tier=1, desc='Soft and light. Ducks shed them; roosters too.'),
    'rabbit_fur': dict(name='Rabbit Fur', type='material', value=60, rarity='uncommon', tier=1, sprite='wool',
                       desc='Brushed from a happy rabbit. Rabbits shed it every few days.'),
    'beeswax': dict(name='Beeswax', type='material', value=30, rarity='common', tier=1, sprite='wax', desc='From the hives, now and then, with the honey.'),
}
HAY_DESC = 'Animal feed. Scythe tall grass, grow wheat, bale fiber at the Mill, or buy it from Maple or Tam. A silo keeps it for the feeders.'

# ---- rules -----------------------------------------------------------------------------------------------
RULES = dict(
    friend_max=1000, pet_friend=30, fed_friend=10, missed_pet_friend=-10, unfed_friend=-15,
    silver_at=250, gold_at=700,           # friendship for silver / gold goods (old 5 / 14 day streaks map here)
    mood_fed=45, mood_pet=35, mood_comfort=20, mood_winter_no_heater=5, mood_auto_water=5,
    legacy_streak_friend=50,              # migration: friend = streak x this (5 -> silver, 14 -> gold)
    young_days=7,                         # default grow days when a species gives none
    rehome_share=0.25, rehome_min_age=28, rehome_goods_days=5, # rehome payout: share of the buy price, 0 under this many days old
    rehome_to='Tam\'s high pasture', rehome_to_gang='Tam\'s high pasture',
    incubator_slots=4, rare_base=0.10,    # genetics-lite: 45% one parent, 45% the other, 10% a roll
    hay_buy=8, silo_per_animal=1,
)

# ---- names (all ages, no real people) ---------------------------------------------------------------------
NAMES = {
    'bird': ['Clementine', 'Pip', 'Nugget', 'Hazelnut', 'Penny', 'Biscuit', 'Daisy', 'Pickles', 'Marigold', 'Poppy', 'Butterbean', 'Sprout'],
    'beast': ['Clover', 'Bramble', 'Maple', 'Thistle', 'Buttons', 'Juniper', 'Truffle', 'Bluebell', 'Oakley', 'Mossy', 'Pumpkin', 'Willow'],
    'small': ['Thumper', 'Cotton', 'Mochi', 'Dandelion', 'Pudding', 'Nibbles', 'Fluff', 'Peanut'],
    'insect': ['Golden Hive', 'Sunny Hive', 'Meadow Hive', 'Bramble Hive', 'Clover Hive', 'Honeypot Hive'],
}

# ---- legacy roster (pre-C11 node names -> species, used once by Ranch.migrate) ---------------------------
# [legacy name, species, variant, home, tier needed, baby_of flag (coop_day/barn_day/barn2_day)]
LEGACY = [
    ['chicken2_27_10', 'chicken', 'white', 'coop', 1, ''], ['chicken2_29_10', 'chicken', 'white', 'coop', 1, ''],
    ['rooster_30_11', 'chicken', 'rooster', 'coop', 1, ''], ['chick_28_11', 'chicken', 'white', 'coop', 1, 'coop_day'],
    ['chicken2_26_12', 'chicken', 'white', 'coop', 2, ''], ['chicken2_30_12', 'chicken', 'white', 'coop', 2, ''],
    ['duck2_25_11', 'duck', 'mallard', 'coop', 2, ''], ['duck2_28_12', 'duck', 'mallard', 'coop', 2, ''],
    ['cow_brown_33_7', 'cow', 'brown', 'barn', 1, ''], ['cow_bw_31_8', 'cow', 'patched', 'barn', 1, ''],
    ['sheep_woolly_34_8', 'sheep', 'white', 'barn', 1, ''], ['calf_35_7', 'cow', 'brown', 'barn', 1, 'barn_day'],
    ['lamb_36_7', 'sheep', 'white', 'barn', 1, 'barn_day'],
    ['goat_32_8', 'goat', 'white', 'barn', 2, ''], ['llama_32_6', 'llama', 'cream', 'barn', 2, ''],
    ['goat_kid_33_6', 'goat', 'white', 'barn', 2, 'barn2_day'],
]
LEGACY_MOVED = {'cow_bw_36_8': 'cow_bw_31_8'}  # spawn cells that moved before C11 (keep the higher streak)

# ---- processing (the stations P3 builds; listed here so recipes and quests share one table) --------------
PROCESSING = {
    'egg': ['mayonnaise'], 'duck_egg': ['mayonnaise'], 'milk': ['cheese', 'butter'], 'goat_milk': ['goat_cheese'],
    'sheep_wool': ['yarn'], 'rabbit_fur': ['yarn'], 'honey': ['flower_mead'], 'beeswax': ['candle'], 'truffle': ['truffle_broth'],
}

BANNED = re.compile(r'\b(slaughter|butcher|meat|kill|blood|dies|dead|corpse|carcass)\b', re.I)


def rehome_pay(s, items):
    """A grown animal's rehome thank-you: the smaller of share x buy price and rehome_goods_days of its goods."""
    pv = int(items.get(s['product']['id'], {}).get('value', 0))
    return int(min(RULES['rehome_share'] * int(s['buy']['price']), RULES['rehome_goods_days'] * pv / max(1, s['product']['every_days'])))


def manifest():
    try:
        return json.load(open(os.path.join(ART, 'manifest.json')))
    except Exception:
        return {}


def art_extra():
    p = os.path.join(ART, 'animals', '_ranch_art.json')
    try:
        return json.load(open(p))
    except Exception:
        return {}


def build():
    man = manifest()
    extra = art_extra()
    species = {}
    for sid, s in SPECIES.items():
        row = json.loads(json.dumps(s))
        row.setdefault('arc', '')
        row.setdefault('pet_word', 'pet')
        row['names'] = NAMES[row['group']]
        ex = extra.get(sid, {})
        for v in ex.get('variants', []):   # P6 renders: {id, art, weight, rare}
            if isinstance(v, dict) and v.get('id') and not any(o['id'] == v['id'] for o in row['art']['variants']):
                row['art']['variants'].append(v)
            elif isinstance(v, dict):
                for o in row['art']['variants']:
                    if o['id'] == v.get('id'):
                        o.update({k: v[k] for k in ('art',) if k in v}); o.pop('tint', None)
        if ex.get('baby'):
            row['art']['baby'] = ex['baby'] if isinstance(ex['baby'], list) else [ex['baby'], 'idle']
        if ex.get('anims'):
            row['art']['anims'] = ex['anims']
        species[sid] = row
    products = {}
    for sid, s in species.items():
        ids = [s['product']['id']] + [v['product'] for v in s['art']['variants'] if v.get('product')]
        if s['product'].get('extra'):
            ids.append(s['product']['extra'][0])
        for pid in ids:
            p = products.setdefault(pid, {'species': [], 'home': []})
            if sid not in p['species']:
                p['species'].append(sid)
            if s['home'] not in p['home']:
                p['home'].append(s['home'])
    return dict(species=species, buildings=BUILDINGS, products=products, rules=RULES, processing=PROCESSING,
                legacy=LEGACY, legacy_moved=LEGACY_MOVED, planned=PLANNED), man


def check(data, man, items):
    fails = []
    homes = set(BUILDINGS)
    for sid, s in data['species'].items():
        if s['home'] not in homes:
            fails.append('%s: home %s has no building' % (sid, s['home']))
        for v in s['art']['variants']:
            if 'animals/' + v['art'] not in man or 'idle' not in man.get('animals/' + v['art'], {}):
                fails.append('%s: variant %s art animals/%s has no idle strip' % (sid, v['id'], v['art']))
        b = s['art']['baby']
        if 'animals/' + b[0] not in man or b[1] not in man.get('animals/' + b[0], {}):
            fails.append('%s: baby art animals/%s/%s missing' % (sid, b[0], b[1]))
        if s['product']['id'] not in items:
            fails.append('%s: product %s not in items.json' % (sid, s['product']['id']))
        if s['breed'].get('egg') and s['breed']['egg'] not in items:
            fails.append('%s: egg %s not in items.json' % (sid, s['breed']['egg']))
        bp = int(s['buy']['price'])
        pv = int(items.get(s['product']['id'], {}).get('value', 0))
        # rehome can't be a loop: a newborn pays 0 (min age), a grown one at most share x price, and a whole
        # grow period's goods are worth more than a rehome payout.
        pay = rehome_pay(s, items)
        s['rehome_pay'] = pay
        per_day = pv / max(1, s['product']['every_days'])
        ch = max(0.05, float(s['breed']['chance'] or 0.5))   # birds: one egg a day can go in the incubator
        births = 28.0 / (1.0 / ch + s['breed']['days']) * sum(s['breed']['litter']) / 2.0   # babies a pair makes a season
        if pay > RULES['rehome_share'] * bp or (bp > 0 and births * pay > 2 * 0.5 * 28 * per_day):
            fails.append('%s: rehome payout %d could loop (%.1f births/season, %.0f goods/day)' % (sid, pay, births, per_day))
        for w in [s['name'], s['name_gang']] + s['names']:
            if BANNED.search(w):
                fails.append('%s: banned word in %r' % (sid, w))
    for home, tiers in BUILDINGS.items():
        last = 0
        for t in tiers:
            if t['cap'] <= last:
                fails.append('%s tier %d: cap %d does not grow' % (home, t['tier'], t['cap']))
            last = t['cap']
            cells = t['pen'][2] * t['pen'][3]
            if cells < t['cap'] * HOME_SPACE[home]:
                fails.append('%s tier %d: pen %d cells < cap %d x space %.2f' % (home, t['tier'], cells, t['cap'], HOME_SPACE[home]))
        if not any(s['home'] == home for s in data['species'].values()):
            fails.append('%s houses no species' % home)
    for row in LEGACY:
        if row[1] not in data['species']:
            fails.append('legacy %s: unknown species %s' % (row[0], row[1]))
        elif not any(v['id'] == row[2] for v in data['species'][row[1]]['art']['variants']):
            fails.append('legacy %s: unknown variant %s' % (row[0], row[2]))
    for k, it in NEW_ITEMS.items():
        if BANNED.search(it['desc']):
            fails.append('item %s: banned word' % k)
    for v in RULES.values():
        if isinstance(v, str) and BANNED.search(v):
            fails.append('rules: banned word in %r' % v)
    return fails


def main():
    items_p = os.path.join(D, 'items.json')
    items = json.load(open(items_p))
    for k, it in NEW_ITEMS.items():
        cur = items.get(k, {})
        merged = dict(it)
        merged['value'] = max(int(it['value']), int(cur.get('value', 0)))  # gen_stations may have lifted it
        cur.update(merged)
        items[k] = cur
    if 'hay' in items:
        items['hay']['desc'] = HAY_DESC
    data, man = build()
    for pid in data['products']:
        if pid in items:
            items[pid]['ranch'] = True   # bag sort groups animal goods; econ_check reads the list from ranch.json
    fails = check(data, man, items)
    if fails:
        for f in fails:
            print('FAIL', f)
        print('gen_ranch: %d failures' % len(fails))
        sys.exit(1)
    if '--check' in sys.argv:
        print('gen_ranch: check ok')
        return
    json.dump(items, open(items_p, 'w'), indent=1, ensure_ascii=False)
    json.dump(data, open(os.path.join(D, 'ranch.json'), 'w'), indent=1, ensure_ascii=False)
    print('gen_ranch: %d species, %d buildings, %d products' % (len(data['species']), len(BUILDINGS), len(data['products'])))


if __name__ == '__main__':
    main()
