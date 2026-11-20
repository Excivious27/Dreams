#!/usr/bin/env python3
"""Decor + wardrobe catalogue (CONDUCT 10a P1). Pure data + self-checks, like gen_rec/gen_collections.
    python3 tools/gen_decor.py [--report]
Writes
  data/decor.json   {rarity, cats, items, sets, shops, pools, recipes, comfort, house_reserved, legacy}
                    (scripts/decor.gd reads only this file)
  data/items.json   dc_* (decor/wallpaper/flooring, type 'decor') and wr_* (wearables, type 'wear') entries,
                    merged in place; stale dc_/wr_ ids are removed; rp_* (gen_rec) are never touched, they
                    appear in decor.json as external entries ('ext': true).
  docs/DECOR-ART.md coverage table per category/sub (existing vs target) for the art packages.
Sources of entries:
  1. reuse pool: art/gen/furniture (named pieces, never kits/), props (neon, jukebox, arcade, statues),
     items icons (tabletop pieces), tiles fl_*/wl_* + seamless floor_* (flooring/wallpaper),
     items apparel icons + hats + the six drawn costumes (wearables)
  2. P6 renders: every entry of art/gen/decor/_catalog.json [{id, name, cat, rarity, arc, layer, size, rot, glow, set}]
Rules (asserted below, the run fails otherwise):
  - every art/icon ref exists in art/gen/manifest.json (or art/gen/decor/<id>.png for P6 renders); none under kits/
  - names unique and <= 26 chars; ids dc_/wr_ + [a-z0-9_]
  - items.json never gets arc 'both' (absent = both arcs; c10_01-09)
  - price bands per rarity (RARITY table); sell value = SELL_SHARE x price (flat, no perks: Decor.sell)
  - unique: price 0, value 0, exactly one non-repeatable source, never in a shop/pool/recipe
  - mythic: never in a shop or a recipe (loot/boss/set only)
  - every pool and shop id exists and is in-arc for at least one arc; pools hold no uniques
  - all-ages words (no drink/drug words; gang_flavour banned words stay out of both-arc names)
"""
import json, os, re, sys, math, zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, 'data')
M = json.load(open(os.path.join(ROOT, 'art', 'gen', 'manifest.json')))
I = json.load(open(os.path.join(D, 'items.json')))
DECOR_DIR = os.environ.get('DECOR_ART_ROOT', os.path.join(ROOT, 'art', 'gen', 'decor'))   # P6 renders (env: tests)
CAT_PATH = os.path.join(DECOR_DIR, '_catalog.json')

# ---- rarity: the one table (Decor.RARITIES mirrors the ids; colours are CVD-safe, c10_07) --------------
# band = shop price range; weight = loot weight; comfort = house comfort points; dots = rank dots drawn
RARITY = [
    {'id': 'common',    'rank': 0, 'col': [0.82, 0.82, 0.82], 'glyph': '',  'label': 'Common',    'band': [60, 400],      'weight': 600, 'comfort': 1},
    {'id': 'uncommon',  'rank': 1, 'col': [0.25, 0.75, 0.45], 'glyph': '',  'label': 'Uncommon',  'band': [300, 1200],    'weight': 260, 'comfort': 2},
    {'id': 'rare',      'rank': 2, 'col': [0.30, 0.50, 1.00], 'glyph': '',  'label': 'Rare',      'band': [900, 4000],    'weight': 100, 'comfort': 3},
    {'id': 'epic',      'rank': 3, 'col': [0.90, 0.30, 0.65], 'glyph': '',  'label': 'Epic',      'band': [3000, 12000],  'weight': 30,  'comfort': 5},
    {'id': 'legendary', 'rank': 4, 'col': [1.00, 0.80, 0.25], 'glyph': '',  'label': 'Legendary', 'band': [10000, 40000], 'weight': 8,   'comfort': 8},
    {'id': 'mythic',    'rank': 5, 'col': [1.00, 0.35, 0.35], 'glyph': '★', 'label': 'Mythic',    'band': [30000, 120000], 'weight': 2,  'comfort': 12},
    {'id': 'unique',    'rank': 6, 'col': [0.40, 1.00, 0.95], 'glyph': '◆', 'label': 'One of a kind', 'band': [0, 0],      'weight': 0,   'comfort': 15},
]
RK = {r['id']: r for r in RARITY}
SET_PAY, SET_PAY_MIN, SET_PAY_CAP = 0.12, 200, 6000   # set claim money: 12% of the pieces' shelf total, 200-6000
SELL_SHARE = 0.15      # sell-back = 15% of the shop price (c10_12: 10-25%), flat: no perks, no demand
REORDER_FEE = 0.10     # re-order from the catalogue after selling: +10% (min 50)
REORDER_MIN = 10        # c10b_10_10: a flat 10% (min 10), not +45% on a common
PRICE_TIER_W = 0.30     # price_for: share of the band position set by tier (rest = per-id spread)
PITY = 8               # Decor.roll: after 8 rolls on a pool without a rare+, the next one is rare+
LUCK_STEP = 0.04       # weight x (1 + LUCK_STEP x rank x luck_eff), luck_eff = 10 x (1 - e^(-luck/8)) (c10_07)
CATS = ['furniture', 'wall_art', 'decor', 'light', 'rug', 'wallpaper', 'flooring', 'outdoor', 'exterior', 'hat', 'top', 'bottom', 'outfit', 'acc', 'shoes']
WEAR_CATS = {'hat', 'top', 'bottom', 'outfit', 'acc', 'shoes'}
TIER_PRICE = {1: 0.0, 2: 0.25, 3: 0.5, 4: 0.75, 5: 1.0}   # where in the rarity band a tier sits

ENTRIES = {}
NAMES = {}
DRINK_P6 = re.compile(r'(?i)\b(wine|ale|rum|beer|whisk(e)?y|vodka|gin|brandy|liquor|booze|cocktail|drug|weed|pill)\b')
ITEM_NAMES = {v.get('name') for k, v in I.items() if not k.startswith(('dc_', 'wr_', 'rp_'))}


def art_ok(ref):
    if '/' not in ref:
        return False
    g, n = ref.rsplit('/', 1)
    if g.startswith('kits'):
        return False
    if g == 'decor':
        return os.path.exists(os.path.join(DECOR_DIR, n + '.png'))
    return n in M.get(g, {})


def size_of(ref):
    g, n = ref.rsplit('/', 1)
    inf = M.get(g, {}).get(n, {})
    return int(inf.get('cell_w', inf.get('w', 32))), int(inf.get('cell_h', inf.get('h', 32)))


def fp_for(ref, layer):
    w, h = size_of(ref)
    cw = max(1, min(4, int(round(w / 32.0))))
    if layer in ('wall', 'window'):
        return [cw, 1]
    if layer == 'under':
        return [max(1, min(4, cw)), max(1, min(3, int(round(h / 40.0))))]
    rows = 2 if (w >= 56 and h >= 64) else 1
    return [cw, rows]


def price_for(rarity, tier, salt=0):
    lo, hi = RK[rarity]['band']
    if hi == 0:
        return 0
    t = TIER_PRICE.get(tier, 0.5)
    h = (salt * 2654435761 % 1000) / 1000.0   # per-id spread (c10b_10_07: no four-price ladder)
    f = 0.04 + 0.92 * (PRICE_TIER_W * t + (1.0 - PRICE_TIER_W) * h)
    p = lo * (hi / float(lo)) ** f             # geometric inside the band: cheap pieces stay cheap
    step = 5 if p < 1000 else (50 if p < 10000 else 500)
    return int(round(p / step) * step)


def add(id, name, cat, rarity, art, layer='floor', tier=1, arc='both', sub='', sources=None, glow=False,
        icon=None, rot=1, sets=None, surface=False, desc='', renders='', costume='', fp=None, ext=False, price=None,
        sell=None, name_gang='', season='', anim=0):
    assert re.match(r'^(dc|wr|rp)_[a-z0-9_]+$', id), id
    assert id not in ENTRIES, 'duplicate id ' + id
    assert cat in CATS, (id, cat)
    if name in ITEM_NAMES:  # never share a name with a non-decor item (gear, goods): cosmetics say "(Look)"
        name = name + (' (Look)' if cat in WEAR_CATS else ' Ornament')
    if name in NAMES:
        raise SystemExit('duplicate decor name %r (%s, %s)' % (name, id, NAMES[name]))
    NAMES[name] = id
    if price is None:
        price = price_for(rarity, tier, zlib.crc32(id.encode()))
    if sell is None:
        sell = int(round(price * SELL_SHARE))
    e = {'name': name, 'cat': cat, 'sub': sub or cat, 'rarity': rarity, 'tier': tier, 'arc': arc,
         'layer': layer, 'size': fp or (fp_for(art, layer) if layer != 'wear' and '/' in art else [1, 1]),
         'rot': rot, 'glow': bool(glow), 'art': art, 'icon': icon or art, 'price': price, 'sell': sell,
         'sources': sources or [], 'set': (sets or [''])[0], 'sets': sets or [], 'comfort': RK[rarity]['comfort']}
    if surface: e['surface'] = True
    if renders: e['renders'] = renders
    if costume: e['costume'] = costume
    if ext: e['ext'] = True
    if name_gang: e['name_gang'] = name_gang
    if season: e['season'] = season
    if anim: e['anim'] = anim
    e['desc'] = desc or default_desc(e)
    ENTRIES[id] = e
    return e


def default_desc(e):
    c = e['cat']
    return {'furniture': 'Furniture for your house.', 'wall_art': 'Hangs on a wall.', 'decor': 'A little something for a shelf or table.',
            'light': 'Lights up a room at night.' if e['glow'] else 'A lamp for your house.', 'rug': 'Lies flat on the floor.',
            'wallpaper': 'Wallpaper for one room.', 'flooring': 'Flooring for one room.',
            'outdoor': 'A piece for the yard outside.', 'exterior': 'Restyles your farmhouse.',
            'hat': 'A hat. Looks only, no stats.', 'top': 'A top. Looks only, no stats.', 'bottom': 'Looks only, no stats.',
            'outfit': 'A full outfit. Looks only, no stats.', 'acc': 'An accessory. Looks only, no stats.',
            'shoes': 'Shoes. Looks only, no stats.'}[c]


# ---- 1) furniture reuse pool --------------------------------------------------------------------------
# Shop/workplace pieces that don't belong in a home (registers, pews, museum cases, forge...).
SKIP = re.compile(r'^(int_|wall_|walltop_|wl_|door|stairs|counter|register|teller|pew|museum|forge|anvil|bellows|feed_|trough|'
                  r'crate|bread_|flour|grain_|hopper|millstones|mill_|quench|oil_|keg_|beer_|meat_|fish_|crab|bait|floats|net_|rod_|'
                  r'price_tag|shop_bell|stalls|time_clock|hard_hats|dynamite|trap_|skin_bench|tack_|saddle|crook|hay_|wool_|cot_|'
                  r'hospital|eye_chart|doctor|medicine|portrait_mayor|council|mayor|spouse_|cellar_|closed_flag|open_flag|score_|ball_|pin_statue|'
                  r'lamp_mech|lamp_mechanism|coins_|coin_tray|ledger|logbook|card_catalogue|slates|stacked_tablets|rubbing_|alphabet|school_bell|'
                  r'teacher|podium|lectern|altar|specimen|seed_rack|shelf_seeds|shelf_cans|shelf_dry|shoe_counter|snack_|ore_case|'
                  r'mouse_hole|apple_tub|cider|bakery|prep_table|kitchen$|kitchen_corner|cake_case|life_ring|fog_bell|rope_posts|wheel_axle|'
                  r'cauldron|bubbling|oil_still|frog_jar|sieve|mortar|mill|scale|herb_bundles|trash|chest_|chest2|window_boarded|win_|stained_|'
                  r'notice_board|wl_|stool_fleece|bunk_log|bedroll|blanket2|charts_hammock|blueprint|map_table|grand_desk|study_desk|'
                  r'reading_table|toy_chest|bow_rack|weapon_rack|tool_rack|potion_shelf|rec_poster|skeleton_poster|lamp$|kettle_stove)')
