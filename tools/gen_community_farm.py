#!/usr/bin/env python3
"""The community farm west of town (scenes/community_farm.tscn, `Commons`).

Writes data/community_farm.json (stages, volunteer schedule, spots, plots,
villager chatter, both arcs), the farm's own items into data/items.json and
its two kitchen recipes into data/recipes.json (ids prefixed cf_ / listed
below; re-runnable, everything else is left alone).
    python3 tools/gen_community_farm.py
Edit this file, never the JSON.
"""
import json, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
D = os.path.join(ROOT, "data")


def P(p, g=None):
    """A text for each arc (penguins, gangsters)."""
    return {"penguins": p, "gangsters": g if g is not None else p}


# ---- stages -----------------------------------------------------------------------
# need: item id -> n ("#veg" families, "#seed" = any seeds). task "debris" = clear the lot by hand.
# friend: villager -> friendship on completion. give: items. crystals. recipe: kitchen flag.
STAGES = [
    {"id": "clear", "name": P("Clear the land", "Clear the lot"), "task": "debris", "need": {},
     "desc": P("Brambles, boulders and fallen logs have swallowed the old commons. Clear every patch so there's room to dig.",
               "Years of dumped tyres, drums and junk. Haul every pile out so there's room to grow."),
     "done": P("Look at that. You can see the old furrows again. My gran planted potatoes right where you're standing.",
               "First time I've seen the ground here since I was a kid. Smells like dirt instead of oil. That's a start."),
     "crystals": 120, "give": {"seed_packet": 5}, "friend": {"hazel": 25, "sal": 10}},
    {"id": "shed", "name": P("Fix the tool shed"), "need": {"wood": 30, "plank": 10, "nails": 20},
     "desc": P("The old shed has no roof and one and a half walls. Timber, planks and nails, and Gideon says he'll lend a hammer.",
               "The shed's been stripped for scrap twice. Timber, planks and nails, and nobody's taking this one."),
     "done": P("A roof! Tools off the ground, compost bin round the side. Help yourself to the share crate: whatever we grow, a third is yours.",
               "Lock on the door, compost round the side. The share crate's yours: a third of everything we grow. That's the deal."),
     "crystals": 200, "give": {"fertilizer": 5}, "friend": {"hazel": 15, "gideon": 15, "sal": 15}},
    {"id": "beds", "name": P("Build raised beds"), "need": {"plank": 24, "stone": 30, "fiber": 20},
     "desc": P("Four raised beds so the soil drains and the rabbits have to work for it. Planks, stone for the footings, fibre for twine.",
               "Four raised beds: the ground under the lot isn't fit to eat from yet. Planks, stone footings, fibre for twine."),
     "done": P("Four beds, square and true. Finn's already arguing about who gets the sunny one.",
               "Four beds. Finn keeps calling them 'the plots', like it's a heist. Let him."),
     "crystals": 200, "give": {"seed_packet": 4}, "friend": {"hazel": 20, "finn": 15}},
    {"id": "seeds", "name": P("Donate seeds"), "need": {"#seed": 24}, "kinds": 3,
     "desc": P("Empty beds feed nobody. Two dozen seeds, at least three kinds: the volunteers plant whatever suits the season.",
               "Empty beds feed nobody. Two dozen seeds, three kinds or more: the crew plants whatever suits the season."),
     "done": P("Seeds are in! Wren wrote down a soup she makes from whatever comes up first. She says it's for you.",
               "Seeds are in. Wren's got a stew she makes from whatever comes up first. Here, it's yours now."),
     "crystals": 150, "give": {"commons_stew": 2}, "recipe": "cf_rec_stew", "friend": {"hazel": 20, "wren": 15, "wren_jr": 10, "mabel": 10}},
    {"id": "well", "name": P("Repair the well"), "need": {"stone": 40, "copper_bar": 4, "rope": 2},
     "desc": P("Hauling water from the river is breaking everyone's backs. Stone for the wall, copper for the pump, rope for the bucket.",
               "Hauling water from the hydrant is getting us looks. Stone for the wall, copper for the pump, rope for the bucket."),
     "done": P("Clear, cold and ours. Benno says he'll water the beds every evening now. Take a drink, you've earned it.",
               "Clean water, no meter. Benno waters every evening now. Drink up, it's on the house."),
     "crystals": 300, "give": {}, "friend": {"benno": 20, "gideon": 10, "hazel": 10}},
    {"id": "orchard", "name": P("Plant the orchard"), "need": {"#fruit": 8, "fertilizer": 6, "sap": 10},
     "desc": P("A row of fruit trees along the south lane: cherry, plum, orange, apple. Fruit for the seed, fertilizer and sap to get them going.",
               "A row of fruit trees along the back fence. Fruit for the seed, fertilizer and sap to get them going."),
     "done": P("Eight little trees! Rook says the blossom will bring the bees. I wrote down my cobbler for you: you'll want it come fall.",
               "Eight trees on a vacant lot. Rook says the bees will find them. My cobbler recipe, for you. Don't share it with the crews."),
     "crystals": 250, "give": {"harvest_cobbler": 2}, "recipe": "cf_rec_cobbler", "friend": {"rook": 20, "tobin": 10, "hazel": 15}},
    {"id": "greenhouse", "name": P("Build the greenhouse"), "need": {"glass": 20, "iron_bar": 5, "plank": 20},
     "desc": P("Glass for the panes, iron for the frame, planks for the benches. With cold frames in front, the commons grows through winter.",
               "Glass, an iron frame, plank benches. With cold frames out front, the garden grows straight through winter."),
     "done": P("Warm as a kitchen in there. Juniper wants to grow her herbs inside, and the cold frames will keep greens coming in the snow.",
               "Warm as the laundromat in there. Juniper's moving her herbs in, and the cold frames keep greens coming all winter."),
     "crystals": 400, "give": {}, "friend": {"juniper": 15, "wren": 20, "hazel": 15}},
    {"id": "market", "name": P("Host the harvest market"), "need": {"#veg": 25, "#fruit": 10, "#flower": 5},
     "desc": P("Stalls, bunting and a table full of everything we've grown. Bring produce for the opening day and the whole town will come.",
               "Stalls, bunting, a table full of everything we grew. Bring produce for opening day and the whole block will come."),
     "done": P("The whole town came. The WHOLE town. From now on it's a market every week, the 7th, 14th, 21st and 28th. This is for you, from all of us.",
               "The whole block showed up. Even the crews kept it civil. Market every week now, 7th, 14th, 21st, 28th. This is from all of us."),
     "crystals": 500, "give": {"green_thumb_charm": 1, "harvest_basket": 3}, "friend": {"hazel": 30, "alder": 20, "maple": 15, "posy": 15, "bram": 15, "lumi": 15, "theo": 10, "finn": 15, "benno": 15, "rook": 15, "wren": 15, "juniper": 15, "gideon": 10, "sal": 15}},
]

