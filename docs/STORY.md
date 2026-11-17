# Dreams — story bible (Round 1 writing pass)

Two arcs on one world. Both end at the same truth: the planet has a prismatic
crystal at its heart; the Dark Crystal is a Light Crystal that went bitter; the
President of the river cities bargained with it. Joy is what it eats.

Themes: **what you keep** (the letter, the locket, the bell), **who you take
with you** (companions, crew), **what you turn back instead of destroy** (Meow
Pow Wow, Doc's "there's a man in there").

Rules for every line: a villager never says a thing anyone could say; every
choice is answered within two chapters; jokes land in the middle of real
stakes, never instead of them.

---

## Arc A — The Too Two Powerful Penguins (wholesome)

**Chapter 1 — A Light in the Field.** The Light Crystal lands in your field
(intro). Partner at the gate on day 3: Pip-Pip and Nova (one stays, one watches
the mountain; the penguin arc always offers penguins). The howling in the east
meadow is a Big Grump: it was Posy's dog, Biscuit's litter-mate. Decision
**tell_town**: tell the town what grumps are, or keep it quiet. *Payoff:* told →
Alder opens the bell question early (Ch4) and Posy's 6-heart scene changes;
quiet → Maple keeps your secret (her 6-heart line) and Posy never learns until
Ch5.

**Chapter 2 — The Spark.** Refine three shards at the resonator. The first
mine keeper (sleep beat: you dream of a heart beating under the ground). The
Wastes gate opens at combat 3. The Grump Commander falls and leaves a brass
locket — Finn's brother, who went to the river cities and "came back wrong".
Decision **locket**: give it to Finn / keep it. *Payoff:* give → Finn's 8-heart
scene and he rows you to the sky-stair shortcut; keep → it hums in your pack and
the Crystal Knight recognises it (Ch3 fight is shorter: the Knight hesitates).

**Chapter 3 — The Sky Stair.** The great tree, the sky islands, the Crystal
Knight (a penguin elder the Dark Crystal froze; Nova knows him). Mer in the
grotto on floor 5. The Knight's last words: "a man in a grey suit bargains with
it" — the first thread to the President. Decision **knight_mercy**: shatter
him / let Nova try the Meow Pow Wow (only if Nova is known and rank ≥ 2).
*Payoff:* mercy → the elder appears at the moon as a ghost-ally; shatter → his
crystal is a weapon (+1 sword damage), and Nova is quieter with you.

**Chapter 4 — The Moon Road.** Power the teleporter. Bitter companions leave
east after day 20. The bell: Alder and Theo (ev_bell) need a gold clapper.
Decision **bell**: forge and ring it (calls the town) / leave it. The night
before the moon: each companion says their piece at the farm gate.

**Chapter 5 — The Heart.** The spire on the moon is the missing piece: the
Dark Crystal grown into the moon. It speaks with the voice of the Light
Crystal's lost sibling. Fight. If the bell rang, the town's voices halve its
strength. If a bitter companion left, they stand beside it (spawned as a foe).
Ending **revert** (Meow Pow Wow rank 3 known and used — the Dark Crystal turns
back; the moon glows) or **shatter** (it breaks; the Light Crystal mourns; the
grumps stop coming anyway). Epilogue at the farm: the Light Crystal plants
itself in your field for good; Posy's dog comes home if the town was told.

## Arc B — Gangster's Paradise (serious)

**Chapter 1 — Lie Low.** Rain, a deed with the wrong name, the letter
(**letter**: burned / kept / memorised — pays off in Ch3 and Ch5). The
President's man in the meadow. Sal: "Call it rent." Partner on day 3: Big Jim
or Sal.

**Chapter 2 — The Hideout.** Through the gate to Hideout town. Riley (mechanic)
and Manny (bartender) know your name but not your face. Recruit **Deuce** (card
sharp, needs a stake: ◆150 or beat him at his own table) and **Mama Rosa** (feed
her kitchen: 10 of any crop). Decision **shop_1**: fund Deuce's card parlour in
town — money, but Posy moves out of the bakery and a thug patrol walks the
avenue at night. *Payoff:* Posy's bakery boarded; Bram's lines change; the
bell can't be rung with three shops funded.

**Chapter 3 — The Docks.** The dock boss's manifest: every crate marked with a
purple crystal. Recruit **Specs** (bring her the manifest), **Ladder** (climb
the crane with him), **Halo** (win a race on the dock road). **Marlene** the
fence offers ◆2000 for the letter if you kept it (**sell_letter**). *Payoff:*
sold → the President knows your face by Ch4 (Enforcer stronger, Dice won't
join); kept → the letter opens the tower in Ch5 without a fight at the door.

**Chapter 4 — Neon.** Flame under the dragon sign; the pit under the street.
Recruit **Vic & Val** (the twins — win the pit), **Dice** (pay his debt ◆300 or
scare the gambler), **The Kid** (find his board — a side task), **Doc** (bring 5
wild herbs; he patches the crew), **Sasha** (beat her in the ring). Decisions
**shop_2**, **shop_3** (Lumi then Juniper leave town). Doc's loyalty 3 scene:
"I used to work for him. There's a man in there."

**Chapter 5 — Uptown.** The Enforcer at the tower steps. The letter (if kept)
opens the doors; otherwise Sasha and Big Jim break them. The President in the
lobby with a Dark Crystal shard in his chest. Ending **free** (Doc at loyalty 3
and you choose to pull the shard: he's just a tired man; the city's crews stand
down) or **take** (you take the city; the Dark Crystal's whisper moves into you
— the last line is the handwriting from the letter, in your own hand). If the
bell was rung (≤2 shops), the villagers are in the plaza when you come home;
if 3 shops, the town is yours and empty.

## Villager heart arcs (data/hearts.json)

Every villager has five milestone scenes (♥2 / ♥4 / ♥6 / ♥8 / ♥10) that play
when you next talk to them, each 3–5 lines in their voice, plus a **personal
quest** at ♥6 (an existing side quest promoted, with new lines) and a changed
daily line after each milestone. The ♥10 scene names what they'd do if the town
fell, and that line is reused in the ending.

## Crew (data/crew.json)

Twelve recruits, each: how they join, three loyalty scenes (talk to them at the
hideout), a passive perk at loyalty 1/2/3, and what they do in the finale.
