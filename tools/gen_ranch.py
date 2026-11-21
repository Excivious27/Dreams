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
                 voice='quack', grow_days=7, buy=dict(seller='hazel', price=900, tier=2),
                 art=dict(adult='duck2', baby=['duck2', 'baby'], variants=[dict(id='mallard', art='duck2', weight=90),
                      dict(id='snow', art='duck2', weight=6, rare=True, tint='#e8eef5')]),
                 product=dict(id='duck_egg', every_days=1, needs_mood=30, extra=['feather', 0.15]), feed='hay',
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
                  product=dict(id='sheep_wool', every_days=2, needs_mood=40), feed='hay',
                  breed=dict(days=8, litter=[1, 1], min_friend=300, chance=0.35)),
    'goat': dict(name='Goat', name_gang='Goat', home='barn', group='beast', space=2, height_px=20, baby_h=12,
                 voice='bleat', grow_days=8, buy=dict(seller='tam', price=1000, tier=2),
                 art=dict(adult='goat2', baby=['goat_kid', 'idle'], variants=[dict(id='white', art='goat2', weight=60),
                      dict(id='brown', art='goat', weight=35), dict(id='chocolate', art='goat2', weight=5, rare=True, tint='#7a4a30')]),
                 product=dict(id='goat_milk', every_days=1, needs_mood=40), feed='hay',
                 breed=dict(days=7, litter=[1, 2], min_friend=300, chance=0.35)),
    'llama': dict(name='Llama', name_gang='Llama', home='barn', group='beast', space=3, height_px=30, baby_h=16,
                  voice='hum', grow_days=12, buy=dict(seller='tam', price=1800, tier=2),
                  art=dict(adult='llama', baby=['llama_cria', 'idle'], variants=[dict(id='cream', art='llama', weight=60),
                       dict(id='brown', art='llama_b', weight=35), dict(id='white', art='llama', weight=5, rare=True, tint='#f4f0ea')]),
                  product=dict(id='sheep_wool', every_days=1, needs_mood=50), feed='hay',
                  breed=dict(days=10, litter=[1, 1], min_friend=400, chance=0.3)),
    'pig': dict(name='Pig', name_gang='Hog', home='sty', group='beast', space=2, height_px=17, baby_h=9,
                voice='oink', grow_days=10, buy=dict(seller='hazel', price=3200, tier=2),
                art=dict(adult='pig_a', baby=['piglet', 'idle'], variants=[dict(id='pink', art='pig_a', weight=60),
                     dict(id='spotted', art='pig_b', weight=35), dict(id='ginger', art='pig_a', weight=5, rare=True, tint='#d0703a')]),
                product=dict(id='truffle', every_days=2, needs_mood=50, dig=True), feed='hay',
                breed=dict(days=6, litter=[1, 2], min_friend=300, chance=0.3)),
    'rabbit': dict(name='Rabbit', name_gang='Rabbit', home='hutch', group='small', space=1, height_px=10, baby_h=6,
                   voice='squeak', grow_days=5, buy=dict(seller='posy', price=700, tier=1),
                   art=dict(adult='rabbit_brown', baby=['rabbit_brown', 'idle'], variants=[dict(id='brown', art='rabbit_brown', weight=55),
                        dict(id='white', art='rabbit_white', weight=40), dict(id='silver', art='rabbit_white', weight=5, rare=True, tint='#b8bcc8')]),
                   product=dict(id='rabbit_fur', every_days=2, needs_mood=40), feed='hay',
                   breed=dict(days=5, litter=[1, 2], min_friend=200, chance=0.3)),
    'bees': dict(name='Bee Hive', name_gang='Hive', home='apiary', group='insect', space=1, height_px=8, baby_h=8,
                 voice='buzz', grow_days=0, buy=dict(seller='posy', price=800, tier=1), pet_word='tend',
                 art=dict(adult='bee_swarm', baby=['bee_swarm', 'idle'], variants=[dict(id='honeybee', art='bee_swarm', weight=100)]),
                 product=dict(id='honey', every_days=3, needs_mood=0, extra=['beeswax', 0.35]), feed='forage',
                 breed=dict(days=7, litter=[1, 1], min_friend=200, chance=0.2)),
}

# Planned rows: species the schema carries before their art lands (unbuyable, read by nothing at runtime).
# C11b moved chrome_hen, moon_hare and ostrich into C11B below (their art landed in the C11b art lane).
PLANNED = {}

