#!/usr/bin/env python3
"""The merkitty colonies (penguin arc side arc): four big island regions in the
sea beyond the beach, each with a fading star crystal. Writes the colony_*
entries in data/regions.json, data/colonies.json, scenes/colony_*.tscn, the
colony bosses in data/enemies.json and the colony items in data/items.json.
Re-runnable.   python3 tools/gen_colonies.py
"""
import json, os, math
D = os.path.join(os.path.dirname(__file__), "..")
R = json.load(open(D + "/data/regions.json"))
E = json.load(open(D + "/data/enemies.json"))
I = json.load(open(D + "/data/items.json"))
G = json.load(open(D + "/data/gifts.json"))

def scene(rid):
    open(D + "/scenes/%s.tscn" % rid, "w").write('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/region.gd" id="1"]\n\n[node name="%s" type="Node2D"]\nscript = ExtResource("1")\nregion_id = "%s"\n' % (rid, rid))

def item(id, name, typ, val, tier, **kw):
    d = {"name": name, "type": typ, "value": val, "rarity": "rare" if tier >= 3 else "uncommon", "tier": tier, "arc": "penguins"}
    d.update(kw); I[id] = d

item("colony_light", "Colony Light", "key", 0, 4, desc="The steady glow of a saved colony's star crystal. The Aurora Dome of the Crystal Ward wants four.")
item("coral_charm", "Coral Charm", "equip", 900, 3, slot="charm", stats={"defense": 2, "luck": 1}, desc="Grown, not carved. Warm in your hand.")
item("tide_pearl", "Tide Pearl", "equip", 1400, 3, slot="ring", stats={"mana": 15, "speed": 1}, desc="You can hear the sea in it.")
item("kelp_wrap", "Kelp Wrap", "food", 120, 2, energy=40, heal=2)
item("frost_lily", "Frost Lily", "material", 160, 3, desc="Never melts.")
item("ember_glass", "Ember Glass", "material", 220, 3, desc="Glass made in a volcano by a very patient cat.")
item("starfish_snack", "Starfish Snack (biscuit)", "food", 90, 2, energy=30, friend=2)

GIFTS_NEW = {
 "c_coral": {"name": "Choking Reef", "colour": "ff7aa0", "gap": 2.8, "moves": [{"type": "zones", "n": 5, "fx": "slow", "linger": 3.0}, {"type": "ring", "n": 14, "gap_n": 3}, {"type": "pull", "secs": 1.2}],
   "rule": {"type": "back", "closed": 0.3, "open": 1.8, "turn": 1.4}, "tip": "Its front is armoured reef. Bait the circles, step round, and hit it from behind."},
 "c_kelp": {"name": "Black Tide", "colour": "4ad0a0", "gap": 2.6, "pull_force": 44.0, "moves": [{"type": "pull", "secs": 1.5}, {"type": "lines", "n": 3}, {"type": "spiral", "secs": 1.4}],
   "rule": {"type": "window", "after": "spiral", "secs": 2.2, "stagger": 1.0, "closed": 0.3, "open": 2.2}, "tip": "Get out of the tide's pull, wait out the spiral, then hit it while it's spent."},
 "c_ice": {"name": "Hollow Winter", "colour": "bfe9ff", "gap": 2.8, "clones": {"n": 2, "at": [0.6, 0.3]}, "moves": [{"type": "ring", "n": 12, "gap_n": 2}, {"type": "zones", "n": 4, "fx": "slow"}],
   "rule": {"type": "real", "open": 1.0}, "tip": "Its reflections cast no shadow. Hit the one with a shadow."},
 "c_ember": {"name": "Smother", "colour": "ff7a3a", "gap": 2.6, "trail": True, "moves": [{"type": "dash"}, {"type": "zones", "n": 5, "fx": "burn", "linger": 2.4}, {"type": "dash"}],
   "rule": {"type": "cycle", "on": 5.0, "off": 3.0, "closed": 0.25, "open": 2.0}, "tip": "It burns too hot to touch, then has to cool. Dodge the trails; strike when the ring goes white."},
}
G["gifts"].update(GIFTS_NEW)

