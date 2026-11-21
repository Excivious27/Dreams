class_name SeasonLook
## C15 P5: one place that turns an outdoor prop into its look-season twin.
## GameMap.prop() and PropDress run every props/nature sprite through pick(), so
## town plaza props, region props and props_c14 dressing all change with the
## season without each map remembering to ask (c15_13-01/-02/-03/-05/-06,
## c15_18-20, c15_17-09). Order: this table (C15 P5 art, ids c15p5_*), then
## <name>_<season> art when it exists, then (winter) WorldGen.winter_look.
## A missing twin keeps the base art: nothing ever disappears.

const TWINS := {
	"c14p2_tree_planter": {"spring": "c15p5_tree_planter_spring", "fall": "c15p5_tree_planter_fall", "winter": "c15p5_tree_planter_winter"},
	"c14p2_rose_arbour": {"winter": "c15p5_rose_arbour_winter"},
	"c14p2_flower_kiosk": {"fall": "c15p5_flower_kiosk_fall", "winter": "c15p5_flower_kiosk_winter"},
	"c14p2_cafe_umbrella": {"winter": "c15p5_cafe_umbrella_winter"},
	"c14p2_bench_curved": {"winter": "c15p5_bench_curved_winter"},
	"c14p2_bench_iron": {"winter": "c15p5_bench_iron_winter"},
	"city_street_tree": {"fall": "c15p5_city_street_tree_fall", "winter": "c15p5_city_street_tree_winter"},
	"hedge2_tree": {"winter": "c15p5_hedge2_tree_winter"},
	"hedge2_tree_s": {"winter": "c15p5_hedge2_tree_s_winter"},
	"hedge2_pot": {"winter": "c15p5_hedge2_pot_winter"},
	"topiary_c": {"winter": "c15p5_topiary_c_winter"},
	"mid_oak": {"fall": "c15p5_mid_oak_fall"},
	"planter2_0": {"fall": "c15p5_planter2_mums_fall"},
	"planter2_1": {"fall": "c15p5_planter2_asters_fall"},
	"planter2_2": {"fall": "c15p5_planter2_mums_fall"},
	"planter2_3": {"fall": "c15p5_planter2_asters_fall"},
}

## Groups whose sprites follow the season (buildings keep their own snow-roof path).
const GROUPS := ["props", "nature"]


static func pick(group: String, name: String, se := "") -> String:
	if not (group in GROUPS):
		return name
	if se == "":
		se = GameState.look_se()
	var row: Dictionary = TWINS.get(name, {})
	if row.has(se) and Art.has(group, str(row[se])):
		return str(row[se])
	if se in ["spring", "summer", "fall"]:
		return name + "_" + se if Art.has(group, name + "_" + se) else name
	if se == "winter":
		# WorldGen.winter_look's rule, for any asked season (it reads the live one).
		if WorldGen.WINTER_LOOKS.has(name):
			var w: String = WorldGen.WINTER_LOOKS[name]
			return w if Art.has(group, w) else name
		for suf: String in ["_winter", "_snow"]:
			if Art.has(group, name + suf):
				return name + suf
	return name


## True when `name` (a base prop) has a twin for `se` (tests, reports).
static func has_twin(group: String, name: String, se: String) -> bool:
	return pick(group, name, se) != name
