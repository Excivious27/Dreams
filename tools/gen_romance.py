#!/usr/bin/env python3
"""Dating and marriage data (CONDUCT 7 P1). Edit this file, never data/romance.json.

Writes data/romance.json and merges the two romance items (bouquet, sea_locket) into
data/items.json. Read by scripts/romance.gd (Romance), scripts/dates.gd (Dates).

romance.json keys
  _            doc string
  rules        numbers the code reads: bouquet_hearts 8, propose_hearts 10, dates_needed 2,
               house_tier 2, ex_days 14, invite_every 3, wedding_after 3, chore_chance 0.4
  shared       lines every candidate can use ({name} = the candidate, {you} = your name):
               too_soon, taken, ex, not_yet_house, not_yet_dates, invite, invite_yes,
               invite_no, missed, no_guest, stay_friends, wedding_intro, wedding_end
  candidates   id -> {
      pronoun      "she" / "he" / "they" (text only: there is no gender gate anywhere)
      arcs         arcs they can be romanced in
      bouquet      [lines] said when they accept a Bouquet (start dating)
      dates        3 dates: {scene, place (words for the goal line), hours [from, to),
                   lines [Dialogue lines], q (their question), a [[answer, friend, reply]]}
                   the last answer is always a kind one; no answer is worth less than +0
      propose      [lines] said when they accept the locket
      vows         one line at the wedding
      spouse       {morning: [], evening: [], rain: [], chore: {water, animals, fence, breakfast, pup}}
      dish         item id for the 'breakfast' chore
      corner       furniture art id of their corner piece in your house
      job_days     day % 7 values they still go to work 9-17 after the wedding
      text_gangsters (optional per line): the gangster arc's words
  }
Lines use the Dialogue format {who, text, mood, keep, pic}. All ages: hand-holding, hugs,
a heart emote, nothing more; wine and ale are never drunk.
"""
import json, os, re, sys

D = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")

RULES = {"bouquet_hearts": 8, "propose_hearts": 10, "dates_needed": 2, "house_tier": 2,
         "ex_days": 14, "invite_every": 3, "wedding_after": 3, "chore_chance": 0.4}

SHARED = {
    "too_soon": ["Oh! Flowers... for me? That's sweet, {you}. But let's get to know each other a little better first, all right? Ask me again when we're closer."],
    "too_soon_locket": ["A locket... {you}, I... not yet. Ask me again when we're even closer. Keep it safe for me?"],
    "taken": ["You're already seeing someone, {you}. I'd never want to get in the middle of that. Keep them for your sweetheart."],
    "ex": ["We said we'd stay friends, and I meant it. Give it a little time, {you}. Maybe later."],
    "not_yet_house": ["{you}... yes. Yes! But where would we live? That one-room cottage barely fits you and {pet}. Put up a Farmhouse first (the Plans board by your door, and a permit from Alder at the hall), then ask me again."],
    "not_yet_dates": ["I love that you asked. But we've hardly been out together yet. A couple more evenings first? Then ask me again."],
    "invite": "Hey, {you}... want to meet up this evening?",
    "invite_yes": "It's a date! {place}, after {hour}. Don't be late!",
    "invite_no": "Another time, then. No rush.",
    "missed": ["You never came last night... It's all right. Things come up on a farm. Let's try again soon."],
    "no_guest": "Only the farm's owner can do that here.",
    "stay_friends": ["I understand. Thank you for being honest with me. We'll always be friends, {you}. Always."],
    "wedding_intro": ["The whole town turned out. Someone tied ribbons to every bench, and the arch is woven with whatever the season had to give."],
    "wedding_end": ["Petals in your hair, cake on everyone's plate, and a whole new life waiting at home."],
}

def L(who, text, mood="", **kw):
    d = {"who": who, "text": text}
    if mood:
        d["mood"] = mood
    d.update(kw)
    return d

def date(scene, place, hours, lines, q, answers):
    return {"scene": scene, "place": place, "hours": hours, "lines": lines, "q": q, "a": answers}

C = {}

