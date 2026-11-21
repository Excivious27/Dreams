#!/usr/bin/env python3
"""Writes data/side_stories.json: the side stories Tom approved (Guide 11 #20-26,
HANDOFF 2026-11-19 17:12 "21-28 all side stories yes"). Run by SideStory
(scripts/side_story.gd) from villager/crew talk, after the story and heart scenes.

Chain fields:
  id, arc ("penguins"/"gangsters"), title, when (GameState._cond_ok conditions to start),
  steps: [{giver, lines, [need: [item, n], ask: lines said while you lack it],
           [choice: {prompt, options, flag}] (the last option is the way out: step waits),
           [give: [item, n]], [money: n], [friend: [id, n]], [flag: name], hint, [done_hint]}]
Steps run in order, at most one per day per chain; each step's hint goes in the
journal as the next thing to do; a need step's done_hint replaces its ask once
handed in (it names the next giver; c12_10-01). Closing lines promise nothing the
game doesn't show yet (c12_10-02). Done flags: ss_<chain>_<i>; ss_<chain>_done at the end.
Hooks still to build on the flags (C11/C14): ss_babies_named + flags.ss_baby_names
(battle helper names), ss_jim_cave (highland cave pocket), ss_vault_open (vault
interior under the hall), ss_commander_home (Tomas home at the lake: a villager later)."""
import json

def L(who, *texts):
    return [{"who": who, "text": t} for t in texts]

def N(*texts):
    return L("", *texts)

C = []

def chain(id, arc, title, when, steps):
    C.append({"id": id, "arc": arc, "title": title, "when": when, "steps": steps})

# 20 — The crystal babies grow up (penguins)
chain("babies", "penguins", "The crystal babies grow up", {"flag": "st_p3_coldy"}, [
    {"giver": "catkins",
     "lines": N("Three small crystal babies are tumbling over each other at Catkins' feet, chiming like wind bells.") + L("Catkins", "Coldy's little ones followed her down the mountain. They're not cursed any more, just loud. They need names. Real ones; 'Oi, you' doesn't count."),
     "choice": {"prompt": "Name the three babies?", "options": ["Glimmer, Pebble and Hum", "Frost, Spark and Twinkle", "Bell, Button and Moss", "Not yet"], "flag": "ss_baby_names"},
     "flag": "ss_babies_named", "hint": "The crystal babies have names. Come back to Catkins tomorrow."},
    {"giver": "catkins",
     "lines": L("Catkins", "They want to help. Guard the meadow, chase off Grumps, show off. Mostly show off.", "Crystals grow strong on light. Bring me two Light Motes and I'll teach them to shine on purpose."),
     "need": ["light_mote", 2],
     "ask": L("Catkins", "Two Light Motes. The deep floors of the mine shed them, and the moon has a few lying about."),
     "hint": "Bring Catkins 2 Light Motes for the crystal babies.",
     "done_hint": "Catkins is teaching the babies to shine. See her in the meadow tomorrow."},
    {"giver": "catkins",
     "lines": N("The babies line up in a row, glowing steadily, almost serious. One of them hiccups a spark.") + L("Catkins", "They'll keep the meadow bright while you're away. Little guards with big hearts. Like someone else I know.", "Heart at the chest. They learned that first. I didn't teach them; they watched you."),
     "give": ["light_mote", 1], "friend": ["catkins", 30], "flag": "ss_babies_helpers", "hint": ""},
])

# 21 — Big Jim's brother (penguins)
chain("jim_brother", "penguins", "Big Jim's brother", {"flag": "st_p3_campfire"}, [
    {"giver": "granite",
     "lines": L("Granite", "Your big friend, the penguin who doesn't fight. Years back, one just like him came through the quarry. Bigger, if you can believe it. Asked the way to the highlands.", "Said he was going to find where the sky starts. Left a fish on my desk as thanks. I didn't have the heart to say I don't eat fish."),
     "hint": "Granite saw a huge penguin head for the highlands years ago. Ask Big Jim's friends in town: Sel reads old marks."},
    {"giver": "sel",
     "lines": L("Sel", "A penguin carving? Above the quarry's top shelf there's a mark nobody's read. Webbed feet, a fire, an arrow pointing up.", "Bring me five stone so I can make a rubbing board, and I'll tell you what it says."),
     "need": ["stone", 5],
     "ask": L("Sel", "Five stone. For the rubbing board. Science is mostly carrying things."),
     "hint": "Bring Sel 5 Stone to read the penguin carving.",
     "done_hint": "Sel is reading the carving. Come back to Sel tomorrow."},
    {"giver": "sel",
     "lines": L("Sel", "It says: 'Gone to see the sky. Tell Jim the fire's still lit.' And under it, a little drawing of a cave mouth, high up, behind a waterfall on Mount Prismatica.", "Somebody waited a long time for somebody to read that. Next time Big Jim sits by your fire, tell him. He'll know what it means."),
     "money": 150, "friend": ["sel", 20], "flag": "ss_jim_cave", "hint": ""},
])

