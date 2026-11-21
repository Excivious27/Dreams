#!/usr/bin/env python3
"""Themed battlefields (CONDUCT 3 P4): one field per campaign region, each with
its own ground, border style, scatter theme, landmarks and one of four layout
families (river split, ring, diagonal ridge, open plain). Lanes follow the
objectives (camp -> hub row -> each point). Imported by tools/gen_battles.py,
which calls build(battle, kinds, rprops) inside its battle() section.

campaign_field(region) -> the bf_* field themed for that region (P1 maps every
campaign's nodes to it).
"""

# ---- which field belongs to which campaign region ------------------------------
FIELD_OF = {
    "orchard_hills": "bf_orchard_line", "highlands": "bf_highland_pass", "quarry": "bf_quarry_cut",
    "marsh": "bf_bog_crossing", "riverlands": "bf_river_ford", "ruins": "bf_ruin_court",
    "wastes": "bf_ash_wastes", "sky": "bf_cloud_stair", "station": "bf_station_deck",
    "jungle": "bf_jungle_grove", "colony_coral": "bf_reef_shallows", "colony_kelp": "bf_kelp_beds",
    "colony_ice": "bf_frostfield", "colony_ember": "bf_ash_wastes", "countryside": "bf_rail_yards",
    "docks": "bf_dockside", "neon": "bf_neon_block", "uptown": "bf_uptown_plaza",
    "underground": "bf_sewer_works",
}


def campaign_field(region):
    """The battlefield themed for a campaign region (falls back to the orchard)."""
    return FIELD_OF.get(region, "bf_orchard_line")


# ---- layout families --------------------------------------------------------------
def _lanes(cols, rows, pts, hub_y, extra=()):
    """Lanes (2 wide) from the camp up to a hub row, along it, then up to each point."""
    camp = [p for p in pts if p["owner"] == "ally"][0]
    cx, cy = camp["cell"]
    out = [[cx - 1, hub_y, 2, cy - hub_y]]
    xs = [p["cell"][0] for p in pts if p is not camp]
    x0, x1 = min(xs + [cx]), max(xs + [cx])
    out.append([x0 - 1, hub_y, x1 - x0 + 2, 2])
    for p in pts:
        if p is camp:
            continue
        px, py = p["cell"]
        if py < hub_y:
            out.append([px - 1, py + 1, 2, hub_y - py])
        elif py > hub_y + 2:
            out.append([px - 1, hub_y, 2, py - hub_y])
    return out + [list(e) for e in extra]


def _pt(i, name, x, y, owner):
    return {"id": "abcdef"[i], "name": name, "cell": [x, y], "owner": owner}