COL = {
 "colony_coral": {"name": "Coral Reach", "tier": 1, "elder": "Grandmother Brine",
   "intro": ["You came by the ferry? Then the sea still lets some through. Good.", "Our star crystal sits in the reef shrine. It's fading, and the reef is turning grey and grabbing at us.",
             "We need food for the little ones, the grey crabs chased off, and the three tide beacons lit so the shoals come home. Then wake the crystal."],
   "need": {"#fish": 6, "kelp_wrap": 0}, "need_text": "The little ones haven't eaten properly in days.", "need_thanks": "Oh, the kits will eat tonight. Bless you.",
   "foe_word": "Grey crabs", "kills": 8, "beacons": 3, "enemies": ["rock_crab", "mud_slime", "river_serpent"],
   "boss": "cboss_coral", "boss_name": "The Grey Reef", "boss_art": "cboss_coral", "gift": "c_coral",
   "crystal_dim": "A star crystal, pink as a shell, barely glowing. Something grey has grown over half of it.",
   "crystal_wake": "You lay your hands on the crystal. The grey reef around it shudders, peels away from the stone, and stands up.",
   "crystal_restored": "The crystal flares rose-gold. All across the reef, grey coral flushes back to colour, and the water fills with fish.",
   "crystal_after": "The crystal hums with the sound of the tide.", "thanks": "You gave us back the sea. Come and go as you please, friend of the reef.",
   "ability": "coral_ward", "ability_name": "Coral Ward", "ability_desc": "Hits land softer (+2 defence, always).", "spells": [], "mana": 0,
   "shop_who": "Reef trader", "shop": [["coral_charm", 900], ["kelp_wrap", 120], ["pearl", 300], ["starfish_snack", 90]]},
 "colony_kelp": {"name": "Kelp Hollow", "tier": 2, "elder": "Old Tidewhisker",
   "intro": ["The forest under the water is dying, and it was the only home we had.", "The crystal in the kelp temple feeds the kelp. The dark is feeding on the crystal.",
             "Bring us plank and rope to shore up the stilt-houses, chase the shadow serpents out, light the beacons, and wake the crystal."],
   "need": {"plank": 30, "rope": 6}, "need_text": "The stilt-houses lean further every tide.", "need_thanks": "That'll hold. That'll hold for years.",
   "foe_word": "Shadow serpents", "kills": 10, "beacons": 3, "enemies": ["river_serpent", "wisp", "slime"],
   "boss": "cboss_kelp", "boss_name": "The Black Tide", "boss_art": "cboss_kelp", "gift": "c_kelp",
   "crystal_dim": "A green star crystal wrapped in black kelp. Its light pulses slower each time.",
   "crystal_wake": "The black kelp unwinds from the crystal and gathers itself into a long, cold shape.",
   "crystal_restored": "Green light floods the hollow. The kelp lifts toward it like it's breathing again.",
   "crystal_after": "The crystal glows green and slow, like a heartbeat.", "thanks": "Swim with us any time. The sea knows you now.",
   "ability": "tideswim", "ability_name": "Tideswim", "ability_desc": "You can swim in any deep water, no partner needed.", "spells": [], "mana": 10,
   "shop_who": "Kelp weaver", "shop": [["tide_pearl", 1400], ["kelp_wrap", 120], ["rope", 30]]},
 "colony_ice": {"name": "Frostfin Isle", "tier": 3, "elder": "Captain Icewhisker",
   "intro": ["You picked a cold day to visit. Every day is a cold day now.", "Our crystal used to keep the isle just warm enough. Now the winter has a mind of its own, and it copies us.",
             "Firewood for the hearths, the wisps chased off, the beacons lit, and then we wake the crystal together."],
   "need": {"wood": 40, "coal": 10}, "need_text": "The hearths are down to embers.", "need_thanks": "Warm hands. You don't know what that means up here.",
   "foe_word": "Ice wisps", "kills": 10, "beacons": 4, "enemies": ["ice_wisp", "hill_wolf", "crystal_baby"],
   "boss": "cboss_ice", "boss_name": "Hollow Winter", "boss_art": "cboss_ice", "gift": "c_ice",
   "crystal_dim": "A pale blue crystal inside a block of ice that wasn't there last year.",
   "crystal_wake": "The ice cracks. Something steps out of it wearing your shape, then two more.",
   "crystal_restored": "The ice melts off the crystal in one long sigh. Snow keeps falling, but it's the gentle kind again.",
   "crystal_after": "The crystal glitters like frost on a window.", "thanks": "The isle is yours whenever you need a cold drink and a warm hearth.",
   "ability": "frost_step", "ability_name": "Frost Step", "ability_desc": "Chill, freeze and slow can't touch you. You also learn the Lull spell.", "spells": ["lull"], "mana": 10,
   "shop_who": "Ice fisher", "shop": [["frost_lily", 160], ["hot_cocoa", 160], ["starfish_snack", 90]]},
 "colony_ember": {"name": "Emberclaw Atoll", "tier": 4, "elder": "Lady Cinderpaw",
   "intro": ["Careful, the sand is hot. It's always been hot. Now it's angry.", "Our crystal tamed the mountain. The dark has woken it.",
             "Bring us glass and silver to rebuild the vents, put out the moths, light the beacons, and wake the crystal before the mountain wakes properly."],
   "need": {"glass": 10, "silver_bar": 3}, "need_text": "The vents are cracked. Glass and silver to patch them.", "need_thanks": "There. Now the mountain breathes where we tell it.",
   "foe_word": "Lantern moths", "kills": 12, "beacons": 4, "enemies": ["lantern_moth", "geode_golem", "shard"],
   "boss": "cboss_ember", "boss_name": "The Smother", "boss_art": "cboss_ember", "gift": "c_ember",
   "crystal_dim": "A crystal like a coal, red at the centre, black at the edges. The black is spreading.",
   "crystal_wake": "The black crust splits. What comes out is all heat and no light.",
   "crystal_restored": "The crystal blazes gold, and the mountain settles down like a cat by a fire.",
   "crystal_after": "The crystal glows like the last coal in a good fire.", "thanks": "Our fires are yours. Take some of the light with you.",
   "ability": "starfire", "ability_name": "Starfire", "ability_desc": "+20 max mana and the Radiance spell: a ring of starlight.", "spells": ["radiance"], "mana": 20,
   "shop_who": "Glassblower", "shop": [["ember_glass", 220], ["crystal_glass", 260], ["tide_pearl", 1400]]},
}
COL["colony_coral"]["need"] = {"#fish": 6}
# ---- C7 (c7_10 / c7_11): one story per colony ---------------------------------
# Every colony keeps the same five steps (elder, supplies, foes, beacons, crystal)
# but now with its own words at each step: an arrival narration, an elder with an
# ancient, sprightly voice, a local problem told after the supplies, one verse of
# the old song per beacon, a reveal after the boss tying it to the Dark Crystal,
# a lore talk after the save, rotating "after" lines, talkable kits with side
# quests, foes that match what the elder names, and island-own secrets.
STORY = {
 "colony_coral": {
   "arrive": "Pink stilt-huts, grey coral creeping up the beach, and somewhere a merkitty singing, badly out of tune.",
   "intro": [{"text": "A merkitty with a white muzzle and a coral comb in her fur flips backwards off the jetty, comes up laughing, and hauls herself out beside you."},
             "Eight hundred and twelve, and I still beat my grandkits to the buoy. You're the one who broke the crabs' line at the Reef Gate! The kits haven't stopped talking about it.",
             "Our star crystal sits in the reef shrine. It's fading, and the reef is turning grey and grabbing at us.",
             "Food for the little ones, the grey crabs and Grumps chased off, and the three tide beacons lit so the shoals come home. Then we wake the crystal together."],
   "intro_mer": "And you carry Mer's song on you. That girl always did wander. Good. She chose well.",
   "intro_nomer": "No tail on you yet? Never mind. The ferry brought you, and the sea doesn't do that for just anyone.",
   "after_gave": ["The kits ate, and then they sang. Badly. Wonderfully.",
                  "Shelly says the reef started whispering after a black pearl washed up on the shrine steps. Whispering! Reefs hum, dear. They don't whisper. Keep your ears open."],
   "beacon_lines": ["The beacon catches. From the shrine, faintly, Brine sings: 'Pink for the morning, the tide coming in...'",
                    "'...gold for the noon, when the shoals turn and spin...'",
                    "'...blue for the night, and the star we hold in.' Out on the reef, something grey shudders."],
   "kills_line": "The grey crabs scuttle off sideways and don't come back. One of them, you'd swear, looked relieved.",
   "reveal": [{"text": "Where the Grey Reef stood, a black pearl lies cracked in two. Inside it, a splinter of dark crystal goes dull and crumbles to sand."},
              "So that's what was whispering. His seed, dropped in our shrine like a stone down a well. Clever. Rude, but clever.",
              "The grey coral wasn't wicked, you know. It was our crystal's little ones, listening to the wrong voice. Look at them now. Pink as sunrise."],
   "lore": ["When the star broke, four pieces fell into the sea. We were the cats who caught them. We've been young ever since. That's what holding a star does.",
            "Catkins of the meadow keeps the old ways on land; we keep them in the water. She sends her regards by gull, about twice a century.",
            "Every colony keeps one verse of the old song. You've heard ours. Hear the other three and the sea will remember you."],
   "after": ["The shoals came home. I've eaten so much fish I may never swim again. I'll swim this afternoon.",
             "Shelly wants to be a shrine-keeper now. She keeps polishing the crystal with her tail.",
             "If you find a bottle on the islet, read it. The sea writes to us sometimes.",
             "Grey coral is coming back pink right up to the ferry posts. Mind your step; it's ticklish."],
   "enemies": ["grump_coral", "rock_crab", "grump_wisp"], "foe_word": "Grey Grumps and crabs",
   "kits": [
     {"name": "Shelly", "wait": "Talk to Grandmother Brine first! She's the one in the coral comb, doing backflips.",
      "quest": {"id": "shells", "title": "Shell Collector", "ask": "I'm making Grandmother a shell necklace for her eight-hundred-and-thirteenth birthday. I need five seashells. The mainland beach has loads!",
                "need": {"seashell": 5}, "thanks": "Perfect! Don't tell her. She'll know anyway. She always knows.", "reward": {"pearl": 1, "crystals": 200}},
      "after": ["Grandmother wore the necklace to bed. And to breakfast. And swimming.", "I'm going to be a shrine-keeper. I've already polished the crystal four times today."]},
     {"name": "Barnaby", "wait": "Grandmother Brine's the one to see. I'm busy being sad about my raft.",
      "quest": {"id": "raft", "title": "Barnaby's Raft", "ask": "My raft fell apart. Again. If you bring me six driftwood and two rope, I'll name the next one after you.",
                "need": {"driftwood": 6, "rope": 2}, "thanks": "She floats! I've called her the Land-Walker. She's very brave and only a bit wonky.", "reward": {"starfish_snack": 3, "crystals": 250}},
      "after": ["The Land-Walker hasn't sunk once. Well. Once.", "I rowed all the way round the islet. Twice. My arms are noodles."]},
     {"name": "Pebble", "lines": ["Grandmother says I can swim to the buoy when I'm a hundred.", "Did you know crabs walk sideways because forwards is boring?", "I'm guarding the jetty. From what? From everything."]}],
   "secrets": [{"type": "loot", "cell": [20, 18], "item": "pearl", "n": 1, "every": 7, "empty": "Just sand and a crab, now.", "hint": "A: dig", "solid": False},
               {"type": "note", "cell": [30, 40], "who": "", "text": "A carving on a flat stone: four crystals in a ring around a fifth. Under it, in merkitty scratch-script: 'Pink for the morning. Ask the others for the rest.'", "hint": "A: carved stone", "solid": False},
               {"type": "loot", "cell": [68, 60], "item": "seashell", "n": 2, "every": 4, "empty": "The tide will bring more.", "hint": "A: tide pool", "solid": False}]},
 "colony_kelp": {
   "arrive": "Teal moss down to the waterline, huts leaning on kelp-wrapped legs, and fog that moves like it's breathing.",
   "intro": [{"text": "An old merkitty is juggling pearls on a hut rail. He doesn't drop one when he sees you."},
             "I was old when the kelp was young, and I'll be young when it's old again. That's how it goes. You lit the path through the Sunken Bell shallows, didn't you? I heard it ring.",
             "The forest under the water is dying, and it was the only home we had. The crystal in the kelp temple feeds the kelp. The dark is feeding on the crystal.",
             "Plank and rope to shore up the stilt-houses, the shadow serpents and their Grumps chased out, the beacons lit. Then we wake the crystal."],
   "intro_mer": "Mer's song is on you. Ha! She used to steal my pearls. I let her. Don't tell her.",
   "intro_nomer": "No tail? Then mind the edges. The water here likes to keep things.",
   "after_gave": ["That'll hold. That'll hold for years. Now: the bell.",
                  "Our colony bell sank in the black tide. Its ring used to call the shoals home, like the tower bell on your mainland calls the town. Same bronze, they say. Same founder.",
                  "Without it the kelp forgets which way is up. Light the beacons; the light will guide its voice back."],
   "beacon_lines": ["The beacon catches. Somewhere under the fog, a bell answers, very faint.",
                    "Tidewhisker hums the second verse: 'Green for the forest that grows in the deep...'",
                    "'...rocked by the bell, so the little ones sleep.' The fog thins, and the kelp lifts toward the light."],
   "kills_line": "The last shadow serpent slides off into deep water, and the fog seems a little lighter for it.",
   "reveal": [{"text": "The Black Tide drains away into the sand. Left behind: a dark crystal splinter, wrapped in black kelp like a gift nobody wanted."},
              "There's his signature again. He doesn't break things. He whispers to them until they break themselves.",
              "Listen. Hear that? The bell's ringing on its own. It hasn't done that in three hundred years. Show-off."],
   "lore": ["Catkins? That old cushion-sitter. She taught me stillness and I taught her to swim. She was terrible. She'll deny it.",
            "Our kelp grows in spirals, and the spirals match the old star maps. We think the star drew them as it fell. We think it was saying goodbye.",
            "Brine has the first verse, I have the second. Icewhisker keeps the third under all that snow, and Cinderpaw the last."],
   "after": ["The bell rings at dawn now. The kits complain. I love it.",
             "Brine owes me a race. Tell her I said so. Tell her I've been practising.",
             "The kelp's growing so fast I've had to move my hammock twice.",
             "Handstand? On the stilts? At my age? Watch this."],
   "enemies": ["river_serpent", "grump_moss", "grump_coral"], "foe_word": "Shadow serpents and Moss Grumps",
   "kits": [
     {"name": "Reed", "wait": "Old Tidewhisker first. He's the one juggling. He's always juggling.",
      "quest": {"id": "net", "title": "The Lost Net", "ask": "The black tide tangled our fishing net into knots. If you bring us four rope and three fish, we can make a new one and fill it the same day.",
                "need": {"rope": 4, "#fish": 3}, "thanks": "A new net, and supper already in it! You're better than a tide.", "reward": {"kelp_wrap": 3, "crystals": 250}},
      "after": ["We caught a fish this big. Okay, this big. Okay, it was a minnow.", "The new net glows a bit in the dark. We don't know why. We like it."]},
     {"name": "Minnow", "wait": "Grown-ups are with Tidewhisker. Go on. I'll wait. I'm good at waiting.",
      "quest": {"id": "lanterns", "title": "Stilt Lantern Night", "ask": "On lantern night every hut hangs a light so the shoals know we're still here. Ours all broke. Could you bring three glass and two honey? We make the candles from honey-wax.",
                "need": {"glass": 3, "honey": 2}, "thanks": "Lanterns on every hut! The shoals will come and look. They always come and look.", "reward": {"pearl": 1, "crystals": 300}},
      "after": ["Lantern night was the best. A fish kissed my nose.", "I'm keeping one lantern lit all year. For luck."]},
     {"name": "Bubbles", "lines": ["I can hold my breath for a whole song. A short song.", "The kelp tickles if you swim through it backwards.", "Tidewhisker can do a handstand on one paw. I can do it on none."]}],
   "secrets": [{"type": "loot", "cell": [20, 18], "item": "river_pearl", "n": 1, "every": 6, "empty": "Only kelp and a cross little crab.", "hint": "A: dig", "solid": False},
               {"type": "note", "cell": [30, 40], "who": "", "text": "Kelp stems pressed into the mud in a spiral, like a star map drawn by someone falling. A shell is pinned at the centre: 'Green for the forest. Brine has the morning.'", "hint": "A: kelp spiral", "solid": False},
               {"type": "loot", "cell": [68, 60], "item": "driftwood", "n": 3, "every": 3, "empty": "The fog will wash more up.", "hint": "A: driftwood pile", "solid": False}]},
 "colony_ice": {
   "arrive": "Snow on everything, the lodge chimneys barely smoking, and a frozen shoreline creaking like an old door.",
   "intro": [{"text": "Someone skates straight down the frozen shore at you, stops in a spray of snow, and salutes. She has a captain's hat and a great deal of white whisker."},
             "Captain Icewhisker! Nine hundred winters, and I still skate the bay every morning. You broke the ice walls at the gate; I saw the steam from my mast.",
             "Our crystal used to keep the isle just warm enough. Now the winter has a mind of its own, and it copies us.",
             "Firewood and coal for the hearths, the Frost Grumps and wisps chased off, the beacons lit. Then we wake the crystal together."],
   "intro_mer": "Mer's song! Then you'll not freeze in our water, at least. Good. Our water is VERY cold.",
   "intro_nomer": "No tail. Don't fall through the ice, then. I'm not fishing you out twice.",
   "after_gave": ["Warm hands. You don't know what that means up here.",
                  "There are lights under the ice. Frostfin cats who went out on the bay when the cold came, and didn't come back. They're not gone. They're frozen, waiting.",
                  "Every beacon you light thaws a few of them. Light all four and they'll come home."],
   "beacon_lines": ["The beacon catches. Under the ice, a small light blinks back, then another.",
                    "Two frozen cats pop up through a crack in the ice, shake themselves off, and skate straight to the lodge for cocoa.",
                    "Icewhisker sings the third verse from her mast: 'White for the winter that rests on the sea...'",
                    "'...and wakes up in spring, and lets the ice free.' The last of the lost cats come home in a laughing line."],
   "kills_line": "The last Frost Grump melts into a puddle and, a moment later, the puddle looks embarrassed.",
   "reveal": [{"text": "Hollow Winter's copies crack and fall to snow. In the middle of the heap: a splinter of dark crystal, cold enough to sting."},
              "It copied us because it had nothing of its own. That's what he gives them: an empty middle, and a voice saying they'll be full if they listen.",
              "Our crystal's own snow is the gentle kind. Feel that? That's what winter is supposed to feel like."],
   "lore": ["We keep the third verse. White for the winter. I sang it to Catkins once and she cried. She'll deny that too.",
            "When the star split, our piece fell on the coldest rock in the sea. It chose us because we didn't mind the cold. We still don't.",
            "My crew used to say I'd outlive the ice. Turns out the ice and I are about the same age, and we get along."],
   "after": ["Cocoa's on in the lodge. It's always on in the lodge.",
             "The kits you thawed are skating rings round the old-timers. As it should be.",
             "Ice fishing derby at dawn. You're invited. You'll lose.",
             "The aurora's back. It came out the night you woke the crystal, and it hasn't left."],
   "enemies": ["grump_frost", "ice_wisp", "grump_crystal"], "foe_word": "Frost Grumps and ice wisps",
   "kits": [
     {"name": "Flurry", "wait": "Captain's over there. She'll skate at you. Just stand still.",
      "quest": {"id": "derby", "title": "Ice Fishing Derby", "ask": "The derby's coming and I've never caught anything. Will you help me practise? Bring me four fish and I'll study them. Very closely.",
                "need": {"#fish": 4}, "thanks": "I've studied them. I know everything about fish now. I'm going to win!", "reward": {"hot_cocoa": 2, "crystals": 250}},
      "after": ["I came second in the derby! Out of two. But still!", "Fish look up at the ice like they're waiting for someone. Maybe us."]},
     {"name": "Sleet", "wait": "Talk to the captain first. Captain likes to be first.",
      "quest": {"id": "lilies", "title": "Frost Lilies for the Lodge", "ask": "Frost lilies never melt. We put them on the lodge table when someone comes home. Lots of cats came home. Could you bring two frost lilies? The ice fisher sells them, once the crystal's awake.",
                "need": {"frost_lily": 2}, "thanks": "The table looks like home again. Thank you.", "reward": {"glass_frosted": 1, "crystals": 300}},
      "after": ["The lilies are on the table. They'll be there for a hundred years.", "Grandpa came home through a crack in the ice. He says he had a lovely nap."]},
     {"name": "Snowdrop", "lines": ["My whiskers froze into a curl. I'm keeping it.", "Captain says a real sailor never feels the cold. I feel it. I'm not a real sailor yet.", "I licked the beacon. Don't lick the beacon."]}],
   "secrets": [{"type": "loot", "cell": [20, 18], "item": "frost", "n": 1, "every": 6, "empty": "Just snow now.", "hint": "A: dig", "solid": False},
               {"type": "note", "cell": [30, 40], "who": "", "text": "Words scratched into the ice by a claw, still sharp: 'White for the winter. We were one star, once. Ask Cinderpaw how it ends.'", "hint": "A: scratched ice", "solid": False},
               {"type": "loot", "cell": [68, 60], "item": "coal", "n": 2, "every": 4, "empty": "Someone's taken the coal for the hearths. Fair.", "hint": "A: coal box", "solid": False}]},
 "colony_ember": {
   "arrive": "Black sand, warm underfoot, glassworks glowing along the shore, and over it all a mountain that won't stop grumbling.",
   "intro": [{"text": "A merkitty cartwheels across the hot sand barefoot, lands in front of you, and laughs at how you're hopping."},
             "Lady Cinderpaw. Two thousand years old and I still run the glassworks myself. You brought real stars back over our smoke at the Ember Gate. I stayed up all night looking.",
             "Careful, the sand is hot. It's always been hot. Now it's angry. Our crystal tamed the mountain, and the dark has woken it.",
             "Glass and silver to patch the vents, the Ember Grumps and moths put out, the beacons lit. Then we wake the crystal, before the mountain wakes properly."],
   "intro_mer": "Mer's song, all the way out here. Good. Then the sea will carry you home if the mountain throws you.",
   "intro_nomer": "No tail? Then don't fall in the sea, and don't fall in the mountain. Simple rules.",
   "after_gave": ["There. Now the mountain breathes where we tell it.",
                  "The Never-Out Fire in the shrine has burned since the star fell. It was lit from the star itself. It's guttering now, and the moths are drawn to it like it's dying.",
                  "Light the beacons around the cone and the fire will have friends again. Fire likes friends."],
   "beacon_lines": ["The beacon catches. In the shrine, the Never-Out Fire flickers taller.",
                    "Cinderpaw sings the last verse, very softly: 'Gold for the fire that never goes out...'",
                    "'...lit from the star, so there's never a doubt...'",
                    "'...and four become one when the song's sung about.' The mountain goes quiet, listening."],
   "kills_line": "The lantern moths drift off toward the beacons instead of the fire. Much better.",
   "reveal": [{"text": "The Smother cools to black glass and cracks. Inside, the last splinter of dark crystal hisses and goes out."},
              "Four crystals, four colonies, four verses. They were one star, once. The fifth piece fell on land and went dark.",
              "That's his Dark Crystal, dear. A piece of our own star that listened to the cold and forgot. Which means it can remember. Tell your Star Crystal. She'll know what to do with that."],
   "lore": ["The four of us were kits together when the star fell. We each grabbed a piece. Brine bit hers. Typical.",
            "Catkins came out here once, a thousand years ago, to learn our fire-meditation. She sat in the hot sand for three days and never once complained. I've never forgiven her.",
            "When the night comes that you need us, we'll come. All four. Old bones, young hearts. Just ring something loud."],
   "after": ["The glassworks are running again. Want a tumbler? Everybody wants a tumbler.",
             "Icewhisker sent a block of ice by ferry. It arrived as a bucket of water. She thinks that's hilarious.",
             "The Never-Out Fire is out of danger. It's showing off now, frankly.",
             "Cartwheels keep you young. That and holding a star."],
   "enemies": ["grump_ember", "lantern_moth", "grump_brute"], "foe_word": "Ember Grumps and lantern moths",
   "kits": [
     {"name": "Cinder", "wait": "Lady Cinderpaw first. She's the one doing cartwheels. On hot sand. Show-off.",
      "quest": {"id": "vents", "title": "Cooling Stones", "ask": "My little brother's hut is right over a cracked vent. If you bring me ten stone and three coal, we can build him a proper hearth instead of a hot floor.",
                "need": {"stone": 10, "coal": 3}, "thanks": "A real hearth! He's asleep already. On the warm bit. On purpose this time.", "reward": {"ember_glass": 1, "crystals": 300}},
      "after": ["My brother cooks on his new hearth. Mostly toast. Very good toast.", "The vent sighs at night now instead of growling. I like the sigh."]},
     {"name": "Flick", "wait": "You want Lady Cinderpaw. Follow the laughing.",
      "quest": {"id": "glassbeads", "title": "Glass Beads for the Fire", "ask": "We hang glass beads round the Never-Out Fire so it can see itself and feel less lonely. Five glass and one silver bar and I'll make a whole string.",
                "need": {"glass": 5, "silver_bar": 1}, "thanks": "Look how it shines in all of them! It's not lonely now.", "reward": {"crystal_glass": 1, "crystals": 350}},
      "after": ["The fire likes the beads. It does a little twirl.", "I'm learning glassblowing. I've made eleven puddles and one bead."]},
     {"name": "Soot", "lines": ["I'm not dirty, I'm volcanic.", "Lady Cinderpaw says the mountain is a big grumpy cat. I'd like to pet it.", "Hot sand, hot sand, hot sand, cool rock. Ahh."]}],
   "secrets": [{"type": "loot", "cell": [20, 18], "item": "glass", "n": 1, "every": 5, "empty": "Sand gone to glass, then gone to someone's pocket.", "hint": "A: dig", "solid": False},
               {"type": "note", "cell": [30, 40], "who": "", "text": "A tile of black glass with gold in it: four flames in a ring around a fifth, dark one. 'Gold for the fire. And four become one.'", "hint": "A: glass tile", "solid": False},
               {"type": "loot", "cell": [68, 60], "item": "coal", "n": 2, "every": 4, "empty": "The mountain will cough up more.", "hint": "A: cinder pile", "solid": False}]},
}

