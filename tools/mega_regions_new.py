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
     "entry": {"scene": "beach", "cell": [24, 14], "prop": "cart_covered", "label": "the sand-sailors' caravan"},
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
     "entry": {"scene": "mountain", "cell": [7, 35], "prop": "veh_crystal_sled_side", "label": "the sled run up to Frostpeak"},
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
     "entry": {"scene": "meadow", "cell": [42, 24], "prop": "veh_balloon", "label": "Captain Zephyr's balloon"},
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
