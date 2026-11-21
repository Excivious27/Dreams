#!/usr/bin/env python3
"""Achievements + rich presence data (CONDUCT S1 P2, findings s1_03 / s1_04 / s1_05).

Writes (edit this file, never the JSON):
  data/achievements.json   60 achievements (both arcs, every system) + the stats table
  data/rich_presence.json  Steam rich-presence tokens (English) per activity

Every achievement is STATE-DERIVED: Achievements.scan() (scripts/achievements.gd)
re-evaluates each "check" against the live run, so old saves unlock retroactively
and the same scan feeds Steam later (through SteamService, P1). Checks name a kind
the runtime knows (see CHECK_KINDS) plus its arguments.

Steam rules baked in (s1_03-13, s1_04-09): API name = "ACH_" + id upper-case
(A-Z0-9_), <= 100 achievements, hidden = Steam "Spoiler", progress achievements
link a stat (INT, min 0, max >= goal), icons 256x256 PNG named <API>_ACHIEVED /
<API>_UNACHIEVED (made by tools/slice_achievements.py).
Content rules (s1_04-14): all ages, no kill/drink/gamble words, nothing rewards
taking a shop, high heat or casino winnings. Names <= 30 chars.

    python3 tools/gen_achievements.py
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")


def _load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return json.load(f)


CAMPS = _load("battles.json")["_campaigns"]["list"]
CAMP_BOTH = sorted(k for k, v in CAMPS.items() if v.get("arc") == "both")
CAMP_PENG = sorted(k for k, v in CAMPS.items() if v.get("arc") == "penguins")
CAMP_GANG = sorted(k for k, v in CAMPS.items() if v.get("arc") == "gangsters")
LIEUTENANTS = list(_load("epilogue.json")["lieutenants"].keys())
MEGA = _load("mega_regions.json")["list"]
MEGA_PENG = sorted(k for k, v in MEGA.items() if v.get("arc") in ("both", "penguins"))
MEGA_GANG = sorted(k for k, v in MEGA.items() if v.get("arc") in ("both", "gangsters"))
ENDINGS = ["revert", "shatter", "free", "take", "clean"]

# Check kinds the runtime evaluates (scripts/achievements.gd _check). "src" world =
# reads keys co-op swaps to the HOST's values while visiting (net.gd WORLD_KEYS),
# so a guest's scan skips them (s1_04-18).
CHECK_KINDS = {
    "grown": "own", "gold": "own", "hearts": "own", "flag": "own", "flag_any": "own",
    "flag_prefix": "own", "won": "own", "wins": "own", "arcade": "own", "cf_stage": "world",
    "claimed": "own", "caught_legend": "own", "museum": "own", "secrets": "own",
    "ranch_any": "world", "ranch_baby": "world", "ranch_rare": "world", "show_blue": "own",
    "decor": "own", "sets": "own", "colonies": "own", "ranch_gift": "own", "crew": "own",
    "turf": "own", "washed": "own", "shops_clean": "own", "marked_free": "own",
    "built": "world", "regions": "own", "year": "world", "earned": "own",
    "endings": "global", "arcs": "global", "net_online": "net", "net_host": "net",
    "net_peers": "net", "net_mixed": "net",
}

# Style for the icon sheets (dreams-image), one pictogram per badge.
SHEET_STYLE = ("round enamel medallion badges with a gold rim, one bold simple pictogram per badge, "
               "readable at 32 px, no text, letters or numbers, cozy hand-painted farming-game look, "
               "flat solid #FF00FF magenta background around every badge, no magenta or violet inside the art, all ages")

A = []


def ach(id_, name, desc, check, icon, arc="both", hidden=False, stat="", goal=0, area="", hint=""):
    A.append({"id": id_, "api": "ACH_" + id_.upper(), "name": name, "desc": desc, "hidden": hidden,
              "hint": hint or ("A secret. Keep exploring." if hidden else ""), "arc": arc, "area": area,
              "stat": stat, "goal": goal, "check": check, "src": CHECK_KINDS[check["k"]],
              "icon": "ach_" + id_, "icon_prompt": icon})


# --- A1 farming (s1_03-02) ---
ach("first_harvest", "First Sprout", "Harvest your first crop.", {"k": "grown", "n": 1}, "a small green sprout with a single ripe radish", area="farm")
ach("harvest_500", "Bumper Crop", "Harvest 500 crops.", {"k": "grown", "n": 500}, "an overflowing wooden crate of vegetables", stat="crops_harvested", goal=500, area="farm")
ach("gold_star", "Gold Standard", "Harvest a gold-star crop.", {"k": "gold"}, "a golden pumpkin with a shining star", area="farm")
# --- A2 hearts and romance (s1_03-03) ---
ach("best_friends", "Best of Friends", "Reach 10 hearts with a villager.", {"k": "hearts", "h": 10, "n": 1}, "two hearts linked side by side", area="hearts")
ach("beloved", "Beloved", "Reach 5 hearts with 10 different villagers.", {"k": "hearts", "h": 5, "n": 10}, "a ring of ten small hearts", stat="friends_5", goal=10, area="hearts")
ach("sweethearts", "Sweethearts", "Start dating someone special.", {"k": "flag_prefix", "p": "dating_", "n": 1}, "a bouquet of flowers tied with a ribbon", area="hearts")
ach("wedding_bells", "Wedding Bells", "Get married.", {"k": "flag", "f": "married"}, "two golden bells with a bow", area="hearts")
# --- A3 campaigns (s1_03-04) ---
ach("first_victory", "First Victory", "Win a campaign battle.", {"k": "wins", "n": 1}, "a small banner planted on a hill", area="battle")
ach("way_is_open", "The Way Is Open", "Win a whole campaign and open a new region.", {"k": "won", "ids": CAMP_BOTH + CAMP_PENG + CAMP_GANG, "n": 1}, "an open wooden gate with a road beyond", area="battle")
ach("six_fronts", "Six Fronts", "Win all six campaigns both stories share.", {"k": "won", "ids": CAMP_BOTH, "n": len(CAMP_BOTH)}, "six small banners in a fan", stat="shared_campaigns", goal=len(CAMP_BOTH), area="battle")
ach("crystal_commander", "Crystal Commander", "Win every campaign in the penguins' story, colonies included.", {"k": "won", "ids": CAMP_PENG, "n": len(CAMP_PENG)}, "a blue crystal crown over crossed banners", arc="penguins", stat="penguin_campaigns", goal=len(CAMP_PENG), area="battle")
# --- A4 arcade (s1_03-05) ---
ach("arcade_regular", "Arcade Regular", "Play every arcade cabinet at least once.", {"k": "arcade", "ms": "all_games"}, "a little arcade cabinet with a joystick", area="arcade")
ach("jumper_champion", "Block Jumper Champion", "Clear all eight Block Jumper levels.", {"k": "arcade", "ms": "jumper_8"}, "a pixel block hero jumping over a flag", area="arcade")
# --- A5 community farm (s1_03-06) ---
ach("breaking_ground", "Breaking Ground", "Clear the land for the community farm.", {"k": "cf_stage", "n": 1}, "a shovel in fresh soil", area="commons")
ach("market_day", "Market Day", "Finish every stage of the community farm, up to the harvest market.", {"k": "cf_stage", "n": 8}, "a striped market stall with produce", stat="cf_stages", goal=8, area="commons")
# --- A6 collections (s1_03-07) ---
ach("hall_of_wonders", "Hall of Wonders", "Complete the museum.", {"k": "claimed", "id": "mus_all"}, "a small museum with columns and a star", area="collections")
ach("master_angler", "Master Angler", "Catch every fish a rod can find.", {"k": "claimed", "id": "fish_all"}, "a fishing rod with a big fish", area="collections")
ach("legend_of_the_lake", "Legend of the Lake", "Catch the legendary koi.", {"k": "caught_legend"}, "a glowing golden koi leaping", hidden=True, hint="A secret of the lake.", area="collections")
# --- A7 secrets (s1_03-08) ---
ach("finders_keepers", "Finders Keepers", "Open a hidden chest.", {"k": "secrets", "p": ["secret_chest_", "hidden_chest_"], "n": 1}, "a small treasure chest half open with sparkles", area="secrets")
ach("wayfarers_journal", "The Wayfarer's Journal", "Find every page of the Wayfarer's Journal.", {"k": "flag", "f": "journal_done"}, "an old leather journal with loose pages", area="secrets")
ach("off_the_path", "Off the Beaten Path", "Find a hidden nook.", {"k": "flag_prefix", "p": "hidden_open_", "n": 1, "or": "hidden_way_"}, "a vine curtain parting to show a cave", hidden=True, area="secrets")
ach("heart_of_the_mountain", "Heart of the Mountain", "Reach the very bottom of the mine.", {"k": "flag", "f": "hollow_heart_open"}, "a glowing crystal heart in dark rock", hidden=True, area="secrets")
# --- A8 ranching (s1_03-09) ---
ach("new_arrival", "New Arrival", "Welcome your first farm animal.", {"k": "ranch_any"}, "a little barn with a happy chick", area="ranch")
ach("growing_family", "Growing Family", "Have a baby born or an egg hatch on your ranch.", {"k": "ranch_baby"}, "a cracked egg with a fluffy chick", area="ranch")
ach("one_in_a_million", "One in a Million", "Raise a rare-coloured animal.", {"k": "ranch_rare"}, "a sparkly rainbow-coloured lamb", hidden=True, area="ranch")
ach("blue_ribbon", "Blue Ribbon", "Win first place at the fair's animal show.", {"k": "show_blue"}, "a blue prize ribbon rosette", area="ranch")
# --- A9 decor (s1_03-10) ---
ach("making_it_home", "Making It Home", "Collect 25 different pieces of home decor.", {"k": "decor", "n": 25}, "a cosy armchair with a lamp", stat="decor_pieces", goal=25, area="decor")
ach("matching_set", "Matching Set", "Complete a decor set from the catalogue.", {"k": "sets", "n": 1}, "three matching tea cups on a tray", area="decor")
# --- A10 penguin story (s1_03-11) ---
ach("the_farm_goes_on", "The Farm Goes On", "Finish the penguins' story.", {"k": "flag_any", "f": ["epilogue_done", "st_p5_epilogue"]}, "two little penguins waving at a sunrise farm", arc="penguins", area="story")
ach("lights_of_the_isles", "Lights of the Isles", "Wake all four merkitty colonies.", {"k": "colonies", "n": 4}, "four little lighthouses glowing on islands", arc="penguins", stat="colonies_saved", goal=4, area="story")
ach("a_heart_for_the_knight", "A Heart for the Knight", "Choose mercy for the Crystal Knight.", {"k": "flag", "f": "st_p3_knight_mercy_after"}, "a crystal helmet with a small heart", arc="penguins", hidden=True, area="story")
ach("over_the_moon", "Over the Moon", "Bring the moon cow home.", {"k": "ranch_gift", "key": "moon:cow"}, "a white cow floating by a crescent moon", arc="penguins", hidden=True, area="story")
# --- B gangster arc (s1_04-02..06) ---
ach("g_first_crew", "Strength in Numbers", "Recruit your first crew member.", {"k": "crew", "n": 1}, "two silhouettes doing a fist-bump", arc="gangsters", area="crew")
ach("g_full_crew", "The Whole Family", "Recruit all twelve crew members.", {"k": "crew", "n": 12}, "a row of twelve tiny hats", arc="gangsters", stat="crew_recruited", goal=12, area="crew")
ach("g_loyal", "Ride or Die", "Finish a crew member's loyalty favour.", {"k": "flag_prefix", "p": "mission_", "n": 1}, "a handshake with a small heart", arc="gangsters", area="crew")
ach("g_all_loyal", "Thick as Thieves", "Finish every crew member's loyalty favour.", {"k": "flag_prefix", "p": "mission_", "n": 12}, "an intertwined rope knot", arc="gangsters", stat="loyalty_done", goal=12, area="crew")
ach("g_first_turf", "On the Map", "Clear a district block and hold it.", {"k": "turf", "n": 1}, "a map pin on a city block", arc="gangsters", area="turf")
ach("g_all_turf", "Every Block", "Hold all four district blocks at once.", {"k": "turf", "n": 4}, "a four-block city map all lit up", arc="gangsters", stat="turf_held", goal=4, area="turf")
ach("g_all_heists", "Nobody Got Hurt", "Pull off all three heists.", {"k": "flag_prefix", "p": "heist_", "n": 3, "only": ["heist_cannery", "heist_arcade", "heist_vault"]}, "an open safe door with a sparkle", arc="gangsters", stat="heists_done", goal=3, area="turf")
ach("g_squeaky", "Squeaky Clean", "Wash $10,000 in face value at the laundromat in one save.", {"k": "washed", "n": 10000}, "soap bubbles over a banknote", arc="gangsters", area="racket")
ach("g_good_neighbour", "Good Neighbour", "Turn down or give back every shop offered to you.", {"k": "shops_clean"}, "a shop awning with a key and a heart", arc="gangsters", area="racket")
ach("g_going_home", "Going Home", "Send one of the Marked home.", {"k": "marked_free", "n": 1}, "a door opening onto a sunrise", arc="gangsters", area="marked")
ach("g_none_left", "Nobody Left Behind", "Every one of the Marked went home.", {"k": "marked_free", "n": 10}, "a row of houses with lit windows", arc="gangsters", stat="marked_home", goal=10, area="marked")
ach("g_first_lt", "First Lieutenant", "Beat a lieutenant in the Lieutenant Cities.", {"k": "flag_prefix", "p": "lt_", "n": 1, "only": ["lt_" + x for x in LIEUTENANTS]}, "a chess knight piece gently tipped over", arc="gangsters", area="marked")
ach("g_all_lt", "Up the Ladder", "Beat all eight lieutenants.", {"k": "flag_prefix", "p": "lt_", "n": len(LIEUTENANTS), "only": ["lt_" + x for x in LIEUTENANTS]}, "a ladder with eight rungs and a star on top", arc="gangsters", stat="lieutenants_beaten", goal=len(LIEUTENANTS), area="marked")
ach("g_top_floor", "Top Floor", "Beat the President on his own red carpet.", {"k": "flag", "f": "boss_president"}, "a tower top with an empty grand chair", arc="gangsters", hidden=True, area="marked")
ach("g_wired", "Wired", "Build all three chrome stations.", {"k": "built", "ids": ["terminal", "clinic", "robotics"], "t": 1}, "a circuit plug with a lightning bolt", arc="gangsters", area="cyber")
ach("g_the_hive", "The Hive", "Upgrade the Robotics Bench all the way.", {"k": "built", "ids": ["robotics"], "t": 4}, "a hexagon hive of tiny friendly drones", arc="gangsters", area="cyber")
ach("g_streets", "Street by Street", "Win all five city campaigns.", {"k": "won", "ids": CAMP_GANG, "n": len(CAMP_GANG)}, "five street signs fanned out", arc="gangsters", stat="gang_campaigns", goal=len(CAMP_GANG), area="battle")
ach("g_gilt", "Gilt Edge", "Reach Gilt City.", {"k": "regions", "ids": ["giltcity"], "n": 1}, "a golden city skyline", arc="gangsters", area="world")
ach("g_clean_break", "A Clean Break", "End the story with no heat, every Marked sent home and no shop left taken.", {"k": "flag", "f": "ending_clean"}, "a broken chain turning into a bird", arc="gangsters", hidden=True, area="story")
# --- co-op (s1_04-07, 04-19) ---
ach("co_together", "Better Together", "Play together with a friend.", {"k": "net_online"}, "two hands holding one seedling", area="coop")
ach("co_host", "Open House", "Host a friend on your farm.", {"k": "net_host", "n": 1}, "an open front door with a welcome mat", area="coop")
ach("co_full_house", "Full House", "Play with three friends at once.", {"k": "net_peers", "n": 3}, "four little tents around a campfire", area="coop")
ach("co_crossover", "Two Stories, One Farm", "Play together with a friend on the other path.", {"k": "net_mixed"}, "a penguin crown and a fedora on one fence post", area="coop")
# --- late game (s1_04-08) ---
ach("l_second_spring", "Second Spring", "Reach spring of year two.", {"k": "year", "n": 2}, "a cherry blossom branch with two buds", area="late")
ach("l_wide_world", "Wide World", "Visit every far region your path can reach.", {"k": "regions", "ids_peng": MEGA_PENG, "ids_gang": MEGA_GANG, "n": 0}, "a compass rose over a tiny globe", stat="regions_seen", goal=len(MEGA_GANG), area="late")
ach("l_two_paths", "Two Paths", "Finish the story on both paths.", {"k": "arcs", "n": 2}, "a fork in a road with two signposts", stat="arcs_finished", goal=2, area="late")
ach("l_every_ending", "Every Ending", "See all five endings across your saves.", {"k": "endings", "n": len(ENDINGS)}, "five little stars in a row over a book", hidden=True, stat="endings_seen", goal=len(ENDINGS), area="late")
ach("l_fortune", "Fortune", "Earn 100,000 in one save.", {"k": "earned", "n": 100000}, "a tall stack of golden coins", area="late")

# Steam INT stats (window "max" = only ever raised; s1_04-09, s1_05-08).
STATS = {
    "crops_harvested": 100000, "friends_5": 60, "shared_campaigns": len(CAMP_BOTH),
    "penguin_campaigns": len(CAMP_PENG), "cf_stages": 8, "decor_pieces": 1000,
    "colonies_saved": 4, "crew_recruited": 12, "loyalty_done": 12, "turf_held": 4,
    "heists_done": 3, "marked_home": 10, "lieutenants_beaten": len(LIEUTENANTS),
    "gang_campaigns": len(CAMP_GANG), "regions_seen": max(len(MEGA_PENG), len(MEGA_GANG)),
    "arcs_finished": 2, "endings_seen": len(ENDINGS),
}

BANNED = re.compile(r"\b(kill|killed|murder|blood|drug|drunk|drink|beer|wine|gamble|jackpot|bet)\b", re.I)


def check():
    errs = []
    ids = set()
    apis = set()
    if not 40 <= len(A) <= 100:
        errs.append("achievement count %d outside 40..100" % len(A))
    for a in A:
        if a["id"] in ids or a["api"] in apis:
            errs.append("duplicate " + a["id"])
        ids.add(a["id"])
        apis.add(a["api"])
        if not re.fullmatch(r"ACH_[A-Z0-9_]+", a["api"]):
            errs.append("bad api " + a["api"])
        if len(a["name"]) > 30:
            errs.append("name too long " + a["id"])
        if BANNED.search(a["name"] + " " + a["desc"]):
            errs.append("banned word in " + a["id"])
        if a["stat"] and (a["stat"] not in STATS or STATS[a["stat"]] < a["goal"]):
            errs.append("bad stat " + a["id"])
        if a["arc"] not in ("both", "penguins", "gangsters"):
            errs.append("bad arc " + a["id"])
    return errs


PRESENCE = {
    "_": "Steam rich presence (English). Upload as the app's rich presence localization file: "
         "tokens are '#'+key. Built by tools/gen_achievements.py; Presence (scripts/presence.gd) picks one.",
    "tokens": {
        "Menu": "In the menus",
        "Farm": "Tending the farm (%season%, year %year%)",
        "Home": "At home",
        "Town": "In town",
        "Mines": "Exploring the mines",
        "Region": "Exploring %place%",
        "Battle": "Leading a campaign battle",
        "Fishing": "Fishing",
        "Arcade": "At the arcade",
        "Bowling": "Bowling at the Rec Center",
        "Casino": "Playing cards at the casino",
        "Hideout": "At the hideout",
        "Coop": "Playing together (%size% players)",
    },
    "scene_map": {
        "farm": "Farm", "house": "Home", "interior": "Home", "town": "Town", "uptown": "Town",
        "neon": "Town", "docks": "Town", "mine": "Mines", "underground": "Mines", "hideout": "Hideout",
        "rec_center": "Bowling", "arcade": "Arcade", "casino": "Casino",
    },
    "group_size_key": "steam_player_group_size",
}


def main():
    errs = check()
    if errs:
        print("\n".join(errs))
        sys.exit(1)
    out = {
        "_": "Generated by tools/gen_achievements.py (S1 P2). Never edit by hand. Steam API name = api; "
             "icons ach_<id> (art/gen/ach); hidden = Steam Spoiler; stats are Steam INT stats, only ever raised.",
        "sheet_style": SHEET_STYLE,
        "list": A,
        "stats": {k: {"type": "INT", "min": 0, "max": v, "window": "max"} for k, v in STATS.items()},
        "endings": ENDINGS,
        "regions": {"penguins": MEGA_PENG, "gangsters": MEGA_GANG},
    }
    with open(os.path.join(DATA, "achievements.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
        f.write("\n")
    with open(os.path.join(DATA, "rich_presence.json"), "w", encoding="utf-8") as f:
        json.dump(PRESENCE, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print("gen_achievements: %d achievements, %d stats" % (len(A), len(STATS)))


if __name__ == "__main__":
    main()
