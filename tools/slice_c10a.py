"""CONDUCT 10a P6: the decor render list (one source for the prompts, the grids and the names).

Imported by tools/slice_c10a.py (slicer) and printed into docs/src/c10a-render-list.md
(`python3 tools/slice_c10a.py doc`). Renders live in art/incoming/c10/<file>.
Every call to the image tool asks for ONE image (n=1) of one sheet; <= 3 images per call (Tom).

Piece tuple: (id, name, cat, rarity, [w, h] footprint cells, layer, rot, glow)
  cat: furniture | wall_art | decor | rug | wallpaper | flooring
  layer: floor (3/4 view object, base on the bottom row) | flat (rug, drawn under) |
         wall (hangs on the back wall, straight-on) | top (tabletop piece) |
         wallpaper | flooring (seamless 256 tile)
  rot: 1 | 2 (front + side: <id>_r1 = side) | 4 (seats: <id>_r1 side facing right,
       <id>_r2 back, <id>_r3 = flip of _r1, written by the slicer)
  glow: 0 or a light radius in px (NightGlow)
A piece whose id ends in "@r1"/"@r2" is a rotation view of the named base piece (no catalogue entry).
"""

STYLE = ("16-bit pixel art game furniture sprites, top-down 3/4 view exactly like Stardew Valley / "
         "Sun Haven interiors, light from top-left, clean 1px dark outlines, crisp hard pixels, "
         "cosy saturated palette, transparent background, NO text, letters or numbers anywhere, "
         "no watermark, no floor, no cast shadow on the background. All ages.")
GRID8 = ("Exactly 8 separate objects in 2 rows of 4, each centred in its own equal grid cell, "
         "wide empty gaps between objects, nothing touching or overlapping.")
GRID_ROT = ("Exactly 8 separate objects in 2 rows of 4, each centred in its own equal grid cell, "
            "wide empty gaps between objects, nothing touching. Row 1 shows ONE seat drawn three "
            "times (same design and colours): facing the viewer, seen from behind, seen from its "
            "right side; then the matching sofa seen from its side. Row 2 holds 4 wall-hung pieces "
            "drawn straight-on (flat to the wall, no floor shadow).")
GRID_ANIM = ("Exactly 3 rows; each row is ONE showpiece drawn 4 times left to right as a 4-frame "
             "animation loop (identical position, size and outline in every frame; only the "
             "lights, sparkles or moving parts change). Equal cells, wide gaps between rows.")
TEX4 = ("1024x1024 image split into a 2x2 grid of four square texture swatches separated by "
        "straight 16-pixel solid black gutters. Each swatch fills its whole quadrant edge to edge, "
        "seen perfectly top-down and flat (no perspective, no objects, no vignette, no border), "
        "and tiles seamlessly. 16-bit pixel art, crisp pixels, NO text.")


def P(i, n, cat, r, wh, layer="floor", rot=1, glow=0):
    return (i, n, cat, r, wh, layer, rot, glow)


F, W, D, R = "furniture", "wall_art", "decor", "rug"
C, U, RA, E, L, M, Q = "common", "uncommon", "rare", "epic", "legendary", "mythic", "unique"

SHEETS = []


def sheet(file, set_id, arc, theme, rows, grid=GRID8, kind="pieces", size="1536x1024"):
    SHEETS.append({"file": file, "set": set_id, "arc": arc, "theme": theme, "rows": rows,
                   "grid": grid, "kind": kind, "size": size})


# ---------------- wave 1: themed sets, sheet A (8 floor pieces) ----------------
sheet("set_neon_noir_a.png", "neon_noir", "gangsters",
      "Neon Noir: 1940s detective office at night, dark wood, smoky blue and hot pink neon trim",
      [[P("dc_noir_desk", "Noir Desk", F, U, [2, 1], rot=2), P("dc_noir_sofa", "Velvet Noir Sofa", F, RA, [2, 1], rot=2),
        P("dc_noir_lamp", "Noir Floor Lamp", F, C, [1, 1], glow=40), P("dc_noir_cabinet", "Case-File Cabinet", F, C, [1, 1])],
       [P("dc_noir_bed", "Noir Daybed", F, U, [2, 2], rot=2), P("dc_noir_hatstand", "Hat Stand", F, C, [1, 1]),
        P("dc_noir_radio", "Console Radio", F, RA, [1, 1]), P("dc_noir_neon_palm", "Neon Palm Planter", F, E, [1, 1], glow=36)]])
sheet("set_chrome_lab_a.png", "chrome_lab", "gangsters",
      "Chrome Lab: friendly cyberpunk workshop, brushed chrome, teal and violet screen glow, cables",
      [[P("dc_chrome_bench", "Chrome Workbench", F, U, [2, 1], rot=2), P("dc_chrome_bed", "Capsule Bed", F, RA, [2, 2], rot=2),
        P("dc_chrome_terminal", "Glow Terminal", F, U, [1, 1], glow=32), P("dc_chrome_locker", "Chrome Locker", F, C, [1, 1])],
       [P("dc_chrome_lamp", "Tube Lamp", F, C, [1, 1], glow=40), P("dc_chrome_robot", "Tea Robot", F, E, [1, 1]),
        P("dc_chrome_plant", "Hydro Planter", F, C, [1, 1], glow=24), P("dc_chrome_server", "Server Tower", F, U, [1, 1], glow=24)]])
sheet("set_safehouse_a.png", "safehouse", "gangsters",
      "Safehouse: cosy crew hideout, worn brick-red leather, crates, maps, warm bulbs",
      [[P("dc_safe_couch", "Lumpy Crew Couch", F, C, [2, 1], rot=2), P("dc_safe_table", "Map Table", F, U, [2, 1], rot=2),
        P("dc_safe_bunk", "Bunk Bed", F, U, [1, 2], rot=1), P("dc_safe_crates", "Crate Shelf", F, C, [1, 1])],
       [P("dc_safe_bulb", "Bare Bulb Stand", F, C, [1, 1], glow=36), P("dc_safe_safe", "Old Iron Safe", F, RA, [1, 1]),
        P("dc_safe_drum", "Oil-Drum Table", F, C, [1, 1]), P("dc_safe_board", "Plan Board", F, U, [1, 1])]])
