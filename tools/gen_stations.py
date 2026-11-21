#!/usr/bin/env python3
"""Writes the workshop system into data/: station buildings (4 tiers each),
their recipe books, and the goods they make. Re-runnable: it rebuilds the
station entries and books from this file and leaves everything else alone.
    python3 tools/gen_stations.py
"""
import json, os
D = os.path.join(os.path.dirname(__file__), '..', 'data') + '/'
B = json.load(open(D + 'buildings.json')); R = json.load(open(D + 'recipes.json')); I = json.load(open(D + 'items.json'))
M = json.load(open(D + '../art/gen/manifest.json'))

def item(id, name, type, value, tier, **kw):
    rar = ['common', 'common', 'uncommon', 'rare', 'epic', 'legendary'][tier]
    cur = I.get(id, {})
    cur.update({'name': name, 'type': type, 'value': value, 'rarity': kw.pop('rarity', rar), 'tier': tier}); cur.update(kw); I[id] = cur

# ---- goods ---------------------------------------------------------------------
G = [  # id, name, type, value, tier, extra
 ('plank', 'Plank', 'craft', 6, 1, {}), ('hardwood_plank', 'Hardwood Plank', 'craft', 45, 2, {}), ('beam', 'Timber Beam', 'craft', 40, 2, {}),
 ('shingles', 'Shingles', 'craft', 14, 1, {}), ('wheel', 'Cart Wheel', 'craft', 90, 2, {}), ('veneer', 'Fine Veneer', 'craft', 160, 3, {}),
 ('ironwood_beam', 'Ironwood Beam', 'craft', 420, 4, {}),
 ('dark_bar', 'Shadowsteel Bar', 'bar', 520, 4, {}), ('moon_bar', 'Moonsilver Bar', 'bar', 2400, 5, {}),
 ('nails', 'Nails', 'craft', 7, 1, {}), ('horseshoe', 'Horseshoe', 'craft', 80, 1, {'stats': {}, 'desc': 'Lucky. Benno swears by them.'}),
 ('gear', 'Gear', 'craft', 110, 2, {}), ('spring', 'Spring', 'craft', 95, 2, {}), ('plating', 'Steel Plating', 'craft', 380, 3, {}),
 ('yarn', 'Yarn', 'craft', 34, 1, {}), ('linen', 'Linen', 'craft', 48, 1, {}), ('cotton_cloth', 'Cotton Cloth', 'craft', 75, 2, {}),
 ('fine_fabric', 'Fine Fabric', 'craft', 220, 3, {}), ('moonweave', 'Moonweave', 'craft', 700, 4, {}), ('sail', 'Sailcloth', 'craft', 150, 2, {}),
 ('fine_leather', 'Fine Leather', 'craft', 140, 3, {}),
 ('brick', 'Brick', 'craft', 12, 1, {}), ('clay_pot', 'Clay Pot', 'craft', 26, 1, {}), ('tile', 'Glazed Tile', 'craft', 60, 2, {}),
 ('crystal_glass', 'Crystal Glass', 'craft', 330, 3, {}),
 ('butter', 'Butter', 'food', 55, 1, {'energy': 20}), ('cooking_oil', 'Cooking Oil', 'craft', 50, 1, {}), ('dried_fruit', 'Dried Fruit', 'food', 70, 2, {'energy': 35}),
 ('crystal_battery', 'Crystal Battery', 'craft', 560, 3, {}),
 # premium keg goods (C8 P2): what a keg makes from produce worth KEG_BREW['premium_at'] or more
 ('reserve_ale', 'Reserve Ale', 'gift', 450, 4, {'desc': 'Brewed from the finest grain. A trade good: sold and gifted, never drunk. Collectors pay well.'}),
 ('royal_mead', 'Royal Mead', 'gift', 450, 4, {'desc': 'Brewed from rare blossoms. A trade good: sold and gifted, never drunk. Collectors pay well.'}),
 ('gourmet_pickles', 'Gourmet Pickles', 'food', 420, 4, {'energy': 70, 'desc': 'Crisp, bright, impossible to stop eating.'}),
 ('herbal_cordial', 'Herbal Cordial', 'food', 420, 4, {'energy': 60, 'heal': 3, 'desc': 'A sweet, green, restoring syrup.'}),
 ('truffle_broth', 'Truffle Broth', 'food', 420, 4, {'energy': 90, 'desc': 'Deep, earthy and warming.'}),
 ('goat_cheese', 'Goat Cheese', 'food', 95, 2, {'energy': 30, 'desc': 'Tangy and soft, pressed from goat milk.'}),
 # ranch processing (C11a P3): Mayo Machine, Honey Extractor, press and loom goods
 ('mayonnaise', 'Mayonnaise', 'food', 60, 1, {'energy': 30, 'desc': 'Whipped from fresh eggs in the Mayo Machine.'}),
 ('duck_mayonnaise', 'Duck Mayonnaise', 'food', 90, 2, {'energy': 40, 'icon': 'mayonnaise', 'desc': 'Rich and golden, from duck eggs.'}),
 ('beeswax', 'Beeswax', 'craft', 30, 1, {'icon': 'wax', 'desc': 'Spun from honeycomb. Candles, polish and fine goods.'}),
 ('honey_jar', 'Jar of Honey', 'food', 160, 2, {'energy': 60, 'heal': 2, 'desc': 'Clear, golden honey, sealed in glass.'}),
 ('beeswax_candle', 'Beeswax Candle', 'craft', 75, 2, {'icon': 'candle', 'desc': 'Burns long and smells of summer.'}),
 ('cream', 'Cream', 'food', 60, 1, {'energy': 25, 'desc': 'Skimmed from fresh milk.'}),
 ('yogurt', 'Honey Yogurt', 'food', 110, 2, {'energy': 40, 'heal': 1, 'icon': 'yogurt', 'desc': 'Thick, tangy and sweetened with honey.'}),
 ('down_pillow', 'Down Pillow', 'craft', 90, 1, {'icon': 'feather', 'desc': 'Soft as a cloud, stuffed with feathers. A fine trade good.'}),
 ('truffle_oil', 'Truffle Oil', 'craft', 320, 3, {'icon': 'cooking_oil', 'desc': 'A few drops make any dish taste rich.'}),
 # potions (the magic potion station)
 ('swift_draught', 'Swift Draught', 'potion', 120, 2, {'buff': {'kind': 'speed', 'minutes': 180, 'amount': 1}, 'desc': 'Quick feet for three hours.'}),
 ('luck_potion', 'Luck Potion', 'potion', 180, 2, {'buff': {'kind': 'luck', 'minutes': 240, 'amount': 2}, 'desc': 'Better finds, kinder dice.'}),
 ('stoneskin_tonic', 'Stoneskin Tonic', 'potion', 200, 3, {'buff': {'kind': 'defense', 'minutes': 180, 'amount': 2}, 'desc': 'Hits land softer.'}),
 ('hearth_brew', 'Hearth Brew', 'potion', 90, 1, {'buff': {'kind': 'warm', 'minutes': 360, 'amount': 1}, 'energy': 20, 'desc': 'Warm to the toes. Snow and cold water bother you less.'}),
 ('growth_elixir', 'Growth Elixir', 'consumable', 300, 3, {'effect': 'growth', 'desc': 'Pour it out: every crop on your farm grows a day.'}),
 ('greater_potion', 'Greater Potion', 'potion', 220, 3, {'heal': 12}),
 ('mana_potion', 'Mana Potion', 'potion', 60, 2, {'mana': 20}),
 ('moonlight_elixir', 'Moonlight Elixir', 'potion', 2200, 5, {'heal': 99, 'energy': 200, 'mana': 99, 'buff': {'kind': 'luck', 'minutes': 600, 'amount': 3}, 'desc': 'Everything, all at once.'}),
 # vehicles (the vehicle workshop)
 ('scooter', 'Kick Scooter', 'vehicle', 600, 2, {'speed': 1.45, 'sprite': 'veh_scooter', 'size': 16, 'desc': 'Hold it and press USE to ride. Faster than walking; no tools while riding.'}),
 ('rowboat', 'Rowboat', 'vehicle', 900, 2, {'speed': 1.0, 'water': 1.5, 'sprite': 'veh_rowboat', 'size': 30, 'desc': 'Hold it and press USE at the water: row instead of swimming, fast and dry.'}),
 ('motor_scooter', 'Motor Scooter', 'vehicle', 2600, 3, {'speed': 1.9, 'sprite': 'veh_motor_scooter', 'size': 20, 'desc': 'Twice as fast as your feet.'}),
 ('balloon', 'Hot-Air Balloon', 'vehicle', 9000, 4, {'fly': True, 'sprite': 'veh_balloon', 'desc': 'Hold it and press USE beside a Balloon Mast (or Charter Pad) you built: fly to another one you built.'}),
 ('crystal_sled', 'Crystal Sled', 'vehicle', 2400, 3, {'speed': 1.7, 'snow': 2.3, 'sprite': 'veh_crystal_sled', 'size': 22, 'arc': 'penguins', 'desc': 'Fast anywhere; faster in winter and on the mountain.'}),
 ('getaway_car', 'Getaway Car', 'vehicle', 5200, 3, {'speed': 2.3, 'sprite': 'veh_getaway_car', 'size': 40, 'arc': 'gangsters', 'desc': 'Black, quiet, quick. Nobody saw you leave.'}),
 # rocket parts
 ('hull_plate', 'Hull Plate', 'craft', 900, 3, {}), ('rocket_engine', 'Rocket Engine', 'craft', 2600, 4, {}), ('fuel_cell', 'Fuel Cell', 'craft', 150, 3, {'desc': 'One launch each.'}),
 ('nav_computer', 'Nav Computer', 'craft', 2200, 4, {}), ('heat_shield', 'Heat Shield', 'craft', 1500, 4, {}),
 # gangster arc only
 ('blank_stock', 'Blank Stock', 'craft', 8, 1, {'arc': 'gangsters', 'desc': 'Paper with the right feel.'}), ('ink', 'Printing Ink', 'craft', 10, 1, {'arc': 'gangsters'}),
 ('bills_crude', 'Crude Bills', 'consumable', 20, 1, {'arc': 'gangsters', 'effect': 'counterfeit', 'face': 70, 'risk': 0.30, 'desc': 'Hold and USE in a town to pass them for ◆70. About 1 in 3 gets noticed.'}),
 ('bills_passable', 'Passable Bills', 'consumable', 35, 2, {'arc': 'gangsters', 'effect': 'counterfeit', 'face': 150, 'risk': 0.18, 'desc': 'Pass for ◆150. About 1 in 6 gets noticed.'}),
 ('bills_fine', 'Fine Bills', 'consumable', 60, 3, {'arc': 'gangsters', 'effect': 'counterfeit', 'face': 320, 'risk': 0.09, 'desc': 'Pass for ◆320. About 1 in 11 gets noticed.'}),
 ('bills_perfect', 'Perfect Bills', 'consumable', 120, 4, {'arc': 'gangsters', 'effect': 'counterfeit', 'face': 700, 'risk': 0.03, 'desc': 'Pass for ◆700. Even the bank blinks.'}),
 ('forged_permit', 'Forged Permit', 'consumable', 80, 2, {'arc': 'gangsters', 'effect': 'forged_permit', 'risk': 0.25, 'desc': 'USE it at home: your next building permit is "already stamped". 1 in 4 gets noticed.'}),
 # gangster arc: the chrome (hacking terminal, chrome clinic, robotics bench)
 ('circuit_board', 'Circuit Board', 'craft', 60, 2, {'arc': 'gangsters'}), ('data_chip', 'Data Chip', 'craft', 160, 2, {'arc': 'gangsters', 'desc': 'Somebody else\'s secrets, very small.'}),
 ('servo', 'Servo', 'craft', 90, 2, {'arc': 'gangsters'}),
 ('scrambler', 'Signal Scrambler', 'consumable', 180, 2, {'arc': 'gangsters', 'effect': 'scrub', 'amount': 2, 'desc': 'USE it: your face drops off two wanted lists. Heat -2.'}),
 ('ghost_ledger', 'Ghost Ledger', 'consumable', 900, 4, {'arc': 'gangsters', 'effect': 'scrub', 'amount': 5, 'desc': 'USE it: you were never here. Heat to zero.'}),
 ('emp_charge', 'EMP Charge', 'consumable', 140, 2, {'arc': 'gangsters', 'effect': 'emp', 'radius': 84, 'stun': 4.0, 'desc': 'USE it: everything near you locks up for 4 seconds, and any Gift stutters OPEN for 3.'}),
 ('emp_heavy', 'Blackout Charge', 'consumable', 420, 3, {'arc': 'gangsters', 'effect': 'emp', 'radius': 130, 'stun': 6.0, 'open': 5.0, 'desc': 'A whole block goes dark. Gifts stutter open for 5 seconds.'}),
 ('spy_drone', 'Spy Drone', 'consumable', 1200, 2, {'arc': 'gangsters', 'effect': 'drone', 'desc': 'USE it (recharges in 2 days): names who is here and how to beat each Gift.'}),
 ('scrap_bot', 'Scrap Bot', 'consumable', 220, 2, {'arc': 'gangsters', 'effect': 'bot', 'life': 30, 'dmg': 2, 'desc': 'USE it: a little bot plants itself and zaps anything hostile for 30 seconds.'}),
 ('guard_bot', 'Guard Bot', 'consumable', 600, 3, {'arc': 'gangsters', 'effect': 'bot', 'life': 60, 'dmg': 4, 'reach': 90, 'desc': 'A bigger bot. A minute of cover.'}),
 ('drone_swarm', 'Drone Swarm', 'consumable', 1500, 4, {'arc': 'gangsters', 'effect': 'bot', 'life': 45, 'dmg': 6, 'reach': 120, 'rate': 0.5, 'desc': 'Six drones, 45 seconds, no mercy for furniture.'}),
 ('optic_implant', 'Optic Implant', 'equip', 700, 2, {'arc': 'gangsters', 'slot': 'charm', 'stats': {'luck': 2, 'damage': 1}, 'desc': 'One eye glows a little. You see the tell before the swing.'}),
 ('optic_mk2', 'Optic Implant Mk II', 'equip', 2600, 4, {'arc': 'gangsters', 'slot': 'charm', 'stats': {'luck': 4, 'damage': 2}}),
 ('reflex_wires', 'Reflex Wires', 'equip', 800, 2, {'arc': 'gangsters', 'slot': 'belt', 'stats': {'speed': 2}, 'desc': 'Your hands arrive before you decide.'}),
 ('reflex_mk2', 'Reflex Wires Mk II', 'equip', 2800, 4, {'arc': 'gangsters', 'slot': 'belt', 'stats': {'speed': 3, 'defense': 2}}),
 ('chrome_arm', 'Chrome Arm', 'equip', 1600, 3, {'arc': 'gangsters', 'slot': 'offhand', 'stats': {'damage': 2, 'defense': 2}, 'desc': 'It hums. Handshakes are shorter now.'}),
 ('subdermal_plating', 'Subdermal Plating', 'equip', 1800, 3, {'arc': 'gangsters', 'slot': 'back', 'stats': {'defense': 5}}),
 ('neural_link', 'Neural Link', 'equip', 3200, 4, {'arc': 'gangsters', 'slot': 'ring', 'stats': {'mana': 20, 'luck': 3}, 'desc': 'More room for borrowed Gifts.'}),
 ('root_beer', 'Root Beer', 'food', 60, 1, {'arc': 'gangsters', 'energy': 35}), ('cream_soda', 'Cream Soda', 'food', 95, 2, {'arc': 'gangsters', 'energy': 45, 'buff': {'kind': 'speed', 'minutes': 120, 'amount': 1}}),
 ('cherry_fizz', 'Cherry Fizz', 'food', 55, 2, {'arc': 'gangsters', 'energy': 30, 'heal': 2}), ('golden_float', 'Golden Float', 'food', 420, 3, {'arc': 'gangsters', 'energy': 90, 'heal': 5, 'buff': {'kind': 'luck', 'minutes': 240, 'amount': 2}, 'friend': 4}),
]
for id, name, typ, val, tier, extra in G:
    item(id, name, typ, val, tier, **extra)