# ---- C11b creatures (CONDUCT 11b P1): exotics (both arcs), fantastic (penguins), lab strains (gangsters) ----
# Art comes from the C11b art lane: art/gen/animals/_ranch_art_c11b.json (adult strip = the species id, baby =
# <id>_baby, variants/rare/shorn as listed there, heights from its meta). One row per creature:
#   sid: (family, home, group, space, voice, grow_days, buy, product, breed, names, pet_word, source, habitat)
#   buy: (seller, price, home tier) or None (earned only: quest, region or lab; buy.price 0, never at a counter)
#   product: (item, every_days, needs_mood, extra or None); breed: (egg item or '', days, litter, min_friend, chance)
#   habitat (read by P2's Ranch.comfort when present): likes [seasons/weather], night_goods, needs_add (an add id on
#   some tier of its home), hates_heater. Lab rows carry lab=(station, tier, recipe need) for the Gene Splicer.
# Values follow TIER_LADDER below (c11b_12-04); econ_check.py re-checks every row.
C11B = {
    # exotics: bought (Hazel/Tam; P3 may move ostrich/emu to Old Rahim with buy.seller 'rahim' once his counter exists)
    'ostrich': ('exotics', 'enclosure', 'bird', 3, 'hoot', 14, ('hazel', 4800, 1), ('ostrich_egg', 2, 60, ['plume', 0.2]),
                ('ostrich_egg', 6, [1, 1], 0, 0.0), 'big_bird', 'pat', 'Hazel imports them once you have an Exotic Enclosure (Sunscorch stock)', dict(likes=['summer'])),
    'emu': ('exotics', 'enclosure', 'bird', 3, 'drum', 12, ('hazel', 3600, 1), ('emu_egg', 2, 55, ['plume', 0.15]),
            ('emu_egg', 5, [1, 1], 0, 0.0), 'big_bird', 'pat', 'Hazel, once you have an Exotic Enclosure', dict(likes=['summer'])),
    'alpaca': ('exotics', 'barn', 'beast', 2, 'hum', 10, ('tam', 1800, 2), ('alpaca_fleece', 2, 50, None),
               ('', 10, [1, 1], 400, 0.3), 'beast', 'pet', 'Tam, once you have the Big Barn', {}),
    'komodo': ('exotics', 'enclosure', 'beast', 4, 'hiss', 20, None, ('shed_scale', 5, 70, None),
               ('', 14, [1, 1], 700, 0.15), 'reptile', 'scratch', 'Quest: a Sun Drake hatchling (penguins) / a rescued Komodo (gangsters)', dict(likes=['summer'], needs_add='heater')),
    'snow_yak': ('exotics', 'barn', 'beast', 2, 'moo', 12, ('tam', 2600, 3), ('yak_wool', 2, 50, ['milk', 0.25]),
                 ('', 10, [1, 1], 400, 0.3), 'frost', 'pet', 'Tam, once you have the Deluxe Barn (Frostpeak stock)', dict(likes=['winter', 'snow'], hates_heater=True)),
    'peacock': ('exotics', 'aviary', 'bird', 1, 'peep', 9, ('hazel', 2400, 1), ('peacock_feather', 2, 50, None),
                ('', 6, [1, 1], 0, 0.0), 'bird', 'pet', 'Hazel, once you have an Aviary', {}),
    'tortoise': ('exotics', 'terrarium', 'small', 2, 'critter', 20, ('posy', 1600, 1), ('shell_moss', 2, 40, None),
                 ('', 14, [1, 1], 400, 0.2), 'reptile', 'pat', 'Posy, once you have a Terrarium', {}),
    'buffalo': ('exotics', 'barn', 'beast', 3, 'moo', 12, ('tam', 3000, 3), ('buffalo_milk', 1, 50, None),
                ('', 12, [1, 1], 400, 0.3), 'beast', 'pet', 'Tam, once you have the Deluxe Barn', dict(likes=['rain'])),
    # fantastic creatures (penguin arc): earned in the places they come from (P3 hands them out via Ranch gifts)
    'crystal_hen': ('fantastic', 'coop', 'bird', 1, 'cluck', 7, None, ('crystal_egg', 2, 40, None),
                    ('crystal_egg', 4, [1, 1], 0, 0.0), 'crystal', 'pet', 'Crystopia: a hen that pecks at crystal dust', {}),
    'star_sheep': ('fantastic', 'barn', 'beast', 2, 'sheep', 9, None, ('star_wool', 2, 50, None),
                   ('', 9, [1, 1], 300, 0.3), 'moon', 'pet', 'The Moon: a lamb from the Star Station', dict(night_goods=True)),
    'moon_hare': ('fantastic', 'hutch', 'small', 1, 'thump', 6, None, ('moon_fluff', 2, 40, None),
                  ('', 6, [1, 2], 200, 0.3), 'moon', 'pet', 'The Moon pad: a hare that hopped aboard', dict(night_goods=True)),
    'star_jelly': ('fantastic', 'tide_pool', 'small', 1.5, 'bubble', 8, None, ('star_dust', 2, 40, None),
                   ('', 8, [1, 1], 300, 0.25), 'reef', 'tend', 'Star Station: a jelly drifting in the tanks', dict(night_goods=True)),
    'glow_gecko': ('fantastic', 'terrarium', 'small', 1, 'critter', 7, None, ('glowcap', 2, 40, None),
                   ('', 7, [1, 2], 200, 0.3), 'glow', 'pat', 'Green Planet: a gecko in the glowcap groves', dict(likes=['rain'])),
    'coral_seahorse': ('fantastic', 'tide_pool', 'small', 1.5, 'bubble', 8, None, ('pearl', 3, 50, ['tide_pearl', 0.03]),
                       ('', 9, [1, 2], 300, 0.25), 'reef', 'tend', 'Coral Reach: a seahorse that followed your boat', {}),
    'kelp_calf': ('fantastic', 'tide_pool', 'beast', 2, 'moo', 10, None, ('sea_milk', 1, 50, None),
                  ('', 10, [1, 1], 300, 0.3), 'reef', 'pet', 'Kelp Hollow: a gentle sea-calf', {}),
    'frost_otter': ('fantastic', 'tide_pool', 'small', 1.5, 'squeak', 8, None, ('ice_pike', 3, 50, None),
                    ('', 8, [1, 2], 300, 0.3), 'frost', 'pet', 'Frostfin Isle: an otter that brings you fish', dict(likes=['winter', 'snow'], hates_heater=True)),
    'ember_newt': ('fantastic', 'ember_pit', 'small', 1, 'critter', 7, None, ('ember_scale', 2, 40, None),
                   ('', 7, [1, 2], 200, 0.3), 'ember', 'pat', 'Emberclaw Atoll: a newt that loves warm rocks', dict(likes=['summer'], needs_add='heater')),
    'cloud_sheep': ('fantastic', 'barn', 'beast', 2, 'sheep', 9, None, ('storm_fluff', 3, 50, None),
                    ('', 9, [1, 1], 300, 0.3), 'sky', 'pet', 'Cloud Isles: a lamb made mostly of fluff', dict(likes=['rain'])),
    'storm_roc': ('fantastic', 'aviary', 'bird', 1.5, 'whistle', 14, None, ('roc_feather', 2, 60, ['storm_eye', 0.01]),
                  ('roc_egg', 8, [1, 1], 0, 0.0), 'sky', 'pat', 'Windward: the egg from the Storm Roc nest', dict(likes=['rain'])),
    'lantern_moth': ('fantastic', 'aviary', 'insect', 1, 'buzz', 6, None, ('wisp_thread', 2, 40, None),
                     ('', 6, [1, 2], 200, 0.3), 'glow', 'tend', 'Gloamwood: a moth that glows like a lamp', dict(night_goods=True)),
    'moon_cow': ('fantastic', 'star_dome', 'beast', 2, 'moo', 10, None, ('moon_milk', 1, 50, None),
                 ('', 10, [1, 1], 300, 0.3), 'moon', 'pet', 'The Moon: a calf from the low-gravity meadow', dict(night_goods=True)),
    'aurora_fox': ('fantastic', 'star_dome', 'small', 1.5, 'purr', 9, None, ('aurora_tuft', 2, 50, None),
                   ('', 9, [1, 2], 300, 0.25), 'frost', 'pet', 'Frostpeak: a fox under the northern lights', dict(likes=['winter'], night_goods=True)),
    'deep_glowworm': ('fantastic', 'terrarium', 'insect', 1, 'critter', 6, None, ('glow_silk', 2, 40, None),
                      ('', 6, [1, 2], 200, 0.3), 'glow', 'tend', 'The Hollow: a glowworm from the deep caves', dict(night_goods=True)),
    'frost_wyrmling': ('fantastic', 'star_dome', 'beast', 2, 'whistle', 21, None, ('moon_shard', 14, 70, None),
                       ('', 28, [1, 1], 900, 0.05), 'frost', 'scratch', 'Frostpeak Summit: the egg left after the summit boss (one per save)', dict(likes=['winter', 'snow'], hates_heater=True)),
    # lab strains (gangster arc): spliced at the Gene Splicer, cute cyber, within +-20% of the classic animal in the same home
    'chrome_hen': ('lab', 'coop', 'bird', 1, 'cluck', 7, None, ('circuit_egg', 2, 30, None),
                   ('circuit_egg', 3, [1, 1], 0, 0.0), 'lab', 'pet', 'Gene Splicer: a hen with a polished chrome comb', {}),
    'glow_sheep': ('lab', 'barn', 'beast', 2, 'sheep', 8, None, ('glow_wool', 2, 40, None),
                   ('', 8, [1, 1], 300, 0.35), 'lab', 'pet', 'Gene Splicer: wool that glows after dark', dict(night_goods=True)),
    'circuit_goat': ('lab', 'barn', 'beast', 2, 'bleat', 8, None, ('coolant', 1, 40, None),
                     ('', 7, [1, 2], 300, 0.35), 'lab', 'pet', 'Gene Splicer: a goat with circuit-trace horns', {}),
    'turbo_bunny': ('lab', 'hutch', 'small', 1, 'thump', 5, None, ('static_fluff', 2, 40, None),
                    ('', 5, [1, 2], 200, 0.3), 'lab', 'pet', 'Gene Splicer: a bunny with springy chrome feet', {}),
    'circuit_cow': ('lab', 'barn', 'beast', 2, 'moo', 10, None, ('synth_milk', 1, 40, None),
                    ('', 10, [1, 1], 300, 0.35), 'lab', 'pet', 'Gene Splicer: a cow with a soft blue status light', {}),
    'drone_hog': ('lab', 'sty', 'beast', 2, 'oink', 10, None, ('circuit_board', 1, 50, ['data_chip', 0.05]),
                  ('', 6, [1, 3], 300, 0.3), 'lab', 'pet', 'Gene Splicer: a hog with little drone rotors', {}),
    'volt_gecko': ('lab', 'terrarium', 'small', 2, 'zap', 7, None, ('static_scale', 2, 40, None),
                   ('', 7, [1, 2], 200, 0.3), 'lab', 'pat', 'Gene Splicer: a gecko that hums with a tiny spark', {}),
    'chrome_runner': ('lab', 'enclosure', 'bird', 3, 'hoot', 14, None, ('alloy_egg', 2, 60, None),
                      ('alloy_egg', 6, [1, 1], 0, 0.0), 'lab', 'pat', 'Gene Splicer: a runner bird with chrome legs', {}),
}
NAME_OF = {'komodo': ('Sun Drake', 'Komodo Dragon'), 'snow_yak': ('Snow Yak', 'Snow Yak'), 'coral_seahorse': ('Coral Seahorse', 'Coral Seahorse'),
           'deep_glowworm': ('Deep Glowworm', 'Deep Glowworm'), 'frost_wyrmling': ('Frost Wyrmling', 'Frost Wyrmling')}
