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
 ('balloon', 'Hot-Air Balloon', 'vehicle', 9000, 4, {'fly': True, 'sprite': 'veh_balloon', 'desc': 'Hold it and press USE outdoors: drift to any place you have already visited.'}),
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
 ('spy_drone', 'Spy Drone', 'consumable', 1200, 2, {'arc': 'gangsters', 'effect': 'drone', 'desc': 'USE it (kept; recharges for 2 days): it circles and reports who is here, how to beat anyone with a Gift, and keeps collectors off you for the day.'}),
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
 ('cherry_fizz', 'Cherry Fizz', 'food', 150, 2, {'arc': 'gangsters', 'energy': 55, 'heal': 3}), ('golden_float', 'Golden Float', 'food', 420, 3, {'arc': 'gangsters', 'energy': 90, 'heal': 5, 'buff': {'kind': 'luck', 'minutes': 240, 'amount': 2}, 'friend': 4}),
]
for id, name, typ, val, tier, extra in G:
    item(id, name, typ, val, tier, **extra)
# Penguin arc only: crystal-shaped gear, Cat-topia's litter works, the campfire.
for id, name, typ, val, tier, extra in [
 ('marshmallow', 'Marshmallow', 'food', 20, 1, {'energy': 12}), ('toasted_marshmallow', 'Toasted Marshmallow', 'food', 45, 1, {'energy': 30}),
 ('smore', "S'more", 'food', 140, 2, {'energy': 55, 'heal': 2}), ('hot_cocoa', 'Hot Cocoa', 'food', 160, 2, {'energy': 45, 'buff': {'kind': 'warm', 'minutes': 480, 'amount': 1}, 'desc': 'Big Jim makes it too sweet. Warm for hours.'}),
 ('campfire_stew', "Big Jim's Stew", 'food', 240, 3, {'energy': 80, 'heal': 5}), ('starlight_smore', "Starlight S'more", 'food', 520, 3, {'energy': 100, 'heal': 4, 'buff': {'kind': 'luck', 'minutes': 300, 'amount': 2}, 'friend': 4}),
 ('scented_litter', 'Scented Litter Box', 'consumable', 40, 2, {'effect': 'stink', 'radius': 84, 'stun': 5.0, 'desc': 'Lavender. Somehow worse. A wider cloud, a longer nose-hold.'}),
 ('mega_litter', 'Mega Litter Box', 'consumable', 110, 3, {'effect': 'stink', 'radius': 120, 'stun': 7.0, 'desc': 'The catapult-sized one. Clears a room.'}),
 ('tuna_treat', 'Tuna Treat', 'food', 18, 1, {'energy': 25, 'friend': 3, 'desc': 'Every cat in Cat-topia wants one. So does your pup.'}),
 ('paw_lantern', 'Paw Lantern', 'consumable', 90, 2, {'buff': {'kind': 'luck', 'minutes': 180, 'amount': 1}, 'mana': 10, 'desc': 'A little jar of Meow Pow Wow light. Open it for luck and mana.'}),
 ('heart_spark', 'Heart Spark', 'consumable', 420, 3, {'mana': 60, 'heal': 6, 'desc': 'A rainbow heart in a bottle. Mana and health at once.'})]:
    extra['arc'] = 'penguins'; item(id, name, typ, val, tier, **extra)
I['litter_box'].update({'radius': 56, 'stun': 3.0})
for id, name, dmg, val, tier in [('icicle_blade', 'Icicle Blade', 3, 150, 1), ('fishbone_sabre', 'Fish-Bone Sabre', 4, 320, 2), ('aurora_blade', 'Aurora Blade', 6, 900, 2), ('prism_lance', 'Prism Lance', 8, 2200, 3), ('starheart_blade', 'Starheart Blade', 11, 5200, 4)]:
    item(id, name, 'tool', val, tier, damage=dmg, weapon=True, arc='penguins')