# (regex, cat, sub, layer, rarity, tier, glow)
RULES = [
    (r'^sofa_velvet', 'furniture', 'seating', 'floor', 'epic', 4, False),
    (r'^sofa', 'furniture', 'seating', 'floor', 'uncommon', 2, False),
    (r'^armchair_window', 'furniture', 'seating', 'floor', 'rare', 3, False),
    (r'^armchair', 'furniture', 'seating', 'floor', 'common', 1, False),
    (r'^(chair|stool)', 'furniture', 'seating', 'floor', 'common', 1, False),
    (r'^bed_double|^bed2_double', 'furniture', 'bed', 'floor', 'rare', 3, False),
    (r'^(bed|bunk_bed|cradle)', 'furniture', 'bed', 'floor', 'uncommon', 2, False),
    (r'^(cat_bed|dog_bed|pet_bed)', 'furniture', 'pet', 'floor', 'common', 1, False),
    (r'^(table_round_cloth|table_square_cloth|table_long_cloth|round_set)', 'furniture', 'table', 'floor', 'uncommon', 2, False),
    (r'^(table|low_table|nightstand|desk)', 'furniture', 'table', 'floor', 'common', 1, False),
    (r'^(bookcase3|bookshelf_ivy)', 'furniture', 'storage', 'floor', 'rare', 3, False),
    (r'^(bookcase|bookshelf|shelf_|dresser|wardrobe|filing|chest)', 'furniture', 'storage', 'floor', 'common', 1, False),
    (r'^(kitchen_|fridge|sink|stove_iron|kettle|coffee_pot|hanging_mugs|jug)', 'furniture', 'kitchen', 'floor', 'common', 1, False),
    (r'^(bathtub|toilet)', 'furniture', 'bath', 'floor', 'uncommon', 2, False),
    (r'^fireplace_anim', 'furniture', 'fireplace', 'floor', 'legendary', 5, True),
    (r'^(fireplace|hearth|fire_pit)', 'furniture', 'fireplace', 'floor', 'rare', 3, True),
    (r'^chandelier', 'light', 'light', 'floor', 'epic', 4, True),
    (r'^(lamp_|lantern|candle)', 'light', 'light', 'floor', 'common', 1, True),
    (r'^(plant|ivy_pot|cattail_pot|flower_jug)', 'decor', 'plant', 'floor', 'common', 1, False),
    (r'^(clock_grand|clock_tall)', 'furniture', 'clock', 'floor', 'rare', 3, False),
    (r'^wall_clock|^clock$', 'wall_art', 'clock', 'wall', 'uncommon', 2, False),
    (r'^(painting2)', 'wall_art', 'painting', 'wall', 'rare', 3, False),
    (r'^(painting|poster_frame|mirror|flag_|antler_hooks|coat_hooks|chalkboard)', 'wall_art', 'painting', 'wall', 'uncommon', 2, False),
    (r'^(curtain)', 'wall_art', 'window', 'window', 'common', 1, False),
    (r'^(window)', 'wall_art', 'window', 'window', 'uncommon', 2, False),
    (r'^(rug2_round|rug_round|round_rug)', 'rug', 'rug', 'under', 'uncommon', 2, False),
    (r'^(rug|reed_mat)', 'rug', 'rug', 'under', 'common', 1, False),
    (r'^pelt', 'rug', 'rug', 'under', 'rare', 3, False),
    (r'^(piano|organ)', 'furniture', 'music', 'floor', 'epic', 4, False),
    (r'^(radio|tv_on|tv_off)', 'furniture', 'tech', 'floor', 'rare', 3, False),
    (r'^(globe|telescope|easel|crystal_ball|crystal_cage|library_ladder|spiral_stair|ink_brushes|books_scrolls)', 'decor', 'study', 'floor', 'rare', 3, False),
    (r'^(safe|vault_closed|vault_open)', 'furniture', 'storage', 'floor', 'epic', 4, False),
    (r'^(trophy_case|trophy_shelf|candle_stand|barrel|barrels3)', 'furniture', 'storage', 'floor', 'uncommon', 2, False),
]
COLOURS = ['blue', 'green', 'red', 'yellow', 'velvet', 'purple', 'white', 'black', 'gold', 'rose', 'round', 'double', 'long4', 'long8', 'long', 'square', 'cloth', 'runner', 'rect']
SERIES = {'': 'Cottage', '2': 'Country', '3': 'Manor'}
VARIANT = {'a': 'Oak', 'b': 'Pine', 'c': 'Walnut', 'd': 'Birch', 'e': 'Cedar', 'f': 'Maple'}
NOUN = {'armchair': 'Armchair', 'sofa': 'Sofa', 'chair': 'Chair', 'stool': 'Stool', 'bed': 'Bed', 'bunk': 'Bunk Bed', 'table': 'Table',
        'bookcase': 'Bookcase', 'bookshelf': 'Bookshelf', 'dresser': 'Dresser', 'wardrobe': 'Wardrobe', 'nightstand': 'Nightstand',
        'desk': 'Desk', 'lamp': 'Lamp', 'lantern': 'Lantern', 'plant': 'Potted Plant', 'painting': 'Painting', 'rug': 'Rug', 'curtain': 'Curtains',
        'mirror': 'Mirror', 'clock': 'Clock', 'window': 'Window'}
PRETTY = {'bed_double': 'Double Bed', 'bed2_double_blue': 'Blue Quilt Double Bed', 'bed2_double_red': 'Red Quilt Double Bed',
          'bed_double_green': 'Green Double Bed', 'bed_single': 'Single Bed', 'bunk_bed': 'Bunk Bed', 'cradle': 'Cradle',
          'fireplace_anim': 'Roaring Hearth', 'fireplace': 'Stone Fireplace', 'fireplace2': 'Brick Fireplace', 'fireplace2_unlit': 'Cold Brick Fireplace',
          'hearth': 'Old Hearth', 'fire_pit2': 'Indoor Fire Bowl', 'chandelier': 'Crystal Chandelier', 'piano': 'Upright Piano', 'organ': 'Pipe Organ',
          'radio': 'Valve Radio', 'tv_on': 'Television', 'tv_off': 'Retro TV Set', 'globe': 'Desk Globe', 'globe2': 'Floor Globe', 'globe3': 'Brass Globe',
          'telescope2': 'Brass Telescope', 'easel2': 'Painter\'s Easel', 'crystal_ball': 'Crystal Ball', 'crystal_cage': 'Crystal Cage',
          'library_ladder': 'Library Ladder', 'spiral_stair': 'Spiral Stair', 'ink_brushes': 'Ink and Brushes', 'books_scrolls': 'Books and Scrolls',
          'safe': 'Iron Safe', 'vault_closed': 'Vault Door', 'vault_open': 'Open Vault Door', 'trophy_case': 'Trophy Case', 'trophy_shelf': 'Trophy Shelf',
          'candle_stand': 'Candelabra', 'barrel': 'Barrel', 'barrels3': 'Barrel Stack', 'clock_grand': 'Grandfather Clock', 'clock_grand2': 'Grand Clock',
          'clock_tall': 'Tall Clock', 'wall_clock': 'Wall Clock', 'clock': 'Mantel Clock', 'bathtub': 'Bathtub', 'toilet': 'Toilet', 'sink': 'Wash Basin',
          'fridge': 'Icebox', 'kitchen_fridge': 'Kitchen Icebox', 'kitchen_sink': 'Kitchen Sink', 'kitchen_stove': 'Kitchen Stove', 'stove_iron': 'Iron Stove',
          'kitchen_counter_a': 'Kitchen Counter', 'kitchen_counter_b': 'Kitchen Cupboard', 'kettle': 'Kettle', 'kettle_stand': 'Kettle Stand',
          'coffee_pot': 'Coffee Pot', 'coffee_pot_a': 'Tall Coffee Pot', 'hanging_mugs': 'Mug Rack', 'jug': 'Water Jug', 'cat_bed': 'Cat Bed',
          'dog_bed': 'Dog Bed', 'pet_bed': 'Pet Cushion', 'low_table': 'Low Table', 'pelt_bear': 'Bear Pelt Rug', 'pelt_leopard': 'Spotted Pelt Rug',
          'pelt_wolf': 'Wolf Pelt Rug', 'reed_mat_a': 'Reed Mat', 'reed_mat_b': 'Woven Reed Mat', 'reed_mat_round': 'Round Reed Mat',
          'round_rug_stone': 'Stone-Ring Rug', 'antler_hooks': 'Antler Hooks', 'coat_hooks': 'Coat Hooks', 'chalkboard': 'Chalkboard',
          'poster_frame': 'Framed Poster', 'flag_a': 'Pennant Flag', 'flag_b': 'Banner Flag', 'mirror': 'Round Mirror', 'mirror2': 'Tall Mirror',
          'ivy_pot': 'Ivy Pot', 'cattail_pot': 'Cattail Pot', 'flower_jug': 'Flower Jug', 'filing_cabinet': 'Filing Cabinet',
          'armchair_window': 'Window Seat', 'sofa_velvet': 'Velvet Sofa', 'lamp_floor': 'Floor Lamp', 'lamp_floor_b': 'Tall Floor Lamp',
          'lamp_table_a': 'Table Lamp', 'lamp_table_b': 'Shaded Table Lamp', 'lantern2': 'Iron Lantern', 'lantern3': 'Brass Lantern', 'lantern4': 'Paper Lantern',
          'shelf_books': 'Book Shelf', 'shelf_empty': 'Plain Shelf', 'shelf_house': 'House Shelf', 'shelf_jars': 'Jar Shelf', 'shelf_misc': 'Odds Shelf',
          'bookshelf_ivy': 'Ivy Bookcase', 'curtain_open': 'Lace Curtains', 'curtain_closed': 'Drawn Lace Curtains', 'window_day': 'Cottage Window',
          'window_night': 'Night Window', 'window_rain': 'Rainy Window', 'window2_day_a': 'Tall Window', 'window2_day_b': 'Wide Window',
          'window2_night_a': 'Tall Night Window', 'window2_night_b': 'Wide Night Window', 'window': 'Small Window', 'stool_wood': 'Wood Stool',
          'chair_down': 'Kitchen Chair', 'chair_up': 'Kitchen Chair (back)', 'table': 'Kitchen Table', 'rug_red': 'Great Red Rug', 'rug2_runner': 'Hall Runner',
          'table2_long4': 'Dining Table', 'table2_long8': 'Banquet Table', 'table2_round': 'Round Dining Table', 'dresser': 'Dresser'}


def auto_name(n):
    if n in PRETTY:
        return PRETTY[n]
    m = re.match(r'^([a-z]+?)(2|3)?(?:_(.*))?$', n)
    base, ser, rest = m.group(1), m.group(2) or '', m.group(3) or ''
    words = []
    for p in rest.split('_') if rest else []:
        if p in VARIANT:
            words.append(VARIANT[p])
        elif p in ('down', 'up', 'left', 'right'):
            words.append({'down': '', 'up': '(back)', 'left': '(left)', 'right': '(right)'}[p])
        else:
            words.append(p.capitalize())
    noun = NOUN.get(base, base.capitalize())
    lead = [w for w in words if w and not w.startswith('(')]
    tail = [w for w in words if w.startswith('(')]
    if base == 'curtain':
        drawn = 'Closed' in lead
        lead = [w for w in lead if w not in ('Open', 'Closed')]
        return ' '.join((['Drawn'] if drawn else []) + lead + ['Curtains']).strip()
    if base == 'plant':
        lead = [{'Oak': 'Fern', 'Pine': 'Palm', 'Walnut': 'Ivy', 'Birch': 'Cactus', 'Cedar': 'Fig', 'Maple': 'Lily'}.get(w, w) for w in lead]
        noun = 'Pot' if lead else 'Potted Plant'
    out = ' '.join([SERIES[ser]] + lead + [noun] + tail).replace('  ', ' ').strip()
    return out if len(out) <= 26 else ' '.join(lead + [noun] + tail).strip()


FURN = M['furniture']
for n in sorted(FURN):
    if SKIP.match(n):
        continue
    for rx, cat, sub, layer, rar, tier, glow in RULES:
        if re.match(rx, n):
            break
    else:
        continue
    name = auto_name(n)
    if name in NAMES:
        name = name + ' II'
    inf = FURN[n]
    add('dc_' + n, name, cat, rar, 'furniture/' + n, layer, tier, sub=sub, glow=glow, anim=int(inf.get('frames', 0)),
        rot=(4 if re.match(r'^chair2_[ab]_down$', n) else 1))
# The 4-view chairs: only the down view is a catalogue entry (rot 4 = _down/_left/_up/_right siblings).
for n in list(ENTRIES):
    if re.match(r'^dc_chair2_[ab]_(left|right|up)$', n):
        NAMES.pop(ENTRIES[n]['name']); ENTRIES.pop(n)
for k in ('dc_chair2_a_down', 'dc_chair2_b_down'):
    if k in ENTRIES:
        ENTRIES[k]['rot'] = 4
        ENTRIES[k]['rot_art'] = [ENTRIES[k]['art'].replace('_down', s) for s in ('_down', '_right', '_up', '_left')]

# The farmhouse's movable starting furniture (house.gd STARTERS, seeded by art furniture/<name>) keeps the
# footprint it had as fixed furniture (extra_w + 1 wide; the rug lies under, 4x2) so seeding never collides.
STARTER_FP = {'lamp_floor': [1, 1], 'bookshelf': [1, 1], 'table_round_cloth': [2, 1], 'chair_down': [1, 1], 'plant2_a': [1, 1],
              'plant_a': [1, 1], 'rug_rect_red': [4, 2], 'shelf_jars': [2, 1], 'barrel': [1, 1], 'plant2_b': [1, 1],
              'bookcase3_a': [1, 1], 'lamp_floor_b': [1, 1], 'plant2_c': [1, 1]}
for n, fp in STARTER_FP.items():
    e = ENTRIES.get('dc_' + n)
    assert e and e['art'] == 'furniture/' + n, 'starter furniture missing from the catalogue: ' + n
    e['size'] = fp
    if n.startswith('rug'):
        e['layer'] = 'under'

# ---- 2) props (gangster + whimsy pieces that live indoors) --------------------------------------------
PROPS = [  # art, name, cat, sub, layer, rarity, tier, arc, glow, name_gang
    ('neon_sign_0', 'Neon Sign: Moon', 'light', 'neon', 'wall', 'rare', 2, 'gangsters', True),
    ('neon_sign_1', 'Neon Sign: Star', 'light', 'neon', 'wall', 'rare', 2, 'gangsters', True),
    ('neon_sign_2', 'Neon Sign: Heart', 'light', 'neon', 'wall', 'rare', 3, 'gangsters', True),
    ('neon_sign_3', 'Neon Sign: Bolt', 'light', 'neon', 'wall', 'rare', 3, 'gangsters', True),
    ('neon_sign_4', 'Neon Sign: Diamond', 'light', 'neon', 'wall', 'epic', 3, 'gangsters', True),
    ('neon_sign_5', 'Neon Sign: Crown', 'light', 'neon', 'wall', 'epic', 4, 'gangsters', True),
    ('neon_sign_6', 'Neon Sign: Ace', 'light', 'neon', 'wall', 'epic', 4, 'gangsters', True),
    ('neon_sign_7', 'Neon Sign: Skyline', 'light', 'neon', 'wall', 'legendary', 5, 'gangsters', True),
    ('rec_neon_0', 'Neon Bowling Pin', 'light', 'neon', 'wall', 'uncommon', 2, 'both', True),
    ('rec_neon_1', 'Neon Strike Sign', 'light', 'neon', 'wall', 'rare', 3, 'both', True),
    ('rec_neon_2', 'Neon Joystick', 'light', 'neon', 'wall', 'rare', 3, 'both', True),
    ('rec_neon_3', 'Neon Ticket Sign', 'light', 'neon', 'wall', 'uncommon', 2, 'both', True),
    ('jukebox_a', 'Chrome Jukebox', 'furniture', 'music', 'floor', 'epic', 4, 'gangsters', True),
    ('jukebox_b', 'Diner Jukebox', 'furniture', 'music', 'floor', 'legendary', 5, 'both', True),
    ('arcade_cab_0', 'Arcade Cabinet: Red', 'furniture', 'tech', 'floor', 'epic', 3, 'both', True),
    ('arcade_cab_1', 'Arcade Cabinet: Blue', 'furniture', 'tech', 'floor', 'epic', 3, 'both', True),
    ('arcade_cab_2', 'Arcade Cabinet: Gold', 'furniture', 'tech', 'floor', 'legendary', 4, 'both', True),
    ('arcade_cab_3', 'Arcade Cabinet: Green', 'furniture', 'tech', 'floor', 'epic', 4, 'both', True),
    ('arcade_cab_4', 'Arcade Cabinet: Violet', 'furniture', 'tech', 'floor', 'epic', 4, 'both', True),
    ('arcade_cab_5', 'Arcade Cabinet: Night', 'furniture', 'tech', 'floor', 'legendary', 5, 'gangsters', True),
    ('rec_pinball_a', 'Pinball Table', 'furniture', 'tech', 'floor', 'epic', 4, 'both', True),
    ('rec_pinball_b', 'Galaxy Pinball', 'furniture', 'tech', 'floor', 'legendary', 5, 'both', True),
    ('cat_statue', 'Cat Statue', 'decor', 'statue', 'floor', 'rare', 3, 'penguins', False),
    ('alien_statue', 'Moon Visitor Statue', 'decor', 'statue', 'floor', 'mythic', 5, 'both', False),
    ('statue2_crystal', 'Crystal Statue', 'decor', 'statue', 'floor', 'legendary', 5, 'penguins', False),
    ('lamp_tall_a', 'Street Lamp (indoor)', 'light', 'light', 'floor', 'uncommon', 2, 'gangsters', True),
    ('lamp_arm_a', 'Arm Lamp', 'light', 'light', 'floor', 'uncommon', 2, 'both', True),
    ('city_planter', 'City Planter', 'decor', 'plant', 'floor', 'common', 1, 'gangsters', False),
    ('carnivore_plant', 'Snapjaw Plant', 'decor', 'plant', 'floor', 'epic', 4, 'both', False),
    ('bulb_plant', 'Glowbulb Plant', 'decor', 'plant', 'floor', 'rare', 3, 'both', True),
]
for a, name, cat, sub, layer, rar, tier, arc, glow in PROPS:
    if a in M['props']:
        add('dc_' + a, name, cat, rar, 'props/' + a, layer, tier, arc, sub=sub, glow=glow)

