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
    path = os.path.join(D, n)
    nl = os.path.exists(path) and open(path, "rb").read()[-1:] == b"\n"  # keep the file's ending (small diffs)
    with open(path, "w") as f:
        json.dump(obj, f, indent=1, ensure_ascii=False)
        if nl:
            f.write("\n")


# ---------------------------------------------------------------- the building
# Town lot: south-east of the library, east of the beach road (town.gd places it).
BUILDING = {
    "cell": [47, 78],
    "penguins": {"sprite": "rec_center", "scale": 0.75, "name": "Rec Center"},
    "gangsters": {"sprite": "rec_hall", "scale": 0.75, "name": "Rec Hall"},
    "lane": [44, 87, 12, 2],   # dirt lane from the avenue to the door
    "open_day": 7,              # opens on the first morning from this day once the town intro is done
    "fee": 25,                  # crystals for one game of bowling
    "soda": 30,                 # vending machine price (C8 P6: priced like the snack bar)
    "hours": [9, 24],           # doors open 9am to midnight (closed 9am-6pm on festival days)
    "hours_gang": [9, 26],      # gangster Rec Hall: 9am to 2am (Tom, Guide 26 #5); past 24 = after midnight
    "house_lane": 4,            # lane villagers never take: always free for a walk-in
    # Upstairs snack bar (RecCenter._snack): item, price, what the menu says it does.
    # Item values stay well under the price, so buying to sell always loses.
    # C8 P6 (c8_06): energy per crystal sits on the shop curve (~0.8; bread 0.9,
    # energy tea 0.6), buffs priced on top, so town food still matters after day 7.
    "snacks": [
        ["rp_popcorn", 25, "lucky hands, 90 min"],
        ["rp_pretzel", 55, "big energy"],
        ["rp_cotton_candy", 45, "quick feet, 60 min"],
        ["rp_fizzy_pop", 30, "a pick-me-up"],
    ],
}

# Arcade cabinets on the ground floor: ArcadeHub.open(map, id) plays one (a2's games;
# ids are ArcadeHub.GAMES). The claw machine prop opens ArcadeHub's "claw" game.
CABINETS = [
    {"id": "jumper", "name": "Block Jumper", "sprite": "arcade_cab_0", "cell": [8, 2]},
    {"id": "stack", "name": "Crystal Stack", "gang_name": "Neon Stack", "sprite": "arcade_cab_5", "cell": [9, 2]},
    {"id": "whack", "name": "Whack-a-Grump", "gang_name": "Whack-a-Snitch", "sprite": "arcade_cab_whack", "cell": [11, 2]},
    {"id": "gallery", "name": "Duck Pond", "gang_name": "Neon Range", "sprite": "arcade_cab_gallery", "cell": [12, 2]},
]

LANES = [  # upper floor: left cell of each 2-wide lane; pins at the top, foul line at y 11
    {"n": 1, "x": 2}, {"n": 2, "x": 5}, {"n": 3, "x": 9}, {"n": 4, "x": 12},
]
LANE_TOP, LANE_FOUL = 3, 11

# ---------------------------------------------------------------- renovations
# The rec is never "done" in one season (Tom, Guide 26 #3): after the grand opening a
# letter announces each renovation, the work runs a few days (that corner taped off),
# then it opens with a second letter. `after` = days after the opening day, `build` =
# days of work; `opens`: cabinets (ids), "skee", "jukebox", "prize_tier" (prizes of
# that tier and up wait for it). RecReno (scripts/rec_reno.gd) runs them each morning.
# After the last phase a seasonal "Rec Cup" letter keeps coming (CUP).
def P2(p, g):
    return {"penguins": p, "gangsters": g}


