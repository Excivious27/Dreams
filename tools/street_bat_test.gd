extends SceneTree
## C3 P6: the gangster arc's Street Bat (starter weapon named/drawn as a bat,
## same "sword" id underneath) and gun sounds by the gun in hand.
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	GameState.new_run("gangsters", "pax", "Pax", "Dreamhollow", "Biscuit")
	check(GameState.has_tool("sword") and (GameState.run["toolbar"] as Array).has("sword"), "gang: starter weapon on the toolbar")
	check(GameState.item_name("sword") == "Street Bat", "gang: it's a Street Bat (%s)" % GameState.item_name("sword"))
	check(Hud.icon_for("sword") == "bat_wood" and Art.has("items", "bat_wood"), "gang: bat icon (%s)" % Hud.icon_for("sword"))
	GameState.run["tool_tier"] = {"sword": 2}
	check(GameState.item_name("sword") == "Iron Street Bat" and Hud.icon_for("sword") == "bat_iron", "gang: tiers name and draw the bat (%s)" % GameState.item_name("sword"))
	for t in GameState.TOOL_TIERS:
		check(Art.has("items", "bat_" + t), "bat art for tier %s" % t)
	check(GameState.weapon_word() == "bat", "gang hints say bat")
	GameState.new_run("penguins", "kairi", "Kairi", "Dreamhollow", "Biscuit")
	check(GameState.item_name("sword") == "Wooden Sword" and Hud.icon_for("sword") == "sword_wood", "penguins keep the Wooden Sword")
	check(Player.gun_sound("scattergun") == "shot_shotgun" and Player.gun_sound("tommy_gun") == "shot_rifle" and Player.gun_sound("six_shooter") == "shot", "gun sounds follow the gun in hand")
	# Money in counts in earned_total, by source (c3_08 #9).
	var e0 := int(GameState.run.get("earned_total", 0))
	GameState.add_money(120, "campaign")
	GameState.add_money(-50, "spend")
	check(int(GameState.run["earned_total"]) == e0 + 120 and int(GameState.run["earned_by"]["campaign"]) == 120, "add_money counts payouts in earned_total, not spending")
	print("street_bat_test: %d fails" % fails)
	quit(1 if fails > 0 else 0)