sheet("set_gilt_deco_a.png", "gilt_deco", "gangsters",
      "Gilt City Deco: art-deco penthouse, black lacquer, gold sunburst inlay, emerald velvet",
      [[P("dc_gilt_bed", "Sunburst Bed", F, E, [2, 2], rot=2), P("dc_gilt_sofa", "Emerald Deco Sofa", F, RA, [2, 1], rot=2),
        P("dc_gilt_lamp", "Deco Torch Lamp", F, U, [1, 1], glow=44), P("dc_gilt_cabinet", "Lacquer Cabinet", F, U, [1, 1])],
       [P("dc_gilt_table", "Gold-Leaf Table", F, RA, [2, 1], rot=2), P("dc_gilt_statue", "Deco Dancer Statue", F, E, [1, 1]),
        P("dc_gilt_gramophone", "Gold Gramophone", F, RA, [1, 1]), P("dc_gilt_palm", "Potted Palm in Brass", F, C, [1, 1])]])
sheet("set_casino_a.png", "casino", "gangsters",
      "Casino Lounge: red felt, gold trim, card-table green, poker chips as decoration (no drinks)",
      [[P("dc_casino_table", "Card Table", F, RA, [2, 1], rot=2), P("dc_casino_roulette", "Roulette Wheel", F, E, [2, 2]),
        P("dc_casino_slot", "Lucky Slot Machine", F, RA, [1, 1], glow=28), P("dc_casino_booth", "Red Velvet Booth", F, U, [2, 1], rot=2)],
       [P("dc_casino_chips", "Chip Tower Stand", F, C, [1, 1]), P("dc_casino_lamp", "Gold Shade Lamp", F, C, [1, 1], glow=40),
        P("dc_casino_rope", "Velvet Rope Post", F, C, [1, 1]), P("dc_casino_dice", "Giant Dice Seat", F, U, [1, 1])]])
sheet("set_crystal_grotto_a.png", "crystal_grotto", "penguins",
      "Crystal Grotto: cave home of glowing aqua and violet crystals, smooth stone, moss",
      [[P("dc_grotto_bed", "Geode Bed", F, RA, [2, 2], rot=2), P("dc_grotto_table", "Stone Slab Table", F, C, [2, 1], rot=2),
        P("dc_grotto_lamp", "Crystal Cluster Lamp", F, U, [1, 1], glow=44), P("dc_grotto_shelf", "Geode Shelf", F, U, [1, 1])],
       [P("dc_grotto_pool", "Glow Pool Basin", F, E, [2, 1]), P("dc_grotto_mushroom", "Glow Mushroom Stool", F, C, [1, 1], glow=20),
        P("dc_grotto_fern", "Cave Fern Pot", F, C, [1, 1]), P("dc_grotto_obelisk", "Crystal Obelisk", F, RA, [1, 1], glow=32)]])
sheet("set_moonlit_a.png", "moonlit", "penguins",
      "Moonlit: midnight-blue and silver bedroom set, crescent moons and little stars",
      [[P("dc_moon_bed", "Crescent Bed", F, RA, [2, 2], rot=2), P("dc_moon_desk", "Stargazer Desk", F, U, [2, 1], rot=2),
        P("dc_moon_lamp", "Moon Orb Lamp", F, U, [1, 1], glow=44), P("dc_moon_wardrobe", "Night-Sky Wardrobe", F, U, [1, 1])],
       [P("dc_moon_telescope", "Brass Telescope", F, E, [1, 1]), P("dc_moon_pouf", "Cloud Pouf", F, C, [1, 1]),
        P("dc_moon_plant", "Moonflower Pot", F, C, [1, 1], glow=16), P("dc_moon_clock", "Star Grandfather Clock", F, RA, [1, 1])]])
sheet("set_ice_palace_a.png", "ice_palace", "penguins",
      "Ice Palace: sparkling carved ice and snow furniture, pale blue and white, penguin motifs",
      [[P("dc_ice_bed", "Snowdrift Bed", F, U, [2, 2], rot=2), P("dc_ice_table", "Carved Ice Table", F, C, [2, 1], rot=2),
        P("dc_ice_igloo_lamp", "Igloo Lamp", F, U, [1, 1], glow=36), P("dc_ice_shelf", "Icicle Shelf", F, C, [1, 1])],
       [P("dc_ice_fountain", "Frost Fountain", F, E, [1, 1]), P("dc_ice_penguin", "Ice Penguin Sculpture", F, RA, [1, 1]),
        P("dc_ice_snowman", "Tiny Snowman", F, C, [1, 1]), P("dc_ice_fish_tank", "Fish Snack Bucket", F, C, [1, 1])]])
sheet("set_merkitty_coral_a.png", "merkitty_coral", "penguins",
      "Merkitty Coral: undersea mer-cat cottage, pink coral, shells, pearls, sea-glass blue",
      [[P("dc_coral_bed", "Clamshell Bed", F, RA, [2, 2], rot=2), P("dc_coral_table", "Coral Table", F, C, [2, 1], rot=2),
        P("dc_coral_lamp", "Pearl Lamp", F, U, [1, 1], glow=36), P("dc_coral_shelf", "Driftwood Shelf", F, C, [1, 1])],
       [P("dc_coral_tank", "Round Fishbowl Stand", F, U, [1, 1]), P("dc_coral_chest", "Treasure Chest", F, E, [1, 1]),
        P("dc_coral_anemone", "Anemone Pot", F, C, [1, 1]), P("dc_coral_catbed", "Sea-Cat Bed", F, U, [1, 1])]])
sheet("set_catkins_a.png", "catkins", "penguins",
      "Catkins Monastery: calm cat-monk retreat, warm teak, paper lanterns, cushions, bonsai",
      [[P("dc_catkins_mat_bed", "Futon Bed", F, U, [2, 2], rot=2), P("dc_catkins_table", "Low Tea Table", F, C, [2, 1], rot=2),
        P("dc_catkins_lantern", "Paper Lantern Stand", F, C, [1, 1], glow=36), P("dc_catkins_shelf", "Scroll Shelf", F, U, [1, 1])],
       [P("dc_catkins_bonsai", "Bonsai", F, RA, [1, 1]), P("dc_catkins_gong", "Little Gong", F, E, [1, 1]),
        P("dc_catkins_cushion", "Meditation Cushion", F, C, [1, 1]), P("dc_catkins_scratch", "Cat Tree Tower", F, U, [1, 1])]])