# Penguin arc only: crystal-shaped gear, Cat-topia's litter works, the campfire.
for id, name, typ, val, tier, extra in [
 ('marshmallow', 'Marshmallow', 'food', 20, 1, {'energy': 15}), ('toasted_marshmallow', 'Toasted Marshmallow', 'food', 45, 1, {'energy': 30}),
 ('smore', "S'more", 'food', 140, 2, {'energy': 55, 'heal': 2}), ('hot_cocoa', 'Hot Cocoa', 'food', 160, 2, {'energy': 45, 'buff': {'kind': 'warm', 'minutes': 480, 'amount': 1}, 'desc': 'Big Jim makes it too sweet. Warm for hours.'}),
 ('campfire_stew', "Big Jim's Stew", 'food', 240, 3, {'energy': 80, 'heal': 5}), ('starlight_smore', "Starlight S'more", 'food', 520, 3, {'energy': 100, 'heal': 4, 'buff': {'kind': 'luck', 'minutes': 300, 'amount': 2}, 'friend': 4}),
 ('scented_litter', 'Scented Litter Box', 'consumable', 40, 2, {'effect': 'stink', 'radius': 84, 'stun': 5.0, 'desc': 'Lavender. Somehow worse. A wider cloud, a longer nose-hold.'}),
 ('mega_litter', 'Mega Litter Box', 'consumable', 110, 3, {'effect': 'stink', 'radius': 120, 'stun': 7.0, 'desc': 'The catapult-sized one. Clears a room.'}),
 ('tuna_treat', 'Tuna Treat', 'food', 18, 1, {'energy': 8, 'friend': 3, 'desc': 'Every cat in Cat-topia wants one. So does your pup.'}),
 ('paw_lantern', 'Paw Lantern', 'consumable', 90, 2, {'buff': {'kind': 'luck', 'minutes': 180, 'amount': 1}, 'mana': 10, 'desc': 'A little jar of Meow Pow Wow light. Open it for luck and mana.'}),
 ('heart_spark', 'Heart Spark', 'consumable', 420, 3, {'mana': 60, 'heal': 6, 'desc': 'A rainbow heart in a bottle. Mana and health at once.'})]:
    extra['arc'] = 'penguins'; item(id, name, typ, val, tier, **extra)
I['litter_box'].update({'radius': 56, 'stun': 3.0})
for id, name, dmg, val, tier in [('icicle_blade', 'Icicle Blade', 3, 150, 1), ('fishbone_sabre', 'Fish-Bone Sabre', 5, 320, 2), ('aurora_blade', 'Aurora Blade', 5, 900, 2), ('prism_lance', 'Prism Lance', 7, 2200, 3), ('starheart_blade', 'Starheart Blade', 11, 5200, 4)]:
    item(id, name, 'tool', val, tier, damage=dmg, weapon=True, arc='penguins')
for id, name, slot, stats, val, tier in [
 ('snow_goggles', 'Snow Goggles', 'head', {'defense': 1, 'luck': 1}, 140, 1), ('aurora_hood', 'Aurora Hood', 'head', {'luck': 2, 'speed': 1}, 520, 3),
 ('puffy_parka', 'Puffy Parka', 'body', {'defense': 2, 'luck': 1}, 380, 2), ('crystal_parka', 'Crystal Parka', 'body', {'defense': 4}, 900, 3), ('starlight_mantle', 'Starlight Mantle', 'body', {'defense': 6, 'luck': 1}, 3200, 4),
 ('ice_cleats', 'Ice Cleats', 'feet', {'defense': 2}, 300, 2), ('mitten_paws', 'Mitten Paws', 'hands', {'damage': 1}, 260, 2),
 ('courage_scarf', 'Scarf of Courage', 'back', {'defense': 2, 'speed': 1}, 700, 3), ('flipper_belt', 'Flipper Belt', 'belt', {'speed': 1, 'damage': 1}, 480, 3), ('bell_collar', 'Bell Collar', 'charm', {'luck': 2}, 800, 3)]:
    item(id, name, 'equip', val, tier, slot=slot, stats=stats, arc='penguins')
# Gangster weapons (melee; "weapon" makes them swing like a sword) and street armor.
for id, name, dmg, val, tier in [('brass_knuckles', 'Brass Knuckles', 3, 150, 1), ('crowbar', 'Crowbar', 5, 320, 2), ('lucky_bat', 'Lucky Bat', 5, 900, 2), ('chrome_blade', 'Chrome Blade', 7, 2200, 3), ('neon_cleaver', 'Neon Cleaver', 11, 5200, 4)]:
    item(id, name, 'tool', val, tier, damage=dmg, weapon=True, arc='gangsters')
# Guns (gangster arc): ranged, one round a shot; out of rounds they're a clumsy club. Cartoon puffs, no blood.
item('rounds', 'Rounds', 'craft', 3, 1, arc='gangsters', desc='One per shot.')
for id, name, dmg, val, tier, extra in [('six_shooter', 'Six-Shooter', 4, 700, 2, {'range': 110, 'cd': 2.0}), ('scattergun', 'Scattergun', 6, 2000, 3, {'range': 64, 'spread': True, 'cd': 1.6}),
                                         ('tommy_gun', 'Tommy Gun', 2, 2600, 3, {'range': 120, 'cd': 0.6}), ('gold_revolver', 'Gold Revolver', 12, 5600, 4, {'range': 140, 'cd': 1.6})]:
    item(id, name, 'tool', val, tier, damage=dmg, weapon=True, arc='gangsters', **extra)
for id, name, slot, stats, val, tier in [
 ('fedora', 'Fedora', 'head', {'defense': 1, 'luck': 1}, 60, 1), ('shades', 'Shades', 'head', {'luck': 2, 'speed': 1}, 520, 3),
 ('pinstripe_suit', 'Pinstripe Suit', 'body', {'defense': 2, 'luck': 1}, 380, 2), ('padded_vest', 'Padded Vest', 'body', {'defense': 4}, 900, 3), ('armored_suit', 'Armored Suit', 'body', {'defense': 6, 'luck': 1}, 3200, 4),
 ('steel_toes', 'Steel-Toe Shoes', 'feet', {'defense': 2}, 300, 2), ('knuckle_gloves', 'Knuckle Gloves', 'hands', {'damage': 1}, 260, 2),
 ('trench_coat', 'Trench Coat', 'back', {'defense': 2, 'speed': 1}, 700, 3), ('tool_belt', "Driver's Belt", 'belt', {'speed': 1, 'damage': 1}, 480, 3), ('gold_chain', 'Gold Chain', 'charm', {'luck': 2}, 800, 3)]:
    item(id, name, 'equip', val, tier, slot=slot, stats=stats, arc='gangsters')

# C10a (c10_09): the six drawn arc costume sheets show when the suit is worn (PaperDoll outfit key), and
# every arc apparel piece says what it is.
for k, c in (('pinstripe_suit', 'pinstripe'), ('padded_vest', 'vest'), ('armored_suit', 'armored'),
             ('puffy_parka', 'parka'), ('crystal_parka', 'crystal_parka'), ('starlight_mantle', 'starlight')):
    if 'outfit_' + c in M.get('body', {}):
        I[k]['costume'] = 'outfit_' + c  # body sheet name (PaperDoll.body_for)
ARC_DESC = {'fedora': 'A sharp felt hat. Every crew boss has one.', 'shades': 'Dark lenses for bright neon nights.',
            'pinstripe_suit': 'A sharp suit with a little padding sewn in.', 'padded_vest': 'Quilted plates under plain cloth.',
            'armored_suit': 'Looks like a suit, stops like a wall.', 'steel_toes': 'Kick a crate, keep your toes.',
            'knuckle_gloves': 'Leather gloves with a hard knuckle.', 'trench_coat': 'Long coat, deep pockets, quick feet.',
            'tool_belt': "A driver's belt: tools close, hands free.", 'gold_chain': 'Heavy, shiny and oddly lucky.',
            'snow_goggles': 'Keeps the glare and the snow out.', 'aurora_hood': 'Shimmers like the northern lights.',
            'puffy_parka': 'Warm, round and surprisingly tough.', 'crystal_parka': 'A parka laced with crystal threads.',
            'starlight_mantle': 'Woven from moonweave. It glows a little.', 'ice_cleats': 'Spiked soles that never slip.',
            'mitten_paws': 'Cosy mittens with a firm grip.', 'courage_scarf': 'A scarf that makes you stand taller.',
            'flipper_belt': 'A belt with a little paddle flair.', 'bell_collar': 'Jingles softly. Lucky, they say.'}
for k, d in ARC_DESC.items():
    if k in I and not I[k].get('desc'):
        I[k]['desc'] = d

# ---- stations ------------------------------------------------------------------
SK = [1, 4, 9, 16]  # C16a P5 (c16a_09-17, c16a_10-12): was [1, 3, 5, 7] (all maxed in the first weeks)
def art(*names):
    for n in names:
        if n in M.get('stations', {}): return ('stations', n)
        if n in M.get('props', {}): return ('props', n)
    return ('props', names[0])
def val(cost): return sum(int(I.get(k, {}).get('value', 5)) * n for k, n in cost.items())
def station(id, label, cat, cell, skill, verb, seller, tiers, w=0, h=1, arc=None, book=None, kind='station', gate_skill=None):
    old = B.get(id, {})
    e = {'label': label, 'cell': cell, 'w': w, 'h': h, 'group': 'props', 'thing': 'station', 'cat': cat, 'seller': seller}
    if kind == 'station':
        e['station'] = {'skill': skill, 'verb': verb, 'book': book or id}
    if arc: e['arc'] = arc
    e['tiers'] = []
    for i, (name, sprites, cost, desc) in enumerate(tiers):
        g, s = art('st_%s_%d' % (id, i + 1), *sprites)
        t = {'tier': i + 1, 'name': name, 'sprite': s, 'group': g, 'cost': cost, 'permit': 0, 'days': 0 if i < 2 else i - 1, 'desc': desc,
             'price': int(round((val(cost) * 2.2 + 150 * (i + 1) ** 2) / 10.0) * 10), 'unlock': {}}
        if i > 0: t['unlock']['progress'] = i
        if SK[i] > 1: t['unlock']['skill'] = [gate_skill or skill, SK[i]]
        if not t['unlock']: del t['unlock']
        t['art_missing'] = s not in M.get(g, {})
        e['tiers'].append(t)
    B[id] = e

P = 'Slots {s}, {v}% faster, recipes to tier {c}.'
def d(i, extra=''):
    return ('%d job%s at once, %s recipes up to tier %d. ' % (i + 1, '' if i == 0 else 's', ['normal speed,', '15% faster,', '30% faster,', '45% faster,'][i], min(5, i + 2)) + extra).strip()

station('workbench', 'Workbench', 'workshop', [3, 15], 'building', 'Build', 'Hazel', [
 ('Workbench', ['workbench_t1', 'workbench3'], {'wood': 20}, d(0)),
 ("Carpenter's Bench", ['workbench_t2'], {'plank': 20, 'nails': 10, 'copper_bar': 2}, d(1)),
 ('Workshop', ['workbench_t3'], {'hardwood_plank': 15, 'gear': 4, 'iron_bar': 5}, d(2)),
 ('Master Workshop', ['workbench_t4', 'workbench_t3'], {'ironwood_beam': 4, 'plating': 4, 'crystal_glass': 2}, d(3))], w=1)
station('sawmill', 'Lumberyard', 'workshop', [6, 15], 'building', 'Saw', 'Hazel', [
 ('Sawhorse', ['sawhorse'], {'wood': 30, 'stone': 10}, d(0, 'Planks from logs.')),
 ('Lumberyard', ['lumberyard'], {'plank': 30, 'copper_bar': 3, 'nails': 10}, d(1)),
 ('Sawmill', ['sawmill'], {'beam': 12, 'gear': 6, 'iron_bar': 6}, d(2)),
 ('Steam Sawmill', ['sawmill_steam'], {'ironwood_beam': 2, 'plating': 4, 'spring': 6, 'dark_bar': 2}, d(3))], w=1)
station('furnace', 'Furnace', 'workshop', [9, 15], 'mining', 'Smelt', 'Gideon', [
 ('Stone Furnace', ['furnace_t1_off', 'furnace2_off'], {'stone': 20, 'copper': 5}, d(0, 'Ore into bars.')),
 ('Brick Furnace', ['furnace_t2_off'], {'brick': 30, 'copper_bar': 5, 'coal': 10}, d(1)),
 ('Blast Furnace', ['furnace_t3_off', 'furnace2_off'], {'brick': 60, 'steel_bar': 8, 'tile': 10}, d(2)),
 ('Starfire Furnace', ['furnace_t4_off', 'furnace2_on'], {'dark_bar': 6, 'crystal_glass': 4, 'crystal_battery': 2}, d(3))])
station('anvil', 'Anvil', 'workshop', [11, 15], 'mining', 'Forge', 'Gideon', [
 ('Field Anvil', ['anvil', 'forge_1'], {'copper_bar': 3, 'wood': 10}, d(0, 'Nails, tools, copper gear.')),
 ('Smithy', ['forge_2'], {'iron_bar': 8, 'brick': 20, 'plank': 10}, d(1)),
 ('Master Forge', ['forge_3'], {'steel_bar': 10, 'gear': 6, 'beam': 6}, d(2)),
 ('Starforge', ['forge_4'], {'dark_bar': 8, 'plating': 6, 'crystal_battery': 2}, d(3))])
station('loom', 'Loom', 'workshop', [6, 18], 'farming', 'Weave', 'Lumi', [
 ('Hand Loom', ['loom_1', 'loom'], {'wood': 25, 'fiber': 20}, d(0, 'Cloth, yarn, rope.')),
 ('Floor Loom', ['loom_2'], {'plank': 20, 'nails': 8, 'yarn': 6}, d(1)),
 ('Weaving Frame', ['loom_3', 'loom_2'], {'hardwood_plank': 12, 'gear': 4, 'cotton_cloth': 8}, d(2)),
 ('Moon Loom', ['loom_4', 'loom_2'], {'ironwood_beam': 2, 'fine_fabric': 6, 'crystal_glass': 2}, d(3))])
station('tannery', 'Tanning Rack', 'workshop', [9, 18], 'combat', 'Tan', 'Rook', [
 ('Tanning Rack', ['tanning_rack'], {'wood': 20, 'rope': 2}, d(0, 'Pelts into leather.')),
 ('Tannery', ['tannery_2', 'tanning_rack'], {'plank': 16, 'nails': 8, 'leather': 4}, d(1)),
 ("Leatherworker's Shop", ['tannery_3', 'tanning_rack'], {'beam': 8, 'gear': 2, 'cooking_oil': 6}, d(2)),
 ("Master Saddler's", ['tannery_4', 'tanning_rack'], {'ironwood_beam': 2, 'fine_leather': 8, 'plating': 2}, d(3))])
station('kitchen', 'Cooking Pot', 'pantry', [3, 21], 'farming', 'Cook', 'Posy', [
 ('Cooking Pot', ['stove_1'], {'stone': 10, 'wood': 5}, d(0, 'Also sets what the house kitchen can do.')),
 ('Iron Stove', ['stove_2'], {'iron_bar': 4, 'brick': 20, 'clay_pot': 4}, d(1)),
 ('Kitchen Range', ['stove_3'], {'steel_bar': 6, 'tile': 16, 'gear': 2}, d(2)),
 ('Grand Range', ['stove_4'], {'plating': 4, 'crystal_glass': 4, 'gold_bar': 2}, d(3))])