def layout(family, cols, rows, seed, names, plateaus=True, water=True):
    """-> (plateaus, water_blobs, points, paths). names: 6 point names, camp last."""
    cx = cols // 2
    camp_y = rows - 11
    s = seed
    P, W = [], []
    if family == "river":
        ry = rows // 2 - 2
        for i, x in enumerate(range(7, cols - 5, 8)):
            W.append({"c": [x, ry + (i % 3) - 1], "r": 6, "seed": s + i})
        pts = [_pt(0, names[0], 22, 25, "enemy"), _pt(1, names[1], cx + 4, 28, "neutral"), _pt(2, names[2], cols - 22, 25, "enemy"),
               _pt(3, names[3], 24, ry + 16, "neutral"), _pt(4, names[4], cols - 24, ry + 16, "neutral"), _pt(5, names[5], cx, camp_y, "ally")]
        P = [{"blobs": [{"c": [22, 24], "r": 9, "seed": s + 20}]}, {"blobs": [{"c": [cols - 22, 24], "r": 9, "seed": s + 21}]}]
        hub = rows - 18
    elif family == "ring":
        my = rows // 2 - 1
        P = [{"blobs": [{"c": [cx, my], "r": 12, "seed": s + 20}, {"c": [cx + 6, my - 4], "r": 6, "seed": s + 21}], "upper": [{"c": [cx, my], "r": 5, "seed": s + 22}]}]
        W = [{"c": [12, my + 2], "r": 4, "seed": s + 1}, {"c": [cols - 12, my - 2], "r": 4, "seed": s + 2}]
        pts = [_pt(0, names[0], 22, 26, "enemy"), _pt(1, names[1], cx, my - 1, "neutral"), _pt(2, names[2], cols - 22, 26, "enemy"),
               _pt(3, names[3], 22, my + 18, "neutral"), _pt(4, names[4], cols - 22, my + 18, "neutral"), _pt(5, names[5], cx, camp_y, "ally")]
        hub = rows - 18
    elif family == "ridge":
        P = [{"blobs": [{"c": [24, 27], "r": 10, "seed": s + 20}, {"c": [32, 22], "r": 6, "seed": s + 21}]},
             {"blobs": [{"c": [50, 40], "r": 8, "seed": s + 22}]},
             {"blobs": [{"c": [72, 52], "r": 8, "seed": s + 23}, {"c": [80, 56], "r": 5, "seed": s + 24}]}]
        W = [{"c": [cols - 18, 42], "r": 6, "seed": s + 1}, {"c": [16, 50], "r": 5, "seed": s + 2}]
        pts = [_pt(0, names[0], 24, 26, "enemy"), _pt(1, names[1], 50, 39, "neutral"), _pt(2, names[2], cols - 20, 26, "enemy"),
               _pt(3, names[3], 28, 58, "neutral"), _pt(4, names[4], 74, 51, "neutral"), _pt(5, names[5], cx, camp_y, "ally")]
        hub = rows - 18
    else:  # plain
        P = [{"blobs": [{"c": [30, 52], "r": 6, "seed": s + 20}]}, {"blobs": [{"c": [cols - 18, 30], "r": 7, "seed": s + 21}]}]
        W = [{"c": [cx - 6, 42], "r": 6, "seed": s + 1}, {"c": [14, 64], "r": 5, "seed": s + 2}, {"c": [cols - 14, 58], "r": 4, "seed": s + 3}]
        pts = [_pt(0, names[0], 20, 27, "enemy"), _pt(1, names[1], cx + 8, 25, "neutral"), _pt(2, names[2], cols - 18, 30, "enemy"),
               _pt(3, names[3], 30, 51, "neutral"), _pt(4, names[4], cols - 30, 56, "neutral"), _pt(5, names[5], cx, camp_y, "ally")]
        hub = rows - 18
    if not plateaus:
        P = []
    if not water:
        W = []
    return P, W, pts, _lanes(cols, rows, pts, hub)


# ---- scatter themes ------------------------------------------------------------------
SNOW = {"trees": ["mid_snowpine", "mid_snowpine_b", "pine_snow"], "rocks": ["rock_snow_m", "rock_snow_s", "rock_snow_l"],
        "logs": False, "bushes": False, "band": ["bush_snow", "rock_snow_s", "bush_bare_snow"]}
STONE = {"trees": [], "rocks": ["boulder_m", "boulder_s", "mrock_stone_0", "mrock_stone_1", "boulder2_m_a"],
         "logs": False, "bushes": False, "band": ["boulder_s", "rock_s", "boulder3_2"]}
CITY = {"trees": [], "rocks": ["props/crates_a", "props/oil_drums", "props/drums"], "logs": False, "bushes": False, "band": []}
LAWN = {"trees": ["props/topiary_a", "props/topiary_b", "props/hedge2_ball"], "rocks": ["props/planter2_0", "props/planter2_1"],
        "logs": False, "bushes": False, "band": ["props/hedge2_ball", "props/hedge2_pot"]}
