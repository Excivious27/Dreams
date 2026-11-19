#!/usr/bin/env python3
"""Round 13 mega regions, part 2: the six NEW mega regions (the contract list).

REGIONS is what the world-map framework (tools/gen_mega_regions.py, data/mega_regions.json)
imports: one entry per mega region with its areas, how you get in and when it opens.
The playable content (layouts, foes, items, quests...) is built from these ids by
tools/gen_mega_new.py, which also writes data/mega_travel.json for MegaTravel.

Fields
  id       mega region id (also the map-tab id)
  name     shown on the tab
  arc      "both" | "penguins" | "gangsters"
  theme    one word for the look (snow, desert, gloam, sky, rail, gilt)
  entry    {"scene", "cell", "prop", "label"}: the travel point in the home world
  unlock   {"tier": story chapters done (GameState.progress_tier()), "quest": hook quest id,
            "flag": set once the way is open}
  hub      the area you arrive in
  areas    [{"id", "scene", "name", "links": [area ids], "tier", "hub": bool}]
  color    tab colour
"""

REGIONS = [
    {"id": "gloamwood", "name": "Gloamwood", "arc": "both", "theme": "gloam", "color": "7a5ab8",
     "entry": {"scene": "forest", "cell": [26, 41], "prop": "fairy_ring", "label": "step into the fairy ring"},
     "unlock": {"tier": 1, "quest": "mega_gloamwood_hook", "flag": "mega_gloamwood_open"},
     "hub": "gloam_lanternfall",
     "areas": [
         {"id": "gloam_lanternfall", "scene": "gloam_lanternfall", "name": "Lanternfall", "links": ["gloam_violet_glade", "gloam_crystal_thicket"], "tier": 2, "hub": True},
         {"id": "gloam_violet_glade", "scene": "gloam_violet_glade", "name": "Violet Glade", "links": ["gloam_lanternfall", "gloam_moonpool"], "tier": 2},
         {"id": "gloam_crystal_thicket", "scene": "gloam_crystal_thicket", "name": "Crystal Thicket", "links": ["gloam_lanternfall"], "tier": 3},
         {"id": "gloam_moonpool", "scene": "gloam_moonpool", "name": "The Moonpool", "links": ["gloam_violet_glade"], "tier": 3},
     ]},
    {"id": "sunscorch", "name": "Sunscorch Expanse", "arc": "both", "theme": "desert", "color": "d8a048",
     "entry": {"scene": "beach", "cell": [24, 14], "prop": "ds_sand_caravan", "label": "the sand-sailors' caravan"},
     "unlock": {"tier": 2, "quest": "mega_sunscorch_hook", "flag": "mega_sunscorch_open"},
     "hub": "desert_mirage_post",
     "areas": [
         {"id": "desert_mirage_post", "scene": "desert_mirage_post", "name": "Mirage Post", "links": ["desert_dune_sea", "desert_glass_canyon"], "tier": 3, "hub": True},
         {"id": "desert_dune_sea", "scene": "desert_dune_sea", "name": "The Dune Sea", "links": ["desert_mirage_post"], "tier": 3},
         {"id": "desert_glass_canyon", "scene": "desert_glass_canyon", "name": "Glass Canyon", "links": ["desert_mirage_post", "desert_sunken_temple"], "tier": 3},
         {"id": "desert_sunken_temple", "scene": "desert_sunken_temple", "name": "Sunken Temple", "links": ["desert_glass_canyon"], "tier": 4},
     ]},
    {"id": "ironline", "name": "Ironline Frontier", "arc": "gangsters", "theme": "rail", "color": "8a6a4a",
     "entry": {"scene": "town", "cell": [50, 4], "prop": "ticket_booth", "label": "the night train booth"},
     "unlock": {"tier": 2, "quest": "mega_ironline_hook", "flag": "mega_ironline_open"},
     "hub": "iron_junction",
     "areas": [
         {"id": "iron_junction", "scene": "iron_junction", "name": "Junction City", "links": ["iron_freight_yards", "iron_mill_district"], "tier": 3, "hub": True},
         {"id": "iron_freight_yards", "scene": "iron_freight_yards", "name": "Freight Yards", "links": ["iron_junction"], "tier": 3},
         {"id": "iron_mill_district", "scene": "iron_mill_district", "name": "Mill District", "links": ["iron_junction", "iron_tunnels"], "tier": 3},
         {"id": "iron_tunnels", "scene": "iron_tunnels", "name": "Coalbrook Tunnels", "links": ["iron_mill_district"], "tier": 4},
     ]},
    {"id": "frostpeak", "name": "Frostpeak Reach", "arc": "both", "theme": "snow", "color": "9ac8e8",
     "entry": {"scene": "mountain", "cell": [7, 35], "prop": "fr_sled_station", "label": "the sled run up to Frostpeak"},
     "unlock": {"tier": 3, "quest": "mega_frostpeak_hook", "flag": "mega_frostpeak_open"},
     "hub": "frost_hearthhold",
     "areas": [
         {"id": "frost_hearthhold", "scene": "frost_hearthhold", "name": "Hearthhold", "links": ["frost_glacier", "frost_caverns", "frost_falls"], "tier": 4, "hub": True},
         {"id": "frost_glacier", "scene": "frost_glacier", "name": "Glacier Fields", "links": ["frost_hearthhold", "frost_summit"], "tier": 4},
         {"id": "frost_caverns", "scene": "frost_caverns", "name": "Rime Caverns", "links": ["frost_hearthhold"], "tier": 4},
         {"id": "frost_falls", "scene": "frost_falls", "name": "Frozen Falls", "links": ["frost_hearthhold"], "tier": 4},
         {"id": "frost_summit", "scene": "frost_summit", "name": "The Summit", "links": ["frost_glacier"], "tier": 5},
     ]},
    {"id": "windward", "name": "Windward Isles", "arc": "penguins", "theme": "sky", "color": "b8d8f8",
     "entry": {"scene": "meadow", "cell": [42, 24], "prop": "wi_mooring_tower", "label": "Captain Zephyr's balloon"},
     "unlock": {"tier": 4, "quest": "mega_windward_hook", "flag": "mega_windward_open"},
     "hub": "wind_breezehaven",
     "areas": [
         {"id": "wind_breezehaven", "scene": "wind_breezehaven", "name": "Breezehaven", "links": ["wind_sunrise_shelf", "wind_storm_shelf"], "tier": 5, "hub": True},
         {"id": "wind_sunrise_shelf", "scene": "wind_sunrise_shelf", "name": "Sunrise Shelf", "links": ["wind_breezehaven"], "tier": 5},
         {"id": "wind_storm_shelf", "scene": "wind_storm_shelf", "name": "Storm Shelf", "links": ["wind_breezehaven", "wind_starfall_garden"], "tier": 5},
         {"id": "wind_starfall_garden", "scene": "wind_starfall_garden", "name": "Starfall Garden", "links": ["wind_storm_shelf"], "tier": 5},
     ]},
    {"id": "giltcity", "name": "Gilt City", "arc": "gangsters", "theme": "gilt", "color": "e8c048",
     "entry": {"scene": "farm", "cell": [40, 31], "spawn": [40, 29], "prop": "limo", "label": "the gold limousine"},
     "unlock": {"tier": 4, "quest": "mega_giltcity_hook", "flag": "mega_giltcity_open"},
     "hub": "gilt_grand_plaza",
     "areas": [
         {"id": "gilt_grand_plaza", "scene": "gilt_grand_plaza", "name": "Grand Plaza", "links": ["gilt_casino_row", "gilt_gardens"], "tier": 5, "hub": True},
         {"id": "gilt_casino_row", "scene": "gilt_casino_row", "name": "Casino Row", "links": ["gilt_grand_plaza", "gilt_vaults"], "tier": 5},
         {"id": "gilt_gardens", "scene": "gilt_gardens", "name": "Gilded Gardens", "links": ["gilt_grand_plaza"], "tier": 5},
         {"id": "gilt_vaults", "scene": "gilt_vaults", "name": "The Vaults", "links": ["gilt_casino_row"], "tier": 5},
     ]},
]

