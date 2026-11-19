#!/usr/bin/env python3
"""The Rec Center (penguins) / Rec Hall (gangsters): every piece of its data.

Writes (edit this file, not the JSON):
  data/rec.json        building, floors, lanes, arcade cabinets, visitor schedules, chatter
  data/prizes.json     the prize counter (Tickets.prize / unlocked / buy)
  data/items.json      the rp_* prize items (merged in place)
  data/interiors.json  the "rec" (ground floor) and "rec_up" (bowling) rooms (merged in place)
  data/quests.json     the rec side quests (merged in place) + data/quest_lines.json lines

    python3 tools/gen_rec.py
"""
import json, os

ROOT = os.path.join(os.path.dirname(__file__), "..")
D = os.path.join(ROOT, "data")


def load(n):
    return json.load(open(os.path.join(D, n)))


def save(n, obj):
    json.dump(obj, open(os.path.join(D, n), "w"), indent=1, ensure_ascii=False)


# ---------------------------------------------------------------- the building
# Town lot: south-east of the library, east of the beach road (town.gd places it).
BUILDING = {
    "cell": [47, 78],
    "penguins": {"sprite": "rec_center", "scale": 0.75, "name": "Rec Center"},
    "gangsters": {"sprite": "rec_hall", "scale": 0.75, "name": "Rec Hall"},
    "lane": [44, 87, 12, 2],   # dirt lane from the avenue to the door
    "open_day": 7,              # opens on the first morning from this day once the town intro is done
    "fee": 25,                  # crystals for one game of bowling
    "soda": 12,                 # vending machine price
    "hours": [9, 24],           # doors open 9am to midnight (closed 9am-6pm on festival days)
    "house_lane": 4,            # lane villagers never take: always free for a walk-in
}

# Arcade cabinets on the ground floor: ArcadeHub.open(map, id) plays one (a2's games;
# ids are ArcadeHub.GAMES). The claw machine prop opens ArcadeHub's "claw" game.
CABINETS = [
    {"id": "jumper", "name": "Block Jumper", "sprite": "arcade_cab_0", "cell": [8, 2]},
    {"id": "stack", "name": "Crystal Stack", "sprite": "arcade_cab_5", "cell": [9, 2]},
    {"id": "whack", "name": "Whack-a-Grump", "sprite": "arcade_cab_whack", "cell": [11, 2]},
    {"id": "gallery", "name": "Duck Pond", "sprite": "arcade_cab_gallery", "cell": [12, 2]},
]

LANES = [  # upper floor: left cell of each 2-wide lane; pins at the top, foul line at y 11
    {"n": 1, "x": 2}, {"n": 2, "x": 5}, {"n": 3, "x": 9}, {"n": 4, "x": 12},
]
LANE_TOP, LANE_FOUL = 3, 11