station('keg', 'Keg', 'pantry', [3, 24], 'farming', 'Brew', 'Tam', [
 ('Keg', ['keg2', 'keg'], {'wood': 30, 'copper_bar': 1}, d(0, 'Anything you grow, given time.')),
 ('Oak Barrel', ['keg3'], {'plank': 24, 'nails': 10, 'iron_bar': 2}, d(1)),
 ('Fermenting Vat', ['keg_4', 'keg3'], {'hardwood_plank': 16, 'steel_bar': 4, 'glass': 10}, d(2)),
 ('Cellar Vats', ['keg_5', 'keg3'], {'ironwood_beam': 2, 'plating': 4, 'crystal_glass': 4}, d(3))])
station('press', 'Pantry Press', 'pantry', [6, 24], 'farming', 'Press', 'Tam', [
 ('Cheese Press', ['cheese_press'], {'wood': 20, 'stone': 10, 'fiber': 6}, d(0, 'Cheese, butter, jam, oil.')),
 ('Oil Press', ['oil_press'], {'plank': 16, 'iron_bar': 3, 'clay_pot': 6}, d(1)),
 ('Preserving Room', ['preserves_jar2', 'preserves_jar'], {'beam': 6, 'glass': 16, 'gear': 3}, d(2)),
 ('Creamery', ['creamery', 'cheese_press'], {'plating': 3, 'crystal_glass': 4, 'tile': 20}, d(3))])
# Ranch processing (C11a P3): two-tier stations beside the pantry row.
station('mayo', 'Mayo Machine', 'pantry', [13, 24], 'ranching', 'Whip', 'Hazel', [
 ('Mayo Machine', ['mayo_1', 'mayo_machine_1', 'mayo_machine'], {'plank': 15, 'copper_bar': 2, 'clay_pot': 2}, d(0, 'Eggs into mayonnaise.')),
 ('Deluxe Mayo Machine', ['mayo_2', 'mayo_machine_2', 'mayo_machine_1', 'mayo_machine'], {'iron_bar': 4, 'glass': 6, 'gear': 2}, d(1, 'Duck eggs and big eggs too.'))])
station('extractor', 'Honey Extractor', 'pantry', [13, 21], 'ranching', 'Spin', 'Hazel', [
 ('Honey Extractor', ['extractor_1', 'honey_extractor'], {'plank': 12, 'copper_bar': 2, 'glass': 4}, d(0, 'Honeycomb into honey and beeswax.')),
 ('Honey House', ['extractor_2', 'honey_extractor'], {'iron_bar': 4, 'glass': 10, 'gear': 2}, d(1, 'Jars of honey and beeswax candles.'))])
station('kiln', 'Kiln', 'workshop', [3, 18], 'mining', 'Fire', 'Granite', [
 ('Clay Kiln', ['kiln', 'glass_kiln'], {'stone': 30, 'clay': 10}, d(0, 'Bricks, pots, glass.')),
 ('Brick Kiln', ['kiln_2', 'glass_kiln'], {'brick': 40, 'copper_bar': 3}, d(1)),
 ('Glassworks', ['glass_kiln'], {'brick': 60, 'steel_bar': 4, 'tile': 12}, d(2)),
 ('Crystal Kiln', ['kiln_4', 'glass_kiln'], {'dark_bar': 3, 'crystal_glass': 4, 'crystal_refined': 6}, d(3))])
station('jeweler', "Jeweller's Bench", 'workshop', [11, 18], 'mining', 'Set', 'Ivy', [
 ("Tinker's Tray", ['jeweller_bench'], {'plank': 10, 'copper_bar': 2}, d(0, 'Rings and charms.')),
 ("Jeweller's Bench", ['jeweller_bench_2', 'jeweller_bench'], {'hardwood_plank': 6, 'glass': 6, 'silver_bar': 2}, d(1)),
 ("Gem-Cutter's Bench", ['jeweller_bench_3', 'jeweller_bench'], {'veneer': 4, 'crystal_glass': 2, 'gold_bar': 3}, d(2)),
 ('Star Setting Bench', ['jeweller_bench_4', 'jeweller_bench'], {'ironwood_beam': 1, 'moon_bar': 1, 'crystal_battery': 2}, d(3))])
station('cauldron', 'Magic Potion Station', 'workshop', [11, 21], 'foraging', 'Brew', 'Wren', [
 ('Bubbling Pot', ['cauldron_1', 'cauldron2'], {'stone': 15, 'copper_bar': 2, 'wild_herb': 5}, d(0, 'Remedies and red potions.')),
 ('Cauldron', ['cauldron_2'], {'iron_bar': 5, 'brick': 16, 'glass': 6}, d(1, 'Swift, luck and hearth brews.')),
 ('Arcane Cauldron', ['cauldron_3'], {'silver_bar': 4, 'crystal_glass': 3, 'crystal_refined': 4}, d(2, 'Growth elixir, stoneskin.')),
 ('Starfire Cauldron', ['cauldron_4'], {'dark_bar': 4, 'moonweave': 2, 'crystal_battery': 3}, d(3, 'Moonlight elixir.'))])
station('resonator', 'Crystal Resonator', 'workshop', [16, 16], 'mining', 'Tune', 'Sel', [
 ('Crystal Resonator', ['resonator'], {'stone': 10, 'shard': 1}, d(0, 'Shards into refined crystal.')),
 ('Twin Resonator', ['resonator_2', 'resonator'], {'crystal_refined': 4, 'copper_bar': 4, 'glass': 4}, d(1)),
 ('Prism Array', ['resonator_3', 'resonator'], {'crystal_glass': 4, 'silver_bar': 4, 'gear': 4}, d(2)),
 ('Star Array', ['resonator_4', 'resonator'], {'crystal_battery': 4, 'moon_bar': 1, 'plating': 4}, d(3))])
station('garage', 'Vehicle Workshop', 'projects', [8, 27], 'building', 'Assemble', 'Benno', [
 ('Wheel Shed', ['garage_1', 'farm_cart'], {'plank': 30, 'nails': 16, 'wheel': 2}, d(0, 'A kick scooter.')),
 ('Boat & Cart Shop', ['garage_2', 'farm_cart'], {'beam': 12, 'gear': 6, 'sail': 2}, d(1, 'A rowboat.')),
 ('Motor Works', ['garage_3', 'farm_cart'], {'plating': 6, 'spring': 8, 'crystal_battery': 1}, d(2, 'Engines.')),
 ('Sky Dock', ['garage_4', 'balloon'], {'ironwood_beam': 4, 'moonweave': 4, 'crystal_battery': 3}, d(3, 'A hot-air balloon.'))], w=2, h=2)
station('launchpad', 'Rocket Yard', 'projects', [15, 27], 'building', 'Assemble', 'Theo', [
 ('Launch Scaffold', ['rocket_1'], {'beam': 20, 'brick': 60, 'nails': 40}, d(0, 'Build rocket parts here.')),
 ('Rocket Frame', ['rocket_2'], {'hull_plate': 6, 'gear': 10, 'spring': 10}, d(1, 'A hull on the pad.')),
 ('Fuelled Rocket', ['rocket_3'], {'rocket_engine': 2, 'heat_shield': 2, 'hull_plate': 4}, d(2, 'LAUNCH: fly to the moon (1 fuel cell a trip).')),
 ('Starship', ['rocket_4'], {'nav_computer': 1, 'rocket_engine': 2, 'moon_bar': 2, 'moonweave': 4}, d(3, 'Also flies to the star station.'))], w=1, h=3, book='rocket')
for t, pr in zip(B['launchpad']['tiers'], [1, 2, 3, 3]): t.setdefault('unlock', {})['progress'] = pr
B['launchpad']['tiers'][0]['unlock']['skill'] = ['building', 4]
for t, sk in zip(B['launchpad']['tiers'][1:], [5, 7, 9]): t['unlock']['skill'] = ['building', sk]  # the gate never drops (C8 P2)
# Keg brews carry the input's value (C8 P2; read by Crafting._keg_recipes and tools/econ_check.py):
# a brew is worth about `mult` x its produce, never more than `cap` x (cheap produce takes several per brew),
# produce worth premium_at or more makes the family's premium good, and one brew gives at most max_out.
B['keg']['brew'] = {'mult': 2.0, 'cap': 3.0, 'max_out': 12, 'premium_at': 200,
                    'premium': {'grain': 'reserve_ale', 'flower': 'royal_mead', 'veg': 'gourmet_pickles', 'herb': 'herbal_cordial', 'mushroom': 'truffle_broth'}}
# ---- gangster arc only ---------------------------------------------------------
station('print_shop', 'Back-Room Press', 'operation', [9, 24], 'bartering', 'Print', 'Specs', [
 ('Back-Room Press', ['press_1'], {'plank': 16, 'nails': 8, 'copper_bar': 2}, d(0, 'Crude bills: hold one and USE it in town to pass it. Risky: a noticed bill raises heat.')),
 ('Offset Press', ['press_2'], {'gear': 6, 'iron_bar': 6, 'linen': 10}, d(1, 'Passable bills, forged permits.')),
 ('Engraving Press', ['press_3'], {'plating': 4, 'spring': 6, 'fine_fabric': 4}, d(2, 'Fine bills.')),
 ('The Mint', ['press_4'], {'dark_bar': 4, 'gold_bar': 6, 'crystal_glass': 4}, d(3, 'Perfect bills.'))], arc='gangsters', book='print')
station('armory', 'Street Armory', 'operation', [11, 24], 'combat', 'Fit', 'Vic', [
 ('Trunk of Tools', ['armory_1', 'forge_anvil_tools'], {'plank': 12, 'copper_bar': 4, 'leather': 2}, d(0, 'Knuckles, a fedora, rounds.')),
 ('Back-Alley Armory', ['armory_2', 'forge_anvil_tools'], {'iron_bar': 8, 'leather': 6, 'cotton_cloth': 4}, d(1, 'Crowbar, bat, six-shooter, suits.')),
 ("Fixer's Workshop", ['armory_3', 'forge_anvil_tools'], {'steel_bar': 10, 'fine_leather': 4, 'gear': 6}, d(2, 'Chrome, tommy gun, scattergun.')),
 ('The Vault', ['armory_4', 'forge_anvil_tools'], {'dark_bar': 8, 'plating': 6, 'fine_fabric': 6}, d(3, 'Neon and armor.'))], arc='gangsters')
station('soda', 'Soda Fountain', 'operation', [3, 27], 'bartering', 'Mix', 'Mama Rosa', [
 ('Soda Cart', ['soda_1'], {'plank': 14, 'glass': 6, 'copper_bar': 2}, d(0, 'Root beer. A front with a real queue.')),
 ('Soda Fountain', ['soda_2'], {'brick': 30, 'glass': 16, 'iron_bar': 4}, d(1)),
 ('Parlour', ['soda_3'], {'tile': 24, 'crystal_glass': 2, 'veneer': 4}, d(2)),
 ('The Gold Room', ['soda_4'], {'gold_bar': 6, 'crystal_glass': 6, 'moonweave': 2}, d(3))], arc='gangsters')
station('laundromat', 'Laundromat', 'operation', [5, 27], 'bartering', '', 'Deuce', [
 ('Wash Tub', ['laundry_1'], {'plank': 20, 'copper_bar': 4, 'fiber': 18}, 'Leave up to 3 bills overnight: paid at 80% with no risk. Heat cools 1 extra a night.'),
 ('Laundromat', ['laundry_2'], {'brick': 40, 'iron_bar': 8, 'gear': 4}, 'Washes 6 bills a night at 85%.'),
 ('Cleaners & Sons', ['laundry_3'], {'tile': 30, 'plating': 4, 'spring': 8}, 'Washes 10 bills a night at 90%.')], w=1, arc='gangsters', kind='building')
station('training', 'Recruit Training Center', 'operation', [18, 27], 'combat', '', 'Val', [
 ('Back-Lot Gym', ['gym_1'], {'plank': 30, 'rope': 8, 'leather': 6}, 'Spar once a day for combat XP. +10 max health.'),
 ('Training Hall', ['gym_2'], {'beam': 16, 'brick': 60, 'steel_bar': 6}, "Every crew member's perk counts one loyalty step higher. Sparring pays double."),
 ('The Academy', ['gym_3'], {'ironwood_beam': 4, 'plating': 8, 'fine_fabric': 8}, 'Crew perks count two loyalty steps higher. +20 max health.')], w=2, h=2, arc='gangsters', kind='building')
station('terminal', 'Hacking Terminal', 'operation', [6, 21], 'bartering', 'Hack', 'Specs', [
 ('Salvaged Terminal', ['terminal_1'], {'plank': 10, 'copper_bar': 4, 'glass': 4}, d(0, 'Circuit boards, data chips.')),
 ('Hacking Terminal', ['terminal_2'], {'iron_bar': 6, 'glass': 10, 'gear': 4}, d(1, 'Scramblers, EMP charges.')),
 ('Server Rack', ['terminal_3'], {'steel_bar': 8, 'crystal_glass': 2, 'spring': 6}, d(2, 'Blackout charges.')),
 ('The Mainframe', ['terminal_4'], {'dark_bar': 4, 'crystal_battery': 3, 'plating': 4}, d(3, 'The Ghost Ledger.'))], arc='gangsters', book='hack')
station('clinic', 'Chrome Clinic', 'operation', [9, 21], 'combat', 'Fit', 'Doc', [
 ('Back-Room Chair', ['clinic_1'], {'plank': 14, 'iron_bar': 4, 'fiber': 18}, d(0, 'Nothing yet: Doc wants better tools.')),
 ('Chrome Clinic', ['clinic_2'], {'steel_bar': 4, 'glass': 12, 'cotton_cloth': 6}, d(1, 'Optics and reflex wires.')),
 ('Augment Lab', ['clinic_3'], {'plating': 4, 'crystal_glass': 3, 'gear': 6}, d(2, 'A chrome arm, plating under the skin.')),
 ('The Clean Room', ['clinic_4'], {'dark_bar': 4, 'crystal_battery': 3, 'fine_fabric': 4}, d(3, 'Mk II implants, the neural link.'))], arc='gangsters', book='implant')
station('robotics', 'Robotics Bench', 'operation', [12, 27], 'building', 'Assemble', 'Ladder', [
 ('Tinker Bench', ['robotics_1'], {'plank': 16, 'gear': 4, 'copper_bar': 4}, d(0, 'Servos.')),
 ('Robotics Bench', ['robotics_2'], {'iron_bar': 8, 'gear': 8, 'spring': 4}, d(1, 'Scrap bots and the spy drone.')),
 ('Drone Bay', ['robotics_3'], {'steel_bar': 8, 'plating': 3, 'crystal_battery': 1}, d(2, 'Guard bots.')),
 ('The Hive', ['robotics_4'], {'dark_bar': 4, 'crystal_battery': 4, 'plating': 6}, d(3, 'A drone swarm.'))], arc='gangsters', book='robot')