for id, name, slot, stats, val, tier in [
 ('snow_goggles', 'Snow Goggles', 'head', {'defense': 1, 'luck': 1}, 140, 1), ('aurora_hood', 'Aurora Hood', 'head', {'luck': 2, 'speed': 1}, 520, 3),
 ('puffy_parka', 'Puffy Parka', 'body', {'defense': 2, 'luck': 1}, 380, 2), ('crystal_parka', 'Crystal Parka', 'body', {'defense': 4}, 900, 3), ('starlight_mantle', 'Starlight Mantle', 'body', {'defense': 6, 'luck': 1}, 3200, 4),
 ('ice_cleats', 'Ice Cleats', 'feet', {'defense': 2}, 300, 2), ('mitten_paws', 'Mitten Paws', 'hands', {'damage': 1}, 260, 2),
 ('courage_scarf', 'Scarf of Courage', 'back', {'defense': 2, 'speed': 1}, 700, 3), ('flipper_belt', 'Flipper Belt', 'belt', {'speed': 1, 'damage': 1}, 480, 3), ('bell_collar', 'Bell Collar', 'charm', {'luck': 2}, 800, 3)]:
    item(id, name, 'equip', val, tier, slot=slot, stats=stats, arc='penguins')
# Gangster weapons (melee; "weapon" makes them swing like a sword) and street armor.
for id, name, dmg, val, tier in [('brass_knuckles', 'Brass Knuckles', 3, 150, 1), ('crowbar', 'Crowbar', 4, 320, 2), ('lucky_bat', 'Lucky Bat', 6, 900, 2), ('chrome_blade', 'Chrome Blade', 8, 2200, 3), ('neon_cleaver', 'Neon Cleaver', 11, 5200, 4)]:
    item(id, name, 'tool', val, tier, damage=dmg, weapon=True, arc='gangsters')
# Guns (gangster arc): ranged, one round a shot; out of rounds they're a clumsy club. Cartoon puffs, no blood.
item('rounds', 'Rounds', 'craft', 3, 1, arc='gangsters', desc='One per shot.')
for id, name, dmg, val, tier, extra in [('six_shooter', 'Six-Shooter', 4, 700, 2, {'range': 110, 'cd': 2.0}), ('scattergun', 'Scattergun', 6, 2000, 3, {'range': 64, 'spread': True, 'cd': 1.6}),
                                         ('tommy_gun', 'Tommy Gun', 3, 2600, 3, {'range': 120, 'cd': 0.6}), ('gold_revolver', 'Gold Revolver', 10, 5600, 4, {'range': 140, 'cd': 2.5})]:
    item(id, name, 'tool', val, tier, damage=dmg, weapon=True, arc='gangsters', **extra)
for id, name, slot, stats, val, tier in [
 ('fedora', 'Fedora', 'head', {'defense': 1, 'luck': 1}, 140, 1), ('shades', 'Shades', 'head', {'luck': 2, 'speed': 1}, 520, 3),
 ('pinstripe_suit', 'Pinstripe Suit', 'body', {'defense': 2, 'luck': 1}, 380, 2), ('padded_vest', 'Padded Vest', 'body', {'defense': 4}, 900, 3), ('armored_suit', 'Armored Suit', 'body', {'defense': 6, 'luck': 1}, 3200, 4),
 ('steel_toes', 'Steel-Toe Shoes', 'feet', {'defense': 2}, 300, 2), ('knuckle_gloves', 'Knuckle Gloves', 'hands', {'damage': 1}, 260, 2),
 ('trench_coat', 'Trench Coat', 'back', {'defense': 2, 'speed': 1}, 700, 3), ('tool_belt', "Driver's Belt", 'belt', {'speed': 1, 'damage': 1}, 480, 3), ('gold_chain', 'Gold Chain', 'charm', {'luck': 2}, 800, 3)]:
    item(id, name, 'equip', val, tier, slot=slot, stats=stats, arc='gangsters')