# ---------------------------------------------------------------- rooms
def room_ground():
    things = [
        {"type": "rec", "act": "prize", "cell": [3, 8], "hint": "A: prize counter", "solid": False},
        {"type": "rec", "act": "prize", "cell": [4, 8], "hint": "A: prize counter", "solid": False},
        {"type": "rec", "act": "desk", "cell": [12, 12], "hint": "A: front desk", "solid": True},
        {"type": "rec", "act": "up", "cell": [2, 3], "hint": "A: upstairs (bowling)", "solid": False},
        {"type": "rec", "act": "jukebox", "cell": [14, 5], "hint": "A: jukebox", "solid": True},
        {"type": "rec", "act": "soda", "cell": [14, 8], "hint": "A: vending machine", "solid": True},
        {"type": "rec", "act": "scores", "cell": [6, 2], "hint": "A: high scores", "solid": True},
        {"type": "rec", "act": "claw", "cell": [14, 2], "hint": "A: claw machine", "solid": True},
        {"type": "rec", "act": "skee", "cell": [2, 11], "hint": "A: skee-ball", "solid": True},
    ]
    cabs = []
    for c in CABINETS:
        things.append({"type": "rec", "act": "cabinet", "game": c["id"], "cell": c["cell"], "hint": "A: play " + c["name"], "solid": True})
        cabs.append({"group": "props", "name": c["sprite"], "cell": c["cell"]})
    return {
        "rec": True, "no_furnish": True,
        "cols": 16, "rows": 16, "floor": "fl_wood_light", "wall": "wl_panel",
        "door": [8, 15], "back": ["town", 54, 87], "music": "rec_center",
        "windows": [4], "pet": False,
        "props": [
            {"name": "stairs_up", "cell": [1, 3], "w": 1, "solid": True},
            {"group": "props", "name": "prize_counter", "cell": [2, 7], "w": 3},
            {"group": "props", "name": "ticket_booth", "cell": [11, 11], "w": 2},
            {"group": "props", "name": "jukebox_a", "cell": [14, 5], "anim": False},
            {"group": "props", "name": "vend_red", "cell": [14, 8]},
            {"group": "props", "name": "vend_blue", "cell": [14, 9]},
            {"group": "props", "name": "claw_machine", "cell": [14, 2]},
            {"group": "props", "name": "skee_ball", "cell": [2, 11], "w": 1},
            {"name": "trophy_case", "cell": [14, 11]},
            {"name": "sofa_red", "cell": [5, 13], "w": 2},
            {"name": "low_table", "cell": [6, 12]},
            {"name": "plant2_a", "cell": [1, 14]},
            {"name": "plant2_b", "cell": [14, 14]},
            {"name": "plant2_c", "cell": [7, 2]},
            {"name": "lamp_floor", "cell": [1, 8]},
        ] + cabs,
        "things": things,
        "npcs": [],
        "intro": "Bright lights, the clatter of pins upstairs, a wall of cabinets blinking for attention. The prize counter glitters like a dragon's hoard.",
        "gangsters": {"floor": "fl_carpet_purple", "wall": "wl_brick", "music": "neon",
                      "intro": "Neon on brick, the clatter of pins upstairs, a wall of cabinets blinking for attention. A sign by the door: NO HEAT INSIDE. EVERYBODY PLAYS."},
    }


def room_up():
    things = []
    for ln in LANES:
        for dx in (0, 1):
            things.append({"type": "rec", "act": "lane", "lane": ln["n"], "cell": [ln["x"] + dx, LANE_FOUL + 1], "hint": "A: bowl (lane %d)" % ln["n"], "solid": False})
    things.append({"type": "rec", "act": "shoes", "cell": [13, 16], "hint": "A: shoe rental", "solid": True})
    things.append({"type": "rec", "act": "snack", "cell": [10, 16], "hint": "A: snack bar", "solid": True})
    things.append({"type": "rec", "act": "trophies", "cell": [1, 13], "hint": "A: trophy case", "solid": True})
    return {
        "rec": True, "no_furnish": True, "lanes": True,
        "cols": 16, "rows": 18, "floor": "fl_parquet", "wall": "wl_panel",
        "door": [8, 17], "back": ["in_rec", 2, 4], "door_prop": "stairs_down", "door_hint": "A: downstairs",
        "music": "rec_center", "windows": [], "pet": False,
        "props": [
            {"name": "ball_return", "cell": [4, 10]},
            {"name": "ball_return", "cell": [11, 10]},
            {"name": "ball_rack", "cell": [7, 10], "w": 1},
            {"name": "score_console", "cell": [3, 14], "w": 1},
            {"name": "score_console", "cell": [11, 14], "w": 1},
            {"name": "trophy_case", "cell": [1, 13]},
            {"name": "pin_statue", "cell": [14, 13]},
            {"name": "sofa_red", "cell": [2, 16], "w": 2},
            {"name": "sofa_blue", "cell": [5, 16], "w": 1},
            {"name": "snack_counter", "cell": [10, 16], "w": 1},
            {"name": "shoe_counter", "cell": [13, 16], "w": 1},
        ],
        "things": things,
        "npcs": [],
        "intro": "Four lanes of polished maple run to four perfect triangles of pins. Somewhere a ball thunders home and the whole floor hums.",
        "gangsters": {"floor": "fl_concrete", "wall": "wl_concrete", "music": "neon",
                      "intro": "Four lanes under blacklight, pins glowing like teeth. Somebody's put a chalk line on the wall: HOUSE RECORD."},
    }