C["lumi"] = {
    "pronoun": "she", "arcs": ["penguins", "gangsters"], "dish": "berry_pie", "corner": "spouse_lumi", "job_days": [2, 4],
    "bouquet": [L("Lumi", "For me? Wildflowers and... is that a sunflower? You picked the colours like a painter would.", "love"),
                L("Lumi", "Yes. Yes, I'd love to be your sweetheart. Can I paint you sometime? Holding these?", "happy")],
    "dates": [
        date("town", "the town fountain", [18, 22], [L("Lumi", "You came! Look, the lamps are coming on. Everything goes gold and blue at this hour.", "happy"),
              L("Lumi", "I brought a sketchbook. Sit still... no, natural. Pretend I'm not here.")],
             "Do you ever just stop and look at things?",
             [["Every evening, on the porch.", 20, "Then we're the same kind of person. I knew it."],
              ["Not often enough.", 10, "Then I'll remind you. That's what I'm for."],
              ["Only when you're the thing I'm looking at.", 20, "Oh! You... hush. My charcoal's smudging."]]),
        date("beach", "the pier on the beach", [17, 21], [L("Lumi", "The sea at sunset is impossible to paint. I keep trying anyway.", "happy"),
              L("Lumi", "Hold my hand? The boards are wobbly. ...That's my excuse and I'm sticking to it.", "love")],
             "If you could keep one colour forever, which would it be?",
             [["The pink of this sky.", 20, "Then I'll mix it for you and paint the porch door."],
              ["Green, like a new field.", 15, "A farmer's answer. I love it."],
              ["Whatever colour makes you smile.", 20, "That's cheating. Sweet, but cheating."]]),
        date("farm", "your farm, under the stars", [20, 24], [L("Lumi", "I've never seen this many stars. The town lamps hide them.", "surprised"),
              L("Lumi", "Lie back on the grass with me. There. That one's yours, and that one's mine. I'm painting this next: not the stars, you looking at them.", "love")],
             "Do you think we'll still do this when we're old?",
             [["Every clear night.", 20, "Then I'll keep a blanket by the door."],
              ["If my back lets me.", 10, "Ha! I'll bring cushions."],
              ["I hope so, with you.", 20, "...Me too."]]),
    ],
    "propose": [L("Lumi", "A locket... it's like the sea froze in glass. {you}, are you asking what I think you're asking?", "surprised"),
                L("Lumi", "Yes! Of course yes! I'm going to paint this moment so big it covers a whole wall.", "love")],
    "vows": "I promise to paint every season we share, and to always save you the warm side of the porch.",
    "spouse": {"morning": ["Morning, love. The light's perfect today; I'm stealing the window.", "I painted the sunrise while you slept. Don't look yet, it's not done.", "Coffee's on the table. I drew a little heart in the foam."],
               "evening": ["Welcome home. Sit with me a while before supper?", "I finished a painting today. It's of you, coming up the path."],
               "rain": ["Rainy days are for painting indoors. Stay a minute before you go out?"],
               "chore": {"water": "Lumi watered the crops at dawn: 'The droplets looked like little lamps!'", "animals": "Lumi fed the animals and sketched the sleepiest one.", "fence": "Lumi tidied the yard, painted a flower on the gate and stacked the offcuts by the door (3 Wood).", "breakfast": "Lumi left a slice of berry pie by the bed.", "pup": "Lumi played fetch with {pet} until they were both out of breath."}},
}

C["theo"] = {
    "pronoun": "he", "arcs": ["penguins", "gangsters"], "dish": "tea", "corner": "spouse_theo", "job_days": [1, 3, 5],
    "bouquet": [L("Theo", "Flowers. For me. I... I've read about this in at least four novels and never once thought it would happen to me.", "surprised"),
                L("Theo", "Yes. I'd like that very much. I'm told the correct response also involves smiling. There.", "happy")],
    "dates": [
        date("town", "the bench by the town fountain", [18, 22], [L("Theo", "I brought two books. One for you, one for me. We can read side by side. It's terribly romantic, I promise.", "happy"),
              L("Theo", "...You're reading upside down. You're watching me instead, aren't you.")],
             "What's a story you'd want someone to write about you?",
             [["A farmer who brought a town back to life.", 20, "I'd read that. I might even write it."],
              ["Something with a happy ending.", 15, "The best kind. Underrated by critics."],
              ["One where you're in every chapter.", 20, "That's... I need a moment. Page forty-two, very gripping."]]),
        date("lake", "the lake shore", [17, 21], [L("Theo", "The lighthouse logs say the lake glows on still evenings. I wanted to see if it's true.", "happy"),
              L("Theo", "It is. Look. ...I'm glad I'm seeing it with you and not reading about it.")],
             "Do you believe in things you can't explain?",
             [["Of course. I live in this valley.", 20, "Ha! Fair. The valley is one long footnote."],
              ["Only after seeing them.", 10, "A scientist's heart. I respect that."],
              ["I believe in us.", 20, "That's not falsifiable. ...I'll allow it."]]),
        date("farm", "your farm, under the stars", [20, 24], [L("Theo", "I've charted these constellations a hundred times. I've never lain on a farm field to look at them.", "happy"),
              L("Theo", "Your hand's cold. Here. For science.", "love")],
             "Shall I name a star after you?",
             [["Only if it's a bright one.", 15, "The brightest. I've already picked it."],
              ["Name it after both of us.", 20, "A binary star. Perfect. They orbit each other forever."],
              ["I'd rather you just stayed right here.", 20, "Then I'll stay."]]),
    ],
    "propose": [L("Theo", "A locket. You're... proposing. To me. I had a speech prepared for this in case it ever happened and I've forgotten all of it.", "surprised"),
                L("Theo", "Yes. The whole speech was just 'yes' anyway.", "love")],
    "vows": "I promise to read to you on rainy nights, and to never, ever correct your pronunciation of 'library'.",
    "spouse": {"morning": ["Morning. I found a lovely passage last night; I'll read it to you at supper.", "Tea's on the table. I timed it to the second.", "Did you know otters hold hands while they sleep? I thought of us."],
               "evening": ["You're home. I saved your place in the book. And on the sofa.", "Long day? Sit. Tell me everything."],
               "rain": ["Rain on the roof. Best reading weather there is. Come back early tonight?"],
               "chore": {"water": "Theo watered the crops, consulting an almanac for every row.", "animals": "Theo fed the animals and named every one of them after a poet.", "fence": "Theo tidied the yard, alphabetised the tool shed and found 3 Wood filed under W.", "breakfast": "Theo left a pot of perfectly brewed tea by the bed.", "pup": "Theo read {pet} a story. {pet} fell asleep on his feet."}},
}