BY_ID = {r["id"]: r for r in REGIONS}

# ---------------------------------------------------------------- map tabs (a5's schema)
# tools/gen_mega_regions.py imports MEGA (five regions of their own) and IRONLINE (areas
# added to the Lieutenant Cities tab: the rail frontier is part of the President's city).
PIN = {"hub": "pin_town"}
MAP = {  # area: (pos on the region map, pin icon, one line)
    "gloam_lanternfall": ([0.45, 0.56], "pin_town", "Lanterns on mushrooms, and a pond that glows."),
    "gloam_violet_glade": ([0.35, 0.31], "pin_forest", "Teal moss, wisps and sleepy moths."),
    "gloam_crystal_thicket": ([0.81, 0.47], "pin_mine", "Crystal trees that ring in the wind."),
    "gloam_moonpool": ([0.44, 0.10], "pin_lake", "Black water, and the Thornmother beneath."),
    "desert_mirage_post": ([0.68, 0.65], "pin_town", "The last well before the Expanse."),
    "desert_dune_sea": ([0.14, 0.53], "pin_wastes", "Dunes, a buried bus, and singing sand."),
    "desert_glass_canyon": ([0.62, 0.33], "pin_mountain", "Red rock and lightning glass."),
    "desert_sunken_temple": ([0.72, 0.08], "pin_tower", "The Sun Colossus guards the door."),
    "frost_hearthhold": ([0.52, 0.68], "pin_town", "Snow-domed houses and a hot spring."),
    "frost_glacier": ([0.50, 0.38], "pin_mountain", "White fields, frost wolves, rime golems."),
    "frost_caverns": ([0.13, 0.53], "pin_mine", "Blue ice caves that hum."),
    "frost_falls": ([0.88, 0.51], "pin_lake", "A waterfall frozen mid-pour; pike below."),
    "frost_summit": ([0.52, 0.10], "pin_mountain", "Where the Rime Wyrm sleeps."),
    "wind_breezehaven": ([0.70, 0.73], "pin_town", "Windmill isles and a penguin captain."),
    "wind_sunrise_shelf": ([0.20, 0.50], "pin_meadow", "Always just sunrise."),
    "wind_storm_shelf": ([0.61, 0.38], "pin_mountain", "Lightning in black cloud."),
    "wind_starfall_garden": ([0.62, 0.10], "pin_moon", "Stars close enough to touch; the Roc's nest."),
    "gilt_grand_plaza": ([0.50, 0.55], "pin_town", "Gold stone, statues, a hundred windows."),
    "gilt_casino_row": ([0.88, 0.43], "pin_tower", "Neon on gold."),
    "gilt_gardens": ([0.14, 0.39], "pin_meadow", "Hedges clipped into crowns."),
    "gilt_vaults": ([0.85, 0.08], "pin_mine", "Madame Aurum's gold, stacked to the ceiling."),
    "iron_junction": ([0.12, 0.40], "pin_town", "Rail town; every train CANCELLED."),
    "iron_freight_yards": ([0.08, 0.16], "pin_docks", "Rail bots and rusting freight."),
    "iron_mill_district": ([0.30, 0.22], "pin_tower", "Brick mills and the Baron's silo."),
    "iron_tunnels": ([0.36, 0.06], "pin_mine", "Old rail tunnels and the Baron's car."),
}
TABS = {  # region: short, style, colours, blurb, travel, leave, how
    "gloamwood": ("Gloam", "cave", [0.12, 0.08, 0.2], [0.42, 0.3, 0.6], [1.0, 0.6, 0.9], [0.95, 0.9, 1.0], "fairy ring",
                  "A forest of lanterns and violet moss, past a fairy ring in the woods.",
                  "The ring hums, the forest folds up like paper, and lanterns bloom around you.",
                  "The ring lets go, and it's plain old daylight in the forest again."),
    "sunscorch": ("Sunscorch", "desert", [0.9, 0.74, 0.45], [0.98, 0.86, 0.6], [0.95, 0.4, 0.25], [0.25, 0.14, 0.08], "sand-sail caravan",
                  "Past the dunes: an oasis post, a glass canyon and a temple with a giant at the door.",
                  "The caravan's sails fill. Three days of gold dunes, then palms and a well: Mirage Post.",
                  "The caravan beaches on your own coast, sand in everything."),
    "frostpeak": ("Frostpeak", "ice", [0.72, 0.84, 0.94], [0.95, 0.97, 1.0], [0.45, 0.95, 0.75], [0.1, 0.16, 0.28], "sled run",
                  "Above the mountain: a snow village, glaciers, ice caves and the Summit.",
                  "The sled climbs past the clouds into white. Smoke from chimneys: Hearthhold.",
                  "The sled shoots down out of the snow, and the valley is green and warm."),
    "windward": ("Windward", "sky", [0.55, 0.75, 0.95], [0.96, 0.97, 1.0], [1.0, 0.85, 0.4], [0.12, 0.16, 0.3], "balloon",
                 "Islands above the sky islands, where the Storm Roc nests.",
                 "The balloon lifts through the last cloud into blue, and islands float by like stepping stones.",
                 "The balloon bumps down in the east meadow. Grass, at last."),
    "giltcity": ("Gilt City", "city", [0.14, 0.11, 0.06], [0.5, 0.42, 0.22], [1.0, 0.85, 0.3], [1.0, 0.95, 0.8], "gold limousine",
                 "Madame Aurum's city of casinos, gardens and vaults.",
                 "The limousine purrs through the night. At dawn: gold stone, statues, and a hundred lit windows.",
                 "The limo drops you at the farm gate and glides away without a sound."),
}