for _rid, _st in STORY.items():
    COL[_rid].update({k: v for k, v in _st.items() if k not in ("enemies",)})
    COL[_rid]["enemies"] = _st["enemies"]
    COL[_rid]["foe_kinds"] = list(_st["enemies"])
# Kelp Hollow's gift no longer repeats the merkitty tail (c7_10): swim faster than any tail.
COL["colony_kelp"]["ability_desc"] = "You swim a quarter faster than any tail can manage, even through strong currents, no partner needed."
OUT = {}
import zlib
_OLD = json.load(open(D + "/data/regions.json"))
_OLD = _OLD.get("regions", _OLD)


def _seed(rid):
    """Stable island seed: keep the seed the colony already has (so maps never
    reshape on a rerun), else derive one that's the same every run."""
    isl = (_OLD.get(rid) or {}).get("islands") or []
    if isl and isinstance(isl[0], dict) and "seed" in isl[0]:
        return int(isl[0]["seed"]) - 1
    return zlib.crc32(rid.encode()) % 900


# CONDUCT 4 (c4_08 #2): the colonies stop sharing one map. Kelp Hollow and Emberclaw
# are the east-west mirror of the base plan (islands, plateaus, paths, elder/shop/crystal,
# beacons, secrets and the ferry all flip), on top of their own island seeds.
MIRROR = ("colony_kelp", "colony_ember")