# Gene Splicer recipes (P-other: the station's craft hands the animal to Ranch.give); data only here, checked for items.
LAB = {'chrome_hen': {'egg': 1, 'circuit_board': 2}, 'glow_sheep': {'sheep_wool': 3, 'circuit_board': 2}, 'circuit_goat': {'goat_milk': 2, 'circuit_board': 3},
       'turbo_bunny': {'rabbit_fur': 2, 'circuit_board': 2}, 'circuit_cow': {'milk': 3, 'circuit_board': 3, 'data_chip': 1},
       'drone_hog': {'truffle': 2, 'circuit_board': 4, 'data_chip': 1}, 'volt_gecko': {'circuit_board': 3, 'data_chip': 1},
       'chrome_runner': {'circuit_board': 6, 'data_chip': 2}}
LAB_TIER = {'chrome_hen': 1, 'turbo_bunny': 1, 'glow_sheep': 2, 'circuit_goat': 2, 'circuit_cow': 2, 'drone_hog': 3, 'volt_gecko': 3, 'chrome_runner': 3}

# One value ladder (c11b_12-04): goods value per pen cell per day by class (warn outside), payback days for
# bought animals = price / (goods per day - hay per day) (fail outside). Earned rows (buy.price 0) use a notional
# price of 40 x goods per day. Lab strains stay within +-20% of the classic in the same home (c11b_03-03).
TIER_LADDER = dict(classic=(10, 40), exotic=(20, 75), fantastic=(25, 90), lab=(10, 80), payback=(20, 60), lab_vs_classic=0.2,
                   unique_cap=200)