def _area(a):
    pos, icon, blurb = MAP[a["id"]]
    return {"id": a["id"], "name": a["name"], "pos": pos, "icon": icon, "blurb": blurb}

def _links(r):
    out = []
    for a in r["areas"]:
        for b in a["links"]:
            if [b, a["id"]] not in out:
                out.append([a["id"], b])
    return out

def _unlock(r):
    return {"any": [{"seen": r["hub"]}, {"flag": r["unlock"]["flag"]}]}

MEGA = []
for _r in REGIONS:
    if _r["id"] == "ironline":
        continue
    sh, style, bg, land, acc, ink, how, blurb, travel, leave = TABS[_r["id"]]
    MEGA.append({"id": _r["id"], "name": _r["name"], "short": sh, "arc": _r["arc"], "status": "built",
                 "blurb": blurb, "travel": travel, "leave": leave,
                 "theme": {"style": style, "bg": bg, "land": land, "accent": acc, "ink": ink},
                 "areas": [_area(a) for a in _r["areas"]], "links": _links(_r),
                 "entries": [{"from": _r["entry"]["scene"], "to": _r["hub"], "how": how, "label": _r["entry"]["scene"].capitalize()}],
                 "unlock": _unlock(_r), "map_art": "ui/map_" + _r["id"]})

