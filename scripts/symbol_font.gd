extends Node
## Autoload: adds fonts/symbols.ttf (◆ ♥ ★ ✓ ▶ ⚔ ☂ ... cut from DejaVu Sans by
## tools/make_symbol_font.py) as a fallback of the default font. Open Sans has
## none of these, and the web build has no system fonts to borrow them from, so
## without this they print as empty boxes on the phone.

const PATH := "res://fonts/symbols.ttf"


func _init() -> void:
	add_to(ThemeDB.fallback_font)


static func add_to(f: Font) -> void:
	if f == null or not ResourceLoader.exists(PATH):
		return
	var sym := load(PATH) as Font
	if sym == null or f.fallbacks.has(sym):
		return
	var fb := f.fallbacks.duplicate()
	fb.append(sym)
	f.fallbacks = fb
