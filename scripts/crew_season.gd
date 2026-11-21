class_name CrewSeason
extends RefCounted
## C15 P4 (c15_15-04 / c15_16-05 / c15_16-22): the crew's seasonal, weather,
## festival and birthday lines, and the crew's birthdays (data/crew.json
## "birthday": [season, day]). Crew.talk mixes these into the everyday pool.
## All ages; nobody drinks.

const LINES := {
	"deuce": {
		"spring": ["Spring deck. Fresh cards, same old tricks.", "Rain on the tin roof. Good shuffling weather."],
		"summer": ["Boardwalk crowd's thick. Good night for a card trick or two.", "Too hot to bluff. Everyone sweats."],
		"fall": ["Leaves on the felt. I keep sweeping them off the table.", "Fall's when people bet like they mean it."],
		"winter": ["Cold hands, slow deal. Bring gloves.", "Snow on the docks. Quiet tables, honest games."],
		"festival": ["Festival day. I'm doing coin tricks for the kids. Free. Don't tell anyone."],
		"rain": ["Rain keeps the marks indoors. Card weather."],
		"birthday": ["My birthday? Who told you. ...Thanks, boss. Really."],
	},
	"mama_rosa": {
		"spring": ["Spring greens in the pot. Eat your vegetables.", "I planted basil out back. Touch it and you're cooking."],
		"summer": ["Too hot for stew? Then it's cold soup. Sit."],
		"fall": ["Pumpkin stew tonight. The whole crew. No excuses.", "Harvest time. Every crate I see, I see dinner."],
		"winter": ["Soup's on for the whole crew. Nobody eats cold on my watch.", "Snow outside, oven on inside. Sit by it."],
		"festival": ["Festival food is fine. Mine is better. Come back hungry."],
		"snow": ["Shake the snow off before you sit. My floor."],
		"birthday": ["A cake? For me? Who baked it? ...Not bad. Not bad at all."],
	},
	"specs": {
		"spring": ["Pollen in the server fans. Spring is my enemy.", "Spring storms flicker the wire. I love it."],
		"summer": ["Rigs run hot in summer. So do I.", "If you need me I'm next to the fan."],
		"fall": ["Fall patch day. Every lock in the city updates at once.", "Cooler air. The wire hums better."],
		"winter": ["Cold is great for the rigs. Terrible for my fingers.", "I wired fairy lights to the router. It blinks when we're online."],
		"festival": ["Festival lights are on my grid. Don't tell the city."],
		"birthday": ["You remembered? I didn't even put it on the wire."],
	},
	"ladder": {
		"spring": ["Spring. Seventeen pigeons on the roof. I named them.", "Rain on the road all morning. Trucks crawl."],
		"summer": ["Heat haze on the bridge. Hard to count cars.", "Clear summer sky. You can see the boats from the roof."],
		"fall": ["Leaves blowing past the lookout: too many to count. I tried.", "Fall sunsets. Best view in the city, up here."],
		"winter": ["Snow on the roof. I can see every footprint in the block.", "Cold up here. Clear, though. I can see the whole city."],
		"festival": ["From the roof the festival looks like a box of lights."],
		"snow": ["Footprints in the snow. Easy to count who came by."],
		"birthday": ["Birthday. One more number. Thanks for counting it."],
	},
	"vic": {
		"spring": ["Spring training. Val runs. I lift.", "Fresh season. We're ready."],
		"summer": ["Summer sparring on the roof. Val wins in the heat.", "Too hot for jackets. We wear them anyway."],
		"fall": ["Fall. Val likes the leaves. I like the cool.", "Left side's crunchy with leaves."],
		"winter": ["Snowball fight with Val. I won. Don't ask her.", "Cold sharpens you."],
		"festival": ["Festival duty. We stand by the stalls. Nobody misbehaves."],
		"birthday": ["Our birthday. Val gets the first slice. Always."],
	},
	"val": {
		"spring": ["Spring. Vic sneezes all season.", "Rain's good for running. Nobody else is out."],
		"summer": ["Summer heat. I win every sparring round.", "Vic says it's too hot. Vic says that every day."],
		"fall": ["I like the leaves. Don't tell Vic.", "Fall air. Best running weather."],
		"winter": ["Snowball fight. I won. Vic will lie about it.", "Ice on the roof. Watch your footing."],
		"festival": ["Festival's calm. We keep it that way."],
		"birthday": ["Our birthday. Same cake, two candles. Vic insists."],
	},
	"halo": {
		"spring": ["Spring rain. Roads are slick. I drive slow. Ish.", "Washed the car. Then it rained."],
		"summer": ["Windows down, boardwalk night. Hop in.", "Summer drives along the docks. Best time of year."],
		"fall": ["Leaves on the windscreen. Fall drives are pretty, I'll give it that.", "Fall roads. Watch the wet corners."],
		"winter": ["Snow tyres on. Still fastest car in the city.", "Engine takes a minute in the cold. So do I."],
		"festival": ["Festival traffic. I know the back way."],
		"snow": ["Snow day. I'll still drive. Slower. A bit."],
		"birthday": ["Birthday? I'm taking the long way home. On purpose."],
	},
	"dice": {
		"spring": ["Spring flyers everywhere. The Word says: Block Party, plaza, day 14.", "New season, new rumours. I've got three. Two are true."],
		"summer": ["Summer rumour: Harbour Lights at the marina. Neon all down the boardwalk.", "Heat makes people talk. I listen."],
		"fall": ["Fall rumour: Mask Night on the strip. Costumes, candy, lanterns.", "Harvest Hustle on the plaza, day 14. Food trucks. I'm going."],
		"winter": ["Winter word: the Gilt Gala uptown, late in the season. Dress sharp.", "Snowlight Street Party, day 14. Wish wall. I wished for quiet."],
		"festival": ["Festival day. Everyone's out. Everyone's talking. Heaven."],
		"birthday": ["My birthday? How did you... I'm the one who knows things. Rude. Thank you."],
	},
	"the_kid": {
		"spring": ["...spring.", "...rain's nice."],
		"summer": ["...ice cream?", "...hot."],
		"fall": ["...leaves.", "...jumped in a leaf pile. ...don't tell."],
		"winter": ["...snow!", "...built a snowman. ...it's you."],
		"festival": ["...festival. ...stay close?"],
		"birthday": ["...birthday. ...thanks."],
	},
	"doc": {
		"spring": ["Spring sniffles. Wash your hands.", "Pollen season. I have tissues. Take some."],
		"summer": ["Drink water. Wear a hat. That's the whole lecture.", "Summer scrapes from the boardwalk. Keep them clean."],
		"fall": ["Fall. Everyone forgets a coat. Don't.", "Cold season's coming. Sleep more."],
		"winter": ["Ice on the steps. I'll see three sprains this week.", "Wear a scarf. Doctor's orders."],
		"festival": ["Festival first-aid tent. Mostly sticky fingers and lost mittens."],
		"birthday": ["A birthday? Fine. One slice. Then rest."],
	},
	"marlene": {
		"spring": ["Spring prices. Everything's fresh, especially the markup.", "Rain ruins paper. Keep it dry, boss."],
		"summer": ["Summer trade's brisk. Tourists don't haggle.", "Boardwalk money moves fast. So do I."],
		"fall": ["Fall. Coats with deep pockets sell well.", "Harvest Hustle's good for business. Everyone's buying."],
		"winter": ["Gala season. Gold's up. So are my prices.", "Snow keeps the competition home."],
		"festival": ["No deals on a festival day. Even I take one off."],
		"birthday": ["My birthday is not a discount day. ...But thank you."],
	},
	"sasha": {
		"spring": ["Spring. Windows open. Easier.", "..."],
		"summer": ["Hot doors stick.", "Summer nights are short."],
		"fall": ["Fall. Leaves hide footsteps.", "..."],
		"winter": ["Cold locks freeze. I carry a lighter for them.", "Snow shows footprints. Careful."],
		"festival": ["Festival. Doors stay shut today."],
		"birthday": ["...birthday. Say nothing. ...Thanks."],
	},
}


