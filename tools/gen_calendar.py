#!/usr/bin/env python3
"""C15 P1: writes data/calendar.json, the calendar's own rows (markets, small events,
year-2+ events) next to P6's data/festivals.json (festivals, holidays, marina rows).
Read at runtime by scripts/calendar.gd (class Calendar); ids also present in
festivals.json are ignored there, so P6's rows always win. Row format = C15 contract:
{id, season, day, kind, arc, name, name_gang, venue{scene}, hours, closes_shops,
 year_min, every, needs, icon, line, line_gang}. Runs in tools/regen_data.sh.
Rules: no event shares a day with a plaza festival day used by the classic calendar
(14) or the proposed P6 days; markets drop themselves on festival days at runtime.
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "calendar.json")
SEASONS = ["spring", "summer", "fall", "winter"]


def row(id, season, day, kind, name, line, arc="both", name_gang="", line_gang="", scene="town",
        hours="day", year_min=1, every=1, icon="music", needs=None):
    r = {"id": id, "season": season, "day": day, "kind": kind, "arc": arc, "name": name,
         "venue": {"scene": scene}, "hours": hours, "closes_shops": False,
         "year_min": year_min, "every": every, "icon": icon, "line": line}
    if name_gang:
        r["name_gang"] = name_gang
    if line_gang:
        r["line_gang"] = line_gang
    if needs:
        r["needs"] = needs
    return r


ROWS = []
# Market days at the Commons (once it is restored): the 7th, 21st and 28th.
for se in SEASONS:
    for d in (7, 21, 28):
        if se == "winter" and d == 28:
            continue  # Year's End
        ROWS.append(row("market_%s_%d" % (se, d), se, d, "market", "Market Day",
                        "Market stalls at the Commons, nine till two.", name_gang="Street Market",
                        line_gang="Street market at the Commons lot, nine till two.",
                        scene="commons", hours=[9, 14], icon="market", needs={"commons": True}))

# Small events (no shop closing), both arcs, some year-2+ only.
ROWS += [
    # SPRING
    row("seed_swap", "spring", 5, "event", "Seed Swap", "Bring spare seeds to the plaza and trade for something new.",
        name_gang="Seed Swap at the Docks", line_gang="Crates of spare seeds change hands on the docks all morning.",
        hours="morning", icon="flower"),
    row("kite_day", "spring", 10, "event", "Kite Day", "Kites over the hill north of town all afternoon.",
        arc="penguins", hours=[12, 18], year_min=2, icon="kite"),
    row("kite_wars", "spring", 20, "event", "Rooftop Kite Wars", "",
        arc="gangsters", line_gang="Crews fly kites off the rooftops: last kite up wins bragging rights.",
        hours=[12, 18], year_min=2, icon="kite"),
    # SUMMER
    row("beach_cleanup", "summer", 11, "event", "Beach Cleanup Day", "Help tidy the beach: shells and driftwood make good trades.",
        arc="penguins", scene="beach", hours="morning", icon="fish"),
    row("street_art_jam", "summer", 18, "event", "Street Art Jam", "",
        arc="gangsters", line_gang="Paint the underpass: the best wall gets a spot in the Hideout.",
        hours=[10, 18], icon="music"),
    row("meteor_watch", "summer", 25, "event", "Meteor Watch", "Stay up late: shooting stars after dark, make a wish.",
        name_gang="Rooftop Meteor Watch", line_gang="Up on the roof after dark: shooting stars over the skyline.",
        hours="night", year_min=2, icon="moon"),
    # FALL
    row("apple_day", "fall", 9, "event", "Apple Picking Day", "The orchard trees are heavy: pick a basket on the hill.",
        arc="penguins", hours="day", icon="pumpkin"),
    row("scrap_swap", "fall", 9, "event", "Scrap Swap", "",
        arc="gangsters", line_gang="Swap meet behind the docks: parts, tools and odd finds.",
        hours="day", icon="market"),
    row("founders_day", "fall", 26, "event", "Founders' Day", "Every second year the town remembers its founders with a picnic on the plaza.",
        name_gang="Founders' Night", line_gang="Every second year the old crews raise a toast of soda to the founders.",
        hours="day", year_min=2, every=2, icon="firework"),
    # WINTER
    row("ice_fishing", "winter", 7, "event", "Ice Fishing Day", "The lake is frozen hard: fish through the ice all day.",
        name_gang="Ice Fishing Day", line_gang="The harbour edge has frozen: fishing holes all along the pier.",
        scene="beach", hours="day", icon="fish"),
    row("snowball_day", "winter", 13, "event", "Snowball Saturday", "Snowball fights in the park: soft snow, big laughs.",
        name_gang="Snowball Turf War", line_gang="Snowball turf war in the park: soft snow, no hard feelings.",
        hours=[10, 16], icon="snow"),
    row("snow_sculpture", "winter", 21, "event", "Snow Sculpture Contest", "Build the best snow sculpture on the plaza.",
        name_gang="Ice Sculpture Night", line_gang="Ice sculptures under the neon: best one wins.",
        hours="day", year_min=2, icon="snow"),
]


def main():
    ids = [r["id"] for r in ROWS]
    assert len(ids) == len(set(ids)), "duplicate calendar ids"
    for r in ROWS:
        assert r["season"] in SEASONS and 1 <= r["day"] <= 28, r["id"]
        assert r["day"] != 14, "day 14 is the plaza festival: %s" % r["id"]
    with open(OUT, "w") as f:
        json.dump({"rows": ROWS}, f, indent=1)
        f.write("\n")


if __name__ == "__main__":
    main()
