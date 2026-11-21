class_name RanchVoice
## Ranch and team animal voices (CONDUCT 11b P5: c11b_14-03/-07/-08/-10, c11b_02-12).
## One place answers "what does this animal sound like": a kind (species id, art strip, baby,
## variant or shorn strip) resolves to a species (ranch.json, then the C11b art table aliases),
## the species to a voice id (ranch.json "voice", else SPECIES_VOICE below), and the voice id to an
## existing sound file at a pitch and level (VOICE_FILES): no new audio files, so the web build
## stays the same size. Lab strains (C11b art family "lab", gangster arc) add a soft layered
## whirr or bleep a moment later (LAYERS), so a chrome hen still clucks but sounds modified.
## Moments: call (petting/CHECK), happy (fed/healed), hurt (soft, rate-capped), attack, down.
## Every file named here is checked by tools/sfx_audit.py.

## voice id -> [file in audio/sfx, pitch, dB]
const VOICE_FILES := {
	"cluck": ["cluck", 1.0, 0.0], "quack": ["quack", 1.0, 0.0], "moo": ["moo", 1.0, 0.0], "baa": ["sheep", 1.0, 0.0],
	"sheep": ["sheep", 1.0, 0.0], "bleat": ["bleat", 1.0, 0.0], "hum": ["bleat", 0.8, -3.0], "oink": ["oink", 1.0, 0.0],
	"squeak": ["critter", 1.3, -3.0], "thump": ["thump", 1.0, 0.0], "buzz": ["buzz", 1.0, -2.0], "peep": ["peep", 1.0, 0.0],
	"rooster": ["rooster", 1.0, 0.0], "whinny": ["whinny", 1.0, 0.0], "horse_whinny": ["horse_whinny", 1.0, 0.0],
	# c11b_02-12: the fantastic creatures, made from existing voices at other pitches
	"moon_moo": ["moo", 1.25, -2.0], "hare_thump": ["thump", 1.2, -1.0], "jelly_hum": ["bubble", 0.8, -4.0],
	"seahorse_click": ["bubble", 1.4, -3.0], "seacalf_hum": ["moo", 0.8, -3.0], "otter_chirp": ["critter", 1.4, -2.0],
	"newt_crackle": ["critter", 0.8, -3.0], "cloud_baa": ["sheep", 1.2, -2.0], "roc_peep": ["peep", 0.7, -1.0],
	"roc_cry": ["seagull", 0.75, -2.0], "moth_flutter": ["bug", 1.2, -4.0], "yak_grunt": ["moo", 0.7, -2.0],
	"glowworm_chime": ["sparkle", 1.3, -6.0], "wyrm_chirp": ["peep", 0.6, -2.0], "fox_yip": ["bark", 1.4, -3.0],
	"crystal_cluck": ["cluck", 1.15, -1.0], "gecko_chirp": ["critter", 1.6, -3.0], "star_baa": ["sheep", 1.1, -2.0],
	# exotics
	"alpaca_hum": ["bleat", 0.85, -3.0], "buffalo_low": ["moo", 0.75, -1.0], "emu_drum": ["frog", 0.6, -2.0],
	"ostrich_boom": ["frog", 0.5, -2.0], "komodo_hiss": ["critter", 0.6, -3.0], "peacock_call": ["seagull", 1.2, -2.0],
	"tortoise_hum": ["thump", 0.7, -4.0], "yak_low": ["moo", 0.7, -2.0],
}

## Species with no ranch.json voice yet (the C11b species, until gen_ranch carries a voice for each).
const SPECIES_VOICE := {
	"alpaca": "alpaca_hum", "buffalo": "buffalo_low", "emu": "emu_drum", "komodo": "komodo_hiss", "ostrich": "ostrich_boom",
	"peacock": "peacock_call", "snow_yak": "yak_grunt", "tortoise": "tortoise_hum",
	"aurora_fox": "fox_yip", "cloud_sheep": "cloud_baa", "coral_seahorse": "seahorse_click", "crystal_hen": "crystal_cluck",
	"deep_glowworm": "glowworm_chime", "ember_newt": "newt_crackle", "frost_otter": "otter_chirp", "frost_wyrmling": "wyrm_chirp",
	"glow_gecko": "gecko_chirp", "kelp_calf": "seacalf_hum", "lantern_moth": "moth_flutter", "moon_cow": "moon_moo",
	"moon_hare": "hare_thump", "star_jelly": "jelly_hum", "star_sheep": "star_baa", "storm_roc": "roc_cry",
	# lab strains: the base animal's voice (the layer makes it "modified")
	"chrome_hen": "cluck", "chrome_runner": "emu_drum", "circuit_cow": "moo", "circuit_goat": "bleat", "drone_hog": "oink",
	"glow_sheep": "baa", "turbo_bunny": "thump", "volt_gecko": "gecko_chirp", "circuit_chick": "peep",
}