RENOVATIONS = [
    {"id": "arcade_wing", "after": 18, "build": 3, "opens": {"cabinets": ["whack", "gallery"]},
     "name": P2("the arcade wing", "the back room"),
     "start": P2("Big news: the boarded-up back of the arcade is getting two new cabinets. Workers start today; that corner's taped off for three days. Keep your tickets warm! - The {hall} front desk",
                 "Word from the {hall}: the back room's getting two new cabinets. Crew's in from today, that corner's taped off three days. Keep your tickets warm. - Front desk"),
     "done": P2("The arcade wing is open! {games} are plugged in and waiting. First one to top the board gets their name on the wall. - The {hall} front desk",
                "Back room's open. {games} are plugged in. Top the board and your initials go on the wall. - Front desk")},
    {"id": "skee_alley", "after": 42, "build": 4, "opens": {"skee": True},
     "name": P2("Skee-Ball Alley", "Skee-Ball Alley"),
     "start": P2("The empty corner by the snack bar is becoming a Skee-Ball alley! Four days of sawing and sanding, so mind the dust. - The {hall} front desk",
                 "The dead corner by the snack bar's becoming a Skee-Ball alley. Four days of sawing. Mind the dust. - Front desk"),
     "done": P2("Skee-Ball Alley is open! Roll for the hundred hole. Tickets pour out of these things. - The {hall} front desk",
                "Skee-Ball Alley's open. Aim for the hundred hole. These machines spit tickets. - Front desk")},
    {"id": "lounge", "after": 66, "build": 3, "opens": {"jukebox": True},
     "name": P2("the jukebox lounge", "the jukebox lounge"),
     "start": P2("We found a jukebox in the old hotel cellar! Gideon is rewiring it and we're building a little lounge around it. Three days. - The {hall} front desk",
                 "Found a jukebox in the hotel cellar. Gideon's rewiring it, we're building a lounge round it. Three days. - Front desk"),
     "done": P2("The jukebox lounge is open: pick a record, any record, and it plays all day. - The {hall} front desk",
                "Jukebox lounge is open. Pick a record and the whole hall hears it all day. - Front desk")},
    {"id": "prize_gallery", "after": 92, "build": 4, "opens": {"prize_tier": 4},
     "name": P2("the prize gallery", "the prize gallery"),
     "start": P2("The prize counter is growing a whole new glass case for our grandest prizes. Four days of polishing. Start saving! - The {hall} front desk",
                 "Prize counter's getting a new glass case for the big prizes. Four days. Start saving. - Front desk"),
     "done": P2("The prize gallery is open: our grandest prizes, under glass, waiting for the very best players. - The {hall} front desk",
                "Prize gallery's open. The big prizes, under glass. Only serious players need apply. - Front desk")},
    {"id": "trophy_hall", "after": 120, "build": 5, "opens": {"cup": True},
     "name": P2("the trophy hall", "the trophy hall"),
     "start": P2("Last big job of the year: the upstairs landing becomes a trophy hall, ready for the first Rec Cup. Five days of work. - The {hall} front desk",
                 "Last big job this year: the upstairs landing's becoming a trophy hall for the first Rec Cup. Five days. - Front desk"),
     "done": P2("The trophy hall is open, and with it the Rec Cup: every season, beat the posted score and win the cup's tickets. Watch your mail. - The {hall} front desk",
                "Trophy hall's open, and so is the Rec Cup. Every season, beat the posted score and take the pot. Watch your mail. - Front desk")},
]
# Seasonal Rec Cup once the trophy hall stands: one game per season (by year), a score to
# beat, and a ticket pot. Announced on the season's first morning.
CUP = {"games": [["bowling", 140], ["stack", 4000], ["whack", 380], ["gallery", 320], ["skee_ball", 240]],
       "step": 1.1, "tickets": 120}


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
            # CONDUCT 2 (c2_07): arcade-floor dressing (tools/slice_c2_07.py).
            {"group": "props", "name": "rec_air_hockey", "cell": [7, 8], "w": 1},
            {"group": "props", "name": "rec_pinball_a", "cell": [12, 6]},
            {"group": "props", "name": "rec_pinball_b", "cell": [13, 6]},
            {"group": "props", "name": "rec_capsule", "cell": [5, 3]},
            {"group": "props", "name": "rec_photo_booth", "cell": [1, 10]},
            {"group": "props", "name": "rec_stool_table", "cell": [2, 13], "w": 1},
        ] + cabs,
        "wall_props": [{"name": "rec_poster_0", "x": 3}, {"name": "rec_poster_2", "x": 5}],
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
        "music": "bowling_alley", "windows": [], "pet": False,  # its own lane song (c2_08)
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
        "wall_props": [{"name": "rec_poster_1", "x": 1}, {"name": "rec_poster_3", "x": 14}],
        "things": things,
        "npcs": [],
        "intro": "Four lanes of polished maple run to four perfect triangles of pins. Somewhere a ball thunders home and the whole floor hums.",
        "gangsters": {"floor": "fl_concrete", "wall": "wl_concrete", "music": "bowling_alley",
                      "intro": "Four lanes under blacklight, pins glowing like teeth. Somebody's put a chalk line on the wall: HOUSE RECORD."},
    }