# C11b integ: the Gene Splicer (gangster arc) makes the lab strains (ranch.json species[*].lab); a finished
# splice is handed over by Crafting.collect as the animal itself, through RanchGift.give (book 'splice').
station('gene_splicer', 'Gene Splicer', 'operation', [18, 23], 'ranching', 'Splice', 'Specs', [
 ('Splice Rig', ['gene_splicer'], {'plank': 12, 'copper_bar': 6, 'glass': 6, 'circuit_board': 2}, d(0, 'Chrome hens and turbo bunnies.')),
 ('Gene Splicer', ['gene_splicer'], {'iron_bar': 8, 'glass': 10, 'circuit_board': 4, 'gear': 4}, d(1, 'Glow sheep, circuit goats and cows.')),
 ('Gene Lab', ['gene_splicer'], {'steel_bar': 8, 'crystal_glass': 2, 'data_chip': 3, 'plating': 2}, d(2, 'Drone hogs, volt geckos, chrome runners.'))], arc='gangsters', book='splice')
# ---- penguin arc only ----------------------------------------------------------
station('shaper', 'Crystal Shaper', 'sanctuary', [9, 24], 'combat', 'Shape', 'Catkins', [
 ('Shard Table', ['shaper_1'], {'plank': 12, 'shard': 4, 'copper_bar': 2}, d(0, 'An icicle blade, snow goggles.')),
 ('Crystal Shaper', ['shaper_2'], {'iron_bar': 8, 'crystal_refined': 4, 'cotton_cloth': 4}, d(1, 'Sabre, parka, cleats.')),
 ('Prism Workshop', ['shaper_3'], {'steel_bar': 10, 'crystal_glass': 4, 'gear': 6}, d(2, 'Prism lance, aurora gear.')),
 ('Heart of Light', ['shaper_4'], {'dark_bar': 8, 'crystal_battery': 4, 'fine_fabric': 6}, d(3, 'The Starheart Blade.'))], arc='penguins')
station('litter', 'Litter Works', 'sanctuary', [11, 24], 'foraging', 'Pack', 'Catkins', [
 ('Sand Tray', ['litter_1'], {'plank': 12, 'sand': 20, 'clay': 6}, d(0, "Litter boxes: Cat-topia's secret weapon.")),
 ('Litter Works', ['litter_2'], {'brick': 30, 'clay_pot': 8, 'iron_bar': 4}, d(1, 'Scented boxes, paw lanterns.')),
 ('Catapult Yard', ['litter_3'], {'beam': 12, 'gear': 6, 'rope': 12}, d(2, 'Mega boxes, heart sparks.')),
 ('Grand Catapult', ['litter_4'], {'ironwood_beam': 3, 'spring': 10, 'crystal_battery': 2}, d(3))], arc='penguins')
station('campfire', "Big Jim's Campfire", 'sanctuary', [3, 27], 'foraging', 'Toast', 'Big Jim', [
 ('Campfire', ['campfire_1'], {'stone': 12, 'wood': 20}, d(0, 'Marshmallows on a stick.')),
 ('Fire Ring', ['campfire_2'], {'brick': 24, 'iron_bar': 3, 'plank': 12}, d(1, "S'mores and cocoa.")),
 ('Cook Camp', ['campfire_3'], {'tile': 16, 'steel_bar': 4, 'sail': 2}, d(2, "Big Jim's stew.")),
 ('Aurora Camp', ['campfire_4'], {'crystal_glass': 4, 'moonweave': 2, 'gold_bar': 3}, d(3))], arc='penguins')
station('pool', 'Merkitty Pool', 'sanctuary', [5, 27], 'fishing', '', 'Mer', [
 ('Tide Pool', ['pool_1'], {'stone': 40, 'clay': 12, 'sand': 20}, 'The merkitties leave 1 gift from the lake each morning. Fish bite a little faster for you.'),
 ('Singing Pool', ['pool_2'], {'brick': 40, 'glass': 12, 'copper_bar': 6}, '2 gifts a morning, sometimes a pearl.'),
 ('Moon Grotto', ['pool_3'], {'tile': 30, 'crystal_glass': 4, 'silver_bar': 4}, '3 gifts a morning; rare fish and pearls.')], w=1, arc='penguins', kind='building')
station('burrow', 'Crystal Baby Burrow', 'sanctuary', [18, 27], 'mining', '', 'Coldy', [
 ('Cosy Burrow', ['burrow_1'], {'plank': 30, 'cloth': 8, 'stone': 40}, 'The babies you turned back dig for you overnight: stone, coal, copper, a shard.'),
 ('Baby Dig', ['burrow_2'], {'beam': 16, 'brick': 60, 'yarn': 10}, 'More diggers; iron and shards.'),
 ('Stomping Grounds', ['burrow_3'], {'ironwood_beam': 4, 'plating': 6, 'fine_fabric': 8}, 'Silver, gold and refined crystal turn up.')], w=2, h=2, arc='penguins', kind='building')
station('shrine', 'Meow Pow Wow Shrine', 'sanctuary', [18, 23], 'magic', '', 'Catkins', [
 ('Paw Stone', ['shrine_1'], {'stone': 30, 'crystal_bloom': 6, 'shard': 3}, 'Practise once a day: mana back and magic XP. +5 max mana.'),
 ('Heart Shrine', ['shrine_2'], {'brick': 40, 'crystal_refined': 6, 'starflower': 3}, 'Your Meow Pow Wow counts one rank stronger. Practice pays double.'),
 ('Rainbow Shrine', ['shrine_3'], {'crystal_glass': 6, 'moonweave': 3, 'star_dust': 4}, 'Two ranks stronger. +15 max mana.')], arc='penguins', kind='building')
B['burrow']['tiers'][0].setdefault('unlock', {})['progress'] = 2
B['burrow']['tiers'][1]['unlock']['progress'] = 2
B['shrine']['tiers'][0].setdefault('unlock', {})['progress'] = 1
for t in B['pool']['tiers']: t.setdefault('unlock', {})
# Story order: the sanctuary opens as you meet who it is for.
B['pool']['tiers'][0]['unlock']['flag'] = 'merkitty_done'
B['burrow']['tiers'][0]['unlock']['flag'] = 'babies_done'
B['shrine']['tiers'][0]['unlock']['flag'] = 'meow_taught'
# Locked plans say what opens them (Builds.gate shows "hint" instead of "story first").
B['pool']['tiers'][0]['unlock']['hint'] = 'meet the merkitties at the lake shore'
B['burrow']['tiers'][0]['unlock']['hint'] = 'turn back the crystal babies on the mountain'
B['shrine']['tiers'][0]['unlock']['hint'] = 'learn the Meow Pow Wow from Catkins'
B['mill']['thing'] = 'station'; B['mill']['station'] = {'skill': 'farming', 'verb': 'Mill', 'book': 'mill'}; B['mill']['cat'] = 'pantry'
for k, v in B.items():
    if isinstance(v, dict) and 'cat' not in v: v['cat'] = 'farm'
for k in ('chest', 'well', 'beehive', 'scarecrow'): B[k]['cat'] = 'farm'

# Upgrades of the older farm buildings now take worked goods, and everything has a ready-made price.
for bid, tier, cost in [('house', 2, {'plank': 80, 'brick': 60, 'nails': 30, 'copper_bar': 5}), ('house', 3, {'beam': 40, 'tile': 60, 'iron_bar': 10, 'glass': 20}),
                        ('shed', 2, {'plank': 50, 'nails': 30, 'copper_bar': 4})]:
    for t in B[bid]['tiers']:
        if t['tier'] == tier: t['cost'] = cost
# ---- ranch buildings (C11a P3) ------------------------------------------------------
# Every ranch building tier lives here (the old hand-kept coop/barn/silo/stable/beehive entries
# and the tier-2 cost patch are gone). Prices/permits/days/gates/sellers come from this table;
# capacity, perks ("adds"), pens and footprints come from data/ranch.json "buildings" (gen_ranch.py,
# runs before this). Builds id -> Ranch home: coop, barn, hutch, sty, beehive = "apiary", stable.
# The Ranching tree gates the hutch and sty (blueprints) and every tier 3 (skill level).
RJ = json.load(open(D + 'ranch.json')) if os.path.exists(D + 'ranch.json') else {}
RB = RJ.get('buildings', {}) if isinstance(RJ.get('buildings'), dict) else {}
RANCH_HOME = {'coop': 'coop', 'barn': 'barn', 'hutch': 'hutch', 'sty': 'sty', 'beehive': 'apiary', 'stable': 'stable',
              'enclosure': 'enclosure', 'aviary': 'aviary', 'terrarium': 'terrarium', 'tide_pool': 'tide_pool', 'ember_pit': 'ember_pit', 'star_dome': 'star_dome'}
RANCH_ARC = {h: a for h, a in RJ.get('home_arc', {}).items()}  # penguin-arc habitats (gen_ranch HOME_ARC)
ADDS_WORD = {'feeder': 'a silo feeder', 'incubator': 'an incubator', 'auto_water': 'automatic water', 'heater': 'a heater for winter',
             'breeding': 'a breeding pen', 'perch': 'perches', 'big_stall': 'big stalls', 'moon_lamp': 'a moon lamp'}
def bart(*names):
    for n in names:
        for g in ('props', 'buildings', 'stations'):  # legacy props first; P6's new tiers live in buildings/
            if n in M.get(g, {}): return (g, n)
    raise SystemExit('gen_stations: no art for ranch tier %s' % (names,))
#  id: (label, seller, seller_gangsters, thing, default cell/w/h, [(name, gang name, sprites, cost, permit, days, unlock, desc)])
RANCH = {
 'coop': ('Coop', 'Hazel', 'The crew', '', ([26, 8], 3, 3), [
   ('Coop', 'Coop', ['coop_1', 'coop_small'], {'wood': 120, 'stone': 40}, 500, 1, {}, 'Chickens: eggs every morning you care for them.'),
   ('Big Coop', 'Big Coop', ['coop_2', 'coop_big'], {'plank': 60, 'nails': 30, 'copper_bar': 3}, 1800, 2, {'skill': ['building', 3]}, 'Room for ducks too; birds eat silo hay.'),
   ('Deluxe Coop', 'Deluxe Coop', ['coop_3', 'coop_deluxe', 'coop_big'], {'hardwood_plank': 20, 'glass': 12, 'iron_bar': 6}, 4500, 3, {'skill': ['ranching', 5], 'progress': 1}, 'The biggest flock, warm all winter.')]),
 'barn': ('Barn', 'Benno', 'The crew', '', ([32, 5], 4, 3), [
   ('Barn', 'Barn', ['barn_1', 'barn_small'], {'wood': 200, 'stone': 80}, 1000, 2, {}, 'Cows and sheep: milk and wool.'),
   ('Big Barn', 'Big Barn', ['barn_2', 'barn_big'], {'beam': 30, 'brick': 60, 'iron_bar': 4}, 3500, 3, {'skill': ['building', 5]}, 'Goats and llamas too; barn animals eat silo hay.'),
   ('Deluxe Barn', 'Deluxe Barn', ['barn_3', 'barn_deluxe', 'barn_big'], {'beam': 40, 'tile': 30, 'steel_bar': 6}, 8000, 3, {'skill': ['ranching', 7], 'progress': 2}, 'A big herd, warm all winter.'),
   ('Grand Barn', 'Freight Barn', ['barn_4'], {'beam': 60, 'steel_bar': 10, 'glass': 20}, 15000, 4, {'skill': ['ranching', 9], 'progress': 3}, 'The biggest herd, with big stalls and a paddock in the pasture.')]),
 'hutch': ('Rabbit Hutch', 'Hazel', 'The crew', 'hutch', ([38, 9], 2, 2), [
   ('Rabbit Hutch', 'Rabbit Hutch', ['hutch_1', 'coop_small'], {'wood': 60, 'fiber': 20, 'plank': 10}, 400, 1, {}, 'Rabbits: soft fur for the loom.'),
   ('Big Hutch', 'Big Hutch', ['hutch_2', 'hutch_1', 'coop_small'], {'plank': 30, 'nails': 16, 'copper_bar': 2}, 1500, 2, {'skill': ['ranching', 4]}, 'More rabbits.')]),
 'sty': ('Pig Sty', 'Benno', 'The crew', 'sty', ([41, 9], 3, 2), [
   ('Pig Sty', 'Pig Pen', ['sty_1', 'pig_pen'], {'wood': 100, 'stone': 40}, 1200, 1, {}, 'Pigs: they dig up truffles outdoors.'),
   ('Big Sty', 'Big Pig Pen', ['sty_2', 'sty_1', 'pig_pen'], {'plank': 40, 'brick': 30, 'iron_bar': 3}, 4000, 2, {'skill': ['ranching', 6]}, 'More pigs.')]),
 'beehive': ('Apiary', 'Hazel', 'The crew', 'beehive', ([29, 19], 0, 1), [
   ('Beehive', 'Beehive', ['apiary_1', 'beehive3_a'], {'wood': 15, 'fiber': 10}, 150, 0, {}, 'Honey every few days; flowers nearby make it finer.'),
   ('Bee House', 'Bee House', ['apiary_2', 'beehive2', 'beehive3_b'], {'plank': 20, 'nails': 10, 'glass': 4}, 600, 1, {'skill': ['ranching', 3]}, 'More hives, more honey.'),
   ('Apiary', 'Apiary', ['apiary_3', 'apiary_2', 'ri_beehive4', 'beehive3_b'], {'hardwood_plank': 10, 'glass': 10, 'gear': 2}, 1500, 2, {'skill': ['ranching', 6]}, 'A whole row of hives.')]),
 'silo': ('Silo', 'Benno', 'The crew', 'silo', ([30, 4], 1, 3), [
   ('Silo', 'Silo', ['silo_1', 'silo2'], {'stone': 60, 'wood': 30}, 200, 1, {}, 'Stores 240 hay. Scythed hay and wheat chaff go straight in; tap to store or take hay.'),
   ('Tall Silo', 'Tall Silo', ['silo_2', 'farm_silo_b', 'silo2'], {'brick': 60, 'plank': 30, 'iron_bar': 2}, 800, 1, {'skill': ['ranching', 2]}, 'Stores 480 hay: enough for a winter with a full coop.'),
   ('Twin Silo', 'Twin Silo', ['silo_3', 'farm_silo_b', 'silo2'], {'brick': 100, 'beam': 12, 'steel_bar': 3}, 2000, 2, {'skill': ['ranching', 5]}, 'Stores 720 hay: a whole ranch through winter.')]),
 'enclosure': ('Exotic Enclosure', 'Hazel', 'The crew', '', ([50, 13], 4, 3), [
   ('Exotic Enclosure', 'Exotics Yard', ['enclosure_1'], {'beam': 20, 'plank': 60, 'iron_bar': 4}, 3000, 2, {'skill': ['ranching', 5], 'progress': 1}, 'A big sandy run with a shade roof: ostriches and emus.'),
   ('Grand Enclosure', 'Big Exotics Yard', ['enclosure_2'], {'beam': 40, 'brick': 80, 'gold_bar': 3}, 7500, 3, {'skill': ['ranching', 8], 'progress': 2}, 'Warm rocks and a big-egg incubator: room for a drake.')]),
 'aviary': ('Aviary', 'Hazel', 'The crew', '', ([57, 13], 3, 3), [
   ('Aviary', 'Drone Loft', ['aviary_1'], {'plank': 50, 'nails': 30, 'iron_bar': 3}, 2000, 2, {'skill': ['ranching', 4], 'progress': 1}, 'A tall mesh house with perches: peacocks and big flying birds.'),
   ('Grand Aviary', 'Big Drone Loft', ['aviary_2'], {'hardwood_plank': 20, 'glass': 16, 'gold_bar': 2}, 5000, 3, {'skill': ['ranching', 7], 'progress': 2}, 'More perches, an incubator and a heater.')]),
 'terrarium': ('Terrarium', 'Posy', 'The crew', '', ([40, 19], 3, 2), [
   ('Terrarium', 'Grow Tank', ['terrarium_1'], {'glass': 20, 'plank': 20, 'copper_bar': 3}, 1500, 2, {'skill': ['ranching', 4], 'progress': 1}, 'A warm glass house: tortoises, geckos and glowing bugs.'),
   ('Grand Terrarium', 'Big Grow Tank', ['terrarium_2'], {'crystal_glass': 4, 'glass': 20, 'iron_bar': 4}, 4000, 3, {'skill': ['ranching', 7], 'progress': 2}, 'Misters and room for little ones.')]),
 'tide_pool': ('Tide Pool', 'Hazel', 'The crew', '', ([45, 19], 3, 2), [
   ('Tide Pool', 'Tide Pool', ['tide_pool_1'], {'stone': 80, 'glass': 12, 'clay_pot': 6}, 3000, 2, {'skill': ['ranching', 6], 'progress': 3}, 'A cool salt-water pool for creatures from the sea.')]),
 'ember_pit': ('Ember Pit', 'Hazel', 'The crew', '', ([50, 19], 2, 2), [
   ('Ember Pit', 'Ember Pit', ['ember_pit_1'], {'brick': 60, 'stone': 40, 'coal': 20}, 2500, 2, {'skill': ['ranching', 6], 'progress': 3}, 'Warm rocks that glow all year: newts love it.')]),
 'star_dome': ('Star Dome', 'Hazel', 'The crew', '', ([55, 19], 3, 3), [
   ('Star Dome', 'Star Dome', ['star_dome_1'], {'crystal_glass': 6, 'moon_bar': 2, 'beam': 20}, 4000, 3, {'skill': ['ranching', 7], 'progress': 3}, 'A night-sky dome for creatures from the Moon and the far north.')]),
 'stable': ('Stable', 'Benno', 'The crew', '', ([32, 11], 3, 3), [
   ('Stable', 'Stable', ['stable_1', 'stable2'], {'wood': 150, 'iron_bar': 2}, 300, 2, {'friend': ['benno', 2]}, 'Your horse sleeps here; it rides 10% faster.')]),
}
BLUEPRINT_GATED = {'hutch', 'sty'}  # Ranching tree blueprints (gen_skill_trees.py UNLOCKS); Builds.gate checks tier 1
def ranch_desc(bid, i, base):
    rows = [r for r in RB.get(RANCH_HOME.get(bid, bid), []) if isinstance(r, dict) and int(r.get('tier', 0)) == i + 1]
    if not rows: return base
    r = rows[0]; bits = []
    if int(r.get('cap', 0)) > 0:
        bits.append('Room for %d.' % int(r['cap']) if bid != 'beehive' else 'Holds %d hives.' % int(r['cap']))
    new = [a for a in r.get('adds', []) if a in ADDS_WORD]
    if i > 0:
        prev = [x for x in RB.get(RANCH_HOME.get(bid, bid), []) if isinstance(x, dict) and int(x.get('tier', 0)) == i]
        if prev: new = [a for a in new if a not in prev[0].get('adds', [])]
    if new:
        bits.append('Adds ' + ', '.join(ADDS_WORD[a] for a in new) + '.')
    return (base + ' ' + ' '.join(bits)).strip()