C["finn"] = {
    "pronoun": "he", "arcs": ["penguins", "gangsters"], "dish": "fish_stew", "corner": "spouse_finn", "job_days": [1, 3, 5],
    "bouquet": [L("Finn", "Well, I'll be. Flowers! Nobody's given me flowers since... well. Since never.", "surprised"),
                L("Finn", "Yes, I'll walk out with you. You cast like you're asking now. I noticed.", "happy")],
    "dates": [
        date("beach", "the pier on the beach", [17, 21], [L("Finn", "Second Cast is tied up at the jetty; I'll row us out after. Brought two rods. No pressure. The fish don't bite much at dusk, but the view does.", "happy"),
              L("Finn", "There. You hear that? Just the water. Best sound in the world.")],
             "What do you think about, out on the water?",
             [["Nothing at all. It's peaceful.", 15, "That's the trick. Most folks never learn it."],
              ["Home.", 20, "Aye. Me too. Lately home's been looking a lot like you."],
              ["The one that got away.", 10, "Ha! Every fisher's ghost story."]]),
        date("lake", "the lake shore", [6, 10], [L("Finn", "Morning mist on the lake. I come out here to think. Never brought anyone before.", "happy"),
              L("Finn", "Sit by me. Here, I made you a cup of something warm.")],
             "You ever been scared of the deep water?",
             [["A little, yes.", 20, "Me too. Don't tell the other fishers. Stay close and you won't need to be."],
              ["Never.", 10, "Brave. Or you haven't seen the big pike yet."],
              ["Not with you here.", 20, "...Now that's a fine thing to say to an old salt."]]),
        date("town", "the town fountain", [18, 22], [L("Finn", "Thought I'd clean up for once. Combed the beard and everything. What do you think?", "happy"),
              L("Finn", "Now don't laugh. I brought you a shell. Found it this morning and thought, that one's for {you}.")],
             "Do you like it here, in the valley?",
             [["I love it.", 15, "Good. Because I'm hoping you'll stay a good long while."],
              ["It's home now.", 20, "Then welcome home."],
              ["It's better with you.", 20, "Ah, you'll make an old fisherman blush."]]),
    ],
    "propose": [L("Finn", "Sea glass... and a locket. You're serious? You want to marry this old fish?", "surprised"),
                L("Finn", "Then yes. A hundred times yes. Wait till I tell the gulls.", "happy")],
    "vows": "I promise to always save you the best catch, and to keep the stove warm for you on cold mornings.",
    "spouse": {"morning": ["Morning! Wind's from the west; good fishing later.", "Made stew. Don't argue, eat.", "Saw a heron by the creek. Reminded me of you; graceful and stubborn."],
               "evening": ["You're back. Sit down, sit down, I'll put the kettle on.", "Good day? Tell me about it while I mend these nets."],
               "rain": ["Rain's good for the fish. Mind you don't slip out there."],
               "chore": {"water": "Finn watered the crops: 'Same as boats, just greener.'", "animals": "Finn fed the animals and told them a fishing story.", "fence": "Finn mended a bit of fence with net twine and stacked the spare boards (3 Wood).", "breakfast": "Finn left a bowl of fish stew on the stove.", "pup": "Finn shared a sardine with {pet}. Don't tell."}},
}

