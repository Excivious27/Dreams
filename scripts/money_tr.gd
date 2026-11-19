extends Translation
## Installed by MoneyHook: rewrites crystal money to cash in the gangster arc
## for every auto-translated Control (Label, Button, RichTextLabel...).


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	if not Money.cash():
		return &""
	var s := String(src_message)
	var o := Money.to_cash(s)
	return StringName(o) if o != s else &""