# ---------------------------------------------------------------- items & prizes
ITEMS = {
    "rp_fizzy_pop": {"name": "Fizzy Pop", "type": "food", "value": 20, "rarity": "common", "tier": 1, "energy": 25, "icon": "soda", "desc": "From the Rec Center machine. Fizzes up your nose."},
    "rp_cotton_candy": {"name": "Cotton Candy", "type": "food", "value": 35, "rarity": "common", "tier": 1, "energy": 30, "buff": {"kind": "speed", "minutes": 60, "amount": 1}, "icon": "cloud_cotton", "desc": "Pure sugar cloud. A spring in your step for an hour."},
    "rp_ribbon": {"name": "Lucky Ribbon", "type": "gift", "value": 40, "rarity": "common", "tier": 1, "icon": "ribbon_red", "desc": "A prize-counter ribbon. Nice to give."},
    "rp_kite": {"name": "Kite", "type": "gift", "value": 90, "rarity": "uncommon", "tier": 2, "icon": "kite", "desc": "Diamond kite with a long tail. The kids would love it."},
    "rp_teddy": {"name": "Teddy Bear", "type": "gift", "value": 120, "rarity": "uncommon", "tier": 2, "icon": "teddy_bear", "desc": "The prize every kid points at first."},
    "rp_penguin_plush": {"name": "Penguin Plush", "type": "gift", "value": 140, "rarity": "uncommon", "tier": 2, "icon": "penguin_figurine", "desc": "Squishy, round, suspiciously familiar."},
    "rp_cat_plush": {"name": "Lucky Cat", "type": "gift", "value": 140, "rarity": "uncommon", "tier": 2, "icon": "cat_figurine", "desc": "Waves one paw forever. For luck."},
    "rp_bowling_cap": {"name": "Bowling Cap", "type": "equip", "slot": "head", "value": 150, "rarity": "uncommon", "tier": 2, "stats": {"luck": 1}, "sprite": "cap", "icon": "cap", "desc": "Rec Center league cap."},
    "rp_neon_cap": {"name": "Neon Cap", "type": "equip", "slot": "head", "value": 180, "rarity": "uncommon", "tier": 2, "stats": {"speed": 1}, "sprite": "cap", "icon": "neon_hat", "desc": "Glows faintly in the dark."},
    "rp_top_hat": {"name": "Top Hat", "type": "equip", "slot": "head", "value": 400, "rarity": "rare", "tier": 3, "stats": {"luck": 2}, "sprite": "tophat", "icon": "tophat", "desc": "For the high roller of the lanes."},
    "rp_star_cape": {"name": "Star Cape", "type": "equip", "slot": "back", "value": 600, "rarity": "rare", "tier": 3, "stats": {"speed": 1, "luck": 1}, "icon": "cape_star", "desc": "Only bowlers who've rolled a 200 wear this."},
    "rp_music_box": {"name": "Music Box", "type": "decor", "value": 200, "rarity": "uncommon", "tier": 2, "icon": "music_box", "desc": "Decor: it sits in your house and plays a little tune."},
    "rp_painting": {"name": "Neon Painting", "type": "decor", "value": 250, "rarity": "uncommon", "tier": 2, "icon": "painting_abstract", "desc": "Decor: hangs in your house."},
    "rp_trophy_bronze": {"name": "Bronze Bowling Trophy", "type": "decor", "value": 250, "rarity": "uncommon", "tier": 2, "icon": "trophy_bronze", "desc": "Decor: for your first 100 game."},
    "rp_trophy_silver": {"name": "Silver Bowling Trophy", "type": "decor", "value": 450, "rarity": "rare", "tier": 3, "icon": "trophy_silver", "desc": "Decor: for a 160 game."},
    "rp_trophy_gold": {"name": "Gold Bowling Trophy", "type": "decor", "value": 900, "rarity": "epic", "tier": 4, "icon": "trophy_gold", "desc": "Decor: for a 220 game. The house record wall knows your name."},
    "rp_golden_pin": {"name": "Golden Pin", "type": "decor", "value": 1500, "rarity": "legendary", "tier": 5, "icon": "trophy_master", "desc": "Decor: for a 270 game. People will ask."},
    "rp_arcade_medal": {"name": "Arcade Medal", "type": "decor", "value": 400, "rarity": "rare", "tier": 3, "icon": "medal_gold", "desc": "Decor: for playing every cabinet in the hall."},
    "rp_jukebox": {"name": "Jukebox", "type": "decor", "value": 800, "rarity": "epic", "tier": 4, "icon": "music_box2", "desc": "Decor: a real jukebox for your house."},
    "rp_arcade_cab": {"name": "Home Arcade Cabinet", "type": "decor", "value": 1000, "rarity": "epic", "tier": 4, "icon": "token_star", "desc": "Decor: your own cabinet at home. It blinks all night."},
}