# ---------------------------------------------------------------- items & prizes
ITEMS = {
    "rp_candy": {"name": "Prize Candy", "type": "food", "value": 2, "rarity": "common", "tier": 1, "energy": 12, "icon": "candy", "loved_by": "candy", "desc": "A paper twist of prize-counter candy. Anyone with a sweet tooth loves it."},
    "rp_sprout_fizz": {"name": "Sprout Fizz", "type": "consumable", "effect": "growth", "value": 50, "rarity": "rare", "tier": 3, "icon": "harvest_potion", "desc": "Prize-counter plant tonic: pour it out and every crop on your farm grows a day. One a week."},
    "rp_fizzy_pop": {"name": "Fizzy Pop", "type": "food", "value": 20, "rarity": "common", "tier": 1, "energy": 25, "icon": "soda", "desc": "From the vending machine at the rec. Fizzes up your nose."},
    "rp_cotton_candy": {"name": "Cotton Candy", "type": "food", "value": 35, "rarity": "common", "tier": 1, "energy": 30, "buff": {"kind": "speed", "minutes": 60, "amount": 1}, "icon": "snack_cotton_candy", "desc": "Pure sugar cloud. A spring in your step for an hour."},
    "rp_popcorn": {"name": "Lucky Popcorn", "type": "food", "value": 6, "rarity": "common", "tier": 1, "energy": 15, "buff": {"kind": "luck", "minutes": 90, "amount": 1}, "icon": "snack_popcorn", "desc": "A striped bucket of buttery popcorn. Regulars swear it steadies your hand at the claw and the skee lanes."},
    "rp_pretzel": {"name": "Hot Pretzel", "type": "food", "value": 10, "rarity": "common", "tier": 1, "energy": 45, "icon": "snack_pretzel", "desc": "Warm, salty, as big as your face. Bowling fuel."},
    "rp_ribbon": {"name": "Lucky Ribbon", "type": "gift", "value": 40, "rarity": "common", "tier": 1, "icon": "ribbon_red", "desc": "A prize-counter ribbon. Nice to give."},
    "rp_kite": {"name": "Kite", "type": "gift", "value": 90, "rarity": "uncommon", "tier": 2, "icon": "kite", "desc": "Diamond kite with a long tail. The kids would love it."},
    "rp_teddy": {"name": "Teddy Bear", "type": "gift", "value": 120, "rarity": "uncommon", "tier": 2, "icon": "teddy_bear", "desc": "The prize every kid points at first."},
    "rp_penguin_plush": {"name": "Penguin Plush", "type": "gift", "value": 140, "rarity": "uncommon", "tier": 2, "icon": "penguin_figurine", "arc": "penguins", "desc": "Squishy, round, suspiciously familiar."},
    "rp_fuzzy_dice": {"name": "Fuzzy Dice", "type": "gift", "value": 140, "rarity": "uncommon", "tier": 2, "icon": "dice", "arc": "gangsters", "desc": "A pair of fuzzy dice for a rear-view mirror. Every getaway car deserves some."},
    "rp_cat_plush": {"name": "Lucky Cat", "type": "gift", "value": 140, "rarity": "uncommon", "tier": 2, "icon": "cat_figurine", "desc": "Waves one paw forever. For luck."},
    "rp_bowling_cap": {"name": "Bowling Cap", "type": "equip", "slot": "head", "value": 150, "rarity": "uncommon", "tier": 2, "stats": {"luck": 1}, "sprite": "cap", "icon": "cap", "desc": "League cap from the lanes at the rec."},
    "rp_neon_cap": {"name": "Neon Cap", "type": "equip", "slot": "head", "value": 180, "rarity": "uncommon", "tier": 2, "stats": {"speed": 1}, "sprite": "cap", "icon": "neon_hat", "desc": "Glows faintly in the dark."},
    "rp_top_hat": {"name": "Top Hat", "type": "equip", "slot": "head", "value": 400, "rarity": "rare", "tier": 3, "stats": {"luck": 2}, "sprite": "tophat", "icon": "tophat", "arc": "penguins", "desc": "For the sharpest bowler on the lanes."},
    "rp_lane_fedora": {"name": "Pinstripe Fedora", "type": "equip", "slot": "head", "value": 400, "rarity": "rare", "tier": 3, "stats": {"luck": 2}, "sprite": "cowboy", "icon": "fedora", "arc": "gangsters", "desc": "Only bowlers who've rolled a 150 at the Rec Hall wear the stripe. People make room."},
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

# need: {"best": {game: score}, "plays": {game: n}, "earned": n, "arcade": {"plays": n, "games": n},
#        "ms": ArcadeHub milestone id, "once": true, "weekly": n (n per week, resets every 7 days)}
PRIZES = [
    ("rp_candy", 15, 1, {}),
    ("rp_fizzy_pop", 15, 1, {}),
    ("rp_cotton_candy", 25, 1, {}),
    ("rp_ribbon", 30, 1, {}),
    ("rp_kite", 60, 2, {}),
    ("rp_teddy", 80, 2, {}),
    ("rp_penguin_plush", 90, 2, {}),
    ("rp_fuzzy_dice", 90, 2, {}),
    ("rp_cat_plush", 90, 2, {}),
    ("rp_bowling_cap", 120, 2, {"plays": {"bowling": 2}, "once": True}),
    ("rp_neon_cap", 140, 2, {"arcade": {"plays": 3}, "once": True}),
    ("rp_music_box", 150, 2, {"once": True}),
    ("rp_painting", 200, 3, {"once": True}),
    ("rp_sprout_fizz", 300, 3, {"earned": 150, "weekly": 1}),
    ("rp_trophy_bronze", 200, 3, {"best": {"bowling": 100}, "once": True}),
    ("rp_top_hat", 300, 3, {"best": {"bowling": 150}, "once": True}),
    ("rp_lane_fedora", 300, 3, {"best": {"bowling": 150}, "once": True}),
    ("rp_trophy_silver", 350, 3, {"best": {"bowling": 160}, "once": True}),
    ("rp_arcade_medal", 300, 3, {"ms": "all_games", "once": True}),
    ("rp_star_cape", 600, 4, {"best": {"bowling": 200}, "once": True}),
    ("rp_jukebox", 900, 4, {"earned": 800, "once": True}),
    ("rp_trophy_gold", 900, 4, {"best": {"bowling": 220}, "once": True}),
    ("rp_arcade_cab", 1200, 4, {"earned": 1500, "arcade": {"plays": 25}, "once": True}),
    ("rp_golden_pin", 1500, 4, {"best": {"bowling": 270}, "once": True}),
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
    # (partners two cells back and aside, so two visitors' bubbles never stack: c9_14)
    "rec_up": {"lane": [[3, 12], [6, 12], [10, 12], [1, 14], [5, 14], [9, 14]],
               "lobby": [[6, 14], [9, 14], [8, 13], [14, 15], [12, 15], [7, 15]]},
}

# How well each villager bowls: their average game. The ONE villager-strength table:
# Bowling.opponent() turns it into a release skill (Bowling.SKILL_AVG curve), a hook and a
# win bonus; they really bowl their frames in a challenge (tools/bowl_audit.gd -- skills
# prints target vs what they bowl).
BOWL_AVG = {
    "maple": 195, "gideon": 175, "benno": 118, "finn": 150, "ivy": 135, "juniper": 115, "rook": 147,
    "theo": 135, "tobin": 95, "wren_jr": 70, "pip": 72, "mabel": 66, "sal": 120, "alder": 102,
    "lumi": 98, "hazel": 88, "posy": 104,
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
    "Somebody carried a whole crate of bowling pins down the avenue. Bowling! Here!",
    "The old hotel south-east of the library is getting a new roof. They say it opens in a few days.",
]
CHAT_SOON_GANG = [
    "Crews have been in and out of that old hotel by the library all week. Banner says {hall}. Bowling, apparently.",
    "Sal says the old hotel's turning into a place where nobody brings heat. I'll believe it when I see it.",
    "Somebody wheeled six arcade cabinets past the library at dawn. Something's opening south-east of there.",
]
# C12 P3 (c12_05-18): a villager's own lead-in line replaces the shared pool for them (both arcs).
CHAT_SOON_OWN = {
    "alder": ["The old hotel's getting a second life. Bowling lanes! Don't tell anyone I picked the carpet."],
    "gideon": ["Somebody ordered forty brass hinges for that old hotel. Forty. I'm not complaining."],
    "tess": ["I built the shoe racks for that hotel place. Size 2 to size 14. Somebody here has size 14 feet."],
    "benno": ["Carted a load of pins up from the beach road for the hotel lot. The horses didn't care for the noise."],
    "hazel": ["Mabel's been counting days till the hotel opens. She's at four. She's been at four for a week."],
    "sal": ["Whatever's going into that old hotel, it's loud. I'm told that's the point."],
}
CHAT_SCORE = [
    "Somebody said you bowled a {best}. Was that you? Respect.",
    "Your name's on the high score board. {best}. Don't let it go to your head.",
]
CHAT = {
    "pip": ["I'm saving tickets for the kite. Don't tell Mabel, she wants it too.", "Block Jumper is easy. I mean, I haven't beaten it. But it's easy."],
    "tobin": ["I bowled a strike once. Okay, it was a gutter that bounced. Still counts.", "Bet you can't beat my high score! ...What is my high score? I forgot."],
    "mabel": ["The teddy bear at the prize counter has a little bow. A LITTLE BOW.", "Mum says tickets aren't money. Mum has never seen the prize counter."],
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
CHAT_GANG = {  # gangster-arc swaps: same people, the town they live in now (serious, cool, all ages)
    "alder": ["A town needs a place to gather where nobody asks questions. The Rec Hall's that place.", "No heat inside. That's the rule. Even the President's people bowl badly."],
    "sal": ["Late at the Rec Hall's the quiet part. Nobody's looking for anybody in there.", "I don't do prizes. I do high scores. Initials and everything."],
    "gideon": ["Bowling's just smithing with a ball. Weight, line, follow through. Same as anything you mean to land.", "Maple's beaten me eleven league nights straight. That doesn't leave this hall."],
    "maple": ["League night's the one night nobody in this town talks business. House rule, and I enforce it.", "I bowl with my grandmother's ball, dear. It's seen rougher streets than these."],
    "finn": ["Bowling's like casting. Pick a line, trust it, don't look back.", "Lane four pulls left. Everybody knows. Nobody fixes it. That's this town all over."],
    "lumi": ["Pink neon on old brick. Only honest light in town. I've filled a sketchbook.", "A rainy afternoon at the {hall}. Nobody watching anybody. Best kind of quiet."],
    "theo": ["I've charted the pin physics. Theory says 300. The lanes say 74.", "Every cabinet has a pattern. Learn it and the machine works for you. Rare thing, in this town."],
    "ivy": ["Tickets earn no interest and nobody can fake them. Cleanest money in the valley.", "I keep score on paper. Machines get fixed. Paper remembers."],
    "juniper": ["Bend your knees when you bowl. Half my Monday patients didn't.", "One night off a week, and I spend it on lane one. Nobody here needs patching up. Usually."],
    "posy": ["I bring cookies at the weekend. Even the tough kids say thank you. Mostly.", "The cotton candy is a crime against baking. I had three. Don't tell the crews."],
    "benno": ["The horses don't care for the pins. I come alone, back lane, nobody bothers me.", "Rolled a 140 once. It's chalked on the house wall. Only record of mine I'll ever want."],
    "hazel": ["Rain on the lot, so I'm at the {hall}. Even gardeners get a night off.", "I don't bowl. I watch who sits with who. You learn a lot that way."],
    "rook": ["A bowling ball only goes one way. Easiest thing in town to track.", "Quiet up there on a weeknight. The pins cover any conversation you'd rather keep."],
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
    {"id": "rec_bowl_120", "giver": "tobin", "text": "Tobin bets you can't bowl 120 or more upstairs at the rec.", "when": {"flag": "rec_open"},
     "done_when": {"flag": "bowl_120"}, "reward": {"crystals": 150, "friend": ["tobin", 15]}},
    {"id": "rec_teddy", "giver": "mabel", "text": "Mabel wants the Teddy Bear from the prize counter (80 tickets).", "when": {"flag": "rec_open", "day": 9},
     "done_when": {"item": ["rp_teddy", 1]}, "take": True, "reward": {"item": ["rp_kite", 1], "friend": ["mabel", 20]}},
    # Arcade challenges (CONDUCT 2, c2_14): the cabinets feed quests, friendship and tickets.
    # Condition keys arcade_ms / rec_best / tickets_won are read by Tickets.cond_ok; reward "tickets" by GameState._give_reward.
    {"id": "rec_pip_jumper", "giver": "pip", "text": "Pip is stuck on Block Jumper. Clear level 3 to show how it's done.", "when": {"flag": "rec_visited", "day": 10},
     "done_when": {"arcade_ms": "jumper_3"}, "reward": {"tickets": 40, "friend": ["pip", 15]}},
    {"id": "rec_theo_stack", "giver": "theo", "text": "Theo wants proof his Crystal Stack pattern works: score 3,000 points.", "text_gangsters": "Theo wants proof his Neon Stack pattern works: score 3,000 points.", "when": {"flag": "rec_visited", "day": 12},
     "done_when": {"rec_best": ["stack", 3000]}, "reward": {"crystals": 120, "tickets": 30, "friend": ["theo", 15]}},
    {"id": "rec_wren_jr_duck", "giver": "wren_jr", "text": "Wren jr wants a Duck Pond score of 300 for the class chart.", "text_gangsters": "Wren jr wants a Neon Range score of 300 for the class chart.", "when": {"flag": "rec_reno_arcade_wing", "day": 11},
     "done_when": {"rec_best": ["gallery", 300]}, "reward": {"tickets": 35, "friend": ["wren_jr", 15]}},
    {"id": "rec_sal_whack", "giver": "sal", "text": "Sal wants initials on the Whack-a-Grump board: score 400.", "text_gangsters": "Sal wants initials on the Whack-a-Snitch board: score 400.", "when": {"flag": "rec_reno_arcade_wing", "day": 14},
     "done_when": {"rec_best": ["whack", 400]}, "reward": {"tickets": 60, "item": ["luck_potion", 1], "friend": ["sal", 15]}},
    {"id": "rec_maple_league", "giver": "maple", "text": "Maple dares you onto league night: bowl 150 or better.", "when": {"flag": "rec_visited", "day": 16, "quest": "rec_bowl_120"},
     "done_when": {"rec_best": ["bowling", 150]}, "reward": {"crystals": 250, "friend": ["maple", 20]}},
    {"id": "rec_alder_cabinets", "giver": "alder", "text": "Mayor Alder wants every cabinet tried before he cuts the arcade ribbon twice.", "when": {"flag": "rec_reno_arcade_wing", "day": 9},
     "done_when": {"arcade_ms": "all_games"}, "reward": {"crystals": 100, "tickets": 30, "friend": ["alder", 15]}},
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
QUEST_LINES.update({
    "rec_pip_jumper": {"offer": ["Block Jumper level three has a gap that is IMPOSSIBLE. Like, actually impossible.", "If you clear it I'll give you my tickets. Some of my tickets. Forty tickets!"],
                       "yes": "Jump at the LAST second. Or the first. I don't know, that's why I'm asking.", "no": "Okay. I'll keep falling in the gap. It's fine.",
                       "wait": "Level three yet? The gap? THE GAP?",
                       "done": ["You cleared it? Show me how! ...Okay, don't, I'll work it out.", "Here, forty tickets. A deal's a deal."]},
    "rec_theo_stack": {"offer": ["I've written down a pattern for Crystal Stack. Flat rows first, a well on the right, wait for the long gem.", "I can't test it. My hands panic. Would you score three thousand with it, for science?"],
                       "yes": "Flat rows. Right-hand well. Patience. Report back.", "no": "The pattern will wait. Patterns are patient.",
                       "wait": "Three thousand points on Crystal Stack. The pattern holds, I'm nearly sure.",
                       "done": ["Three thousand! The pattern holds. I'm writing a footnote with your name in it.", "Take this for your trouble. Science pays. A little."]},
    "rec_wren_jr_duck": {"offer": ["Our class has a chart of Duck Pond scores and mine is the lowest. By a LOT.", "If you get three hundred I can say a friend did it. That counts. I asked."],
                         "yes": "Pop the gold ducks, they're worth more! Mum says aim small.", "no": "Okay. The chart can stay sad.",
                         "wait": "Three hundred on Duck Pond! For the chart!",
                         "done": ["Three hundred! I'm putting a star next to it. A big one.", "These are my saved tickets. You earned them."]},
    "rec_sal_whack": {"offer": ["There's a board over Whack-a-Grump. Top score's four hundred and the initials are rude.", "Knock them off. I'll make it worth your while."],
                      "yes": "Bop the grumps, leave the bunnies. The bunnies cost you.", "no": "Rude initials stay up, then. Your call.",
                      "wait": "Four hundred on Whack-a-Grump. The board's still rude.",
                      "done": ["Four hundred. The board's clean. Good work.", "Tickets, and something for luck. You'll need it on the lanes."]},
    "rec_maple_league": {"offer": ["You beat Tobin's bet, I hear. That's sweet, dear. Tobin is eleven.", "League night is the third day of every week. Bowl a hundred and fifty and I'll treat you like a real rival."],
                         "yes": "Lane one is mine. You can have lane two.", "no": "Scared of an old lady with a heavy ball. Sensible.",
                         "wait": "A hundred and fifty, dear. League night's the third day of the week.",
                         "done": ["A hundred and fifty! Well. Gideon owes me a pie, he bet against you.", "Here, from the league kitty. Don't tell the league."]},
    "rec_alder_cabinets": {"offer": ["The arcade cabinets are the town's pride and I have personally tried... one.", "Would you play every cabinet once and tell me they all work? The town will reward diligence!"],
                           "yes": "Splendid! Report back, citizen.", "no": "Another day, then. They're not going anywhere. They're bolted down.",
                           "wait": "Every cabinet, once! For the public good.",
                           "done": ["Every cabinet works! Diligence! Civic spirit!", "A small reward from the town purse, and tickets from the front desk."]},
})
QUEST_LINES_GANG = {
    "rec_wren_jr_duck@gangsters": {"offer": ["Our class has a chart of Neon Range scores and mine is the lowest. By a LOT.", "If you get three hundred I can say a friend did it. That counts. I asked."],
                                   "wait": "Three hundred on Neon Range! For the chart!"},
    "rec_theo_stack@gangsters": {"offer": ["I've written down a pattern for Neon Stack. Flat rows first, a well on the right, wait for the long bar.", "I can't test it. My hands panic. Would you score three thousand with it, for science?"],
                                 "wait": "Three thousand points on Neon Stack. The pattern holds, I'm nearly sure."},
    "rec_bowl_120@gangsters": {"offer": ["You been up the Rec Hall? Bet you can't bowl a hundred and twenty.", "Do it and Dad pays you. He says everybody in this town owes somebody. Now he owes you."],
                               "done": ["You did NOT. ...The chalk wall says you did.", "Fine. Dad, pay up. A deal's a deal."]},
    "rec_teddy@gangsters": {"offer": ["The Teddy Bear. At the Rec Hall counter. With the bow.", "I need eighty tickets and I have four. Win him for me? I'll give you my kite."]},
    "rec_alder_cabinets@gangsters": {"offer": ["The Rec Hall cabinets keep this town calm, and I have personally tried... one.", "Play every cabinet once and tell me they all work. The town pays for diligence, whatever else it's paying for."],
                                     "done": ["Every cabinet works. Good. A town that plays doesn't fight.", "Something from the town purse, and tickets from the front desk."]},
    "rec_sal_whack@gangsters": {"offer": ["Board over Whack-a-Snitch. Top score's four hundred and the initials are from a crew I don't like.", "Knock them off. I'll make it worth your while."],
                                "yes": "Bop the snitches, leave the bunnies. The bunnies cost you.",
                                "wait": "Four hundred on Whack-a-Snitch. Their initials are still up.",
                                "done": ["Four hundred. Their initials are gone. They'll notice. Good.", "Tickets, and something for luck."]},
}


# ---------------------------------------------------------------- the ticket economy
# Tickets are won with crystals ($ in the gangster arc) and spent on prizes; prizes sell
# back for a sliver, so the counter is a sink, never a crystal machine. The numbers here
# are checked by check_economy() every time this runs (it refuses to write a loop), and
# `python3 tools/gen_rec.py --sim` prints how long each prize takes three kinds of player.

# What one play costs (mirrors the games' own fees; tools/ticket_econ_test.gd checks them).
FEES = {"bowling": 25, "jumper": 10, "stack": 10, "whack": 10, "gallery": 10, "claw": 20, "skee_ball": 10}
# Per-play payout (Tickets.payout): full up to "soft", half rate above it, never past "cap".
# Sources not listed (welcome gift, quests) pay as given.
PAYOUT = {
    "bowling": {"soft": 40, "cap": 60},
    "jumper": {"soft": 24, "cap": 34},
    "stack": {"soft": 24, "cap": 34},
    "whack": {"soft": 24, "cap": 34},
    "gallery": {"soft": 24, "cap": 34},
    "claw": {"soft": 14, "cap": 20},
    "skee_ball": {"soft": 24, "cap": 34},
}
RESALE = 8        # a counter prize sells for 1/RESALE of its ticket cost (floor 2)
MAX_SELL = 2.23   # best stacked sell multiplier (festival 1.1 x bartering/Alder 1.4 x skill 1.2 x Deuce 1.15 x Lucky Day 1.05; C8 P6)
FENCE = 1.2       # Marlene's fence on treasure/drop/junk (gangster arc), on top of MAX_SELL
FENCED = ("treasure", "drop", "junk")
SNACK_ENERGY_PER_CRYSTAL = (0.55, 1.0)  # snack bar energy per crystal must sit on the shop curve
CLAW_WIN = 0.8    # a keen player's first claw try of the day (the grip loosens after each win)
# Steady state after many wins in a day (c10_07): ArcadeClaw.grip_for = heavy x tightness
# (floor 0.45) + luck (capped, ArcadeClaw.LUCK_GRIP_MAX); a lift-and-carry of CLAW_CARRY_S
# seconds slips at (1-g)^2 x 1.4 per second. A go at that grip must stay under the fee.
CLAW_LUCK_CAP = 0.12
CLAW_TIGHT_FLOOR = 0.45
CLAW_HEAVY = 0.94
CLAW_CARRY_S = 2.0

# What the claw machine's plushes hide: [item, weight]. Mostly counter prizes; a few small
# treasures keep it exciting, but its average prize stays under what a go costs.
CLAW_POOL = [["rp_teddy", 18], ["rp_penguin_plush", 16], ["rp_fuzzy_dice", 16], ["rp_cat_plush", 16], ["rp_candy", 22],
             ["rp_ribbon", 12], ["rp_cotton_candy", 10], ["old_coin", 2], ["toy", 2], ["fossil", 1]]


def payout(game, n):
    p = PAYOUT.get(game)
    if not p or n <= p["soft"]:
        return max(0, n) if not p else n
    return min(p["cap"], p["soft"] + (n - p["soft"]) // 2)


def balance_values():
    """Prize items sell for 1/RESALE of their ticket cost (see check_economy)."""
    for item, cost, tier, need in PRIZES:
        if item in ITEMS:
            ITEMS[item]["value"] = max(2, cost // RESALE)


def _value(item, items):
    return int((ITEMS.get(item) or items.get(item, {})).get("value", 0))


def _type(item, items):
    return str((ITEMS.get(item) or items.get(item, {})).get("type", ""))


def check_economy(items):
    """Refuse any number that would turn the rec into a crystal machine."""
    errs = []
    worst_ticket = MAX_SELL / RESALE  # crystals one ticket can come back as, at best
    for g, fee in FEES.items():
        cap = PAYOUT[g]["cap"]
        if cap * worst_ticket >= fee:
            errs.append("%s: %d tickets can sell back for %.1f >= the %d fee" % (g, cap, cap * worst_ticket, fee))
    for item, cost, tier, need in PRIZES:
        v = _value(item, items)
        if v * RESALE > max(cost, 2 * RESALE):
            errs.append("%s: worth %d for %d tickets" % (item, v, cost))
        if not item.startswith("rp_"):
            errs.append("%s: counter prizes must be rp_ items (their value is set here)" % item)
    tw = sum(w for _, w in CLAW_POOL)
    avg = sum(_value(i, items) * w for i, w in CLAW_POOL) / float(tw)
    # Sell-back worth with the fence on loot (C8 P6): the true best case.
    avg_fenced = sum(_value(i, items) * w * (FENCE if _type(i, items) in FENCED else 1.0) for i, w in CLAW_POOL) / float(tw)
    tickets = min(PAYOUT["claw"]["cap"], 10 + int(avg) // 10)
    ev = CLAW_WIN * (avg_fenced * MAX_SELL + tickets * worst_ticket) + (1 - CLAW_WIN) * 2 * worst_ticket
    if ev >= FEES["claw"]:
        errs.append("claw: a go is worth %.1f at best (fee %d); average prize %.1f" % (ev, FEES["claw"], avg))
    import math
    g = min(0.97, CLAW_HEAVY * CLAW_TIGHT_FLOOR + CLAW_LUCK_CAP)
    win_steady = math.exp(-(1 - g) * (1 - g) * 1.4 * CLAW_CARRY_S)
    ev_steady = win_steady * (avg_fenced * MAX_SELL + tickets * worst_ticket) + (1 - win_steady) * 2 * worst_ticket
    if ev_steady >= FEES["claw"]:
        errs.append("claw: with max luck a go keeps paying %.1f all day (fee %d)" % (ev_steady, FEES["claw"]))
    src = open(os.path.join(ROOT, "scripts/arcade_claw.gd")).read()
    if "LUCK_GRIP_MAX := %s" % CLAW_LUCK_CAP not in src:
        errs.append("claw: ArcadeClaw.LUCK_GRIP_MAX must equal CLAW_LUCK_CAP (%s)" % CLAW_LUCK_CAP)
    for i, _ in CLAW_POOL:
        if i not in ITEMS and i not in items:
            errs.append("claw pool: no item " + i)
    # Snack bar and vending machine (C8 P6): never a buy-and-ship loop, and energy
    # priced like the town's food.
    stalls = [(sn[0], sn[1]) for sn in BUILDING["snacks"]] + [("rp_fizzy_pop", BUILDING["soda"])]
    for sid, price in stalls:
        v = _value(sid, items)
        if v * MAX_SELL >= price:
            errs.append("snack %s: sells back for %.1f >= its %d price" % (sid, v * MAX_SELL, price))
        en = int((ITEMS.get(sid) or items.get(sid, {})).get("energy", 0))
        lo, hi = SNACK_ENERGY_PER_CRYSTAL
        if en and not (lo <= en / float(price) <= hi):
            errs.append("snack %s: %.2f energy per crystal (shop curve %.2f-%.2f)" % (sid, en / float(price), lo, hi))
    if errs:
        raise SystemExit("gen_rec: ticket economy loop(s):\n  " + "\n  ".join(errs))
    return {"claw_avg": round(avg, 1), "claw_ev_best": round(ev, 1)}


# ---------------------------------------------------------------- pacing simulation
# Three players over 12 weeks. Ticket formulas mirror the games (bowling RecCenter.tickets_for,
# arcade _tickets_for) at a typical score for that skill; payout() applies the caps.
def _raw_tickets(game, skill):
    S = {  # casual, regular, keen
        "bowling": [(70, 1, 2), (120, 3, 3), (180, 6, 3)],     # score, strikes, spares
        "whack": [120, 200, 380], "gallery": [200, 420, 750],
        "stack": [(1500, 8), (4000, 20), (15000, 60)],          # score, lines
        "jumper": [1, 4, 8],                                    # level cleared
        "skee_ball": [90, 100, 120], "claw": [0.3, 0.55, 0.75],  # claw: win chance
    }[game][skill]
    if game == "bowling":
        return 5 + S[0] // 8 + S[1] * 2 + S[2]
    if game == "whack":
        return S // 12
    if game == "gallery":
        return S // 15
    if game == "stack":
        return S[0] // 250 + S[1] // 2
    if game == "jumper":
        return 6 + 4 * S + 3
    if game == "skee_ball":
        return max(1, S // 20)
    return S * 11 + (1 - S) * 2


PLAYERS = {  # visits a week, plays per visit {game: n}
    "casual": (0, 1, {"bowling": 1, "whack": 1, "skee_ball": 2}),
    "regular": (1, 2, {"bowling": 2, "whack": 1, "gallery": 1, "jumper": 1, "stack": 1, "claw": 1, "skee_ball": 1}),
    "keen": (2, 4, {"bowling": 3, "whack": 2, "gallery": 2, "jumper": 2, "stack": 2, "claw": 1, "skee_ball": 2}),
}


def simulate(weeks=12, verbose=True):
    """Each player buys the cheapest unlocked prize they don't own yet whenever they can
    (keepsakes first, then each toy once, Sprout Fizz weekly). Returns {player: {prize: week bought}}."""
    out = {}
    for name, (skill, visits, plays) in PLAYERS.items():
        tk, earned, spent, got = 20, 0, 0, {}
        per_visit = sum(payout(g, _raw_tickets(g, skill)) * n for g, n in plays.items())
        cost_visit = sum(FEES[g] * n for g, n in plays.items())
        best = {"bowling": [90, 150, 220][skill]}  # best game so far, not the typical one
        arcade_plays = 0
        for wk in range(1, weeks + 1):
            fizz_week = False
            for v in range(visits):
                tk += per_visit
                earned += per_visit
                spent += cost_visit
                arcade_plays += sum(n for g, n in plays.items() if g != "bowling")
                # Keepsakes first (cheapest open one), then a toy or the weekly tonic.
                for item, cost, tier, need in sorted(PRIZES, key=lambda p: (not p[3].get("once"), p[1])):
                    if item in got and not need.get("weekly"):
                        continue
                    if need.get("weekly") and fizz_week:
                        continue
                    ok = all(best.get(g, 0) >= s for g, s in need.get("best", {}).items())
                    ok = ok and earned >= need.get("earned", 0) and arcade_plays >= need.get("arcade", {}).get("plays", 0)
                    ok = ok and (need.get("ms") != "all_games" or len([g for g in plays if g not in ("bowling", "skee_ball")]) >= 5)
                    if ok and tk < cost and need.get("once"):
                        break  # saving up for this keepsake
                    if ok and tk >= cost:
                        tk -= cost
                        got.setdefault(item, wk)
                        if need.get("weekly"):
                            fizz_week = True
        out[name] = got
        if verbose:
            once = [p for p in PRIZES if p[3].get("once")]
            have = len([p for p in once if p[0] in got])
            print("%-8s %d visits/wk, %d tickets/visit for %d crystals; after %d weeks: %d/%d keepsakes, %d crystals spent"
                  % (name, visits, per_visit, cost_visit, weeks, have, len(once), spent))
            for item, cost, tier, need in PRIZES:
                if need.get("once"):
                    print("    %-18s %4d  %s" % (item, cost, ("week %d" % got[item]) if item in got else "-"))
    return out


def main():
    import sys
    balance_values()
    econ = check_economy(load("items.json"))
    if "--sim" in sys.argv:
        simulate()
        return
    rec = {
        "_": "Generated by tools/gen_rec.py",
        "building": BUILDING, "renovations": RENOVATIONS, "cup": CUP, "cabinets": CABINETS, "lanes": LANES, "lane_top": LANE_TOP, "lane_foul": LANE_FOUL,
        "visitors": VISITORS, "stands": STANDS,
        "bowl_avg": BOWL_AVG, "chat_spot": CHAT_SPOT, "chat_league": CHAT_LEAGUE, "chat_league_own": CHAT_LEAGUE_OWN,
        "chat_rain": CHAT_RAIN, "chat_result": CHAT_RESULT, "day_words": DAY_WORDS,
        "chat_any": CHAT_ANY, "chat_soon": CHAT_SOON, "chat_soon_gang": CHAT_SOON_GANG, "chat_soon_own": CHAT_SOON_OWN, "chat_score": CHAT_SCORE, "chat": CHAT, "chat_gang": CHAT_GANG,
        "house_decor": HOUSE_DECOR,
    }
    save("rec.json", rec)

    names = {"bowling": "Bowling"}
    for c in CABINETS:
        names[c["id"]] = c["name"]
    names["claw"] = "Claw Machine"
    names["skee_ball"] = "Skee-Ball"
    gang = {c["id"]: c["gang_name"] for c in CABINETS if "gang_name" in c}  # gangster-arc cabinet names (Tickets.game_name)
    pz = {"_": "Generated by tools/gen_rec.py", "game_names": names, "game_names_gang": gang, "order": [p[0] for p in PRIZES], "prizes": {},
          "fees": FEES, "payout": PAYOUT, "resale": RESALE, "max_sell": MAX_SELL, "claw_pool": CLAW_POOL, "check": econ}
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
    mine = {x["id"]: x for x in QUESTS}
    have = {x["id"] for x in q["side"]}
    # Update rec quests where they already sit (small diffs), append new ones.
    q["side"] = [mine.get(x["id"], x) for x in q["side"]] + [x for x in QUESTS if x["id"] not in have]
    save("quests.json", q)
    ql = load("quest_lines.json")
    ql.update(QUEST_LINES)
    ql.update(QUEST_LINES_GANG)
    save("quest_lines.json", ql)
    print("rec: %d prizes, %d items, %d cabinets, %d visitors" % (len(PRIZES), len(ITEMS), len(CABINETS), len(VISITORS)))


if __name__ == "__main__":
    main()
