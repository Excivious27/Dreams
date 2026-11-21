#!/usr/bin/env python3
"""Writes data/epilogue.json: the end slideshow (scripts/epilogue.gd).
One line per villager (close = 6+ hearts, else far), per crew member (loyal = 3,
else around), per companion kept, per colony, per lieutenant, per Marked, and per
story choice. %hero %pet %town are filled in.  Run: python3 tools/gen_epilogue.py
"""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V = {
 "maple": ("Maple started keeping a jar of the good seeds behind the counter, labelled with your name.", "Maple still marks up the nails. Some things don't change."),
 "gideon": ("Gideon hung your first broken hoe over the forge. He says it's a warning. It isn't.", "Gideon's hammer rings every morning, steady as a clock."),
 "wren": ("Wren names a potion after you. It tastes awful and works perfectly.", "Wren's window glows green late into the night, like always."),
 "alder": ("Mayor Alder gives a speech about you at the Harvest Fair. It runs long. You don't mind.", "Mayor Alder takes the credit for everything, which is how you know things are back to normal."),
 "sal": ("Sal stops drifting. There's a chair on your porch that's Sal's now.", "Sal moves on down the road one morning, and leaves a note that just says: thanks."),
 "finn": ("Finn teaches the kids to fish off the end of the pier, and swears your name is lucky.", "Finn still fishes from dawn to dusk, and still says the big one got away."),
 "lumi": ("Lumi paints %town as it is now. You're in the corner of it, small, watering something.", "Lumi's new paintings are brighter. Nobody asks why."),
 "theo": ("Theo finishes his book. The last chapter is about a farm.", "Theo is still writing the book. He'll finish it. Probably."),
 "hazel": ("Hazel and you swap seeds over the fence every spring, like neighbours have done forever.", "Hazel's rows are the straightest in the valley, and she'll tell you so."),
 "bram": ("Bram keeps a stool at the inn that nobody else sits on.", "The inn stays loud and warm, with or without you in it."),
 "posy": ("Posy's window has a new cake in it: a little farm made of sugar.", "Posy's bread is ready at six, every day, no matter what."),
 "juniper": ("Juniper says she's glad she hasn't had to patch you up in weeks. She means it as a compliment.", "Juniper's clinic stays open, quiet and ready."),
 "rook": ("Rook takes you up into the high woods once, to show you a place he's never shown anyone.", "Rook goes back to the woods, where he's happiest."),
 "pip": ("Pip tells everyone at school that you're her best friend. She is not wrong.", "Pip finds a new treasure every week and keeps them all in a shoebox."),
 "wren_jr": ("Wren jr's notebook of birds has a page just for you.", "Wren jr is still out in the meadow with binoculars, counting."),
 "tobin": ("Tobin's kite flies higher than the lighthouse. He says you taught him that.", "Tobin finally fixed his bike. He rides it everywhere."),
 "mabel": ("Mabel writes a song about the summer. You're in the second verse.", "Mabel reads under the big tree every afternoon."),
 "marlowe": ("Marlowe lets you light the lighthouse lamp, just once, on the longest night.", "The lighthouse turns every night, the way it always has."),
 "orla": ("Orla's mill grinds your wheat first, always.", "The mill wheel keeps turning, patient as Orla."),
 "benno": ("Benno says your horse is the happiest in the valley.", "Benno brushes the horses and hums."),
 "ivy": ("Ivy opens an account in your name with one crystal in it. 'For luck.'", "Ivy keeps the books balanced to the last crystal."),
 "tam": ("Tam's sheep follow you down the hill whenever you visit.", "Tam's flock grows bigger every spring."),
 "old_moss": ("Old Moss walks out of the marsh for the first time in years, to see your farm.", "Old Moss stays in his marsh, and that's how he likes it."),
 "granite": ("Granite carves your name on the quarry wall, next to the crew's.", "The quarry rings with picks from dawn to dusk."),
 "sel": ("Sel reads the last rune aloud with you there. It says: home.", "Sel is still out in the ruins, reading stones."),
 "catkins": ("Catkins sits on your fence at dusk and purrs the Meow Pow Wow, just quietly, for you.", "Catkins rules Cat-topia with a soft paw and a sharp eye."),
}
# Gangster arc: villager lines that read wrong there (cash money; Sal is crew).
V_GANG = {
 "ivy": ("Ivy opens an account in your name with one dollar in it. 'For luck.'", "Ivy keeps the books balanced to the last cent."),
}
# Skipped in the villager slide when Sal is crew/companion (he gets his own line there).
V_SKIP_IF_KNOWN = ["sal"]
# A companion line that replaces the usual one when a flag is set.
COMP_IF = {"penguin_f": ["knight_reverted", "Nova and Grandfather Auk fish off the end of the pier every morning. He still won't talk about the glass."],
           "penguin_m": ["knight_reverted", "Pip-Pip and Grandfather Auk argue about fishing every morning. Grandfather Auk wins."]}