# need: {"best": {game: score}, "plays": {game: n}, "earned": n, "arcade": {"plays": n, "games": n}, "once": true}
PRIZES = [
    ("candy", 15, 1, {}),
    ("rp_fizzy_pop", 15, 1, {}),
    ("rp_cotton_candy", 25, 1, {}),
    ("rp_ribbon", 30, 1, {}),
    ("rp_kite", 60, 2, {}),
    ("rp_teddy", 80, 2, {}),
    ("rp_penguin_plush", 90, 2, {}),
    ("rp_cat_plush", 90, 2, {}),
    ("rp_bowling_cap", 120, 2, {"plays": {"bowling": 2}, "once": True}),
    ("rp_neon_cap", 140, 2, {"arcade": {"plays": 3}, "once": True}),
    ("rp_music_box", 150, 2, {"once": True}),
    ("rp_painting", 200, 3, {"once": True}),
    ("growth_elixir", 400, 3, {"earned": 150}),
    ("rp_trophy_bronze", 200, 3, {"best": {"bowling": 100}, "once": True}),
    ("rp_top_hat", 300, 3, {"best": {"bowling": 150}, "once": True}),
    ("rp_trophy_silver", 350, 3, {"best": {"bowling": 160}, "once": True}),
    ("rp_arcade_medal", 300, 3, {"arcade": {"games": 4}, "once": True}),
    ("rp_star_cape", 450, 4, {"best": {"bowling": 200}, "once": True}),
    ("rp_jukebox", 600, 4, {"earned": 400, "once": True}),
    ("rp_trophy_gold", 700, 4, {"best": {"bowling": 220}, "once": True}),
    ("rp_arcade_cab", 800, 4, {"earned": 600, "arcade": {"plays": 15}, "once": True}),
    ("rp_golden_pin", 1200, 4, {"best": {"bowling": 270}, "once": True}),
]

# Where owned decor shows up in your house (House calls RecCenter.dress_house).
HOUSE_DECOR = {
    "rp_music_box": {"shelf": [11, 8], "slot": 1, "name": "music_box"},
    "rp_painting": {"wall": "painting_abstract", "x": 8},
    # Trophies stand on a trophy shelf (shelf: [cell x, y], slot 0-2 across its top).
    "rp_trophy_bronze": {"shelf": [11, 6], "slot": 0, "name": "trophy_bronze"},
    "rp_trophy_silver": {"shelf": [11, 6], "slot": 1, "name": "trophy_silver"},
    "rp_trophy_gold": {"shelf": [11, 6], "slot": 2, "name": "trophy_gold"},
    "rp_golden_pin": {"shelf": [11, 8], "slot": 0, "name": "trophy_master"},
    "rp_arcade_medal": {"shelf": [11, 8], "slot": 2, "name": "medal_gold"},
    "rp_jukebox": {"group": "props", "name": "jukebox_b", "cell": [1, 5], "solid": True},
    "rp_arcade_cab": {"group": "props", "name": "arcade_cab_1", "cell": [1, 7], "solid": True},
}

