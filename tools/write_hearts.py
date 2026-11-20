#!/usr/bin/env python3
"""Writes data/hearts.json: five milestone scenes per villager (♥2/4/6/8/10),
a personal quest promoted at ♥6, a daily line after each milestone, and the
♥10 'if the town fell' line used by the endings. Edit here, then run."""
import json

H = {}

def v(id, q6, m2, m4, m6, m8, m10, fall, after, q6g=None, ag=None):
    H[id] = {"quest6": q6, "milestones": {"2": m2, "4": m4, "6": m6, "8": m8, "10": m10}, "fall": fall, "after": after}
    if q6g:
        H[id]["quest6_gangsters"] = q6g
    if ag:
        H[id]["after_gangsters"] = ag  # daily lines that differ in the gangster arc

# A tuple is (penguin text, gangster-arc text).
def L(who, *texts):
    return [{"who": who, "text": t[0], "text_gangsters": t[1]} if isinstance(t, tuple) else {"who": who, "text": t} for t in texts]

v("maple", "maple_supply_run",
  L("Maple", "You keep coming back. Most people buy seeds once and then I see them at the sell box, counting.", "Here. A turnip seed packet with a bent corner. It's the first thing I ever sold in this shop; I kept it. Plant it or don't, but it should be in the ground somewhere."),
  L("Maple", "My brother used to stock these shelves. Taller than me, could reach the top row. He ran from something, never said what, and now he's a baker in the capital.", "I write. He writes back, four lines, every month. Four lines is a lot, from him."),
  L("Maple", "The back storeroom's falling in. I've been pretending it isn't since spring.", "I don't ask people for things. I'm asking. Twenty wood and ten stone and I'll stop pretending."),
  L("Maple", ("When that light came down in your field, I was closing up. I saw it from the step. I didn't run out. I didn't tell anyone.", "The day you came in with that deed in the wrong name, I was closing up. I saw your face. I didn't ask. I didn't tell anyone."), "I thought: whoever's out there, they're going to need somebody who doesn't ask questions. So I didn't. I'm asking one now. Are you all right?"),
  L("Maple", "Four lines came today. Five, actually. The fifth one says: 'Is it safe to come home?'", "I don't know what to write back. I think the answer's you. I think the answer's been you since the turnips."),
  "Maple would lock the store and stand in the doorway with a broom, and nobody would get past the broom.",
  {"2": "Plant the bent packet. I want to know what comes up.", "4": "Four lines this month. He asked about the weather. That's a lot, from him.", "6": "The storeroom. I've stopped pretending about it. Mostly.", "8": "I still don't ask questions. I've just started noticing the answers.", "10": "I wrote back. One line. 'Yes.'"})

v("gideon", "gideon_ruby",
  L("Gideon", "You swing like a farmer. Shoulders. It's the wrists; the hammer does the work if you let it.", "...Here. Hold it like that. No. Like THAT. Hm. Better."),
  L("Gideon", "My father's hammer. This one. Head's been replaced twice and the handle three times, so you tell me whose hammer it is.", "He'd have liked you. He didn't like anyone, so that's a guess."),
  L("Gideon", "There's a ring I've been making for eleven years. It needs a ruby. I don't talk about who it's for.", "If you found one, in the mountain, I'd... I don't finish sentences well. Find one."),
  L("Gideon", "The ring's for Juniper. There. Said it. Eleven years, I've said it to a farmer and a forge.", "She set my arm when I broke it on the anvil. Said I was an idiot. Nobody's ever been so right about me."),
  L("Gideon", "I gave her the ring. She said I was an idiot. She's wearing it.", "You did that. Not the ruby. The... you came in every day and swung like a farmer until I had to talk to you. That's what you did."),
  "Gideon would bar the smith's door and stand behind it with his father's hammer, and he would not say a single word, and nobody would try the door twice.",
  {"2": "Wrists. Remember.", "4": "Father's hammer's holding up. You're holding up.", "6": "Eleven years. Don't look at me like that.", "8": "She said idiot again today. Twice. Good day.", "10": "She's wearing it. Still. I check."})

v("wren", "wren_starflower",
  L("Wren", "You pick herbs like you're apologising to them. Don't. They're herbs. Pull.", "...The mushroom you brought last time had a good smell. I kept the stem. For the spore jar."),
  L("Wren", "My daughter thinks I talk to the plants. I do. They don't answer, which is restful, which is the point.", "You answer. That's... fine. That's also fine."),
  L("Wren", ("There's a flower that only grows where the crystal fell. Starflower. I had one once; I used it on a fever and it worked and I never found another.", "There's a blue herb by the orchard wall. Moonwort. I had some once; I used it on a fever and it worked and I never found more."), "If you're going back out there. If."),
  L("Wren", ("The fever was Wren junior's. She was three. The starflower was the only thing in this town that was going to work, and it did, and I never told anyone how close it was. Not even her.", "The fever was Wren junior's. She was three. The moonwort was the only thing in this town that was going to work, and it did, and I never told anyone how close it was. Not even her."), "Her father's not here now. That's a different story, and it's not yours. But you should know what you brought me."),
  L("Wren", "I've started talking to Wren junior instead of the plants. It's harder. She answers.", "You did that. Not with the flower. With the coming back. Here: the recipe for the fever tonic. Nobody has it but me. Now two people."),
  "Wren would brew something foul and throw it at whatever came through the gate, and it would work, because Wren's things work.",
  {"2": "Pull, don't pick.", "4": "The plants say hello. I'm interpreting.", "6": "A starflower. Just one. I'm not greedy.", "8": "She's seven now. She talks about frogs. Frogs are fine.", "10": "I answered her today before she asked. That's new."},
  q6g="wren_moonwort", ag={"6": "Moonwort. Just a sprig. I'm not greedy."})

v("alder", "alder_gold",
  L("Alder", "The town records show you've paid every fee on time. I mention it because nobody else has, in my term.", "There's a seat on the council open. There has been for six years. I mention THAT because I'm tired."),
  L("Alder", "My father was mayor. His father. The portraits in the hall; you've seen them. I'm the small one at the end.", "I never wanted it. I was going to be a... it doesn't matter. Somebody has to sign things."),
  L("Alder", "The bell. Twenty-one years. I was there when it stopped: the clapper cracked in the middle of the harvest ring and fell and nearly took my father's foot.", "He said it was a sign. I said it was metal fatigue. We never settled it. A gold bar would."),
  L("Alder", "I was going to be a painter. There. Lumi knows; nobody else. I had a place in the capital and my father got ill the week before I left.", "I still have the brushes. In the hall, bottom drawer, under the fee ledgers. That's where I keep the things I didn't do."),
  L("Alder", "I painted this morning. Four a.m., before the fees. It's bad. It's wonderful; it's bad.", "The council seat's yours if you want it. You won't. That's why it's yours."),
  "Alder would open the town hall doors and stand in them in his father's coat and read the town charter aloud, very slowly, until whatever it was went away or he finished.",
  {"2": "Fees on time. Noted.", "4": "The small portrait at the end. Don't look too long.", "6": "Metal fatigue. I maintain it.", "8": "Bottom drawer. You didn't hear that from me.", "10": "Four a.m. It's getting less bad."})