LAB_CLASSIC = {'coop': 'chicken', 'barn': None, 'hutch': 'rabbit', 'sty': 'pig', 'terrarium': 'tortoise', 'enclosure': 'ostrich'}
LAB_PAIR = {'glow_sheep': 'sheep', 'circuit_goat': 'goat', 'circuit_cow': 'cow'}

# New goods (items.json rows; gen_stations lifts made goods to its ECON floors). All ages: never meat; lab goods
# are materials, never food (nobody eats circuitry).
C11B_ITEMS = {
    'ostrich_egg': ('Ostrich Egg', 'food', 320, 3, 'egg', 'Huge and cream-coloured. One makes breakfast for a whole table.'),
    'emu_egg': ('Emu Egg', 'food', 220, 3, 'egg', 'Deep green and glossy, like a polished stone.'),
    'plume': ('Plume', 'material', 120, 3, '', 'A long, soft plume dropped by a big bird. Hat makers love them.'),
    'alpaca_fleece': ('Alpaca Fleece', 'material', 90, 2, '', 'Silky and warm. Spins into fine yarn.'),
    'shed_scale': ('Shed Scale', 'material', 600, 4, '', 'A shiny scale shed by a happy drake. It grows a new one.'),
    'yak_wool': ('Yak Wool', 'material', 110, 3, '', 'Thick winter wool, brushed out, never cut close.'),
    'peacock_feather': ('Peacock Feather', 'material', 140, 3, '', 'An eye-patterned feather the peacock dropped while showing off.'),
    'shell_moss': ('Shell Moss', 'forage', 90, 2, '', 'Soft green moss that grows on a tortoise shell. Brewers prize it.'),
    'buffalo_milk': ('Buffalo Milk', 'food', 75, 3, 'milk', 'Rich, creamy milk. Makes the best soft cheese.'),
    'crystal_egg': ('Crystal Egg', 'food', 160, 4, 'egg', 'A faceted egg that rings softly when tapped.'),
    'star_wool': ('Star Wool', 'material', 200, 4, '', 'Lavender wool with tiny twinkles in it.'),
    'moon_fluff': ('Moon Fluff', 'material', 140, 4, '', 'Fluff so light it floats for a moment before landing.'),
    'sea_milk': ('Sea Milk', 'food', 110, 4, 'milk', 'Cool, faintly salty and very creamy.'),
    'ember_scale': ('Ember Scale', 'material', 150, 4, '', 'Still warm. A little fuel that never smokes.'),
    'roc_feather': ('Roc Feather', 'material', 240, 4, '', 'A storm-grey flight feather that crackles in the wind.'),
    'roc_egg': ('Roc Egg', 'material', 400, 5, '', 'Too precious to cook. The incubator in an Aviary can hatch it.'),
    'aurora_tuft': ('Aurora Tuft', 'material', 180, 4, '', 'A tuft of fox fur that shimmers green and gold.'),
    'glow_silk': ('Glow Silk', 'material', 140, 4, '', 'Fine thread spun by glowworms, faintly lit.'),
    'moon_milk': ('Moon Milk', 'food', 150, 4, 'milk', 'Pale silver milk from a moon cow.'),
    'circuit_egg': ('Circuit Egg', 'material', 48, 2, '', 'Warm, smooth and faintly humming. Crack it for parts.'),
    'glow_wool': ('Glow Wool', 'material', 56, 2, '', 'Soft wool that glows after dark.'),
    'coolant': ('Coolant', 'material', 48, 2, '', 'Cold blue and never spills. Bots love it.'),
    'static_fluff': ('Static Fluff', 'material', 70, 2, '', 'It sticks to everything and crackles when you pet it.'),
    'synth_milk': ('Synth Milk', 'material', 43, 2, '', 'Smooth and blue-white. Machines run cooler on it.'),
    'static_scale': ('Static Scale', 'material', 90, 3, '', 'A tiny scale with a spark trapped inside.'),
    'alloy_egg': ('Alloy Egg', 'material', 300, 4, '', 'A heavy metal-shelled egg. Crack it for rare parts.'),
    # made goods (recipes in gen_stations.py)
    'grand_omelette': ('Grand Omelette', 'food', 420, 3, '', 'One giant egg, folded with herbs. Feeds everyone.'),
    'fine_yarn': ('Fine Yarn', 'craft', 120, 3, '', 'Silky yarn from alpaca fleece or yak wool.'),
    'scale_charm': ('Scale Charm', 'gift', 800, 4, '', 'A polished drake scale on a cord. Said to bring warm days.'),
    'moon_cheese': ('Moon Cheese', 'food', 240, 4, '', 'A pale round cheese with little craters.'),
    'glow_yarn': ('Glow Yarn', 'craft', 80, 2, '', 'Yarn that glows softly. Neon tailors want it.'),
    'moss_tea_blend': ('Moss Tea Blend', 'food', 130, 2, '', 'Shell moss and herbs, dried for a calming tea.'),
    'buffalo_mozzarella': ('Buffalo Mozzarella', 'food', 120, 3, '', 'Soft, fresh and milky.'),
    'star_yarn': ('Star Yarn', 'craft', 280, 4, '', 'Yarn spun from star wool. It twinkles.'),
    'cloud_yarn': ('Cloud Yarn', 'craft', 300, 4, '', 'Lighter than air, nearly.'),
    'ember_charm': ('Ember Charm', 'gift', 220, 4, '', 'A warm scale charm. Good company on a cold night.'),
    'feather_fan': ('Feather Fan', 'gift', 220, 3, '', 'A showy fan of dropped feathers.'),
    'giant_egg_custard': ('Giant Egg Custard', 'food', 300, 3, '', 'A whole big egg baked into a wobbly custard.'),
}
# Existing goods the ladder retunes (c11b_12-03): lifted, never lowered.
VALUE_LIFT = {'sheep_wool': 48}
STORY_NAMES = {'Pip', 'Pip-Pip', 'Nova', 'Catkins', 'Big Jim', 'Star Crystal'}
LORE_BANNED = re.compile(r'grump|crystal_baby|crystal baby|finargle', re.I)
BANNED_VOICE = {'roar', 'growl', 'monster', 'scream', 'die', 'hurt', 'beast_down', 'knockout', 'boom'}