for bid, (label, seller, gseller, thing, (cell, w, h), tiers) in RANCH.items():
    old = B.get(bid, {})
    home = RANCH_HOME.get(bid, bid)
    rb0 = next((r for r in RB.get(home, []) if isinstance(r, dict) and r.get('cell')), {})
    e = {'label': label, 'cell': list(rb0.get('cell', old.get('cell', cell))), 'w': int(rb0.get('w', old.get('w', w))),
         'h': int(rb0.get('h', old.get('h', h))), 'group': 'props', 'cat': 'farm', 'seller': seller, 'seller_gang': gseller, 'ranch': home}
    if thing: e['thing'] = thing
    if RANCH_ARC.get(home): e['arc'] = RANCH_ARC[home]
    for k in ('anim',):
        if k in old: e[k] = old[k]
    e['tiers'] = []
    for i, (name, gname, sprites, cost, permit, days, unlock, desc) in enumerate(tiers):
        g, sp = bart(*sprites)
        t = {'tier': i + 1, 'name': name, 'sprite': sp, 'group': g, 'cost': cost, 'permit': permit, 'days': days,
             'desc': ranch_desc(bid, i, desc), 'price': int(round((val(cost) * 2.2 + 150 * (i + 1) ** 2) / 10.0) * 10)}
        if unlock: t['unlock'] = dict(unlock)
        if gname != name: t['name_gang'] = gname  # C11b P6: Builds._arc_words; tier rows may grow (cell/w/h)
        t.update({k: rr[k] for rr in RB.get(home, []) if isinstance(rr, dict) and int(rr.get('tier', 0)) == i + 1 for k in ('cell', 'w', 'h') if k in rr and i > 0})
        if bid in BLUEPRINT_GATED and i == 0:
            t.setdefault('unlock', {})['hint'] = 'learn the %s Blueprint (Ranching tree)' % ('Hutch' if bid == 'hutch' else 'Sty')
        if i > 0 and 'skill' in t.get('unlock', {}) and t['unlock']['skill'][0] == 'ranching':
            t['unlock']['hint'] = 'Ranching level %d' % t['unlock']['skill'][1]
        e['tiers'].append(t)
    B[bid] = e

for k, v in B.items():
    if isinstance(v, dict):
        v.setdefault('seller', 'Hazel')
        for t in v.get('tiers', []):
            if 'price' not in t and t.get('cost'):
                t['price'] = int(round((val(t['cost']) * 2.2 + 150 * t['tier'] ** 2) / 10.0) * 10)

# ---- recipe books --------------------------------------------------------------
def rc(id, name, need, give=None, tier=1, n=1, **kw):
    r = {'id': id, 'name': name, 'need': need, 'give': give or id, 'tier': tier}
    if n != 1: r['n'] = n
    r.update(kw); return r
old = {r['id']: r for st in ('workbench', 'smith', 'kitchen', 'alchemy', 'mill', 'furnace', 'anvil', 'loom', 'tannery', 'jeweler', 'cauldron') for r in R.get(st, [])}
def keep(*ids): return [old[i] for i in ids if i in old]
for r in old.values():
    if r['id'] == 'iron_helm': r['tier'] = 2  # same tier as the rest of the iron set
# (the Crystal armour set is appended below, so those 8 aren't kept from the old book: no duplicates)
CRYSTAL_SET = {'crystal_' + s for s in ('helm', 'chest', 'legs', 'boots', 'gloves', 'shield', 'cape', 'belt')}
metal_gear = [r for r in old.values() if r['id'] not in CRYSTAL_SET and r['id'].split('_')[0] in ('copper', 'iron', 'steel', 'silver', 'gold', 'crystal') and r['id'].split('_')[-1] in ('helm', 'chest', 'legs', 'boots', 'gloves', 'shield', 'cape', 'belt', 'mail', 'greaves', 'plate', 'sword')]
leather_gear = [r for r in old.values() if r['id'].startswith('leather_') and r['id'] not in ('leather', 'leather_scrap')]
books = {}
books['workbench'] = keep('torch', 'chest', 'scarecrow', 'fertilizer', 'sprinkler', 'sprinkler_quality', 'bait', 'straw_hat', 'pup_treat') + [
 rc('fence_kit', 'Shingles', {'plank': 4, 'nails': 2}, 'shingles', 1, 6), rc('wheel', 'Cart Wheel', {'plank': 6, 'nails': 4, 'iron_bar': 1}, tier=2), rc('sprinkler_iridium', 'Iridium Sprinkler', {'gold_bar': 2, 'iron_bar': 2, 'crystal_refined': 3}, tier=4)]
books['sawmill'] = [rc('plank', 'Plank', {'wood': 2}, n=1), rc('charcoal', 'Charcoal (burns as coal)', {'wood': 6}, 'coal', 1, 2), rc('beam', 'Timber Beam', {'wood': 12}, tier=2),
 rc('hardwood_plank', 'Hardwood Plank', {'hardwood': 1}, tier=2), rc('veneer', 'Fine Veneer', {'hardwood_plank': 3, 'sap': 2}, tier=3), rc('ironwood_beam', 'Ironwood Beam', {'hardwood_plank': 6, 'beam': 2, 'dark': 1}, tier=4)]
books['furnace'] = keep('copper_bar', 'iron_bar', 'steel_bar', 'silver_bar', 'gold_bar') + [rc('dark_bar', 'Shadowsteel Bar', {'dark': 5, 'coal': 4}, tier=4), rc('moon_bar', 'Moonsilver Bar', {'moon_shard': 2, 'silver_bar': 2}, tier=5)]
books['anvil'] = [rc('nails', 'Nails', {'copper_bar': 1}, n=10), rc('horseshoe', 'Horseshoe', {'copper_bar': 1}), rc('gear', 'Gear', {'iron_bar': 1}, tier=2), rc('spring', 'Spring', {'iron_bar': 1, 'coal': 1}, tier=2),
 rc('plating', 'Steel Plating', {'steel_bar': 2, 'coal': 2}, tier=3)] + sorted(metal_gear, key=lambda r: (r['tier'], r['id'])) + keep('pup_collar_iron', 'pup_boots')
books['loom'] = keep('rope', 'cloth') + [rc('yarn', 'Yarn', {'sheep_wool': 1, 'fiber': 1}, n=2), rc('linen', 'Linen', {'flax': 2}), rc('cotton_cloth', 'Cotton Cloth', {'cotton': 2}, tier=2),
 rc('sail', 'Sailcloth', {'linen': 3, 'rope': 2}, tier=2), rc('fine_fabric', 'Fine Fabric', {'cotton_cloth': 1, 'linen': 1, 'yarn': 1}, tier=3), rc('moonweave', 'Moonweave', {'fine_fabric': 2, 'star_dust': 1}, tier=4)] + keep(
 'work_shirt', 'outfit_farmer', 'outfit_forester', 'outfit_fisher', 'outfit_miner', 'outfit_merchant', 'outfit_scholar', 'outfit_neon', 'outfit_penguin')
books['tannery'] = [rc('leather', 'Leather', {'pelt': 1}, tier=1), rc('leather_scrap', 'Leather (from wings)', {'bat_wing': 2, 'slime_gel': 1}, 'leather', 1), rc('fine_leather', 'Fine Leather', {'leather': 2, 'cooking_oil': 1}, tier=3)] + sorted(leather_gear, key=lambda r: r['id']) + keep(
 'boots', 'running_shoes', 'pup_collar_leather', 'pup_pack_small', 'pup_pack_large')
books['kitchen'] = R['kitchen'] if 'kitchen' in R else []
books['mill'] = R['mill']
books['press'] = [rc('cheese', 'Cheese', {'milk': 1}), rc('butter', 'Butter', {'milk': 1}), rc('jam', 'Jam', {'#berry': 3}), rc('cooking_oil', 'Cooking Oil', {'sunflower': 2}), rc('sesame_oil', 'Cooking Oil (sesame)', {'sesame': 2}, 'cooking_oil', 2, 2),
 rc('pickles', 'Pickles', {'#veg': 2, 'clay_pot': 1}, tier=2, n=2), rc('dried_fruit', 'Dried Fruit', {'#tree': 2}, tier=2), rc('wine_reserve', 'Fine Wine (from fruit wine)', {'fruit_wine': 2, '#herb': 1}, 'fine_wine', 3)]
books['kiln'] = [rc('brick', 'Brick', {'clay': 1}, n=2), rc('stone_brick', 'Brick (from stone)', {'stone': 4, 'coal': 1}, 'brick', 1, 2), rc('clay_pot', 'Clay Pot', {'clay': 2}), rc('glass', 'Glass', {'sand': 3, 'coal': 1}),
 rc('tile', 'Glazed Tile', {'brick': 2, 'sand': 1}, tier=2), rc('lens', 'Glass Lens', {'glass': 2, 'sand': 2}, tier=2), rc('crystal_glass', 'Crystal Glass', {'glass': 2, 'crystal_refined': 1}, tier=3)]
books['mayo'] = [rc('mayonnaise', 'Mayonnaise', {'egg': 1}), rc('duck_mayonnaise', 'Duck Mayonnaise', {'duck_egg': 1}, tier=2)]
books['extractor'] = [rc('honey_comb', 'Honey (from honeycomb)', {'honeycomb': 1}, 'honey', 1, 2), rc('beeswax', 'Beeswax', {'honeycomb': 1}, n=2),
 rc('honey_jar', 'Jar of Honey', {'honey': 3, 'glass': 1}, tier=2), rc('beeswax_candle', 'Beeswax Candle', {'beeswax': 2, 'fiber': 1}, tier=2)]
books['jeweler'] = keep('copper_ring', 'paw_charm', 'silver_ring', 'ruby_ring', 'crystal_lens', 'pup_collar_crystal', 'crystal_crown', 'light_charm', 'moon_ring', 'dream_charm')
books['cauldron'] = keep('herb_remedy', 'energy_tea', 'potion', 'dream_tonic', 'cloud_walkers') + [
 rc('hearth_brew', 'Hearth Brew', {'#herb': 1, 'honey': 1, 'clay_pot': 1}), rc('mana_potion', 'Mana Potion', {'flower': 2, 'glass': 1, 'light_mote': 1}, tier=2),
 rc('swift_draught', 'Swift Draught', {'#herb': 2, 'glass': 1, 'slime_gel': 1}, tier=2), rc('luck_potion', 'Luck Potion', {'#flower': 2, 'glass': 1, 'old_coin': 1}, tier=2),
 rc('greater_potion', 'Greater Potion', {'potion': 2, '#mushroom': 1, 'glass': 1}, tier=3), rc('stoneskin_tonic', 'Stoneskin Tonic', {'#mushroom': 2, 'crystal_glass': 1, 'quarry_dust': 2}, tier=3),
 rc('growth_elixir', 'Growth Elixir', {'fertilizer': 3, '#magic': 1, 'crystal_glass': 1}, tier=3), rc('moonlight_elixir', 'Moonlight Elixir', {'greater_potion': 1, 'moon_tear': 1, 'star_dust': 2, 'crystal_glass': 1}, tier=5)]
books['resonator'] = [rc('crystal_refined', 'Refined Crystal', {'shard': 3}, tier=1), rc('crystal_battery', 'Crystal Battery', {'crystal_refined': 2, 'copper_bar': 1, 'glass': 1}, tier=3)]
books['garage'] = [rc('scooter', 'Kick Scooter', {'plank': 6, 'wheel': 2, 'nails': 10}, tier=1, vehicle=True), rc('rowboat', 'Rowboat', {'plank': 30, 'beam': 4, 'nails': 30, 'rope': 4}, tier=2, vehicle=True),
 rc('motor_scooter', 'Motor Scooter', {'scooter': 1, 'gear': 8, 'spring': 4, 'crystal_battery': 1}, tier=3, vehicle=True),
 rc('crystal_sled', 'Crystal Sled', {'hardwood_plank': 10, 'plating': 2, 'crystal_refined': 4}, tier=3, vehicle=True, arc='penguins'),
 rc('getaway_car', 'Getaway Car', {'plating': 8, 'wheel': 4, 'gear': 10, 'crystal_battery': 2, 'fine_leather': 2}, tier=3, vehicle=True, arc='gangsters'),
 rc('balloon', 'Hot-Air Balloon', {'moonweave': 6, 'sail': 6, 'rope': 12, 'hardwood_plank': 8, 'crystal_battery': 1}, tier=5, vehicle=True)]
