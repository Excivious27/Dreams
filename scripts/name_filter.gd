class_name NameFilter
## All-ages word filter for every player-typed name other players can see (s1_13-03 / s1_13-10):
## character, town, pet and ranch animal names, and peers' names received over co-op.
## Static and data-free so title.gd, puppet.gd, team_animals.gd and net.gd can call it with a one-line hook:
##   if not NameFilter.is_ok(text): refuse with a friendly line / use NameFilter.clean(text, fallback)
## The list is short on purpose (common English profanity and slurs, leetspeak-normalised);
## server/server.js should mirror it when the relay package takes the hook.

const BLOCK := [
	"fuck", "shit", "bitch", "cunt", "asshole", "bastard", "slut", "whore", "nigg", "retard",
	"nazi", "hitler", "porn", "penis", "vagina", "wank", "twat", "kkk", "suicide", "dildo", "jizz",
]
## Whole words only: as substrings these hit innocent names ("Grape", "Peacock", "Prickles", "Skillet",
## "Cucumber", "Essex", "Dickens", "Booboo", "Pussycat", "Analise").
const WORDS := ["ass", "hoe", "rape", "cock", "dick", "prick", "kill", "sex", "sexy", "cum", "anal", "boob", "boobs",
	"tits", "nude", "piss", "pussy", "fag", "spic", "chink", "kike", "damn", "crap"]
const LEET := {"0": "o", "1": "i", "!": "i", "3": "e", "4": "a", "@": "a", "5": "s", "$": "s", "7": "t", "8": "b", "9": "g", "+": "t", "|": "i"}


## Lower-case, leetspeak folded, everything but letters dropped ("F.u_C k" -> "fuck").
static func squash(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		var c: String = LEET.get(ch, ch)
		if c >= "a" and c <= "z":
			out += c
	return out


## Lower-case words with leetspeak folded, split on anything that isn't a letter.
static func words(s: String) -> PackedStringArray:
	var t := ""
	for ch in s.to_lower():
		var c: String = LEET.get(ch, ch)
		t += c if (c >= "a" and c <= "z") else " "
	return t.split(" ", false)


static func is_ok(s: String) -> bool:
	var sq := squash(s)
	for b in BLOCK:
		if sq.contains(b):
			return false
	# collapse doubled letters ("fuuuck") and test again
	var dd := ""
	for ch in sq:
		if dd == "" or dd[dd.length() - 1] != ch:
			dd += ch
	for b in BLOCK:
		if dd.contains(b):
			return false
	for w in words(s):
		if w in WORDS:
			return false
	return true


## The name itself when clean, else `fallback` (a pool name, "Player", the species name).
static func clean(s: String, fallback: String = "Player") -> String:
	return s if is_ok(s) else fallback