# 22 — Coldy's key (penguins)
chain("coldy_key", "penguins", "Coldy's key", {"flag": "st_p3_coldy"}, [
    {"giver": "alder",
     "lines": L("Alder", "Odd thing. The oldest town plans show a little room under the hall. A vault, with a lock drawn like a snowflake. Nobody's had a key in living memory.", "Your friend Coldy wears a key like a snowflake. I'm a mayor, not a detective, but I can count to two."),
     "hint": "Alder thinks Coldy's sacred key fits a vault under the town hall. Theo keeps the old records."},
    {"giver": "theo",
     "lines": L("Theo", "The vault! There's a note in the founders' ledger: 'Sealed by the cold folk of the mountain, to keep what the town will need when it forgets.'", "The ledger's water-stained. An old coin was pressed in the page as a bookmark, the same mint as the vault door. Bring me two old coins and I can match the date."),
     "need": ["old_coin", 2],
     "ask": L("Theo", "Two old coins. Sel trades them at the ruins camp, and they turn up when you dig out in the wild places."),
     "hint": "Bring Theo 2 Old Coins (Sel sells them) to date the vault.",
     "done_hint": "Theo dated the vault: it really is Coldy's lock. Take the news to Mayor Alder at the town hall tomorrow."},
    {"giver": "alder",
     "lines": N("Coldy's key turns in the snowflake lock with a sound like ice cracking on a pond. The little room smells of cold stone and old paper.") + L("Alder", "The town's first bell rope. A bundle of seed packets, still good. And a letter: 'If you are reading this, you remembered. Ring the bell.'", "Twenty-one years we forgot. I'll hang it the day the bell has a clapper again."),
     "give": ["gold_bar", 1], "friend": ["alder", 20], "flag": "ss_vault_open", "hint": "",
     # c11b_04-06: a snow duck nesting in the cold vault goes home with you.
     "animal": {"species": "duck", "variant": "snow", "name": "Frost", "keepsake": True, "toast": "A snow duck was nesting in the cold vault. She's coming to your coop."}},
])

# 23 — The Wastes Commander (penguins). He left Tomas's locket where he fell
# (p2_locket): the Commander was Tomas, Finn's brother, changed in the river cities.
chain("commander", "penguins", "The Wastes Commander", {"flag": "boss_wastes"}, [
    {"giver": "finn",
     "lines": L("Finn", "Someone's been leaving fish on the end of my jetty. At night. Pike, gutted the way Tomas used to, badly, from the wrong end.", "Nobody else does it that badly. Nobody. I sat up last night and nobody came. Marlowe sees the whole shore from the lamp; ask him?"),
     "hint": "Someone leaves pike on Finn's jetty at night. Ask Marlowe what he sees from the lighthouse."},
    {"giver": "marlowe",
     "lines": L("Marlowe", "A thin fellow in grey rags. Walks the shore after dark, stands by Finn's boat, never knocks. Walks like he's carrying armour that isn't there any more.", "He's lost, not bad. Lost people need a light to walk toward. I've the lanterns; I'm short on oil. Two flasks and I'll hang them down the jetty."),
     "need": ["lamp_oil", 2],
     "ask": L("Marlowe", "Two flasks of lamp oil. I sell it at the lighthouse counter, if your purse is lighter than your conscience."),
     "hint": "Bring Marlowe 2 Lamp Oil (sold at the lighthouse) to light the jetty.",
     "done_hint": "Marlowe is hanging lanterns down Finn's jetty. Check on Finn at the lake tomorrow."},
    {"giver": "finn",
     "lines": N("Finn's boat is pulled up on the shore. Finn sits in it with a thin, tired man wrapped in a blanket, both of them looking at the lake.") + L("Finn", "He walked up the lanterns and sat in the boat. Didn't say anything for an hour. Then he said 'that's not the pike'.", "He doesn't remember much of the Wastes. Good. He remembers the dock. He's home. Tomas is home."),
     "money": 300, "friend": ["finn", 30], "flag": "ss_commander_home", "hint": ""},
])

