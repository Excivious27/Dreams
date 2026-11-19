extends Node
## Autoload: keeps the cash Translation (scripts/money_tr.gd) registered while
## the game runs, and removes it on exit (a script Translation left in the
## TranslationServer crashes Godot at shutdown).

var _tr: Translation


func _enter_tree() -> void:
	_tr = load("res://scripts/money_tr.gd").new()
	_tr.locale = TranslationServer.get_locale()
	TranslationServer.add_translation(_tr)


func _exit_tree() -> void:
	if _tr:
		TranslationServer.remove_translation(_tr)
		_tr = null