# ---------------------------------------------------------------- villagers
# slots: [days, from_hour, to_hour, floor] ; days: "all", "rest" (every 6th/7th day),
# "league" (day % 7 == 3, league night), "rain", or a list of day%7 numbers.
VISITORS = {
    "pip": {"slots": [["rest", 13, 17, "rec"], ["rain", 14, 18, "rec"], [[2, 5], 15, 17, "rec"]], "spot": "cab"},
    "tobin": {"slots": [["rest", 13, 17, "rec_up"], ["rain", 14, 18, "rec"], [[1, 4], 15, 17, "rec"]], "spot": "lane"},
    "mabel": {"slots": [["rest", 14, 17, "rec"], ["rain", 14, 18, "rec"], [[3], 15, 17, "rec"]], "spot": "cab"},
    "wren_jr": {"slots": [["rest", 13, 16, "rec_up"], ["rain", 14, 18, "rec"]], "spot": "cab"},
    "gideon": {"slots": [["league", 19, 22, "rec_up"], [[5], 19, 21, "rec_up"]], "spot": "lane"},
    "maple": {"slots": [["league", 19, 21, "rec_up"]], "spot": "lane"},
    "finn": {"slots": [[[6], 18, 21, "rec_up"], ["league", 19, 21, "rec_up"]], "spot": "lane"},
    "sal": {"slots": [["all", 20, 23, "rec"]], "spot": "cab"},
    "lumi": {"slots": [["rain", 13, 17, "rec"], [[4], 16, 18, "rec"]], "spot": "lobby"},
    "theo": {"slots": [[[4], 17, 19, "rec"], ["rain", 17, 19, "rec"]], "spot": "cab"},
    "ivy": {"slots": [[[5], 17, 19, "rec_up"], ["league", 19, 21, "rec_up"]], "spot": "lane"},
    "alder": {"slots": [[[0], 15, 17, "rec"]], "spot": "lobby"},
    "juniper": {"slots": [[[1], 19, 21, "rec_up"]], "spot": "lane"},
    "posy": {"slots": [[[6], 17, 19, "rec"]], "spot": "lobby"},
    "benno": {"slots": [[[4], 18, 20, "rec_up"], ["league", 20, 22, "rec_up"]], "spot": "lane"},
    "hazel": {"slots": [["rain", 15, 18, "rec"]], "spot": "lobby"},
    "rook": {"slots": [[[2], 19, 21, "rec_up"]], "spot": "lane"},
}

# Where visitors stand: per floor, ordered (lanes: on the approach of lanes 1-3, then a
# partner behind each; lane 4 is the house lane and stays free; cabinets: in front of each).
STANDS = {
    # cab: two players, then watchers in the gaps (beside a pair, by the claw), then the
    # last two cabinets. A visitor at a cabinet steps aside when you ask for a go.
    "rec": {"cab": [[8, 3], [11, 3], [10, 3], [13, 3], [9, 3], [12, 3]],
            "lobby": [[5, 10], [9, 13], [9, 10], [4, 12], [10, 7], [6, 6]]},
    "rec_up": {"lane": [[3, 12], [6, 12], [10, 12], [2, 13], [5, 13], [9, 13]],
               "lobby": [[6, 14], [9, 14], [8, 13], [14, 15], [12, 15], [7, 15]]},
}

# How well each villager bowls (their average; a game with you lands within about 25 of it).
BOWL_AVG = {
    "maple": 182, "gideon": 168, "benno": 118, "finn": 142, "ivy": 131, "juniper": 124, "rook": 147,
    "theo": 74, "tobin": 66, "wren_jr": 58, "pip": 61, "mabel": 55, "sal": 120, "alder": 96,
    "lumi": 88, "hazel": 79, "posy": 92,
}