# ---- 3) tabletop pieces from item icons (layer floor, surface: may sit on a table) ---------------------
TABLETOP = [  # icon, name, rarity, tier, arc
    ('vase', 'Glazed Vase', 'common', 1, 'both'), ('cat_figurine', 'Cat Figurine', 'uncommon', 2, 'penguins'),
    ('penguin_figurine', 'Penguin Figurine', 'uncommon', 2, 'penguins'), ('snow_globe', 'Snow Globe', 'rare', 2, 'both'),
    ('teddy_bear', 'Teddy Bear', 'common', 1, 'both'), ('statue_head', 'Marble Bust', 'rare', 3, 'both'),
    ('candle', 'Candle', 'common', 1, 'both'), ('candle_tall', 'Tall Candle', 'common', 1, 'both'),
    ('pot_a', 'Clay Jar', 'common', 1, 'both'), ('pot_b', 'Painted Jar', 'common', 1, 'both'), ('pot_c', 'Urn', 'uncommon', 2, 'both'),
    ('snowman', 'Tiny Snowman', 'uncommon', 2, 'penguins'), ('wisp_bottle', 'Wisp in a Bottle', 'epic', 4, 'both'),
    ('bottled_wind', 'Bottled Breeze', 'rare', 3, 'both'), ('echo_shell', 'Echo Shell', 'rare', 3, 'both'),
    ('fossil_shell', 'Fossil Shell', 'uncommon', 2, 'both'), ('trophy_fish_a', 'Fishing Cup', 'rare', 3, 'both'),
    ('trophy_farm_a', 'Harvest Cup', 'rare', 3, 'both'), ('trophy_craft_a', 'Maker\'s Cup', 'rare', 3, 'both'),
    ('trophy_crystal', 'Crystal Cup', 'epic', 4, 'both'), ('medal_bronze', 'Bronze Medal Frame', 'uncommon', 2, 'both'),
    ('medal_silver', 'Silver Medal Frame', 'rare', 3, 'both'), ('lantern_moon', 'Moon Lantern', 'epic', 4, 'both'),
    ('lantern_crystal', 'Crystal Lantern', 'rare', 3, 'penguins'), ('lantern_red', 'Red Paper Lantern', 'common', 1, 'both'),
    ('lantern_gold', 'Gold Lantern', 'epic', 4, 'gangsters'), ('lantern_copper', 'Copper Lantern', 'uncommon', 2, 'both'),
    ('pumpkin_lantern', 'Pumpkin Lantern', 'uncommon', 2, 'both'), ('wisp_lantern', 'Wisp Lantern', 'legendary', 5, 'both'),
    ('first_dollar', 'Framed First Dollar', 'rare', 2, 'gangsters'), ('bottle_cap', 'Bottle-Cap Jar', 'common', 1, 'gangsters'),
    ('snow_heart', 'Snow Heart', 'rare', 3, 'penguins'), ('painting_landscape', 'Landscape Canvas', 'uncommon', 2, 'both'),
    ('painting_portrait', 'Portrait Canvas', 'uncommon', 2, 'both'),
]
for icon, name, rar, tier, arc in TABLETOP:
    if icon in M['items']:
        glow = 'lantern' in icon or 'candle' in icon or 'wisp' in icon
        add('dc_tt_' + icon, name, 'light' if glow else ('wall_art' if icon.startswith('painting') else 'decor'), rar,
            'items/' + icon, 'wall' if icon.startswith('painting') else 'floor', tier, arc,
            sub='tabletop', glow=glow, surface=not icon.startswith('painting'), fp=[1, 1])

# ---- 4) wallpaper and flooring ------------------------------------------------------------------------
WALL_NAMES = {'floral': 'Rose Floral', 'floral_blue': 'Blue Floral', 'brick': 'Red Brick', 'library': 'Library Panel', 'bakery': 'Bakery Cream',
              'clinic': 'Clinic Mint', 'chalk': 'Schoolhouse', 'curve': 'Arched Plaster', 'fish': 'Seaside Boards', 'hut': 'Hut Wattle',
              'concrete': 'Bare Concrete', 'log': 'Log Cabin', 'marble': 'Marble Hall', 'mill': 'Mill Boards', 'plaster': 'Plain Plaster',
              'reed': 'Woven Reed', 'timber': 'Timber Frame', 'wood': 'Wood Panel'}
WALL_GANG = {'brick', 'concrete', 'marble'}
tiles = M['tiles']
styles = sorted({re.sub(r'_(l|m|m2|m3|r|r2|corner|door|window|window_day)$', '', n)[3:] for n in tiles if n.startswith('wl_')})
for s in styles:
    if not all(('wl_%s_%s' % (s, p)) in tiles for p in ('l', 'r')) or not any(('wl_%s_%s' % (s, p)) in tiles for p in ('m', 'm2', 'm3')):
        continue
    nm = WALL_NAMES.get(s, s.replace('_', ' ').title()) + ' Wallpaper'
    rar = 'rare' if s in ('marble', 'library') else ('uncommon' if s in ('floral_blue', 'curve', 'timber', 'brick') else 'common')
    add('dc_wall_' + s, nm, 'wallpaper', rar, 'tiles/wl_' + s + '_l', 'wall', 1 if rar == 'common' else (2 if rar == 'uncommon' else 3),
        'gangsters' if s == 'concrete' else 'both', sub='wallpaper', fp=[1, 1])
    ENTRIES['dc_wall_' + s]['style'] = 'wl_' + s
FLOOR_NAMES = {'wood': 'Honey Plank', 'wood_dark': 'Dark Plank', 'wood_light': 'Light Plank', 'plank': 'Barn Plank', 'grey_plank': 'Grey Plank',
               'moss_plank': 'Mossy Plank', 'hut_plank': 'Hut Plank', 'parquet': 'Parquet', 'marble': 'Marble', 'tile': 'White Tile',
               'carpet_blue': 'Blue Carpet', 'carpet_green': 'Green Carpet', 'carpet_purple': 'Purple Carpet', 'carpet_red': 'Red Carpet',
               'brick': 'Brick', 'cobble': 'Cobble', 'stone': 'Flagstone', 'round_stone': 'River Stone', 'concrete': 'Concrete', 'inn': 'Inn Boards',
               'bakery': 'Bakery Tile', 'clinic': 'Clinic Tile', 'grate': 'Steel Grate', 'quarry': 'Quarry Stone', 'camp': 'Camp Boards'}
for s in sorted({re.sub(r'_\d+$', '', n)[3:] for n in tiles if n.startswith('fl_')}):
    if s not in FLOOR_NAMES:
        continue
    rar = 'rare' if s in ('marble', 'parquet') else ('uncommon' if s.startswith('carpet') or s in ('tile', 'wood_dark') else 'common')
    first = sorted(n for n in tiles if re.match(r'^fl_%s(_\d+)?$' % s, n))[0]
    add('dc_floor_' + s, FLOOR_NAMES[s] + ' Floor', 'flooring', rar, 'tiles/' + first, 'under', 1 if rar == 'common' else (2 if rar == 'uncommon' else 3),
        'gangsters' if s in ('grate', 'concrete') else 'both', sub='flooring', fp=[1, 1])
    ENTRIES['dc_floor_' + s]['style'] = 'fl_' + s
SEAM_NAMES = {'floor_carpet': 'Plush Carpet', 'floor_checker': 'Checker Tile', 'floor_dark': 'Ebony Board', 'floor_light': 'Ash Board',
              'floor_oak': 'Oak Board', 'floor_stone_tiles': 'Stone Tile', 'floor_terracotta': 'Terracotta', 'floor_worn': 'Worn Board',
              'floor_flagstone': 'Garden Flagstone', 'brick_herring': 'Herringbone Brick'}
for s, nm in SEAM_NAMES.items():
    if s in M.get('seamless', {}):
        rar = 'rare' if s in ('floor_checker', 'brick_herring') else 'uncommon'
        add('dc_floor_' + s.replace('floor_', 's_'), nm + ' Floor', 'flooring', rar, 'seamless/' + s, 'under', 2 if rar == 'uncommon' else 3,
            'gangsters' if s == 'floor_checker' else 'both', sub='flooring', fp=[1, 1])
        ENTRIES['dc_floor_' + s.replace('floor_', 's_')]['style'] = 'seamless/' + s

# ---- 5) wearables (cosmetic: no stats ever; renders: doll = drawn on the paper-doll hero, icon = badge only)
HAT_DOLL = {h: 'hats/' + h for h in M.get('hats', {})}
HAT_DOLL.update({h: 'hats_poses/' + h for h in ('fedora', 'shades', 'snow_goggles', 'aurora_hood')})
WEAR = [  # id, name, cat, icon, rarity, tier, arc, doll art (or '')
    ('straw', 'Sun Straw Hat', 'hat', 'items/straw_hat', 'common', 1, 'both'),
    ('cowboy', 'Ranch Hat', 'hat', 'items/cowboy_hat', 'uncommon', 1, 'both'),
    ('beanie', 'Knit Beanie', 'hat', 'items/beanie', 'common', 1, 'both'),
    ('bandana', 'Bandana', 'hat', 'items/bandana', 'common', 1, 'both'),
    ('cap', 'Ball Cap', 'hat', 'items/cap', 'common', 1, 'both'),
    ('flatcap', 'Flat Cap', 'hat', 'items/flatcap', 'uncommon', 2, 'gangsters'),
    ('tophat', 'Silk Top Hat', 'hat', 'items/top_hat', 'rare', 3, 'both'),
    ('witch', 'Wizard Hat', 'hat', 'items/wizard_hat', 'rare', 3, 'penguins'),
    ('flower_crown', 'Flower Crown', 'hat', 'items/flower_crown', 'uncommon', 2, 'both'),
    ('crystal_crown', 'Crystal Tiara', 'hat', 'items/crystal_crown', 'epic', 4, 'penguins'),
    ('goggles', 'Tinker Goggles', 'hat', 'items/goggles', 'uncommon', 2, 'both'),
    ('hood', 'Traveller Hood', 'hat', 'items/hood', 'common', 1, 'both'),
    ('earmuffs', 'Earmuffs', 'hat', 'items/penguin_hat', 'common', 1, 'penguins'),
    ('kerchief', 'Kerchief', 'hat', 'items/bandana_drop', 'common', 1, 'both'),
    ('halo', 'Star Halo', 'hat', 'items/token_crown', 'mythic', 5, 'both'),
    ('fedora', 'Pinstripe Fedora', 'hat', 'items/merchant_hat', 'rare', 2, 'gangsters'),
    ('shades', 'Night Shades', 'acc', 'items/shades', 'uncommon', 2, 'gangsters'),
    ('snow_goggles', 'Snow Goggles', 'acc', 'items/snow_goggles', 'uncommon', 2, 'penguins'),
    ('aurora_hood', 'Aurora Hood', 'hat', 'items/aurora_hood', 'legendary', 5, 'penguins'),
]
for wid, name, cat, icon, rar, tier, arc in WEAR:
    if not art_ok(icon):
        continue
    doll = HAT_DOLL.get(wid, '')
    add('wr_' + wid, name, cat, rar, doll or icon, 'wear', tier, arc, icon=icon, renders='doll' if doll else 'icon', fp=[1, 1])
COSTUMES = [  # costume key (portraits/hero_outfit_<k> + PaperDoll outfit), name, rarity, tier, arc
    ('pinstripe', 'Pinstripe Suit', 'rare', 2, 'gangsters'), ('vest', 'Padded Vest', 'uncommon', 2, 'gangsters'),
    ('armored', 'Armored Suit', 'epic', 4, 'gangsters'), ('parka', 'Puffy Parka', 'uncommon', 2, 'penguins'),
    ('crystal_parka', 'Crystal Parka', 'epic', 4, 'penguins'), ('starlight', 'Starlight Mantle', 'legendary', 5, 'both'),
    ('farmer', 'Farmhand Overalls', 'common', 1, 'both'), ('fisher', 'Angler Outfit', 'common', 1, 'both'),
    ('forester', 'Forester Outfit', 'common', 1, 'both'), ('merchant', 'Merchant Coat', 'uncommon', 2, 'both'),
    ('miner', 'Miner Outfit', 'common', 1, 'both'), ('scholar', 'Scholar Robe', 'uncommon', 2, 'both'),
    ('neon', 'Neon Street Outfit', 'rare', 3, 'gangsters'), ('penguin', 'Snowfolk Outfit', 'rare', 3, 'penguins'),
]
for k, name, rar, tier, arc in COSTUMES:
    art = 'portraits/hero_outfit_' + k + '/neutral'
    if art_ok(art):
        add('wr_outfit_' + k, name, 'outfit', rar, art, 'wear', tier, arc, renders='doll' if ('outfit_' + k) in M.get('body', {}) else 'icon',
            costume=('outfit_' + k) if ('outfit_' + k) in M.get('body', {}) else '', fp=[1, 1])