DECK = {"trees": [], "rocks": ["props/cargo_grey", "props/crates_a"], "logs": False, "bushes": False, "band": []}
SEWER = {"trees": [], "rocks": ["props/pipe_valve", "props/oil_drums", "props/crates_a", "props/grate_a"], "logs": False, "bushes": False, "band": []}
CLOUD = {"trees": ["cloud_tree_a", "cloud_tree_b"], "rocks": ["props/skydeco_0", "props/skydeco_1"], "logs": False, "bushes": False, "band": ["cloud_tree_c"]}
REEF = {"trees": ["palm"], "rocks": ["props/bk_pebbles_m", "props/boulder_s"], "logs": False, "bushes": False,
        "band": ["props/bk_seaweed_a", "props/bk_seaweed_b", "props/bk_shell_conch", "props/bk_starfish_orange"]}
KELP = {"trees": ["mid_willow", "big_willow"], "rocks": ["props/boulder_s"], "logs": True, "bushes": False,
        "band": ["reeds2_0", "reeds2_1", "cattail_1", "props/mk_reeds_2"]}
JUNGLE = {"trees": ["props/mushroom_tree_a", "props/mushroom_tree_b"], "rocks": ["props/jdeco_3", "props/jdeco_5"], "logs": True, "bushes": False,
          "band": ["props/jdeco_0", "props/jdeco_1", "props/jdeco_2"]}
CRYSTAL = {"trees": ["props/crystal_tree", "props/crystal_tree_frost"], "rocks": ["props/crystal_rock", "props/mine_crystal_rock_1", "props/boulder_m"],
           "logs": False, "bushes": False, "band": ["props/ccrystal_1", "props/ccrystal_2", "boulder_s"]}
ASH = {"trees": ["dead_tree_m", "dead_tree_s"], "rocks": ["props/boulder_m", "props/dspike_1"], "logs": False, "bushes": False,
       "band": ["dead_tree_s", "props/dspike_2", "props/boulder_s"]}

BT_SNOW = {"mid": ["mid_snowpine", "mid_snowpine_b", "mid_pine"], "big": ["big_snowpine_a", "big_snowpine_b", "big_pine_c"]}
BT_DEAD = {"mid": ["mid_dead", "mid_dead_b", "dead_tree_l"], "big": ["big_dead_a", "big_dead_b", "dead_giant"]}
BT_PINE = {"mid": ["mid_pine", "mid_pine_b", "mid_dead"], "big": ["big_pine_a", "big_pine_b", "big_pine_c"]}
BT_CLOUD = {"mid": ["cloud_tree_a", "cloud_tree_b"], "big": ["cloud_tree_c", "cloud_tree_b"]}
BT_HEDGE = {"mid": ["props/hedge2_tree", "props/city_street_tree", "props/hedge2_tree_s"], "big": ["props/hedge2_tree", "props/city_street_tree"]}
BT_PALM = {"mid": ["palm"], "big": ["palm"]}
BT_WILLOW = {"mid": ["mid_willow", "mid_willow_b"], "big": ["big_willow"]}
BT_JUNGLE = {"mid": ["props/mushroom_tree_a"], "big": ["props/mushroom_tree_b", "props/mushroom_tree_a"]}
BT_CITY = {"mid": ["props/city_brickwall", "props/city_tenement"], "big": ["props/city_tenement", "props/city_walkup", "props/city_apartment"]}


def _p(name, x, y, w=3, h=1, group=None):
    d = {"name": name, "cell": [x, y], "w": w, "h": h}
    if group:
        d["group"] = group
    return d


