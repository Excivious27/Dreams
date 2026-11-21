#!/usr/bin/env python3
"""C15 P6: the festival year -> data/festivals.json (contract row format, C15_CONTRACT.md section 1).

Every season, both arcs: 2+ festivals and 1+ holiday (plus year-gated rows from year 2/3 and the
marina festivals, which need a marina tier). Calendar (scripts/calendar.gd, P1) merges these rows with
calendar.json; town.gd plays the festival through `handler`. No festival day falls on a villager
birthday (tools/festival_calendar_test.gd checks it against data/npcs.json).

Row: {id, season, day, kind, arc, name, name_gang, venue{scene, cell}, hours, closes_shops, year_min,
every, weather, host, host_gang, handler, stall, prize_pool, music, music_fallback, needs{marina_tier, flag},
line, line_gang, icon}.
hours: "day" 9-18 | "evening" sunset-4..sunset+3.5 | "night" sunset..sunset+4 | "allday".
music: "festival_<id>" (song to make after Dec 1, docs/ART-QUEUE.md); music_fallback: an existing song.
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PLAZA = {"scene": "town", "cell": [40, 50]}
PARK = {"scene": "town", "cell": [12, 41]}
MAZE = {"scene": "town", "cell": [51, 6]}
BEACH = {"scene": "beach", "cell": [30, 20]}
FARM = {"scene": "farm", "cell": [20, 20]}


def row(id, season, day, kind, name, name_gang, venue, hours, host, host_gang, line, line_gang,
        closes_shops=None, arc="both", year_min=1, every=1, weather="", handler=None, music_fallback=None,
        marina_tier=0, flag="", icon=""):
    if closes_shops is None:
        closes_shops = kind == "festival" and venue["scene"] == "town"
    if music_fallback is None:
        music_fallback = "festival_night" if hours in ("evening", "night") else "festival"
    return {
        "id": id, "season": season, "day": day, "kind": kind, "arc": arc, "name": name, "name_gang": name_gang,
        "venue": venue, "hours": hours, "closes_shops": closes_shops, "year_min": year_min, "every": every,
        "weather": weather, "host": host, "host_gang": host_gang, "handler": handler or id,
        "stall": "festival_" + id, "prize_pool": "festival_%s_prize" % id, "music": "festival_" + id,
        "music_fallback": music_fallback, "needs": {"marina_tier": marina_tier, "flag": flag},
        "line": line, "line_gang": line_gang, "icon": icon or ("holiday" if kind == "holiday" else kind),
    }


ROWS = [
    # SPRING
    row("planting_day", "spring", 1, "holiday", "Planting Day", "Fresh Start", FARM, "allday", "Hazel", "Halo",
        "Planting Day: a free seed packet in the mail and Gideon's seeds are cheaper today.",
        "Fresh Start: an envelope and a seed bag left at the Hideout door. New season, clean slate."),
    row("egg", "spring", 14, "festival", "Egg Festival", "Stash Hunt", PLAZA, "day", "Alder", "Halo",
        "Egg Festival on the plaza: the egg hunt, the Best Egg table and spring treats.",
        "Stash Hunt on the plaza: twelve envelopes hidden, and the kids are fast.", music_fallback="festival_egg"),
    row("blossom", "spring", 24, "festival", "Blossom Dance", "Rooftop Bloom", PARK, "evening", "Posy", "Halo",
        "Blossom Dance in the park: ask a partner, follow the steps under the petals.",
        "Rooftop Bloom in the park: string lights, a DJ booth and a dance circle.", weather="petals"),
    # SUMMER
    row("longest_day", "summer", 1, "holiday", "Longest Day", "Longest Day", FARM, "allday", "Marlowe", "Marlowe",
        "Longest Day: the sun stays up an hour later tonight.",
        "Longest Day: the streetlights come on late tonight."),
    row("founders", "summer", 7, "festival", "Founders' Day", "Turf Day", PLAZA, "day", "Theo", "Halo",
        "Founders' Day parade on the plaza: the town's anniversary, floats and a history talk.",
        "Turf Day: the crew's anniversary. A drumline, a float and a long table on the plaza.", year_min=2),
    row("lantern", "summer", 14, "festival", "Lantern Festival", "River Lights", PLAZA, "evening", "Lumi", "Halo",
        "Lantern Festival: float your lantern down the river at dusk.",
        "River Lights: float a light down the river at dusk and keep it off the snags.", music_fallback="festival_lantern"),
    row("regatta", "summer", 18, "marina", "Regatta", "Harbour Lights", {"scene": "beach", "cell": [30, 12]}, "day", "Roz", "Roz",
        "Regatta at the marina: three legs round the buoys, bunting on every mast.",
        "Harbour Lights on the boardwalk: neon stalls and a ring toss.", marina_tier=3),
    row("tide_feast", "summer", 24, "festival", "Tide Feast", "Boardwalk Block Party", BEACH, "day", "Ines", "Ines",
        "Tide Feast on the beach: add one dish to the big pot and see what the town thinks.",
        "Boardwalk Block Party: put one thing on the crew grill and hear the verdict.", closes_shops=True),
    row("moon_jellies", "summer", 27, "festival", "Moon Jellies", "Neon Tide", {"scene": "beach", "cell": [30, 8]}, "night", "Marlowe", "Marlowe",
        "Moon Jellies: at night the glowing jellies drift past the pier.",
        "Neon Tide: the glow buoys light up the bay tonight.", year_min=2, music_fallback="festival_night_2"),
    # FALL
    row("cider_day", "fall", 1, "holiday", "Cider Pressing Day", "Payday", FARM, "allday", "Hazel", "Halo",
        "Cider Pressing Day: Hazel presses apples for the whole town (fresh juice, for everyone).",
        "Payday: the crew squares up. A little extra in your envelope today."),
    row("derby", "fall", 9, "marina", "Fishing Derby", "Fishing Derby", {"scene": "beach", "cell": [30, 12]}, "day", "Ines", "Ines",
        "Fishing Derby: biggest fish on the pier by 2pm wins. Ines is judging.",
        "Fishing Derby: biggest catch by 2pm takes the pot.", marina_tier=2),
    row("harvest", "fall", 14, "festival", "Harvest Fair", "Street Fair", PLAZA, "day", "Alder", "Halo",
        "Harvest Fair: enter your best crop, the Animal Show and fall treats.",
        "Street Fair: food carts, the produce contest and the show pen."),
    row("hollow", "fall", 27, "festival", "Hollow Night", "Masquerade Alley", MAZE, "night", "Theo", "Halo",
        "Hollow Night: lantern maze, treats at the cottage doors and a costume contest.",
        "Masquerade Alley: masks on, a lantern walk and a masquerade judged by the crew.", weather="leaves"),
    # WINTER
    row("first_frost", "winter", 1, "holiday", "First Frost", "First Frost", FARM, "allday", "Bram", "Halo",
        "First Frost: the town lights its windows and Bram's cocoa is half price.",
        "First Frost: the block lights its windows. Hot cocoa on the house at the Hideout."),
    row("winter_market", "winter", 10, "festival", "Winter Market", "Night Market", PLAZA, "evening", "Maple", "Halo",
        "Winter Market: guest stalls on the plaza and a snow-sculpt contest.",
        "Night Market: neon stalls down the plaza and a snow-sculpt contest.", closes_shops=False),
    row("star", "winter", 14, "festival", "Star Festival", "Rooftop Wishes", PLAZA, "evening", "Alder", "Halo",
        "Star Festival: the gift swap and one star-wish under the sky.",
        "Rooftop Wishes: one gift each, one wish under the sky.", music_fallback="festival_star"),
    row("longest_night", "winter", 21, "holiday", "Longest Night", "Longest Night", FARM, "allday", "Theo", "Halo",
        "Longest Night: the darkest night of the year. Lamps in every window.",
        "Longest Night: the darkest night of the year. The block keeps its lights on."),
    row("comet", "winter", 21, "festival", "Comet Night", "Blackout Night", FARM, "night", "Theo", "Halo",
        "Comet Night: once every three years, crystals fall over the farm.",
        "Blackout Night: the city's power goes out and the stars come back.", every=3, year_min=3,
        closes_shops=False, music_fallback="festival_night_2"),
    row("gift_swap", "winter", 28, "festival", "Gift Swap Feast", "Gilt Gala", PLAZA, "evening", "Alder", "Halo",
        "Gift Swap Feast: bring a gift for your secret partner and the year's-end speech.",
        "Gilt Gala: black tie, chips only, a secret gift and the year's-end toast."),
]


def main():
    seen = set()
    for r in ROWS:
        assert r["id"] not in seen, r["id"]
        seen.add(r["id"])
        assert 1 <= r["day"] <= 28 and r["season"] in ("spring", "summer", "fall", "winter")
    out = {"_note": "Generated by tools/gen_festivals.py (C15 P6). Do not edit by hand.", "festivals": ROWS}
    path = os.path.join(ROOT, "data", "festivals.json")
    text = json.dumps(out, indent=1, ensure_ascii=False) + "\n"
    old = open(path).read() if os.path.exists(path) else ""
    if old != text:
        with open(path, "w") as f:
            f.write(text)
    print("gen_festivals: %d rows" % len(ROWS))


if __name__ == "__main__":
    main()