# Icon-only wearables (shown as a badge on the Hero tab; the drawn heroes show nothing: honestly labelled)
SETS8 = ['farmer', 'fisher', 'forester', 'merchant', 'miner', 'scholar', 'neon', 'penguin']
SET_ARC = {'neon': 'gangsters', 'penguin': 'penguins'}
for s in SETS8:
    for part, cat, word in (('scarf', 'acc', 'Scarf'), ('gloves', 'acc', 'Gloves'), ('shoes', 'shoes', 'Shoes')):
        for v, suf in (('', ''), ('_b', ' II')):
            icon = 'items/%s_%s%s' % (s, part, v)
            if art_ok(icon):
                nm = '%s %s%s' % ({'neon': 'Neon', 'penguin': 'Snowfolk'}.get(s, s.capitalize()), word, suf)
                add('wr_%s_%s%s' % (s, part, v), nm, cat, 'uncommon' if v else 'common', icon, 'wear', 2 if v else 1,
                    SET_ARC.get(s, 'both'), renders='icon', fp=[1, 1], sets=['wear_' + s])
for c in ['black', 'blue', 'green', 'red', 'white', 'gold', 'paw', 'penguin', 'star', 'moon', 'cloud', 'storm', 'frost', 'ember', 'dream', 'crystal']:
    icon = 'items/cape_' + c
    if art_ok(icon):
        rar = {'star': 'epic', 'moon': 'epic', 'dream': 'legendary', 'crystal': 'epic', 'gold': 'rare', 'storm': 'rare', 'frost': 'rare', 'ember': 'rare'}.get(c, 'uncommon')
        arc = {'penguin': 'penguins', 'paw': 'penguins', 'crystal': 'penguins'}.get(c, 'both')
        add('wr_cape_' + c, c.capitalize() + ' Cape', 'acc', rar, icon, 'wear', RK[rar]['rank'] + 1, arc, renders='icon', fp=[1, 1])
for c in ['black', 'blue', 'cyan', 'green', 'purple', 'red', 'white', 'yellow']:
    icon = 'items/scarf_' + c
    if art_ok(icon):
        add('wr_scarf_' + c, c.capitalize() + ' Knit Scarf', 'acc', 'common', icon, 'wear', 1, renders='icon', fp=[1, 1])
for icon, name, cat, rar, tier, arc in [('hoodie', 'Hoodie', 'top', 'common', 1, 'both'), ('jacket', 'Bomber Jacket', 'top', 'uncommon', 2, 'gangsters'),
                                        ('sweater', 'Cosy Sweater', 'top', 'common', 1, 'both'), ('lab_coat', 'Lab Coat', 'top', 'uncommon', 2, 'gangsters'),
                                        ('dress', 'Sun Dress', 'top', 'uncommon', 2, 'both'), ('overalls', 'Denim Overalls', 'bottom', 'common', 1, 'both'),
                                        ('jacket_patch', 'Patched Jacket', 'top', 'rare', 3, 'gangsters'), ('mask', 'Masquerade Mask', 'acc', 'rare', 3, 'both'),
                                        ('dancing_shoes', 'Dancing Shoes', 'shoes', 'rare', 3, 'both'), ('rain_boots', 'Rain Boots', 'shoes', 'common', 1, 'both'),
                                        ('hiking_boots', 'Hiking Boots', 'shoes', 'uncommon', 2, 'both'), ('snow_boots', 'Fur Snow Boots', 'shoes', 'uncommon', 2, 'penguins'),
                                        ('necklace_a', 'Bead Necklace', 'acc', 'common', 1, 'both'), ('necklace_b', 'Pendant Necklace', 'acc', 'uncommon', 2, 'both'),
                                        ('flower_crown_a', 'Daisy Crown', 'hat', 'common', 1, 'both'), ('flower_crown_b', 'Rose Crown', 'hat', 'uncommon', 2, 'both'),
                                        ('cloak', 'Wanderer Cloak', 'acc', 'uncommon', 2, 'both'), ('commander_cape', 'Commander Cape', 'acc', 'legendary', 5, 'gangsters'),
                                        ('grump_king_crown', 'Grump King Crown', 'hat', 'unique', 5, 'penguins'),
                                        ('golem_crown', 'Golem Crown', 'hat', 'mythic', 5, 'both'),
                                        ('president_crown', 'Smuggler King Crown', 'hat', 'unique', 5, 'gangsters')]:
    if art_ok('items/' + icon):
        src = [{'kind': 'quest', 'ref': {'grump_king_crown': 'commander', 'president_crown': 'tower'}[icon], 'once': True}] if rar == 'unique' else None
        add('wr_' + icon, name, cat, rar, 'items/' + icon, 'wear', tier, arc, renders='icon', fp=[1, 1], sources=src)

# ---- 6) external entries: Rec prize decor already in items.json (gen_rec owns those items) --------------
REC_ART = {'rp_arcade_cab': 'props/arcade_cab_0', 'rp_jukebox': 'props/jukebox_b'}
for rid, it in sorted(I.items()):
    if rid.startswith('rp_') and it.get('type') == 'decor':
        icon = 'items/' + str(it.get('icon', rid))
        art = REC_ART.get(rid, icon)
        add(rid, it['name'], 'decor' if 'trophy' in rid or 'medal' in rid or 'pin' in rid or 'music_box' in rid else ('wall_art' if 'painting' in rid else 'furniture'),
            it.get('rarity', 'uncommon'), art, 'wall' if 'painting' in rid else 'floor', int(it.get('tier', 2)), icon=icon,
            sub='prize', sources=[{'kind': 'prize', 'ref': 'rec'}], ext=True, price=0, sell=int(it.get('value', 0)),
            glow=rid in ('rp_jukebox', 'rp_arcade_cab'), surface='trophy' in rid or 'medal' in rid or rid in ('rp_music_box', 'rp_golden_pin'), fp=[1, 1])

# ---- 7) unique showpieces (one per game; exactly one source each, owned by P4/P3 hooks) ----------------
UNIQUES = [  # id, name, art, cat, layer, arc, source kind, ref
    # c10b_06_01/c10b_07/c10b_04_19: every ref is a grant key that really fires (region boss win, pocket chest, main quest)
    ('dc_u_aurum_statue', 'Golden Aurum Statue', 'props/gc_aurum_statue', 'decor', 'floor', 'gangsters', 'boss', 'gilt_vaults'),
    ('dc_u_vault_door', 'Gilt Vault Door', 'props/gc_vault_door', 'furniture', 'floor', 'gangsters', 'chest', 'hidden_chest_gilt_vaults'),
    ('dc_u_horse_statue', 'Bronze Horse Statue', 'props/statue2_horse', 'decor', 'floor', 'penguins', 'quest', 'finale'),
    ('dc_u_golden_fountain', 'Little Gold Fountain', 'props/gold_fountain', 'furniture', 'floor', 'both', 'set', 'set_master'),
    ('dc_u_lighthouse_lamp', 'Lighthouse Lens', 'props/lighthouse_lamp', 'light', 'floor', 'both', 'secret', 'lighthouse_lit'),
]
for uid, name, art, cat, layer, arc, kind, ref in UNIQUES:
    if art_ok(art):
        add(uid, name, cat, 'unique', art, layer, 5, arc, sub='showpiece', sources=[{'kind': kind, 'ref': ref, 'once': True}],
            glow=cat == 'light', fp=[2, 2] if cat != 'light' else [1, 1], desc='One of a kind. There is only one in the whole valley.')

# ---- 7b) Collections keepsakes (P3's collections.gd gives these; ids fixed by P3) ---------------------
COLL = [  # id, name, art, cat, layer, rarity, source ref
    ('dc_museum_trophy', 'Museum Trophy', 'props/museum_trophy', 'decor', 'floor', 'rare', 'museum_trophy'),
    ('dc_mineral_display', 'Mineral Display', 'props/mineral_display', 'decor', 'floor', 'rare', 'mineral_display'),
    ('dc_relic_shelf', 'Relic Shelf', 'props/relic_shelf', 'furniture', 'floor', 'epic', 'relic_shelf'),
    ('dc_curio_jar', 'Curio Jar', 'props/curio_jar', 'decor', 'floor', 'uncommon', 'curio_jar'),
    ('dc_fish_trophy', 'Fish Trophy', 'props/fish_trophy', 'wall_art', 'wall', 'rare', 'fish_trophy'),
    ('dc_shipper_ribbon', 'Shipper Ribbon', 'props/shipper_ribbon', 'wall_art', 'wall', 'uncommon', 'shipper_ribbon'),
    ('dc_koi_scroll', 'Koi Scroll', 'items/painting_landscape', 'wall_art', 'wall', 'legendary', 'legendary_koi'),
    ('dc_golden_rod_mount', 'Golden Rod Mount', 'furniture/rod_a', 'wall_art', 'wall', 'epic', 'fish_all'),
    ('dc_master_hearth', 'Master Hearth', 'furniture/fireplace2', 'furniture', 'floor', 'epic', 'cook_all'),
    ('dc_golden_crate', 'Golden Crate', 'furniture/crate', 'decor', 'floor', 'epic', 'ship_150'),
    ('dc_collectors_shelf', 'Collector\'s Shelf', 'furniture/trophy_shelf', 'furniture', 'floor', 'rare', 'decor_50'),
    ('dc_grand_catalogue_stand', 'Grand Catalogue Stand', 'furniture/lectern', 'furniture', 'floor', 'legendary', 'decor_200'),
]
for cid, name, art, cat, layer, rar, ref in COLL:
    if art_ok(art):
        add(cid, name, cat, rar, art, layer, 4 if rar in ('epic', 'legendary') else 3, sub='keepsake',
            sources=[{'kind': 'collection', 'ref': ref, 'once': True}], fp=[1, 1], price=0, sell=0,
            desc='A keepsake from the museum and your collections.')
        ENTRIES[cid]['order'] = False
if art_ok('furniture/globe3'):
    add('dc_founders_orrery', 'Founder\'s Orrery', 'decor', 'unique', 'furniture/globe3', 'floor', 5, sub='showpiece',
        sources=[{'kind': 'collection', 'ref': 'mus_all', 'once': True}], fp=[1, 1],
        desc='One of a kind. The founders charted the valley sky with it.')