# ---- the new fields -------------------------------------------------------------------
# id: region, title, arc, tier, family, look, landmarks, names (5 points + camp),
#     brief, win, lose, reward, back
FIELDS = [
    dict(id="bf_highland_pass", region="highlands", title="Highland Pass", arc="both", tier=2, family="ridge", seed=401,
         ground="grass", patch="snowpatch", path="stone", backdrop="mountains", cliff_style=["snow", "stair_snow"],
         border={"n": "cliff", "s": "trees", "w": "trees", "e": "cliff"}, border_trees=BT_SNOW, theme=SNOW,
         scatter=["rock_snow_l", "rock_snow_m", "stump_snow", "bush_snow", "grass_tuft_frost"],
         props=[_p("bf_cairn", 30, 30, 2), _p("bf_cairn", 70, 60, 2), _p("stone_circle", 48, 43, 4, 2)],
         crit=["crow", "goat", "rabbit"],
         names=["Cairn Height", "Windy Saddle", "Shepherd's Fold", "Frost Ledge", "Howling Tor", "Pass Camp"],
         brief="The highland pass climbs in steps of stone and snow. Hold the cairns and the ridge, and the high road is yours.",
         win="The pass is open. Somewhere a goat bell rings like it's cheering.", lose="The wind wins this one. Back down to camp.",
         reward={"crystals": 520, "items": {"iron_bar": 5, "greater_potion": 2}}),
    dict(id="bf_quarry_cut", region="quarry", title="The Deep Cut", arc="both", tier=2, family="ring", seed=411,
         ground="quarry_floor", ground_seam="pale_stone", patch="ruinfloor", path="stone", backdrop="mountains", cliff_style=["sand", "stair_wood"],
         border={"n": "cliff", "s": "trees", "w": "cliff", "e": "cliff"}, border_trees=BT_PINE, theme=STONE,
         scatter=["boulder_l", "boulder_m", "cave_ore_crate", "mrock_stone_0", "boulder2_s_a"],
         props=[_p("crane", 30, 32, 3, 1), _p("cave_cart", 76, 34, 3, 1), _p("mine_crystal_cart", 66, 58, 2, 1), _p("cave_ore_crate", 38, 60, 3, 1)],
         crit=["crow", "rat"],
         names=["Crane Pit", "Hammer Terrace", "Echo Shaft", "Slag Hill", "Cutters' Steps", "Rubble Gate Camp"],
         brief="The quarry's terraces ring a deep pit. Take the cranes and the high terrace, and the golems lose their footing.",
         win="The cranes swing your way. The golems set down their hammers.", lose="Too much rock, too few friends. Back to the gate.",
         reward={"crystals": 520, "items": {"iron_bar": 6, "stone": 30}}),
    dict(id="bf_river_ford", region="riverlands", title="The River Ford", arc="both", tier=2, family="river", seed=421,
         ground="grass", patch="track", path="dirt", backdrop="hills",
         border={"n": "trees", "s": "trees", "w": "trees", "e": "trees"}, border_trees=BT_WILLOW, theme={"band": ["reeds2_0", "reeds2_2", "cattail_1", "bush"]},
         scatter=["reeds2_0", "cattail_2", "boulder_m", "log"],
         props=[_p("bf_weir_gate", 46, 36, 3, 1), _p("mill", 80, 60, 4, 2), _p("fishing_hut_stilts", 18, 66, 5, 2)],
         crit=["heron", "duck", "dragonfly", "frog"], fish=["trout", "catfish"],
         names=["North Willows", "Weir Gate", "Otter Bank", "Ford of Stones", "Mill Race", "Ferry Camp"],
         brief="The river splits the field in two. Cross at the fords, take the weir, and the far bank falls.",
         win="The weir opens and the river runs easy. Fish leap all the way upstream.", lose="The river's against us today. Back to the ferry.",
         reward={"crystals": 520, "items": {"greater_potion": 2, "iron_bar": 4}}),
    dict(id="bf_ruin_court", region="ruins", title="The Pillared Court", arc="both", tier=3, family="ring", seed=431,
         ground="grass", patch="ruinfloor", path="stone", backdrop="hills",
         border={"n": "cliff", "s": "trees", "w": "trees", "e": "trees"}, border_trees=BT_PINE,
         theme={"rocks": ["props/boulder3_0", "props/boulder3_3", "props/boulder_m"], "bushes": False},
         scatter=["boulder3_1", "boulder3_4", "ferns", "bf_ruin_pillar"],
         props=[_p("bf_ruin_pillar", 30, 32, 2), _p("bf_ruin_pillar", 78, 32, 2), _p("bf_ruin_wall", 26, 58, 4), _p("bf_ruin_wall", 80, 58, 4), _p("arch", 52, 60, 3)],
         crit=["crow", "owl", "bat"],
         names=["West Colonnade", "Guardian Dais", "East Colonnade", "Scribes' Wall", "Toppled Arch", "Broken Stair Camp"],
         brief="An old court of pillars around a raised dais. The guardians hold the dais; take the colonnades and climb.",
         win="The guardians bow their stone heads. The court is quiet and warm in the sun.", lose="The stones are stubborn today. Back to the stair.",
         reward={"crystals": 720, "items": {"gold_bar": 3, "amethyst": 2}}),
    dict(id="bf_cloud_stair", region="sky", title="The Cloud Stair", arc="penguins", tier=3, family="plain", seed=441, water=False, plateaus=False,
         ground="cloud", ground_seam="cloud", path="stone", backdrop="hills",  # C16b P5 (c16b_04-12): grey stone lanes read on cloud (was float_stone)
         border={"n": "trees", "s": "trees", "w": "trees", "e": "trees"}, border_trees=BT_CLOUD, theme=CLOUD,
         scatter=["skydeco_0", "skydeco_1", "skydeco_2", "skydeco_3", "cloud_tree_a"],
         props=[_p("bf_sky_pillar", 26, 32, 2), _p("bf_sky_pillar", 84, 36, 2), _p("bf_sky_pillar", 60, 48, 2)],
         crit=["eagle", "butterfly_blue"],
         names=["Star Ledge", "Finargle Roost", "Thin Air Fort", "Prism Shelf", "Cloudfoot", "Summit Camp"],
         brief="Up here the ground is cloud and the walls are sky. Hold the star pillars and the grumps fall back down the stair.",
         win="The clouds part under your feet. The pillars hum a bright, clean note.", lose="Too high, too windy. Back to the summit camp.",
         reward={"crystals": 760, "items": {"crystal_refined": 3, "gold_bar": 2}}),
    dict(id="bf_station_deck", region="station", title="Station Deck", arc="penguins", tier=4, family="ring", seed=451, plateaus=False, water=False,
         ground="metal_a", path="metal_b", backdrop="space",
         border={"n": "void", "s": "void", "w": "void", "e": "void"}, theme=DECK,
         scatter=["crates_a", "cargo_grey", "pipe_valve"],
         props=[_p("airlock", 52, 26, 6, 1), _p("crashed_probe", 22, 46, 3, 1), _p("landing_pad", 80, 44, 3, 2), _p("cryo_pod", 28, 62, 4, 1)],
         crit=[],
         names=["Airlock Row", "Reactor Ring", "Solar Wing", "Hydro Bay", "Crew Galley", "Docking Camp"],
         brief="The station's decks circle a dark reactor ring. Shards crawl the corridors; take the wings and power it back up.",
         win="The deck lights come on one row at a time. Somebody left the radio playing.", lose="The air's thin and the shards are thick. Back to the dock.",
         reward={"crystals": 900, "items": {"crystal_battery": 2, "gold_bar": 2}}),
    dict(id="bf_jungle_grove", region="jungle", title="Glowroot Grove", arc="penguins", tier=4, family="river", seed=461,
         ground="teal_moss", ground_seam="teal_moss", path="bio_path_0", backdrop="night",
         border={"n": "trees", "s": "trees", "w": "trees", "e": "trees"}, border_trees=BT_JUNGLE, theme=JUNGLE,
         scatter=["jdeco_0", "jdeco_4", "jdeco_6", "jdeco_8", "carnivore_plant"],
         props=[_p("alien_statue", 30, 32, 3), _p("carnivore_plant", 78, 34, 3), _p("mushroom_tree_b", 60, 62, 4)],
         crit=["jelly", "firefly", "butterfly_blue"], fish=["mooncarp"],
         names=["Fern Wall", "Vine Bridge", "Spore Hollow", "Glow Pool", "Root Temple", "Landing Camp"],
         brief="A glowing river cuts the grove. Shards hold the far bank; cross on the roots and take the temple.",
         win="The giant flowers turn to watch you pass, and they seem pleased.", lose="The jungle closes in. Back to the landing.",
         reward={"crystals": 900, "items": {"crystal_refined": 3, "greater_potion": 3}}),
    dict(id="bf_reef_shallows", region="colony_coral", title="Reef Shallows", arc="both", tier=2, family="river", seed=471,
         ground="grass", ground_seam="coral_sand", path="sand", patch="sand", backdrop="hills", water_shore="sand",
         border={"n": "water", "s": "trees", "w": "water", "e": "water"}, border_trees=BT_PALM, theme=REEF,
         scatter=["bk_shell_scallop", "bk_starfish_pink", "bk_seaweed_c", "bk_pebbles_s", "bk_driftwood_a"],
         props=[_p("coral_crystal_dim", 50, 30, 3, 1), _p("beached_boat", 24, 60, 3), _p("bk_tidepool_l", 80, 62, 4, 2), _p("bk_rowboat", 84, 30, 4)],
         crit=["seagull", "crab", "turtle"], fish=["eel", "salmon"],
         names=["Pearl Cove", "Coral Arch", "Wreck Point", "Tide Pools", "Crab Kingdom", "Boat Landing"],
         brief="A tidal channel splits the reef. Wade the sandbars, take the coral arch, and the colony can see you coming.",
         win="The merkitties wave from the shore. The reef glows pink and gold.", lose="The tide turns. Back to the boats.",
         reward={"crystals": 520, "items": {"greater_potion": 2, "iron_bar": 4}}),
    dict(id="bf_kelp_beds", region="colony_kelp", title="Kelp Beds", arc="both", tier=3, family="plain", seed=481,
         ground="teal_moss", ground_seam="teal_moss", path="sand", patch="bog", backdrop="hills", water_shore="sand", extra_water=True,
         border={"n": "water", "s": "trees", "w": "water", "e": "water"}, border_trees=BT_WILLOW, theme=KELP,
         scatter=["reeds2_1", "cattail_3", "mk_lily_l1", "mk_reeds_4"],
         props=[_p("kelp_crystal_dim", 52, 28, 3, 1), _p("mk_boardwalk", 30, 46, 3), _p("bk_rowboat", 78, 50, 4)],
         crit=["frog", "heron", "dragonfly"], fish=["eel"],
         names=["Kelp Edge", "Sunken Bell", "Eel Narrows", "Bubble Field", "Glow Shallows", "Driftwood Camp"],
         brief="Kelp and black water everywhere. Hold the dry humps between the pools and light a path to the colony.",
         win="The kelp sways open. Little lights blink on all along the path.", lose="The eels have the water today. Back to the raft.",
         reward={"crystals": 720, "items": {"gold_bar": 2, "crystal_refined": 2}}),
    dict(id="bf_uptown_plaza", region="uptown", title="Fountain Plaza", arc="gangsters", tier=3, family="ring", seed=491,
         ground="lawn", ground_seam="meadow_grass", path="asphalt2", backdrop="gritty",
         border={"n": "trees", "s": "trees", "w": "trees", "e": "trees"}, border_trees=BT_HEDGE, theme=LAWN,
         scatter=["topiary_a", "topiary_c", "bench_green", "lamp2_tall_0", "planter2_2"],
         props=[_p("gold_fountain", 50, 44, 5, 1), _p("bench2_iron_a", 30, 30, 3), _p("bench2_iron_b", 78, 30, 3), _p("lamp2_tall_0", 40, 60, 1), _p("lamp2_tall_0", 68, 60, 1)],
         crit=["pigeon", "cat_grey"],
         names=["Gallery Steps", "Fountain Terrace", "Glass Atrium", "Valet Ramp", "Tower Gardens", "Lawn Terrace Camp"],
         brief="Uptown's plaza rings a raised fountain terrace. The guards hold the terrace; take the lawns and walk up.",
         win="The fountain's yours. Up close the tower looks smaller.", lose="Too many suits on the lawn. Back to the terrace.",
         reward={"crystals": 720, "items": {"data_chip": 3, "servo": 6}}),
    dict(id="bf_sewer_works", region="underground", title="The Sewer Works", arc="gangsters", tier=4, family="river", seed=501, plateaus=False,
         ground="sewer_brick", ground_seam="cave_stone_floor", path="sewer_mossy", backdrop="night",
         border={"n": "void", "s": "void", "w": "void", "e": "void"}, theme=SEWER,
         scatter=["pipe_t", "pipe_valve", "grate_a", "grate_b", "oil_drums"],
         props=[_p("bf_sewer_mouth", 22, 22, 4, 1), _p("bf_sewer_mouth", 84, 22, 4, 1), _p("manhole_open", 54, 58, 2), _p("pipe_t", 30, 60, 1)],
         crit=["rat", "bat"],
         names=["West Outfall", "Pump Room", "East Outfall", "Old Platform", "Sluice Gate", "Manhole Camp"],
         brief="The sewer works run along one long channel. Crawlers and crews hold the outfalls; cross the walkways and take the pumps.",
         win="The pumps thump in time. Down here your name echoes.", lose="It stinks and they know it. Back up the ladder.",
         reward={"crystals": 900, "items": {"data_chip": 3, "servo": 8}}),
]