CREW = {
 "deuce": ("Deuce runs a card-trick show uptown, tokens only, with your name on the chair beside his.", "Deuce takes his card-trick show three valleys over. He sends a postcard."),
 "mama_rosa": ("Mama Rosa's restaurant has a line round the block, and the first plate every night is yours.", "Mama Rosa feeds whoever comes in hungry."),
 "specs": ("Specs keeps the books honest now. Mostly.", "Specs found a quieter line of work."),
 "ladder": ("Ladder still watches the street from the rooftops, but now it's to warn the bakery about rain.", "Ladder climbs somewhere new every week."),
 "vic": ("Vic and Val run the gym under the pit, and the kids there call you boss.", "Vic went back to the pit, where things are simple."),
 "val": ("Val stands at your door some nights for no reason at all. Just in case.", "Val keeps an eye on the docks."),
 "halo": ("Halo's car is the fastest in the city, and it's always parked outside your farm.", "Halo drives off into the sunset. Literally. Show-off."),
 "dice": ("Dice runs the token arcade on the avenue. Everyone wins something.", "Dice rolls for whoever buys him lunch, and still owes the pawnbroker a postcard."),
 "the_kid": ("The Kid goes back to school. He comes by after, every day.", "The Kid runs messages across the city, faster than anyone."),
 "doc": ("Doc's free clinic opens with your name over the door.", "Doc patches people up and doesn't ask questions."),
 "marlene": ("Marlene burns her old ledger in your fireplace and laughs.", "Marlene's shop is still there, dark window, open door."),
 "sasha": ("Sasha teaches the Marked to open doors instead of forcing them.", "Sasha slipped away one night. She'll turn up again."),
}
# Vic without Val (Val never joined): his line can't name her.
CREW_SOLO = {"vic": ("Vic runs the gym under the pit, and the kids there call you boss.", "Vic went back to the pit, where things are simple."), "val_needs": "crew_val"}
# Threads the crew's loyalty scenes planted, paid off when that scene was seen
# (loyalty >= n). "not_ending": skipped in that ending.
CREW_THREADS = {
 "the_kid": [2, "The Kid's sister came down from the tower the morning after, still in her cleaner's uniform. Now there are two hoods on your fence after school.", "take"],
 "vic": [2, "Vic and Val's big brother came home the week the stone went quiet. He's quiet too, and he laughs at the wrong moments, and the twins don't let him out of their sight.", "take"],
 "specs": [3, "Specs went for the wire, like she said she would. The tower's cameras show nothing but rain now.", ""],
 "marlene": [3, "Marlene opened her safe one last time: a deed with your right name on it. It hangs over your fireplace, next to the one with his.", ""],
}
# C12 (c12_04-10): the loyal line when you took the chair (ending "take").
CREW_TAKE = {
 "halo": "Halo drives the long black car now. She never asks who's in the back. She used to promise herself she'd never drive for that tower again.",
 "doc": "Doc patches people in the tower basement again. He doesn't say anything about it. He doesn't have to.",
 "deuce": "Deuce deals at the tower's private tables now, straight as ever, and looks at you a beat too long when he shuffles.",
 "mama_rosa": "Mama Rosa still sends a plate up to the tower every night. It comes back half eaten.",
 "ladder": "Ladder counts the trucks going into your tower now. He's stopped saying the number out loud.",
 "dice": "Dice runs the token arcade on the avenue. Everyone wins something, and nobody asks who owns the machines.",
}
# The loyal line when a flag is set and that shop wasn't given back: [flag, text].
CREW_IF = {"ladder": ["shop_1", "Ladder still watches the street from the rooftops, but now it's to warn Mama Rosa about rain."]}
# C12 (c12_04-05): a flag line that changes (or goes, when "") with another flag
# (ending_<id> flags included): first match wins.
FLAG_ALT = {
 "hale_outrun": [["hale_has_stone", "You outran Inspector Hale once. The second time, you walked right up to her with the stone. She still can't decide which story to tell at parties."]],
 "hale_fooled": [["hale_has_stone", ""], ["hale_seen_neon", "Inspector Hale never did write you down as a farmer. She just stopped saying so out loud."]],
 "hale_friend": [["ending_take", "Inspector Hale stopped sending postcards. The last one was blank, which from her is a whole letter."]],
}
COMP = {
 "penguin_m": "Pip-Pip waddles the farm every morning like he owns it. He sort of does.",
 "penguin_f": "Nova keeps one piece of blue glass from the knight's armour on a shelf, and tells the story to anyone who'll sit still. She always ends it the same way: \"He's still up there. I'll find him.\"",
 "big_jim": "Big Jim still breaks the odd stump for you, and complains about it every single time.",
 "dad": "Dad fixes the fence before you notice it's broken, and pretends he was just passing.",
 "mom": "Mom's jam is on every shelf in the house, and her letters always end: come home for supper.",
 "mer": "Mer swims up the river to visit, and leaves shells on the porch.",
 "coldy": "Coldy and the crystal babies stamp around the field, keeping the dark away just by being there.",
 "pax": "Pax stays on as a farmhand and is secretly better at it than you.",
 "kairi": "Kairi plants a row of flowers by the gate, one for every friend you made.",
 "sal": "Sal keeps the porch light on.",
}
COLONY = {"colony_coral": "Coral Reach glows rose-gold again, and Grandmother Brine tells the story of the farmer who came by ferry.",
          "colony_kelp": "In Kelp Hollow, the old song is sung every evening, and the kelp stays green.",
          "colony_ice": "Frostfin Isle thawed, and Captain Icewhisker's boats are back out on the water.",
          "colony_ember": "On Emberclaw Atoll, the star crystal burns bright, and Lady Cinderpaw's glassblowers make you a gift every year."}
