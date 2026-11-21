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
	"fuk", "fuq", "phuck", "phuk", "biatch", "cocaine", "heroin", "molest", "pedo",
]
## C17 P5 (c17_17-06/-13): innocent names that contain a blocked piece ("Shitake", "Scunthorpe",
## "Ignazio"); these hosts are cut out before the substring tests.
const HOSTS := ["shitake", "scunthorpe", "ignazi", "dickens", "dickinson", "dickson", "benedick", "cockatoo", "cockatiel", "peacock",
	"woodcock", "hancock", "gamecock", "cocker", "cockle", "grape", "drape", "scrape", "trapez", "parapet", "rapeseed",
	"cucumber", "cumin", "cumulus", "circum", "acumen", "cumber", "cumbria", "document", "cockburn", "pussycat", "pussywillow", "skill", "booboo", "therapist"]
## Substrings that are never innocent once the hosts are cut ("BigDick", "cumlord", "rapeu").
const PIECES := ["dick", "cock", "rape", "pussy", "sexy", "cum", "boob"]
## Accents and look-alike letters folded to a-z first (fück, fυck, сука-style Cyrillic).
const FOLD := {"à": "a", "á": "a", "â": "a", "ã": "a", "ä": "a", "å": "a", "æ": "ae", "ç": "c", "è": "e", "é": "e", "ê": "e", "ë": "e",
	"ì": "i", "í": "i", "î": "i", "ï": "i", "ñ": "n", "ò": "o", "ó": "o", "ô": "o", "õ": "o", "ö": "o", "ø": "o", "ù": "u", "ú": "u",
	"û": "u", "ü": "u", "ý": "y", "ÿ": "y", "ß": "ss", "ś": "s", "š": "s", "ž": "z", "č": "c", "ł": "l",
	"α": "a", "β": "b", "ε": "e", "η": "n", "ι": "i", "κ": "k", "μ": "u", "ν": "v", "ο": "o", "ρ": "p", "τ": "t", "υ": "u", "χ": "x", "ω": "w",
	"а": "a", "в": "b", "е": "e", "ё": "e", "к": "k", "м": "m", "н": "h", "о": "o", "р": "p", "с": "c", "т": "t", "у": "y", "х": "x", "і": "i", "ѕ": "s", "ј": "j"}
## Whole words only: as substrings these hit innocent names ("Grape", "Peacock", "Prickles", "Skillet",
## "Cucumber", "Essex", "Dickens", "Booboo", "Pussycat", "Analise").
const WORDS := ["ass", "hoe", "rape", "cock", "dick", "prick", "kill", "sex", "sexy", "cum", "anal", "boob", "boobs",
	"tits", "nude", "piss", "pussy", "fag", "spic", "chink", "kike", "damn", "crap",
	"fck", "sht", "azz", "kys", "weed", "coke", "meth", "crack", "stoned", "drunk", "booze", "dope", "killer", "murder"]
## Whole tokens (digits kept): drug and mature numbers.
const NUMBERS := ["420", "69", "666"]
const LEET := {"0": "o", "1": "i", "!": "i", "3": "e", "4": "a", "@": "a", "5": "s", "$": "s", "7": "t", "8": "b", "9": "g", "+": "t", "|": "i"}


## Lower-case, leetspeak folded, everything but letters dropped ("F.u_C k" -> "fuck").
static func fold(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		out += str(FOLD.get(ch, ch))
	return out


static func squash(s: String) -> String:
	var out := ""
	for ch in fold(s):
		var c: String = LEET.get(ch, ch)
		if c >= "a" and c <= "z":
			out += c
	return out


## Lower-case words with leetspeak folded, split on anything that isn't a letter.
static func words(s: String) -> PackedStringArray:
	var t := ""
	for ch in fold(s):
		var c: String = LEET.get(ch, ch)
		t += c if (c >= "a" and c <= "z") else " "
	return t.split(" ", false)


## Words split also at camelCase and letter/digit edges, no leetspeak ("BigDick" -> big dick,
## "Weed420" -> weed 420), plus single letters joined ("A S S" -> ass).
static func parts(s: String) -> PackedStringArray:
	var t := ""
	var prev := ""
	for ch0 in s:
		var lo := ch0.to_lower()
		var ch := str(FOLD.get(lo, lo))
		var is_up := ch0 != lo
		var kind := "d" if (ch >= "0" and ch <= "9") else ("l" if (ch >= "a" and ch <= "z") else "")
		if kind == "":
			t += " "
		else:
			if prev != "" and (kind != prev or (is_up and prev == "l")):
				t += " "
			t += ch
		prev = kind
	var out := t.split(" ", false)
	var joined := ""
	var extra := PackedStringArray()
	for w in out:
		if w.length() == 1:
			joined += w
		else:
			if joined.length() > 1:
				extra.append(joined)
			joined = ""
	if joined.length() > 1:
		extra.append(joined)
	out.append_array(extra)
	return out


static func is_ok(s: String) -> bool:
	var sq := squash(s)
	for h in HOSTS:
		sq = sq.replace(h, "_")
	for pc in PIECES:
		if sq.contains(pc):
			return false
	for w in parts(s):
		if w in WORDS or w in NUMBERS:
			return false
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