# Tweaks to the original eight fields (c3_12 #4, #7): north points 4 rows lower,
# Frostfield on snow, Dockside on the sea with a pier, the Vale full of crystals,
# and a themed border/scatter for each.
OLD = {
    "bf_frostfield": dict(ground="snow", ground_seam="snow_smooth", border_trees=BT_SNOW, theme=SNOW,
                          scatter=["rock_snow_l", "rock_snow_m", "rock_snow_s", "stump_snow", "bush_snow", "props/ice_crystal_dim"]),
    "bf_shattered_vale": dict(theme=CRYSTAL, border_trees=BT_PINE, region_count=150,
                              scatter=["crystal_rock", "mine_crystal_rock_1", "mine_crystal_rock_3", "ccrystal_1", "ccrystal_2", "ccrystal_3",
                                       "crystal_tree", "crystal_tree_pink", "moon_crystal_blue", "moon_crystal_pink", "boulder_l"]),
    # C16b P5 (c16b_18-18): the rail yards get freight cars, a coal hopper and a signal mast
    "bf_rail_yards": dict(theme=CITY, border_trees=BT_DEAD,
                          extra_props=[_p("train_car", 12, 62, 5, 2), _p("train_car", 84, 60, 5, 2), _p("ir_coal_hopper", 6, 36, 3, 4),
                                       _p("ir_signal_tower", 102, 38, 2, 5), _p("rusted_car", 30, 70, 3, 1)],
                          scatter=["drums", "tyres", "crates_a", "oil_drums", "cargo_red", "cargo_grey"]),
    "bf_dockside": dict(theme=DECK, ground="concrete_pier", ground_seam="dock_concrete", border={"n": "water", "s": "trees", "w": "trees", "e": "cliff"}, water_shore="sand",
                        extra_props=[_p("bk_pier_straight", 44, 3, 4, 2), _p("bk_pier_straight", 74, 3, 4, 2), _p("bollard_a", 40, 8, 1), _p("bollard_a", 82, 8, 1)],
                        scatter=["crates_a", "crates_pallet", "barrel_a", "oil_drums", "bollard_a", "rope_coil"]),
    # C16b P5 (c16b_04-13): the Neon Block gets its neon: signs, tall street lamps, a getaway car
    "bf_neon_block": dict(theme=CITY, border_trees=BT_CITY,
                          extra_props=[_p("neon_sign_0", 8, 40, 2, 2), _p("neon_sign_3", 96, 40, 2, 2), _p("neon_sign_5", 34, 66, 2, 2),
                                       _p("neon_sign_6", 72, 64, 2, 2), _p("neon_open", 70, 34, 3, 1), _p("lamp2_tall_0", 40, 74, 2, 5),
                                       _p("lamp2_tall_2", 64, 74, 2, 5), _p("veh_getaway_car_side", 86, 76, 5, 2)],
                          scatter=["crates_a", "oil_drums", "neon_sign_1", "neon_sign_2", "neon_sign_4", "lamp2_short_0"]),
    "bf_ash_wastes": dict(theme=ASH, border_trees=BT_DEAD),
    "bf_orchard_line": dict(),
    "bf_bog_crossing": dict(theme={"band": ["reeds2_0", "reeds2_3", "cattail_0", "props/mk_reeds_1"]}),
}