# ---- the map's places (cells in the community farm map) ---------------------------
SPOTS = {
    "cf_lot": [16, 18, "haul"], "cf_beds_a": [8, 18, "farm"], "cf_beds_b": [17, 22, "farm"],
    "cf_shed": [26, 9, "work"], "cf_compost": [23, 9, "haul"], "cf_well": [31, 22, "haul"],
    "cf_orchard_w": [11, 32, "farm"], "cf_orchard_e": [24, 32, "farm"], "cf_greenhouse": [39, 12, "farm"],
    "cf_market": [41, 28, "market"], "cf_market_2": [46, 28, "market"], "cf_picnic": [36, 32, "picnic"],
    "cf_board": [44, 18, "talk"], "cf_bench": [34, 18, "sit"],
    "cf_market_3": [36, 28, "market"], "cf_plaza": [26, 23, "talk"],
}
# A spot opens once this many stages are done (before that, its volunteer helps clear the lot).
SPOT_STAGE = {"cf_beds_a": 3, "cf_beds_b": 3, "cf_shed": 2, "cf_compost": 2, "cf_well": 5, "cf_orchard_w": 6, "cf_orchard_e": 6,
              "cf_greenhouse": 7, "cf_market": 3, "cf_market_2": 8, "cf_picnic": 1, "cf_bench": 1,
              "cf_market_3": 8, "cf_plaza": 1}
