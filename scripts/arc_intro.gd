class_name ArcIntro
extends RefCounted
## First use of an arc's own farm building: one short scene that says what it
## is for and how its loop works, so nobody has to guess (flag "arc_intro_<id>").
## Called from farm._station before the building's own menu opens.
##   who: the person who'd explain it. Crew members only speak once recruited;
##        until then the same words come from a note left on it.

const LINES := {
	"print_shop": {"who": "Specs", "crew": "specs", "lines": [
		"Blank stock and ink go in, bills come out. Make them here like anything else at a station.",
		"Then hold a bill and USE it in a town. Most tills take it. Some look twice: a noticed bill costs you a fine and adds heat.",
		"The streets only take a few a day. Want it safe instead? Wash them at a laundromat."]},
	"laundromat": {"who": "Deuce", "crew": "deuce", "lines": [
		"Passing bills is a coin flip with your face on it. Leave them here instead.",
		"Whatever's in the wash comes back as clean money in the morning, minus a cut. No risk, no heat. And heat cools a step faster with this running."]},
	"training": {"who": "Val", "crew": "val", "lines": [
		"Spar here once a day for combat practice. It wears you out, so pick your day.",
		"Grow this place and it's not just you: every recruit's perk counts a step higher."]},
	"soda": {"who": "Mama Rosa", "crew": "mama_rosa", "lines": [
		"A front needs a real queue. Mix root beer here and sell it like any good: honest money, no heat at all."]},
	"pool": {"who": "Mer", "lines": [
		"We merkitties swim up from the lake at night. Keep this pool and we'll leave you something from the deep each morning.",
		"Come and empty it now and then. The basket only holds so much, and when it's full we stop."]},
	"burrow": {"who": "Coldy", "lines": [
		"Bee bop! The babies dig all night and sleep all day. Whatever they find, they leave here for you.",
		"Collect it often. A full burrow means no more digging."]},
	"shrine": {"who": "Catkins", "lines": [
		"Practise here once a day, hands at your chest, like I showed you. Your mana comes back and the magic grows.",
		"As the shrine grows, your Meow Pow Wow grows stronger everywhere you go."]},
	"litter": {"who": "Catkins", "lines": [
		"Cat-topia's secret weapon. Make litter boxes here, then throw one in a fight: every Grump nearby stops to hold its nose."]},
	"campfire": {"who": "Big Jim", "lines": [
		"Toast things here. Marshmallows first, they're quick. Food from the fire gives you energy back on the road."]},
}


static func has_intro(id: String) -> bool:
	return LINES.has(id) and not GameState.run["flags"].has("arc_intro_" + id)


## The lines as a Dialogue script (no side effects).
static func script_for(id: String) -> Array:
	var e: Dictionary = LINES.get(id, {})
	if e.is_empty():
		return []
	var who := str(e.get("who", ""))
	var c := str(e.get("crew", ""))
	var spoken := c == "" or Crew.recruited(c)
	var out: Array = []
	if not spoken:
		out.append({"who": "", "text": "A note is tucked under the corner, in %s's hand:" % who})
	for t in e["lines"]:
		out.append({"who": who if spoken else "Note", "text": str(t)})
	return out


static func first(m: GameMap, id: String) -> void:
	if not has_intro(id):
		return
	GameState.run["flags"]["arc_intro_" + id] = true
	await m.say(script_for(id))