# What people say about the place. {best} = your best game, {tickets} = tickets on hand,
# {name} = you, {hall} = Rec Center / Rec Hall.
CHAT_ANY = [
    "Have you been to the {hall} yet? I keep hearing pins in my sleep.",
    "League night at the {hall}. Half the town goes, the other half pretends not to care.",
    "The prize counter has a teddy bear the size of a toddler. I'm just saying.",
]
# Before the grand opening (from day 3, until it opens): the lead-in.
CHAT_SOON = [
    "Hammering at the old hotel by the library all week. The banner says {hall}. Mayor Alder won't stop grinning.",
    "Somebody carried a whole crate of bowling pins past my window. Bowling! Here!",
    "The old hotel south-east of the library is getting a new roof. They say it opens in a few days.",
]
CHAT_SOON_GANG = [
    "Crews have been in and out of that old hotel by the library all week. Banner says {hall}. Bowling, apparently.",
    "Sal says the old hotel's turning into a place where nobody brings heat. I'll believe it when I see it.",
    "Somebody wheeled six arcade cabinets past the library at dawn. Something's opening south-east of there.",
]
CHAT_SCORE = [
    "Somebody said you bowled a {best}. Was that you? Respect.",
    "Your name's on the high score board. {best}. Don't let it go to your head.",
]
CHAT = {
    "pip": ["I'm saving tickets for the kite. Don't tell Mabel, she wants it too.", "Block Jumper is easy. I mean, I haven't beaten it. But it's easy."],
    "tobin": ["I bowled a strike once. Okay, it was a gutter that bounced. Still counts.", "Bet you can't beat my high score! ...What is my high score? I forgot."],
    "mabel": ["The teddy bear at the prize counter has a little bow. A LITTLE BOW.", "Grandma Hazel says tickets aren't money. Grandma Hazel has never seen the prize counter."],
    "wren_jr": ["Mum says if I get a strike she'll make pancakes. I've had a lot of not-pancakes.", "The machines upstairs talk when you win. Mostly they say TRY AGAIN."],
    "gideon": ["Bowling's just smithing with a ball. Weight, line, follow through.", "Maple thinks she's the league champion. Maple is the league champion. Don't tell her I said it."],
    "maple": ["League night is the only night Gideon's quiet. He's concentrating.", "I bowl with my grandmother's ball. It's heavier than it looks, dear. So am I."],
    "finn": ["Bowling's like casting. Pick a line and trust it.", "The lanes are oiled like a calm sea. Ball goes straight till it doesn't."],
    "sal": ["Late at the {hall}'s the quiet part. Just me and the cabinets.", "I don't do prizes. I do high scores. Initials and everything."],
    "lumi": ["The colors in there! I've been sketching the neon all week.", "A rainy day and the {hall}: the best kind of afternoon."],
    "theo": ["I've charted the pin physics. Theoretically I should bowl 300. Practically: 74.", "Every cabinet has a pattern. Learn the pattern, beat the game."],
    "ivy": ["I keep score on paper. The machine's never wrong, but paper feels right.", "Tickets are a currency with zero interest. I've done the maths."],
    "alder": ["Cutting that ribbon was the proudest morning of my term. Well. One of them.", "A town needs a place to gather that isn't the inn. The {hall} is that place."],
    "juniper": ["Bend your knees when you bowl. I've seen the alternative. It's my whole job.", "My one night off and I spend it at lane one. Worth it."],
    "posy": ["I bring cookies to the {hall} on the weekend. The kids find me in seconds.", "The cotton candy is a crime against baking. I had three."],
    "benno": ["The horses don't care for the pins. I go alone.", "Rolled a 140 once. Haven't stopped talking about it, they tell me."],
    "hazel": ["Rain on the fields, so I'm at the {hall}. Don't look at me like that.", "I don't bowl. I watch. It's the same thing with less effort."],
    "rook": ["Tracking a bowling ball's easy. It only goes one way.", "Quiet up there on a weeknight. I like the thunder of it."],
}
CHAT_GANG = {  # gangster-arc swaps
    "alder": ["A town needs a place to gather where nobody asks questions. The Rec Hall's that place.", "No heat inside. That's the rule. Even the President's people bowl badly."],
    "sal": ["Late at the Rec Hall's the quiet part. Nobody's looking for anybody in there.", "I don't do prizes. I do high scores. Initials and everything."],
}