# ---- 7c) outdoor / yard decor (C10b P1, c10b_02/03): existing world props promoted, zero new renders ----
# Layer "outdoor": placed on the farm/yards by DecorMode (P2). "scale" = the draw scale of the art (the world
# draws these props at hand scales; c10b_03), "size" = footprint in cells from w*scale/16. "season" = a
# festival/seasonal set (stall:festival_<season> sells them in season). P6 renders with layer "outdoor" merge below.
OUTDOOR = [  # art, name, sub, rarity, tier, arc, glow, scale, season, name_gang
    ('props/lamp2_tall_0', 'Garden Lamp Post', 'lamp', 'common', 1, 'both', True, 0.3, '', 'Street Lamp Post'),
    ('props/lamp2_tall_1', 'Twin Garden Lamp', 'lamp', 'uncommon', 2, 'both', True, 0.3, '', 'Twin Street Lamp'),
    ('props/lamp2_tall_2', 'Ornate Lamp Post', 'lamp', 'rare', 3, 'both', True, 0.3, '', ''),
    ('props/lamp2_short_0', 'Short Path Lamp', 'lamp', 'common', 1, 'both', True, 0.35, '', ''),
    ('props/lamp2_short_1', 'Bollard Lamp', 'lamp', 'common', 1, 'both', True, 0.35, '', ''),
    ('props/lamp2_short_2', 'Lantern Bollard', 'lamp', 'uncommon', 2, 'both', True, 0.35, '', ''),
    ('props/lantern_lit', 'Yard Lantern', 'lamp', 'common', 1, 'both', True, 0.5, '', ''),
    ('props/ri_lantern_post', 'Rustic Lantern Post', 'lamp', 'common', 1, 'both', True, 0.5, '', ''),
    ('props/dock_lantern', 'Harbour Lantern', 'lamp', 'rare', 3, 'both', True, 0.3, '', ''),
    ('props/lanterns_red', 'Red Paper Lanterns', 'lamp', 'uncommon', 2, 'both', True, 0.4, 'spring', ''),
    ('props/lanterns_pink', 'Pink Paper Lanterns', 'lamp', 'uncommon', 2, 'both', True, 0.4, 'spring', ''),
    ('props/lanterns_cyan', 'Teal Paper Lanterns', 'lamp', 'uncommon', 2, 'both', True, 0.4, 'summer', ''),
    ('props/planter2_0', 'Terracotta Planter', 'planter', 'common', 1, 'both', False, 0.32, '', ''),
    ('props/planter2_1', 'Stone Planter', 'planter', 'common', 1, 'both', False, 0.32, '', ''),
    ('props/planter2_2', 'Flower Urn', 'planter', 'uncommon', 2, 'both', False, 0.32, '', ''),
    ('props/planter2_3', 'Herb Trough', 'planter', 'uncommon', 2, 'both', False, 0.32, 'summer', ''),
    ('props/city_planter', 'Street Planter', 'planter', 'common', 1, 'gangsters', False, 0.5, '', ''),
    ('props/hedge2_pot', 'Potted Hedge', 'planter', 'uncommon', 2, 'both', False, 0.35, '', ''),
    ('props/flower_cart', 'Flower Cart', 'planter', 'epic', 4, 'both', False, 0.35, 'summer', ''),
    ('props/flowerbed_blue', 'Bluebell Bed', 'flowerbed', 'common', 1, 'both', False, 0.5, 'spring', ''),
    ('props/flowerbed_pink', 'Pink Tulip Bed', 'flowerbed', 'common', 1, 'both', False, 0.5, 'spring', ''),
    ('props/flowerbed_red', 'Red Poppy Bed', 'flowerbed', 'common', 1, 'both', False, 0.5, 'summer', ''),
    ('props/flowerbed_yellow', 'Marigold Bed', 'flowerbed', 'common', 1, 'both', False, 0.5, 'summer', ''),
    ('nature/sunflowers', 'Sunflower Patch', 'flowerbed', 'common', 1, 'both', False, 0.5, 'summer', ''),
    ('nature/sunflower_bush', 'Sunflower Clump', 'flowerbed', 'uncommon', 2, 'both', False, 0.5, 'summer', ''),
    ('nature/fairy_ring', 'Fairy Ring', 'flowerbed', 'rare', 3, 'penguins', False, 0.5, 'fall', ''),
    ('props/hedge2_ball', 'Round Hedge', 'hedge', 'common', 1, 'both', False, 0.35, '', ''),
    ('props/hedge2_tree_s', 'Clipped Hedge Tree', 'hedge', 'uncommon', 2, 'both', False, 0.35, '', ''),
    ('props/hedge2_tree', 'Tall Hedge Tree', 'hedge', 'uncommon', 2, 'both', False, 0.35, '', ''),
    ('props/topiary_a', 'Spiral Topiary', 'hedge', 'uncommon', 2, 'both', False, 0.5, '', ''),
    ('props/topiary_b', 'Cone Topiary', 'hedge', 'common', 1, 'both', False, 0.5, '', ''),
    ('props/topiary_c', 'Ball Topiary', 'hedge', 'common', 1, 'both', False, 0.5, '', ''),
    ('props/hedge2_arch', 'Hedge Arch', 'arch', 'rare', 3, 'both', False, 0.35, '', ''),
    ('props/statue', 'Garden Statue', 'statue', 'uncommon', 2, 'both', False, 0.5, '', ''),
    ('props/statue_cane', 'Gentleman Statue', 'statue', 'uncommon', 2, 'both', False, 0.5, '', 'Boss Statue'),
    ('props/cat_statue', 'Stone Cat Statue', 'statue', 'rare', 3, 'both', False, 0.35, '', ''),
    ('props/alien_statue', 'Star Visitor Statue', 'statue', 'epic', 4, 'both', False, 0.3, '', ''),
    ('props/ds_sun_obelisk', 'Sun Obelisk', 'statue', 'epic', 4, 'both', False, 0.3, '', ''),
    ('props/fountain', 'Garden Fountain', 'fountain', 'epic', 4, 'both', False, 0.5, '', ''),
    ('props/fountain2', 'Grand Fountain', 'fountain', 'legendary', 5, 'both', False, 0.35, '', ''),
    ('props/glow_pond', 'Glow Pond', 'fountain', 'rare', 3, 'both', True, 0.35, '', ''),
    ('props/birdbath', 'Stone Birdbath', 'fountain', 'common', 1, 'both', False, 0.5, '', ''),
    ('props/well_stone', 'Wishing Well', 'fountain', 'uncommon', 2, 'both', False, 0.5, '', ''),
    ('props/well_roofed', 'Roofed Well', 'fountain', 'uncommon', 2, 'both', False, 0.5, '', ''),
    ('props/bench2_wood_a', 'Park Bench', 'bench', 'common', 1, 'both', False, 0.35, '', ''),
    ('props/bench2_iron_a', 'Iron Park Bench', 'bench', 'uncommon', 2, 'both', False, 0.35, '', ''),
    ('props/bench2_green_a', 'Green Park Bench', 'bench', 'common', 1, 'both', False, 0.35, '', ''),
    ('nature/log_bench', 'Log Seat', 'bench', 'common', 1, 'both', False, 0.5, '', ''),
    ('props/cf_picnic_table', 'Picnic Table', 'bench', 'uncommon', 2, 'both', False, 0.35, 'summer', ''),
    ('props/umbrella_red', 'Red Sun Umbrella', 'bench', 'common', 1, 'both', False, 0.4, 'summer', ''),
    ('props/umbrella_blue', 'Blue Sun Umbrella', 'bench', 'common', 1, 'both', False, 0.4, 'summer', ''),
    ('props/umbrella_yellow', 'Yellow Sun Umbrella', 'bench', 'common', 1, 'both', False, 0.4, 'summer', ''),
    ('props/trellis', 'Rose Trellis', 'arch', 'uncommon', 2, 'both', False, 0.35, 'spring', ''),
    ('props/wedding_arch', 'Flower Arch', 'arch', 'rare', 3, 'both', False, 0.4, 'spring', ''),
    ('props/stone_arch', 'Stone Garden Arch', 'arch', 'rare', 3, 'both', False, 0.35, '', ''),
    ('props/fence2_wood_h', 'Wood Fence Run', 'fence', 'common', 1, 'both', False, 0.5, '', ''),
    ('props/fence2_iron_h', 'Iron Fence Run', 'fence', 'uncommon', 2, 'both', False, 0.5, '', ''),
    ('props/fence2_stone_h', 'Stone Wall Run', 'fence', 'uncommon', 2, 'both', False, 0.5, '', ''),
    ('props/rope_fence', 'Rope Fence', 'fence', 'common', 1, 'both', False, 0.5, '', ''),
    ('props/gold_fence_a', 'Gilded Fence', 'fence', 'epic', 4, 'both', False, 0.5, '', ''),
    ('props/chain_fence_h', 'Chain-Link Fence', 'fence', 'common', 1, 'gangsters', False, 0.5, '', ''),
    ('props/scarecrow_knight', 'Knight Scarecrow', 'garden', 'uncommon', 2, 'both', False, 0.5, '', ''),
    ('props/scarecrow_pumpkin', 'Pumpkin Scarecrow', 'garden', 'uncommon', 2, 'both', False, 0.5, 'fall', ''),
    ('props/ri_windmill_small', 'Garden Windmill', 'garden', 'uncommon', 2, 'both', False, 0.5, '', ''),
    ('props/haystack', 'Hay Bale Stack', 'garden', 'common', 1, 'both', False, 0.5, 'fall', ''),
    ('props/bee_house', 'Bee Hotel', 'garden', 'uncommon', 2, 'both', False, 0.35, '', ''),
    ('props/signpost_1', 'Garden Signpost', 'garden', 'common', 1, 'both', False, 0.5, '', ''),
    ('props/signpost_2', 'Tall Signpost', 'garden', 'common', 1, 'both', False, 0.5, '', ''),
    ('props/fest_fw_00', 'Harvest Pumpkin Pile', 'seasonal', 'uncommon', 2, 'both', False, 0.25, 'fall', ''),
    ('props/fest_fw_01', 'Pumpkin Patch Display', 'seasonal', 'uncommon', 2, 'both', False, 0.25, 'fall', ''),
    ('props/fest_fw_38', 'Yard Snowman', 'seasonal', 'uncommon', 2, 'both', False, 0.3, 'winter', ''),
    ('props/fest_fw_41', 'Ice Sculpture', 'seasonal', 'rare', 3, 'both', False, 0.25, 'winter', ''),
    ('props/fest_fw_62', 'Festive Pine', 'seasonal', 'rare', 3, 'both', True, 0.2, 'winter', ''),
    ('props/fest_ss_02', 'Maypole', 'seasonal', 'rare', 3, 'both', False, 0.25, 'spring', ''),
    ('props/fest_ss_09', 'Egg Basket Display', 'seasonal', 'uncommon', 2, 'both', False, 0.25, 'spring', ''),
    ('props/fest_ss_22', 'Lantern Garland', 'seasonal', 'uncommon', 2, 'both', True, 0.3, 'summer', ''),
    ('props/fest_ss_31', 'String Lights', 'seasonal', 'uncommon', 2, 'both', True, 0.25, 'summer', ''),
    ('props/lux_car_red', 'Red Coupe', 'yard_gang', 'epic', 4, 'gangsters', False, 0.75, '', ''),
    ('props/taxi', 'Retired Cab', 'yard_gang', 'rare', 3, 'gangsters', False, 0.75, '', ''),
    ('props/rusted_car', 'Project Car', 'yard_gang', 'uncommon', 2, 'gangsters', False, 0.6, '', ''),
    ('props/oil_drums', 'Oil Drum Stack', 'yard_gang', 'common', 1, 'gangsters', False, 0.5, '', ''),
    ('props/crates_pallet', 'Pallet of Crates', 'yard_gang', 'common', 1, 'gangsters', False, 0.5, '', ''),
]


def outdoor_fp(art, scale):
    w, h = size_of(art)
    cw = max(1, min(4, int(round(w * scale / 16.0))))
    rows = max(1, min(3, int(round(h * scale / 16.0 * 0.35))))  # the base, not the full height (sprites stand up)
    return [cw, rows]


for art, name, sub, rar, tier, arc, glow, scale, season, ngang in OUTDOOR:
    if not art_ok(art):
        continue
    oid = 'dc_out_' + art.split('/', 1)[1]
    e = add(oid, name, 'outdoor', rar, art, 'outdoor', tier, arc, sub=sub, glow=glow, fp=outdoor_fp(art, scale),
            name_gang=ngang, season=season, anim=int(M[art.split('/')[0]][art.split('/')[1]].get('frames', 0) or 0) if int(M[art.split('/')[0]][art.split('/')[1]].get('frames', 0) or 0) > 1 else 0)
    e['scale'] = scale
    e['desc'] = {'lamp': 'A light for the yard. Glows at night.', 'planter': 'A planter for the yard.', 'flowerbed': 'Flowers for the yard.',
                 'hedge': 'Clipped greenery for the yard.', 'statue': 'A statue for the yard.', 'fountain': 'Water for the yard.',
                 'bench': 'Somewhere to sit outside.', 'arch': 'An arch to walk under.', 'fence': 'A fence piece. Lay them in a row.',
                 'garden': 'A touch of the farm life.', 'seasonal': 'A seasonal piece for the yard.', 'yard_gang': 'Street-style yard dressing.'}[sub]

# ---- 7d) house exterior parts (C10b P3 contract): art/gen/house_parts/_catalog.json entries -----------
# Each entry: {"id": "ext_<part>_<style>", "part": siding|roof|door|window|trim|chimney|porch|fence|mailbox,
# "style": str, "name": str, "rarity", "tier", "arc", "icon": "<file in house_parts>"}. Written as cat
# "exterior", layer "exterior", entry key "part" (never "ext": that flag already means external rp_ prizes).
# The applied parts live in run.decor.exterior {part: id} (Decor.st(); Decor.total counts them).
HP_DIR = os.path.join(ROOT, 'art', 'gen', 'house_parts')
HP_CAT = os.path.join(HP_DIR, '_catalog.json')
EXT_PARTS = ('siding', 'roof', 'door', 'window', 'trim', 'chimney', 'porch', 'fence', 'mailbox')
EXT_WARN = []
for c in (json.load(open(HP_CAT)) if os.path.exists(HP_CAT) else []):
    try:
        xid = str(c['id'])
        if not re.match(r'^ext_[a-z0-9_]+$', xid) or c.get('part') not in EXT_PARTS:
            EXT_WARN.append('%s: bad id/part' % xid); continue
        icon = 'house_parts/' + str(c.get('icon', xid))
        if not os.path.exists(os.path.join(HP_DIR, icon.split('/', 1)[1] + '.png')):
            EXT_WARN.append('%s: no icon %s' % (xid, icon)); continue
        rar = c.get('rarity', 'common') if c.get('rarity', 'common') in RK and c.get('rarity') != 'unique' else 'common'
        e = add('dc_' + xid, str(c.get('name', xid))[:26], 'exterior', rar, icon, 'exterior', int(c.get('tier', 1 + min(4, RK[rar]['rank']))),
                c.get('arc', 'both') or 'both', sub=c['part'], fp=[1, 1], desc='Restyles your farmhouse: the %s.' % c['part'])
        e['part'] = c['part']
        e['style'] = str(c.get('style', xid))
        e['ext_id'] = xid
    except (KeyError, ValueError, TypeError, SystemExit) as ex:
        EXT_WARN.append('%s: %s' % (c, ex))
for w in EXT_WARN:
    print('WARN ext', w)

# ---- 8) P6 renders: art/gen/decor/_catalog.json merged as-is (names/rarities from c10_01/c10_09) -------
p6 = json.load(open(os.environ.get('DECOR_CATALOG', CAT_PATH))) if os.path.exists(os.environ.get('DECOR_CATALOG', CAT_PATH)) else []
P6_WARN = []   # a bad render entry is skipped with a warning (never breaks regen_data at merge time)
GANG_WORD = re.compile(r'(?i)penguin|crystal|casino|gambl|cigar')
P6_LAYER = {'floor': 'floor', 'top': 'floor', 'flat': 'under', 'wall': 'wall', 'window': 'window', 'flooring': 'under', 'wallpaper': 'wall', 'under': 'under', 'outdoor': 'outdoor', 'yard': 'outdoor'}
for c in p6:
    try:
        cid = c['id'] if c['id'].startswith(('dc_', 'wr_')) else (('wr_' if c.get('cat') in WEAR_CATS else 'dc_') + c['id'])
        if cid in ENTRIES or not re.match(r'^(dc|wr)_[a-z0-9_]+$', cid):
            P6_WARN.append('%s: duplicate or bad id' % c.get('id')); continue
        raw = c['id']
        art = 'decor/' + raw
        icon = 'decor/' + str(c['icon']) if c.get('icon') and art_ok('decor/' + str(c['icon'])) else art
        if not art_ok(art):
            P6_WARN.append('%s: no art/gen/decor/%s.png' % (cid, raw)); continue
        rar = c.get('rarity', 'common') if c.get('rarity', 'common') in RK else 'common'
        arc = c.get('arc', 'both') or 'both'
        cat = c.get('cat', 'decor') if c.get('cat', 'decor') in CATS else 'decor'
        nm = str(c.get('name', raw.replace('_', ' ').title()))
        if len(nm) > 26:
            nm = nm[:26].rsplit(' ', 1)[0]
        if arc == 'gangsters' and GANG_WORD.search(nm) or DRINK_P6.search(nm):
            P6_WARN.append('%s: name %r has an arc/all-ages word' % (cid, nm)); continue
        if nm in NAMES or nm in ITEM_NAMES:
            nm = (nm[:23] + ' II') if (nm[:23] + ' II') not in NAMES else nm[:22] + ' III'
        src = None
        if rar == 'unique':  # one source each; P3/P4 hand it out (listed in the report)
            src = [c['source']] if isinstance(c.get('source'), dict) else [{'kind': 'collection', 'ref': 'decor_' + raw, 'once': True}]
        layer = P6_LAYER.get(str(c.get('layer', 'floor')), 'floor')
        tier = int(c.get('tier', 1 + min(4, RK[rar]['rank'])))
        e = add(cid, nm, cat, rar, art, layer, tier, arc, sub=c.get('sub', cat if cat not in ('furniture',) else str(c.get('set') or cat)),
                glow=bool(c.get('glow')), icon=icon, rot=int(c.get('rot', 1)), sets=[c['set']] if c.get('set') else None,
                fp=[max(1, min(4, int(v))) for v in (c.get('size') or [1, 1])][:2], renders=c.get('renders', 'icon' if cat in WEAR_CATS else ''),
                anim=int(c.get('frames', 0)) if int(c.get('frames', 0)) > 1 else 0, sources=src, surface=c.get('layer') == 'top')
        if int(c.get('glow') or 0) > 1:
            e['glow_r'] = int(c['glow'])
        if c.get('fps'):
            e['fps'] = int(c['fps'])
        if c.get('colourway_of'):
            e['colourway_of'] = str(c['colourway_of'])
        if cat in ('wallpaper', 'flooring'):
            e['style'] = art  # a seamless 256 tile (draw it per cell like seamless/*)
        if rar == 'unique':
            e['desc'] = 'One of a kind. There is only one in the whole valley.'
        if int(c.get('rot', 1)) > 1:
            e['rot_art'] = ['decor/%s%s' % (raw, '' if i == 0 else '_r%d' % i) for i in range(int(c.get('rot', 1)))]
            if not all(art_ok(r) for r in e['rot_art']):
                e['rot'] = 1; e.pop('rot_art')
                P6_WARN.append('%s: rotation art missing, rot 1' % cid)
    except (KeyError, ValueError, TypeError, SystemExit) as ex:
        P6_WARN.append('%s: %s' % (c.get('id') if isinstance(c, dict) else c, ex))
