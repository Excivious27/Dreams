class_name PadFocus
extends RefCounted
## Focus navigation for Button-built screens (C9 P1). A screen opts in with
## PadFocus.enter(root) when it opens (and PadFocus.refresh(root) after it
## rebuilds its buttons); PadFocus.leave(root) when it closes. While a pad or
## keyboard is the device: every visible BaseButton under root can take focus,
## the first (or the one focused before the rebuild, matched by text/name) is
## focused, Godot's ui_* actions move focus (d-pad / stick / arrows), pad A or
## Enter presses (InputSetup adds pad A/B to ui_accept/ui_cancel), the focused
## button is lit and scrolled into view. On touch nothing changes.

const LIT := Color(1.25, 1.18, 0.85)
const META_ROOT := "pad_focus_root"
const META_WAS := "pf_was_none"


static func wants_focus() -> bool:
	return PadInput.device_kind() != "touch"


static func enter(root: Control, first: Control = null) -> void:
	if root == null:
		return
	root.set_meta(META_ROOT, true)
	if not wants_focus():
		return
	var btns := buttons(root)
	for b: BaseButton in btns:
		_arm(b)
	var pick: Control = first if first != null and first in btns else null
	if pick == null:
		var key := str(root.get_meta("pf_last", ""))
		for b: BaseButton in btns:
			if key != "" and _key(b) == key:
				pick = b
				break
	if pick == null and not btns.is_empty():
		pick = btns[0]
	if pick != null and pick.is_inside_tree():
		pick.grab_focus()


## After a screen rebuilt its rows: arm the new buttons, keep the place.
static func refresh(root: Control) -> void:
	if root == null:
		return
	var f := root.get_viewport().gui_get_focus_owner() if root.is_inside_tree() else null
	if f != null and root.is_ancestor_of(f):
		root.set_meta("pf_last", _key(f))
	enter(root)


static func leave(root: Control) -> void:
	if root == null:
		return
	if root.has_meta(META_ROOT):
		root.remove_meta(META_ROOT)
	for b: BaseButton in buttons(root, false):
		if b.has_meta(META_WAS):
			b.focus_mode = Control.FOCUS_NONE
			b.remove_meta(META_WAS)
		if b.has_focus():
			b.release_focus()


## True when a Control sits under a PadFocus screen (PadInput leaves its focus).
static func owns(c: Node) -> bool:
	var n := c
	while n != null:
		if n.has_meta(META_ROOT):
			return true
		n = n.get_parent()
	return false


static func buttons(root: Node, visible_only := true) -> Array:
	var out: Array = []
	_collect(root, out, visible_only)
	return out


static func _collect(n: Node, out: Array, visible_only: bool) -> void:
	for ch in n.get_children():
		if ch is CanvasItem and visible_only and not (ch as CanvasItem).visible:
			continue
		if ch is BaseButton and not (visible_only and (ch as BaseButton).disabled):
			out.append(ch)
		_collect(ch, out, visible_only)


static func _key(c: Control) -> String:
	if c is Button and (c as Button).text != "":
		return "t:" + (c as Button).text
	return "n:" + str(c.name)


static func _arm(b: BaseButton) -> void:
	if b.focus_mode == Control.FOCUS_NONE:
		b.focus_mode = Control.FOCUS_ALL
		b.set_meta(META_WAS, true)
	if not b.focus_entered.is_connected(_lit.bind(b, true)):
		b.focus_entered.connect(_lit.bind(b, true))
		b.focus_exited.connect(_lit.bind(b, false))


static func _lit(b: BaseButton, on: bool) -> void:
	if not is_instance_valid(b):
		return
	b.self_modulate = LIT if on else Color.WHITE
	if on:
		var p := b.get_parent()
		while p != null:
			if p is ScrollContainer:
				(p as ScrollContainer).ensure_control_visible(b)
				break
			p = p.get_parent()