books['rocket'] = [rc('fuel_cell', 'Fuel Cell', {'lamp_oil': 4, 'glass': 2, 'coal': 6}, tier=2, n=2), rc('hull_plate', 'Hull Plate', {'plating': 2, 'nails': 20}, tier=2),
 rc('heat_shield', 'Heat Shield', {'tile': 12, 'moonweave': 1, 'plating': 1}, tier=3), rc('rocket_engine', 'Rocket Engine', {'plating': 3, 'gear': 8, 'spring': 6, 'crystal_battery': 2}, tier=3),
 rc('nav_computer', 'Nav Computer', {'crystal_lens': 2, 'gear': 6, 'gold_bar': 2, 'crystal_battery': 2}, tier=4)]
books['print'] = [rc('blank_stock', 'Blank Stock', {'fiber': 8}, n=4), rc('ink', 'Printing Ink', {'coal': 1, 'sap': 1}, n=2), rc('bills_crude', 'Crude Bills', {'blank_stock': 2, 'ink': 1}, n=2),
 rc('bills_passable', 'Passable Bills', {'blank_stock': 2, 'ink': 2, 'linen': 1}, tier=2, n=2), rc('forged_permit', 'Forged Permit', {'blank_stock': 3, 'ink': 2, 'old_coin': 1}, tier=2),
 rc('bills_fine', 'Fine Bills', {'blank_stock': 2, 'ink': 2, 'fine_fabric': 1}, tier=3, n=2), rc('bills_perfect', 'Perfect Bills', {'blank_stock': 2, 'ink': 3, 'moonweave': 1, 'gold_bar': 1}, tier=5, n=4)]
books['armory'] = [rc('brass_knuckles', 'Brass Knuckles', {'copper_bar': 3}, tool=True), rc('rounds', 'Rounds', {'copper_bar': 1, 'coal': 1}, n=40), rc('six_shooter', 'Six-Shooter', {'iron_bar': 4, 'gear': 2, 'hardwood_plank': 1}, tier=2, tool=True), rc('scattergun', 'Scattergun', {'steel_bar': 4, 'spring': 3, 'hardwood_plank': 2}, tier=3, tool=True), rc('tommy_gun', 'Tommy Gun', {'steel_bar': 5, 'spring': 6, 'gear': 6}, tier=3, tool=True), rc('gold_revolver', 'Gold Revolver', {'gold_bar': 4, 'dark_bar': 2, 'spring': 4}, tier=4, tool=True), rc('fedora', 'Fedora', {'fiber': 6, 'leather': 1}), rc('crowbar', 'Crowbar', {'iron_bar': 3}, tier=2, tool=True),
 rc('lucky_bat', 'Lucky Bat', {'hardwood_plank': 3, 'nails': 10, 'horseshoe': 1, 'iron_bar': 1}, tier=2, tool=True), rc('pinstripe_suit', 'Pinstripe Suit', {'cotton_cloth': 4, 'linen': 2}, tier=2),
 rc('steel_toes', 'Steel-Toe Shoes', {'leather': 2, 'iron_bar': 1}, tier=2), rc('knuckle_gloves', 'Knuckle Gloves', {'leather': 2, 'copper_bar': 2}, tier=2),
 rc('chrome_blade', 'Chrome Blade', {'steel_bar': 5, 'plating': 1, 'fine_leather': 1}, tier=3, tool=True, skill=['combat', 5]), rc('padded_vest', 'Padded Vest', {'fine_leather': 3, 'cotton_cloth': 4, 'plating': 1}, tier=3),
 rc('trench_coat', 'Trench Coat', {'fine_fabric': 3, 'fine_leather': 1}, tier=3), rc('tool_belt', "Driver's Belt", {'fine_leather': 2, 'gear': 2}, tier=3), rc('shades', 'Shades', {'crystal_glass': 1, 'silver_bar': 1}, tier=3),
 rc('gold_chain', 'Gold Chain', {'gold_bar': 2}, tier=3), rc('neon_cleaver', 'Neon Cleaver', {'dark_bar': 4, 'crystal_battery': 1, 'plating': 2}, tier=4, tool=True, skill=['combat', 8]),
 rc('armored_suit', 'Armored Suit', {'pinstripe_suit': 1, 'plating': 4, 'moonweave': 1}, tier=4)]
books['shaper'] = [rc('icicle_blade', 'Icicle Blade', {'shard': 3, 'copper_bar': 1}, tool=True), rc('snow_goggles', 'Snow Goggles', {'glass': 2, 'leather': 1}), rc('fishbone_sabre', 'Fish-Bone Sabre', {'iron_bar': 2, 'bone': 6}, tier=2, tool=True),
 rc('aurora_blade', 'Aurora Blade', {'iron_bar': 3, 'crystal_refined': 2, 'light_mote': 2}, tier=2, tool=True), rc('puffy_parka', 'Puffy Parka', {'cotton_cloth': 4, 'yarn': 3}, tier=2),
 rc('ice_cleats', 'Ice Cleats', {'leather': 2, 'iron_bar': 1}, tier=2), rc('mitten_paws', 'Mitten Paws', {'yarn': 4, 'leather': 1}, tier=2),
 rc('prism_lance', 'Prism Lance', {'steel_bar': 4, 'crystal_glass': 2, 'fine_leather': 1}, tier=3, tool=True, skill=['combat', 5]), rc('crystal_parka', 'Crystal Parka', {'puffy_parka': 1, 'crystal_refined': 4, 'plating': 1}, tier=3),
 rc('courage_scarf', 'Scarf of Courage', {'fine_fabric': 3, 'yarn': 4}, tier=3), rc('flipper_belt', 'Flipper Belt', {'fine_leather': 2, 'gear': 2}, tier=3), rc('aurora_hood', 'Aurora Hood', {'fine_fabric': 2, 'crystal_glass': 1}, tier=3),
 rc('bell_collar', 'Bell Collar', {'gold_bar': 2}, tier=3), rc('starheart_blade', 'Starheart Blade', {'dark_bar': 3, 'crystal_battery': 2, 'star_dust': 2}, tier=4, tool=True, skill=['combat', 8]),
 rc('starlight_mantle', 'Starlight Mantle', {'crystal_parka': 1, 'moonweave': 2, 'crystal_battery': 1}, tier=4)]
books['litter'] = [rc('litter_box', 'Litter Box', {'sand': 4, 'clay': 1}, n=2), rc('tuna_treat', 'Tuna Treat', {'minnow': 2}), rc('scented_litter', 'Scented Litter Box', {'litter_box': 1, '#herb': 1}, tier=2),
 rc('paw_lantern', 'Paw Lantern', {'glass': 1, 'light_mote': 1, 'crystal_bloom': 1}, tier=2), rc('mega_litter', 'Mega Litter Box', {'scented_litter': 2, 'clay_pot': 1}, tier=3), rc('heart_spark', 'Heart Spark', {'paw_lantern': 1, 'crystal_refined': 1, 'starflower': 1}, tier=3)]
books['campfire'] = [rc('marshmallow', 'Marshmallow', {'sugar_beet': 1, 'egg': 1}, n=4), rc('toasted_marshmallow', 'Toasted Marshmallow', {'marshmallow': 1}), rc('smore', "S'more", {'toasted_marshmallow': 1, 'chocolate': 1, 'bread': 1}, tier=2, n=2),
 rc('hot_cocoa', 'Hot Cocoa', {'cacao': 1, 'milk': 1, 'marshmallow': 1}, tier=2), rc('campfire_stew', "Big Jim's Stew", {'#veg': 3, '#mushroom': 1, 'trout': 1}, tier=3), rc('starlight_smore', "Starlight S'more", {'smore': 1, 'starflower': 1, 'honey': 1}, tier=3)]
books['soda'] = [rc('root_beer', 'Root Beer', {'#herb': 1, 'honey': 1}, n=2), rc('cream_soda', 'Cream Soda', {'milk': 1, 'honey': 1, 'vanilla': 1}, tier=2, n=2),
 rc('cherry_fizz', 'Cherry Fizz', {'#berry': 3, 'glass': 1}, tier=2, n=2), rc('golden_float', 'Golden Float', {'cream_soda': 1, 'butter': 1, '#magic': 1}, tier=3)]
books['hack'] = [rc('circuit_board', 'Circuit Board', {'copper_bar': 1, 'glass': 1}, n=2), rc('data_chip', 'Data Chip', {'circuit_board': 1, 'crystal_refined': 1}), rc('scrambler', 'Signal Scrambler', {'data_chip': 1, 'ink': 1}, tier=2),
 rc('emp_charge', 'EMP Charge', {'circuit_board': 2, 'spring': 1, 'coal': 2}, tier=2, n=2), rc('emp_heavy', 'Blackout Charge', {'emp_charge': 2, 'crystal_battery': 1}, tier=3), rc('ghost_ledger', 'Ghost Ledger', {'data_chip': 4, 'bills_fine': 2, 'crystal_battery': 1}, tier=4)]
books['implant'] = [rc('optic_implant', 'Optic Implant', {'lens': 2, 'circuit_board': 2, 'silver_bar': 1}, tier=2), rc('reflex_wires', 'Reflex Wires', {'spring': 4, 'circuit_board': 2, 'copper_bar': 3}, tier=2),
 rc('chrome_arm', 'Chrome Arm', {'plating': 3, 'servo': 4, 'data_chip': 1}, tier=3), rc('subdermal_plating', 'Subdermal Plating', {'plating': 4, 'fine_leather': 2}, tier=3),
 rc('optic_mk2', 'Optic Implant Mk II', {'optic_implant': 1, 'crystal_lens': 1, 'data_chip': 2}, tier=4), rc('reflex_mk2', 'Reflex Wires Mk II', {'reflex_wires': 1, 'crystal_battery': 1, 'servo': 4}, tier=4),
 rc('neural_link', 'Neural Link', {'data_chip': 4, 'gold_bar': 2, 'crystal_battery': 2}, tier=4)]
books['robot'] = [rc('servo', 'Servo', {'gear': 2, 'spring': 1}, n=2), rc('scrap_bot', 'Scrap Bot', {'servo': 2, 'circuit_board': 1, 'iron_bar': 2}, tier=2), rc('spy_drone', 'Spy Drone', {'servo': 4, 'lens': 2, 'circuit_board': 2, 'data_chip': 1}, tier=2),
 rc('guard_bot', 'Guard Bot', {'servo': 4, 'plating': 2, 'data_chip': 1, 'crystal_battery': 1}, tier=3), rc('drone_swarm', 'Drone Swarm', {'servo': 12, 'data_chip': 3, 'crystal_battery': 2}, tier=4)]
books['splice'] = []
for _sid, _sp in sorted((RJ.get('species', {}) if isinstance(RJ.get('species'), dict) else {}).items()):
    _lab = _sp.get('lab') or {}
    if _lab.get('station') != 'gene_splicer':
        continue
    item('splice_' + _sid, '%s Splice Kit' % _sp.get('name_gang', _sid), 'splice', 0, min(5, int(_lab.get('tier', 1)) + 1),
         arc='gangsters', icon=_sp.get('product', {}).get('id', 'circuit_board'),
         desc='A finished splice: the %s moves into your %s (or waits for room).' % (_sp.get('name_gang', _sid), _sp.get('home', 'farm')))
    books['splice'].append(rc('splice_' + _sid, 'Splice: %s' % _sp.get('name_gang', _sid), dict(_lab.get('need', {})), tier=int(_lab.get('tier', 1)), days=1))
# The armour pieces nothing made before (audit loop 3): Crystal and Moon sets,
# +1 tempering for every set, the Neon Jacket.
SLOTS = {'helm': 2, 'chest': 4, 'legs': 3, 'boots': 2, 'gloves': 1, 'shield': 3, 'cape': 2, 'belt': 1}   # same bar counts as the copper..gold sets
# 1) Crystal set: anvil recipe tier 4 (needs Smithy t3 + Mining Lv7), the step after gold
# Raw goods that only exist once tools/gen_ranch.py has written them (C11a P1): recipes join when their inputs do.
for bk, r in [('mayo', rc('big_mayo', 'Mayonnaise (big egg)', {'large_egg': 1}, 'mayonnaise', 2, 2)),
              ('mayo', rc('golden_mayo', 'Mayonnaise (golden egg)', {'golden_egg': 1}, 'duck_mayonnaise', 2, 6)),
              ('loom', rc('down_pillow', 'Down Pillow', {'feather': 2, 'cloth': 1})),
              ('loom', rc('angora_yarn', 'Yarn (rabbit fur)', {'rabbit_fur': 1}, 'yarn', 1, 3)),
              ('press', rc('big_cheese', 'Cheese (big milk)', {'large_milk': 1}, 'cheese', 1, 2)),
              # C11b creature goods (c11b_01-07, c11b_03-03): every new good goes somewhere, ~1.2-2.4x like the classics
              ('kitchen', rc('grand_omelette', 'Grand Omelette', {'ostrich_egg': 1, '#herb': 1}, tier=2)),
              ('kitchen', rc('grand_omelette_emu', 'Grand Omelette (emu egg)', {'emu_egg': 1, '#herb': 1, 'butter': 1}, 'grand_omelette', 2)),
              ('kitchen', rc('giant_egg_custard', 'Giant Egg Custard', {'crystal_egg': 1, 'milk': 1, 'honey': 1}, tier=3)),
              ('kitchen', rc('giant_egg_custard_emu', 'Giant Egg Custard (emu egg)', {'emu_egg': 1, 'milk': 1}, 'giant_egg_custard', 2)),
              ('loom', rc('fine_yarn', 'Fine Yarn', {'alpaca_fleece': 1}, tier=2)),
              ('loom', rc('fine_yarn_yak', 'Fine Yarn (yak wool)', {'yak_wool': 1}, 'fine_yarn', 2)),
              ('loom', rc('star_yarn', 'Star Yarn', {'star_wool': 1}, tier=3)),
              ('loom', rc('star_yarn_moon', 'Star Yarn (moon fluff)', {'moon_fluff': 2}, 'star_yarn', 3)),
              ('loom', rc('star_yarn_aurora', 'Star Yarn (aurora tuft)', {'aurora_tuft': 2}, 'star_yarn', 3)),
              ('loom', rc('cloud_yarn', 'Cloud Yarn', {'storm_fluff': 1}, tier=3)),
              ('loom', rc('glow_yarn', 'Glow Yarn', {'glow_wool': 1}, tier=2)),
              ('loom', rc('glow_yarn_static', 'Glow Yarn (static fluff)', {'static_fluff': 1}, 'glow_yarn', 2)),
              ('loom', rc('wisp_silk', 'Glow Silk (wisp thread)', {'wisp_thread': 1}, 'glow_silk', 3)),
              ('loom', rc('glow_silk_fabric', 'Fine Fabric (glow silk)', {'glow_silk': 1, 'cotton_cloth': 1}, 'fine_fabric', 3)),
              ('loom', rc('feather_fan', 'Feather Fan', {'peacock_feather': 2}, tier=2)),
              ('loom', rc('feather_fan_plume', 'Feather Fan (plumes)', {'plume': 2}, 'feather_fan', 2)),
              ('loom', rc('feather_fan_roc', 'Feather Fan (roc feather)', {'roc_feather': 1, 'cloth': 1}, 'feather_fan', 3)),
              ('press', rc('buffalo_mozzarella', 'Buffalo Mozzarella', {'buffalo_milk': 1}, tier=2)),
              ('press', rc('moon_cheese', 'Moon Cheese', {'moon_milk': 1}, tier=3)),
              ('press', rc('sea_cheese', 'Cheese (sea milk)', {'sea_milk': 1}, 'cheese', 2, 2)),
              ('press', rc('moss_tea_blend', 'Moss Tea Blend', {'shell_moss': 1, '#herb': 1}, tier=2)),
              ('jeweler', rc('scale_charm', 'Scale Charm', {'shed_scale': 1, 'silver_bar': 1}, tier=3)),
              ('jeweler', rc('ember_charm', 'Ember Charm', {'ember_scale': 1, 'copper_bar': 1}, tier=2)),
              ('hack', rc('crack_circuit_egg', 'Crack a Circuit Egg', {'circuit_egg': 1}, 'circuit_board', 1, 2)),
              ('hack', rc('crack_alloy_egg', 'Crack an Alloy Egg', {'alloy_egg': 1}, 'circuit_board', 3, 6)),
              ('robot', rc('battery_coolant', 'Crystal Battery (coolant)', {'coolant': 6, 'copper_bar': 1}, 'crystal_battery', 3)),
              ('robot', rc('battery_synth', 'Crystal Battery (synth milk)', {'synth_milk': 6, 'copper_bar': 1}, 'crystal_battery', 3)),
              ('robot', rc('battery_static', 'Crystal Battery (static scales)', {'static_scale': 4, 'copper_bar': 1}, 'crystal_battery', 3))]:
    if all(k in I or k.startswith('#') for k in r['need']) and r['give'] in I:
        books[bk] = [x for x in books[bk] if x['id'] != r['id']]   # kitchen/mill books are read back from recipes.json
        books[bk].append(r)