v("sal", "sal_fish",
  L("Sal", "You walk like somebody who's been followed. Shoulders up. Relax them; it's a tell.", "I'd know. I had the same walk for ten years."),
  L("Sal", "River cities. Ran with a crew. We weren't good people but we were good at it, and then the man with the stone came, and we weren't anything.", "I'm the one who left. The others stayed. I think about that at the gate, most nights."),
  L("Sal", "I don't eat much. Bad knee, bad habits. If you brought me a fish I'd probably cook it. Probably.", "Not a favour. A test. I'm testing whether I can still accept things."),
  L("Sal", "The knee was a door. Uptown. I held it so the others could get out, and they wouldn't come. They stayed with him. I went.", "That's the whole story. There isn't a better version. I've looked."),
  L("Sal", "I've decided something. If this town goes, I go with it. Not away from it. With it.", "First time I've picked a side since the door. Feels like the knee's going to hold."),
  "Sal would sit on the bench by the south gate with a bad knee and a worse temper, and nothing would get past the bench.",
  {"2": "Shoulders. Down.", "4": "Gate's quiet. Quiet's fine. I'll tell you when it isn't.", "6": "Fish. Still testing whether I can take things. Don't make it a thing.", "8": "Knee's holding.", "10": "With it, boss. Not away."})

v("finn", "finn_pearl",
  L("Finn", "You cast like you're angry at the water. Water doesn't care. Cast like you're asking.", "There. See? It's not about the fish. The fish is a bonus."),
  L("Finn", "Had a brother. Tomas. Went to the river cities to make money for a boat we were going to build together.", "Boat's still half a boat. In the shed. I go in there sometimes and don't build it."),
  L("Finn", "There's a pearl in the lake. Marlowe says so, and Marlowe doesn't say things.", "I don't want it to sell. I want it because Tomas always said there wasn't one."),
  L("Finn", "I finished the boat. Last week. Just... did it, one morning, before I'd thought about it.", "She floats. I haven't named her. You name a boat, it's real. I'll get there."),
  L("Finn", "Named the boat. 'Second Cast.' Because you don't catch anything on the first one; that's just asking the water.", "She's yours any time. Just say. I'll row."),
  "Finn would push every boat on the lake into the water and float them all out of reach, and then sit on the dock and wait, with a rod, like it was Tuesday.",
  {"2": "Asking, not angry. Remember.", "4": "Half a boat. Still.", "6": "Marlowe says pearl. Marlowe doesn't say things.", "8": "She floats. That's all she has to do.", "10": "Second Cast. Any time."})

v("lumi", "lumi_starflower",
  L("Lumi", "Hold still. No— don't hold still, that's worse. Just... exist near the window. Good.", "I'm painting the light, not you. You're what the light's doing."),
  L("Lumi", "Alder bought my first painting. Paid too much. Hung it in the hall where nobody looks.", "He wanted to be a painter, you know. He's never said. I can tell by how he looks at the corners."),
  L("Lumi", ("There's a flower where the crystal fell. Starflower. The blue in it doesn't exist anywhere else; I've tried to mix it for a year.", "There's a blue in the moonwort by the orchard wall that doesn't exist anywhere else; I've tried to mix it for a year."), "Bring me one and I'll stop trying, which would be a relief to everyone."),
  L("Lumi", ("I mixed the blue. From the starflower. It's not the same; it's better, because I had to work for it.", "I mixed the blue. From the moonwort. It's not the same; it's better, because I had to work for it."), ("The painting's of the gate. Your gate. The morning the penguins came. Don't ask how I knew; painters know.", "The painting's of the gate. Your gate. The morning you came to town. Don't ask how I knew; painters know.")),
  L("Lumi", "It's hanging in the hall. Next to Alder's portrait. He cried; he'll say he didn't.", "It's the gate, and the light, and someone in it who looks like they've decided to stay. I didn't give them a face. They have yours."),
  "Lumi would paint the town as it was, very fast, on the hall wall, so that whatever came would have to look at it first.",
  {"2": "Exist near the window.", "4": "He looks at the corners.", "6": "The blue. Just the blue.", "8": "The gate painting's drying.", "10": "Next to his portrait. He cried."},
  q6g="lumi_moonwort")

v("theo", "theo_book",
  L("Theo", "You read the board notices. All of them. Nobody reads the small ones.", "I write the small ones. Hello."),
  L("Theo", "The library has four hundred books and I've read three hundred and ninety-eight. The other two are in a language I'm inventing as I go.", "It's going slowly. The language, not the reading."),
  L("Theo", "There's a book in the mine. Old. The miners' log, from before the bell stopped. It would explain... a great many small notices.", "I can't go down there. I'm a reader. You're a... whatever you are. Please."),
  L("Theo", "The log says the bell cracked the same night something fell in the east. The same night. Twenty-one years ago.", ("Your light isn't the first. Something came before. Something that didn't ask for help.", "You aren't the first stranger up that road. Something came before. Something that didn't ask for help.")),
  L("Theo", "I've finished the two books. The language was mine after all; I just hadn't learned it yet.", "The last line of the last one says: 'They came back for the town.' I don't know if it's a record or a prediction. I'd like it to be both."),
  "Theo would carry four hundred books into the chapel two at a time and read the last one aloud until whatever came was bored into leaving.",
  {"2": "Small notices. Hello.", "4": "Three hundred and ninety-eight.", "6": "The miners' log. Please.", "8": "The same night. Twenty-one years.", "10": "They came back for the town."})

v("hazel", "hazel_milk",
  L("Hazel", "Your rows are crooked. I'm not criticising; mine were worse. Pull the string tight and walk it.", "Turnips don't mind crooked. Carrots do. Carrots are fussy."),
  L("Hazel", "Mabel's mine. My girl. Her father went to the quarry for one season and the season's been nine years.", "She thinks he's coming back. I let her. Some things you let."),
  L("Hazel", "The cheese cellar. I built it for two. Four milk would fill it. Nobody's filled it in nine years.", "I'd like to see it full. Just once. See if I still remember what to do with it."),
  L("Hazel", "Granite told me. At the quarry. He didn't leave us. There was a rockfall; he got the whole crew out and hurt his back so badly he went to the coast to mend, too proud to write. Nine years, Granite's been carrying that up the road and not quite knocking.", "I told Mabel. She cried, and then she asked if she could see the quarry, and I said yes. I don't know why I said yes. I'm glad I did."),
  L("Hazel", "Cellar's full. Mabel named every wheel. One's called after you; it's the lumpy one.", "Granite comes by Sundays. Fixes the fence. Doesn't say much. The fence doesn't need fixing."),
  "Hazel would put Mabel in the cheese cellar with the lumpy wheel and a lamp, and then she'd pick up the scythe, and she would not put it down.",
  {"2": "Pull the string tight.", "4": "She thinks he's coming back.", "6": "Four milk. Just to see.", "8": "Granite knocked. Finally.", "10": "The lumpy one's yours."})

