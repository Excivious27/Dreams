class_name ItemWords
## Plain English around item names (CONDUCT 7 P4): "3 Turnips", "4 Wood",
## "an Apple", "some Turnip Seeds". Item names in items.json are singular.

## Last words that never take a plural or an article ("4 Wood", "some Honey").
const MASS := ["wood", "stone", "hay", "flour", "honey", "milk", "coal", "clay", "fiber", "fibre",
	"sap", "bait", "goo", "linen", "cloth", "rice", "wool", "sugar", "salt", "cheese", "butter",
	"jam", "ore", "sand", "silk", "oil", "cream", "bread", "fertiliser", "fertilizer", "feed", "mayo",
	"syrup", "tea", "coffee", "cocoa", "juice", "water", "soup", "stew", "corn", "wheat", "kale",
	"lettuce", "spinach", "asparagus", "garlic", "celery", "dill", "parsley", "basil", "chives",
	"lemongrass", "moss", "glass", "slime", "dust", "ink", "paper", "chocolate", "candy", "fudge", "pie"]
## Names that end in s but are one thing ("a Crystal Lens").
const SINGLE_S := ["lens", "iris", "lotus", "edelweiss", "bass", "moss", "glass", "cactus", "hibiscus", "crocus", "octopus", "walrus"]
## Fish keep their name in the plural ("3 Bass", "2 Trout").
const SAME := ["bass", "trout", "salmon", "carp", "pike", "cod", "perch", "sardine", "tuna", "halibut", "squid", "shrimp", "deer", "sheep"]


static func _last(name: String) -> String:
	var parts := name.strip_edges().split(" ")
	return parts[parts.size() - 1].to_lower() if parts.size() > 0 else ""


static func is_plural(name: String) -> bool:
	var w := _last(name)
	return w.ends_with("s") and not w.ends_with("ss") and not (w in SINGLE_S) and not (w in MASS)


static func is_mass(name: String) -> bool:
	return _last(name) in MASS


## "Turnip" x3 -> "Turnips"; "Wood" -> "Wood"; "Strawberry" -> "Strawberries".
static func plural(name: String) -> String:
	var w := _last(name)
	if name == "" or is_plural(name) or is_mass(name) or w in SAME:
		return name
	if w.ends_with("y") and w.length() > 1 and not ("aeiou".contains(w[w.length() - 2])):
		return name.substr(0, name.length() - 1) + "ies"
	if w.ends_with("s") or w.ends_with("sh") or w.ends_with("ch") or w.ends_with("x") or w.ends_with("z") or w in ["potato", "tomato", "mango"]:
		return name + "es"
	if w.ends_with("leaf"):
		return name.substr(0, name.length() - 1) + "ves"
	return name + "s"


## "3 Turnips" / "1 Turnip" / "4 Wood".
static func count(name: String, n: int) -> String:
	return "%d %s" % [n, name if n == 1 else plural(name)]


## Same, from an item id.
static func count_id(id: String, n: int) -> String:
	return count(GameState.item_name(id), n)


## "an Apple", "a Carrot", "some Turnip Seeds", "some Honey".
static func with_article(name: String) -> String:
	if is_plural(name) or is_mass(name):
		return "some " + name
	var f := name.substr(0, 1).to_lower()
	return ("an " if "aeiou".contains(f) and f != "" else "a ") + name


## Fill {item} in a line, fixing a leading "A {item}"/"a {item}" article.
static func fill(text: String, name: String) -> String:
	var art := with_article(name)
	text = text.replace("A {item}", art.substr(0, 1).to_upper() + art.substr(1))
	text = text.replace("a {item}", art)
	return text.replace("{item}", name)