## Lab layers: [file, pitch, dB, delay s] played softly just after the base voice.
const LAYERS := {"lab_whirr": ["servo", 1.2, -9.0, 0.06], "lab_bleep": ["beep", 1.3, -9.0, 0.06]}

## Moment -> [pitch multiplier, dB]; hurt is soft and cartoonish (all ages).
const MOMENTS := {"call": [1.0, 0.0], "happy": [1.08, -1.0], "hurt": [1.1, -4.0], "attack": [0.95, 0.0]}
const HURT_GAP := 0.8

static var _alias: Dictionary = {}   # art kind -> species
static var _family: Dictionary = {}  # species -> C11b family (exotics / fantastic / lab)
static var _hurt_t: Dictionary = {}  # key -> PlayClock time of the last hurt voice


static func _load_alias() -> void:
	if not _alias.is_empty():
		return
	for path: String in ["res://art/gen/animals/_ranch_art.json", "res://art/gen/animals/_ranch_art_c11b.json"]:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var v: Variant = JSON.parse_string(f.get_as_text())
		if not (v is Dictionary):
			continue
		for sp: String in (v as Dictionary):
			if sp.begins_with("_") or not ((v as Dictionary)[sp] is Dictionary):
				continue
			var row: Dictionary = (v as Dictionary)[sp]
			_alias[sp] = sp
			if str(row.get("family", "")) != "":
				_family[sp] = str(row["family"])
			for k in [str(row.get("kind", "")), str(row.get("baby", "")), str(row.get("shorn", ""))]:
				if k != "" and not _alias.has(k):
					_alias[k] = sp
			for k in (row.get("height", {}) as Dictionary):
				if not _alias.has(str(k)):
					_alias[str(k)] = sp
			for k in (row.get("alias", {}) as Dictionary):
				if not _alias.has(str(k)):
					_alias[str(k)] = sp
	if _alias.is_empty():
		_alias["_"] = ""


## The species a kind/strip/uid belongs to ("" = unknown).
static func species_of(kind: String) -> String:
	if not Ranch.animal(kind).is_empty():
		return str(Ranch.animal(kind).get("species", ""))
	if not Ranch.species(kind).is_empty() or SPECIES_VOICE.has(kind):
		return kind
	_load_alias()
	return str(_alias.get(kind, ""))


## The voice id of a kind ("" = unknown: callers fall back).
static func voice_id(kind: String) -> String:
	var sp := species_of(kind)
	if sp == "":
		return ""
	var v := str(Ranch.species(sp).get("voice", ""))
	if v == "" or not VOICE_FILES.has(v):
		v = str(SPECIES_VOICE.get(sp, v))
	return v if VOICE_FILES.has(v) else ""


## The sound file a kind's voice plays ("" = unknown).
static func file_of(kind: String) -> String:
	var v := voice_id(kind)
	return str((VOICE_FILES[v] as Array)[0]) if v != "" else ""


## The lab layer of a species ("" = none): ranch.json voice_layer, else C11b family "lab".
static func layer_of(kind: String) -> String:
	var sp := species_of(kind)
	if sp == "":
		return ""
	var l := str(Ranch.species(sp).get("voice_layer", ""))
	if LAYERS.has(l):
		return l
	_load_alias()
	if str(_family.get(sp, "")) == "lab":
		return "lab_bleep" if absi(hash(sp)) % 2 == 1 else "lab_whirr"
	return ""


## Play a kind's voice for a moment. Returns false when nothing played (rate cap, unknown kind
## with no fallback). fallback: a file used when the kind is unknown.
static func say(tree: SceneTree, kind: String, moment := "call", fallback := "pickup") -> bool:
	if tree == null:
		return false
	var mus := Music.instance(tree)
	if mus == null:
		return false
	if moment == "down":
		mus.sfx("whimper", "pickup")
		return true
	if moment == "hurt":
		var now := PlayClock.now()
		if now - float(_hurt_t.get(kind, -100.0)) < HURT_GAP:
			return false
		_hurt_t[kind] = now
	var v := voice_id(kind)
	var m: Array = MOMENTS.get(moment, [1.0, 0.0])
	if v == "":
		if fallback == "":
			return false
		mus.sfx_pitched(fallback, "pickup", float(m[0]), float(m[1]))
		return true
	var row: Array = VOICE_FILES[v]
	mus.sfx_pitched(str(row[0]), fallback, float(row[1]) * float(m[0]), float(row[2]) + float(m[1]))
	var l := layer_of(kind)
	if l != "":
		var lr: Array = LAYERS[l]
		mus.sfx_pitched(str(lr[0]), "", float(lr[1]), float(lr[2]) + float(m[1]), float(lr[3]))
	return true


## Every sound file this table can play (tools/sfx_audit.py reads the same constants).
static func all_files() -> Array:
	var out: Array = []
	for v in VOICE_FILES.values():
		if not str(v[0]) in out:
			out.append(str(v[0]))
	for v in LAYERS.values():
		if not str(v[0]) in out:
			out.append(str(v[0]))
	return out