v("bram", "bram_wine",
  L("Bram", "You always sit in the corner. Back to the wall. I had a brother-in-law like that.", "He was a terrible man. You're not. But the corner's yours."),
  L("Bram", "This inn was my wife's. Posy's mother. She ran it like a ship and I ran the kitchen like a man hiding in a kitchen.", "Still do. The kitchen part."),
  L("Bram", ("Festival night. Posy's mother kept two bottles of lake wine on the inn's sill, never opened: one for the harvest, one for whoever came home late. The sill's been bare since she went.", "Festival night. Two root beers. I want to raise one glass that isn't water, for once, for Posy's mother."), ("Two bottles, for the sill. Not for drinking; for remembering. I'll pay. I just can't walk to the lake for them. Every year I mean to.", "I'll pay for them. I just can't get to the soda fountain on the avenue. Every year I mean to.")),
  L("Bram", ("I walked to the lake. Myself. Halfway, then I sat down, then the rest of the way.", "I walked to the avenue. Myself. Halfway, then I sat down, then the rest of the way."), ("She used to walk it in forty minutes. Took me two hours. The sill was full again before I sat down.", "She used to walk it in forty minutes. Took me two hours. Her glass was full before I sat down.")),
  L("Bram", "Posy's running the front now. She's better than her mother was, and I said so, and she threw a tea towel at me.", "Corner's still yours. Always will be. I've put your name on it; don't look, it's under the table."),
  "Bram would stand in the inn doorway with a cleaver, which he has never once used on anything but onions, and nobody would argue with the doorway.",
  {"2": "Corner's yours.", "4": "Still hiding in the kitchen.", "6": "Two bottles for the sill. Festival night.", "8": "Two hours. The sill's full.", "10": "Tea towel. Right in the face."},
  q6g="bram_rootbeer", ag={"6": "Two root beers. Festival night.", "8": "Two hours. Her glass was full."})

v("posy", "posy_strawberries",
  L("Posy", "You smell the bread before you come in. Everyone does. You're the only one who waits for the second batch.", "Second batch is better. Oven's warm by then. Don't tell the first-batch people."),
  L("Posy", "Mum made the bread. I made the cakes. Dad hid in the inn kitchen, which is where he's happiest, so that's fine.", "I do both now. I'm not as good at bread. I'll say that out loud once."),
  L("Posy", "Twelve strawberries. Jam. Mum's jam, actually; I found the recipe in a drawer under the receipts.", "I'm scared to make it in case it's wrong. I'm more scared not to."),
  L("Posy", "It was right. The jam. I cried into it, which Mum would say was the secret ingredient, which is disgusting, which is exactly what she'd say.", ("Dad walked to the lake for two bottles for Mum's sill. Did you hear? Two hours. He's insufferable about it.", "Dad walked to the avenue for root beer. Did you hear? Two hours. He's insufferable about it.")),
  L("Posy", "I had a dog, when I was small. Biscuit. He ran off the week Mum— the week things went bad. I've never said that to anyone, because what's a dog, next to that.", "A dog's a lot. I know that now. I don't know why I know it. Something about the way you look at yours."),
  "Posy would bake until the whole town smelled of bread, because nothing bad has ever happened in a town that smells like that, and she'd be right.",
  {"2": "Second batch.", "4": "I'll say it once: not as good at bread.", "6": "Mum's jam. Twelve.", "8": "Secret ingredient. Disgusting.", "10": "A dog's a lot."})

v("juniper", "juniper_glowcap",
  L("Juniper", "Sit. No, you're not hurt; sit anyway. I like to see people sit who aren't hurt. It's rare.", "There's a crack in your left boot. Fix it before winter or I'll be seeing you the other way: on my table."),
  L("Juniper", "I trained in the capital. Twelve years. Came back because the capital had enough nurses and this town had none and a blacksmith who'd broken his arm on an anvil like an idiot.", "He's still an idiot. I've said so, professionally."),
  L("Juniper", "Glow caps. Two. I've a theory about fevers and I need to be wrong about it in a controlled way.", "Theo says that's not how theories work. Theo has never set a bone."),
  L("Juniper", "Gideon gave me a ring. Eleven years of forging, he said, like that's a normal amount of time. I called him an idiot.", "I'm wearing it. You've noticed. Say nothing; I've a reputation."),
  L("Juniper", "I've started a ledger of who in this town would be hurt first, if something came. It's a nurse's habit.", "You're not on it. You're on the other list. The one of people who'd be standing in front."),
  "Juniper would turn the clinic into a fort with the beds, and anyone who came through the door hurt would be treated, whatever side they'd come in on, and then sent back out, and she would keep count.",
  {"2": "Left boot.", "4": "Still an idiot. Professionally.", "6": "Two glow caps. Controlled.", "8": "Say nothing.", "10": "The other list."})

v("rook", "rook_tracks",
  L("Rook", "You walk loud. Heel first. Toe first, roll, and the forest stops noticing you.", ("Try it. No. Try it again. ...Better. Grumps won't hear that.", "Try it. No. Try it again. ...Better. Nobody on the avenue will hear that.")),
  L("Rook", "I came out of the river cities on foot. Took a season. Ate what I could catch, which taught me to catch things.", "The lodge was empty when I got here. Still is, mostly. I like mostly."),
  L("Rook", ("The orchard. Grumps in it. They'll reach the north bridge by harvest, and the clinic's past the bridge.", "The orchard. Strangers in it, at night. They'll reach the north bridge by harvest, and the clinic's past the bridge."), "I can't hold it alone. I've tried, and I'm not a man who says that."),
  L("Rook", "Your pup's got a nose. I've watched it. It tracks the way I did before I learned to, which means it'll be better than me.", "Bring it by. I'll show it the orchard the right way; the way you don't get seen."),
  L("Rook", "I've a daughter in the river cities. Grown. She doesn't know I'm alive. I've decided she should.", "I'm writing it tonight. Toe first, roll. That's the only way I know to do hard things."),
  "Rook would be on the lodge roof with a bow before anyone else knew anything was coming, and whatever it was would turn back before it reached the bridge.",
  {"2": "Toe first. Roll.", "4": "Mostly empty. I like mostly.", "6": "The orchard. By harvest.", "8": "That pup's got a nose.", "10": "Wrote it. Sent it. Toe first."})

v("pip", "pip_candy",
  L("Pip", ("You're the one with the light! Mabel says it's a crystal and Wren jr says it's frogs and I say it's BOTH.", "You're the new one! Mabel says you're a spy and Wren jr says you're a frog in a coat and I say it's BOTH."), "Don't tell them I said both. Both is cheating."),
  L("Pip", "Mum runs the store. Maple. She doesn't know I know she cries at the letters. I know everything; I'm nine.", "Uncle writes four lines. I counted. I'm going to write him five."),
  L("Pip", "If you throw a candy in the fountain and say a wish the fountain does it. It did it for Tobin's kite. It's SCIENCE.", "Bring candy. I'll show you. You have to say the wish out loud or it doesn't count and I'll know."),
  L("Pip", "I wrote Uncle five lines. He wrote back six. SIX. Mum read it and went in the back for a while.", "I think I won. I don't know what I won. I think it was important."),
  L("Pip", "When I'm mayor— I'm going to be mayor, Alder says I can have it— I'm making a law that the bell rings every day.", "And a law about frogs. Wren jr's writing that one."),
  "Pip would ring the bell. Clapper or no clapper. Pip would ring it with a rock.",
  {"2": "Both. Don't tell.", "4": "Five lines. I'm nine.", "6": "Candy in the fountain. SCIENCE.", "8": "Six lines. I WON.", "10": "Bell every day. It's a law."})