for w in P6_WARN:
    print('WARN p6', w)

# ---- 8b) arc words (c10b_13_03/04/08, c10b_08-33): penguin pieces are penguin-arc only; "Crystal"/"Wisp"
# both-arc names get a gangster name; "Crew" both-arc names read "Team" in the penguin arc.
GANG_SWAP = [('Crystal', 'Glass'), ('Wisp', 'Glow'), ('Snowfolk', 'Winter')]
for k, e in ENTRIES.items():
    if e.get('ext'):
        continue
    if e['arc'] == 'both' and re.search(r'(?i)penguin|catkin', e['name'] + ' ' + k):
        e['arc'] = 'penguins'
    if e['arc'] == 'both' and not e.get('name_gang'):
        ng = e['name']
        for a, b in GANG_SWAP:
            ng = ng.replace(a, b)
        if ng != e['name']:
            e['name_gang'] = ng
    if e['arc'] == 'both' and re.search(r'\bCrew\b', e['name']):
        pen = e['name'].replace('Crew', 'Team')
        if pen not in NAMES:
            del NAMES[e['name']]; e['name_gang'] = e['name']; e['name'] = pen; NAMES[pen] = k
# Seasonal sets (c10b_06_03): dc_fest_* pieces carry their festival season.
FEST_SEASON = {'cornucopia': 'fall', 'hay_scarecrow': 'fall', 'leaf_wreath': 'fall', 'pumpkins': 'fall',
               'gift_pile': 'winter', 'snow_lantern': 'winter', 'stocking': 'winter', 'winter_tree': 'winter'}
for k, e in ENTRIES.items():
    for w, se in FEST_SEASON.items():
        if k == 'dc_fest_' + w and not e.get('season'):
            e['season'] = se

# ---- 9) sets (+ comfort bonus when complete) -----------------------------------------------------------
def ids_where(f):
    return sorted(k for k, e in ENTRIES.items() if f(k, e))
SETS = {
    'cottage': {'name': 'Cottage Classics', 'arc': 'both', 'pieces': ids_where(lambda k, e: e['cat'] in ('furniture',) and e['name'].startswith('Cottage') and not e.get('ext'))[:8]},
    'country': {'name': 'Country Comforts', 'arc': 'both', 'pieces': ids_where(lambda k, e: e['name'].startswith('Country') and not e.get('ext'))[:8]},
    'manor': {'name': 'Manor House', 'arc': 'both', 'pieces': ids_where(lambda k, e: e['name'].startswith('Manor') or k in ('dc_sofa_velvet', 'dc_chandelier', 'dc_clock_grand', 'dc_piano'))[:8]},
    'neon_noir': {'name': 'Neon Noir', 'arc': 'gangsters', 'pieces': ids_where(lambda k, e: k.startswith('dc_neon_sign_') or k in ('dc_jukebox_a', 'dc_safe', 'dc_lamp_tall_a', 'dc_vault_closed'))},
    'arcade_den': {'name': 'Arcade Den', 'arc': 'both', 'pieces': ids_where(lambda k, e: k.startswith(('dc_arcade_cab_', 'dc_rec_pinball_', 'dc_rec_neon_')))},
    'snow_parlour': {'name': 'Snow Parlour', 'arc': 'penguins', 'pieces': ids_where(lambda k, e: k in ('dc_tt_penguin_figurine', 'dc_tt_snow_globe', 'dc_tt_snowman', 'dc_tt_snow_heart', 'dc_tt_cat_figurine', 'dc_cat_statue', 'dc_tt_lantern_crystal'))},
    'rec_trophies': {'name': 'Rec Hall of Fame', 'arc': 'both', 'pieces': ids_where(lambda k, e: k.startswith('rp_trophy') or k == 'rp_golden_pin')},
    'cosy_kitchen': {'name': 'Cosy Kitchen', 'arc': 'both', 'pieces': ids_where(lambda k, e: e['sub'] == 'kitchen')[:8]},
    'reading_nook': {'name': 'Reading Nook', 'arc': 'both', 'pieces': ids_where(lambda k, e: e['sub'] == 'study')[:6]},
}
SETS['rec_trophies']['name'] = 'Prize Trophy Case'   # c10b_13_02: "Rec Hall" is the gangster arc's name
BUILT_SETS = set(SETS)
for k0, e in ENTRIES.items():
    for s0 in e.get('sets', []):
        if s0 and s0 not in BUILT_SETS:
            SETS.setdefault(s0, {'name': s0.replace('wear_', '').replace('_', ' ').title() + ' Set', 'arc': e['arc'], 'pieces': []})
            SETS[s0]['pieces'].append(k0)
SET_NAMES = {'casino': 'Lucky Lounge Set'}   # c10b_13_01: no "casino" in a set name
for sid, s in SETS.items():
    if sid in SET_NAMES:
        s['name'] = SET_NAMES[sid]
    if s.get('arc', 'both') in ('both', ''):   # c10b_07: a both-arc set never needs a one-arc piece (Arcade Den 11/12)
        drop = [p for p in s['pieces'] if ENTRIES[p]['arc'] not in ('both', '')]
        s['pieces'] = [p for p in s['pieces'] if p not in drop]
        for p in drop:
            ENTRIES[p]['sets'] = [x for x in ENTRIES[p].get('sets', []) if x != sid]
            if ENTRIES[p].get('set') == sid:
                ENTRIES[p]['set'] = ''
    s['pieces'] = sorted(set(s['pieces']))
    s['comfort'] = 5 + 2 * len(s['pieces'])
    # c10b_07: a claim pays: SET_PAY of what the pieces cost on the shelf (capped), wear sets the same; never a loop
    # (you already bought the pieces; the pay is < their sell-back total + a fraction).
    cost = sum(ENTRIES[p]['price'] for p in s['pieces'])
    s['reward'] = {'comfort': s['comfort'], 'money': int(round(min(SET_PAY_CAP, max(SET_PAY_MIN, cost * SET_PAY)) / 10.0) * 10)}
    for p in s['pieces']:
        if sid not in ENTRIES[p]['sets']:
            ENTRIES[p]['sets'].append(sid)
        if not ENTRIES[p]['set']:
            ENTRIES[p]['set'] = sid
SETS = {k: v for k, v in SETS.items() if len(v['pieces']) >= 3}
for e in ENTRIES.values():
    e['sets'] = [s for s in e['sets'] if s in SETS]
    e['set'] = e['sets'][0] if e['sets'] else ''

# ---- 10) recipes (gen_stations imports these into its books; decor values capped below inputs there) ----
RECIPES = []
def recipe(book, id, need, tier=1):
    e = ENTRIES[id]
    RECIPES.append({'book': book, 'id': id, 'name': e['name'], 'need': need, 'tier': tier})
    e['sources'].append({'kind': 'craft', 'ref': book})
CRAFT = [  # book, id, need
    ('workbench', 'dc_stool_wood', {'plank': 4}), ('workbench', 'dc_chair_a', {'plank': 6, 'nails': 4}),
    ('workbench', 'dc_table_square', {'plank': 10, 'nails': 6}), ('workbench', 'dc_shelf_empty', {'plank': 8, 'nails': 4}),
    ('workbench', 'dc_low_table', {'plank': 8, 'nails': 4}), ('workbench', 'dc_nightstand_a', {'plank': 6, 'nails': 4}),
    ('workbench', 'dc_cat_bed', {'cloth': 2, 'plank': 2}), ('workbench', 'dc_dog_bed', {'cloth': 2, 'plank': 2}),
    ('sawmill', 'dc_bookshelf', {'hardwood_plank': 3, 'nails': 10}), ('sawmill', 'dc_dresser', {'hardwood_plank': 4, 'nails': 10}),
    ('sawmill', 'dc_wardrobe_a', {'hardwood_plank': 6, 'nails': 12}), ('sawmill', 'dc_table2_long4', {'hardwood_plank': 5, 'beam': 1}),
    ('sawmill', 'dc_desk_a', {'hardwood_plank': 4, 'nails': 8}), ('sawmill', 'dc_bed_single', {'hardwood_plank': 4, 'cloth': 3}),
    ('loom', 'dc_rug_rect_blue', {'yarn': 6}), ('loom', 'dc_rug_rect_green', {'yarn': 6}), ('loom', 'dc_rug_rect_red', {'yarn': 6}),
    ('loom', 'dc_reed_mat_a', {'fiber': 10}), ('loom', 'dc_curtain_blue_open', {'linen': 3}), ('loom', 'dc_curtain_red_open', {'linen': 3}),
    ('loom', 'dc_rug2_round_blue', {'cotton_cloth': 3, 'yarn': 4}), ('loom', 'wr_hoodie', {'cotton_cloth': 3}),
    ('loom', 'wr_sweater', {'yarn': 6}), ('loom', 'wr_scarf_red', {'yarn': 3}), ('loom', 'wr_scarf_blue', {'yarn': 3}),
    ('loom', 'wr_beanie', {'yarn': 4}),
    ('kiln', 'dc_tt_vase', {'clay': 3, 'coal': 1}), ('kiln', 'dc_tt_pot_a', {'clay': 2}), ('kiln', 'dc_tt_pot_c', {'clay': 4, 'tile': 1}),
    ('kiln', 'dc_ivy_pot', {'clay_pot': 1, 'fiber': 4}),
    ('anvil', 'dc_lantern2', {'iron_bar': 1, 'glass': 1}), ('anvil', 'dc_lamp_floor', {'iron_bar': 2, 'glass': 1}),
    ('anvil', 'dc_stove_iron', {'iron_bar': 4, 'coal': 2}),
    ('jeweler', 'dc_tt_snow_globe', {'glass': 2, 'shard': 2}), ('jeweler', 'dc_tt_lantern_crystal', {'crystal_glass': 1, 'gold_bar': 1}),
    ('armory', 'dc_safe', {'steel_bar': 6, 'gear': 2}), ('armory', 'wr_shades', {'glass': 2, 'leather': 1}),
    ('hack', 'dc_neon_sign_0', {'glass': 3, 'circuit_board': 1}), ('hack', 'dc_neon_sign_1', {'glass': 3, 'circuit_board': 1}),
    ('shaper', 'dc_tt_snowman', {'shard': 2, 'fiber': 2}), ('shaper', 'dc_tt_penguin_figurine', {'shard': 2, 'clay': 2}),
]
for book, id, need in CRAFT:
    if id in ENTRIES and all(k in I for k in need):
        e = ENTRIES[id]
        recipe(book, id, need, max(1, min(4, e['tier'])))

# ---- 11) shops: {shop: [[tier, [ids]]]} -- Decor.stock(shop) rotates N of them per day -------------------
EXT_OK = [False]
def shop_rows(f):
    rows = {}
    for k, e in sorted(ENTRIES.items()):
        if e.get('ext') or e['rarity'] in ('mythic', 'unique') or not e['price'] or not f(k, e):
            continue
        if e['cat'] == 'exterior' and not EXT_OK[0]:   # c10b_01-14: exterior parts only on their own shelves
            continue
        rows.setdefault(min(4, e['tier']), []).append(k)
    return [[t, rows[t]] for t in sorted(rows)]