C["rook"] = {
    "pronoun": "he", "arcs": ["penguins", "gangsters"], "dish": "salad", "corner": "spouse_rook", "job_days": [2, 4, 6],
    "bouquet": [L("Rook", "...Flowers. For me." , "surprised"),
                L("Rook", "I'm not good at words. But yes. I'd like that. Don't tell anyone I smiled.", "happy")],
    "dates": [
        date("forest", "the forest path", [17, 21], [L("Rook", "Walk quiet. There. A family of deer. They don't come out for just anyone.", "happy"),
              L("Rook", "They trust you. So do I.")],
             "Why do you like the woods?",
             [["They're calm.", 15, "Calm. Yes. People are loud."],
              ["Because you're in them.", 20, "...That's a good answer."],
              ["I'm still learning to.", 15, "I'll teach you."]]),
        date("lake", "the lake shore", [18, 22], [L("Rook", "I made a fire. Sit. Warm your hands.", "happy"),
              L("Rook", "I don't usually bring people here. This is my spot. Now it's ours.")],
             "Would you be happy with a quiet life?",
             [["Quiet sounds perfect.", 20, "Good. Me too."],
              ["A little noise is fine.", 10, "I'll get used to it."],
              ["Any life, with you.", 20, "...Stop. You'll make me say something soppy."]]),
        date("farm", "your farm, under the stars", [20, 24], [L("Rook", "Owls are out. Hear them? Two of them, calling to each other.", "happy"),
              L("Rook", "Like us. Silly. Come here.", "love")],
             "Do you ever get lonely out in the woods?",
             [["Sometimes.", 15, "Not anymore."],
              ["You won't be now.", 20, "I know."],
              ["I'll visit every day.", 20, "Then I'll keep the kettle on."]]),
    ],
    "propose": [L("Rook", "A locket. You're asking me...", "surprised"),
                L("Rook", "Yes. I've never been more sure of anything. Not even a trail.", "happy")],
    "vows": "I promise to always find my way home to you, whatever the weather.",
    "spouse": {"morning": ["Morning. I checked the fences. All good.", "Brought you wild berries. Don't eat the red ones. Those are mine.", "Fox tracks by the barn. I scared it off. Gently."],
               "evening": ["You're home. Good.", "Sit by the fire with me."],
               "rain": ["Rain. Take a coat. I mean it."],
               "chore": {"water": "Rook watered the crops before sunrise without a word.", "animals": "Rook fed the animals. They follow him around now.", "fence": "Rook mended a broken fence post and split the old one for you (3 Wood).", "breakfast": "Rook left a bowl of wild greens on the table.", "pup": "Rook took {pet} on a long walk in the woods."}},
}

C["juniper"] = {
    "pronoun": "she", "arcs": [], "retired": "engaged to Gideon in her own heart arc (hearts ♥8)", "dish": "salad", "corner": "spouse_juniper", "job_days": [1, 2, 4, 5],
    "bouquet": [L("Juniper", "Oh! For me? That's... Doctor's orders: I accept.", "surprised"),
                L("Juniper", "I mean it, {you}. I'd love to be your sweetheart. Just promise you'll get more sleep.", "happy")],
    "dates": [
        date("town", "the town fountain", [18, 22], [L("Juniper", "I finally got off shift! I brought sandwiches. Real ones, not clinic ones.", "happy"),
              L("Juniper", "Ah, this is nice. Nobody's sniffling, nobody's sprained anything. Just you.")],
             "What do you do to relax?",
             [["Walk the fields at dusk.", 15, "I'll come with you sometime."],
              ["This, with you.", 20, "Good answer. Very good answer."],
              ["I nap. A lot.", 15, "Healthy! I approve."]]),
        date("beach", "the pier on the beach", [17, 21], [L("Juniper", "Sea air is good for the lungs, you know. That's why I suggested here. Mostly.", "happy"),
              L("Juniper", "Okay, also because it's pretty. And so are you.", "love")],
             "Do you ever worry you work too hard?",
             [["Every day.", 15, "Then we'll take care of each other."],
              ["Only when I forget to eat.", 10, "I'll pack you lunches. That's settled."],
              ["I'll slow down for you.", 20, "That's the best medicine I've heard all week."]]),
        date("farm", "your farm, under the stars", [20, 24], [L("Juniper", "I've never stayed up for stars. I'm always too tired. But tonight... worth it.", "happy"),
              L("Juniper", "Can I lean on your shoulder? Just for a minute.", "love")],
             "What does home look like, years from now?",
             [["Animals everywhere.", 20, "And me checking every one of them. Nurse's habits."],
              ["A porch and a quiet evening.", 15, "Prescribed. Daily."],
              ["Whatever we choose together.", 20, "Together. I like that word."]]),
    ],
    "propose": [L("Juniper", "Is that a... are you... oh, I need to sit down. Pulse is very high.", "surprised"),
                L("Juniper", "Yes. Don't make a fuss. ...Fine, make a small fuss. Prescription: forever.", "love")],
    "vows": "I promise to look after you on the hard days, and to dance with you on the good ones.",
    "spouse": {"morning": ["Morning. Water. Then breakfast. Then you can look at me like that.", "I packed you a snack. You'll thank me at noon.", "You were snoring. It was adorable."],
               "evening": ["Welcome home! Let me see those hands. Splinters again!", "Sit. Feet up. Nurse's orders."],
               "rain": ["Rainy days mean colds. Scarf. Now."],
               "chore": {"water": "Juniper watered the crops and checked every leaf for blight.", "animals": "Juniper fed the animals and gave them all a little check-up.", "fence": "Juniper tidied the porch, patched a fence board and set aside 3 Wood.", "breakfast": "Juniper left a fresh salad and a note: 'Eat greens!'", "pup": "Juniper brushed {pet}'s coat until it shone."}},
}