v("wren_jr", "wrenjr_frog",
  L("Wren jr", "Mum talks to plants. I talk to frogs. Frogs talk BACK, so I think I'm winning.", "That one's Gerald. He's the mayor of the pond. Don't tell Alder."),
  L("Wren jr", "I was sick once. Really sick. I don't remember it but Mum does; she gets a face.", "There was a flower. A blue one. I'm going to find one for her so she stops getting the face."),
  L("Wren jr", "Gerald's gone. From the pond. Frogs go, Mum says, but Gerald wouldn't; he's the mayor.", "If you see a frog that looks important. That's him."),
  L("Wren jr", "Gerald came back! He was at the LAKE. He went on a TRIP. Mum says that's not how frogs work and I say Gerald isn't how frogs work.", "I'm seven. I'm allowed to be right sometimes."),
  L("Wren jr", "Mum answered me today before I asked. She's never done that. She looked surprised at herself.", "I think you did something to her. The good kind. The frog kind."),
  "Wren jr would put every frog in the pond in a bucket and carry them somewhere safe, because somebody has to think of the frogs, and nobody else will.",
  {"2": "Gerald. Mayor of the pond.", "4": "The blue flower. For the face.", "6": "If you see an important frog.", "8": "He went on a TRIP.", "10": "The frog kind."})

v("tobin", "tobin_shells",
  L("Tobin", "I live at the inn. Dad cooks. He says I'm the best thing in the kitchen, which is a joke, because I'm not allowed in the kitchen.", "Bram's not my dad. He says it's complicated. I say it's not."),
  L("Tobin", "My real dad was a sailor. Mum said. Mum's not here. Bram is. That's the whole thing; it's not complicated.", "I want a kite. A real one. Sailors can fly kites, Bram says, it's practically the same as a sail."),
  L("Tobin", "Shells. Five. The beach has them but you have to go past the dock and I'm not allowed past the dock.", "If you got them I'd build the kite. Bram says a kite needs shells for the tail. I think he made that up. I don't care."),
  L("Tobin", "Kite flies. It FLIES. Bram cried. He says it was onions. There weren't any onions; I checked the whole kitchen.", "I'm allowed in the kitchen now. For checking."),
  L("Tobin", "Bram asked if I wanted to call him Dad. I said I already did, in my head, and he said that counts, and I said I know.", "The kite's on the inn roof. You can see it from your farm. Look up sometime."),
  "Tobin would climb onto the inn roof and fly the kite, because when the kite's up everyone looks up, and when everyone's looking up nobody's afraid.",
  {"2": "Not allowed in the kitchen.", "4": "Practically the same as a sail.", "6": "Five shells. For the tail.", "8": "It FLIES. No onions.", "10": "Look up sometime."})

v("mabel", "mabel_flowers",
  L("Mabel", "I sing to the cows. They give more milk. Mum says it's the singing. It's definitely the singing.", "I'll sing one for your pup. Dogs are harder than cows. They have opinions."),
  L("Mabel", "Dad's at the quarry. He's been at the quarry a long time. Mum does a thing with her mouth when I say it.", "I'm going to go see him. When I'm ten. Ten's old enough for the quarry road."),
  L("Mabel", "Flowers. For the cellar. Mum built it for two and it's empty and I think flowers would make it less empty while we wait for cheese.", "I'm eight. I'm allowed to have plans."),
  L("Mabel", "Granite told Mum. About Dad. I cried, and then I asked if I could see the quarry, and Mum said yes.", "There's a stone at the quarry with his name on it, for getting everyone out. Granite cut it. I sang to it; stones are easier than dogs."),
  L("Mabel", "The cellar's full and every wheel has a name and Granite comes Sundays and fixes a fence that doesn't need it.", "I've started calling him Granite. Just Granite. Mum says that's enough for now. I think it's enough forever."),
  "Mabel would sing. Loudly. From the cheese cellar. And the cows would come, and the cows have opinions.",
  {"2": "Definitely the singing.", "4": "When I'm ten.", "6": "Flowers for the cellar. I have plans.", "8": "A good stone.", "10": "Just Granite."})

v("marlowe", "lighthouse_lens",
  L("Marlowe", "Thirty years I lit that lamp. Nobody's needed it for twenty. I'd light it tonight if it had oil.", "You don't light a lamp for the boats. You light it so the dark knows somebody's counting."),
  L("Marlowe", "There's a pearl in the lake. I've seen it, once, from the top, in the right moon. Finn doesn't believe me. Finn believes in fish.", "Tell him. He'll believe you; you've got the face for it."),
  L("Marlowe", "The lens is cracked. Has been since the night the bell stopped. Same night, you know. I heard it from up here.", "Something fell in the east that night. I lit the lamp at it. It didn't come."),
  L("Marlowe", "New lens. Thirty years I've looked through a crack and now I can't remember what I was looking at.", "I'll tell you: the east. Every night. Waiting for whatever it was to try again."),
  L("Marlowe", ("It tried again. The night your light came down. I saw it from the top, and I lit the lamp, and this time it wasn't the dark that landed.", "It tried again, this year. Purple, in the city crates. I saw the boats from the top, and I lit the lamp, and this time somebody came to stop it. You."), "Thirty years of counting and the sum came out. I'm going to sleep tonight. First time in a while."),
  "Marlowe would light the lamp, and turn it to the east, and keep it there, and the dark would know somebody was counting.",
  {"2": "So the dark knows.", "4": "He believes in fish.", "6": "Same night. I heard it.", "8": "The east. Every night.", "10": "The sum came out."})

v("orla", "orla_oil",
  L("Orla", "The wheel turns whether I'm here or not. That's the thing about mills. I just keep it honest.", "You bring good wheat. Not great. Good is enough; great is for people with something to prove."),
  L("Orla", "My husband built the wheel. My son rebuilt it. I've only ever kept it turning, which is the longest job and the one nobody paints.", "Lumi tried. I wouldn't sit still."),
  L("Orla", "Marlowe's lamp wants oil. He won't ask. He'd row the lake in a storm before he'd ask.", "I'd take it over myself if the knees allowed. They don't. You've got knees."),
  L("Orla", "Marlowe came by. First time in nine years. Stood at the door, said the lamp was lit, left.", "That's a love letter, from him. I've had three. I keep them in the flour tin."),
  L("Orla", "I sat still for Lumi. Finally. It's hanging in the mill; the wheel's behind me and I look like a woman who's kept something turning.", "Which I have. Four letters now. The fourth one said 'come up and see.' I'm going up."),
  "Orla would stop the wheel. Just stop it. Thirty years of turning, and the silence would be so loud that the whole lake would hear it.",
  {"2": "Good is enough.", "4": "The job nobody paints.", "6": "He'd row a storm first.", "8": "In the flour tin.", "10": "I'm going up."})

v("benno", "benno_pup_pack",
  L("Benno", "Horses know. Before you've decided to be cruel or kind, the horse knows. Yours knows you're all right.", "The pup too. Animals read the first page and skip the rest."),
  L("Benno", "I was a jockey. Smaller then; I know. Fell at the capital track, three years ago, and the horse was fine and I wasn't.", "Came here because nobody here had seen the race. Still haven't told anyone. Now you."),
  L("Benno", "That pup wants to carry things. I can see it in the shoulders. A pack, small, and it'd feel like a job.", "Everybody needs a job. Even the ones with four legs. ESPECIALLY those."),
  L("Benno", "I got back on. Yesterday. Just round the paddock. The grey mare; she's patient with cowards.", "Didn't fall. Didn't do anything. Sat there and shook and it was the best ride of my life."),
  L("Benno", "Race at the festival. I'm riding. Alder's put it on the notice; Theo wrote it small, bless him.", "I'll lose. I'll lose on purpose if I have to, so I can say I finished one. Come and watch me finish."),
  "Benno would open every stall and ride out at the head of the whole stable, and horses know, and they'd follow him anywhere.",
  {"2": "Horses know.", "4": "Nobody here saw the race.", "6": "A pack. Small. A job.", "8": "Sat there and shook.", "10": "Come watch me finish."})

