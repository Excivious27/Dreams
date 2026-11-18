#!/usr/bin/env python3
"""The town projects (Stardew community-center style): one long build per arc.
  penguins  The Crystal Ward: a protective crystal system that clears the
            darkness from the world, and in the end reaches past it.
  gangsters Headquarters: recruits move in, run automations, and the crew
            prepares to take the President's eight lieutenants, then him.
Each stage asks for bundles (items, crystals) and grants something lasting.
Writes data/projects.json.   python3 tools/gen_projects.py
"""
import json, os
D = os.path.join(os.path.dirname(__file__), "..", "data")
P = {
 "penguins": {
  "id": "crystal_ward", "name": "The Crystal Ward", "where": "town", "cell": [47, 40], "keeper": "Catkins",
  "intro": "Catkins has chalked a circle on the plaza stones. 'A ward. Six crystals, set right, and the dark stops coming through. Set more, and maybe it stops everywhere.'",
  "stages": [
   {"name": "The Ward Stone", "bundles": [{"name": "Foundation", "need": {"stone": 40, "clay": 10, "shard": 6}}, {"name": "First Light", "need": {"crystal_refined": 2, "#flower": 5}}],
    "grant": "ward_stone", "desc": "A pale stone hums on the plaza. Every morning it leaves a crystal shard in the sell box's place."},
   {"name": "Light Pylons", "bundles": [{"name": "Pylon Frames", "need": {"iron_bar": 6, "plank": 30}}, {"name": "Lenses", "need": {"glass": 8, "crystal_refined": 3}}, {"name": "Harvest Offering", "need": {"#veg": 12, "#fruit": 6}}],
    "grant": "war_table", "desc": "Four pylons ring the town. Catkins sets a war table under them: the crystal battlefields are open."},
   {"name": "The Prism Array", "bundles": [{"name": "Prisms", "need": {"crystal_glass": 4, "silver_bar": 4}}, {"name": "Night Garden", "need": {"#magic": 4, "#herb": 10}}, {"name": "Deep Gifts", "need": {"gold": 6, "dark": 4}}],
    "grant": "prism_array", "desc": "Light bends over the farm: crops within the ward grow a little faster and your mana refills in the morning."},
   {"name": "The Sky Lens", "bundles": [{"name": "Lens Frame", "need": {"steel_bar": 6, "crystal_glass": 6}}, {"name": "Sea Gifts", "need": {"#fish": 8, "pearl": 2}}],
    "grant": "sky_lens", "desc": "The lens catches the colonies' crystal light across the sea. Ferry passes to the merkitty islands are yours."},
   {"name": "The Aurora Dome", "bundles": [{"name": "Starglass", "need": {"crystal_battery": 4, "moon_bar": 2}}, {"name": "Colony Light", "need": {"colony_light": 4}}, {"name": "Grand Harvest", "need": {"#veg": 30, "#fruit": 20, "#grain": 20}}],
    "grant": "aurora_dome", "desc": "An aurora settles over the valley and stays. The fog of the dark lifts from every region; foes there are weaker."},
   {"name": "The Star Beacon", "bundles": [{"name": "Heart of the Ward", "need": {"star_dust": 10, "crystal_battery": 6}}, {"name": "Every Friend", "need": {"friendship_tokens": 1}}],
    "grant": "star_beacon", "desc": "The beacon lights. Far off, other worlds see it and answer. The universe is a little less dark tonight."}]},
 "gangsters": {
  "id": "hq", "name": "Headquarters", "where": "hideout", "cell": [30, 30], "keeper": "Deuce",
  "intro": "Deuce kicks a crate. 'A back room is a back room. A headquarters is a promise. Build it, and the people we've helped move in. Then we go after his lieutenants. Then him.'",
  "stages": [
   {"name": "The Back Room", "bundles": [{"name": "Walls", "need": {"plank": 40, "nails": 20}}, {"name": "Furniture", "need": {"cloth": 10, "iron_bar": 4}}],
    "grant": "hq_back_room", "desc": "A table, a lamp, a map. Two crew can be given standing jobs overnight (talk to Deuce at HQ)."},
   {"name": "The Safehouse", "bundles": [{"name": "Bunks", "need": {"hardwood_plank": 12, "cotton_cloth": 8}}, {"name": "Pantry", "need": {"#veg": 15, "root_beer": 4}}],
    "grant": "hq_safehouse", "desc": "Recruits live here now. Heat cools one extra each night, and four crew can work jobs."},
   {"name": "The Ops Floor", "bundles": [{"name": "Wiring", "need": {"circuit_board": 6, "copper_bar": 8}}, {"name": "Maps", "need": {"blank_stock": 10, "ink": 6}}],
    "grant": "war_table", "desc": "Specs wires a war table: the battlefields are open. Lieutenant intel goes up on the wall."},
   {"name": "The Workshop Wing", "bundles": [{"name": "Machines", "need": {"gear": 12, "spring": 8, "servo": 4}}, {"name": "Power", "need": {"crystal_battery": 2, "steel_bar": 6}}],
    "grant": "hq_workshop", "desc": "Six crew can work jobs, and every job pays half again."},
   {"name": "Rooftop Comms", "bundles": [{"name": "Antenna", "need": {"steel_bar": 8, "data_chip": 4}}, {"name": "Drones", "need": {"spy_drone": 1, "scrap_bot": 2}}],
    "grant": "hq_comms", "desc": "Drones patrol the districts: collectors never raid you, and the map marks lieutenants you haven't beaten."},
   {"name": "The Tower Plan", "bundles": [{"name": "Lieutenants", "need": {"lieutenant_marks": 6}}, {"name": "War Chest", "need": {"gold_bar": 6, "bills_fine": 6}}],
    "grant": "tower_plan", "desc": "The whole crew is ready. Against the President you start with full mana, a shield, and the crew's backup."}]},
}
JOBS = {
 "press": {"name": "Run the press", "desc": "Prints 4 passable bills overnight.", "give": {"bills_passable": 4}},
 "farm": {"name": "Mind the farm", "desc": "Waters every crop overnight.", "water": True},
 "scout": {"name": "Watch the streets", "desc": "Heat cools one more each night.", "heat": -1},
 "fence": {"name": "Fence goods", "desc": "Earns ◆120 a night from contacts.", "crystals": 120},
 "salvage": {"name": "Salvage runs", "desc": "Brings back scrap: gears, springs, circuit boards.", "give": {"gear": 2, "spring": 1, "circuit_board": 1}},
 "train": {"name": "Drill recruits", "desc": "Combat XP every night.", "xp": ["combat", 25]},
}
json.dump({"_": "Generated by tools/gen_projects.py", "projects": P, "jobs": JOBS}, open(D + "/projects.json", "w"), indent=1, ensure_ascii=False)
print("projects ok")