# Raised beds (4) and the cold frames by the greenhouse (2): [x, y, w, h].
BEDS = [[5, 14, 7, 3], [14, 14, 7, 3], [5, 23, 7, 3], [14, 23, 7, 3]]
FRAMES = [[34, 13, 4, 2], [41, 13, 4, 2]]
ORCHARD = [[6, 35, "cherry"], [10, 35, "plum"], [14, 35, "orange"], [18, 35, "apple"], [22, 35, "cherry"], [26, 35, "plum"], [30, 35, "orange"], [34, 36, "apple"]]
# What the volunteers plant, by season (cold frames grow the winter list).
PLANT = {"spring": ["turnip", "carrot", "potato", "cabbage", "lettuce", "radish", "pea", "onion", "kale"],
         "summer": ["tomato", "corn", "pepper", "sunflower", "eggplant", "blueberry", "melon"],
         "fall": ["pumpkin", "beet", "garlic", "cauliflower", "cranberry"],
         "winter": ["lettuce", "kale", "radish", "cabbage"]}

# ---- volunteers: [npc, from hour, to hour, spot, stages done needed] --------------
SCHEDULE = [
    ["hazel", 6, 10, "cf_beds_a", 0], ["hazel", 15, 17, "cf_orchard_w", 1],
    ["sal", 9, 11, "cf_shed", 0], ["gideon", 12, 13, "cf_shed", 1], ["alder", 15, 17, "cf_board", 1],
    ["lumi", 7, 9, "cf_bench", 1], ["finn", 13, 15, "cf_beds_b", 2], ["mabel", 15, 17, "cf_compost", 2],
    ["wren", 6, 8, "cf_beds_b", 3], ["wren_jr", 16, 18, "cf_beds_a", 3], ["pip", 15, 17, "cf_picnic", 3], ["theo", 16, 17, "cf_bench", 3],
    ["benno", 18, 20, "cf_well", 4], ["rook", 5, 8, "cf_orchard_e", 5], ["tobin", 16, 18, "cf_orchard_e", 5],
    ["juniper", 17, 19, "cf_greenhouse", 6], ["posy", 13, 14, "cf_market", 7], ["bram", 11, 13, "cf_market_2", 7], ["maple", 12, 13, "cf_market", 7],
]
# Market day (every 7th day once the market is open): who comes, when. The market beats
# the 7th-day chapel morning (Npc.place_now asks Commons first on market days).
MARKET_DAY = [
    ["hazel", 9, 15, "cf_market"], ["rook", 9, 11, "cf_market_2"], ["lumi", 9, 12, "cf_picnic"], ["mabel", 9, 11, "cf_plaza"],
    ["alder", 11, 13, "cf_board"], ["finn", 11, 13, "cf_market_2"],
    ["theo", 12, 13, "cf_picnic"], ["ivy", 12, 13, "cf_market_3"], ["juniper", 12, 13, "cf_picnic"], ["sal", 13, 15, "cf_plaza"],
    ["pip", 14, 16, "cf_picnic"], ["mabel", 14, 16, "cf_market"], ["tobin", 14, 16, "cf_orchard_e"], ["wren_jr", 14, 16, "cf_bench"],
    ["benno", 15, 17, "cf_plaza"],
]
# Spots that keep working in winter (once the greenhouse stands) and in the rain.
WINTER_SPOTS = ["cf_greenhouse", "cf_shed", "cf_compost", "cf_board", "cf_market", "cf_market_2"]
RAIN_SPOTS = ["cf_greenhouse", "cf_shed"]
# In the wet, grown-up volunteers shelter at an open rain spot (the shed's eaves, the greenhouse)
# instead of going home; the kids stay in. Npc.rain_walker villagers keep working out in it.
KIDS = ["pip", "wren_jr", "tobin", "mabel"]