# ---- buildings -------------------------------------------------------------------------------------------
# cap: animals housed; adds: feeder (silo feeds the grown ones each night), incubator (eggs hatch),
# auto_water (+mood), heater (winter mood), breeding (two adults may have a baby). pen: [x, y, w, h]
# cells on the farm (P2 places and may move them; capacity never exceeds pen cells / home space).
# C11b (c11b_05-02/-04): each tier carries its footprint (cell [x, y], w, h: the Plans building, read by
# gen_stations.py) and its pen right in front of the door; check() keeps every pen touching its footprint's
# front, pens apart from each other, and the v2 homes inside the Pasture (PASTURE, P4's farm zone).
PASTURE = [39, 13, 22, 14]
BUILDINGS = {
    'coop': [dict(tier=1, cap=4, adds=[], pen=[25, 9, 6, 4]),
             dict(tier=2, cap=8, adds=['feeder', 'incubator'], pen=[25, 9, 6, 4]),
             dict(tier=3, cap=12, adds=['feeder', 'incubator', 'auto_water', 'heater'], pen=[24, 9, 7, 4])],
    'barn': [dict(tier=1, cap=4, adds=[], pen=[31, 6, 4, 3]),
             dict(tier=2, cap=8, adds=['feeder', 'breeding'], pen=[31, 5, 4, 4]),
             dict(tier=3, cap=12, adds=['feeder', 'breeding', 'auto_water', 'heater'], pen=[30, 5, 6, 4]),
             dict(tier=4, cap=16, adds=['feeder', 'breeding', 'auto_water', 'heater', 'big_stall'], pen=[30, 5, 6, 4],
                  paddock=[39, 25, 12, 2])],
    'hutch': [dict(tier=1, cap=4, adds=['breeding'], cell=[40, 13], w=2, h=2, pen=[40, 15, 3, 2]),
              dict(tier=2, cap=8, adds=['breeding', 'feeder', 'heater'], cell=[40, 13], w=2, h=2, pen=[40, 15, 4, 2])],
    'sty': [dict(tier=1, cap=2, adds=[], cell=[45, 13], w=3, h=2, pen=[45, 15, 3, 2]),
            dict(tier=2, cap=4, adds=['breeding', 'feeder'], cell=[45, 13], w=3, h=2, pen=[45, 15, 4, 2])],
    'apiary': [dict(tier=1, cap=2, adds=[], pen=[16, 5, 2, 1]),
               dict(tier=2, cap=4, adds=['breeding'], pen=[16, 5, 4, 1]),
               dict(tier=3, cap=6, adds=['breeding'], pen=[16, 5, 6, 1])],
    # v2 homes (C11b): exotics, birds that fly, reptiles/insects, and the penguin-arc habitats
    'enclosure': [dict(tier=1, cap=2, adds=['feeder'], cell=[50, 13], w=4, h=3, pen=[50, 16, 6, 2]),
                  dict(tier=2, cap=4, adds=['feeder', 'incubator', 'breeding', 'heater'], cell=[50, 13], w=4, h=3, pen=[50, 16, 6, 2])],
    'aviary': [dict(tier=1, cap=4, adds=['perch'], cell=[57, 13], w=3, h=3, pen=[57, 16, 4, 2]),
               dict(tier=2, cap=8, adds=['perch', 'feeder', 'incubator', 'heater'], cell=[57, 13], w=3, h=3, pen=[57, 16, 4, 2])],
    'terrarium': [dict(tier=1, cap=2, adds=['heater'], cell=[40, 19], w=3, h=2, pen=[40, 21, 4, 2]),
                  dict(tier=2, cap=4, adds=['heater', 'breeding', 'auto_water'], cell=[40, 19], w=3, h=2, pen=[40, 21, 4, 2])],
    'tide_pool': [dict(tier=1, cap=4, adds=['breeding', 'auto_water'], cell=[45, 19], w=3, h=2, pen=[45, 21, 4, 3])],
    'ember_pit': [dict(tier=1, cap=4, adds=['breeding', 'heater'], cell=[50, 19], w=2, h=2, pen=[50, 21, 4, 2])],
    'star_dome': [dict(tier=1, cap=4, adds=['breeding', 'moon_lamp'], cell=[55, 19], w=3, h=3, pen=[55, 22, 4, 3])],
}
HOME_SPACE = {'coop': 1, 'barn': 1.5, 'hutch': 0.75, 'sty': 1.5, 'apiary': 1,   # min cells per animal (pen check)
              'enclosure': 3, 'aviary': 0.75, 'terrarium': 2, 'tide_pool': 1.5, 'ember_pit': 1, 'star_dome': 1.5}
