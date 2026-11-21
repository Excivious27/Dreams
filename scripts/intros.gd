class_name Intros
extends RefCounted
## First meetings (conduct 1, c1_11). The first time you talk to a townsperson
## they say who they are, what they do and where to find them, Stardew-style,
## before any of their everyday chatter. Town and interior talk both call
## Intros.talk() after the story gets its turn; a story beat on that first talk
## counts as the meeting. run.flags["met_<id>"] marks it.
##
## Per villager: "both" lines, or "pen" / "gang" for the arc's own version.
## %hero %pet %town are filled in.

const LINES := {
	"maple": {
		"pen": ["Oh! You're the one on the old plot! I'm Maple. Maple's Mercantile is mine, north of the plaza: seeds, fertiliser, bread, the odd backpack.", "Open seven till nine. I'm behind the counter mornings and afternoons; if I'm out at my market stall at lunch, leave the money on the till. Everyone does."],
		"gang": ["New face. I'm Maple, I run the Mercantile north of the plaza. Seeds on the left, bread by the door, and I don't ask names.", "Open seven till nine. If I'm not at the till, leave the money on it. People here are honest. Mostly."],
	},
	"gideon": {
		"pen": ["Gideon. Forge, next to Maple's. I fix tools, sharpen blades, and smelt ore if you bring it.", "Copper bars and a few crystals and your hoe comes back a better hoe. Next morning, not while you wait. Seven till nine; knock loud, I can't hear over the anvil."],
		"gang": ["Gideon. Forge, next to Maple's. I fix tools, sharpen blades, and smelt ore if you bring it.", "Copper bars and a little cash and your hoe comes back a better hoe. Next morning, not while you wait. Seven till nine; knock loud, I can't hear over the anvil."],
	},
	"wren": {
		"pen": ["You're new. And you've been near something odd: you've got a shimmer on you. I'm Wren. Potion shop, south-east of the plaza, the one that smells like burnt sugar.", "Red bottles mend you, green tea wakes you up. I'm in the shop from eight; afternoons I'm in my garden by the cottage, or at the pond."],
		"gang": ["I'm Wren. Potions, south-east of the plaza. You look like you'll need the red ones.", "Shop from eight, garden or the pond in the afternoon. I don't gossip about customers. It's bad for business and worse for customers."],
	},
	"alder": {
		"pen": ["Ah, our new farmer! Mayor Alder. The hall's north-east of the plaza; that's where projects get funded and the town gets built.", "Mornings I'm at the hall, evenings I'm usually at the inn pretending I'm not working."],
		"gang": ["Mayor Alder. The hall's north-east of the plaza. Permits, projects, the town ledger.", "I like a quiet town. You look like someone who also likes a quiet town. Let's both keep it that way."],
	},
	"sal": {
		"pen": ["Sal. Drifter. I wash up wherever it's quiet, and this was quiet. Mornings I'm on the bridge or down by the river; afternoons, the bench by the south gate.", "If something comes down that road that shouldn't, I'll see it first. I'll tell you. Probably."],
		"gang": ["...Sal. You've got the walk. I had it too. Mornings I'm by the river or on the bridge, afternoons on the bench by the south gate.", "Ask me things when you're ready to hear the answers. Not before."],
	},
	"finn": {
		"both": ["Finn! I fish. That's the whole job. The hut's up at the lake, through the forest from your farm: rods, bait, the best gossip in the valley.", "Here in town I'm on the river at dawn and dusk. Fish bite in the morning, people bite in the afternoon."],
	},
	"lumi": {
		"pen": ["Hi! Lumi. I paint. The sky's been doing the most beautiful wrong colours since you arrived.", "You'll find me sketching in the park or by the pond, or at the bandstand in the afternoon. Theo and I share the cottage on the south lane."],
		"gang": ["Lumi. I paint people. You've got an interesting face. That's not a compliment, it's a warning.", "Park, pond or the bandstand most days. I share the south-lane cottage with Theo."],
	},
	"theo": {
		"both": ["Theo, librarian. The library's south-east of the plaza; I'm there most of the day and I keep the town's records.", "If you find old coins or books, bring them. Books especially. Nobody brings books."],
	},
	"hazel": {
		"both": ["Another farmer! About time. Hazel; my farmhouse is down the south-west lane. I'm in the yard at dawn and at the market in the morning.", "Water before nine, plant what's in season, and don't till more than you can water. Ask me anything about crops, or hens: put up a coop and I've chicks looking for a home."],
	},
	"tess": {
		"pen": ["Hi! Tess. I'm the carpenter: the old warehouse up by the farm road is my workshop now.", "Chairs, beds, shelves, rugs, garden benches and lamp posts. Eight till six. New pieces come off the bench every few days, so come and look often."],
		"gang": ["Tess. Carpenter. I took the old warehouse by the farm road; the crews let me be because everyone needs a table.", "Furniture, rugs, things for your yard. Eight till six. New stock every few days. I don't ask what the back room's for."],
	},
	"bram": {
		"pen": ["Welcome, welcome! Bram, of Bram's inn, south-east of the plaza. Hot soup, a warm seat, and the door's open all day and most of the night.", "Come by in the evening. Half the town eats here, and the other half wishes they did."],
		"gang": ["Bram. The inn's south-east of the plaza, open all day, half the night. Soup's honest, the stories aren't.", "Evenings, half the town's in my dining room. Good place to listen, if you're a listener."],
	},
	"posy": {
		"both": ["Hello! Posy, the baker. The bakery's north of the plaza, past the hall; I'm up at four, the bread's out at seven.", "If you ever have spare flour or honey, I trade in pies. Very good pies."],
	},
	"juniper": {
		"both": ["Juniper. I'm the nurse; the clinic's over the bridge, across the river. Open seven to nine.", "If you push yourself until you fall over, someone will carry you to me. I'd rather you ate lunch."],
	},
	"rook": {
		"both": ["Rook. Hunter. My lodge is across the river, past the chapel. I sell what I trap and buy what you find.", "Dawn in the orchard, afternoons at the south gate. If you see big tracks, tell me. Don't follow them."],
	},
	"pip": {
		"both": ["I'm Pip! My mum is Maple. That makes me the store's, uh, assistant manager.", "School in the morning, then the fountain. If you've got candy I'll tell you a secret."],
	},
	"wren_jr": {
		"both": ["I'm Wren too but everyone calls me Wren jr. My mum makes the potions. I'm not allowed to touch the purple ones.", "After school I'm at the plaza or the pond. Do you have a dog? Is that your dog?"],
	},
	"tobin": {
		"both": ["Tobin. I live at the inn with Bram. I know every crab on the beach road by name.", "After school I'm on the beach road. Bring me a shell and I'll be your friend forever. Or till Thursday."],
	},
	"mabel": {
		"both": ["Hi. I'm Mabel. Hazel's my mum. I'm going to be a farmer too, but better.", "After school I'm in the park or at the bandstand. Your turnips look small. Mum says that's normal at first."],
	},
	"benno": {
		"both": ["Benno, stable hand. The stable's at the south end of the avenue, by the beach road. Horses, hay, and a saddle when you're ready for one.", "I'm with the horses most of the day; mornings I'm at the market for feed. Build a barn and I'll talk you through cows."],
	},
	"tam": {
		"pen": ["Tam. Shepherd. The hut up in the orchard hills is mine, and so are the sheep. They're all called Dolly. Saves time.", "Wool, cheese now and then, and advice about animals if you ask. Mornings I'm with the flock; evenings by the stove."],
		"gang": ["Tam. Shepherd, up in the orchard hills. Sheep don't care who you run with. Neither do I.", "Wool and cheese if you need them, and advice about animals if you ask. Mornings with the flock, evenings by the stove."],
	},
	"ivy": {
		"pen": ["Ivy, from the bank, at the top of the avenue by the farm road. Deposits, a little interest, very little excitement.", "Eight to five at the window. Lunch on the plaza bench, if you want to talk numbers. Nobody does."],
		"gang": ["Ivy. Bank teller, top of the avenue. I count other people's money and I'm very good at not seeing faces.", "Window's open eight to five. Lunch on the bench by the plaza. If anyone asks, we never spoke."],
	},
}


static func met(id: String) -> bool:
	return GameState.run.get("flags", {}).has("met_" + id)


static func mark(id: String) -> void:
	if not GameState.run.is_empty():
		GameState.run["flags"]["met_" + id] = true


static func lines_for(id: String) -> Array:
	var d: Dictionary = LINES.get(id, {})
	var arr: Array = d.get("both", d.get("pen" if GameState.is_penguins() else "gang", []))
	var name := str(GameState.npcs.get(id, {}).get("name", id.capitalize()))
	var names: Dictionary = GameState.names()
	var out: Array = []
	for t: String in arr:
		out.append({"who": name, "text": t.replace("%hero", str(names.get("character", ""))).replace("%pet", str(names.get("pet", ""))).replace("%town", str(names.get("town", "")))})
	return out


## The first meeting, once. True when it talked (the caller stops there).
static func talk(m: GameMap, id: String) -> bool:
	if met(id):
		return false
	mark(id)
	var lines := lines_for(id)
	if lines.is_empty():
		return false
	await m.say(lines)
	return true