# ---- chatter --------------------------------------------------------------------
# Lines anyone may say, by stages done (index = stages done, 0..8).
TALK_ANY = [
    P(["Hazel's out at the old commons west of town every morning, pulling brambles on her own. Somebody ought to help her.",
       "The old commons used to feed half the valley. Now it feeds the rabbits."],
      ["Hazel's out at the vacant lot on the west road every morning, hauling junk on her own. Somebody should help.",
       "That lot west of town was a garden once. Then the crews started dumping there."]),
    P(["You can see the old commons from the road again. Hazel says next is the shed.",
       "I walked past the commons. Clean as a dinner plate. Was that you?"],
      ["The lot's clear! First time in years you can see the ground.", "You cleared the lot? Huh. The crews won't like losing their dump."]),
    P(["The commons shed has a roof again. Hazel's talking about raised beds now.", "Gideon lent his good hammer to the commons. He never lends anything."],
      ["The garden shed's got a lock now. Gideon's lock. Nobody's breaking that.", "Hazel says the lot needs raised beds. Ground's too rough to plant straight in."]),
    P(["Four raised beds at the commons! Now all it needs is seeds.", "Finn says he's claimed the sunny bed at the commons. Hazel says nobody claims anything."],
      ["Raised beds at the lot. Seeds next, Hazel says.", "Finn calls the raised beds 'the score'. Hazel's given up correcting him."]),
    P(["There are sprouts at the commons! Real ones!", "The commons beds are planted. Hazel's walking around like a proud aunt."],
      ["Stuff's actually growing at the lot. In this town!", "The kids water the lot beds after school. Nobody told them to."]),
    P(["The commons well works again. Best water in the valley, Benno says.", "Benno waters the commons every evening now. He hums."],
      ["The lot's got its own well. No meter, no bill.", "Benno waters the garden every evening. Says it's the quietest hour of his day."]),
    P(["Fruit trees at the commons. In a few seasons there'll be pies for everybody.", "Rook planted a beehive by the commons orchard. The bees found it in a day."],
      ["They planted trees on the lot. Trees! On a lot!", "Rook says the bees found the lot orchard in a day. Bees know a good thing."]),
    P(["A greenhouse at the commons. Greens in winter, imagine that.", "Juniper grows her herbs in the commons greenhouse now."],
      ["A greenhouse on the lot. Winter greens, no imports.", "Juniper's herbs live in the lot greenhouse now. Warmer than her clinic."]),
    P(["Market day at the commons is the best day of the week.", "Posy sells her bread at the commons market now. Sells out by noon.", "Did you see the commons on market day? The whole town was there."],
      ["Market day at the lot garden. Best day of the week.", "Posy sells out at the lot market by noon.", "The whole block turns out for the lot market. Even the crews behave."]),
]
# A villager's own lines, from a stage on: [npc, stages done needed, lines]
TALK_OWN = [
    ["hazel", 0, P(["My back's not what it was. The commons won't clear itself, but it won't mind a second pair of hands.", "Every town needs a place where anyone can grow something. Ours got lost under the brambles."],
                   ["I'm not waiting for the city to fix that lot. Nobody's waiting for the city anymore.", "A garden's the one thing the crews can't shake down. You can't fence a tomato."])],
    ["hazel", 4, P(["Come by the commons and check the beds. If something's ripe, pick it: it all goes in the stand.", "The share crate's for you. Don't be shy about it."],
                   ["Something's always ripe at the lot. Pick it, it all goes in the stand.", "Your share's in the crate by the shed. Take it."])],
    ["sal", 0, P(["I help Hazel at the commons in the mornings. Hauling things is the one thing I'm good at.", "Nobody asks questions at a garden. I like that."],
                 ["I haul for Hazel at the lot mornings. Honest work. Weird feeling.", "The lot's the only place in town nobody asks who I used to be."])],
    ["gideon", 1, P(["I fixed the shed hinges at the commons. They'll outlast all of us.", "If a commons tool breaks, bring it to me. No charge. Don't tell anyone."],
                    ["I put a lock on that garden shed. My lock. Let them try.", "Garden tools, I fix free. Don't spread it around."])],
    ["finn", 2, P(["Beans and fish: the only two things worth growing. The commons only has room for one.", "I tend the second bed at the commons after lunch. Fish don't bite at one o'clock anyway."],
                  ["I work the second bed at the lot after lunch. Fish don't bite at one anyway.", "Planting's like fishing. You wait, then everything happens at once."])],
    ["wren", 3, P(["The commons soil is good. Old. It remembers being a garden.", "I grow feverfew in the corner of the commons beds. Don't pick it, it's not a salad."],
                  ["The lot soil came back faster than I thought. Dirt's forgiving.", "There's feverfew in the corner bed at the lot. It's medicine, not lunch."])],
    ["benno", 4, P(["I water the commons every evening. The horses can spare me an hour.", "That well's deeper than it looks. Cold all summer."],
                   ["I water the lot every evening. Best hour of my day.", "That well's cold even in August. Don't tell the President."])],
    ["rook", 5, P(["The commons orchard needs a few years. Trees don't hurry for anyone.", "I watch the commons trees mornings. Deer love a young plum."],
                  ["I keep an eye on the lot trees mornings. Rats love a young plum.", "Trees on a vacant lot. Funny old world."])],
    ["juniper", 6, P(["I moved my herbs into the commons greenhouse. They've never looked better.", "Fresh greens in winter keep me less busy. That's the whole point."],
                     ["My herbs live in the lot greenhouse now. Better than my windowsill.", "Winter greens keep people out of my clinic. Best medicine there is."])],
    ["posy", 7, P(["I bake with commons flour and commons berries now. It tastes like home.", "Market day, I sell out by noon. Come early!"],
                  ["Everything I bake for market day is from the lot. People can taste it.", "Market day, I sell out by noon. Come early, boss."])],
    ["alder", 1, P(["The commons is the best thing to happen to this town's budget in years. It costs nothing.", "I've put the commons in the town records. Officially, it's a park now."],
                   ["The lot garden is officially a park now. I filed it myself. Let the developers argue with a park.", "Civic pride, at last. And at no cost to the treasury."])],
]
# What a volunteer says when you talk to them at the farm, by activity (plus "rain", "winter", "market_day").
AT_WORK = {
    "farm": P(["Weeds don't take days off, so neither do I.", "Look at these roots! Healthy as anything.", "Mind the edges, the seedlings are shy."],
              ["Weeds don't take days off. Neither do I.", "Look at those roots. Healthiest thing on the block.", "Watch your feet, the seedlings bruise easy."]),
    "haul": P(["One more load and I'll sit down. Probably.", "Heavy, but good heavy.", "Everything here gets carried twice. Once in, once out as dinner."],
              ["One more load, then a break. Probably.", "Heavy, but honest heavy.", "Everything on this lot gets carried twice: junk out, dinner in."]),
    "work": P(["Hinges, handles, the odd broken rake. Somebody has to.", "Tools last forever if you clean them. Nobody cleans them."],
              ["Hinges, handles, the odd bent rake. Somebody's got to.", "Clean your tools and they never let you down. Same as people."]),
    "market": P(["Fresh today! Well, fresh-ish.", "Prices are low because the soil works for free.", "Take a look, everything's from the beds behind me."],
                ["Fresh today. Mostly.", "Prices are low: the dirt works for free.", "Everything here grew twenty steps away."]),
    "picnic": P(["Lunch tastes better outside. That's science.", "Sit down a minute. The beds will still be there."],
                ["Lunch tastes better outside. Fact.", "Sit a minute. The beds aren't going anywhere."]),
    "talk": P(["The board says what's next. Read it, then help me make it happen.", "I like to see the plan with my own eyes."],
              ["The board's got the plan. Read it, then let's make it happen.", "I like to see the plan for myself."]),
    "sit": P(["I come here to think. And to watch the bees.", "Best bench in the valley. Don't tell the park."],
             ["I come here to think. Quietest bench in town.", "Best seat on the block. Don't tell anyone."]),
    "rain": P(["Rain's doing the watering for us. I'm just keeping the tools dry.", "Nothing grows faster than a garden in the rain. Except mud.", "We'll wait it out under here. The beds don't mind a bit."],
              ["Rain does the watering. I'm keeping the tools dry.", "Wet day. The beds love it, my boots don't.", "We wait it out under here. Dirt doesn't care."]),
    "winter": P(["Winter's for mending and planning. And the greenhouse, thank goodness.", "Cold hands, warm compost."],
                ["Winter's for fixing things and planning. And the greenhouse.", "Cold hands, warm compost. That's the trade."]),
    "market_day": P(["Market day! Have you tried Posy's bread yet?", "Half the valley's here. Isn't it wonderful?", "Sell at the stand today, folks pay well."],
                    ["Market day. Whole block's out.", "Try the bread before it's gone.", "Sell at the stand today. People pay good."]),
}
# A volunteer's own at-work lines (mixed in with the activity's).
AT_WORK_OWN = {
    "hazel": P(["You can tell a lot about a person by how they hold a hoe. You hold it like you mean it."], ["You hold a hoe like you mean it. Good."]),
    "sal": P(["Strong back, quiet mouth. That's what Hazel wanted, that's what she got."], ["Strong back, quiet mouth. That's the job."]),
    "gideon": P(["This rake's older than you. Still pulls true."], ["Rake's older than you. Still pulls true."]),
    "finn": P(["Worms are worms. Garden worms, fishing worms. I don't judge."], ["Worms are worms. I don't judge where they came from."]),
    "wren": P(["The feverfew's coming up nicely. Don't eat it."], ["Feverfew's coming up. Still not lunch."]),
    "wren_jr": P(["Mum says I've got green fingers. They're just muddy."], ["Mum says I've got green fingers. They're just dirty."]),
    "pip": P(["I found a worm this long! Then it left."], ["I found a worm this long! Then it left."]),
    "tobin": P(["I'm guarding the trees. From what? Everything."], ["I'm guarding the trees. From who? Everybody."]),
    "benno": P(["Two buckets a bed. The horses could do it faster, but they won't."], ["Two buckets a bed. Quietest hour in town."]),
    "rook": P(["Bees found the blossom before I did."], ["Bees found the blossom before I did. Good scouts."]),
    "juniper": P(["Mint wants the whole greenhouse. Mint can't have it."], ["Mint wants the whole greenhouse. Mint doesn't get it."]),
    "mabel": P(["Compost is just old dinner having a nap."], ["Compost is old dinner taking a nap."]),
    "lumi": P(["I'm sketching the beds. The light's perfect on the kale."], ["Sketching the beds. The kale's got good bones."]),
    "theo": P(["Did you know the old commons had forty-one kinds of apple? I'm writing it down."], ["This lot was an orchard in 1903. I checked the records."]),
    "alder": P(["Officially a park. Unofficially the best thing I've signed."], ["Officially a park now. Best thing I ever signed."]),
}
# Short lines volunteers call out when you pass close (floating text, by activity; "rain", "greet").
BARKS = {
    "greet": P(["Morning!", "Hello there!", "Nice day for it!", "Oh, hi!"], ["Hey.", "'Sup.", "Look who it is.", "Hey, you."]),
    "farm": P(["Pull, don't snap...", "These are coming on!", "Ooh, a big one."], ["Pull, don't snap...", "These are coming on.", "Ooh, a fat one."]),
    "haul": P(["Heave!", "Mind your toes!", "Last load. Ish."], ["Heave!", "Watch your toes!", "Last load. Maybe."]),
    "work": P(["Tap, tap...", "There we go.", "Who bent this?"], ["Tap, tap...", "There we go.", "Who bent this?"]),
    "market": P(["Fresh greens!", "Two for one!", "Try a slice!"], ["Fresh greens!", "Two for one!", "Get it while it's hot!"]),
    "picnic": P(["Mmm!", "Pass the bread?", "Lovely."], ["Mmm.", "Pass the bread?", "Not bad."]),
    "sit": P(["Ahh.", "Listen to the bees."], ["Ahh.", "Quiet, huh?"]),
    "talk": P(["Next on the list...", "Hmm, hmm."], ["Next on the list...", "Hmm."]),
    "rain": P(["What a downpour!", "Free water!", "Brr!"], ["What a downpour!", "Free water.", "Brr."]),
}
# Lend a hand: what a volunteer asks you to do, by kind (CfVolunteers runs them; once per volunteer a day).
HELP = {
    "weed": {"n": 4, "ask": P("Weeds keep coming up round the bed frames faster than I can pull them. Grab a few for me?",
                              "Weeds keep coming up round the bed frames. Pull a few for me?"),
             "go": P("Pull the weeds round the beds (marked with leaves).", "Pull the weeds round the beds."),
             "done": P("Lovely and tidy. Here, take some of what we grew.", "Clean as a whistle. Here, take a cut of the harvest.")},
    "haul": {"n": 3, "ask": P("There's a stack of crates that needs carrying to the %s. Give me a hand?",
                              "Stack of crates needs hauling to the %s. Got a minute?"),
             "go": P("Carry the crates to the %s, one at a time.", "Haul the crates to the %s, one at a time."),
             "done": P("That's the lot. Strong arms! Here, for your trouble.", "That's the lot. Here, for your trouble.")},
    "water": {"n": 0, "ask": P("The beds are thirsty and the river's a long walk. Water a few for me? Grab your can.",
                               "Beds are dry and the hydrant's a hike. Water a few? Bring your can."),
              "go": P("Water the dry beds near %s with your can.", "Water the dry beds near %s."),
              "done": P("Listen to them drink! Thank you. Here, take some of this.", "They'll be fat by Friday. Here, take some of this.")},
}
# What each activity asks help with ("" = they're happy chatting).
HELP_KIND = {"farm": "weed", "haul": "haul", "work": "haul", "market": "haul"}