V2_HOMES = {'hutch', 'sty', 'enclosure', 'aviary', 'terrarium', 'tide_pool', 'ember_pit', 'star_dome'}  # live in PASTURE
# penguin-arc habitats only appear in the penguin arc (gangster lab strains use coop/barn/hutch/sty/terrarium/enclosure)
HOME_ARC = {'tide_pool': 'penguins', 'ember_pit': 'penguins', 'star_dome': 'penguins'}

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
    friend_max=1000, pet_friend=15, fed_friend=5,   # c11b_12-09: gold ~day 35-45 of daily care, max ~day 65 missed_pet_friend=-10, unfed_friend=-15,
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
    'bird': ['Clementine', 'Dumpling', 'Nugget', 'Hazelnut', 'Penny', 'Biscuit', 'Daisy', 'Pickles', 'Marigold', 'Poppy', 'Butterbean', 'Sprout'],
    'beast': ['Clover', 'Bramble', 'Acorn', 'Thistle', 'Buttons', 'Hollyhock', 'Truffle', 'Bluebell', 'Oakley', 'Mossy', 'Pumpkin', 'Willow'],
    'small': ['Thumper', 'Cotton', 'Mochi', 'Dandelion', 'Pudding', 'Nibbles', 'Fluff', 'Peanut'],
    'big_bird': ['Dune', 'Sahara', 'Tumbleweed', 'Rocket', 'Twiggy', 'Bertha', 'Stilts', 'Duster'],
    'reptile': ['Sunny', 'Ember', 'Pebble', 'Basil', 'Ziggy', 'Dusty', 'Gumdrop', 'Shelly'],
    'crystal': ['Prism', 'Facet', 'Glimmer', 'Quartzy', 'Twinkle', 'Geode'],
    'moon': ['Luna', 'Crater', 'Comet', 'Orbit', 'Selene', 'Moonbeam', 'Halo', 'Eclipse'],
    'reef': ['Coral', 'Ripple', 'Splash', 'Bubbles', 'Lagoon', 'Shoal', 'Marina', 'Wavelet'],
    'glow': ['Flicker', 'Lantern', 'Glimmer', 'Spark', 'Firefly', 'Wisp'],
    'ember': ['Cinder', 'Ash', 'Toasty', 'Blaze', 'Kindle', 'Sizzle'],
    'sky': ['Gale', 'Stratus', 'Zephyr', 'Breeze', 'Thunder', 'Puff', 'Cirrus', 'Drizzle'],
    'frost': ['Frosty', 'Icicle', 'Sleet', 'Flurry', 'Snowdrop', 'Aurora', 'Blizzard', 'Chill'],
    'lab': ['Bolt', 'Widget', 'Sprocket', 'Byte', 'Pixel', 'Gizmo', 'Servo', 'Chip', 'Diode', 'Ratchet'],
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
# ---- sellers (fix2): every species.buy.seller has a counter Shops.run reaches, in both arcs ---------------
# seller -> where the counter stands (interior id + cell; Shops.ranch_counters injects it, TownHours.counter_shut
# keeps the hours), the keeper's words per arc, and who takes over when the seller is away (any away flag set;
# "gang:" flags only count in the gangster arc). Hazel also sells from her morning market stall (Town.MARKET_STALLS).
SELLERS = {
    'tam': dict(name='Tam', interior='', cell=None, away=[], fallback='',
                greet="Wool, hay, and saplings for the orchard. The sheep did most of the work.",
                greet_gang="Wool, hay, and saplings for the orchard. The sheep did most of the work."),
    'hazel': dict(name='Hazel', interior='hazel_house', cell=[5, 5], away=[], fallback='',
                  greet="Hens, ducks, cows and pigs, all hand-raised in my yard. Who's coming home with you?",
                  greet_gang="Birds, cattle and hogs off my own yard. Cash, and treat them right."),
    'posy': dict(name='Posy', interior='bakery', cell=[5, 5], away=['posy_gone', 'gang:shop_1'], fallback='hazel',
                 greet="Rabbits from out back and hives for honey. Bees make the best cakes, you know.",
                 greet_gang="Rabbits and hives off the back lot. Honey sells, and nobody asks where from."),
}
# Hazel's welcome gift (Mail RANCH_LETTERS "Your hens are settled"): animals that join the roster the first
# time a home reaches a tier (Ranch.starter_gift), always leaving room to buy more (check() keeps it under cap).
STARTER = {
    'coop': {'1': [['chicken', 'white'], ['chicken', 'white']], '2': [['duck', 'mallard']]},
    'barn': {'1': [['cow', 'brown'], ['sheep', 'white']], '2': [['goat', 'white']]},
}
LEGACY_MOVED = {'cow_bw_36_8': 'cow_bw_31_8'}  # spawn cells that moved before C11 (keep the higher streak)

# ---- processing (the stations P3 builds; listed here so recipes and quests share one table) --------------
PROCESSING = {
    'egg': ['mayonnaise'], 'duck_egg': ['mayonnaise'], 'milk': ['cheese', 'butter'], 'goat_milk': ['goat_cheese'],
    'sheep_wool': ['yarn'], 'rabbit_fur': ['yarn'], 'honey': ['flower_mead'], 'beeswax': ['candle'], 'truffle': ['truffle_broth'],
    # C11b goods (recipes in gen_stations.py)
    'ostrich_egg': ['grand_omelette', 'giant_egg_custard'], 'emu_egg': ['grand_omelette', 'giant_egg_custard'], 'plume': ['feather_fan'],
    'peacock_feather': ['feather_fan'], 'roc_feather': ['feather_fan'], 'alpaca_fleece': ['fine_yarn'], 'yak_wool': ['fine_yarn'],
    'shed_scale': ['scale_charm'], 'ember_scale': ['ember_charm'], 'buffalo_milk': ['buffalo_mozzarella'], 'moon_milk': ['moon_cheese'],
    'sea_milk': ['cheese'], 'star_wool': ['star_yarn'], 'moon_fluff': ['star_yarn'], 'storm_fluff': ['cloud_yarn'], 'glow_wool': ['glow_yarn'],
    'glow_silk': ['fine_fabric'], 'aurora_tuft': ['star_yarn'], 'crystal_egg': ['giant_egg_custard'], 'shell_moss': ['moss_tea_blend'],
    'circuit_egg': ['circuit_board'], 'alloy_egg': ['circuit_board', 'data_chip'], 'coolant': ['crystal_battery'],
    'static_fluff': ['glow_yarn'], 'synth_milk': ['crystal_battery'], 'static_scale': ['crystal_battery'],
}
TAG_SKIP = {'ice_pike', 'moon_shard', 'circuit_board', 'data_chip', 'tide_pearl', 'storm_eye', 'pearl', 'star_dust', 'glowcap',
            'storm_fluff', 'wisp_thread'}   # goods that already exist outside the ranch keep their bag group

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
        out = json.load(open(p))
    except Exception:
        out = {}
    try:  # C11b P2 hook: rare looks' own strips (tools/slice_ranch_variants.py) replace their tints
        for sid, row in json.load(open(os.path.join(ART, 'animals', '_ranch_art_rare.json'))).items():
            out.setdefault(sid, {}).setdefault('variants', []).extend(row.get('variants', []))
    except Exception:
        pass
    return out