v("ivy", "ivy_coins",
  L("Ivy", "Your account is in order. I say that to everyone. It's true of almost nobody.", "A deposit on the same day each week. That's a person who intends to stay. The bank notices."),
  L("Ivy", "I came from the capital with a letter of introduction and a reputation for honesty, which in the capital is a reason to leave.", "The vault here has never been robbed. It's never had anything in it either. Those may be connected."),
  L("Ivy", "Old coins. Theo collects them; I value them. There's a set from before the bell that would settle a question of dates.", "I don't say 'please' in a professional capacity. Consider it said in a personal one."),
  L("Ivy", ("The coins settled it. The bell, the light, the mine log: one night, twenty-one years ago. Theo's writing a small notice.", "The coins settled it. The bell, the dark lamp, the mine log: one night, twenty-one years ago. Theo's writing a small notice."), "I've opened an account in your name you don't know about. Interest only. Call it the bank's opinion of you."),
  L("Ivy", "Someone offered me a position in the capital. Twice my salary. A vault with something in it.", "I declined. In writing. I kept a copy. I'm keeping everything from here on; I've decided this is where the records are."),
  "Ivy would lock the vault with the town's deeds inside it, swallow the key, and sit on the step with her ledger, writing down the name of everyone who tried.",
  {"2": "The bank notices.", "4": "Those may be connected.", "6": "Said personally.", "8": "The bank's opinion of you.", "10": "This is where the records are."})

v("tam", "tam_lamb",
  L("Tam", "Sheep don't care who you are. That's why I keep sheep. Also the wool.", "That one's Dolly. All of them are Dolly. It saves time."),
  L("Tam", "Grew up in the highlands. Came down when the ice wisps got bad; a flock can't outrun a wisp.", "I'd go back. Every spring I say I'll go back. The Dollys vote no."),
  L("Tam", "A lamb's due. First of the year. If you're about when it comes, you can name it, and it won't be Dolly.", "I'll let you know. Sheep don't keep to a schedule but they do keep to a look."),
  L("Tam", "The lamb's yours. I mean that. Take her up to the farm; she's got a look that says fences are a suggestion.", "First one I've given away. I'll pretend it's about the wool."),
  L("Tam", "Going up. To the highlands. Spring. The Dollys voted and it was close and I overruled them, which I've never done.", "Watch the lamb while I'm gone. If I don't come back, she's the flock. You're the shepherd. Sheep don't care who you are."),
  "Tam would drive the whole flock into the plaza, and nothing that ever walked could get through two hundred Dollys who've decided not to move.",
  {"2": "All of them are Dolly.", "4": "The Dollys vote no.", "6": "She'll have a look.", "8": "Fences are a suggestion.", "10": "Sheep don't care who you are."})

v("old_moss", "moss_glowcaps",
  L("Old Moss", "You stepped around the black water. Most don't. Most come out of it with something that wasn't theirs.", "Sit. The pot's always on. Don't ask what's in it; it's in it."),
  L("Old Moss", "I was the town's doctor before Juniper. Before her mother. I came out here when I got tired of promising cures I didn't have.", "The frogs don't need fixing. I listen to them. It's restful."),
  L("Old Moss", "Glow caps. The witch in the deep marsh uses them for the fog. I use them for the opposite.", "Bring me some and I'll show you a lantern the fog doesn't like. I made it for myself. I don't need it anymore; I've gotten to like the fog."),
  L("Old Moss", "The marsh witch was my patient. Fifty years ago. The thing I couldn't fix. She got lost in the marsh fog one night and came out of it as what she is.", "I stayed out here to be near her. That's the whole reason. Juniper knows; she's the only one I told."),
  L("Old Moss", "If you ever face her— the witch— don't stay to listen. Don't let her talk. She'll use my voice; she learned it from fifty years of me talking to her through the fog.", "And then come and tell me. I'd like to go into town after. I'd like to see the clinic. Just once."),
  "Old Moss would stand at the edge of the black water and call to what's in it, and it would listen, because it always has.",
  {"2": "The pot's always on.", "4": "I listen to the frogs.", "6": "The fog doesn't like it.", "8": "She was my patient.", "10": "Don't stay to listen."})

v("granite", "granite_bones",
  L("Granite", "You swing a pick like you're mad at the rock. The rock's fine with that; the rock doesn't care. Your shoulder does.", "Short strokes. Let the weight do it. Coffee's on the stove; it's terrible."),
  L("Granite", "Nine years foreman. Was a hand before that. There was a rockfall, first year. A good man got us all out and paid for it with his back. Hazel's man.", "I've been meaning to walk up the road and say so. Nine years of meaning to."),
  L("Granite", "Bones in the mine. Old beast bones, from before the quarry. Rook wants them for arrowheads and I want them out of my quarry's reputation.", "Deep floors. Where the keeper is. You've been; I can tell by the dust."),
  L("Granite", "I walked up the road. Knocked. Hazel opened it and I said it, all of it, nine years of it, in about a minute.", "She said: 'I know. I've always known. Come in and fix the fence.' So I'm fixing the fence."),
  L("Granite", "The little one calls me Granite. Just Granite. Not Mr. Not sir. I cut the stone with her father's name on it and she sang to it and now she calls me Granite.", "I'm going to be at that house every Sunday till I die. The fence will be the best fence in the valley."),
  "Granite would bring every man from the quarry down the road with picks, in a line, not fast, the way rock moves, and nothing moves rock.",
  {"2": "Short strokes.", "4": "Nine years of meaning to.", "6": "The keeper's floors.", "8": "Fixing the fence.", "10": "Every Sunday."})

v("sel", "sel_fossil",
  L("Sel", "Don't touch that. Or do; it's been here three thousand years, it can survive a farmer.", "I'm Sel. I read stones. The stones here are saying something rude about the sky, I think. My grammar's shaky."),
  L("Sel", "The ruins were a town. Like yours. Same shape; same plaza, same well. Then one night, from the east, something came, and they wrote about it in the walls because the paper burned.", "I've been out here four years. The university thinks I'm dead. It's restful."),
  L("Sel", "There's a fossil in the quarry that isn't a fossil. It's a stone with a record in it, same hand as the ruin walls, and I need it to finish the sentence.", "The sentence is about your field. I'm fairly sure. My grammar's shaky."),
  L("Sel", "The sentence: 'The light came; the town was awake; the dark went home.' That's it. That's the whole wall. Three thousand years to say three things.", "Awake. The bell. They had a bell; it's in the plaza, cracked. They rang it."),
  L("Sel", "I'm going back to the university. To tell them. Not that I'm alive; that there's a wall three thousand years old that says a town can beat the dark by being awake.", "They won't believe me. You will. That's why I waited to tell you first."),
  "Sel would go to the ruins and ring the cracked bell with a rock, because that's what the wall says to do, and Sel believes the wall.",
  {"2": "Rude about the sky.", "4": "They wrote it in the walls.", "6": "The sentence is about your field.", "8": "The town was awake.", "10": "A town can beat the dark by being awake."})

# ---- C7 P4: staging for the ♥8 and ♥10 scenes (a narrated opening, and the
# villager's own closing words), plus Catkins' arc. "" speaker = narration.
def N(*texts):
    return L("", *texts)