SHOPS = {
    'home_goods': shop_rows(lambda k, e: e['cat'] in ('furniture', 'decor', 'light', 'rug') and e['rarity'] in ('common', 'uncommon', 'rare') and e['arc'] != 'gangsters'),
    'wall_art': shop_rows(lambda k, e: e['cat'] in ('wall_art', 'wallpaper', 'flooring') and e['rarity'] != 'legendary' and e['arc'] != 'gangsters'),
    'wardrobe': shop_rows(lambda k, e: e['cat'] in WEAR_CATS and e['rarity'] in ('common', 'uncommon', 'rare') and e['arc'] != 'gangsters'),
    'crew_goods': shop_rows(lambda k, e: e['arc'] in ('gangsters', 'both') and e['rarity'] in ('common', 'uncommon', 'rare', 'epic') and (e['arc'] == 'gangsters' or e['sub'] in ('tech', 'music', 'neon', 'seating', 'light'))),
    'hub_goods': shop_rows(lambda k, e: e['rarity'] in ('rare', 'epic', 'legendary') and e['cat'] not in WEAR_CATS),
}
# Keeper shelves (P4's DecorSources.SHELF reads these keys; "<key>_gang" is the gangster arc's list, and
# "stall:<scene>" lists are optional). Full lists: P4 rotates them itself, so they get no shop_slots.
def text(k, e): return (k + ' ' + e['name'] + ' ' + e['sub'] + ' ' + e.get('set', '')).lower()
KEEPERS = {  # key: (cats, words (any; empty = every piece of those cats))
    'maple': (('decor', 'light', 'rug', 'wallpaper', 'flooring'), ()),
    'gideon': (('furniture', 'light'), ('iron', 'lantern', 'lamp', 'stove', 'safe', 'storage', 'chandelier', 'clock', 'steel', 'metal', 'forge')),
    'wren': (('decor', 'light', 'furniture'), ('plant', 'potion', 'bottle', 'wisp', 'herb', 'crystal', 'jar', 'candle', 'flower', 'bloom')),
    'granite': (('decor', 'furniture', 'flooring', 'wallpaper'), ('stone', 'statue', 'fireplace', 'hearth', 'brick', 'marble', 'cobble', 'flagstone', 'quarry', 'bust')),
    'sel': (('decor', 'wall_art', 'furniture'), ('study', 'globe', 'book', 'scroll', 'painting', 'telescope', 'relic', 'ink', 'easel', 'library', 'map')),
    'tam': (('rug', 'furniture', 'top', 'acc', 'hat'), ('rug', 'wool', 'quilt', 'knit', 'scarf', 'sweater', 'bed', 'beanie', 'pelt', 'mat')),
    'orla': (('furniture', 'decor', 'flooring'), ('kitchen', 'table', 'jug', 'kettle', 'coffee', 'mug', 'bread', 'pantry', 'tile')),
    'marlowe': (('light', 'wall_art', 'decor'), ('lantern', 'window', 'shell', 'sea', 'bottle', 'lighthouse', 'lamp', 'boat', 'anchor')),
    'rook': (('rug', 'wall_art', 'furniture', 'hat', 'acc'), ('pelt', 'antler', 'lodge', 'hood', 'cloak', 'log', 'trophy', 'cabin', 'hunt')),
    'old_moss': (('decor', 'rug', 'furniture'), ('plant', 'reed', 'cattail', 'frog', 'moss', 'hut', 'mat', 'ivy', 'fern')),
    'catkins': (('decor', 'furniture', 'rug', 'wall_art'), ('cat', 'paw', 'penguin', 'snow', 'cushion', 'figurine', 'yarn')),
    'finn': (('decor', 'wall_art', 'rug'), ('fish', 'shell', 'sea', 'net', 'boat', 'koi', 'rod', 'anchor', 'coral', 'echo')),
    'hazel': (('furniture', 'rug', 'wallpaper', 'flooring'), ('bed', 'chair', 'table', 'sofa', 'armchair', 'stool', 'dresser', 'wardrobe', 'shelf', 'bench', 'cottage', 'country')),
}
for key, (cats, words) in KEEPERS.items():
    def keep_f(k, e, cats=cats, words=words, gang=False):
        if e['cat'] not in cats or e['rarity'] in ('legendary',):
            return False
        if gang and e['arc'] == 'penguins' or not gang and e['arc'] == 'gangsters':
            return False
        if not gang and e['sub'] in ('tech', 'neon', 'music'):  # arcade/neon pieces live on the crew shelves
            return False
        return not words or any(w in text(k, e) for w in words)
    SHOPS[key] = shop_rows(keep_f)
    g = shop_rows(lambda k, e, f=keep_f: f(k, e, gang=True) or (e['arc'] == 'gangsters' and e['cat'] in cats and e['rarity'] != 'legendary'))
    if g != SHOPS[key] and key != 'catkins':  # Catkins is penguin-only
        SHOPS[key + '_gang'] = g
# C10b: yard pieces at Hazel's (the farmer; c10b_10_03 option A), exterior parts at Gideon's (he builds the
# house upgrades), seasonal stalls at the festivals (stall:festival_<season>, Shops.stall via town.gd),
# Lumi's loom sells the wardrobe (c10b_10_06), crew counters split crew_goods (c10b_10_04).
OUT_F = lambda k, e: e['cat'] == 'outdoor' and e['rarity'] in ('common', 'uncommon', 'rare', 'epic')
for key, gang in (('hazel', False), ('hazel_gang', True)):
    rows = {t: list(ids) for t, ids in SHOPS.get(key, [])}
    for t, ids in shop_rows(lambda k, e, g=gang: OUT_F(k, e) and (e['arc'] in ('both', 'gangsters' if g else 'penguins'))):
        rows.setdefault(t, []).extend(ids)
    SHOPS[key] = [[t, sorted(set(rows[t]))] for t in sorted(rows)]
EXT_OK[0] = True
for key in ('gideon', 'gideon_gang'):
    rows = {t: list(ids) for t, ids in SHOPS.get(key, [])}
    for t, ids in shop_rows(lambda k, e, g=key.endswith('_gang'): e['cat'] == 'exterior' and e['arc'] in ('both', 'gangsters' if g else 'penguins')):
        rows.setdefault(t, []).extend(ids)
    if rows:
        SHOPS[key] = [[t, sorted(set(rows[t]))] for t in sorted(rows)]
EXT_OK[0] = False
for se in ('spring', 'summer', 'fall', 'winter'):
    SHOPS['stall:festival_' + se] = shop_rows(lambda k, e, se=se: e.get('season') == se and e['rarity'] in ('common', 'uncommon', 'rare'))
# Mega hub and Valley stalls (c10b_10_05/09): region.gd's Shops.stall reads "stall:<scene>". Hub stalls sell
# rare-legendary pieces by region theme: the late-game sink (legendary only here, mythic never sold).
HUB_STALLS = {'gloam_lanternfall': ('lantern', 'lamp', 'candle', 'moon', 'glow', 'wisp'),
              'desert_mirage_post': ('rug', 'brass', 'sun', 'sand', 'urn', 'obelisk', 'pot'),
              'frost_hearthhold': ('fur', 'pelt', 'snow', 'ice', 'hearth', 'fire', 'winter'),
              'wind_breezehaven': ('sail', 'shell', 'sea', 'boat', 'kite', 'wind', 'anchor'),
              'gilt_grand_plaza': ('gilt', 'gold', 'velvet', 'chandelier', 'marble', 'statue'),
              'iron_junction': ('iron', 'rail', 'steel', 'clock', 'lantern', 'stove')}
for sc, words in HUB_STALLS.items():
    SHOPS['stall:' + sc] = shop_rows(lambda k, e, w=words: e['rarity'] in ('rare', 'epic', 'legendary') and e['cat'] not in WEAR_CATS
                                     and any(x in text(k, e) for x in w))
VALLEY_STALLS = {'docks': ('shell', 'net', 'anchor', 'boat', 'fish'), 'neon': ('neon', 'sign', 'arcade'), 'hideout': ('crate', 'lamp', 'rug')}
for sc, words in VALLEY_STALLS.items():
    SHOPS['stall:' + sc] = shop_rows(lambda k, e, w=words: e['rarity'] in ('common', 'uncommon', 'rare') and e['cat'] not in WEAR_CATS
                                     and e['arc'] != 'penguins' and any(x in text(k, e) for x in w))
SHOPS['lumi'] = SHOPS['wardrobe']
SHOPS['lumi_gang'] = shop_rows(lambda k, e: e['cat'] in WEAR_CATS and e['rarity'] in ('common', 'uncommon', 'rare') and e['arc'] != 'penguins')
CREW_WORDS = {'marlene': ('crate', 'rug', 'antique', 'clock', 'safe', 'vault', 'lamp', 'cabinet', 'chest'),
              'deuce': ('arcade', 'neon', 'jukebox', 'pinball', 'music', 'lucky', 'dice', 'card', 'sign'),
              'specs': ('tech', 'screen', 'computer', 'monitor', 'desk', 'study', 'book', 'chrome', 'lab'),
              'halo': ('garage', 'chrome', 'motor', 'car', 'tyre', 'tire', 'oil', 'tool', 'drum', 'yard_gang')}
crew_ids = {i for _, ids in SHOPS['crew_goods'] for i in ids} | {k for k, e in ENTRIES.items() if e['sub'] == 'yard_gang'}
for cw, words in CREW_WORDS.items():
    SHOPS['crew_' + cw] = shop_rows(lambda k, e, w=words: k in crew_ids and e['arc'] != 'penguins' and any(x in text(k, e) for x in w))
SHOP_SLOTS = {'home_goods': 8, 'wall_art': 6, 'wardrobe': 6, 'crew_goods': 8, 'hub_goods': 5}
SHOP_DAYS = {'home_goods': 1, 'wall_art': 3, 'wardrobe': 3, 'crew_goods': 1, 'hub_goods': 7}   # rotation period in days
for s, rows in SHOPS.items():
    for _, ids in rows:
        for k in ids:
            if not any(x.get('kind') == 'shop' for x in ENTRIES[k]['sources']):
                ENTRIES[k]['sources'].append({'kind': 'shop', 'ref': s})

# ---- 12) loot pools: [[id, weight]] (weights from RARITY; Decor.roll applies luck + pity) ----------------
def pool(f, cap_rank=6):
    return [[k, RK[e['rarity']]['weight']] for k, e in sorted(ENTRIES.items())
            if not e.get('ext') and e['rarity'] != 'unique' and e['cat'] != 'exterior' and RK[e['rarity']]['rank'] <= cap_rank and f(k, e)]
POOLS = {}
for t in range(1, 6):
    POOLS['chest_t%d' % t] = pool(lambda k, e, t=t: e['tier'] <= t and e['tier'] >= t - 2 and e['cat'] not in ('wallpaper', 'flooring'), min(5, t))
    POOLS['mine_t%d' % t] = pool(lambda k, e, t=t: e['tier'] <= t and (e['sub'] in ('light', 'statue', 'study', 'tabletop', 'storage') or 'crystal' in k), min(4, t))
POOLS['boss'] = pool(lambda k, e: e['rarity'] in ('epic', 'legendary', 'mythic') and e['cat'] not in ('wallpaper', 'flooring'))
POOLS['fishing'] = pool(lambda k, e: any(w in k for w in ('shell', 'fish', 'bottle', 'wisp', 'echo', 'reed', 'fossil', 'lantern')), 4)
POOLS['fishing_sea'] = pool(lambda k, e: any(w in text(k, e) for w in ('shell', 'sea', 'coral', 'anchor', 'boat', 'fish', 'bottle', 'net', 'lighthouse')), 4)
POOLS['fishing_deep'] = pool(lambda k, e: RK[e['rarity']]['rank'] >= 2 and any(w in text(k, e) for w in ('shell', 'sea', 'coral', 'wisp', 'koi', 'pearl', 'echo', 'bottle', 'crystal')), 5)
POOLS['mail'] = pool(lambda k, e: e['sub'] in ('tabletop', 'plant') or (e['cat'] in ('decor', 'light') and e['tier'] <= 2), 1)
POOLS['claw'] = pool(lambda k, e: e['sub'] in ('tabletop', 'pet', 'neon') and e['rarity'] in ('common', 'uncommon', 'rare'), 2)
POOLS['festival'] = pool(lambda k, e: e.get('season') or k.startswith(('dc_fest_', 'wr_flower_crown')), 3)   # c10b_06_17
for se in ('spring', 'summer', 'fall', 'winter'):   # contest prizes (town festivals: places 1-3; c10b_06_02/04)
    POOLS['festival_%s_prize' % se] = pool(lambda k, e, se=se: e.get('season') == se and e['rarity'] in ('uncommon', 'rare', 'epic'), 3)
for pid, rows in POOLS.items():
    for k, _ in rows:
        if not any(x.get('kind') == 'loot' for x in ENTRIES[k]['sources']):
            ENTRIES[k]['sources'].append({'kind': 'loot', 'ref': pid})

# ---- 12b) grants {"<owner>:<ref>": id} (P4 DecorSources.grant_key; generators may read them too) -------
GRANTS = {}
def grant(key, id):
    if id in ENTRIES and key not in GRANTS:
        GRANTS[key] = id
        if ENTRIES[id]['rarity'] != 'unique' or not ENTRIES[id]['sources']:
            ENTRIES[id]['sources'].append({'kind': key.split(':')[0], 'ref': key.split(':', 1)[1]})
def first(f, any_arc=False):
    for k, e in sorted(ENTRIES.items()):
        if not e.get('ext') and e.get('order') is not False and e['rarity'] not in ('unique',) and (any_arc or e['arc'] == 'both') and f(k, e) and k not in GRANTS.values():
            return k
    return ''
# Every unique's single source is also a grant key ("<kind>:<ref>"): region boss wins call grant_key("boss:<rid>"),
# pocket chests "chest:<key>", GameState.complete_quest "quest:<id>", DecorSources.sweep the rest
# (secret flags, campaigns, collections, set:set_master) every morning.
for k, e in sorted(ENTRIES.items()):
    if e['rarity'] == 'unique' and e['sources'] and e['sources'][0]['kind'] in ('boss', 'chest', 'quest', 'secret', 'campaign', 'set', 'collection'):
        GRANTS.setdefault('%s:%s' % (e['sources'][0]['kind'], e['sources'][0]['ref']), k)
grant('secret:journal', first(lambda k, e: e['rarity'] == 'epic' and e['sub'] in ('study', 'tabletop')) or first(lambda k, e: e['rarity'] == 'epic'))
grant('house:2', first(lambda k, e: e['sub'] == 'seating' and e['rarity'] == 'uncommon'))
grant('house:3', first(lambda k, e: e['sub'] == 'clock' and e['rarity'] == 'rare') or first(lambda k, e: e['rarity'] == 'rare' and e['cat'] == 'furniture'))
for fl, rar in ((25, 'rare'), (50, 'rare'), (75, 'epic'), (100, 'epic'), (120, 'legendary')):
    grant('mine:%d' % fl, first(lambda k, e, rar=rar: e['rarity'] == rar and any(w in text(k, e) for w in ('crystal', 'lantern', 'lamp', 'statue', 'stone', 'gem'))))
for npc in KEEPERS:
    rows = SHOPS.get(npc, [])
    pick = first(lambda k, e, ids={i for _, ids in rows for i in ids}: k in ids and e['rarity'] in ('rare', 'epic')) \
        or first(lambda k, e, w=KEEPERS[npc][1]: e['rarity'] in ('rare', 'epic') and e['cat'] not in WEAR_CATS | {'exterior'} and any(x in text(k, e) for x in w)) \
        or first(lambda k, e: e['rarity'] == 'rare' and e['cat'] in ('decor', 'wall_art', 'light'))
    grant('heart:%s:8' % npc, pick)
