# CONDUCT 14 contract (fixed before launch)

## 1. TravelNet (P4 builds; P3/P5/maps rely on it)
scripts/travel_net.gd, `class_name TravelNet`, static, state `run["travel"]` via `TravelNet.st()` -> {unlocked: {link_id: true}, seen: {link_id: true}, built: {station_id: true}}.
Data: data/travel.json (tools/gen_travel.py): stations [{id, arc ("penguins"|"gangsters"|"both"), scene, cell [x,y], kind (cart|rail|ferry|bus|plane|cloud|taxi|subway|current|mast|hop|zip|ladder|stairs), prop, keeper}], links [{id, a, b, tier (1..5), kind, unlock {type: quest|project|campaign|skill|explore|tier, id, n}, cost {money, items}, free_after, path [[x,y]...] on the Map-tab art, both_ways}].
TravelNet ALSO loads `data/marina.json["routes"]` (same link format, kind "ferry"/"boat") so P3 never edits gen_travel.py.
API (add, never change signatures): `TravelNet.links_at(scene) -> Array`, `TravelNet.can_ride(id) -> bool`, `TravelNet.why_not(id) -> String` (all-ages words, Campaign.blocks still applies), `TravelNet.unlock(id, source)`, `TravelNet.build(station_id)`, `TravelNet.ride(link_id)` (pays cost, plays TravelScene unless seen + skip, changes scene to b's station cell), `TravelNet.station_prop(m, station_id)` (maps call this from their draw to place the station prop via prop()/anim_prop()), `TravelNet.desk(m, station_id)` (opens the ride choice list with a way out last).
Station ids P3 uses at the beach: `beach_marina` (passage desk), `beach_colony_ferry` (penguin colony ferry), `beach_tidewater` (gang water-taxi). P5 adds `colony_<id>_jetty` at each colony spawn (penguin) and calls TravelNet.station_prop / desk there; P4 lists those station ids in gen_travel.py.

## 2. Save blocks (P4 owns the game_state.gd edit)
P4 adds BOTH "travel" and "marina" to GameState.RUN_BLOCKS, one SAVE_VERSION bump, one `_migrate` step creating both empty blocks. P3 never edits game_state.gd; Marina.st() returns run["marina"] (create on demand if missing).

## 3. Marina (P3)
scripts/marina.gd `class_name Marina`, data/marina.json {tiers, npcs, spots, schedule, shops, quests, charters, routes, festival, lines {pen, gang}}. Routes use the TravelNet link format. Charter areas are region entries merged by gen_marina.py into regions.json the way gen_colonies.py does (P5 owns gen_mega_new/gen_colonies; P3 only adds its own merge step in regen_data.sh after them).

## 4. Ownership of shared files
- game_map.gd: P1. Others: hooks of at most 2 lines (station props, prop_dress call, travel desk).
- gen_mega_new.py / mega_regions_new.py: P5, except the region entries for P1's home maps (countryside, riverlands, highlands, orchard hills, community farm look). Edit only your entries' dicts; regions.json is regenerated at integration.
- game_state.gd: P4 (save blocks) + P6 (lighting helpers, small). Nobody else.
- interiors: P2. mines: P6. colonies: P5. beach: P3. town: P2.
- art/gen/manifest.json: everyone appends via their slicer; json_merge at integration. Never modify an existing file under art/ in place (rm first, then write). New art ids prefixed by package: c14p1_*, c14p2_*, ... (no clashes).
- tools/regen_data.sh: P3 and P4 each add their generator line (append-only, near the end).
- tools/check.sh: new test blocks appended at the END, each with an `echo "== ... =="` header, blank line before and after.

## 5. Prop dressing (P6)
`PropDress.dress(m: GameMap, scene_id: String)` reads data/props_c14.json {scene: [{id, cell, layer, anim}]} and places props through m.prop()/anim_prop()/under_layer() during baked drawing. Map owners (P1/P2/P3/P5) add the one-line call at the end of their draw if missing; P6 may add it itself as an allowed hook.

## 6. Art budget (dreams-image, 1000/day, ~720 left today)
P1 120, P2 100, P3 80, P4 60, P5 150, P6 150 images. Count every generate/edit call. Max 3 images per prompt file. Record every prompt in your report (Tom gets an ART-PROMPTS file).

## 7. Rules
Deterministic tests on game time, --fixed-fps 60. Data with a generator: edit the generator, then bash tools/regen_data.sh. All ages; no family/staff names (new NPCs: invented names, check docs/PROJECT-MEMORY no-names rule). Both arcs everywhere. Every menu has a way out last. Notes between packages: /home/claude/wt/c14f_reports/NOTES.md ("P3 -> P4: ...").