# ---------------- wave 1: sheet B (seat 3 views + sofa side; 4 wall pieces) ----------------
def rot_sheet(file, set_id, arc, theme, seat, sofa, walls):
    s_id, s_name, s_r = seat
    rows = [[P(s_id, s_name, F, s_r, [1, 1], rot=4), P(s_id + "@r2", "", F, s_r, [1, 1]),
             P(s_id + "@r1", "", F, s_r, [1, 1]), P(sofa + "@r1", "", F, C, [1, 2])],
            [P(i, n, W, r, [1, 1], layer="wall", glow=g) for i, n, r, g in walls]]
    sheet(file, set_id, arc, theme, rows, grid=GRID_ROT)


rot_sheet("set_neon_noir_b.png", "neon_noir", "gangsters", SHEETS[0]["theme"],
          ("dc_noir_armchair", "Club Armchair", U), "dc_noir_sofa",
          [("dc_noir_neon_moon", "Neon Moon Sign", RA, 30), ("dc_noir_clock", "Noir Wall Clock", C, 0),
           ("dc_noir_blinds", "Window Blinds", C, 0), ("dc_noir_city_poster", "Night City Poster", U, 0)])
rot_sheet("set_gilt_deco_b.png", "gilt_deco", "gangsters", SHEETS[3]["theme"],
          ("dc_gilt_chair", "Deco Lounge Chair", RA), "dc_gilt_sofa",
          [("dc_gilt_mirror", "Sunburst Mirror", E, 0), ("dc_gilt_sconce", "Gold Fan Sconce", U, 34),
           ("dc_gilt_skyline", "Skyline Panel", RA, 0), ("dc_gilt_clock", "Deco Wall Clock", U, 0)])
rot_sheet("set_casino_b.png", "casino", "gangsters", SHEETS[4]["theme"],
          ("dc_casino_stool", "High-Roller Stool", U), "dc_casino_booth",
          [("dc_casino_ace_sign", "Neon Ace Sign", RA, 30), ("dc_casino_chip_frame", "Framed Lucky Chip", U, 0),
           ("dc_casino_cards_art", "Royal Flush Art", C, 0), ("dc_casino_marquee", "Marquee Light Strip", E, 36)])
rot_sheet("set_safehouse_b.png", "safehouse", "gangsters", SHEETS[2]["theme"],
          ("dc_safe_chair", "Patched Armchair", C), "dc_safe_couch",
          [("dc_safe_map", "City Map Pinboard", U, 0), ("dc_safe_keys", "Key Hook Rack", C, 0),
           ("dc_safe_wanted", "Crew Photo Frame", C, 0), ("dc_safe_neon_arrow", "Neon Arrow Sign", RA, 30)])
rot_sheet("set_crystal_grotto_b.png", "crystal_grotto", "penguins", SHEETS[5]["theme"],
          ("dc_grotto_throne", "Amethyst Seat", RA), "dc_grotto_table",
          [("dc_grotto_wall_crystal", "Wall Crystal", U, 28), ("dc_grotto_moss_frame", "Moss Mirror", C, 0),
           ("dc_grotto_fossil", "Framed Fossil", RA, 0), ("dc_grotto_vines", "Glow Vines", C, 20)])
rot_sheet("set_ice_palace_b.png", "ice_palace", "penguins", SHEETS[7]["theme"],
          ("dc_ice_throne", "Frost Armchair", RA), "dc_ice_table",
          [("dc_ice_snowflake", "Snowflake Wall Charm", C, 0), ("dc_ice_mirror", "Frost Mirror", U, 0),
           ("dc_ice_penguin_portrait", "Penguin Portrait", U, 0), ("dc_ice_aurora_window", "Aurora Panel", E, 30)])
rot_sheet("set_moonlit_b.png", "moonlit", "penguins", SHEETS[6]["theme"],
          ("dc_moon_chair", "Crescent Chair", U), "dc_moon_desk",
          [("dc_moon_star_garland", "Star Garland", C, 18), ("dc_moon_phase_art", "Moon Phases Print", U, 0),
           ("dc_moon_dreamcatcher", "Dreamcatcher", C, 0), ("dc_moon_constellation", "Constellation Map", RA, 0)])
rot_sheet("set_cottage_bloom_b.png", "cottage_bloom", "both",
          "Cottage Bloom: sunny flower cottage, cream wood, pastel florals, gingham cushions",
          ("dc_bloom_chair", "Floral Armchair", C), "dc_bloom_sofa",
          [("dc_bloom_wreath", "Flower Wreath", C, 0), ("dc_bloom_shelf", "Teacup Shelf", U, 0),
           ("dc_bloom_sampler", "Stitched Sampler", C, 0), ("dc_bloom_birdhouse", "Wall Birdhouse", U, 0)])
sheet("set_cottage_bloom_a.png", "cottage_bloom", "both", "Cottage Bloom: sunny flower cottage, cream wood, pastel florals, gingham",
      [[P("dc_bloom_bed", "Quilted Bloom Bed", F, U, [2, 2], rot=2), P("dc_bloom_sofa", "Gingham Sofa", F, C, [2, 1], rot=2),
        P("dc_bloom_lamp", "Tulip Lamp", F, C, [1, 1], glow=36), P("dc_bloom_dresser", "Painted Dresser", F, U, [1, 1])],
       [P("dc_bloom_table", "Lace Tea Table", F, C, [2, 1], rot=2), P("dc_bloom_flowers", "Flower Cart", F, RA, [1, 1]),
        P("dc_bloom_basket", "Yarn Basket", F, C, [1, 1]), P("dc_bloom_cradle_cat", "Cat Basket", F, C, [1, 1])]])

# ---------------- wave 2: gap categories ----------------
sheet("wallart_both.png", "", "both", "framed wall art for a cosy farmhouse, all drawn straight-on, flat to the wall",
      [[P("dc_art_meadow", "Meadow Painting", W, C, [1, 1], "wall"), P("dc_art_seascape", "Seascape Painting", W, C, [1, 1], "wall"),
        P("dc_art_still_life", "Fruit Still Life", W, U, [1, 1], "wall"), P("dc_art_mountain", "Mountain Painting", W, U, [1, 1], "wall")],
       [P("dc_art_cuckoo", "Cuckoo Clock", W, RA, [1, 1], "wall"), P("dc_art_round_mirror", "Round Mirror", W, C, [1, 1], "wall"),
        P("dc_art_plate_rack", "Plate Rack", W, C, [1, 1], "wall"), P("dc_art_antlers", "Carved Wood Antlers", W, U, [1, 1], "wall")]])