C["posy"] = {
    "pronoun": "she", "arcs": ["penguins", "gangsters"], "dish": "bread", "corner": "spouse_posy", "job_days": [1, 2, 3, 5, 6],
    "bouquet": [L("Posy", "Flowers! Oh, they smell almost as nice as fresh bread. That's a compliment, I promise!", "surprised"),
                L("Posy", "Yes! Yes, I'd love to. I'll bake you something heart-shaped. Is that too much? It's too much. I'm doing it anyway.", "happy")],
    "dates": [
        date("town", "the town fountain", [18, 22], [L("Posy", "I brought a basket. Cinnamon rolls, still warm. I made a dozen. For two people. Don't judge me.", "happy"),
              L("Posy", "Try one. ...Well? Be honest. No, be nice. Be honest-nice.")],
             "What's the sweetest thing you've ever tasted?",
             [["These rolls.", 20, "Oh, stop. No, don't stop."],
              ["Honey straight from the comb.", 15, "Ooh, I could bake with that."],
              ["Hard to say; you're distracting me.", 20, "{you}! I'm going to burn red as a cherry tart."]]),
        date("beach", "the pier on the beach", [17, 21], [L("Posy", "I never get to see the sunset. I'm always cleaning trays by now. This is a treat!", "happy"),
              L("Posy", "Can I hold your hand? Mine are a bit floury. Sorry.", "love")],
             "Would you ever want to run a shop?",
             [["One shop's enough: yours.", 20, "Ha! I'll put you on the payroll. Paid in muffins."],
              ["The farm keeps me busy.", 10, "True. And you grow my wheat!"],
              ["Only if we ran it together.", 20, "A farm-to-bakery... oh, I like that."]]),
        date("farm", "your farm, under the stars", [20, 24], [L("Posy", "Your farm smells like hay and cut grass. It's lovely. I could sleep out here.", "happy"),
              L("Posy", "Look! A shooting star! Make a wish. I already made mine. It might be standing next to me.", "love")],
             "What did you wish for?",
             [["A good harvest.", 10, "Practical. I love it."],
              ["That this lasts.", 20, "It will. I'll make sure of it."],
              ["It's a secret, but you're in it.", 20, "Oh, you!"]]),
    ],
    "propose": [L("Posy", "Is this... a locket? Are you proposing? To me? Over the sound of my oven timer in my head?", "surprised"),
                L("Posy", "YES! I'm baking the biggest cake this town has ever seen!", "happy")],
    "vows": "I promise warm bread every morning, and a warm hug every night.",
    "spouse": {"morning": ["Morning, sweetheart! Fresh loaf on the table.", "I tried a new recipe. You're my taste tester. Forever.", "You've got flour on your nose. ...That's mine. I got flour on your nose."],
               "evening": ["You're home! Supper's warm. Dessert is warmer.", "Sit, sit. Tell me about your day while I knead."],
               "rain": ["Rain! Perfect baking weather. Hurry home?"],
               "chore": {"water": "Posy watered the crops, humming a baking song.", "animals": "Posy fed the animals and saved crumbs for the birds.", "fence": "Posy swept the porch, fixed a squeaky gate and stacked the spare slats (3 Wood).", "breakfast": "Posy left a jar of her mum's jam and a warm roll on the table: second batch.", "pup": "Posy gave {pet} a little dog biscuit she baked."}},
}

C["ivy"] = {
    "pronoun": "she", "arcs": ["penguins", "gangsters"], "dish": "coffee", "corner": "spouse_ivy", "job_days": [1, 2, 3, 4],
    "bouquet": [L("Ivy", "A bouquet. That's... not in any of my ledgers. I'll need a new column.", "surprised"),
                L("Ivy", "Yes. I accept. Wholeheartedly. Is there a form? I'm kidding. Mostly.", "love")],
    "dates": [
        date("town", "the town fountain", [18, 22], [L("Ivy", "I balanced the books early just to come here. That's how much this matters.", "happy"),
              L("Ivy", "I wrote down things to talk about. Don't look. ...Fine, you can look. It just says 'be yourself'.")],
             "Are you a saver or a spender?",
             [["A saver.", 15, "Be still my heart."],
              ["A spender, on seeds.", 15, "An investor! In vegetables. I can work with that."],
              ["I'd spend all my evenings on you.", 20, "...That's an excellent return."]]),
        date("lake", "the lake shore", [17, 21], [L("Ivy", "It's so quiet out here. No coins clinking. Just frogs.", "happy"),
              L("Ivy", "Hold my hand? I'm afraid of frogs. That's a lie. I just wanted to hold your hand.", "love")],
             "What do you want, more than anything?",
             [["A good life on the farm.", 15, "Steady and true. Like you."],
              ["A home that feels like home.", 20, "We could build that."],
              ["You already know.", 20, "I'd like to hear you say it anyway."]]),
        date("farm", "your farm, under the stars", [20, 24], [L("Ivy", "I counted the stars. Lost count at three hundred and twelve. First time I've ever stopped counting.", "happy"),
              L("Ivy", "It's because you're here, you know.", "love")],
             "Do you think I'm too serious?",
             [["You're perfect.", 15, "Statistically impossible. But thank you."],
              ["Just serious enough.", 20, "Good. Because I'm seriously fond of you."],
              ["You make me laugh every day.", 20, "Really? Me? ...Write that down."]]),
    ],
    "propose": [L("Ivy", "A locket. Silver chain, sea glass... you're proposing. The interest on this is going to be incredible.", "surprised"),
                L("Ivy", "Yes. Absolutely, completely, one-hundred-percent yes.", "love")],
    "vows": "I promise to keep our little home in order, and to keep my heart open to you always.",
    "spouse": {"morning": ["Morning! I made a budget for the week. We're doing wonderfully.", "Coffee's ready. Exactly two sugars.", "You looked so peaceful sleeping. I nearly didn't wake you. Nearly."],
               "evening": ["You're home. I saved the last biscuit. That's love.", "Sit with me. I'll do the sums later."],
               "rain": ["Rain. Take the umbrella. I labelled it 'yours'."],
               "chore": {"water": "Ivy watered the crops in perfectly even rows.", "animals": "Ivy fed the animals right on schedule.", "fence": "Ivy tidied the shed, counted every nail and set aside 3 Wood.", "breakfast": "Ivy left a hot cup of coffee by the bed.", "pup": "Ivy taught {pet} a new trick: 'sit pretty'."}},
}