# Playing as a story character: lines that would talk about you in the third
# person ("Nova still goes looking for him") get a "you" version; "" drops it.
HERO_FLAG_LINES = {
 "penguin_f": {"auk_shard": "The knight's armour lies in pieces above the clouds, and Grandfather Auk waddled off into the high cloud. You still go looking for him, and some mornings you find fresh footprints.",
               "knight_reverted": "You and Grandfather Auk fish off the end of the pier every morning. He still won't talk about the glass."},
}
# Big Jim's tail (Tom, Guide 11 #6): his own slide with a picture, in any run he
# was part of (penguins: the campfire; gangsters: he joined you).
TAIL = {"title": "Big Jim's tail", "pic": "cut_big_jim_tail", "flag": "st_p3_campfire", "known": "big_jim",
        "text": "One morning Big Jim woke up with a tail. A long, fluffy, striped one. He screamed about it for a week.\n\nThen he found out he could hang off the fence by it. Then he could juggle apples while he hung there. Then he could fish with it, crack walnuts with it, and catch a falling egg without looking.\n\nNow he wouldn't give it back for anything, and he tells everyone it was his idea.",
        "text_hero": "One morning you woke up with a tail. A long, fluffy, striped one. You screamed about it for a week.\n\nThen you found out you could hang off the fence by it. Then you could juggle apples while you hung there. Then you could fish with it, crack walnuts with it, and catch a falling egg without looking.\n\nNow you wouldn't give it back for anything, and you tell everyone it was your idea."}
