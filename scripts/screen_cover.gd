class_name ScreenCover
extends RefCounted
## Full-screen opaque mini-games (arcade cabinets, bowling) cover the whole map, yet
## Godot still renders the world under them every frame (~70-110 draw calls in the
## Rec Center). While one is open, hide the map's world (its own CanvasItems; HUD
## layers are separate and unaffected). Counted, so a cabinet opened from the
## picker keeps the map hidden until the last screen closes. Same pixels on screen:
## the stretch aspect is "keep", so nothing of the map shows beside the screen.


## Call from the screen's _ready with its parent; returns what to pass to uncover().
static func cover(parent: Node) -> CanvasItem:
	var ci := parent as CanvasItem
	if ci == null or not (parent is GameMap):
		return null
	var n := int(ci.get_meta("screen_covers", 0))
	if n == 0:
		ci.set_meta("screen_cover_was", ci.visible)
		ci.visible = false
	ci.set_meta("screen_covers", n + 1)
	return ci


## Call from the screen's _exit_tree (safe twice: the counter only counts real covers).
static func uncover(ci: CanvasItem) -> void:
	if ci == null or not is_instance_valid(ci) or not ci.has_meta("screen_covers"):
		return
	var n := int(ci.get_meta("screen_covers", 1)) - 1
	if n > 0:
		ci.set_meta("screen_covers", n)
		return
	ci.remove_meta("screen_covers")
	ci.visible = bool(ci.get_meta("screen_cover_was", true))
	ci.remove_meta("screen_cover_was")