# ---- items and recipes -------------------------------------------------------------
ITEMS = {
    "commons_stew": {"name": "Commons Stew", "type": "food", "value": 120, "rarity": "uncommon", "tier": 2, "heal": 4, "energy": 70, "icon": "soup_vegetable",
                     "desc": "Whatever came up first in the community beds, simmered all afternoon."},
    "harvest_cobbler": {"name": "Harvest Cobbler", "type": "food", "value": 150, "rarity": "uncommon", "tier": 2, "heal": 3, "energy": 60, "icon": "fruit_tart",
                        "buff": {"kind": "luck", "minutes": 180, "amount": 1}, "desc": "Hazel's cobbler: orchard fruit under a golden crust. Feels lucky."},
    "harvest_basket": {"name": "Harvest Basket", "type": "gift", "value": 90, "rarity": "uncommon", "tier": 2, "friend": 30, "icon": "fruit_basket",
                       "desc": "A basket of the community farm's best. Everybody loves one."},
    "green_thumb_charm": {"name": "Green Thumb Charm", "type": "equip", "slot": "charm", "value": 600, "rarity": "rare", "tier": 3, "stats": {"luck": 1, "energy": 20},
                          "icon": "charm_root", "desc": "Carved from the commons' first orchard prune, from everyone who helped."},
}
RECIPES = [
    {"id": "commons_stew", "name": "Commons Stew", "need": {"#veg": 3, "#herb": 1}, "give": "commons_stew", "tier": 1, "flag": "cf_rec_stew", "flag_hint": "learn it at the community farm"},
    {"id": "harvest_cobbler", "name": "Harvest Cobbler", "need": {"#fruit": 2, "flour": 1, "egg": 1}, "give": "harvest_cobbler", "tier": 1, "flag": "cf_rec_cobbler", "flag_hint": "learn it at the community farm"},
]