sheet("wallart_gang.png", "", "gangsters", "underworld and cyberpunk wall decor (no weapons, no drinks), drawn straight-on, flat to the wall",
      [[P("dc_gart_jazz_poster", "Jazz Night Poster", W, C, [1, 1], "wall"), P("dc_gart_cyber_poster", "Cyber City Poster", W, C, [1, 1], "wall"),
        P("dc_gart_gold_record", "Framed Gold Record", W, RA, [1, 1], "wall"), P("dc_gart_neon_star", "Neon Star", W, U, [1, 1], "wall", glow=28)],
       [P("dc_gart_tv_wall", "Wall Screen", W, U, [1, 1], "wall", glow=24), P("dc_gart_car_plate", "Vintage Car Plates", W, C, [1, 1], "wall"),
        P("dc_gart_fedora_hook", "Fedora Hook", W, C, [1, 1], "wall"), P("dc_gart_circuit_art", "Circuit Art", W, E, [1, 1], "wall", glow=20)]])
sheet("wallart_penguin.png", "", "penguins", "whimsical penguin and cat wall decor, drawn straight-on, flat to the wall",
      [[P("dc_part_penguin_family", "Penguin Family Photo", W, U, [1, 1], "wall"), P("dc_part_fish_clock", "Fish Clock", W, C, [1, 1], "wall"),
        P("dc_part_iceberg", "Iceberg Painting", W, C, [1, 1], "wall"), P("dc_part_paw_banner", "Paw Banner", W, C, [1, 1], "wall")],
       [P("dc_part_snow_globe_shelf", "Snow-Globe Shelf", W, RA, [1, 1], "wall"), P("dc_part_scarf_hook", "Scarf Hook", W, C, [1, 1], "wall"),
        P("dc_part_aurora_art", "Aurora Painting", W, E, [1, 1], "wall"), P("dc_part_fish_trophy", "Golden Fish Plaque", W, RA, [1, 1], "wall")]])
sheet("tabletop_both.png", "", "both", "small tabletop decorations for a cosy home, each small enough to sit on a table",
      [[P("dc_top_vase", "Flower Vase", D, C, [1, 1], "top"), P("dc_top_candles", "Candle Trio", D, C, [1, 1], "top", glow=20),
        P("dc_top_books", "Book Stack", D, C, [1, 1], "top"), P("dc_top_teapot", "Teapot Set", D, U, [1, 1], "top")],
       [P("dc_top_globe", "Desk Globe", D, U, [1, 1], "top"), P("dc_top_hourglass", "Hourglass", D, RA, [1, 1], "top"),
        P("dc_top_music_box", "Wind-Up Music Box", D, RA, [1, 1], "top"), P("dc_top_cactus", "Tiny Cactus", D, C, [1, 1], "top")]])
sheet("tabletop_arcs.png", "", "both", "small tabletop decorations: row 1 underworld and cyberpunk (no drinks), row 2 penguin whimsy",
      [[P("dc_top_desk_phone", "Rotary Phone", D, C, [1, 1], "top"), P("dc_top_cash_register_mini", "Toy Cash Register", D, U, [1, 1], "top"),
        P("dc_top_holo_cube", "Holo Cube", D, RA, [1, 1], "top", glow=18), P("dc_top_chess", "Chess Set", D, U, [1, 1], "top")],
       [P("dc_top_snow_globe", "Penguin Snow Globe", D, U, [1, 1], "top"), P("dc_top_fish_bowl", "Goldfish Bowl", D, C, [1, 1], "top"),
        P("dc_top_penguin_plush", "Penguin Plush", D, C, [1, 1], "top"), P("dc_top_ice_crystal", "Ice Crystal", D, RA, [1, 1], "top", glow=18)]])
sheet("kitchen.png", "", "both", "cosy home kitchen furniture",
      [[P("dc_kit_stove", "Cast-Iron Range", F, U, [1, 1]), P("dc_kit_counter", "Butcher-Block Counter", F, C, [2, 1]),
        P("dc_kit_sink", "Farmhouse Sink", F, C, [1, 1]), P("dc_kit_fridge", "Retro Icebox", F, U, [1, 1])],
       [P("dc_kit_hutch", "Dish Hutch", F, U, [1, 1]), P("dc_kit_pot_rack", "Copper Pot Stand", F, C, [1, 1]),
        P("dc_kit_bread_oven", "Bread Oven", F, RA, [1, 1], glow=24), P("dc_kit_dining", "Round Dining Table", F, C, [2, 2])]])
sheet("bath.png", "", "both", "cosy home bathroom furniture",
      [[P("dc_bath_tub", "Clawfoot Tub", F, U, [2, 1], rot=2), P("dc_bath_sink", "Pedestal Basin", F, C, [1, 1]),
        P("dc_bath_toilet", "Washroom Throne", F, C, [1, 1]), P("dc_bath_screen", "Folding Screen", F, C, [1, 1])],
       [P("dc_bath_towels", "Towel Rack", F, C, [1, 1]), P("dc_bath_vanity", "Mirror Vanity", F, U, [1, 1]),
        P("dc_bath_plant", "Fern Stand", F, C, [1, 1]), P("dc_bath_duck_tub", "Rubber Duck Basin", F, RA, [1, 1])]])
sheet("lights_both.png", "", "both", "home lights and lamps, each glowing softly",
      [[P("dc_light_chandelier", "Candle Chandelier", F, RA, [1, 1], glow=56), P("dc_light_brass", "Brass Floor Lamp", F, C, [1, 1], glow=40),
        P("dc_light_lantern", "Hanging Lantern Post", F, C, [1, 1], glow=36), P("dc_light_candelabra", "Candelabra", F, U, [1, 1], glow=36)],
       [P("dc_light_fairy", "Fairy-Light Jar", F, C, [1, 1], glow=28), P("dc_light_stained", "Stained-Glass Lamp", F, RA, [1, 1], glow=40),
        P("dc_light_fireplace", "Stone Fireplace", F, U, [2, 1], glow=56), P("dc_light_firefly", "Firefly Lamp", F, E, [1, 1], glow=36)]])