# 24 — Mama Rosa's restaurant (gangsters)
chain("rosa", "gangsters", "Mama Rosa's restaurant", {"flag": "st_g2_rosa"}, [
    {"giver": "mama_rosa",
     "lines": L("Mama Rosa", "A man in a shiny suit came to my kitchen door. Bellamy. He runs the diner on the avenue. He wants to buy my place, and he wasn't asking nicely.", "I told him my kitchen is honest. Honest kitchens don't get sold, they get beaten. In a cook-off. Come back tomorrow; we start cooking."),
     "hint": "Mama Rosa challenged Bellamy to a cook-off. See her in her kitchen tomorrow to get ready."},
    {"giver": "mama_rosa",
     "lines": L("Mama Rosa", "My fish stew won my mother a husband and my grandmother a war. Bring me three trout, fresh, and I'll win us a street.", "Clean, mind. If I find a hook in one, you're washing pots."),
     "need": ["trout", 3],
     "ask": L("Mama Rosa", "Three trout. The river, the lake, wherever they're biting. Fresh!"),
     "hint": "Bring Mama Rosa 3 Trout for the cook-off.",
     "done_hint": "The trout are in. The cook-off is tomorrow: see Mama Rosa in her kitchen."},
    {"giver": "mama_rosa",
     "lines": N("The whole block crowds into Rosa's kitchen to taste. Bellamy takes one spoonful, puts the spoon down, and doesn't pick it up again.") + L("Mama Rosa", "He shook my hand. He's going to send his overflow to my kitchen now. Honest, see? Honest wins, it just needs a good stew behind it.", "You ever want a bowl, you come to my door. Nobody pays for it. Not you."),
     "money": 250, "flag": "ss_rosa_won", "hint": "",
     # c11b_04-06: two of Rosa's kitchen hens retire to your coop (RanchGift: they wait for room).
     "animal": {"species": "chicken", "count": 2, "toast": "Mama Rosa is sending two of her kitchen hens to your coop: they lay better in the country."}},
])

# 25 — The Kid's school (gangsters)
chain("kid_school", "gangsters", "The Kid's school", {"flag": "st_g4_kid"}, [
    {"giver": "the_kid",
     "lines": L("The Kid", "Don't laugh. I want to go back to school. Real school, with a bell and a desk and a teacher who's mean about spelling.", "But the road past the old schoolhouse is where the collectors park. Nobody's sending their kid past that."),
     "hint": "The Kid wants to go back to school. Ask Mayor Alder about making the road safe."},
    {"giver": "alder",
     "lines": L("Alder", "A safe crossing by the schoolhouse? I'd sign that today. A fence, a gate, a lamp. The council has no money for it, of course. The council never has money.", "Twenty planks and the town will build it. I'll stand there myself in the mornings if I have to."),
     "need": ["plank", 20],
     "ask": L("Alder", "Twenty planks for the school fence. A sawhorse on your farm turns two logs into a plank."),
     "hint": "Bring Mayor Alder 20 Planks for the school crossing.",
     "done_hint": "The school crossing is going up. Look for The Kid tomorrow."},
    {"giver": "the_kid",
     "lines": N("The Kid shows up at the gate in a clean shirt, hair flattened with water, a satchel that's clearly new.") + L("The Kid", "First day. The teacher's mean about spelling. It's the best.", "You didn't have to do that. You did it anyway. That's the kind of crew I want to be in."),
     "money": 150, "flag": "ss_kid_school", "hint": "",
     # c11b_04-06: the class rabbit comes to your hutch for good.
     "animal": {"species": "rabbit", "name": "Professor", "keepsake": True, "toast": "The class rabbit, Professor, is coming to live in your hutch for good."}},
])

# 26 — Specs and the wire (gangsters)
chain("specs_wire", "gangsters", "Specs and the wire", {"flag": "st_g3_specs"}, [
    {"giver": "specs",
     "lines": L("Specs", "I was tidying a wire I'm not supposed to have. Found a folder I'm not supposed to see. M.'s private files.", "Your name's in them, boss. Before you ever got to town. I'll need a day to read the rest without my hands shaking."),
     "hint": "Specs found M.'s files with your name in them. Give Specs a day."},
    {"giver": "specs",
     "lines": L("Specs", "M. picked you. The farm, the deed, the strawberry seeds. M. needed somebody who'd start out wanting to clean the city up and wouldn't notice what it cost them.", "And there's more. Every one of the President's lieutenants has a page with the same word on it: 'gifted'. Gifted with what, the file doesn't say. Their tricks aren't tricks, boss."),
     "hint": "Specs read M.'s files: every lieutenant is marked 'gifted'. Talk to Sal about it."},
    {"giver": "sal",
     "lines": L("Sal", "So M. chose you, and somebody chose them. Doesn't matter who chose. What matters is what you do with the part that's yours.", "You came here to take the gangs down, remember? Not to become one. You still can. I'd follow that version of you."),
     "friend": ["sal", 20], "flag": "ss_specs_files", "hint": ""},
])