# Where they are and what they're doing: lines by spot ({game} = the cabinet in front of them).
CHAT_SPOT = {
    "cab": ["Shh. I'm on a streak. {game} can smell fear.", "One more go on {game} and then I'll go home. That was four goes ago.",
            "If you want {game}, just ask. I'll watch. I'm a great watcher."],
    "lane": ["Lane's warm. Want to bowl a game together? Loser buys the Fizzy Pop.", "Bowling's better with company. Grab a ball and join me.",
             "I'm just practising. ...Okay, I'm losing to myself."],
    "lobby": ["I came for the games. I'm staying for the sofa.", "Best seat in the house is right here. You see everyone's face when they miss.",
              "Somebody won the big teddy last week. The whole room clapped."],
}
# League night (upstairs): every league bowler, plus a few of their own.
CHAT_LEAGUE = ["League night! Two to a lane, and lane four's kept for walk-ins.", "League's friendly. Mostly. Gideon keeps a notebook.",
               "Bowl a game with us if you like. No dues, just bragging rights."]
CHAT_LEAGUE_OWN = {
    "gideon": ["League night. Maple's ahead by six pins. Six. I counted twice.", "Steady hands, steady line. Same as the anvil."],
    "maple": ["League night, dear. I'm defending the cup. Again.", "Gideon thinks I can't hear him counting. I can."],
    "finn": ["League's like a good tide. Comes round every week whether you're ready or not."],
    "ivy": ["I've got everyone's averages on paper. Mine's improving. Slowly. Measurably."],
    "benno": ["League night's the one night the horses go to bed without me."],
}
# Rain brings them in: lines for a rainy afternoon.
CHAT_RAIN = ["Rain all day, so here we all are. Best roof in town.", "Listen to it hammering on the roof! Nobody's going home till it stops.",
             "Rainy days are rec days. Everybody knows that."]
# After a game together: [you won, you lost, a tie]. {you}/{them} = scores.
CHAT_RESULT = {
    "_": ["{you} to {them}! You win this one. I want a rematch.", "{them} to your {you}. Good game though. Same time next week?", "{you} each! A dead heat. That never happens."],
    "maple": ["{you} to {them}... well. Don't tell Gideon, dear.", "{them} to {you}. The cup stays on my shelf. Lovely game.", "A tie! I'll take it. Gideon won't."],
    "gideon": ["{you} to {them}. Hm. Good line. I'll be practising.", "{them} to {you}. Weight, line, follow through. You'll get there.", "Even at {you}. Like two halves of a horseshoe."],
    "tobin": ["{you} to {them}?! The lane was SLANTED.", "{them} to {you}! I WON! Tell everyone. Tell Pip.", "Same score! That means I win. That's the rule."],
}
# The front desk's board: who's in when (shown by "What's on today?").
DAY_WORDS = {"rest": "a rest day (the 6th and 7th of each week)", "league": "league night (the 3rd, 10th, 17th and 24th)"}