sheet("lights_gang.png", "", "gangsters", "underworld and cyberpunk lights and glowing furniture (no drinks)",
      [[P("dc_glight_neon_tube", "Neon Tube Lamp", F, C, [1, 1], glow=40), P("dc_glight_lava", "Lava Lamp", F, U, [1, 1], glow=30),
        P("dc_glight_spot", "Stage Spotlight", F, U, [1, 1], glow=48), P("dc_glight_jukebox", "Neon Jukebox", F, E, [1, 1], glow=40)],
       [P("dc_glight_arcade", "Retro Arcade Cabinet", F, RA, [1, 1], glow=32), P("dc_glight_holo", "Holo Projector", F, RA, [1, 1], glow=36),
        P("dc_glight_streetlamp", "Indoor Street Lamp", F, C, [1, 1], glow=44), P("dc_glight_tv", "Big Retro TV", F, U, [2, 1], glow=30)]])
sheet("rugs.png", "", "both", "rugs and floor mats seen from directly above, flat on the floor with no thickness and no shadow",
      [[P("dc_rug_braided", "Braided Rug", R, C, [2, 2], "flat"), P("dc_rug_persian", "Patterned Long Rug", R, U, [3, 2], "flat", rot=2),
        P("dc_rug_star", "Star Rug", R, RA, [2, 2], "flat"), P("dc_rug_neon", "Neon Grid Rug", R, U, [3, 2], "flat", rot=2)],
       [P("dc_rug_penguin", "Penguin Rug", R, U, [2, 2], "flat"), P("dc_rug_bear", "Faux Bear Rug", R, C, [2, 2], "flat"),
        P("dc_rug_casino", "Red Carpet Runner", R, C, [3, 1], "flat", rot=2), P("dc_rug_moon", "Moon Rug", R, RA, [2, 2], "flat")]])

# ---------------- wave 2: seamless wallpaper and floors (4 per image) ----------------
def tex_sheet(file, arc, kind, names):
    layer = "wallpaper" if kind == "wallpaper" else "flooring"
    cat = layer
    rows = [[P(i, n, cat, r, [1, 1], layer) for i, n, r, _ in names[:2]],
            [P(i, n, cat, r, [1, 1], layer) for i, n, r, _ in names[2:]]]
    desc = "; ".join("%s: %s" % (["top-left", "top-right", "bottom-left", "bottom-right"][k], d)
                     for k, (_, _, _, d) in enumerate(names))
    sheet(file, "", arc, desc, rows, grid=TEX4, kind=layer, size="1024x1024")


tex_sheet("wallpaper_both.png", "both", "wallpaper", [
    ("dc_wp_rose_stripe", "Rose Stripe Paper", C, "cream wallpaper with thin rose stripes and tiny flowers"),
    ("dc_wp_sage_damask", "Sage Damask Paper", U, "sage green damask wallpaper pattern"),
    ("dc_wp_plank_white", "Whitewashed Planks", C, "vertical whitewashed wooden wall planks"),
    ("dc_wp_star_navy", "Starry Navy Paper", RA, "navy blue wallpaper with small gold stars")])
tex_sheet("wallpaper_gang.png", "gangsters", "wallpaper", [
    ("dc_wp_deco_gold", "Gold Deco Paper", RA, "black wallpaper with gold art-deco fan pattern"),
    ("dc_wp_red_velvet", "Red Velvet Paper", U, "deep red flocked velvet wallpaper"),
    ("dc_wp_brick_neon", "Painted Brick", C, "dark painted brick wall with faint teal tint"),
    ("dc_wp_circuit", "Circuit Panel Wall", E, "dark metal wall panels with glowing teal circuit lines")])
tex_sheet("wallpaper_penguin.png", "penguins", "wallpaper", [
    ("dc_wp_ice_block", "Ice Block Wall", C, "pale blue stacked ice blocks"),
    ("dc_wp_snowflake", "Snowflake Paper", U, "light blue wallpaper with white snowflakes"),
    ("dc_wp_penguin_print", "Penguin Print Paper", RA, "mint wallpaper with tiny cute penguins"),
    ("dc_wp_coral_shell", "Seashell Paper", U, "soft coral pink wallpaper with little seashells")])
tex_sheet("floors_both.png", "both", "flooring", [
    ("dc_fl_herringbone", "Herringbone Oak", U, "honey oak herringbone parquet floor"),
    ("dc_fl_terracotta_hex", "Hex Terracotta", C, "terracotta hexagon floor tiles"),
    ("dc_fl_blue_tile", "Blue Kitchen Tile", C, "white and blue patterned ceramic floor tiles"),
    ("dc_fl_moss_carpet", "Moss Carpet", C, "soft moss green wall-to-wall carpet")])
tex_sheet("floors_gang.png", "gangsters", "flooring", [
    ("dc_fl_checker_gold", "Black-Gold Checker", RA, "black and gold checkerboard marble floor"),
    ("dc_fl_casino_carpet", "Casino Carpet", U, "busy red and gold patterned casino carpet"),
    ("dc_fl_metal_grid", "Glow Grid Floor", E, "dark metal floor plates with thin glowing violet seams"),
    ("dc_fl_dark_parquet", "Dark Walnut Floor", C, "dark walnut wood plank floor")])
tex_sheet("floors_penguin.png", "penguins", "flooring", [
    ("dc_fl_ice", "Polished Ice", U, "polished pale blue ice floor with soft cracks"),
    ("dc_fl_snow_carpet", "Snow Carpet", C, "fluffy white snow-like carpet"),
    ("dc_fl_sand_shell", "Shell Sand Floor", C, "smooth pale sand with tiny shells"),
    ("dc_fl_tatami", "Tatami Mats", U, "woven tatami straw floor mats")])

# ---------------- wave 2: legendary / mythic / unique showpieces (4-frame strips) ----------------
sheet("showpiece_penguin.png", "", "penguins", "penguin-world treasures",
      [[P("dc_show_aurora_tank", "Aurora Aquarium", F, L, [2, 1], glow=40)],
       [P("dc_show_star_orrery", "Star Orrery", F, M, [2, 2], glow=44)],
       [P("dc_show_moon_throne", "Moon Throne", F, Q, [2, 2], glow=48)]], grid=GRID_ANIM, kind="anim")
sheet("showpiece_gang.png", "", "gangsters", "underworld and cyberpunk treasures (no drinks, no weapons)",
      [[P("dc_show_gold_jukebox", "Golden Jukebox", F, L, [1, 1], glow=40)],
       [P("dc_show_skyline_window", "Neon Skyline Window", W, M, [2, 1], "wall", glow=40)],
       [P("dc_show_kingpin_vault", "Kingpin's Vault Door", F, Q, [2, 2], glow=24)]], grid=GRID_ANIM, kind="anim")
