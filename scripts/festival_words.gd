class_name FestivalWords
extends RefCounted
## Festival words for the town plaza (C12 P3): hosts who left town are replaced,
## arc voice (crystals / cash) and time of day (no night sky at noon).

## C12 P3: a festival host who has left town (gangster story: posy_gone, lumi_gone) is
## replaced by someone who is still here, like the Star Festival's Bram swap.
const FEST_FALLBACK := {"Posy": "Hazel", "Lumi": "Theo", "Hazel": "Maple", "Bram": "Maple", "Benno": "Hazel"}


static func fest_host(nm: String) -> String:
	var fl: Dictionary = GameState.run.get("flags", {})
	var tries := 0
	while fl.has(nm.to_lower() + "_gone") and FEST_FALLBACK.has(nm) and tries < 4:
		nm = str(FEST_FALLBACK[nm])
		tries += 1
	return nm


## C12 P3 festival words: arc voice and time of day.
const EGG_COUNT := 12


static func egg_call() -> String:
	if GameState.is_penguins():
		return "The egg hunt! Twelve eggs hidden round the plaza. Find them before the kids do."
	return "Egg hunt. Twelve hidden round the plaza. The kids are fast and they don't play fair."


static func egg_prize_text() -> String:
	if GameState.is_penguins():
		return "Every last egg! Mayor Alder hands you %s and a sticky handful of candy." % Money.amount(200)
	return "Every last egg. Alder peels %s off his own roll." % Money.amount(200)


static func lantern_tail() -> String:
	return " The sky fills." if GameState.is_night() else " Later tonight the whole river will be lit."


static func star_call() -> String:
	if GameState.is_night():
		return "Now look up and make a star-wish. Just one. The sky's listening tonight." if GameState.is_penguins() else "One wish. Look up. Even this block gets stars tonight."
	return "Make a star-wish. Just one. The stars are up there even now; they're listening." if GameState.is_penguins() else "One wish. The stars are up there even in daylight. Make it count."