C["benno"] = {
    "pronoun": "he", "arcs": ["penguins", "gangsters"], "dish": "bread", "corner": "spouse_benno", "job_days": [1, 3, 5],
    "bouquet": [L("Benno", "Whoa, flowers? For me? The horses usually eat them before I get a look.", "surprised"),
                L("Benno", "Yeah. Yes! I'd love to. Wait till I tell the horses. They'll be thrilled.", "happy")],
    "dates": [
        date("meadow", "the meadow", [17, 21], [L("Benno", "I brought apples. For us, not the horses. Okay, one for the horses.", "happy"),
              L("Benno", "The meadow at sunset... the grass goes all gold. Feels like running, even when you're sitting still.")],
             "Ever wanted to just ride and never stop?",
             [["All the time.", 15, "Then let's ride together sometime."],
              ["I'd rather stop here, with you.", 20, "...Yeah. Here's good."],
              ["I'm scared of horses.", 10, "I'll introduce you to the gentle ones."]]),
        date("town", "the town fountain", [18, 22], [L("Benno", "I washed! Twice! You can barely smell the stable.", "happy"),
              L("Benno", "Can I... hold your hand? I won't pull. Promise.", "love")],
             "What makes a good partner, do you think?",
             [["Someone who shows up.", 20, "Every day. Rain or shine. That's me."],
              ["Someone kind to animals.", 20, "Well, I've got that covered."],
              ["Someone who makes me laugh.", 15, "Knock knock. ...Okay, I'm working on it."]]),
        date("farm", "your farm, under the stars", [20, 24], [L("Benno", "Your animals all settled down when I got here. They know a friend.", "happy"),
              L("Benno", "Look at all those stars. Sit with me? The grass is soft.", "love")],
             "Do you think I'm silly?",
             [["Wonderfully silly.", 20, "Good. I'll keep it up."],
              ["Only a little.", 15, "A little's fine."],
              ["You're perfect as you are.", 20, "Aw. Now I'm the one blushing."]]),
    ],
    "propose": [L("Benno", "Is that a... are you asking me to marry you?", "surprised"),
                L("Benno", "YES! Oh, wow, yes! Can the horses come to the wedding?", "happy")],
    "vows": "I promise to always be steady for you, like a good horse on a long road.",
    "spouse": {"morning": ["Morning! The animals are fed. I couldn't help it.", "Brought you an apple. Polished it on my shirt.", "Big day? I believe in you."],
               "evening": ["You're home! Let me take your boots.", "Sit, I'll rub your shoulders. Strong hands from the stable, see?"],
               "rain": ["Muddy out there. Watch your step."],
               "chore": {"water": "Benno hauled water for every row of crops.", "animals": "Benno fed and brushed every animal on the farm.", "fence": "Benno fixed a loose fence board and stacked the offcuts (3 Wood).", "breakfast": "Benno left a slice of bread with honey.", "pup": "Benno raced {pet} round the yard. {pet} won."}},
}