# ---------------------------------------------------------------- quests
QUESTS = [
    {"id": "rec_bowl_120", "giver": "tobin", "text": "Tobin bets you can't bowl 120 or more at the Rec Center.", "when": {"flag": "rec_open"},
     "done_when": {"flag": "bowl_120"}, "reward": {"crystals": 150, "friend": ["tobin", 15]}},
    {"id": "rec_teddy", "giver": "mabel", "text": "Mabel wants the Teddy Bear from the prize counter (80 tickets).", "when": {"flag": "rec_open", "day": 9},
     "done_when": {"item": ["rp_teddy", 1]}, "take": True, "reward": {"item": ["rp_kite", 1], "friend": ["mabel", 20]}},
]
QUEST_LINES = {
    "rec_bowl_120": {"offer": ["You've been to the Rec Center? Bet you can't bowl a hundred and twenty.", "I'll give you my whole allowance if you do. Okay, Dad's whole allowance. Okay, Dad will pay."],
                     "yes": "Ha! Lane two's luckiest. Everybody knows that.", "no": "Scared of the pins. Classic.",
                     "wait": "A hundred and twenty! Not a hundred and nineteen. I'll know.",
                     "done": ["You did NOT. ...You did? The board says you did.", "Fine. Dad, pay up. A deal's a deal."]},
    "rec_teddy": {"offer": ["The Teddy Bear. At the prize counter. With the bow.", "I need eighty tickets and I have four. Could you win it for me? Please? I'll give you my kite. I'll win another kite."],
                  "yes": "THANK YOU. Name him something good.", "no": "...He'll still be there. Probably. Unless Pip gets him.",
                  "wait": "Is he still there? The bear? With the bow?",
                  "done": ["You got him! He's softer than I thought! He's PERFECT.", "Here, the kite's yours. I mean it. Bears are better than kites."]},
}
QUEST_LINES_GANG = {
    "rec_bowl_120@gangsters": {"offer": ["You been up the Rec Hall? Bet you can't bowl a hundred and twenty.", "I'll get Dad to put up the stakes. He likes a bet. Mum says he can't, but bowling's different."],
                               "done": ["You did NOT. ...The chalk wall says you did.", "Fine. Dad, pay up. A deal's a deal."]},
    "rec_teddy@gangsters": {"offer": ["The Teddy Bear. At the Rec Hall counter. With the bow.", "I need eighty tickets and I have four. Win him for me? I'll give you my kite."]},
}


def balance_values():
    """Prize items sell for about half their ticket cost (a ticket costs a crystal or more
    to win), so the counter is never a crystal machine: buy-and-sell always loses."""
    for item, cost, tier, need in PRIZES:
        if item in ITEMS:
            ITEMS[item]["value"] = max(5, cost // 2)


def main():
    balance_values()
    rec = {
        "_": "Generated by tools/gen_rec.py",
        "building": BUILDING, "cabinets": CABINETS, "lanes": LANES, "lane_top": LANE_TOP, "lane_foul": LANE_FOUL,
        "visitors": VISITORS, "stands": STANDS,
        "bowl_avg": BOWL_AVG, "chat_spot": CHAT_SPOT, "chat_league": CHAT_LEAGUE, "chat_league_own": CHAT_LEAGUE_OWN,
        "chat_rain": CHAT_RAIN, "chat_result": CHAT_RESULT, "day_words": DAY_WORDS,
        "chat_any": CHAT_ANY, "chat_soon": CHAT_SOON, "chat_soon_gang": CHAT_SOON_GANG, "chat_score": CHAT_SCORE, "chat": CHAT, "chat_gang": CHAT_GANG,
        "house_decor": HOUSE_DECOR,
    }
    save("rec.json", rec)

    names = {"bowling": "Bowling"}
    for c in CABINETS:
        names[c["id"]] = c["name"]
    names["claw"] = "Claw Machine"
    names["skee_ball"] = "Skee-Ball"
    pz = {"_": "Generated by tools/gen_rec.py", "game_names": names, "order": [p[0] for p in PRIZES], "prizes": {}}
    for item, cost, tier, need in PRIZES:
        pz["prizes"][item] = {"item": item, "cost": cost, "tier": tier, "need": need}
    save("prizes.json", pz)

    items = load("items.json")
    for k, v in ITEMS.items():
        items[k] = dict(v, rec=True)
    for k in [k for k in items if k.startswith("rp_") and k not in ITEMS]:
        del items[k]
    save("items.json", items)

    rooms = load("interiors.json")
    rooms["rec"] = room_ground()
    rooms["rec_up"] = room_up()
    save("interiors.json", rooms)

    q = load("quests.json")
    ids = {x["id"] for x in QUESTS}
    q["side"] = [x for x in q["side"] if x["id"] not in ids] + QUESTS
    save("quests.json", q)
    ql = load("quest_lines.json")
    ql.update(QUEST_LINES)
    ql.update(QUEST_LINES_GANG)
    save("quest_lines.json", ql)
    print("rec: %d prizes, %d items, %d cabinets, %d visitors" % (len(PRIZES), len(ITEMS), len(CABINETS), len(VISITORS)))


if __name__ == "__main__":
    main()