EXTRA = {
 "maple": {"8": (N("Maple turns the shop sign to CLOSED while you're still inside, and doesn't turn it back."), L("Maple", "You don't have to answer. I just wanted it asked, once, out loud, by somebody who'd mind the answer.")),
           "10": (N("Maple has the letter flat on the counter under a jar of seeds, as if it might blow away."), L("Maple", "He'll want the top shelf back. I'll let him have it. You can have the bent packet's row; it's the best row in the shop."))},
 "gideon": {"8": (N("The forge is banked low. Gideon has the little ring in his palm, closing his fist over it whenever the door creaks."), L("Gideon", "Don't tell her. I'll do it. Eleven years; I can manage a week.")),
            "10": (N("Gideon is at the anvil, not working. He keeps glancing at the clinic across the way."), L("Gideon", "Here. A horseshoe nail, bent into a loop. It's not a ring. It's a thank-you that's shaped like a ring. Don't make it weird."))},
 "wren": {"8": (N("Wren shuts the shop door and turns the little bell so it won't ring."), L("Wren", "Sit. I'll make tea. I never make anyone tea.")),
          "10": (N("Wren junior is behind the counter on a crate, labelling bottles in very large letters. Wren watches her and not the brew."), L("Wren", "She spelled it 'fevver'. I'm leaving it. It's the right medicine either way."))},
 "alder": {"8": (N("Alder locks the hall door behind you, then the drawer, then unlocks the drawer again."), L("Alder", "A box of brushes, a sketchbook, and one bad painting of the bell tower. Thirty years under the fee ledgers. Don't laugh. ...You can laugh a little.")),
           "10": (N("There's paint on Alder's cuff and he hasn't noticed. Everyone in the hall has, and nobody's said a word."), L("Alder", "Lumi says it's 'honest'. I've decided that's a compliment. I'm painting the plaza next. With you in it, if you'll stand still."))},
 "sal": {"8": (N("Sal walks you to the bench by the south gate and sits with the bad knee straight out, watching the road."), L("Sal", "Thanks for not saying anything. People always say something.")),
         "10": (N("Sal is on the bench by the south gate, but facing the town for once, not the road."), L("Sal", "Funny. I always sat here so I'd see trouble coming. Turns out I like watching the town better."))},
 "finn": {"8": (N("Finn walks you down the jetty to a little blue boat tied at the end, bobbing like it's pleased with itself."), L("Finn", "Tomas would've laughed at the paint job. That's how I know it's right.")),
          "10": (N("The boat has a name now, in careful white letters, still a bit tacky to the touch."), L("Finn", "First fish off her goes to you. That's the rule. I just made it up, so it's the oldest rule on the lake."))},
 "lumi": {"8": (N("Lumi pulls a sheet off the easel, then hesitates, then pulls it the rest of the way."), L("Lumi", "You're the first person to see it. Theo doesn't count; he only looks at the corners.")),
          "10": (N("Half the town has been past the hall today to look. Lumi is pretending not to count them."), L("Lumi", "Next one's of the whole valley. It'll take years. Good. I'd like to have years here."))},
 "theo": {"8": (N("Theo lays the miners' log open on the library desk and holds the pages flat with two inkwells."), L("Theo", "I'm putting it in a small notice. A very small one. Some things need to be read quietly first.")),
          "10": (N("The two last books sit on Theo's desk, finished, with a ribbon in each. He's smiling at them like old friends."), L("Theo", "The library now has four hundred books and I've read four hundred. I'm going to need you to find me more. That's not a request, it's a crisis."))},
 "hazel": {"8": (N("Hazel walks you to the end of the farm lane, where you can see the quarry road climbing the hill."), L("Hazel", "Nine years we looked at that road and thought it was the reason. It was only a road.")),
           "10": (N("Hazel takes you down to the cellar by lantern light. Wheels of cheese line every shelf, each with a chalk name."), L("Hazel", "Two for the house, one for the town fair, and the lumpy one's yours. It's the best one. Don't tell the others."))},
 "bram": {"8": (N("Bram is on the inn step with his boots off, rubbing his feet and looking at the lake road as if it owes him money."), L("Bram", "Next year I'll do it in an hour and a half. Don't tell Posy; she'll want to come.")),
          "10": (N("Through the inn window, Posy is laughing at the front counter. Bram watches from the kitchen hatch, wiping the same plate."), L("Bram", "Her mother would've liked you. She liked anyone who sat with their back to the wall and still smiled at the door."))},
 "posy": {"8": (N("Posy hands you a jar of jam still warm from the pan, then takes it back to wipe the lid, then gives it to you again."), L("Posy", "First batch that tasted like hers. You get the first jar. That's how it works now.")),
          "10": (N("Posy is on the bakery step at closing time with a paper bag of crusts, the way you'd leave them out for someone."), L("Posy", "I still put crusts out. Just in case Biscuit's nose works better than my hope. Sit with me a minute?"))},
 "juniper": {"8": (N("Juniper is rolling bandages at the clinic desk. The ring catches the lamplight every time her hands move."), L("Juniper", "If you say 'congratulations' I'll take your temperature in the least dignified way I know.")),
             "10": (N("The clinic is quiet. Juniper shows you a ledger, then a second, much shorter list tucked in the back."), L("Juniper", "Gideon's on it. Maple. Granite. You, at the top. It's a short list. It's a good list."))},
 "rook": {"8": (N("Rook crouches by your pup at the orchard edge and lets it sniff his glove for a long moment."), L("Rook", "Good nose. Better heart. Don't let anyone tell you those aren't the same thing.")),
          "10": (N("Rook is sitting on a fence rail with a blank letter on his knee and a pencil he keeps not using."), L("Rook", "First line's done. 'I'm alive, and I'm sorry, and I live somewhere with apples.' The rest is just walking."))},
 "pip": {"8": (N("Pip runs up waving a letter over their head so fast it's nearly a flag."), L("Pip", "Six lines! I'm going to write SEVEN. Then he'll have to write eight. It's a war. A nice war.")),
         "10": (N("Pip drags you to the foot of the bell tower and points up, very seriously, like a mayor."), L("Pip", "Every day at noon. That's the law. You can ring it on Sundays. That's also the law. I just made it."))},
 "wren_jr": {"8": (N("Wren jr has a jar with holes in the lid and a very large, very calm frog inside it, wearing a leaf like a hat."), L("Wren jr", "He's the mayor of the pond. Don't tell Alder. He gets jealous.")),
             "10": (N("Wren jr pulls you down to her height to whisper, which is a very loud whisper."), L("Wren jr", "When I grow up I'm going to be a potion lady AND a frog lady. Mum says you can't be both. You're a farmer and a hero. So you can."))},
 "tobin": {"8": (N("Tobin hauls you out into the inn yard by the sleeve. A red kite is already high over the roof, tugging at its line."), L("Tobin", "Hold it! Both hands! Feel that? That's the wind saying yes.")),
           "10": (N("Tobin is sitting on the inn's back step with Bram, both of them looking up at the kite on the roof."), L("Tobin", "When the wind's right it points at your farm. I tied it that way on purpose. Don't tell Bram I'm sentimental."))},
 "mabel": {"8": (N("Mabel takes your hand and walks you up the quarry road, humming, till you reach a cut stone by the gate."), L("Mabel", "That's his name. Granite carved it neat. I sing here on Saturdays. You can come. You don't have to sing.")),
           "10": (N("Mabel is at the fence with Granite on a Sunday, handing him nails one at a time, very bossily."), L("Mabel", "He's slow. Mum says that's how stone people do things. I think it's so he can stay longer."))},
 "marlowe": {"8": (N("Marlowe leads you up the lighthouse stairs, all of them, one hand on the rail and one on your shoulder."), L("Marlowe", "Look east. Nothing there now. That's the first time I've been glad to see nothing.")),
             "10": (N("The lamp turns overhead. Marlowe is asleep in his chair by the window, a blanket over his knees, smiling."), N("On the table, a note in big letters: 'Gone to sleep. Lamp's lit. Thank you. - M.'"))},
 "orla": {"8": (N("Orla lifts the lid of the flour tin and shows you three folded scraps of paper, dusted white."), L("Orla", "He never writes more than five words. I've read them five hundred times each. That's the maths of it.")),
          "10": (N("Orla has her good shawl on and a basket of fresh rolls, and is looking at the lighthouse path."), L("Orla", "If I'm not back by supper, mind the wheel. It only needs feeding and talking to. Like the rest of us."))},
 "benno": {"8": (N("Benno leads the grey mare out of the stable, and she noses at his pocket for the apple she knows is there."), L("Benno", "She knew. Horses always know. She stood like a statue till I stopped shaking.")),
           "10": (N("Benno is in the paddock at dawn, walking the race course on foot, counting the turns out loud."), L("Benno", "Fourteen turns. I'll take every one of them slow. Finishing's the race. The rest is just horses."))},
 "ivy": {"8": (N("Ivy slides a small brass key across the bank counter, then a passbook with your name on it in her neat hand."), L("Ivy", "Don't thank me. Thanking is for people who haven't earned it. You have.")),
         "10": (N("Ivy is filing a letter into a drawer marked KEEP, with a small, satisfied click."), L("Ivy", "The capital can keep its vault. I've got a town that settles its accounts. That's worth more than interest."))},
 "tam": {"8": (N("Tam brings the lamb on a rope that the lamb plainly thinks is optional. It headbutts your knee, gently."), L("Tam", "She's called Bramble. She's eaten two of my hats. Feed her and she's yours for life.")),
         "10": (N("Tam is packing a rucksack with a crook tied to the side. The Dollys are watching from the fence, unimpressed."), L("Tam", "I'll write. Sheep don't, so I have to. Keep a light on at the farm; it helps, coming down off the hills."))},
 "old_moss": {"8": (N("Old Moss stops listening to the frogs and listens to you instead, which feels like a bigger thing than it should."), L("Old Moss", "Fifty years is a long time to keep a promise to someone who can't hear it. I'd do it again. That's the trouble.")),
              "10": (N("Old Moss has a clean coat on and is brushing marsh mud off his boots, slowly, the way you'd tidy for a visit."), L("Old Moss", "The frogs will manage a day without me. They pretend they won't. Walk me in when you're ready?"))},
 "granite": {"8": (N("Granite has a hammer in one hand and a fence post over his shoulder, and he's smiling, which nobody at the quarry has seen."), L("Granite", "Nine years I thought the hard part was the rockfall. It was the knocking.")),
             "10": (N("The fence at Hazel's is the straightest fence anyone has ever seen. Granite is adding another rail anyway."), L("Granite", "Sunday dinner. You're invited. Hazel said so, which means it's an order. Bring your appetite; Mabel cooks the beans."))},
 "sel": {"8": (N("Sel traces the carved letters with a fingertip, lips moving, as if reading a bedtime story to the wall."), L("Sel", "Three thousand years, and the last word they cut was 'awake'. I'd like that on my stone. Not soon. But that word.")),
         "10": (N("Sel's tent is packed. A rubbing of the wall is rolled up under one arm, tied with string."), L("Sel", "I'll come back. The stones aren't finished talking. Neither, I think, are we."))},
}
for vid, ms in EXTRA.items():
    for n, (pre, post) in ms.items():
        H[vid]["milestones"][n] = pre + H[vid]["milestones"][n] + post