LT = {"vance": "Harbourmaster Vance", "lucia": "Lucia \"Flame\" Ardent", "brock": "Brock the Unbroken", "silas": "Silas Crane",
      "mags": "Old Mags", "surveyor": "The Surveyor", "pike": "Conductor Pike", "ostrova": "Madame Ostrova"}
LT_LINES = {"spared": "%s walked away when you let them, and nobody's seen them make trouble since.",
            "joined": "%s works with your crew now, and the city is safer for it.",
            "beaten": "%s was beaten, and the President's orders stopped coming."}
CHOICES = {
 "tell_town": {"0": "%town knows the truth about the Grumps now, and they look after every stray.", "1": "You kept the secret about the Grumps. Some nights it's heavy. The Star Crystal helps you carry it."},
 "locket": {"1": "The humming locket sits by your bed. Sometimes it glows when the moon is full."},
 "fennimore": {"1": "You told Fennimore nothing above the clouds. Whatever she learned about him, she learned the hard way."},
 "letter": {"0": "You burned the letter. Nothing to sell, nothing to fear."},
 "photo": {"0": "You burned the photo. The past stays burned.", "1": "The photo stays with the deed, a little piece of a case nobody else will ever close.", "2": "You learned that hand by heart. In the end, it was a hand you knew."},
 "shop_1": {"0": "The bakery stayed an arcade. Some mornings the avenue still smells of bread that isn't there.", "1": "The bakery never closed. You were the reason why."},
 "shop_2": {"0": "Lumi's studio is the arcade's second floor now. Kids love it. There's a square of cleaner paint on one wall where her easel stood.", "1": "You left Lumi's studio alone. Her next painting was the avenue at night, and one window in it was lit for you."},
 "shop_3": {"0": "The crew still runs the clinic you took. You told yourself it would be free one day; Juniper never came back to see if it was.", "1": "You drew the line at the clinic, and held it."},
 "sell_letter": {"0": "You sold the letter. The money built the crew. The President knew your face, and it didn't matter.", "1": "You never sold the letter. Marlene still says it was the best deal you ever turned down."},
}
# A shop you took and then gave back: replaces that choice's line.
RETURNED = {"shop_1": "You took the bakery, and then you bought it back and handed Posy the keys. The avenue smells of bread again.",
            "shop_2": "You took Lumi's studio, and then you gave it back. Her painting of the day you did hangs in the town hall.",
            "shop_3": "You took the clinic, and then you gave it back. Juniper still won't thank you, but she leaves the door open."}
ENDINGS = {"revert": "Two Crystals", "shatter": "The Quiet Mountain", "free": "A Tired Man", "take": "The Chair", "clean": "A Clean Break"}
# Picture on the THE END slide (ui/<name>), and on the last slide per arc.
ENDING_PICS = {"revert": "ending_two_crystals", "shatter": "ending_quiet_mountain", "free": "ending_tired_man", "take": "ending_the_chair", "clean": "cut_clean_break"}
THANKS_PICS = {"penguins": "cut_old_dog", "gangsters": "cut_rain_road"}
# No family or staff names in the game (CLAUDE.md). Must say the same as docs/steam-store/ai-disclosure.md
# (tools/ratings_facts_check.py compares the key phrases); the studio name waits on Tom (s1_13-09).
CREDITS = ("Made by a small family team: the story, the friends and the farm.\n\n"
           "Art generated with OpenAI image models from our own designs, then cut, cleaned and finished by hand.\n\n"
           "Writing with Anthropic's Claude, from our own story outline.\n\n"
           "Music made with ACE Music.\n\n"
           "Sound effects and ambience from CC0 packs on OpenGameArt.org.\n\n"
           "Built with the Godot Engine (MIT licence).")