sheet("showpiece_both.png", "", "both", "magical home treasures",
      [[P("dc_show_crystal_tree", "Crystal Tree", F, M, [2, 2], glow=48)],
       [P("dc_show_grand_piano", "Grand Piano", F, L, [2, 2])],
       [P("dc_show_dream_clock", "Dream Clock", F, Q, [1, 1], glow=36)]], grid=GRID_ANIM, kind="anim")

ANIM_WORDS = {
    "dc_show_aurora_tank": "a long glass aquarium with a frosted silver frame, tiny fish and aurora-coloured light moving inside",
    "dc_show_star_orrery": "a brass orrery of planets on rings above a star-chart base, planets moving around their rings",
    "dc_show_moon_throne": "a silver throne carved like a crescent moon with a glowing moon-pearl crest that pulses",
    "dc_show_gold_jukebox": "an ornate golden jukebox with rainbow bubble tubes, its lights chasing",
    "dc_show_skyline_window": "a wide wall window showing a neon night city skyline, signs blinking (straight-on, wall-hung)",
    "dc_show_kingpin_vault": "a huge round gold-and-steel vault door in a frame, its dial and bolts turning, glints",
    "dc_show_crystal_tree": "a small tree made of glowing crystal in a stone pot, sparkles drifting through its branches",
    "dc_show_grand_piano": "a black grand piano with the lid open, little golden music notes floating up",
    "dc_show_dream_clock": "a tall whimsical clock with a swirling starry face, its hands and pendulum moving",
}


def prompt(s):
    if s["kind"] in ("wallpaper", "flooring"):
        return "%s %s." % (TEX4, s["theme"])
    lines = [STYLE, s["grid"], "Theme: %s." % s["theme"]]
    if s["kind"] == "anim":
        for k, row in enumerate(s["rows"]):
            p = row[0]
            lines.append("Row %d: %s (%s)." % (k + 1, ANIM_WORDS[p[0]], p[1]))
        lines.append("Each object is drawn large and fills most of its cell; every row is one object only.")
        return " ".join(lines)
    for k, row in enumerate(s["rows"]):
        names = []
        for p in row:
            base, _, view = p[0].partition("@")
            nm = p[1] or next((q[1] for sh in SHEETS for r in sh["rows"] for q in r if q[0] == base), base)
            if view == "r1":
                nm = "%s seen from its right side" % nm
            elif view == "r2":
                nm = "%s seen from behind" % nm
            elif p[5] == "wall":
                nm = "%s (wall-hung, straight-on)" % nm
            elif p[5] == "flat":
                nm = "%s (top-down, flat)" % nm
            names.append(nm)
        lines.append("Row %d left to right: %s." % (k + 1, ", ".join(names)))
    lines.append("Keep every object the same pixel scale (one floor tile = 32 pixels) and the same art style.")
    return " ".join(lines)


# =====================================================================================
# Slicer.   python3 tools/slice_c10a.py [sheets anims textures check doc sheet]
# Writes art/gen/decor/<id>.png (+ _r1/_r2/_r3 rotations, 4-frame strips for showpieces,
# 256x256 seamless wallpaper/flooring), art/gen/decor/_catalog.json and the manifest
# group "decor". Hardlinked art: every file is removed before it is written.
# After: python3 tools/art_audit.py --fix <decor ids>, python3 tools/set_import_lossy.py,
# flock godot --headless --import.
# =====================================================================================
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

SRC = "c10/"
GROUP = "decor"
CELL = 32          # source px per footprint cell (2x detail, drawn at 0.5)
FILL = 0.94        # floor pieces fill this share of their footprint width
WALL_MAX = 48      # wall art fits in 48x48 src px (1.5 x 1.5 cells)
TOP_MAX = 30       # tabletop pieces fit in 30x30 src px (sit on one table cell)
FPS = 6
# side views drawn facing RIGHT (all other sheets drew them facing left; _r1 is always
# stored facing right, _r3 is its mirror)
FACE_RIGHT = {"set_neon_noir_b.png"}
# the exact prompts sent where the generated text above was hand-tuned before the call
PROMPT_TWEAKS = {
    "set_cottage_bloom_a.png": "Cottage Bloom theme said 'pink gingham'.",
    "wallart_both.png": "wall-art preamble (no 3/4 view), names spelled out (painting/plaque).",
    "wallart_gang.png": "'no lettering' hints on the poster/plates, hat hanging on the hook.",
    "wallart_penguin.png": "names spelled out (fish-shaped clock, shelf holding three snow globes).",
    "tabletop_both.png": "'drawn large enough to show detail', no tile scale.",
    "tabletop_arcs.png": "per-row arc wording, 'drawn large enough to show detail'.",
    "kitchen.png": "names spelled out (stove, fridge, brick oven, table with two chairs).",
    "bath.png": "names spelled out (bathtub, toilet with wooden seat, basin with a rubber duck).",
    "lights_both.png": "chandelier 'on a standing pole', fireplace 'with a fire'.",
    "lights_gang.png": "spotlight 'on a stand', projector 'showing a glowing globe', TV 'on legs'.",
    "rugs.png": "rug-only preamble; round/long shapes named per rug.",
    "wallpaper_*.png": "'straight-on' (not top-down) and 'wallpaper for a game interior'.",
    "floors_*.png": "'floor for a game interior'.",
}


def _S():
    import slice_art as S
    return S


def _rm(name):
    S = _S()
    p = os.path.join(S.OUT, GROUP, name + ".png")
    if os.path.exists(p):
        os.remove(p)


def save(img, name):
    _rm(name)
    return _S().save(img, GROUP, name)


def save_strip(frames, name):
    _rm(name)
    S = _S()
    S.strip(frames, GROUP, name)
    S.manifest[GROUP][name]["fps"] = FPS


def rgba_of(file):
    import numpy as np
    from PIL import Image
    S = _S()
    src = Image.open(os.path.join(S.INC, SRC + file)).convert("RGBA")
    a = np.asarray(S.key_magenta(src)).copy()
    a[..., 3] = np.minimum(a[..., 3], np.asarray(src)[..., 3])
    return a