# Catkins (penguin arc only): taught by the Star Crystal long ago, thousands of
# years old, last of an ancient line of cat guardians who keep the Meow Pow Wow
# as a spiritual way (monasteries, meditations, the four elements). Tom 17:12 #5.
v("catkins", "",
  N("Catkins is sitting very still on a sun-warm rock, paws tucked, eyes half closed.") + L("Catkins", "Sit. Not like that; like a cat. Back straight, tail around your feet. You don't have a tail. Imagine one.", "Breathe in for four. Out for four. That's the first meditation. It took me two hundred years to like it."),
  N("Catkins draws four small circles in the dust with one claw: a drop, a flame, a pebble, a feather.") + L("Catkins", "Water, fire, earth, air. Every guardian learns all four, and then learns that they're one thing wearing four coats.", "The Meow Pow Wow is that one thing, given away. Love, offered with no hook in it. That's all. That's the hardest thing there is."),
  N("Catkins leads you to the edge of Cat-topia, where a mossy stair climbs into the trees to a crumbling gate.") + L("Catkins", "Up there was the old monastery. Cats came from every valley to sit in its courtyard and learn to purr at the dark until the dark sat down.", "It's quiet now. There used to be a bell. If you find anything up there that wants ringing, bring it to me."),
  N("At dusk, Catkins looks up at the first star for a long time before she speaks.") + L("Catkins", "Long ago, before your town was a town, a star came down and sat with a small, frightened kitten. It taught her to breathe, and to purr at the dark, and to keep that gift safe till it was needed.", "I was the kitten. I have kept it for thousands of years. I did not know, until you came, who I was keeping it for.", "Your partners carry it now. I'm not sad. A gift that's kept forever isn't a gift. It's a lock."),
  N("Catkins sits beside you on the warm rock. For once she isn't meditating. She's just sitting.") + L("Catkins", "I made a decision. I'm going to teach again. The courtyard, the four coats, the breathing. Kittens, merkitties, a penguin if one asks politely.", "The first student's name goes on the monastery wall. Yours is there already. Don't argue with a guardian; it's very bad luck.", "Heart at the chest. Hearts and paws. You remembered. You always remember."),
  "Catkins would sit in the middle of the road with her eyes closed and purr, and whatever came would find it had nowhere it wanted to go but home.",
  {"2": "Four in, four out. Don't forget your imaginary tail.", "4": "Water, fire, earth, air. One thing, four coats.", "6": "The monastery stair is mossy. Mind your paws.", "8": "Thousands of years, and it was worth every one.", "10": "A guardian with a student again. Imagine that."})
H["catkins"]["arc"] = "penguins"

# Lines that change when the story sent someone away (hearts.gd swaps them in).
H["gideon"]["milestones"]["10"][0]["if_gone"] = {"juniper": "Gideon is at the anvil, not working. He keeps glancing up the road the clinic cart took."}
H["gideon"]["milestones"]["10"][1]["if_gone"] = {"juniper": "I gave her the ring the morning she left. She said I was an idiot. She took it with her."}
H["bram"]["milestones"]["10"][0]["if_gone"] = {"posy": "Bram is at the kitchen hatch with a letter propped against the salt, reading it again between plates."}
H["bram"]["milestones"]["10"][1]["if_gone"] = {"posy": "Posy writes from the capital. There's a bakery there with her name over the door, and her mother's under it."}
# ♥6 lines for a quest you finished before ♥6 (hearts.gd swaps them in).
H["pip"]["milestones"]["6"][1]["if_done"] = "You already paid me candy for the secret. I kept one back and threw it in the fountain. I made my wish. I'm not telling. It's SCIENCE."
H["tobin"]["milestones"]["6"][0]["if_done"] = "The five shells you got me are on the tail. Bram says a kite needs them. I think he made that up."
H["tobin"]["milestones"]["6"][1]["if_done"] = "The kite's nearly built. The wind's wrong. The wind's always wrong. I don't care."
H["mabel"]["milestones"]["6"][0]["if_done"] = "Your flowers were my crown. Now they're in the cellar. Mum built it for two and it's less empty now, while we wait for cheese."
H["marlowe"]["milestones"]["6"][0]["if_done"] = "The new lens holds. I still look for the crack every night. It was there since the night the bell stopped. Same night, you know."
H["benno"]["milestones"]["6"][0]["if_done"] = "That pup wears the pack like a medal. I can see it in the shoulders. It's got a job now."

