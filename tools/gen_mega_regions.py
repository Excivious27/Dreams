#!/usr/bin/env python3
"""Mega regions: the big separate worlds you unlock later (data/mega_regions.json).

Edit this file, not the JSON. Run:  python3 tools/gen_mega_regions.py

A mega region is a cluster of areas (scenes) that feels like its own world: it
has its own tab in Menu > Map (hidden until unlocked), its own drawn map, a
travel line when you cross into it and a name banner. The home world is the
"Valley" tab; every scene not listed in a mega region belongs to it.

Fields (runtime: scripts/mega_region.gd `MegaRegion`, map tab: scripts/mega_map.gd `MegaMap`):
  id, name, short (tab label, <= 9 chars), arc ("both" / "penguins" / "gangsters"),
  status: "built" (areas exist) or "planned" (areas still to make). Either way a
      region only shows once at least one of its areas has res://scenes/<id>.tscn.
  blurb: one line under the map. travel: line shown when you cross in. leave: line
      when you go back to the Valley.
  theme: {"style": space|sea|city|cave|sky|deep|ice|desert|clockwork|chrome,
          "bg": [r,g,b], "land": [r,g,b], "accent": [r,g,b], "ink": [r,g,b]}
  map_art: optional "ui/<name>": a painted map (portrait). Pins sit at area pos on it.
  areas: [{"id", "name", "pos": [x, y] (0..1 of the map), "icon": "pin_*" (art/gen/ui),
           "arc" (optional, defaults to the region's), "blurb"}]
  links: [[area, area], ...]  roads/routes drawn between pins.
  entries: [{"from": valley scene, "to": area, "how": "rocket", "label": "..."}]
      where the region connects to the Valley (drawn as the "to Valley" arrow; the
      Valley tab shows a gate badge on `from`).
  unlock: {"any": [cond, ...]} or {"all": [...]} (nest freely). Conditions:
      {"seen": scene}          visited it / flags <scene>_seen
      {"flag": name}           run.flags has it
      {"quest": id}            quest taken or done
      {"quest_done": id}
      {"tier": n}              GameState.progress_tier() >= n
      {"built": [id, tier]}    Builds.built_tier(id) >= tier
      {"campaign_ready": cid}  the campaign can be fought (or is started/won)
      {"campaign_won": cid}
      {"arc": "penguins"}      this run's arc
  Arriving in any of its areas also unlocks a region (you're there, after all).
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

REGIONS = [
    # ---------------------------------------------------------------- existing
    {
        "id": "space", "name": "Space", "short": "Space", "arc": "both", "status": "built",
        "blurb": "Past the sky: the moon, the old star station and the green planet beyond it.",
        "travel": "The engines roar, the blue goes black, and the Valley shrinks to a green coin below.",
        "leave": "Down through the clouds, and the Valley smells of grass again.",
        "theme": {"style": "space", "bg": [0.06, 0.05, 0.16], "land": [0.55, 0.52, 0.66], "accent": [0.75, 0.6, 1.0], "ink": [0.95, 0.92, 1.0]},
        "areas": [
            {"id": "moon", "name": "The Moon", "pos": [0.30, 0.74], "icon": "pin_moon", "blurb": "Grey dust, low gravity, a crystal spire."},
            {"id": "station", "name": "Star Station", "pos": [0.58, 0.42], "icon": "pin_moon", "blurb": "An empty station humming in orbit."},
            {"id": "jungle", "name": "Green Planet", "pos": [0.76, 0.14], "icon": "pin_forest", "blurb": "Teal moss and glowing mushrooms."},
        ],
        "links": [["moon", "station"], ["station", "jungle"]],
        "entries": [
            {"from": "mountain", "to": "moon", "how": "landing pad", "label": "Mountain pad"},
            {"from": "farm", "to": "moon", "how": "rocket", "label": "Rocket Yard"},
        ],
        "unlock": {"any": [{"seen": "moon"}, {"seen": "station"}, {"seen": "jungle"}, {"flag": "moon_unlocked"},
                           {"flag": "rocket_flown"}, {"built": ["launchpad", 3]}]},
    },
    {
        "id": "colonies", "name": "Merkitty Colonies", "short": "Colonies", "arc": "penguins", "status": "built",
        "blurb": "Four island colonies, each kept alive by a star crystal. Pip's ferry sails from the beach pier.",
        "travel": "Pip's ferry rocks out past the breakers. Salt spray, gulls, and the Valley falls behind the waves.",
        "leave": "The ferry bumps the pier. Home sand under your boots.",
        "theme": {"style": "sea", "bg": [0.16, 0.42, 0.62], "land": [0.86, 0.78, 0.52], "accent": [0.55, 0.9, 1.0], "ink": [0.1, 0.12, 0.18]},
        "areas": [
            {"id": "colony_coral", "name": "Coral Reach", "pos": [0.26, 0.66], "icon": "pin_beach", "blurb": "Warm shallows and coral huts."},
            {"id": "colony_kelp", "name": "Kelp Hollow", "pos": [0.72, 0.62], "icon": "pin_lake", "blurb": "A village in the kelp forest."},
            {"id": "colony_ice", "name": "Frostfin Isle", "pos": [0.28, 0.22], "icon": "pin_mountain", "blurb": "Snow, ice floes, frostfin cats."},
            {"id": "colony_ember", "name": "Emberclaw Atoll", "pos": [0.74, 0.18], "icon": "pin_wastes", "blurb": "Black sand and a smoking peak."},
        ],
        "links": [],
        "hub": [0.5, 0.92],
        "entries": [{"from": "beach", "to": "colony_coral", "how": "ferry", "label": "Beach pier"}],
        "unlock": {"any": [{"seen": "colony_coral"}, {"seen": "colony_kelp"}, {"seen": "colony_ice"}, {"seen": "colony_ember"},
                           {"all": [{"tier": 1}, {"seen": "beach"}]}]},
    },
    {
        "id": "cities", "name": "Lieutenant Cities", "short": "Cities", "arc": "gangsters", "status": "built",
        "blurb": "The President's city: every district run by one of his lieutenants.",
        "travel": "The night bus hisses into the city. Neon on wet glass, sirens far off, and the Valley is a rumour.",
        "leave": "The last bus rattles out past the billboards. Crickets again.",
        "theme": {"style": "city", "bg": [0.1, 0.09, 0.15], "land": [0.28, 0.26, 0.34], "accent": [1.0, 0.35, 0.75], "ink": [0.95, 0.9, 1.0]},
        "areas": [
            {"id": "docks", "name": "The Docks", "pos": [0.22, 0.70], "icon": "pin_docks", "blurb": "Harbourmaster Vance's cranes and crates."},
            {"id": "neon", "name": "Neon", "pos": [0.52, 0.46], "icon": "pin_tower", "blurb": "Lucia's rain-soaked strip."},
            {"id": "uptown", "name": "Uptown", "pos": [0.78, 0.20], "icon": "pin_tower", "blurb": "Silas Crane's marble and the tower."},
            {"id": "underground", "name": "The Pit", "pos": [0.60, 0.78], "icon": "pin_mine", "blurb": "Brock's fight club under the streets."},
        ],
        "links": [["docks", "neon"], ["neon", "uptown"], ["neon", "underground"]],
        "entries": [{"from": "hideout", "to": "docks", "how": "night bus", "label": "Hideout"}],
        "unlock": {"any": [{"seen": "docks"}, {"seen": "neon"}, {"seen": "uptown"}, {"seen": "underground"},
                           {"all": [{"seen": "hideout"}, {"campaign_ready": "c_docks"}]}]},
    },
    {
        "id": "hollow", "name": "The Hollow Heart", "short": "Hollow", "arc": "both", "status": "built",
        "blurb": "Under the deepest mine floor, a whole country lit by crystal.",
        "travel": "The long lift sinks for minutes. The air turns warm, and crystal light comes up to meet you.",
        "leave": "The lift climbs and climbs, and at last there is daylight in the shaft.",
        "theme": {"style": "cave", "bg": [0.1, 0.06, 0.14], "land": [0.36, 0.26, 0.44], "accent": [0.7, 0.45, 1.0], "ink": [0.95, 0.9, 1.0]},
        "areas": [
            {"id": "hollow_heart", "name": "Hollow Heart", "pos": [0.5, 0.5], "icon": "pin_mine", "blurb": "Crystal caverns and the heart below."},
        ],
        "links": [],
        "entries": [{"from": "mine", "to": "hollow_heart", "how": "deep lift", "label": "Mine (deepest floor)"}],
        "unlock": {"any": [{"seen": "hollow_heart"}, {"flag": "hollow_heart_open"}]},
    },
    {
        "id": "sky", "name": "Sky Isles", "short": "Sky", "arc": "penguins", "status": "built",
        "blurb": "Islands floating on cloud above the great tree. Something enormous swims beneath them.",
        "travel": "Up the stair inside the great tree, until there is no tree: only cloud underfoot and sky all round.",
        "leave": "Down the great tree's stair, ring after ring, back to the forest floor.",
        "theme": {"style": "sky", "bg": [0.55, 0.75, 0.95], "land": [0.96, 0.97, 1.0], "accent": [1.0, 0.85, 0.4], "ink": [0.12, 0.16, 0.3]},
        "areas": [
            {"id": "sky", "name": "Cloud Isles", "pos": [0.5, 0.48], "icon": "pin_mountain", "blurb": "Floating islands and the knight's stair."},
        ],
        "links": [],
        "entries": [{"from": "forest", "to": "sky", "how": "great tree stair", "label": "Great tree"}],
        "unlock": {"any": [{"seen": "sky"}, {"quest": "sky_stair"}, {"campaign_ready": "c_sky"}]},
    },
    # ---------------------------------------------------------------- new (agent a6 builds the areas)
    {
        "id": "sunken", "name": "Sunken City", "short": "Sunken", "arc": "both", "status": "planned",
        "blurb": "A drowned city of domes and lantern-fish streets, reached by diving bell.",
        "travel": "The diving bell sinks into green light. Bubbles, then lamps: streets under the sea.",
        "leave": "The bell breaks the surface into sunshine.",
        "theme": {"style": "deep", "bg": [0.04, 0.2, 0.28], "land": [0.2, 0.42, 0.44], "accent": [0.4, 1.0, 0.85], "ink": [0.9, 1.0, 0.98]},
        "areas": [
            {"id": "sunken_gate", "name": "Bell Landing", "pos": [0.3, 0.8], "icon": "pin_beach", "blurb": "Where the diving bell sets down."},
            {"id": "sunken_plaza", "name": "Drowned Plaza", "pos": [0.55, 0.5], "icon": "pin_town", "blurb": "Domes, statues and lantern fish."},
            {"id": "sunken_vaults", "name": "Pearl Vaults", "pos": [0.7, 0.2], "icon": "pin_mine", "blurb": "The old treasury, sealed for a reason."},
        ],
        "links": [["sunken_gate", "sunken_plaza"], ["sunken_plaza", "sunken_vaults"]],
        "entries": [{"from": "beach", "to": "sunken_gate", "how": "diving bell", "label": "Beach"}],
        "unlock": {"any": [{"seen": "sunken_gate"}, {"all": [{"tier": 3}, {"seen": "beach"}]}]},
    },
    {
        "id": "north", "name": "Frozen North", "short": "North", "arc": "both", "status": "planned",
        "blurb": "Past the highlands: snowfields, an aurora village and halls cut into a glacier.",
        "travel": "The sled train climbs into white. The wind bites, and the aurora rolls overhead.",
        "leave": "The sled train rattles down out of the snow into green hills.",
        "theme": {"style": "ice", "bg": [0.72, 0.84, 0.94], "land": [0.95, 0.97, 1.0], "accent": [0.45, 0.95, 0.75], "ink": [0.1, 0.16, 0.28]},
        "areas": [
            {"id": "north_pass", "name": "Frost Pass", "pos": [0.25, 0.78], "icon": "pin_mountain", "blurb": "Where the sled train stops."},
            {"id": "north_village", "name": "Aurora Village", "pos": [0.55, 0.5], "icon": "pin_town", "blurb": "Warm lodges under the lights."},
            {"id": "north_glacier", "name": "Glacier Halls", "pos": [0.75, 0.2], "icon": "pin_mine", "blurb": "Blue ice halls, something frozen inside."},
        ],
        "links": [["north_pass", "north_village"], ["north_village", "north_glacier"]],
        "entries": [{"from": "highlands", "to": "north_pass", "how": "sled train", "label": "Highlands"}],
        "unlock": {"any": [{"seen": "north_pass"}, {"all": [{"tier": 3}, {"seen": "highlands"}]}]},
    },
    {
        "id": "desert", "name": "Desert Bazaar", "short": "Desert", "arc": "both", "status": "planned",
        "blurb": "Beyond the wastes: a caravan road, a great bazaar and a canyon of glass.",
        "travel": "The caravan sways over the dunes for a day and a night. Then lanterns, music, spice: the bazaar.",
        "leave": "The caravan winds back across the dunes to the edge of the wastes.",
        "theme": {"style": "desert", "bg": [0.9, 0.74, 0.45], "land": [0.98, 0.86, 0.6], "accent": [0.95, 0.4, 0.25], "ink": [0.25, 0.14, 0.08]},
        "areas": [
            {"id": "desert_road", "name": "Dune Road", "pos": [0.22, 0.75], "icon": "pin_wastes", "blurb": "Caravan tracks and wind-carved rock."},
            {"id": "desert_bazaar", "name": "The Bazaar", "pos": [0.52, 0.48], "icon": "pin_town", "blurb": "A market under a hundred awnings."},
            {"id": "desert_canyon", "name": "Glass Canyon", "pos": [0.78, 0.22], "icon": "pin_mountain", "blurb": "Sand fused to glass by something hot."},
        ],
        "links": [["desert_road", "desert_bazaar"], ["desert_bazaar", "desert_canyon"]],
        "entries": [{"from": "wastes", "to": "desert_road", "how": "caravan", "label": "Wastes"}],
        "unlock": {"any": [{"seen": "desert_road"}, {"all": [{"tier": 2}, {"seen": "wastes"}]}]},
    },
    {
        "id": "clockwork", "name": "Clockwork Isles", "short": "Clockwork", "arc": "penguins", "status": "planned",
        "blurb": "Brass islands that tick, wound by merkitty tinkerers. The airship sails from the Sky Isles.",
        "travel": "The airship's propellers whirr. Below, islands of brass turn slowly, like a clock with no hands.",
        "leave": "The airship sets you down among the clouds of the Sky Isles.",
        "theme": {"style": "clockwork", "bg": [0.32, 0.22, 0.14], "land": [0.78, 0.6, 0.3], "accent": [1.0, 0.82, 0.4], "ink": [0.98, 0.93, 0.8]},
        "areas": [
            {"id": "clock_harbor", "name": "Cog Harbour", "pos": [0.25, 0.75], "icon": "pin_docks", "blurb": "Airship moorings on a turning dock."},
            {"id": "clock_works", "name": "The Gearworks", "pos": [0.55, 0.48], "icon": "pin_town", "blurb": "Tinkerer workshops and a great spring."},
            {"id": "clock_spire", "name": "Spire of Hours", "pos": [0.75, 0.18], "icon": "pin_tower", "blurb": "The clock at the centre of it all."},
        ],
        "links": [["clock_harbor", "clock_works"], ["clock_works", "clock_spire"]],
        "entries": [{"from": "sky", "to": "clock_harbor", "how": "airship", "label": "Sky Isles"}],
        "unlock": {"any": [{"seen": "clock_harbor"}, {"all": [{"seen": "sky"}, {"tier": 4}]}]},
    },
    {
        "id": "megacity", "name": "Chrome Megacity", "short": "Megacity", "arc": "gangsters", "status": "planned",
        "blurb": "The maglev from Uptown runs to a city of chrome towers, where the President's money really lives.",
        "travel": "The maglev slides out of Uptown without a sound. Towers of chrome and light rise out of the haze.",
        "leave": "The maglev glides back into Uptown's marble station.",
        "theme": {"style": "chrome", "bg": [0.08, 0.1, 0.16], "land": [0.42, 0.48, 0.58], "accent": [0.3, 0.9, 1.0], "ink": [0.9, 0.97, 1.0]},
        "areas": [
            {"id": "mega_terminal", "name": "Maglev Terminal", "pos": [0.22, 0.78], "icon": "pin_docks", "blurb": "Glass halls and security drones."},
            {"id": "mega_market", "name": "Chrome Market", "pos": [0.5, 0.5], "icon": "pin_tower", "blurb": "Holo-signs and street tech."},
            {"id": "mega_arcology", "name": "The Arcology", "pos": [0.76, 0.18], "icon": "pin_tower", "blurb": "A tower city behind locked gates."},
        ],
        "links": [["mega_terminal", "mega_market"], ["mega_market", "mega_arcology"]],
        "entries": [{"from": "uptown", "to": "mega_terminal", "how": "maglev", "label": "Uptown"}],
        "unlock": {"any": [{"seen": "mega_terminal"}, {"campaign_won": "c_uptown"}]},
    },
]


def main() -> None:
    ids = [r["id"] for r in REGIONS]
    assert len(ids) == 10 and len(set(ids)) == 10, "there are ten mega regions"
    seen_areas = {}
    for r in REGIONS:
        assert r["arc"] in ("both", "penguins", "gangsters"), r["id"]
        assert len(r["short"]) <= 9, r["id"]
        names = {a["id"] for a in r["areas"]}
        for a in r["areas"]:
            assert a["id"] not in seen_areas, "area %s in two regions" % a["id"]
            seen_areas[a["id"]] = r["id"]
            assert all(0.0 <= v <= 1.0 for v in a["pos"]), a["id"]
        for l in r["links"]:
            assert l[0] in names and l[1] in names, (r["id"], l)
        for e in r["entries"]:
            assert e["to"] in names, (r["id"], e)
    arcs = {"penguins": 0, "gangsters": 0}
    for r in REGIONS:
        for a in arcs:
            if r["arc"] in ("both", a):
                arcs[a] += 1
    out = {"_note": "Written by tools/gen_mega_regions.py: edit that, not this file.",
           "order": ids, "list": {r["id"]: r for r in REGIONS},
           "area_of": seen_areas}
    path = os.path.join(ROOT, "data", "mega_regions.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=1)
        f.write("\n")
    print("mega regions: %d (penguins %d, gangsters %d), %d areas -> data/mega_regions.json" % (len(ids), arcs["penguins"], arcs["gangsters"], len(seen_areas)))


if __name__ == "__main__":
    main()