C["tam"] = {
    "pronoun": "he", "arcs": ["penguins", "gangsters"], "dish": "salad", "corner": "spouse_tam", "job_days": [2, 4, 6],
    "bouquet": [L("Tam", "Flowers? The sheep'll be jealous.", "surprised"),
                L("Tam", "Yes. I'd like that. You're a good soul, {you}. Even the old ram likes you.", "happy")],
    "dates": [
        date("meadow", "the meadow", [17, 21], [L("Tam", "The Dollys have voted you in. Unanimous. They never agree on anything. Sit on the hill with me; you can see the whole valley from here.", "happy"),
              L("Tam", "I come up here to think. Thought I'd bring the thing I think about most.", "love")],
             "Do you count sheep to sleep?",
             [["Every night.", 15, "Ha. I count farmers now."],
              ["I count stars.", 15, "Better. They don't wander off."],
              ["I think about you.", 20, "...Same, if I'm honest."]]),
        date("farm", "your farm, under the stars", [20, 24], [L("Tam", "Wool blanket. Spun it myself. Room for two.", "happy"),
              L("Tam", "Quiet nights like this make all the hard ones worth it.")],
             "Could you be happy with a simple life?",
             [["Simple is best.", 20, "Thought so."],
              ["Simple and busy.", 15, "That's farming."],
              ["Any life you're in.", 20, "Now that's not simple at all. That's everything."]]),
        date("town", "the town fountain", [18, 22], [L("Tam", "Town at night. Lots of people. I'm not used to it. Hold my hand so I don't wander back to the hills?", "happy"),
              L("Tam", "Better. Much better.", "love")],
             "Do you miss anything from before you came here?",
             [["Not really.", 15, "Good. The valley's yours now."],
              ["Old friends.", 15, "You've got new ones. Me, for one."],
              ["Nothing. I found you here.", 20, "Ah. You'll make an old shepherd soft."]]),
    ],
    "propose": [L("Tam", "A locket... You want to marry me? Good thing I didn't go up the hill.", "surprised"),
                L("Tam", "Yes. I'll knit you a wedding scarf. It'll be the softest thing you ever wore.", "love")],
    "vows": "I promise to keep you warm, keep you fed, and keep you laughing.",
    "spouse": {"morning": ["Morning. Wind's turning. Good day for wool.", "Made porridge. Eat it while it's hot.", "Knitted you socks. Don't look at the heel."],
               "evening": ["You're back. Fire's lit.", "Sit with me. The wool can wait."],
               "rain": ["Rain. The sheep hate it. I don't mind. Means you might stay in a bit longer."],
               "chore": {"water": "Tam watered the crops at first light.", "animals": "Tam fed the animals. They followed him like a flock.", "fence": "Tam fixed a gap in the fence: 'Can't have strays.' The old rails went on the woodpile (3 Wood).", "breakfast": "Tam left a bowl of fresh greens on the table.", "pup": "Tam taught {pet} to herd. Mostly it herded Tam."}},
}

C["sel"] = {
    "pronoun": "they", "arcs": ["penguins", "gangsters"], "dish": "tea", "corner": "spouse_sel", "job_days": [2, 3, 5],
    "bouquet": [L("Sel", "A bouquet. In the old carvings, this meant a promise. Do you know what you're promising?", "surprised"),
                L("Sel", "...Yes. I'll be your sweetheart. History can wait. You can't.", "love")],
    "dates": [
        date("mountain", "the mountain path", [17, 21], [L("Sel", "There are ruins up here no one else knows about. I wanted you to see them first.", "happy"),
              L("Sel", "Careful. Take my hand on the rocks.", "love")],
             "Do you think the people who built this were happy?",
             [["I hope they were.", 15, "I like to think so too."],
              ["Happy enough to build something lasting.", 20, "Like us. Building something."],
              ["Not as happy as I am right now.", 20, "...Flatterer. Keep going."]]),
        date("lake", "the lake shore", [18, 22], [L("Sel", "The old texts say this lake was a mirror for the sky. Look how still it is.", "happy"),
              L("Sel", "I've spent years reading about the past. I never thought about my own future. Until you.")],
             "What would you want to leave behind?",
             [["A good farm.", 15, "Practical. And wonderful."],
              ["Happy memories for everyone.", 20, "That's the best legacy there is."],
              ["A story about us.", 20, "Then let's write it well."]]),
        date("farm", "your farm, under the stars", [20, 24], [L("Sel", "The ancients mapped these stars. I'd rather map them with you.", "happy"),
              L("Sel", "There's a constellation the carvings call 'the Two Travellers'. There. Side by side.", "love")],
             "Will you travel with me, someday?",
             [["Anywhere.", 20, "Then I'll pack two of everything."],
              ["As long as we come home.", 20, "Home. Yes. That's the best part."],
              ["I'd like that.", 15, "Then it's a plan."]]),
    ],
    "propose": [L("Sel", "A locket. In the old way, that meant forever.", "surprised"),
                L("Sel", "Yes. Forever sounds right.", "love")],
    "vows": "I promise to remember every day with you, so the story of us is never lost.",
    "spouse": {"morning": ["Morning. I translated a love poem last night. It's about a farmer. Coincidence.", "Tea's brewing. It's an old recipe.", "I dreamed of the ruins. You were there, holding a lantern."],
               "evening": ["You're home. Sit with me; I'll tell you what I found today.", "Every evening with you is worth recording."],
               "rain": ["Rain. Good for reading old texts. And for staying close."],
               "chore": {"water": "Sel watered the crops, reciting an ancient planting song.", "animals": "Sel fed the animals and sketched their tracks.", "fence": "Sel mended a fence and stacked the old boards by the post (3 Wood).", "breakfast": "Sel left a pot of fragrant tea by the bed.", "pup": "Sel took {pet} digging for treasure. They found a bone."}},
}