def _mirror(r, cols):
    fx = lambda x: cols - 1 - x
    for k in ("islands",):
        for b in r.get(k, []):
            b["c"][0] = fx(b["c"][0])
    for pl in r.get("plateaus", []):
        for b in pl.get("blobs", []) + pl.get("upper", []):
            b["c"][0] = fx(b["c"][0])
    r["paths"] = [[cols - p[0] - p[2], p[1], p[2], p[3]] for p in r["paths"]]
    for e in r.get("exits", []):
        e["rect"][0] = cols - e["rect"][0] - e["rect"][2]
    r["spawn"][0] = fx(r["spawn"][0])
    for t in r.get("things", []):
        t["cell"][0] = fx(t["cell"][0])


for rid, c in COL.items():
    cols, rows = 96, 76
    # Islands: a big main island, two smaller ones joined by sand bars, and a reef islet.
    isl = [{"c": [40, 40], "r": 22, "seed": _seed(rid) + 1}, {"c": [72, 26], "r": 11, "seed": _seed(rid) + 2},
           {"c": [70, 56], "r": 10, "seed": _seed(rid) + 3}, {"c": [56, 33], "r": 5, "seed": 4}, {"c": [57, 48], "r": 5, "seed": 5},
           {"c": [18, 16], "r": 7, "seed": _seed(rid) + 6}]
    pts = {"elder": [40, 44], "shop": [44, 44], "crystal": [72, 24], "beacons": [[24, 30], [42, 57], [70, 58], [18, 16]][: c["beacons"]]}
    things = [{"type": "elder", "cell": pts["elder"], "hint": "A: " + c["elder"], "solid": True},
              {"type": "colony_shop", "cell": pts["shop"], "hint": "A: " + c["shop_who"], "solid": True},
              {"type": "star_crystal", "cell": pts["crystal"], "hint": "A: the star crystal", "solid": True}]
    for i, b in enumerate(pts["beacons"]):
        things.append({"type": "beacon", "key": "b%d" % i, "cell": b, "hint": "A: tide beacon", "solid": True})
    # Secrets: a buried cache on the islet, a lore stone, a shore pile: each island its own (c7_10).
    things += [dict(t) for t in c["secrets"]]
    R[rid] = {"cols": cols, "rows": rows, "music": "beach", "backdrop": "sea", "ground": "grass", "path": "sand", "spawn": [40, 60], "pad": 6,
              "border": {"n": "water", "s": "water", "w": "water", "e": "water"},
              "exits": [{"rect": [38, 63, 4, 1], "scene": "beach", "spawn": [12, 22], "facing": "down", "label": "▼ ferry home"}],
              "paths": [[39, 44, 2, 20], [42, 34, 32, 2], [40, 50, 32, 2], [18, 22, 2, 20], [18, 41, 24, 2]], "islands": isl, "island_shore": "sand",
              "plateaus": [{"blobs": [{"c": [34, 32], "r": 7, "seed": 41}], "upper": [{"c": [34, 30], "r": 3.5, "seed": 43}]}, {"blobs": [{"c": [74, 22], "r": 5, "seed": 42}]}],
              "patch_set": "sand", "ground_threshold": -0.05, "fruit": 0, "forage": 14,
              "gen": {"clumps": 2, "scatter": 18, "critters": ["seagull", "crab", "sparrow"], "critter_count": 8},
              "things": things, "enemies": [{"kind": k, "count": 3, "colony": True} for k in c["enemies"]], "npcs": [],
              "intro": [c["arrive"]], "colony": rid}
    # Each island looks and feels like itself.
    LOOK = {"colony_coral": {"music": "colony_coral", "critters": ["seagull", "crab", "turtle"]},
            "colony_kelp": {"music": "colony_kelp", "ground": "teal_moss", "ground_seam": "teal_moss", "patch_set": "bog", "critters": ["frog", "heron", "dragonfly"], "weather": "fog"},
            "colony_ice": {"music": "colony_ice", "season": "winter", "patch_set": "snowpatch", "critters": ["seagull", "otter", "moon_rabbit"], "weather": "snow"},
            "colony_ember": {"music": "colony_ember", "ground": "dead_grass", "ground_seam": "ash", "patch_set": "sand", "critters": ["firefly", "crow", "snake"]}}
    lk = LOOK.get(rid, {})
    for key in ("music", "ground", "ground_seam", "patch_set", "weather", "season"):
        if key in lk:
            R[rid][key] = lk[key]
    if "critters" in lk:
        R[rid]["gen"]["critters"] = lk["critters"]
    if rid in MIRROR:
        _mirror(R[rid], cols)
    # Talkable kits (c7_10): things on the cells where region._colony_village stands kit i
    # (elder cell + (-4 + 4i, 3 + i % 2), after the mirror, like region.gd does).
    ec = next(t["cell"] for t in R[rid]["things"] if t["type"] == "elder")
    for i, k in enumerate(c["kits"]):
        R[rid]["things"].append({"type": "colony_kit", "key": "k%d" % i, "cell": [ec[0] - 4 + 4 * i, ec[1] + 3 + i % 2], "hint": "A: " + k["name"], "solid": True})
    scene(rid)
    E["enemies"]["cboss_" + rid.split("_")[1]] = {"hp": 70 + 30 * c["tier"], "dmg": 2 + c["tier"] // 2, "speed": 26, "xp": 50 + 20 * c["tier"], "tier": c["tier"] + 1,
        "abilities": [], "gift": c["gift"], "art": c["boss_art"], "name": c["boss_name"], "reward": 100 * c["tier"]}
    E["drops"]["cboss_" + rid.split("_")[1]] = [["crystal_refined", 1.0, 2]]
    OUT[rid] = {k: v for k, v in c.items() if k not in ("boss_art", "gift", "enemies", "secrets", "arrive")}
json.dump(R, open(D + "/data/regions.json", "w"), indent=1, ensure_ascii=False)
json.dump(E, open(D + "/data/enemies.json", "w"), indent=1, ensure_ascii=False)
json.dump(I, open(D + "/data/items.json", "w"), indent=1, ensure_ascii=False)
json.dump(G, open(D + "/data/gifts.json", "w"), indent=1, ensure_ascii=False)
json.dump(OUT, open(D + "/data/colonies.json", "w"), indent=1, ensure_ascii=False)
print("colonies:", list(OUT))