def tweak_old(R, fid):
    """Apply OLD[fid] to a generated original field (north points 4 rows lower)."""
    o = OLD.get(fid, {})
    rr = R[fid]
    for p in rr["battle"]["points"]:
        if p["cell"][1] < 26:
            p["cell"][1] = max(24, p["cell"][1] + 4)
    for k in ("ground", "ground_seam", "border", "border_trees", "water_shore"):
        if k in o:
            rr[k] = o[k]
    if "theme" in o:
        rr["gen"]["theme"] = o["theme"]
    if "scatter" in o:
        rr["gen"]["region_props"] = [n.split("/")[-1] for n in o["scatter"]]
    if "region_count" in o:
        rr["gen"]["region_count"] = o["region_count"]
    if o.get("theme", {}).get("trees") == []:
        rr["gen"]["clumps"] = 0
        rr["gen"]["scatter"] = 40
    rr["props"] = list(rr.get("props", [])) + _off_lanes(list(o.get("extra_props", [])), rr.get("paths", []), rr["battle"]["points"])


def _off_lanes(props, lanes, pts):
    """Landmarks never sit on a lane or a point (they block): slide them sideways until clear."""
    def hit(x, y, w, h):
        for lx, ly, lw, lh in lanes:
            if x < lx + lw + 1 and lx - 1 < x + w and y - h < ly + lh and ly <= y:
                return True
        for p in pts:
            px, py = p["cell"]
            if abs(px - (x + w / 2.0)) < w / 2.0 + 3 and abs(py - y) < 4:
                return True
        return False
    out = []
    for pr in props:
        pr = dict(pr, cell=list(pr["cell"]))
        x, y = pr["cell"]
        for dx in (0, 3, -3, 6, -6, 9, -9, 12, -12):
            if not hit(x + dx, y, pr["w"], pr["h"]):
                pr["cell"][0] = x + dx
                break
        out.append(pr)
    return out