def art_c11b():
    try:
        return json.load(open(os.path.join(ART, 'animals', '_ranch_art_c11b.json')))
    except Exception:
        return {}


def c11b_species(items):
    """C11B rows -> SPECIES-shaped dicts (art, heights, variants from the C11b art table)."""
    art = art_c11b()
    out = {}
    for sid, (fam, home, group, space, voice, grow, buy, prod, breed, names, pet_word, source, habitat) in C11B.items():
        a = art.get(sid, {})
        hts = a.get('height', {})
        arc = {'exotics': '', 'fantastic': 'penguins', 'lab': 'gangsters'}[fam]
        nm, ng = NAME_OF.get(sid, (sid.replace('_', ' ').title(),) * 2)
        variants = [dict(id='common', art=sid, weight=70)]
        for v in a.get('variants', []):
            variants.append(dict(id=v[len(sid) + 1:], art=v, weight=max(5, 25 // max(1, len(a.get('variants', []))))))
        for v in a.get('rare', []):
            variants.append(dict(id=v[len(sid) + 1:], art=v, weight=4, rare=True))
        row = dict(name=nm, name_gang=ng, home=home, group=group, space=space, voice=voice, grow_days=grow, arc=arc,
                   family=fam, height_px=int(hts.get(sid, 16)), baby_h=int(hts.get(sid + '_baby', max(6, int(hts.get(sid, 16) * 0.55)))),
                   buy=dict(seller=buy[0], price=buy[1], tier=buy[2]) if buy else dict(seller='hazel', price=0, tier=1),
                   art=dict(adult=sid, baby=[a.get('baby', sid + '_baby'), 'idle'], variants=variants),
                   product=dict(id=prod[0], every_days=prod[1], needs_mood=prod[2]), feed='hay', pet_word=pet_word,
                   breed=dict(days=breed[1], litter=breed[2], min_friend=breed[3], chance=breed[4]),
                   names_key=names, source=source, team=bool(a.get('team')), special=a.get('special', ''),
                   long_low=bool(a.get('long_low')))
        if a.get('shorn'):
            row['art']['shorn'] = a['shorn']
        if prod[3]:
            row['product']['extra'] = list(prod[3])
        if breed[0]:
            row['breed']['egg'] = breed[0]
        if habitat:
            row['habitat'] = dict(habitat)
        if sid in LAB:
            row['lab'] = dict(station='gene_splicer', tier=LAB_TIER[sid], need=dict(LAB[sid]))
        if fam == 'fantastic' and sid == 'frost_wyrmling':
            row['unique'] = True   # one per save (Summit egg): exempt from the per-cell ceiling
        out[sid] = row
    return out


def build():
    man = manifest()
    extra = art_extra()
    species = {}
    items = json.load(open(os.path.join(D, 'items.json')))
    for sid, s in list(SPECIES.items()) + list(c11b_species(items).items()):
        row = json.loads(json.dumps(s))
        row.setdefault('arc', '')
        row.setdefault('pet_word', 'pet')
        row['names'] = NAMES[row.pop('names_key', row['group'])]
        ex = extra.get(sid, {})
        for v in ex.get('variants', []):   # P6 renders: {id, art, weight, rare}
            if isinstance(v, dict) and v.get('id') and not any(o['id'] == v['id'] for o in row['art']['variants']):
                row['art']['variants'].append(v)
            elif isinstance(v, dict):
                for o in row['art']['variants']:
                    if o['id'] == v.get('id'):
                        o.update({k: v[k] for k in ('art', 'baby') if k in v}); o.pop('tint', None)
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
                legacy=LEGACY, legacy_moved=LEGACY_MOVED, planned=PLANNED, sellers=SELLERS, starter=STARTER,
                home_arc=HOME_ARC, pasture=PASTURE, ladder=TIER_LADDER), man


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
            cells = t['pen'][2] * t['pen'][3] + (t['paddock'][2] * t['paddock'][3] if t.get('paddock') else 0)
            if cells < t['cap'] * HOME_SPACE[home]:
                fails.append('%s tier %d: pen %d cells < cap %d x space %.2f' % (home, t['tier'], cells, t['cap'], HOME_SPACE[home]))
        if not any(s['home'] == home for s in data['species'].values()):
            fails.append('%s houses no species' % home)
    for row in LEGACY:
        if row[1] not in data['species']:
            fails.append('legacy %s: unknown species %s' % (row[0], row[1]))
        elif not any(v['id'] == row[2] for v in data['species'][row[1]]['art']['variants']):
            fails.append('legacy %s: unknown variant %s' % (row[0], row[2]))
    for sid, s in data['species'].items():   # fix2: every seller has a counter (or a fallback that has one)
        sel = s['buy']['seller']
        if sel not in SELLERS:
            fails.append('%s: seller %s has no SELLERS row' % (sid, sel))
        elif SELLERS[sel]['fallback'] and SELLERS[sel]['fallback'] not in SELLERS:
            fails.append('seller %s: fallback %s unknown' % (sel, SELLERS[sel]['fallback']))
    for sel, r in SELLERS.items():
        for w in (r['greet'], r['greet_gang']):
            if BANNED.search(w):
                fails.append('seller %s: banned word' % sel)
    for home, tiers in STARTER.items():
        got = 0
        for t, rows in sorted(tiers.items()):
            got += len(rows)
            cap = next((b['cap'] for b in BUILDINGS[home] if b['tier'] == int(t)), 0)
            if got >= cap:
                fails.append('starter %s tier %s: %d animals leave no room (cap %d)' % (home, t, got, cap))
            for sp, var in rows:
                if sp not in data['species'] or data['species'][sp]['home'] != home:
                    fails.append('starter %s: %s does not live there' % (home, sp))
                elif not any(v['id'] == var for v in data['species'][sp]['art']['variants']):
                    fails.append('starter %s: unknown variant %s' % (sp, var))
    for k, it in NEW_ITEMS.items():
        if BANNED.search(it['desc']):
            fails.append('item %s: banned word' % k)
    for v in RULES.values():
        if isinstance(v, str) and BANNED.search(v):
            fails.append('rules: banned word in %r' % v)
    fails += check_c11b(data, items)
    return fails


def _rects_hit(a, b):
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]


def _inside(a, z):
    return a[0] >= z[0] and a[1] >= z[1] and a[0] + a[2] <= z[0] + z[2] and a[1] + a[3] <= z[1] + z[3]


def check_c11b(data, items):
    """C11b self-checks: lore/name guards, all-ages voices, arcs, lab rows, habitat adds, footprints and pens."""
    fails = []
    try:
        npc_names = {str(v.get('name', '')) for v in json.load(open(os.path.join(D, 'npcs.json'))).values() if isinstance(v, dict)}
    except Exception:
        npc_names = set()
    taken = STORY_NAMES | npc_names
    for sid, s in data['species'].items():
        if LORE_BANNED.search(sid) or LORE_BANNED.search(s['name']) or LORE_BANNED.search(s['name_gang']):
            fails.append('%s: Grumps, crystal babies and foes are never ranch stock' % sid)
        for w in s['names']:
            if w in taken:
                fails.append('%s: pet name %r is a story/villager name' % (sid, w))
        if s['voice'] in BANNED_VOICE or s['voice'].startswith('shot'):
            fails.append('%s: voice %r is not all-ages' % (sid, s['voice']))
        home_arc = HOME_ARC.get(s['home'], '')
        if home_arc and s.get('arc', '') != home_arc:
            fails.append('%s: lives in %s (%s arc only) but its arc is %r' % (sid, s['home'], home_arc, s.get('arc', '')))
        for pid in [s['product']['id']] + ([s['product']['extra'][0]] if s['product'].get('extra') else []):
            if pid not in items:
                fails.append('%s: good %s not in items.json' % (sid, pid))
        if s.get('family') == 'lab':
            if s.get('arc') != 'gangsters' or int(s['buy']['price']) != 0:
                fails.append('%s: lab strains are gangster-only and never sold' % sid)
            for k in s.get('lab', {}).get('need', {}):
                if k not in items:
                    fails.append('%s: lab recipe needs unknown %s' % (sid, k))
            if 'lab' not in s:
                fails.append('%s: lab strain without a Gene Splicer recipe' % sid)
            if s.get('arc') == 'gangsters' and items.get(s['product']['id'], {}).get('type') == 'food':
                fails.append('%s: lab goods are never food' % sid)
        if s.get('family') == 'fantastic' and s.get('arc') != 'penguins':
            fails.append('%s: fantastic creatures are penguin-arc' % sid)
        need = s.get('habitat', {}).get('needs_add')
        if need and not any(need in t['adds'] for t in BUILDINGS[s['home']]):
            fails.append('%s: needs %s but no %s tier offers it' % (sid, need, s['home']))
        if int(s['buy']['price']) > 0 and int(s['buy']['tier']) > max(t['tier'] for t in BUILDINGS[s['home']]):
            fails.append('%s: buy tier %d beyond the %s tiers' % (sid, s['buy']['tier'], s['home']))
    # footprints and pens (c11b_05-02): pen in front of the door, no two homes' pens or footprints overlapping
    rects = []
    for home, tiers in BUILDINGS.items():
        for t in tiers:
            if 'cell' in t:
                fp = [t['cell'][0], t['cell'][1], t['w'], t['h']]
                pen = t['pen']
                if pen[1] != fp[1] + fp[3] or pen[0] > fp[0] + fp[2] - 1 or pen[0] + pen[2] - 1 < fp[0]:
                    fails.append('%s tier %d: pen %s not right in front of footprint %s' % (home, t['tier'], pen, fp))
                if home in V2_HOMES and not (_inside(fp, PASTURE) and _inside(pen, PASTURE)):
                    fails.append('%s tier %d: outside the pasture %s' % (home, t['tier'], PASTURE))
            elif home in V2_HOMES:
                fails.append('%s tier %d: v2 home without a footprint' % (home, t['tier']))
            if t.get('paddock') and not _inside(t['paddock'], PASTURE):
                fails.append('%s tier %d: paddock outside the pasture' % (home, t['tier']))
        last = tiers[-1]
        rects += [(home, last['pen'])] + ([(home, [last['cell'][0], last['cell'][1], last['w'], last['h']])] if 'cell' in last else []) \
            + ([(home, last['paddock'])] if last.get('paddock') else [])
    for i, (ha, ra) in enumerate(rects):
        for hb, rb in rects[i + 1:]:
            if ha != hb and _rects_hit(ra, rb):
                fails.append('%s %s overlaps %s %s' % (ha, ra, hb, rb))
    for sid in C11B:
        if sid not in data['species']:
            fails.append('C11b %s missing from species' % sid)
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
    for k, (nm, typ, v, tier, fam, desc) in C11B_ITEMS.items():
        cur = items.get(k, {})
        row = dict(name=nm, type=typ, value=int(v),   # gen_stations lifts made goods to its floors each run (fixed point)
                   rarity=['common', 'common', 'uncommon', 'rare', 'epic', 'legendary'][tier], tier=tier, desc=desc)
        if fam:
            row['family'] = fam
        if typ == 'food':
            row.setdefault('energy', int(cur.get('energy', min(80, 10 + v // 8))))
        cur.update(row)
        items[k] = cur
    for k, v in VALUE_LIFT.items():
        if k in items:
            items[k]['value'] = max(int(items[k].get('value', 0)), v)
    if 'hay' in items:
        items['hay']['desc'] = HAY_DESC
    data, man = build()
    for pid in data['products']:
        if pid in items and pid not in TAG_SKIP:
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