CF = json.load(open(os.path.join(D, 'community_farm.json'))).get('stages', [])
CF_WORDS = {'clear': ('signpost', 'bench'), 'shed': ('lantern', 'lamp'), 'beds': ('flowerbed', 'bed'), 'seeds': ('planter', 'trough'),
            'well': ('well', 'birdbath'), 'orchard': ('hedge', 'topiary'), 'greenhouse': ('planter', 'urn'), 'market': ('umbrella', 'cart', 'picnic')}
# Side-story keepsakes picked for the story (c10b_06_07, c10b_13_12): words per chain, arc-safe.
SS_WORDS = {'babies': ('figurine', 'plush', 'cradle', 'snow'), 'jim_brother': ('photo', 'frame', 'painting', 'portrait'),
            'coldy_key': ('key', 'chest', 'lantern', 'ice'), 'commander': ('banner', 'flag', 'trophy', 'statue'),
            'rosa': ('kitchen', 'oven', 'stove', 'herb', 'bread', 'kettle'), 'kid_school': ('book', 'globe', 'study', 'desk', 'chalk'),
            'specs_wire': ('tech', 'screen', 'radio', 'computer', 'monitor')}
for st in (CF if isinstance(CF, list) else []):
    sid = st.get('id') if isinstance(st, dict) else None
    if sid:
        # c10b_06_08: a garden/yard keepsake per stage, both arcs, no arc words
        grant('commons:' + sid, first(lambda k, e, w=CF_WORDS.get(sid, ()): e['cat'] in ('outdoor', 'decor') and e['rarity'] in ('uncommon', 'rare')
                                      and (not w or any(x in text(k, e) for x in w)) and not re.search(r'(?i)neon|penguin|crystal', e['name']))
              or first(lambda k, e: e['sub'] in ('plant', 'tabletop') and e['rarity'] == 'uncommon' and not re.search(r'(?i)neon|penguin|crystal', e['name'])))
SS = json.load(open(os.path.join(D, 'side_stories.json'))).get('chains', [])
for ch in SS:
    cid2 = ch.get('id') if isinstance(ch, dict) else None
    if cid2:
        okarc = lambda e, a=ch.get('arc', ''): (e['arc'] == 'both' or e['arc'] == a) and not (a == 'gangsters' and re.search(r'(?i)penguin|crystal', e['name']))
        grant('side:' + cid2, first(lambda k, e, w=SS_WORDS.get(cid2, ()): e['rarity'] in ('uncommon', 'rare') and e['cat'] in ('wall_art', 'decor', 'furniture')
                                    and okarc(e) and any(x in text(k, e) for x in w) and not re.search(r'(?i)casino|lucky|ace|dice', e['name']), any_arc=True)
              or first(lambda k, e: e['rarity'] == 'rare' and e['cat'] in ('wall_art', 'decor') and okarc(e), any_arc=True))
# Festival contest places (town.gd): place 1 rolls "festival_<season>_prize"; the Rec Cup winner gets a trophy (c10b_06_06).
grant('rec:cup', first(lambda k, e: 'cup' in k and 'trophy' in text(k, e)) or first(lambda k, e: 'trophy' in k and e['cat'] != 'exterior'))
# Main quests with a home piece (c10b_06_12): the arc's chapter ends.
for qid, qarc, w in (('cattopia', 'penguins', ('cat',)), ('knight', 'penguins', ('knight', 'shield', 'banner', 'pennant', 'armour')), ('docks', 'gangsters', ('anchor', 'boat', 'ship', 'harbour', 'lantern')),
                     ('neon', 'gangsters', ('neon', 'sign')), ('uptown', 'gangsters', ('clock', 'velvet', 'chandelier'))):
    grant('quest:' + qid, first(lambda k, e, w=w, a=qarc: e['rarity'] in ('rare', 'epic') and e['cat'] not in WEAR_CATS | {'exterior'} and e['arc'] in ('both', a)
                                and not (a == 'gangsters' and re.search(r'(?i)penguin|crystal', e['name'])) and any(x in e['name'].lower() for x in w), any_arc=True))

# ---- 13) house: reserved cells per tier (mirror of house.gd consts; Decor.place refuses them) ------------
# Mirror of house.gd consts (BED 3,2 (2x2), CHEST/dresser 12,2, DOOR 8,11 + the cell in front, stove 13,9,
# CELLAR 17,9 (2x2), STUDY 17,3 (2x1), BATH 23,3, SPOUSE_CORNER per tier, back wall row 1). P2's Decor
# placement refuses these cells; keep in step with house.gd (decor_test checks the door/bed cells).
def _res(tier, cols):
    out = [[1, 1, cols - 2, 1, 'wall'], [3, 2, 2, 2, 'bed'], [12, 2, 1, 1, 'dresser'], [8, 10, 1, 2, 'door'], [13, 9, 1, 1, 'stove']]
    out.append({1: [14, 5, 1, 1, 'spouse'], 2: [17, 4, 1, 1, 'spouse'], 3: [23, 8, 1, 1, 'spouse']}[tier])
    if tier >= 3:
        out += [[17, 9, 2, 2, 'cellar'], [17, 3, 2, 1, 'study'], [23, 3, 1, 1, 'bath']]
    return out
HOUSE_RESERVED = {str(t): _res(t, c) for t, c in {1: 16, 2: 20, 3: 26}.items()}
# Old saves that already passed a unique's event get it once at migration (Decor.migrate; c10_06):
# {id: run.flags key}. Only events whose flag already exists in the game are listed.
BACKGRANT = {'dc_u_lighthouse_lamp': 'lighthouse_lit'}
LEGACY = {'museum_trophy': 'dc_tt_trophy_crystal', 'fish_trophy': 'dc_tt_trophy_fish_a'}

# ---- self-checks ---------------------------------------------------------------------------------------
fails = []
BANNED_BOTH = re.compile(r'(?i)rec center|rec hall|commons|high roller|casino|gambl|cigar')
DRINK = re.compile(r'(?i)\b(wine|ale|rum|beer|whisk(e)?y|vodka|gin|brandy|liquor|booze|cocktail|drug|weed|pill)\b')
for k, e in ENTRIES.items():
    for ref in [e['art'], e['icon']] + e.get('rot_art', []):
        if not art_ok(ref):
            fails.append('art missing/kits: %s %s' % (k, ref))
    if len(e['name']) > 26:
        fails.append('name too long: %s %r' % (k, e['name']))
    if DRINK.search(e['name']) or DRINK.search(e['desc']):
        fails.append('drink/drug word: ' + k)
    if e['arc'] == 'both' and BANNED_BOTH.search(e['name']) and not e.get('ext'):
        fails.append('arc word in a both-arc name: ' + k)
    if e['arc'] == 'gangsters' and re.search(r'(?i)penguin|crystal|casino|gambl|cigar', e['name']):
        fails.append('gang word: ' + k)
    r = e['rarity']
    lo, hi = RK[r]['band']
    keepsake = e.get('order') is False and not e['price']
    if not e.get('ext') and r != 'unique' and not keepsake and not (lo <= e['price'] <= hi):
        fails.append('price outside band: %s %s %d' % (k, r, e['price']))
    if not e.get('ext') and not keepsake and e['sell'] * 2.6 >= e['price'] * 0.72 and r != 'unique':
        fails.append('sell/buy loop: ' + k)
    if r == 'unique':
        if e['price'] or e['sell'] or len(e['sources']) != 1 or e['sources'][0]['kind'] in ('shop', 'loot', 'prize', 'craft'):
            fails.append('unique rule: ' + k)
    if r == 'mythic' and any(s['kind'] in ('shop', 'craft') for s in e['sources']):
        fails.append('mythic sold/crafted: ' + k)
    if not e['sources'] and r != 'unique':
        pass
for s, rows in SHOPS.items():
    for _, ids in rows:
        for k in ids:
            if ENTRIES[k]['rarity'] in ('mythic', 'unique'):
                fails.append('shop %s sells %s' % (s, k))
for p, rows in POOLS.items():
    if not rows:
        fails.append('empty pool ' + p)
    for k, _ in rows:
        if ENTRIES[k]['rarity'] == 'unique':
            fails.append('pool %s holds unique %s' % (p, k))
for r in RECIPES:
    if ENTRIES[r['id']]['rarity'] in ('mythic', 'unique'):
        fails.append('recipe for ' + r['id'])
nosrc = sorted(k for k, e in ENTRIES.items() if not e['sources'])
# Every piece needs a way in: give the stragglers a hub shop or loot slot by rarity.
for k in nosrc:
    e = ENTRIES[k]
    if e['rarity'] in ('mythic',):
        POOLS['boss'].append([k, RK['mythic']['weight']]); e['sources'].append({'kind': 'loot', 'ref': 'boss'})
    elif e['price']:
        t = min(4, e['tier'])
        row = [rw for rw in SHOPS['hub_goods'] if rw[0] == t]
        if row:
            row[0][1].append(k)
        else:
            SHOPS['hub_goods'].append([t, [k]]); SHOPS['hub_goods'].sort()
        e['sources'].append({'kind': 'shop', 'ref': 'hub_goods'})
if fails:
    print('\n'.join('FAIL ' + f for f in fails[:40]))
    raise SystemExit('gen_decor: %d failures' % len(fails))

# ---- write ---------------------------------------------------------------------------------------------
out = {'rarity': RARITY, 'cats': CATS, 'sell_share': SELL_SHARE, 'reorder_fee': REORDER_FEE, 'reorder_min': REORDER_MIN,
       'pity': PITY, 'luck_step': LUCK_STEP, 'items': ENTRIES, 'sets': SETS, 'shops': SHOPS, 'shop_slots': SHOP_SLOTS,
       'shop_days': SHOP_DAYS, 'pools': POOLS, 'recipes': RECIPES, 'house_reserved': HOUSE_RESERVED, 'legacy': LEGACY,
       'backgrant': {k: v for k, v in BACKGRANT.items() if k in ENTRIES}, 'grants': GRANTS}
# c10b_08-08/09-01/12: catalogue wallpaper/flooring are room surfaces: DecorMode.SURFACE_LAYERS reads
# layer "wallpaper"/"flooring" (the entry keeps "style" = the tile kit / seamless texture it paints).
for e in ENTRIES.values():
    if e['cat'] in ('wallpaper', 'flooring'):
        e['layer'] = e['cat']
# decor.json uses the contract's arc convention: "" = both arcs (P4/P3 test a == "" or a == run.arc)
for e in ENTRIES.values():
    if e['arc'] == 'both':
        e['arc'] = ''
for st2 in SETS.values():
    if st2.get('arc') == 'both':
        st2['arc'] = ''
with open(os.path.join(D, 'decor.json'), 'w') as f:
    json.dump(out, f, indent=1, ensure_ascii=False, sort_keys=True)
    f.write('\n')
# items.json: dc_/wr_ entries (stale ones removed); never 'arc': 'both'
for k in [k for k in I if k.startswith(('dc_', 'wr_'))]:
    if k not in ENTRIES:
        del I[k]
for k, e in ENTRIES.items():
    if e.get('ext'):
        continue
    it = I.get(k, {})
    it.update({'name': e['name'], 'type': 'wear' if e['cat'] in WEAR_CATS else 'decor', 'value': e['sell'],
               'rarity': e['rarity'], 'tier': min(5, e['tier']), 'icon': e['icon'], 'desc': e['desc'], 'decor': True})
    if e['arc'] not in ('both', ''):
        it['arc'] = e['arc']
    else:
        it.pop('arc', None)
    if e['rarity'] == 'unique':
        it['keep'] = True
    I[k] = it
assert not any(v.get('arc') == 'both' for v in I.values())
with open(os.path.join(D, 'items.json'), 'w') as f:
    json.dump(I, f, indent=1, ensure_ascii=False)
# coverage table
from collections import Counter
TARGET = {'seating': 40, 'table': 30, 'bed': 16, 'storage': 40, 'kitchen': 28, 'bath': 12, 'light': 30, 'plant': 18, 'rug': 24,
          'painting': 70, 'window': 16, 'tabletop': 45, 'music': 8, 'tech': 14, 'study': 12, 'statue': 10, 'neon': 16, 'fireplace': 6,
          'wallpaper': 30, 'flooring': 40, 'showpiece': 10}
subs = Counter(e['sub'] for e in ENTRIES.values())
cats = Counter(e['cat'] for e in ENTRIES.values())
rars = Counter(e['rarity'] for e in ENTRIES.values())
arcs = Counter(e['arc'] for e in ENTRIES.values())
lines = ['# Decor art coverage (written by tools/gen_decor.py; do not edit)', '',
         'Entries: %d (decor %d, wear %d). P6 renders merged: %d.' % (len(ENTRIES), sum(1 for e in ENTRIES.values() if e['cat'] not in WEAR_CATS),
                                                                      sum(1 for e in ENTRIES.values() if e['cat'] in WEAR_CATS), len(p6)), '',
         '| sub | have | target | gap |', '|---|---|---|---|']
for s in sorted(set(TARGET) | set(subs)):
    lines.append('| %s | %d | %d | %d |' % (s, subs.get(s, 0), TARGET.get(s, 0), max(0, TARGET.get(s, 0) - subs.get(s, 0))))
lines += ['', 'By category: ' + ', '.join('%s %d' % kv for kv in sorted(cats.items())),
          'By rarity: ' + ', '.join('%s %d' % (r['id'], rars.get(r['id'], 0)) for r in RARITY),
          'By arc: ' + ', '.join('%s %d' % kv for kv in sorted(arcs.items())), ''] + (['P6 entries skipped:'] + ['- ' + w for w in P6_WARN] + [''] if P6_WARN else [])
open(os.path.join(ROOT, 'docs', 'DECOR-ART.md'), 'w').write('\n'.join(lines))
print('gen_decor: %d entries (%s), %d sets, %d recipes, shops %s, pools %d' % (
    len(ENTRIES), ', '.join('%s %d' % (r['id'], rars.get(r['id'], 0)) for r in RARITY), len(SETS), len(RECIPES),
    {k: sum(len(r[1]) for r in v) for k, v in SHOPS.items()}, len(POOLS)))
if '--report' in sys.argv:
    print('\n'.join(lines))