out = {
    "_": "Generated by tools/gen_community_farm.py: edit that, not this file.",
    "names": P("Dreamhollow Commons", "Westside Lot Garden"),
    "short": P("the commons", "the lot garden"),
    "keeper": "hazel",
    "intro": P("This was the town commons, when I was small. Everybody grew a little and shared the rest. Then folks got busy, and the brambles didn't. Help me bring it back? The board by the gate says what we need, one step at a time.",
               "This lot was a garden when I was a kid. Then the crews used it as a dump, and the city looked the other way. I want it back. Help me? The board by the gate has the plan, one step at a time."),
    "letter": P("Dear neighbour, the old commons west of town has gone to brambles. I mean to bring it back, and I could use a strong pair of hands. Take the west road out of the plaza. Mornings, I'm there. - Hazel",
                "Hey. There's a vacant lot on the west road out of town, full of junk the crews dumped. I'm turning it back into a garden. I could use help. Mornings, I'm there. - Hazel"),
    "stages": STAGES, "spots": SPOTS, "spot_stage": SPOT_STAGE, "beds": BEDS, "frames": FRAMES, "orchard": ORCHARD, "plant": PLANT,
    "schedule": SCHEDULE, "market_day": MARKET_DAY, "winter_spots": WINTER_SPOTS, "rain_spots": RAIN_SPOTS,
    "talk_any": TALK_ANY, "talk_own": TALK_OWN, "at_work": AT_WORK, "at_work_own": AT_WORK_OWN, "barks": BARKS,
    "help": HELP, "help_kind": HELP_KIND, "kids": KIDS,
}
for s in STAGES:
    for k in s.get("give", {}):
        assert k in ITEMS or k in json.load(open(os.path.join(D, "items.json"))), k
json.dump(out, open(os.path.join(D, "community_farm.json"), "w"), indent=1, ensure_ascii=False)

I = json.load(open(os.path.join(D, "items.json")))
for k, v in ITEMS.items():
    I[k] = v
json.dump(I, open(os.path.join(D, "items.json"), "w"), indent=1, ensure_ascii=False)

R = json.load(open(os.path.join(D, "recipes.json")))
ids = {r["id"] for r in RECIPES}
R["kitchen"] = [r for r in R.get("kitchen", []) if r["id"] not in ids] + RECIPES
json.dump(R, open(os.path.join(D, "recipes.json"), "w"), indent=1, ensure_ascii=False)
print("community_farm.json: %d stages, %d volunteers; %d items, %d recipes" % (len(STAGES), len(SCHEDULE), len(ITEMS), len(RECIPES)))