books['anvil'] += [rc('crystal_' + s, I['crystal_' + s]['name'], {'crystal_refined': n, 'gold_bar': 1, 'leather': 1}, tier=4) for s, n in SLOTS.items()]
# 2) Moon set: anvil recipe tier 5 (Starforge t4 + Mining Lv9): one or two moon bars, not four
books['anvil'] += [rc('moon_' + s, I['moon_' + s]['name'], {'moon_bar': 1 if n <= 2 else 2, 'crystal_refined': n, 'fine_leather': 1}, tier=5) for s, n in SLOTS.items()]
# 3) Temper: base piece + its metal (+ a catalyst) -> "+1". Anvil for metal, crystal and moon; tannery for leather.
TEMPER = {  # set: (book, tier, extra need)
 'leather': ('tannery', 2, {'leather': 2, 'slime_gel': 1}),
 'copper':  ('anvil', 2, {'copper_bar': 1, 'coal': 2}),
 'iron':    ('anvil', 3, {'iron_bar': 1, 'coal': 2}),
 'steel':   ('anvil', 3, {'steel_bar': 1, 'coal': 2}),
 'silver':  ('anvil', 4, {'silver_bar': 1, 'coal': 2}),
 'gold':    ('anvil', 4, {'gold_bar': 1, 'coal': 2}),
 'crystal': ('anvil', 5, {'crystal_refined': 2, 'light_mote': 1}),
 'moon':    ('anvil', 5, {'crystal_refined': 2, 'star_dust': 2})}
for m, (bk, t, extra) in TEMPER.items():
    for s in SLOTS:
        base = '%s_%s' % (m, s)
        books[bk].append(rc('temper_' + base, 'Temper: ' + I[base]['name'], dict({base: 1}, **extra), base + '_plus', t))
        # A tempered piece looks like its base piece (else it draws nothing when worn).
        if base + '_plus' in I and I[base].get('sprite') and not I[base + '_plus'].get('sprite'):
            I[base + '_plus']['sprite'] = I[base]['sprite']
        # A tempered piece must be better than its base (gloves +5 energy, cape +1 defence, belts +1 to each stat).
        if base + '_plus' in I and I[base + '_plus'].get('stats') == I[base].get('stats'):
            st = dict(I[base].get('stats', {}))
            I[base + '_plus']['stats'] = {k: v + 5 for k, v in st.items()} if 'energy' in st else (dict(st, defense=st.get('defense', 0) + 1) if 'speed' in st else {k: v + 1 for k, v in st.items()})
# 4) Neon Jacket (the Vault's "neon"): gangster armory, recipe tier 3
books['armory'].append(rc('neon_jacket', 'Neon Jacket', {'outfit_neon': 1, 'fine_leather': 2, 'circuit_board': 2}, tier=3))
# 5) Values that don't lose money and can't loop (below the 1.1 buy floor)
for bk in ('anvil', 'tannery', 'armory'):
    for r in books[bk]:
        if r['id'].startswith(('crystal_', 'moon_', 'temper_', 'neon_')):
            I[r['give']]['value'] = max(int(I[r['give']].get('value', 0)), int(0.8 * val(r['need'])))

# 6) Decor and wearables (C10a): gen_decor.py lists its craftable pieces in data/decor.json "recipes";
# they join the books here (gen_stations rebuilds every book, so it must import them). Decor is a money
# sink: crafted decor saves money against the shop price but never earns (value capped below the inputs).
DEC = json.load(open(D + 'decor.json')) if os.path.exists(D + 'decor.json') else {}
DECOR_IDS = set()
for dr in DEC.get('recipes', []):
    if dr['book'] in books and dr['id'] in I and all(k in I or k.startswith('#') for k in dr['need']):
        books[dr['book']].append(rc(dr['id'], dr['name'], dict(dr['need']), tier=int(dr.get('tier', 1)), decor=True))
        DECOR_IDS.add(dr['id'])

# ---- economy pass (C8 P2) ---------------------------------------------------------
# Every number here is checked by tools/econ_check.py (in check.sh).
ECON = {'craft_floor': 1.15,   # intermediates (craft/material/bar) sell for >= 1.15 x their inputs
        'goods_floor': 1.2,    # food/potion/consumable/placeable/gift made at a station: >= 1.2 x inputs
        'armour_floor': 0.7,   # metal/leather set pieces: >= 0.7 x their bars (slot and metal both show)
        'loop_cap': 1.1,       # anything made only from shop-bought goods sells for <= 1.1 x them (no buy-craft-sell loop)
        'decor_cap': 0.8}      # crafted decor/wear sells for <= 0.8 x its inputs (a sink, never income; c10_05-23)
FLOOR_TYPES = {'craft': 'craft_floor', 'material': 'craft_floor', 'bar': 'craft_floor',
               'food': 'goods_floor', 'potion': 'goods_floor', 'consumable': 'goods_floor', 'placeable': 'goods_floor', 'gift': 'goods_floor'}
NO_FLOOR = {'bills_crude', 'bills_passable', 'bills_fine', 'bills_perfect', 'forged_permit', 'rounds'}  # face value / ammo, priced by hand
import re
def shop_goods():
    """Every item id a town shop sells (mirror of the static lists in scripts/shops.gd offers()) plus
    every decor/wear piece a decor shop stocks (data/decor.json "shops", C10a)."""
    src = open(os.path.join(D, '..', 'scripts', 'shops.gd')).read()
    a = src.index('static func offers'); b = src.index('static func run', a)
    out = set()
    for m in re.finditer(r'\[([^\[\]]*)\]', src[a:b]):
        if src[a:b][:m.start()].rstrip().endswith(' in'): continue  # `cid in [...]` filters name crops, not goods
        out |= {w for w in re.findall(r'"([a-z0-9_]+)"', m.group(1)) if w in I}
    out |= {k for rows in DEC.get('shops', {}).values() for _, ids in rows for k in ids if k in I}
    return out
SHOP = shop_goods()
# Recipe fixes: milling adds value, made goods cost less than the shop's, tier-1 gates match tier 1.
I['flour']['value'] = 20
books['mill'] = [dict(r, need={'wheat': 1}) if r['id'] == 'flour' else (dict(r, need={'oat': 1}) if r['id'] == 'oat_flour' else r) for r in books['mill']]
for bk, rid, need in [('anvil', 'iron_sword', {'iron_bar': 1, 'hardwood_plank': 1}), ('jeweler', 'copper_ring', {'copper_bar': 1}),
                      ('cauldron', 'potion', {'berry': 3, 'slime_gel': 1})]:
    for r in books[bk]:
        if r['id'] == rid: r['need'] = need
GATES = {'fertilizer': ['farming', 2], 'herb_remedy': ['foraging', 2], 'sprinkler_quality': None}
for b in books.values():
    for r in b:
        if r['id'] in GATES:
            r.pop('skill', None)
            if GATES[r['id']]: r['skill'] = GATES[r['id']]
# Milk and eggs: goat milk and duck eggs work wherever milk or eggs do.
for k, fam in (('milk', 'milk'), ('goat_milk', 'milk'), ('egg', 'egg')):
    I[k]['family'] = fam
item('duck_egg', 'Duck Egg', 'food', 34, 1, energy=14, family='egg', desc='Big, rich and blue-green.')
for b in books.values():
    for r in b:
        for raw, fam in (('milk', '#milk'), ('egg', '#egg')):
            if raw in r['need'] and r['id'] not in ('cheese', 'butter'):
                r['need'][fam] = r['need'].pop(raw)
books['press'].insert(2, rc('goat_cheese', 'Goat Cheese', {'goat_milk': 1}))
books['press'] += [rc('cream', 'Cream', {'#milk': 1}), rc('yogurt', 'Honey Yogurt', {'#milk': 1, 'honey': 1}, tier=2),
                   rc('truffle_oil', 'Truffle Oil', {'truffle': 1}, tier=3)]
# Animal goods text (c11a_04-21, c11a_08): what they are and where they come from.
for k, dd in (('goat_milk', 'From the barn goats.'), ('sheep_wool', 'Shorn from a happy sheep or llama. Spin it into yarn at the Loom.'),
              ('honey', 'From your beehives, or found in the Meadow.'), ('butter', 'Churned from fresh milk.'),
              ('yarn', 'Soft and warm. Spun from wool or rabbit fur at the Loom.'), ('truffle', 'Dug up by happy pigs, or found in old forests.'),
              ('honeycomb', 'Straight from the hive. Spin it at the Honey Extractor for honey and beeswax.'),
              ('hay', 'Animal feed. Scythe grass, grow wheat, bale fiber at the Mill, or buy from Maple or Tam.')):
    if k in I: I[k]['desc'] = dd
I['duck_egg']['energy'] = 26
I['honey']['energy'] = 20
I['butter']['value'] = 70; I['cheese']['desc'] = 'Pressed from fresh milk.'
def fval(k):  # value of a need key ('#fam' = its cheapest member)
    if k.startswith('#'):
        vs = [int(v.get('value', 5)) for v in I.values() if v.get('family') == k[1:] or (k == '#fruit' and v.get('family') in ('tree', 'berry'))]
        return min(vs) if vs else 5
    return int(I.get(k, {}).get('value', 5))
def need_val(need): return sum(fval(k) * n for k, n in need.items())
def all_shop(need): return all((not k.startswith('#')) and k in SHOP for k in need)
ARMOUR = ('copper_', 'iron_', 'steel_', 'silver_', 'gold_', 'leather_')
# C11b integ: a recipe that needs one arc's goods belongs to that arc (and so does a C11b good made only that
# way): shared stations never list what the arc can't make. Repeat so chains (milk -> cheese -> ...) settle.
_station_arc = {b['station'].get('book', bid): b.get('arc') for bid, b in B.items() if isinstance(b, dict) and isinstance(b.get('station'), dict)}
for _ in range(3):
    for bk, b in books.items():
        for r in b:
            if r.get('arc') or _station_arc.get(bk):
                continue
            ra = {I[k].get('arc') for k in r['need'] if not k.startswith('#') and k in I and I[k].get('arc')}
            if len(ra) == 1:
                r['arc'] = next(iter(ra)); r['_need_arc'] = True
    _by_give = {}
    for bk, b in books.items():
        for r in b:
            _by_give.setdefault(r['give'], []).append(r)
    for g, rs in _by_give.items():
        arcs = {r.get('arc') for r in rs}
        if g in I and not I[g].get('arc') and all(r.get('_need_arc') for r in rs) and len(arcs) == 1:
            I[g]['arc'] = next(iter(arcs))  # made only from that arc's goods
for b in books.values():
    for r in b:
        r.pop('_need_arc', None)