def build(battle, kinds, rprops):
    """Make every themed field through gen_battles.battle()."""
    for f in FIELDS:
        cols, rows = 108, 86
        P, W, pts, paths = layout(f["family"], cols, rows, f["seed"], f["names"], f.get("plateaus", True), f.get("water", True))
        if f.get("extra_water"):
            W += [{"c": [40, 34], "r": 4, "seed": f["seed"] + 7}, {"c": [70, 40], "r": 5, "seed": f["seed"] + 8}]
        for w in W:
            if f.get("fish"):
                w["fish"] = f["fish"]
            if f.get("water_shore"):
                w["shore"] = f["water_shore"]
        en = kinds(f["region"]) or ["grump"]
        if f["arc"] == "penguins":
            en = [k for k in en if not k.startswith("thug_")] or ["grump"]
        if f["arc"] != "gangsters" and "grump" not in en:
            en.append("grump")
        back = ["hideout", 26, 38] if f["arc"] == "gangsters" else ["town", 40, 60]
        scat = list(f.get("scatter", [])) or rprops(f["region"])
        f["props"] = _off_lanes(f["props"], paths, pts)
        battle(f["id"], f["title"], f["arc"], f["tier"], cols, rows, f["ground"], f.get("patch"), f["path"], P, W, pts, en[:6],
               f["props"], f["crit"] or ["crow"], f["brief"], f.get("who", "Catkins" if f["arc"] != "gangsters" else "Halo"), f["win"], f["lose"],
               f["reward"], back, backdrop=f["backdrop"], border=f["border"], lanes=paths, scatter=scat,
               **{k: f[k] for k in ("ground_seam", "cliff_style", "border_trees", "theme", "water_shore") if k in f})
