extends RefCounted
## C11b P6 (c11b_14-01/02, c11b_13-17): the voice of every C11b creature, one shared list.
## Names: classic farm voices (moo, cluck, sheep, bleat, oink, llama, thump) or cv_<group> files from
## tools/cc0_import.py (all ages: soft hoots, chirrs, burbles, snorts). Never an effect's name ("boom").
## Babies use their adult's voice. GameMap.animal_voice asks here first; ranch.json species.voice
## (gen_ranch.py) may name the same values.

const VOICES := {
	# exotics (both arcs)
	"ostrich": "cv_ostrich", "emu": "cv_emu", "komodo": "cv_komodo", "alpaca": "sheep", "buffalo": "moo",
	"peacock": "cv_sky", "snow_yak": "moo", "tortoise": "cv_komodo",
	# fantastic (penguin arc)
	"aurora_fox": "cv_frost", "cloud_sheep": "sheep", "coral_seahorse": "cv_merkitty", "crystal_hen": "cluck",
	"deep_glowworm": "cv_gloam", "ember_newt": "cv_komodo", "frost_otter": "cv_frost", "frost_wyrmling": "cv_frost",
	"glow_gecko": "cv_gloam", "kelp_calf": "cv_merkitty", "lantern_moth": "cv_gloam", "moon_cow": "cv_moon",
	"moon_hare": "cv_moon", "star_jelly": "cv_moon", "star_sheep": "cv_moon", "storm_roc": "cv_sky",
	# lab strains (gangster arc): their base animal's voice
	"chrome_hen": "cluck", "chrome_runner": "cv_ostrich", "circuit_cow": "moo", "circuit_goat": "bleat",
	"drone_hog": "oink", "glow_sheep": "sheep", "turbo_bunny": "thump", "volt_gecko": "cv_gloam",
}

## Night-active kinds (their voices carry after dark; the farm herd goes quiet).
const NIGHT := ["deep_glowworm", "glow_gecko", "lantern_moth", "moon_cow", "moon_hare", "star_jelly", "star_sheep", "aurora_fox"]


## The voice for a kind or strip name ("moon_cow", "moon_cow_baby", "moon_cow_mint"), "" if not a C11b kind.
static func voice(kind: String) -> String:
	var k := kind.to_lower()
	var best := ""
	for sp: String in VOICES:
		if (k == sp or k.begins_with(sp + "_")) and sp.length() > best.length():
			best = sp
	return str(VOICES[best]) if best != "" else ""


static func night_kind(kind: String) -> bool:
	for sp: String in NIGHT:
		if kind == sp or kind.begins_with(sp + "_"):
			return true
	return false