VENUES = {"penguins": {"place": "the chapel", "pic": "cut_wedding_penguins", "officiant": "Mayor Alder"},
          "gangsters": {"place": "the plaza bandstand", "pic": "cut_wedding_gangsters", "officiant": "Mayor Alder"}}

ITEMS = {
    "bouquet": {"name": "Bouquet", "type": "romance", "value": 135, "icon": "bouquet_pink", "rarity": "uncommon", "tier": 1,
                "desc": "Give to someone at 8 hearts to start dating."},
    "sea_locket": {"name": "Sea-Glass Locket", "type": "romance", "value": 3300, "icon": "pendant_pearl", "rarity": "rare", "tier": 1,
                   "desc": "Give to your sweetheart at 10 hearts to propose."},
}

# Your spouse's birthday at home (Romance._spouse_talk, first talk of the day). C12 P4 (07-24).
SPOUSE_BIRTHDAY = {
    "lumi": "You remembered. Of course you did; you live with the calendar I painted.",
    "theo": "I've written myself a very small notice: 'Today, be spoiled.' You may read it.",
    "finn": "Birthday. Row me out on Second Cast and we'll call it even.",
    "rook": "Birthday. I don't usually count them. I'm counting this one.",
    "juniper": "My birthday. Doctor's orders: you're not allowed to work too hard today. Neither am I.",
    "posy": "I baked my own birthday cake at four this morning. Second batch is yours. Obviously.",
    "ivy": "My birthday. I've entered it in the ledger under 'assets'. You're in the same column.",
    "benno": "Birthday. The mare got an apple and so do you. Don't tell her you got the bigger one.",
    "tam": "Birthday. The Dollys sang. It sounded like baaing. It was singing.",
    "sel": "My birthday. Three thousand years of walls and nobody wrote that one down. You did.",
}
for _cid, _t in SPOUSE_BIRTHDAY.items():
    C[_cid]["spouse"]["birthday"] = _t

BAD = re.compile(r"\b(wine|ale|beer|drunk|kiss(ed|es|ing)?|whiskey|bed together|family someday|full house)\b", re.I)


def lines_of(c):
    out = list(c["bouquet"]) + list(c["propose"])
    for d in c["dates"]:
        out += d["lines"]
    return out


def check(npcs, items):
    err = []
    for cid, c in C.items():
        n = npcs.get(cid)
        if n is None:
            err.append(cid + ": not in npcs.json")
            continue
        if n.get("role") == "Kid":
            err.append(cid + ": a kid can't be a candidate")
        if len(c["dates"]) != 3:
            err.append(cid + ": needs 3 dates")
        for l in lines_of(c):
            if not l.get("who") or not l.get("text"):
                err.append(cid + ": line without who/text")
        for d in c["dates"]:
            if min(a[1] for a in d["a"]) < 0:
                err.append(cid + ": a date answer below +0")
        if c["dish"] not in items:
            err.append(cid + ": dish %s missing" % c["dish"])
        blob = json.dumps(c)
        if BAD.search(blob):
            err.append(cid + ": all-ages word: " + BAD.search(blob).group(0))
        for k in ("water", "animals", "fence", "breakfast", "pup"):
            if k not in c["spouse"]["chore"]:
                err.append(cid + ": chore line " + k)
        if "Wood" not in c["spouse"]["chore"].get("fence", ""):
            err.append(cid + ": the fence chore gives 3 Wood; its line must say so")
        if not c["spouse"].get("birthday"):
            err.append(cid + ": spouse birthday line")
    if BAD.search(json.dumps(SHARED)):
        err.append("shared: all-ages word")
    return err


def main():
    npcs = json.load(open(os.path.join(D, "npcs.json")))
    items = json.load(open(os.path.join(D, "items.json")))
    err = check(npcs, items)
    if err:
        print("\n".join(err))
        sys.exit(1)
    out = {"_": "Generated by tools/gen_romance.py (edit that, not this file)", "rules": RULES, "shared": SHARED,
           "venues": VENUES, "candidates": C}
    with open(os.path.join(D, "romance.json"), "w") as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
        f.write("\n")
    for k, v in ITEMS.items():
        items[k] = v
    path = os.path.join(D, "items.json")
    nl = open(path, "rb").read()[-1:] == b"\n"
    with open(path, "w") as f:
        json.dump(items, f, indent=1, ensure_ascii=False)
        if nl:
            f.write("\n")
    print("romance.json: %d candidates" % len(C))


if __name__ == "__main__":
    main()