# ---- C7 P4: a narrated opening for every ♥2/♥4/♥6 scene too (applied last, so
# the if_done/if_gone line indexes above still point at the spoken lines).
OPEN = {
 "maple": ["Maple is restocking the seed rack and keeps glancing at you over the packets.", "Maple is dusting the top shelf she can't quite reach, standing on a crate.", "A plank in the shop floor creaks under you. Maple winces at it like it's an old friend letting her down."],
 "gideon": ["Gideon watches you swing at the anvil for a long, silent moment, then takes the hammer out of your hands.", "Gideon turns an old hammer over in his big hands, slowly, like it might have something to say.", "Gideon is filing something tiny at the back of the forge. He hides it the moment you walk in."],
 "wren": ["Wren doesn't look up from her mortar and pestle. \"You're doing it wrong,\" she says, before you've done anything.", "Wren is murmuring to a pot of mint. She stops, mid-word, when she sees you.", "Wren is sorting dried flowers into jars and stops at one that's empty."],
 "alder": ["Alder is stamping forms at the hall desk. He stamps yours twice, then looks at it, then at you.", "Alder stands in front of the row of mayors' portraits with his hands behind his back.", "Alder looks out of the hall window at the bell tower for a long time before he says anything."],
 "sal": ["Sal watches you walk up the road the way you'd watch weather coming in.", "Sal is turning a worn coin over his knuckles, not really looking at it.", "Sal is sitting with his bad leg out straight and an empty plate beside him."],
 "finn": ["Finn hands you his spare rod without a word and nods at the water.", "Finn is mending a net and keeps tying the same knot over and over.", "Finn is staring out at the middle of the lake, where the water's darkest."],
 "lumi": ["Lumi is squinting at you over the top of a sketchbook, pencil moving fast.", "Lumi is tidying brushes into a jar, a smear of blue on her nose.", "Lumi holds up a scrap of canvas covered in blue swatches, every one of them crossed out."],
 "theo": ["Theo is pinning a very small notice to the plaza board with a very small pin.", "Theo has two thick books open side by side and a magnifying glass in each hand.", "Theo is pacing between the library shelves, stopping every few steps to look at the floor, as if it goes down further than it should."],
 "hazel": ["Hazel leans on your fence and watches you plant a row, saying nothing until the end of it.", "Hazel is plaiting a little girl's ribbon into a length of twine, absent-mindedly.", "Hazel leads you round the back of the house to a low wooden door set into the hill."],
 "bram": ["Bram sets a bowl of stew in front of you before you've ordered, in the corner seat.", "Bram is wiping down the bar for the third time, though it's already clean.", "Bram is standing by the inn's front window, looking at an empty sill."],
 "posy": ["The bakery smells of the first batch. Posy waves you to wait with a floury hand.", "Posy is kneading dough hard enough to shake the table.", "Posy has a scrap of old paper flattened under a rolling pin on the counter."],
 "juniper": ["Juniper points at the clinic stool. It isn't a suggestion.", "Juniper is folding clean sheets with sharp, exact corners.", "Juniper is writing in a notebook, crossing things out with the same neat line."],
 "rook": ["Rook appears from behind a tree you'd have sworn was too thin to hide anyone.", "Rook is cleaning an old knife by the lodge fire, very carefully.", "Rook is crouched at the orchard edge, studying a line of torn-up grass."],
 "pip": ["Pip skids to a stop in front of you, out of breath and very pleased.", "Pip is sitting on the store steps with a pencil and a letter, tongue out in concentration.", "Pip beckons you over to the fountain with a whole-arm wave and a very secret face."],
 "wren_jr": ["Wren jr is crouched at the pond edge, nose almost in the water.", "Wren jr is sitting on the potion shop step, kicking her heels and looking serious.", "Wren jr is at the pond with an empty jar and a very wobbly lip."],
 "tobin": ["Tobin comes barrelling out of the inn kitchen with a ladle he isn't supposed to have.", "Tobin is drawing kites on the inn steps in chalk, big ones, with long tails.", "Tobin is standing at the very edge of the dock rope, toes exactly on the line."],
 "mabel": ["Mabel is humming to the cows over the fence. They seem to be listening.", "Mabel is sitting on the farm gate, looking up the quarry road.", "Mabel is picking flowers by the lane, one of every colour, very carefully."],
 "marlowe": ["Marlowe is on the lighthouse step, squinting out over the water at nothing in particular.", "Marlowe is polishing an old brass telescope with the corner of his coat.", "Marlowe runs a thumb along a crack in a big glass lens, the way you'd touch a scar."],
 "orla": ["The mill wheel creaks round. Orla is sweeping flour off the step with a stiff broom.", "Orla is sitting on a sack of grain, rubbing her knees and watching the wheel turn.", "Orla is looking across the lake toward the dark lighthouse with her arms folded."],
 "benno": ["A horse in the stable stretches its neck out to sniff your sleeve. Benno watches, nodding.", "Benno is brushing a horse he never rides, in long slow strokes.", "Benno is watching your pup trot about, chin on his folded arms on the fence."],
 "ivy": ["Ivy runs a finger down a column of your bank book, then closes it with a satisfied snap.", "Ivy is straightening a framed letter on the bank wall that is already perfectly straight.", "Ivy is holding a small tarnished coin up to the light by the window."],
 "tam": ["A flock of identical sheep crowds round you. Tam doesn't even try to call them off.", "Tam is looking up at the hills, leaning on a shepherd's crook.", "Tam is crouched in the straw beside a very round ewe, talking to her softly."],
 "old_moss": ["Old Moss is sitting by a bubbling pot at the marsh edge, listening to the frogs.", "Old Moss is turning an old doctor's bag over in his hands, the leather cracked.", "Old Moss is peering into the fog over the deep marsh, his face very still."],
 "granite": ["Granite is at the quarry ledge with a tin mug of terrible coffee, watching you work.", "Granite is sitting on a block of stone, looking down the road toward the farms.", "Granite drops a cracked old bone on the table in front of you with a thud."],
 "sel": ["Sel is lying flat in the ruins, reading the underside of a fallen stone.", "Sel is sketching a carving by lamplight, muttering in a language nobody speaks any more.", "Sel is pacing among the ruin walls, tapping her pencil on each stone she passes."],
}
for vid, ops in OPEN.items():
    for n, t in zip(["2", "4", "6"], ops):
        H[vid]["milestones"][n] = N(t) + H[vid]["milestones"][n]

out = {"_": "Villager heart arcs. milestones: lines at ♥2/4/6/8/10 (play when you next talk to them). quest6: side quest promoted at ♥6 (offered with its own lines). after: a daily line used once a milestone has passed. fall: what they'd do if the town fell (endings).", "villagers": H}
json.dump(out, open("data/hearts.json", "w"), indent=1, ensure_ascii=False)
print(len(H), "villagers,", sum(len(x["milestones"][k]) for x in H.values() for k in x["milestones"]), "milestone lines")