def cells(a, n_rows, n_cols, min_area=400):
    """Union box of every blob whose centre falls in each equal grid cell."""
    from slice_comp import blobs
    H, W = a.shape[:2]
    out = [[None] * n_cols for _ in range(n_rows)]
    for b in blobs(a, merge=4, min_area=min_area):
        cx, cy = (b[0] + b[2]) / 2, (b[1] + b[3]) / 2
        r, c = min(n_rows - 1, int(cy * n_rows / H)), min(n_cols - 1, int(cx * n_cols / W))
        o = out[r][c]
        out[r][c] = b if o is None else (min(o[0], b[0]), min(o[1], b[1]), max(o[2], b[2]), max(o[3], b[3]))
    for r in range(n_rows):
        for c in range(n_cols):
            assert out[r][c] is not None, ("empty cell", r, c)
    return out


def _crop(a, b):
    from PIL import Image
    return Image.fromarray(a[b[1]:b[3], b[0]:b[2]].copy())


def _scaled(im, f):
    S = _S()
    w, h = max(1, round(im.width * f)), max(1, round(im.height * f))
    out = S.scale_to(im, width=w, height=h)
    if max(out.size) <= 48:
        from crispen import crispen
        out = crispen(out, colors=32, outline=False, sharpen=60)
    return out


def factor(p, im):
    """Scale factor for a front piece: footprint width for floor/flat, a box for wall/top."""
    w, h = p[4]
    if p[5] == "wall":
        return min(WALL_MAX * w / im.width, WALL_MAX / im.height)
    if p[5] == "top":
        return min(TOP_MAX / im.width, TOP_MAX / im.height)
    if p[5] == "flat":
        return min(CELL * w * FILL / im.width, CELL * h * FILL / im.height)
    return CELL * w * FILL / im.width


CATALOG = {}


def entry(p, s, **extra):
    i, n, cat, r, wh, layer, rot, glow = p
    e = {"id": i, "name": n, "cat": cat, "rarity": r, "arc": s["arc"], "layer": layer,
         "size": list(wh), "rot": 1, "glow": glow, "set": s["set"], "sheet": s["file"]}
    e.update(extra)
    CATALOG[i] = e
    return e


def sheet_pieces(s):
    from PIL import Image, ImageOps
    a = rgba_of(s["file"])
    rows = s["rows"]
    boxes = cells(a, len(rows), len(rows[0]))
    row_f = {}
    for r, row in enumerate(rows):
        for c, p in enumerate(row):
            im = _crop(a, boxes[r][c])
            base, _, view = p[0].partition("@")
            if not view:
                f = factor(p, im)
                if r == 0 and s["grid"] is GRID_ROT:
                    row_f[r] = f
                out = _scaled(im, f)
                save(out, base)
                e = entry(p, s, px=list(out.size))
                if p[5] == "flat" and p[6] == 2:     # top-down rug: the slicer turns it
                    save(out.rotate(90, expand=True), base + "_r1")
                    e["rot"] = 2
                continue
            # rotation views share the seat-front factor of their row (same render scale)
            f = row_f.get(r) or CELL * FILL / im.width
            out = _scaled(im, f)
            if view == "r1":
                if s["file"] not in FACE_RIGHT:
                    out = ImageOps.mirror(out)
                save(out, base + "_r1")
                save(ImageOps.mirror(out), base + "_r3")
            else:
                save(out, base + "_r2")


def sheet_anim(s):
    from PIL import Image
    a = rgba_of(s["file"])
    boxes = cells(a, 3, 4)
    for r, row in enumerate(s["rows"]):
        p = row[0]
        crops = [_crop(a, b) for b in boxes[r]]
        f = factor(p, crops[0]) if p[5] != "wall" else min(CELL * p[4][0] * FILL / crops[0].width, 64 / crops[0].height)
        frames = [_scaled(im, f) for im in crops]
        save_strip(frames, p[0])
        save(frames[0], p[0] + "_icon")
        entry(p, s, frames=4, fps=FPS, px=[frames[0].width, frames[0].height], icon=p[0] + "_icon")