_I = BY_ID["ironline"]
IRONLINE = {"areas": [_area(a) for a in _I["areas"]], "links": _links(_I),
            "entries": [{"from": _I["entry"]["scene"], "to": _I["hub"], "how": "night train", "label": "Town"}],
            "unlock": _unlock(_I)}

# ---------------------------------------------------------------- second areas for converted regions
# Built by gen_mega_new.py like the rest; gen_mega_regions.py adds them to a5's region entries.
EXTRA = [
    {"id": "hollow", "arc": "both", "hub": None, "unlock": {}, "areas": [
        {"id": "hollow_deeps", "scene": "hollow_deeps", "name": "The Glowing Deeps", "links": ["hollow_heart"], "tier": 5,
         "pos": [0.78, 0.36], "icon": "pin_mine", "blurb": "Crystal rivers east of the Heart, where the old miners camped."}]},
    {"id": "sky", "arc": "penguins", "hub": None, "unlock": {}, "areas": [
        {"id": "sky_reaches", "scene": "sky_reaches", "name": "Whale Reaches", "links": ["sky"], "tier": 4,
         "pos": [0.5, 0.14], "icon": "pin_mountain", "blurb": "High cloud where the sky whale circles."}]},
]
# The existing maps these join (they get an exit added): size and the exit side/position on them.
EXTERNAL = {"hollow_heart": {"cols": 76, "rows": 64}, "sky": {"cols": 48, "rows": 42}}
for _e in EXTRA:
    BY_ID[_e["id"]] = _e