econ_log = []
for _ in range(3):  # upstream values move downstream ones: settle in a few passes
    floor, cap = {}, {}
    for bk, b in books.items():
        if bk == 'keg': continue
        for r in sorted(b, key=lambda r: r.get('tier', 1)):
            g = r['give']; it = I.get(g)
            if not it or g in NO_FLOOR: continue
            per = need_val(r['need']) / float(r.get('n', 1))
            if all_shop(r['need']):
                cap[g] = min(cap.get(g, 1e9), int(ECON['loop_cap'] * per))
            if it.get('type') in ('decor', 'wear'):
                cap[g] = min(cap.get(g, 1e9), max(1, int(ECON['decor_cap'] * per)))
                continue
            if it.get('type') == 'equip' and g.startswith(ARMOUR) and not g.endswith('_plus'):
                f = int(ECON['armour_floor'] * per)
            elif it.get('type') in FLOOR_TYPES and not r.get('tool') and not r.get('vehicle'):
                f = -(-int(ECON[FLOOR_TYPES[it['type']]] * per * 100) // 100)
            else:
                continue
            floor[g] = min(floor.get(g, 1e9), f)  # the cheapest way to make it must not lose money
    for g in set(floor) | set(cap):
        cur = int(I[g].get('value', 0)); new = cur
        if g in floor: new = max(new, int(floor[g]))
        if g in cap: new = min(new, cap[g])
        if new != cur:
            econ_log.append('%s %d -> %d' % (g, cur, new)); I[g]['value'] = new
# Tempered pieces are worth more than their base (c10_07: moon _plus sold below the plain piece).
for bk2 in ('anvil', 'tannery', 'armory', 'shaper'):
    for r in books.get(bk2, []):
        if r['id'].startswith('temper_') and r['give'] in I:
            base = r['id'][len('temper_'):]
            if base in I:
                want = max(int(int(I[base].get('value', 0)) * 1.08), int(I[base].get('value', 0)) + 1)
                if int(I[r['give']].get('value', 0)) < want:
                    econ_log.append('%s %s -> %d (temper)' % (r['give'], I[r['give']].get('value'), want)); I[r['give']]['value'] = want
# ---- C16a P5: gear ladders, station gates and gang words ------------------------------------
# c16a_07-04/05: one damage per weapon tier for every source, both arcs (T1 3, T2 5, T3 7, T4 10, arc signature 11);
# the smith's swords are penguin-arc (the gang smith sells the crowbar line, shops.gd).
for k, dmg, tier, v in (('iron_sword', 5, 2, 320), ('steel_sword', 7, 3, 800), ('crystal_sword', 10, 4, 2400)):
    I[k].update({'damage': dmg, 'tier': tier, 'value': max(v, int(I[k].get('value', 0))), 'arc': 'penguins',
                 'rarity': ['common', 'common', 'uncommon', 'rare', 'epic', 'legendary'][tier]})
# c16a_07-06: armour defence per metal 1..8, steel is a tier-3 set, values rise with every metal.
METALS = ['leather', 'copper', 'iron', 'steel', 'silver', 'gold', 'crystal', 'moon']
for mi, m in enumerate(METALS):
    for sl in SLOTS:
        for k, add in (('%s_%s' % (m, sl), 0), ('%s_%s_plus' % (m, sl), 1)):
            it = I.get(k)
            if not it: continue
            st = it.get('stats', {})
            if set(st) == {'defense'}:
                it['stats'] = {'defense': mi + 1 + add}
            if m == 'steel': it['tier'] = 3
for sl in SLOTS:
    prev = 0
    for m in METALS:
        k = '%s_%s' % (m, sl)
        if k not in I: continue
        want = max(int(I[k].get('value', 0)), int(prev * 1.15) + 1)
        if want != int(I[k].get('value', 0)): econ_log.append('%s %s -> %d (armour ladder)' % (k, I[k].get('value'), want)); I[k]['value'] = want
        prev = want
        kp = k + '_plus'
        if kp in I:
            I[kp]['value'] = max(int(I[kp].get('value', 0)), int(want * 1.08) + 1)
for k, twin in (('iron_mail', 'iron_chest'), ('crystal_plate', 'crystal_chest')):
    if k in I and twin in I:
        I[k]['stats'] = dict(I[k].get('stats', {}), defense=I[twin]['stats'].get('defense', 0))
# c16a_10-01: tier-1 stations open over season 1, not all on day 1 (day 1: workbench, cooking pot, furnace, keg).
T1_GATE = {'anvil': {'skill': ['mining', 2]}, 'sawmill': {'skill': ['building', 2]}, 'mayo': {'skill': ['ranching', 2]},
           'extractor': {'skill': ['ranching', 3]}, 'resonator': {'progress': 1}, 'armory': {'skill': ['combat', 2]},
           'shaper': {'skill': ['combat', 2]}, 'soda': {'skill': ['bartering', 2]}, 'print_shop': {'skill': ['bartering', 2]},
           'gene_splicer': {'progress': 1, 'skill': ['ranching', 4]}, 'laundromat': {'progress': 1}, 'training': {'progress': 1}}
for sid, st in B.items():
    if not isinstance(st, dict) or st.get('thing') != 'station' or not st.get('tiers'): continue
    t1 = st['tiers'][0]
    if sid in T1_GATE:
        t1['unlock'] = dict(t1.get('unlock', {}), **T1_GATE[sid])
    # ready-made tier 1 costs 1.5x: buying is a choice, not a skip
    t1['price'] = int(round(int(t1['price']) * 1.5 / 10.0)) * 10
    # c16a_10-02 / c16a_09-17: the top tier of a 4-tier station waits for year 2
    if len(st['tiers']) >= 4:
        st['tiers'][3].setdefault('unlock', {})['year'] = 2
# c16a_06-09: the top farm and ranch tiers wait for year 2 (Builds.gate reads unlock.year).
YEAR2_TIERS = {'Grand Barn', 'Grand Enclosure', 'Grand Aviary', 'Grand Terrarium', 'Star Dome'}
for bid, bd in B.items():
    if isinstance(bd, dict):
        for t in bd.get('tiers', []):
            if t.get('name') in YEAR2_TIERS:
                t.setdefault('unlock', {})['year'] = 2
for bk, b in books.items():
    for r in b:
        if r['id'] == 'sprinkler_iridium': r['year'] = 2
# c16a_10-03 / c16a_09-05: both-arc stations in the gangster arc's own words (Builds._arc_words reads name_gang).
GANG_TIER = {'Workbench': 'Work Bench', "Carpenter's Bench": 'Shop Bench', 'Workshop': 'Garage Shop', 'Master Workshop': 'Fab Shop',
             'Stone Furnace': 'Scrap Furnace', 'Brick Furnace': 'Smelter', 'Starfire Furnace': 'Arc Furnace',
             'Crystal Resonator': 'Signal Booster', 'Twin Resonator': 'Twin Booster', 'Prism Array': 'Relay Array', 'Star Array': 'Satellite Array',
             'Cooking Pot': 'Hot Plate', 'Iron Stove': 'Diner Stove', 'Kitchen Range': 'Line Kitchen', 'Grand Range': "Chef's Line",
             'Moon Loom': 'Power Loom', 'Crystal Kiln': 'Glass Kiln', 'Star Setting Bench': 'Diamond Bench', 'Starforge': 'Arc Forge',
             'Bubbling Pot': 'Chem Pot', 'Cauldron': 'Chem Lab', 'Arcane Cauldron': 'Lab Bench', 'Starfire Cauldron': 'Clean Lab', 'Sky Dock': 'Air Dock'}
GANG_LABEL = {'resonator': 'Signal Booster', 'kitchen': 'Hot Plate', 'cauldron': 'Chem Lab'}
for sid, st in B.items():
    if not isinstance(st, dict) or st.get('thing') != 'station' or st.get('arc'): continue
    for t in st.get('tiers', []):
        if t['name'] in GANG_TIER: t['name_gang'] = GANG_TIER[t['name']]
    if sid in GANG_LABEL: st['label_gang'] = GANG_LABEL[sid]

# Station cards don't promise recipes a tier doesn't add.
for sid, st in B.items():
    if not isinstance(st, dict) or 'station' not in st or st['station'].get('book') == 'keg': continue
    rts = [int(r.get('tier', 1)) for r in books.get(st['station'].get('book', sid), [])]
    if not rts: continue
    top = max(rts)
    for i, t in enumerate(st['tiers']):
        c = min(5, i + 2)
        if i > 0 and min(5, i + 1) >= top:
            t['desc'] = t['desc'].replace(' recipes up to tier %d.' % c, ' every recipe already open.')

used = {r['id'] for b in books.values() for r in b}
lost = [i for i in old if i not in used and i not in ('glass', 'leather', 'fence_kit', 'crab_pot')]
for i in lost: books['workbench'].append(old[i])
for k in ('smith', 'alchemy'): R.pop(k, None)
R.update(books)
json.dump(B, open(D + 'buildings.json', 'w'), indent=1, ensure_ascii=False)
json.dump(R, open(D + 'recipes.json', 'w'), indent=1, ensure_ascii=False)
for k, d in (('sprinkler', 'Place it on the farm (hold it, USE on open ground). Waters the 4 tiles beside it every morning. USE it again to pick it up.'),
             ('sprinkler_quality', 'Waters the 8 tiles around it every morning.'),
             ('sprinkler_iridium', 'Waters a 5x5 square around it every morning.'),
             ('scarecrow', 'Place it on the farm. Keeps crows off crops within 8 tiles.')):
    if k in I:
        I[k]['type'] = 'placeable'; I[k]['desc'] = d
# ---- C12 P6 (c12_12-05): every item has a line under its name -----------------------------------------
# Items with no authored desc get one from ITEM_DESC (hand-written) or a per-type template; filled lines
# carry desc_auto so later runs rewrite them from the templates (an authored desc is never touched).
import zlib as _z
_CROPS = json.load(open(D + 'crops.json'))
_SEASON_OF = {}
for _ck, _cv in _CROPS.items():
    _SEASON_OF[str(_cv.get('yield', _ck))] = str(_cv.get('season', 'any'))
ITEM_DESC = {
    'hoe': 'Tills soil for planting. Upgrade it at the smith to till more at once.',
    'can': 'Waters crops. Refill it at any pond, river or well.',
    'axe': 'Chops trees, logs and stumps for wood.',
    'pickaxe': 'Breaks rocks for stone, ore and the odd gem.',
    'scythe': 'Cuts weeds and tall grass. Cut grass makes hay.',
    'hammer': 'Knocks things apart and puts them right again.',
    'rod': 'Face water and cast. Reel in when it bites.',
    'sword': 'A practice blade of carved wood. Better than bare hands.',
    'iron_sword': 'A solid iron blade, forged by the smith.',
    'steel_sword': 'Tempered steel: lighter and sharper than iron.',
    'crystal_sword': 'A blade of living crystal that hums when you swing it.',
    'crowbar': 'Pries open crates and knocks back trouble.',
    'lucky_bat': 'A well-worn bat. Lucky for you, not for them.',
    'chrome_blade': 'A chrome blade that flashes under the street lights.',
    'neon_cleaver': 'A heavy cleaver with a neon edge. Hits hard and glows.',
    'icicle_blade': 'Cold to the touch and sharp as winter.',
    'fishbone_sabre': 'Carved from a giant fish bone. Light and quick.',
    'aurora_blade': 'Shimmers green and violet with every swing.',
    'prism_lance': 'A long crystal lance that splits light into colours.',
    'starheart_blade': 'Forged around a fallen star. The finest blade there is.',
    'six_shooter': 'A reliable sidearm. Loads rounds; one per shot.',
    'scattergun': 'A wide, short-range blast. Slow to reload.',
    'tommy_gun': 'Sprays rounds fast and far. Hungry for ammo.',
    'gold_revolver': 'Gold-plated and dead accurate. The boss of sidearms.',
    'bait': 'Fish bite faster with a little bait on the hook.',
    'boot': 'Somebody lost a boot in the water. Recycle it for scrap.',
    'fiber': 'Tough plant fibre. Twist it into rope or cloth.',
    'wood': 'The basic building block of farm life.',
    'stone': 'Good for paths, walls and almost every building.',
    'hardwood': 'Dense, slow-grown timber for the sturdiest builds.',
    'coal': 'Fuel for the furnace. Every bar of metal needs some.',
    'shard': 'A raw crystal shard. Refine three at the Resonator.',
    'gift_pie': 'A pie baked to give away. Wrapped with a ribbon.',
    'gift_red': 'Something nice in red paper. Anyone would smile.',
    'gift_gold': 'Gold paper, a big bow. A gift for someone special.',
}
_BAR_ORE = {'copper_bar': 'copper ore', 'iron_bar': 'iron ore', 'silver_bar': 'silver ore', 'gold_bar': 'gold ore',
            'steel_bar': 'iron and coal', 'dark_bar': 'shadow ore', 'moon_bar': 'moonsilver ore', 'platinum_bar': 'platinum ore'}
_SLOT = {'head': 'Headgear', 'body': 'Body armour', 'feet': 'Footwear', 'back': 'Worn on the back', 'belt': 'A sturdy belt',
         'legs': 'Legwear', 'hands': 'Gloves', 'offhand': 'Held in your off hand', 'ring': 'A ring', 'charm': 'A lucky charm'}
_STAT = {'defense': 'defence', 'luck': 'luck', 'speed': 'speed', 'energy': 'energy', 'damage': 'damage'}
_TYPE = {
    'crop': ['Fresh from the farm. Good in the kitchen or the sell box.', 'Grown with care. Cook it, gift it or ship it.'],
    'fruit': ['Fresh off the branch. Sweet in a pie, or sell it by the crate.', 'Picked ripe. Lovely in jam, a pie or the press.'],
    'flower': ['Cut fresh from the field. Villagers love a bunch.', 'A pretty bloom. Lovely in a vase or as a gift.', 'Bees adore it, and so do most neighbours.'],
    'herb': ['A fragrant herb. Cooks and potion-makers use it.', 'Smells wonderful. Good for teas, stews and remedies.'],
    'fish': ['Caught fresh. Cook it, gift it or sell it.', 'A good catch. The fish log has a page for it.', 'Still flapping. Grill it or ship it.'],
    'forage': ['Found growing wild. Free for the picking.', 'A wild find. Cooks pay for these.'],
    'material': ['A building material. The workbench and Plans board use it.', 'Raw stuff for crafting and building.'],
    'ore': ['Raw ore from the rocks. Smelt it in a furnace.', 'Dug from the rocks. The furnace turns it into bars.'],
    'gem': ['A cut-ready gem. Jewelers and collectors pay well.', 'It sparkles in any light. Rare and valuable.'],
    'magic': ['It hums with a strange glow. Used in rare recipes.', 'Faintly warm to the touch. Alchemists prize it.'],
    'craft': ['A crafted part. Other recipes build on it.', 'Handy in the workshop: many recipes need it.'],
    'food': ['A home-cooked dish. Restores energy.', 'Warm, filling and made with care.', 'Good food for a long day.'],
    'potion': ['A potion in a little bottle. Use it when you need it.', 'Brewed to help when things get tough.'],
    'treasure': ['An old find. The museum would love it, or a collector will pay.', 'A relic from long ago. Worth a lot to the right buyer.'],
    'petgear': ['Gear for your pup. Put it on from the pup page.', 'Made to fit your pup just right.'],
    'gift': ['A gift, ready to give.'],
    'junk': ['Not much use. Recycle it.'],
    'misc': ['Useful odds and ends.'],
}


def _pick_d(k, lines):
    return lines[_z.crc32(k.encode()) % len(lines)]


def _season_words(se):
    return {'spring': 'in spring', 'summer': 'in summer', 'fall': 'in fall', 'winter': 'in winter'}.get(se, 'in any season')


def auto_desc(k, it):
    t = str(it.get('type', ''))
    if k in ITEM_DESC:
        return ITEM_DESC[k]
    if t == 'seed':
        c = str(it.get('crop', ''))
        cr = _CROPS.get(c, {})
        nm = I.get(str(cr.get('yield', c)), {}).get('name', cr.get('name', ''))
        if cr and nm:
            return 'Plant %s. Grows into %s in %d days.' % (_season_words(str(cr.get('season', 'any'))), nm, int(cr.get('days', 4)))
        return 'Plant in tilled soil and water it each morning.'
    if t == 'tool' and it.get('weapon'):
        return 'A weapon. Hits for %d.' % int(it.get('damage', 1)) + (' Loads rounds; one per shot.' if it.get('range') else '')
    if t == 'tool':
        return 'A tool for the farm and the road.'
    if t == 'bar':
        ore = _BAR_ORE.get(k, 'ore')
        return 'Smelted from %s. The smith and the workbench need it.' % ore
    if t == 'equip':
        st = it.get('stats', {}) or {}
        bits = ['+%s %s' % (v, _STAT.get(s, s)) for s, v in st.items() if v]
        base = _SLOT.get(str(it.get('slot', '')), 'Gear to wear')
        lvl = re.search(r'\+(\d)$', str(it.get('name', '')))
        tail = ' Tempered at the forge: a little tougher than the plain one.' if lvl else ''
        return ('%s: %s while worn.' % (base, ', '.join(bits)) if bits else base + '.') + tail
    if t in ('crop', 'fruit'):
        fam = str(it.get('family', ''))
        se = _SEASON_OF.get(k, '')
        if fam == 'magic':
            return 'It glows faintly. Cooks and alchemists prize it.'
        if fam == 'grain':
            return 'A grain crop. Mill it into flour or feed it to the keg.'
        if se in ('spring', 'summer', 'fall', 'winter'):
            return 'A %s harvest. Good in the kitchen or the sell box.' % se
        return _pick_d(k, _TYPE[t])
    if t in _TYPE:
        return _pick_d(k, _TYPE[t])
    return ''


# C12 c12_08-07 / 08-14: rare herbs are herbs (not flowers), Memory Tea is a herb food, and the
# kids' candy is "loved_by: candy" like the prize candy.
RARE_HERBS = ['dreamleaf', 'lantern_sage', 'singing_thyme', 'mirror_mint', 'thunder_nettle', 'silver_sage',
              'gold_chamomile', 'prism_basil', 'moon_mugwort', 'comet_dill', 'wisp_rosemary', 'echo_yarrow', 'star_lavender']
for _k in RARE_HERBS:
    if _k in I and I[_k].get('type') in ('flower', 'herb'):
        I[_k]['type'] = 'herb'
        I[_k]['family'] = 'herb'
if 'memory_tea' in I:
    I['memory_tea'].update({'type': 'food', 'family': 'herb'})
    I['memory_tea'].setdefault('energy', 30)
if 'candy' in I:
    I['candy']['loved_by'] = 'candy'


for _k, _it in I.items():
    if _k.startswith(('dc_', 'wr_')) or not isinstance(_it, dict):
        continue
    if _it.get('desc') and not _it.get('desc_auto'):
        continue
    _d = auto_desc(_k, _it)
    if _d:
        _it['desc'] = _d
        _it['desc_auto'] = True

json.dump(I, open(D + 'items.json', 'w'), indent=1, ensure_ascii=False)
print('stations', sum(1 for v in B.values() if isinstance(v, dict) and v.get('thing') == 'station'), 'recipes', {k: len(v) for k, v in R.items() if isinstance(v, list)}, 'moved to workbench:', lost)
print('economy pass:', len(econ_log), 'values changed'); open('/tmp/econ_pass.log', 'w').write('\n'.join(econ_log))
print('art missing:', [(k, t['name']) for k, v in B.items() if isinstance(v, dict) for t in v.get('tiers', []) if t.get('art_missing')])
