#!/usr/bin/env python3
"""Fast-travel network data (CONDUCT 14 P4, findings c14_05-01..25, contract section 1).

Writes (edit this file, never the JSON):
  data/travel.json  {stations: [...], links: [...], kinds: {...}, pos: {...}}

Tom (C14): travel is EARNED. You walk first; then you find or build local
shortcuts (T1), regional lines (T2), world lines to the mega regions (T3),
hub-to-hub lines (T4) and last of all a few instant hops (T5). Each arc has its
own stations; "both" stations serve either arc.

station {id, arc, scene, cell [x,y], kind, prop, keeper, name, build {money, items}?,
         spawn [x,y]? (arrival cell; default the cell below the station), placed (bool:
         TravelNet.on_enter puts the prop and desk down; false = another system already
         draws it, e.g. the mega keepers' vehicles, the beach marina desk, colony jetties)}
link {id, a, b, tier 1..5, kind, unlock {type, id, n} | {type: "all", of: [...]},
      cost {money, items}, free_after {cond} ({} = always paid; {"type":"rides","n":5}
      = free after five paid rides), minutes (game minutes the ride takes), path [[x,y]..]
      (0..1 points on the Map-tab painting, a->b), both_ways}
unlock types: quest (quest done), campaign (Campaign.is_won), crew_perk (Crew.perk_level(id) >= n), skill (skill id reaches
level n), perk (id "skill:node"), explore (scene visited), flag (run flag), tier
(progress_tier >= n), project (every station of the link built), always, all.
TravelNet also loads data/marina.json["routes"] (same link format; P3 owns it).

    python3 tools/gen_travel.py
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")

# Valley spots on the Map-tab painting (same numbers as GameMenu.PINS).
POS = {"farm": [0.44, 0.47], "town": [0.52, 0.70], "forest": [0.30, 0.24], "lake": [0.14, 0.40],
       "meadow": [0.66, 0.46], "crystal_meadow": [0.86, 0.40], "mine": [0.72, 0.20], "mountain": [0.74, 0.70],
       "beach": [0.40, 0.90], "moon": [0.90, 0.08], "wastes": [0.95, 0.26], "hideout": [0.95, 0.52],
       "docks": [0.86, 0.84], "neon": [0.72, 0.92], "uptown": [0.58, 0.96], "underground": [0.70, 0.98],
       "countryside": [0.98, 0.66], "sky": [0.28, 0.06], "station": [0.80, 0.03], "jungle": [0.66, 0.04],
       "orchard_hills": [0.24, 0.12], "highlands": [0.50, 0.12], "ruins": [0.60, 0.30], "quarry": [0.58, 0.84],
       "marsh": [0.22, 0.86], "riverlands": [0.08, 0.62], "community_farm": [0.36, 0.72],
       "colony_coral": [0.30, 0.99], "colony_kelp": [0.46, 0.99], "colony_ice": [0.20, 0.99], "colony_ember": [0.56, 0.99]}

# What each kind is called, its prop art (art/gen/c14p4 group "c14p4"), its ride
# vehicle strip for TravelScene and its sound.
KINDS = {
    "cart": {"name": "Cart Stop", "prop": "c14p4_cart_stop", "veh": "c14p4_veh_cart", "sfx": "cart_rattle", "gang_name": "Freight Trolley Stop"},
    "rail": {"name": "Rail Halt", "prop": "c14p4_rail_halt", "veh": "c14p4_veh_train", "sfx": "train_depart"},
    "ferry": {"name": "Ferry Landing", "prop": "c14p4_ferry_kiosk", "veh": "c14p4_veh_ferry", "sfx": "ferry_horn"},
    "boat": {"name": "Boat Landing", "prop": "c14p4_ferry_kiosk", "veh": "c14p4_veh_ferry", "sfx": "ferry_horn"},
    "bus": {"name": "Bus Stop", "prop": "c14p4_bus_stop", "veh": "c14p4_veh_bus", "sfx": "car_start"},
    "plane": {"name": "Airstrip", "prop": "c14p4_airstrip", "veh": "c14p4_veh_plane", "sfx": "airship_whoosh"},
    "cloud": {"name": "Cloud Dock", "prop": "c14p4_cloud_dock", "veh": "c14p4_veh_cloud", "sfx": "airship_whoosh"},
    "taxi": {"name": "Taxi Stand", "prop": "c14p4_taxi_stand", "veh": "c14p4_veh_taxi", "sfx": "car_start"},
    "subway": {"name": "Subway Entrance", "prop": "c14p4_subway", "veh": "c14p4_veh_subway", "sfx": "train_depart"},
    "current": {"name": "Current Pool", "prop": "c14p4_current_pool", "veh": "c14p4_veh_bubble", "sfx": "splash"},
    "mast": {"name": "Balloon Mast", "prop": "c14p4_balloon_mast", "veh": "c14p4_veh_balloon", "sfx": "airship_whoosh"},
    "hop": {"name": "Waystone", "prop": "c14p4_waystone", "veh": "", "sfx": "teleport"},
    "zip": {"name": "Zip Line", "prop": "c14p4_zip_pad", "veh": "", "sfx": "airship_whoosh"},
    "ladder": {"name": "Ladder", "prop": "c14p4_ladder", "veh": "", "sfx": "door"},
    "stairs": {"name": "Cliff Stairs", "prop": "c14p4_stairs", "veh": "", "sfx": "door"},
    "mega": {"name": "", "prop": "", "veh": "c14p4_veh_caravan", "sfx": "door"},
}

S = []  # stations
L = []  # links


def st(sid, arc, scene, cell, kind, keeper="", name="", build=None, spawn=None, placed=True, prop=None):
    d = {"id": sid, "arc": arc, "scene": scene, "cell": list(cell), "kind": kind,
         "prop": KINDS.get(kind, {}).get("prop", "") if prop is None else prop, "keeper": keeper,
         "name": name or KINDS.get(kind, {}).get("name", kind), "placed": placed}
    if build:
        d["build"] = build
    if spawn:
        d["spawn"] = list(spawn)
    S.append(d)


def path(a_scene, b_scene):
    pa = POS.get(a_scene)
    pb = POS.get(b_scene)
    if not pa or not pb:
        return []
    mid = [round((pa[0] + pb[0]) / 2 + (pb[1] - pa[1]) * 0.08, 3), round((pa[1] + pb[1]) / 2 - (pb[0] - pa[0]) * 0.08, 3)]
    return [pa, mid, pb]


def ln(lid, a, b, tier, kind, unlock, cost=None, free_after=None, minutes=20, both=True):
    sa = next(x for x in S if x["id"] == a)
    sb = next(x for x in S if x["id"] == b)
    L.append({"id": lid, "a": a, "b": b, "tier": tier, "kind": kind, "unlock": unlock,
              "cost": cost or {"money": 0, "items": {}}, "free_after": free_after or {},
              "minutes": minutes, "path": path(sa["scene"], sb["scene"]), "both_ways": both})


def money(n, **items):
    return {"money": n, "items": items}


RIDES5 = {"type": "rides", "n": 5}

# ---- T1 local shortcuts (both arcs: found or built, free) ----------------------------
st("farm_hedge_gap", "both", "farm", [70, 28], "hop", name="Hedge Gap", prop="c14p4_hedge_gap")
st("meadow_hedge_gap", "both", "meadow", [1, 14], "hop", name="Hedge Gap", prop="c14p4_hedge_gap")
ln("t1_farm_meadow", "farm_hedge_gap", "meadow_hedge_gap", 1, "hop", {"type": "skill", "id": "foraging", "n": 3}, minutes=5)
st("town_cliff_stairs", "penguins", "town", [47, 92], "stairs", build=money(500, plank=20, stone=30))
st("beach_cliff_stairs", "penguins", "beach", [30, 1], "stairs")
ln("t1_town_beach", "town_cliff_stairs", "beach_cliff_stairs", 1, "stairs", {"type": "project"}, minutes=5)
st("forest_log_bridge", "both", "forest", [2, 30], "ladder", name="Log Bridge", prop="c14p4_log_bridge", build=money(0, wood=20))
st("lake_log_bridge", "both", "lake", [46, 20], "ladder", name="Log Bridge", prop="c14p4_log_bridge")
ln("t1_forest_lake", "forest_log_bridge", "lake_log_bridge", 1, "ladder", {"type": "project"}, minutes=5)
st("mountain_zip", "penguins", "mountain", [30, 4], "zip", build=money(2000, rope=4, iron_bar=10))
st("farm_zip", "penguins", "farm", [50, 3], "zip")
ln("t1_mountain_farm", "mountain_zip", "farm_zip", 1, "zip", {"type": "all", "of": [{"type": "project"}, {"type": "tier", "n": 1}]}, minutes=3, both=False)
# Gangster T1: the Hideout's back door, fire escapes.
st("hideout_backdoor", "gangsters", "hideout", [3, 10], "ladder", name="Back Door", prop="c14p4_ladder")
st("town_alley", "gangsters", "town", [80, 60], "ladder", name="Alley Door", prop="c14p4_ladder")
ln("t1_hideout_town", "hideout_backdoor", "town_alley", 1, "ladder", {"type": "quest", "id": "docks"}, minutes=5)
st("neon_fire_escape", "gangsters", "neon", [46, 20], "ladder", name="Fire Escape")
st("uptown_fire_escape", "gangsters", "uptown", [4, 30], "ladder", name="Fire Escape")
ln("t1_neon_uptown", "neon_fire_escape", "uptown_fire_escape", 1, "ladder", {"type": "quest", "id": "neon"}, minutes=5)

# ---- T2 regional lines ----------------------------------------------------------------
# The Valley mine-cart line (Tom: "carts between the mines and the valley").
st("quarry_cart", "both", "quarry", [26, 20], "cart", keeper="", build=money(800, iron_bar=10, plank=20))
st("meadow_cart", "both", "meadow", [30, 4], "cart")
st("mountain_cart", "both", "mountain", [10, 6], "cart")
for a, b, lid in (("quarry_cart", "meadow_cart", "t2_cart_quarry_meadow"), ("meadow_cart", "mountain_cart", "t2_cart_meadow_mountain"),
                  ("quarry_cart", "mountain_cart", "t2_cart_quarry_mountain")):
    ln(lid, a, b, 2, "cart", {"type": "all", "of": [{"type": "project"}, {"type": "quest", "id": "granite_bones"}]},
       money(50), {"type": "campaign", "id": "c_quarry"}, minutes=30)
# The river ferry (penguins): farm dock - lake - riverlands.
st("farm_dock", "penguins", "farm", [6, 56], "ferry", build=money(300, plank=25))
st("lake_dock", "penguins", "lake", [24, 36], "ferry")
st("riverlands_dock", "penguins", "riverlands", [26, 30], "ferry")
ln("t2_ferry_farm_lake", "farm_dock", "lake_dock", 2, "ferry", {"type": "all", "of": [{"type": "project"}, {"type": "quest", "id": "finn_trout"}]},
   money(50), RIDES5, minutes=30)
ln("t2_ferry_lake_river", "lake_dock", "riverlands_dock", 2, "ferry", {"type": "all", "of": [{"type": "project"}, {"type": "explore", "id": "riverlands"}]},
   money(50), {"type": "campaign", "id": "c_riverlands"}, minutes=40)
# Beach marina (P3 draws these desks) and the colony jetties (P5 draws those).
st("beach_marina", "both", "beach", [77, 19], "ferry", name="Marina Passage Desk", spawn=[77, 18], placed=False)
st("beach_colony_ferry", "penguins", "beach", [12, 29], "ferry", name="Colony Ferry", spawn=[12, 22], placed=False)
st("beach_tidewater", "gangsters", "beach", [12, 29], "boat", name="Tidewater Launch", spawn=[12, 22], placed=False)
COLONIES = ["coral", "kelp", "ice", "ember"]
for c in COLONIES:
    # Real jetty cells from P5's gen_colonies (kelp/ember are mirrored).
    st("colony_%s_jetty" % c, "penguins", "colony_" + c, [51, 61] if c in ("kelp", "ember") else [44, 61], "ferry", name="Jetty",
       spawn=[55, 60] if c in ("kelp", "ember") else [40, 60], placed=False)
    ln("t2_colony_%s" % c, "beach_colony_ferry", "colony_%s_jetty" % c, 2, "ferry", {"type": "explore", "id": "colony_" + c},
       money(30), {"type": "campaign", "id": "c_colony_" + c}, minutes=45)
# Merkitty currents between colonies (T3 inside the sea, after all four beacons).
ALL_COLONIES = {"type": "all", "of": [{"type": "flag", "id": "colony_%s_done" % c} for c in COLONIES]}
for i, c in enumerate(COLONIES):
    d = COLONIES[(i + 1) % len(COLONIES)]
    ln("t3_current_%s_%s" % (c, d), "colony_%s_jetty" % c, "colony_%s_jetty" % d, 3, "current", ALL_COLONIES, minutes=20)
# Town: the Harbour Row ferry & coach office (P2's c14p2_ticket_office, quay cell 50,110).
st("town_ferry_office", "penguins", "town", [50, 110], "ferry", name="Ferry Office")
ln("t2_town_marina", "town_ferry_office", "beach_marina", 2, "ferry", {"type": "explore", "id": "beach"}, money(20), RIDES5, minutes=15)
# Gangster T2: the city bus, payphone taxis, the harbour water taxi.
st("bus_hideout", "gangsters", "hideout", [10, 4], "bus")
st("bus_docks", "gangsters", "docks", [4, 12], "bus")
ln("t2_bus_hideout_docks", "bus_hideout", "bus_docks", 2, "bus", {"type": "quest", "id": "docks"}, money(10), RIDES5, minutes=20)
st("taxi_town", "gangsters", "town", [50, 110], "taxi")  # the Harbour Row coach office's taxi rank (P2)
for sc, cell in (("farm", [44, 40]), ("docks", [10, 20]), ("neon", [6, 12]), ("uptown", [6, 16]), ("hideout", [16, 8])):
    st("taxi_" + sc, "gangsters", sc, cell, "taxi")
    ln("t2_taxi_town_" + sc, "taxi_town", "taxi_" + sc, 2, "taxi", {"type": "explore", "id": sc}, money(40),
       {"type": "crew_perk", "id": "rides", "n": 2}, minutes=15)
st("docks_water_taxi", "gangsters", "docks", [30, 36], "boat", name="Harbor Shuttle")
ln("t2_harbor_shuttle", "beach_tidewater", "docks_water_taxi", 2, "boat", {"type": "quest", "id": "docks"}, money(40), RIDES5, minutes=25)

# ---- T3 world lines: the mega-region keepers (MegaTravel draws their vehicles) ---------
MEGA = json.load(open(os.path.join(DATA, "mega_travel.json"))).get("regions", {})
HUBS = []
for rid, r in MEGA.items():
    e = r.get("entry", {})
    arc = r.get("arc", "both")
    st(rid + "_home", arc, e["scene"], e["cell"], "mega", keeper=r.get("keeper", ""), name=r.get("hub_name", rid) + " ride",
       spawn=e.get("spawn"), placed=False)
    st(rid + "_hub", arc, r["hub"], r.get("hub_spawn", [10, 10]), "mega", keeper=r.get("keeper", ""), name=r.get("hub_name", rid),
       spawn=r.get("hub_spawn"), placed=False)
    POS.setdefault(r["hub"], [0.5, 0.02])
    ln("mega_" + rid, rid + "_home", rid + "_hub", 3, "mega", {"type": "flag", "id": "mega_%s_open" % rid}, money(150), RIDES5,
       minutes={"frostpeak": 40, "sunscorch": 60, "giltcity": 20}.get(rid, 40))
    HUBS.append((rid, arc))
# ---- T4 hub-to-hub lines, the airship dock and the charter plane ------------------------
for i, (a, arc_a) in enumerate(HUBS):
    for b, arc_b in HUBS[i + 1:]:
        arc = arc_a if arc_a != "both" else arc_b
        if arc_a != "both" and arc_b != "both" and arc_a != arc_b:
            continue
        ln("t4_%s_%s" % (a, b), a + "_hub", b + "_hub", 4, "mega",
           {"type": "all", "of": [{"type": "flag", "id": "mega_%s_open" % a}, {"type": "flag", "id": "mega_%s_open" % b}, {"type": "tier", "n": 3}]},
           money(150), RIDES5, minutes=60)
st("mountain_airship", "penguins", "mountain", [44, 10], "cloud", name="Airship Dock", build=money(8000, plank=60, sail=20, crystal_refined=10))
st("mountain_airstrip", "gangsters", "mountain", [44, 10], "plane", name="Charter Airstrip", build=money(8000, plank=40, iron_bar=20, gear=10))
for rid, arc in HUBS:
    for sid, a2 in (("mountain_airship", "penguins"), ("mountain_airstrip", "gangsters")):
        if arc not in ("both", a2):
            continue
        ln("t4_%s_%s" % (sid, rid), sid, rid + "_hub", 4, "cloud" if a2 == "penguins" else "plane",
           {"type": "all", "of": [{"type": "project"}, {"type": "tier", "n": 3}, {"type": "flag", "id": "mega_%s_open" % rid}]},
           money(200), RIDES5, minutes=50)
# Subway: Uptown <-> Iron Mill District ('Reopen the Red Line').
st("uptown_subway", "gangsters", "uptown", [24, 22], "subway", name="Red Line", build=money(6000, iron_bar=40, gear=10))
st("iron_mill_subway", "gangsters", "iron_mill_district", [25, 30], "subway", name="Red Line")
ln("t3_red_line", "uptown_subway", "iron_mill_subway", 3, "subway",
   {"type": "all", "of": [{"type": "project"}, {"type": "quest", "id": "neon"}, {"type": "flag", "id": "mega_ironline_open"}]}, money(30), RIDES5, minutes=25)

# ---- Balloon masts / charter pads (the balloon item flies only between built masts) -----
MASTS = [("farm", [36, 6]), ("town", [30, 30]), ("mountain", [20, 30]), ("meadow", [18, 22])]
for sc, cell in MASTS:
    st("mast_" + sc, "penguins", sc, cell, "mast", build=money(1500, plank=20, rope=8, cloth=6))
    st("pad_" + sc, "gangsters", sc, [cell[0] + 2, cell[1]], "plane", name="Charter Pad", build=money(1500, plank=20, iron_bar=8, gear=4))
for i, (a, _) in enumerate(MASTS):
    for b, _ in MASTS[i + 1:]:
        ln("t3_mast_%s_%s" % (a, b), "mast_" + a, "mast_" + b, 3, "mast", {"type": "all", "of": [{"type": "project"}, {"type": "tier", "n": 2}]}, money(60),
           {"type": "skill", "id": "foraging", "n": 8}, minutes=30)
        ln("t3_pad_%s_%s" % (a, b), "pad_" + a, "pad_" + b, 3, "plane", {"type": "all", "of": [{"type": "project"}, {"type": "tier", "n": 2}]}, money(60),
           {"type": "skill", "id": "foraging", "n": 8}, minutes=20)

# ---- T5 instant hops: Star Crystal waystones / the Hideout dispatch board ---------------
WAY = [("farm", [38, 30]), ("town", [44, 48]), ("mountain", [28, 24])]
for sc, cell in WAY:
    st("way_" + sc, "penguins", sc, cell, "hop")
for i, (a, _) in enumerate(WAY):
    for b, _ in WAY[i + 1:]:
        ln("t5_way_%s_%s" % (a, b), "way_" + a, "way_" + b, 5, "hop", {"type": "quest", "id": "teleporter"}, minutes=0)
st("dispatch_hideout", "gangsters", "hideout", [20, 6], "taxi", name="Dispatch Board", prop="c14p4_dispatch")
for sc in ("farm", "docks", "neon", "uptown"):
    ln("t5_dispatch_" + sc, "dispatch_hideout", "taxi_" + sc, 5, "taxi", {"type": "quest", "id": "uptown"}, minutes=0)


def check():
    ids = set()
    for s in S:
        assert s["id"] not in ids, s["id"]
        ids.add(s["id"])
        assert s["arc"] in ("penguins", "gangsters", "both"), s
        assert s["kind"] in KINDS, s
    lids = set()
    for l in L:
        assert l["id"] not in lids, l["id"]
        lids.add(l["id"])
        assert l["a"] in ids and l["b"] in ids, l
        assert 1 <= l["tier"] <= 5, l
    # Every tier exists for each arc (c14_05-08/09).
    by = {s["id"]: s for s in S}
    for arc in ("penguins", "gangsters"):
        tiers = {l["tier"] for l in L if by[l["a"]]["arc"] in ("both", arc) and by[l["b"]]["arc"] in ("both", arc)}
        assert tiers == {1, 2, 3, 4, 5}, (arc, tiers)


def main():
    check()
    out = {"_doc": "written by tools/gen_travel.py; edit the generator", "kinds": KINDS, "pos": POS, "stations": S, "links": L}
    with open(os.path.join(DATA, "travel.json"), "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)
        f.write("\n")
    print("gen_travel: %d stations, %d links" % (len(S), len(L)))


if __name__ == "__main__":
    main()