# C15 P3 (c15_11-04): one seasonal chain per season, both arcs. The chain's "when"
# holds the season, so each step only plays in that season (a chain started late
# picks up again the next year).
chain("spring_beds", "", "Wren's spring beds", {"season": "spring", "day": 3}, [
    {"giver": "wren",
     "lines": L("Wren", "Spring's the only time the wildflowers along the lanes are worth picking for seed. I want a bed of them by my door this year.", "Bring me three wildflowers and I'll show you how to save their seeds."),
     "need": ["flower", 3],
     "ask": L("Wren", "Three wildflowers. They grow along the paths and the meadow edges in spring."),
     "hint": "Bring Wren 3 Wildflowers for her spring flower bed.",
     "done_hint": "Wren is planting her flower bed. See her again tomorrow."},
    {"giver": "wren",
     "lines": N("A neat new bed of wildflowers runs along Wren's doorstep, already buzzing.") + L("Wren", "Look at that. Bees by lunchtime. Here, a tea from last year's flowers. Next spring, these will be the seeds."),
     "give": ["tea", 2], "friend": ["wren", 20], "flag": "ss_spring_beds", "hint": ""},
])
chain("summer_shells", "", "Lumi's summer shells", {"season": "summer", "day": 3}, [
    {"giver": "lumi",
     "lines": L("Lumi", "I want to paint the beach with real shells pressed into the frame. The summer tide leaves the best ones.", "Two seashells, please. The prettier the better. I'm very picky. I'm sorry. I'm not sorry."),
     "need": ["seashell", 2],
     "ask": L("Lumi", "Two seashells from the shore. Summer tides bring them in."),
     "hint": "Bring Lumi 2 Seashells for her beach painting.",
     "done_hint": "Lumi is framing her beach painting. Visit her tomorrow."},
    {"giver": "lumi",
     "lines": N("The painting is all blues and gold, with your two shells set into the corners of the frame.") + L("Lumi", "It's done! It's going on the wall at the inn so everyone can see summer even in winter. Take this, you've earned a cool drink."),
     "give": ["energy_tea", 2], "friend": ["lumi", 20], "flag": "ss_summer_shells", "hint": ""},
])
chain("fall_soup", "", "Bram's fall soup", {"season": "fall", "day": 3}, [
    {"giver": "bram",
     "lines": L("Bram", "Every fall I make one pot of mushroom soup for the whole town. One. It's tradition and also all I have time for.", "Three mushrooms and I can start it. The woods are full of them this time of year."),
     "need": ["mushroom", 3],
     "ask": L("Bram", "Three mushrooms. Look under the trees after a fall rain."),
     "hint": "Bring Bram 3 Mushrooms for his fall soup.",
     "done_hint": "Bram's soup is simmering. Come back to the inn tomorrow."},
    {"giver": "bram",
     "lines": N("The whole inn smells of mushrooms and thyme. Bram ladles out bowl after bowl.") + L("Bram", "There. The town's fed and nobody's cold. Take a bowl home. Two, actually. You picked the mushrooms."),
     "give": ["pumpkin_soup", 2], "friend": ["bram", 20], "flag": "ss_fall_soup", "hint": ""},
])
chain("winter_tarts", "", "Posy's winter tarts", {"season": "winter", "day": 3}, [
    {"giver": "posy",
     "lines": L("Posy", "Frostberry tarts. Only in winter, only with real frostberries, and I've run out.", "Two frostberries and I'll bake a batch for the whole street. And one for you. Fine, two for you."),
     "need": ["frostberry", 2],
     "ask": L("Posy", "Two frostberries. They only grow in winter."),
     "hint": "Bring Posy 2 Frostberries for her winter tarts.",
     "done_hint": "Posy is baking frostberry tarts. Visit the bakery tomorrow."},
    {"giver": "posy",
     "lines": N("Trays of glossy purple tarts cool on every surface of the bakery.") + L("Posy", "The whole street's had one. Two people cried. Happy crying. Here, something warm to go with yours."),
     "give": ["hot_cocoa", 2], "friend": ["posy", 20], "flag": "ss_winter_tarts", "hint": ""},
])

# C10a P4: a chain's last step may hand over a home keepsake: data/decor.json "grants"
# "side:<chain id>": decor id (tools/gen_decor.py runs first). Only when the step has no
# give of its own (SideStory gives one item per step) and the id is in the catalogue.
try:
    DECOR = json.load(open("data/decor.json"))
except (OSError, ValueError):
    DECOR = {}
for ch in C:
    did = (DECOR.get("grants", {}) or {}).get("side:" + ch["id"], "")
    if did and did in (DECOR.get("items", {}) or {}) and "give" not in ch["steps"][-1]:
        ch["steps"][-1]["give"] = [did, 1]

json.dump({"_": __doc__.strip().splitlines()[0], "chains": C}, open("data/side_stories.json", "w"), indent=1, ensure_ascii=False)
print(len(C), "side stories,", sum(len(c["steps"]) for c in C), "steps")
