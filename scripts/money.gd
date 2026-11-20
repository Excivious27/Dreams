class_name Money
extends RefCounted
## Arc-aware money. The penguin arc pays in crystals (◆); the gangster arc pays
## in CASH ($). Code keeps storing the amount in run["crystals"] (one number for
## both arcs); everything the player reads goes through here:
##  - Money.sym()/fmt(n)/word() for new strings,
##  - Money.t(text) rewrites any finished string (◆ -> $, "40 crystals" -> "$40"...),
##  - MoneyHook (autoload) installs Money.t as a Translation, so every Label,
##    Button and RichTextLabel shows cash in the gangster arc without each
##    caller remembering to convert. Custom draw_string calls use Money.t.

const PHRASES := [
	["a crystal a dozen", "a dime a dozen"],
	["loose crystals", "loose cash"],  # C7 (c7_08): penguin texts say crystals, never coins
	["I count crystals", "I count cash"],
	["Not enough crystals", "Not enough cash"],
	["not enough crystals", "not enough cash"],
	["paid in crystals", "paid in cash"],
	["pays you in crystals", "pays you in cash"],
	["interest on crystals", "interest on cash"],
	["dice: crystals", "dice: cash"],
	["I have crystals. Take them.", "I have cash. Take it."],
	["forty crystals", "forty bucks"],
	["Crystals for goods. Goods for crystals.", "Cash for goods. Goods for cash."],
	["small ◆ fee", "small cash fee"],
	["crystals in hand", "cash in hand"],
	["in shade. And crystals.", "in shade. And cash."],
	["Not enough crystals (", "Not enough cash ("],
]
## Exact whole-string labels.
const EXACT := {"Crystals": "Cash"}

## Sound swaps in the gangster arc (Music.sfx runs every name through sfx_name).
const SFX := {"coin": "cash_pickup"}
## The crystal arc pays in crystals: banknote/register cues become the coin chime.
const CRYSTAL_SFX := {"cash": "coin", "cash_register": "coin", "cash_pickup": "coin"}

## Shop price rules (C8 P6; GameState.buy_price/shop_price read them):
## a novice pays BUY_MARKUP x value; no shop sells below RESALE_FLOOR x what the
## piece sells for (perks and demand in, today's saturation out).
const BUY_MARKUP := 1.5
const RESALE_FLOOR := 1.15

static var _re_num_sym: RegEx
static var _re_sym: RegEx
static var _re_num_word: RegEx


static func sfx_name(name: String) -> String:
	if GameState.run.is_empty():
		return name
	return str(SFX.get(name, name)) if cash() else str(CRYSTAL_SFX.get(name, name))


static func cash() -> bool:
	return str(GameState.run.get("arc", "")) == "gangsters"


static func sym() -> String:
	return "$" if cash() else "◆"


static func fmt(n: int) -> String:
	return sym() + group(n)


## 1234567 -> "1,234,567" (year-2/3 sums stay readable; C8 P6).
static func group(n: int) -> String:
	var neg := n < 0
	var d := str(absi(n))
	var out := ""
	while d.length() > 3:
		out = "," + d.substr(d.length() - 3) + out
		d = d.substr(0, d.length() - 3)
	return ("-" if neg else "") + d + out


static func word() -> String:
	return "cash" if cash() else "crystals"


## An amount as words: "40 crystals" / "$40" (arcade tops, fees, prices).
static func amount(n: int) -> String:
	return ("$" + group(n)) if cash() else (group(n) + " crystals")


## A bare amount: "40" in the penguin arc (the word is around it), "$40" in cash.
static func num(n: int) -> String:
	return ("$" + group(n)) if cash() else group(n)


static func t(s: String) -> String:
	if not cash():
		return s
	return to_cash(s)


## The conversion itself (arc-independent, for tests).
static func to_cash(s: String) -> String:
	if s.is_empty() or (not s.contains("◆") and not s.contains("rystal")):
		return s
	if EXACT.has(s):
		return str(EXACT[s])
	if _re_num_sym == null:
		_re_num_sym = RegEx.create_from_string("(%d|%s|\\d+)\\s?◆")
		_re_sym = RegEx.create_from_string("◆\\s?")
		_re_num_word = RegEx.create_from_string("(\\+?)(\\d{1,3}(?:,\\d{3})+|\\d+|%d) crystals\\b")
	var out := s
	for p in PHRASES:
		out = out.replace(str(p[0]), str(p[1]))
	out = _re_num_sym.sub(out, "$$$1", true)
	out = _re_sym.sub(out, "$$", true)
	out = _re_num_word.sub(out, "$1$$$2", true)
	return out


## True when text still talks about crystals as money (used by tools/cash_test.gd).
static func looks_like_crystal_money(s: String) -> bool:
	if s.contains("◆"):
		return true
	var re := RegEx.create_from_string("(?i)(\\d+|%d|forty|enough|paid in|pays you in|interest on|dice:) crystals\\b|crystals (overnight|in hand|for goods)|\\bcrystal a dozen")
	return re.search(s) != null