def _period(l, axis, lo=16, hi=300):
    """Smallest shift that maps the swatch onto itself (2-D correlation along one axis)."""
    import numpy as np
    x = l - l.mean()
    n = x.shape[axis]
    hi = min(hi, n // 2)
    best = []
    for k in range(lo, hi):
        a = x[:, :-k] if axis == 1 else x[:-k]
        b = x[:, k:] if axis == 1 else x[k:]
        d = np.sqrt((a * a).sum() * (b * b).sum())
        best.append((a * b).sum() / d if d else 0)
    best = np.array(best)
    if len(best) == 0 or best.max() < 0.75:
        return 0
    top = best.max()
    for i in range(1, len(best) - 1):   # first local peak close to the best one
        if best[i] >= best[i - 1] and best[i] >= best[i + 1] and best[i] > 0.9 * top:
            return lo + i
    return lo + int(np.argmax(best))


def _seamless(a, band=24):
    import numpy as np
    n, m = a.shape[:2]
    r = np.roll(a, (n // 2, m // 2), (0, 1))
    dy = np.minimum(np.arange(n), n - 1 - np.arange(n)).astype(float)
    dx = np.minimum(np.arange(m), m - 1 - np.arange(m)).astype(float)
    wy = np.clip(dy / band, 0, 1); wy = wy * wy * (3 - 2 * wy)
    wx = np.clip(dx / band, 0, 1); wx = wx * wx * (3 - 2 * wx)
    w = np.minimum.outer(wy, wx)[..., None]
    return a * w + r * (1 - w)


def swatch_boxes(a):
    """The four swatches between the black gutters (gutters found by dark rows/cols)."""
    import numpy as np
    l = a[..., :3].mean(2)
    H, W = l.shape

    def split(prof, n):
        mid = np.arange(n // 4, 3 * n // 4)
        dark = mid[prof[mid] < 22]
        if len(dark) == 0:
            return n // 2 - 8, n // 2 + 8
        return int(dark.min()), int(dark.max()) + 1

    y0, y1 = split(l.mean(1), H)
    x0, x1 = split(l.mean(0), W)
    pad = 6
    return [(pad, pad, x0 - pad, y0 - pad), (x1 + pad, pad, W - pad, y0 - pad),
            (pad, y1 + pad, x0 - pad, H - pad), (x1 + pad, y1 + pad, W - pad, H - pad)]


def _fade_axis(a, axis, band=40):
    """Cross-fade one axis only (the other already wraps exactly)."""
    import numpy as np
    n = a.shape[axis]
    r = np.roll(a, n // 2, axis)
    d = np.minimum(np.arange(n), n - 1 - np.arange(n)).astype(float)
    w = np.clip(d / band, 0, 1); w = w * w * (3 - 2 * w)
    w = w[None, :, None] if axis == 1 else w[:, None, None]
    return a * w + r * (1 - w)


def tile_from(sw):
    """Crop whole pattern periods on each axis that repeats (exact wrap); cross-fade the rest."""
    import numpy as np
    from PIL import Image
    l = sw[..., :3].mean(2)
    px, py = _period(l, 1), _period(l, 0)
    H, W = l.shape
    side = min(H, W)
    cw = max(1, W // px) * px if px else side
    chh = max(1, H // py) * py if py else side
    crop = sw[:chh, :cw]
    o = np.asarray(Image.fromarray(crop.astype(np.uint8)).resize((256, 256), Image.LANCZOS)).astype(float)
    if not px:
        o = _fade_axis(o, 1)
    if not py:
        o = _fade_axis(o, 0)
    how = "x:%s y:%s" % (px or "fade", py or "fade")
    o = np.clip(o, 0, 255).astype(np.uint8)
    o[..., 3] = 255
    return Image.fromarray(o), how


def sheet_texture(s):
    import numpy as np
    from PIL import Image
    S = _S()
    a = np.asarray(Image.open(os.path.join(S.INC, SRC + s["file"])).convert("RGBA")).astype(np.int32)
    flat = [p for row in s["rows"] for p in row]
    for p, b in zip(flat, swatch_boxes(a)):
        im, how = tile_from(a[b[1]:b[3], b[0]:b[2]])
        save(im, p[0])
        save(im.crop((112, 112, 144, 144)), p[0] + "_icon")
        entry(p, s, px=[256, 256], period_cells=8, tile=how, icon=p[0] + "_icon")


def settle_rot():
    """rot from the views that were drawn: back view -> 4 (seat), side only -> 2."""
    for s in SHEETS:
        for row in s["rows"]:
            for p in row:
                base, _, view = p[0].partition("@")
                if view and base in CATALOG:
                    e = CATALOG[base]
                    e["rot"] = 4 if (view == "r2" or e["rot"] == 4) else max(2, e["rot"])


def write_catalog():
    S = _S()
    settle_rot()
    path = os.path.join(S.OUT, GROUP, "_catalog.json")
    if os.path.exists(path):
        os.remove(path)
    rows = []
    for e in sorted(CATALOG.values(), key=lambda e: e["id"]):
        rows.append({k: e[k] for k in ("id", "name", "cat", "rarity", "arc", "layer", "size", "rot", "glow", "set")}
                    | {k: e[k] for k in ("frames", "fps", "icon", "px", "tile", "sheet") if k in e})
    with open(path, "w") as fh:
        json.dump(rows, fh, indent=1, sort_keys=True)
    return rows


def check():
    """Every catalogue id has its art; rotations exist for rot>1; ids/names unique."""
    S = _S()
    cat = json.load(open(os.path.join(S.OUT, GROUP, "_catalog.json")))
    ids = [e["id"] for e in cat]
    names = [e["name"].lower() for e in cat]
    assert len(set(ids)) == len(ids), "duplicate ids"
    assert len(set(names)) == len(names), "duplicate names"
    bad = []
    for e in cat:
        need = [e["id"]] + {2: ["_r1"], 4: ["_r1", "_r2", "_r3"]}.get(e["rot"], [])
        for n in need:
            n = n if n.startswith("dc_") else e["id"] + n
            if not os.path.exists(os.path.join(S.OUT, GROUP, n + ".png")):
                bad.append(n)
        assert e["id"].startswith("dc_") and len(e["name"]) <= 22, e["id"]
        assert e["rarity"] in ("common", "uncommon", "rare", "epic", "legendary", "mythic", "unique")
        assert e["arc"] in ("both", "penguins", "gangsters")
    assert not bad, bad
    print("check ok: %d catalogue pieces" % len(cat))


def doc():
    out = ["# C10a decor render list (CONDUCT 10a P6)", "",
           "Generated by `python3 tools/slice_c10a.py doc` from the SHEETS table in tools/slice_c10a.py "
           "(the one source for prompts, grids and names). Renders: art/incoming/c10/<file>, one image "
           "per call (n=1, <= 3 per call), dreams-image `generate_image`, background transparent "
           "(textures opaque). Slice: `python3 tools/slice_c10a.py` -> art/gen/decor/ + _catalog.json.", "",
           "Hand-tuned wording sent instead of the generated prompt: " +
           "; ".join("%s: %s" % kv for kv in PROMPT_TWEAKS.items()), ""]
    for s in SHEETS:
        out += ["## %s (%s, %s, arc %s)" % (s["file"], s["size"], s["kind"], s["arc"]), "",
                "Pieces: " + ", ".join("%s%s" % (p[0], "" if "@" in p[0] else " (%s)" % p[3]) for r in s["rows"] for p in r), "",
                "Prompt:", "", "> " + prompt(s), ""]
    p = os.path.join(os.path.dirname(__file__), "..", "docs", "src", "c10a-render-list.md")
    with open(p, "w") as fh:
        fh.write("\n".join(out))
    print("wrote", os.path.normpath(p))


def main(only):
    S = _S()
    mpath = os.path.join(S.OUT, "manifest.json")
    S.manifest.update(json.load(open(mpath)))
    if "doc" in only:
        doc()
        return
    if only == ["check"]:
        check()
        return
    os.makedirs(os.path.join(S.OUT, GROUP), exist_ok=True)
    for s in SHEETS:
        if only and s["file"] not in only and s["kind"] not in only:
            continue
        {"pieces": sheet_pieces, "anim": sheet_anim}.get(s["kind"], sheet_texture)(s)
        print("ok", s["file"])
    if only:   # partial run: keep earlier catalogue rows
        cp = os.path.join(S.OUT, GROUP, "_catalog.json")
        if os.path.exists(cp):
            for e in json.load(open(cp)):
                CATALOG.setdefault(e["id"], e)
    rows = write_catalog()
    data = json.dumps(S.manifest, indent=1, sort_keys=True)
    os.remove(mpath)
    with open(mpath, "w") as fh:
        fh.write(data)
    print("catalogue:", len(rows))
    check()


if __name__ == "__main__":
    main(sys.argv[1:])