## [season, day] of a crew member's birthday (data/crew.json), or [] if none.
static func birthday_of(id: String) -> Array:
	var b: Variant = (Crew.members().get(id, {}) as Dictionary).get("birthday", [])
	return b if b is Array and (b as Array).size() == 2 else []


## Crew members whose birthday falls on this season/day: [{id, name}] (Calendar merges these, P1).
static func birthdays_on(se: String, day: int) -> Array:
	var out: Array = []
	for id: String in Crew.members():
		var b := birthday_of(id)
		if not b.is_empty() and str(b[0]) == se and int(b[1]) == day:
			out.append({"id": id, "name": str(Crew.members()[id].get("name", id))})
	return out


static func is_birthday(id: String) -> bool:
	var b := birthday_of(id)
	return not b.is_empty() and str(b[0]) == GameState.season() and int(b[1]) == GameState.day_of_season()


## The seasonal line for today, or "" (birthday > festival > snow/rain > season).
static func line(id: String, day: int) -> String:
	var d: Dictionary = LINES.get(id, {})
	if d.is_empty():
		return ""
	var keys: Array = []
	if is_birthday(id):
		keys.append("birthday")
	if GameState.festival_today() != "":
		keys.append("festival")
	var wx := GameState.weather_today()
	if wx in ["snow", "blizzard"]:
		keys.append("snow")
	elif wx in ["rain", "storm"]:
		keys.append("rain")
	keys.append(GameState.season())
	for k: String in keys:
		var ls: Array = d.get(k, [])
		if not ls.is_empty():
			return str(ls[day % ls.size()])
	return ""


## Everyday pool with today's seasonal line mixed in: a birthday or festival line
## always shows; otherwise the season wins about two days in five.
static func mix(id: String, pool: Array, day: int) -> Array:
	var s := line(id, day)
	if s == "":
		return pool
	if is_birthday(id) or GameState.festival_today() != "" or day % 5 < 2:
		return [s]
	return pool