json.dump({"_": "End slideshow. Generated by tools/gen_epilogue.py.", "villagers": V, "crew": CREW, "companions": COMP,
           "companions_if": COMP_IF, "villagers_gang": V_GANG, "villagers_skip_if_known": V_SKIP_IF_KNOWN,
           "crew_solo": CREW_SOLO, "crew_threads": CREW_THREADS, "crew_take": CREW_TAKE, "crew_if": CREW_IF, "flag_alt": FLAG_ALT, "hero_flag_lines": HERO_FLAG_LINES, "tail": TAIL,
           "returned": RETURNED, "ending_pics": ENDING_PICS, "thanks_pics": THANKS_PICS, "credits": CREDITS, "colonies": COLONY, "lieutenants": LT, "lt_lines": LT_LINES, "choices": CHOICES, "endings": ENDINGS,
           "flag_lines": {"museum_done_peng": "Theo's museum outgrew the library's east wing. School trips come every spring, and Pip gives the tour.",
                          "museum_done_gang": "The Curio Room became the city's favourite free afternoon. Theo still keeps the ledger.",
                          "town_lost": "%town never quite forgave the clinic. People still lower their voices when you pass the plaza.",
                          "tower_loud": "Every light in the tower came on the night you went in. The city still calls it the Loud Night.",
                          "fennimore_free": "Fennimore's crown went out in your arms. The finargles have a queen again: a gentler one.",
                          "final_town_help": "The whole town climbed the tower stairs to ring the bell, and the Dark Crystal's shell cracked at the sound.",
                          "doors_by_sasha": "Sasha let you into the tower with a service key she never handed back. Nobody in the city has ever asked her how she kept it.",
                          "doors_by_letter": "The letter you kept since the rain went into the tower's slot, and the doors opened. Nobody fought you.",
                          "finn_told": "Finn wears the locket now. He smiles more.",
                          "tomas_home": "Tomas came home, thin and quiet, and the brothers fish off the pier together. Tomas still says his pike was bigger.",
                          "biscuit_home": "Biscuit sleeps on the bakery step now, and gets the first crust of every loaf. Some afternoons he walks out to your farm to visit %pet.",
                          "bitter_home": "The friend you turned away found their way back in the end. You still don't talk about the gate, but you sit on the same fence.",
                          "knight_reverted": "The knight above the clouds was given a chance, and took it.",
                          "auk_shard": "The knight's armour lies in pieces above the clouds, and Grandfather Auk waddled off into the high cloud. Nova still goes looking for him, and some mornings she finds fresh footprints.",
                          "proj_star_beacon": "The Star Beacon still burns over the plaza. Ships steer by it now.",
                          "journal_done": "You found every page of the Wayfarer's Journal. The last one had your name on it.",
                          "purpose_kept": "Somewhere along the way you remembered why you came out of the river cities. Sal says that's the part he'll tell people about.",
                          "hale_friend": "Inspector Hale sends a postcard from the capital every spring. It always says the same thing: still clean?",
                          "hale_fooled": "Inspector Hale closed her file on the turnip farmer. She still wonders, some nights.",
                          "hale_outrun": "Inspector Hale never did catch you. She tells the story at parties, and it gets faster every time.",
                          "hale_has_stone": "The stone sits in a lead box in a basement in the capital, under a label in Hale's handwriting: DO NOT OPEN. NOT EVEN YOU."}},
          open(os.path.join(ROOT, "data/epilogue.json"), "w"), indent=1, ensure_ascii=False)
print("epilogue lines:", len(V) * 2 + len(CREW) * 2 + len(COMP) + len(COLONY) + sum(len(v) for v in CHOICES.values()))