# ---- stations ------------------------------------------------------------------
SK = [1, 3, 5, 7]
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
# ---- gangster arc only ---------------------------------------------------------
station('print_shop', 'Back-Room Press', 'operation', [9, 24], 'bartering', 'Print', 'Specs', [
 ('Back-Room Press', ['press_1'], {'plank': 16, 'nails': 8, 'copper_bar': 2}, d(0, 'Crude bills. Risky.')),
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
station('shrine', 'Meow Pow Wow Shrine', 'sanctuary', [18, 23], 'foraging', '', 'Catkins', [
 ('Paw Stone', ['shrine_1'], {'stone': 30, 'crystal_bloom': 6, 'shard': 3}, 'Practise once a day: mana back and foraging XP. +5 max mana.'),
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
B['mill']['thing'] = 'station'; B['mill']['station'] = {'skill': 'farming', 'verb': 'Mill', 'book': 'mill'}; B['mill']['cat'] = 'pantry'
for k, v in B.items():
    if isinstance(v, dict) and 'cat' not in v: v['cat'] = 'farm'
for k in ('chest', 'well', 'beehive', 'scarecrow'): B[k]['cat'] = 'farm'

# Upgrades of the older farm buildings now take worked goods, and everything has a ready-made price.
for bid, tier, cost in [('house', 2, {'plank': 80, 'brick': 60, 'nails': 30, 'copper_bar': 5}), ('house', 3, {'beam': 40, 'tile': 60, 'iron_bar': 10, 'glass': 20}),
                        ('coop', 2, {'plank': 60, 'nails': 30, 'copper_bar': 3}), ('barn', 2, {'beam': 30, 'brick': 60, 'iron_bar': 4}), ('shed', 2, {'plank': 50, 'nails': 30, 'copper_bar': 4})]:
    for t in B[bid]['tiers']:
        if t['tier'] == tier: t['cost'] = cost
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
books['workbench'] = keep('torch', 'chest', 'scarecrow', 'fertilizer', 'sprinkler', 'sprinkler_quality', 'crab_pot', 'bait', 'straw_hat', 'pup_treat') + [
 rc('fence_kit', 'Shingle Bundle', {'plank': 4, 'nails': 2}, 'shingles', 1, 6), rc('wheel', 'Cart Wheel', {'plank': 6, 'nails': 4, 'iron_bar': 1}, tier=2), rc('sprinkler_iridium', 'Iridium Sprinkler', {'gold_bar': 2, 'iron_bar': 2, 'crystal_refined': 3}, tier=4)]
books['sawmill'] = [rc('plank', 'Plank', {'wood': 2}, n=1), rc('charcoal', 'Charcoal (burns as coal)', {'wood': 6}, 'coal', 1, 2), rc('beam', 'Timber Beam', {'wood': 12}, tier=2),
 rc('hardwood_plank', 'Hardwood Plank', {'hardwood': 1}, tier=2), rc('veneer', 'Fine Veneer', {'hardwood_plank': 3, 'sap': 2}, tier=3), rc('ironwood_beam', 'Ironwood Beam', {'hardwood_plank': 6, 'beam': 2, 'dark': 1}, tier=4)]
books['furnace'] = keep('copper_bar', 'iron_bar', 'steel_bar', 'silver_bar', 'gold_bar') + [rc('dark_bar', 'Shadowsteel Bar', {'dark': 5, 'coal': 4}, tier=4), rc('moon_bar', 'Moonsilver Bar', {'moon_shard': 2, 'silver_bar': 2}, tier=5)]
books['anvil'] = [rc('nails', 'Nails', {'copper_bar': 1}, n=10), rc('horseshoe', 'Horseshoe', {'copper_bar': 1}), rc('gear', 'Gear', {'iron_bar': 1}, tier=2), rc('spring', 'Spring', {'iron_bar': 1, 'coal': 1}, tier=2),
 rc('plating', 'Steel Plating', {'steel_bar': 2, 'coal': 2}, tier=3)] + sorted(metal_gear, key=lambda r: (r['tier'], r['id'])) + keep('pup_collar_iron', 'pup_boots')
books['loom'] = keep('rope', 'cloth') + [rc('yarn', 'Yarn', {'sheep_wool': 1}), rc('linen', 'Linen', {'flax': 2}), rc('cotton_cloth', 'Cotton Cloth', {'cotton': 2}, tier=2),
 rc('sail', 'Sailcloth', {'linen': 3, 'rope': 2}, tier=2), rc('fine_fabric', 'Fine Fabric', {'cotton_cloth': 1, 'linen': 1, 'yarn': 1}, tier=3), rc('moonweave', 'Moonweave', {'fine_fabric': 2, 'star_dust': 1}, tier=4)] + keep(
 'work_shirt', 'outfit_farmer', 'outfit_forester', 'outfit_fisher', 'outfit_miner', 'outfit_merchant', 'outfit_scholar', 'outfit_neon', 'outfit_penguin')
books['tannery'] = [rc('leather', 'Leather', {'pelt': 1}, tier=1), rc('leather_scrap', 'Leather (from wings)', {'bat_wing': 2, 'slime_gel': 1}, 'leather', 1), rc('fine_leather', 'Fine Leather', {'leather': 2, 'cooking_oil': 1}, tier=3)] + sorted(leather_gear, key=lambda r: r['id']) + keep(
 'boots', 'running_shoes', 'pup_collar_leather', 'pup_pack_small', 'pup_pack_large')
books['kitchen'] = R['kitchen'] if 'kitchen' in R else []
books['mill'] = R['mill']
books['press'] = [rc('cheese', 'Cheese', {'milk': 1}), rc('butter', 'Butter', {'milk': 1}), rc('jam', 'Jam', {'#berry': 3}), rc('cooking_oil', 'Cooking Oil', {'sunflower': 2}), rc('sesame_oil', 'Cooking Oil (sesame)', {'sesame': 2}, 'cooking_oil', 2, 2),
 rc('pickles', 'Pickles', {'#veg': 2, 'clay_pot': 1}, tier=2, n=2), rc('dried_fruit', 'Dried Fruit', {'#tree': 2}, tier=2), rc('wine_reserve', 'Fruit Wine Reserve', {'fruit_wine': 2, '#herb': 1}, 'fine_wine', 3)]
books['kiln'] = [rc('brick', 'Brick', {'clay': 1}, n=2), rc('stone_brick', 'Brick (from stone)', {'stone': 4, 'coal': 1}, 'brick', 1, 2), rc('clay_pot', 'Clay Pot', {'clay': 2}), rc('glass', 'Glass', {'sand': 3, 'coal': 1}),
 rc('tile', 'Glazed Tile', {'brick': 2, 'sand': 1}, tier=2), rc('lens', 'Lens', {'glass': 2, 'sand': 2}, tier=2), rc('crystal_glass', 'Crystal Glass', {'glass': 2, 'crystal_refined': 1}, tier=3)]
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
books['armory'] = [rc('brass_knuckles', 'Brass Knuckles', {'copper_bar': 3}, tool=True), rc('rounds', 'Rounds', {'copper_bar': 1, 'coal': 1}, n=30), rc('six_shooter', 'Six-Shooter', {'iron_bar': 4, 'gear': 2, 'hardwood_plank': 1}, tier=2, tool=True), rc('scattergun', 'Scattergun', {'steel_bar': 4, 'spring': 3, 'hardwood_plank': 2}, tier=3, tool=True), rc('tommy_gun', 'Tommy Gun', {'steel_bar': 5, 'spring': 6, 'gear': 6}, tier=3, tool=True), rc('gold_revolver', 'Gold Revolver', {'gold_bar': 4, 'dark_bar': 2, 'spring': 4}, tier=4, tool=True), rc('fedora', 'Fedora', {'fiber': 6, 'leather': 1}), rc('crowbar', 'Crowbar', {'iron_bar': 3}, tier=2, tool=True),
 rc('lucky_bat', 'Lucky Bat', {'hardwood_plank': 3, 'nails': 10, 'horseshoe': 1}, tier=2, tool=True), rc('pinstripe_suit', 'Pinstripe Suit', {'cotton_cloth': 4, 'linen': 2}, tier=2),
 rc('steel_toes', 'Steel-Toe Shoes', {'leather': 2, 'iron_bar': 1}, tier=2), rc('knuckle_gloves', 'Knuckle Gloves', {'leather': 2, 'copper_bar': 2}, tier=2),
 rc('chrome_blade', 'Chrome Blade', {'steel_bar': 5, 'plating': 1, 'fine_leather': 1}, tier=3, tool=True), rc('padded_vest', 'Padded Vest', {'fine_leather': 3, 'cotton_cloth': 4, 'plating': 1}, tier=3),
 rc('trench_coat', 'Trench Coat', {'fine_fabric': 3, 'fine_leather': 1}, tier=3), rc('tool_belt', "Driver's Belt", {'fine_leather': 2, 'gear': 2}, tier=3), rc('shades', 'Shades', {'crystal_glass': 1, 'silver_bar': 1}, tier=3),
 rc('gold_chain', 'Gold Chain', {'gold_bar': 2}, tier=3), rc('neon_cleaver', 'Neon Cleaver', {'dark_bar': 4, 'crystal_battery': 1, 'plating': 2}, tier=4, tool=True),
 rc('armored_suit', 'Armored Suit', {'pinstripe_suit': 1, 'plating': 4, 'moonweave': 1}, tier=4)]
books['shaper'] = [rc('icicle_blade', 'Icicle Blade', {'shard': 3, 'copper_bar': 1}, tool=True), rc('snow_goggles', 'Snow Goggles', {'glass': 2, 'leather': 1}), rc('fishbone_sabre', 'Fish-Bone Sabre', {'iron_bar': 2, 'bone': 6}, tier=2, tool=True),
 rc('aurora_blade', 'Aurora Blade', {'iron_bar': 3, 'crystal_refined': 2, 'light_mote': 2}, tier=2, tool=True), rc('puffy_parka', 'Puffy Parka', {'cotton_cloth': 4, 'yarn': 3}, tier=2),
 rc('ice_cleats', 'Ice Cleats', {'leather': 2, 'iron_bar': 1}, tier=2), rc('mitten_paws', 'Mitten Paws', {'yarn': 4, 'leather': 1}, tier=2),
 rc('prism_lance', 'Prism Lance', {'steel_bar': 4, 'crystal_glass': 2, 'fine_leather': 1}, tier=3, tool=True), rc('crystal_parka', 'Crystal Parka', {'puffy_parka': 1, 'crystal_refined': 4, 'plating': 1}, tier=3),
 rc('courage_scarf', 'Scarf of Courage', {'fine_fabric': 3, 'yarn': 4}, tier=3), rc('flipper_belt', 'Flipper Belt', {'fine_leather': 2, 'gear': 2}, tier=3), rc('aurora_hood', 'Aurora Hood', {'fine_fabric': 2, 'crystal_glass': 1}, tier=3),
 rc('bell_collar', 'Bell Collar', {'gold_bar': 2}, tier=3), rc('starheart_blade', 'Starheart Blade', {'dark_bar': 3, 'crystal_battery': 2, 'star_dust': 2}, tier=4, tool=True),
 rc('starlight_mantle', 'Starlight Mantle', {'crystal_parka': 1, 'moonweave': 2, 'crystal_battery': 1}, tier=4)]
books['litter'] = [rc('litter_box', 'Litter Box', {'sand': 4, 'clay': 1}, n=2), rc('tuna_treat', 'Tuna Treat', {'minnow': 2}, n=2), rc('scented_litter', 'Scented Litter Box', {'litter_box': 1, '#herb': 1}, tier=2),
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
# The armour pieces nothing made before (audit loop 3): Crystal and Moon sets,
# +1 tempering for every set, the Neon Jacket.
SLOTS = {'helm': 2, 'chest': 4, 'legs': 3, 'boots': 2, 'gloves': 1, 'shield': 3, 'cape': 2, 'belt': 1}   # same bar counts as the copper..gold sets
# 1) Crystal set: anvil recipe tier 4 (needs Smithy t3 + Mining Lv7), the step after gold
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

used = {r['id'] for b in books.values() for r in b}
lost = [i for i in old if i not in used and i not in ('glass', 'leather', 'fence_kit')]
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
json.dump(I, open(D + 'items.json', 'w'), indent=1, ensure_ascii=False)
print('stations', sum(1 for v in B.values() if isinstance(v, dict) and v.get('thing') == 'station'), 'recipes', {k: len(v) for k, v in R.items() if isinstance(v, list)}, 'moved to workbench:', lost)
print('art missing:', [(k, t['name']) for k, v in B.items() if isinstance(v, dict) for t in v.get('tiers', []) if t.get('art_missing')])
