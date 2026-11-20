# Dreams — story bible (Round 1 writing pass)

Two arcs on one world. Both end at the same truth: the planet has a prismatic
crystal at its heart; the Dark Crystal is a Star Crystal that went bitter; the
President of the river cities bargained with it. Joy is what it eats.

Themes: **what you keep** (the letter, the locket, the bell), **who you take
with you** (companions, crew), **what you turn back instead of destroy** (Meow
Pow Wow, Doc's "there's a man in there").

Rules for every line: a villager never says a thing anyone could say; every
choice is answered within two chapters; jokes land in the middle of real
stakes, never instead of them.

---

## Arc A — The Two Too Powerful Penguins (wholesome)

Source: Tom and his daughter's book (`reference/PENGUIN-STORY-by-Tom-and-daughter.txt`); design map in `docs/PENGUIN-ARC.md`. The Star Crystal is *she*; the Dark Crystal is her brother; Pip-Pip and Nova are brother and sister.

**Chapter 1 — The Day the Star Crystal Came Down.** She lands in your field and asks for help; the farm gets a bubble (safe after dark). Day 2+: red sky and a howl in the east meadow — the Grumps, the Dark Crystal's army. After the Big Grump: the collar (Grumps are loved things, squeezed). Decision **tell_town** (told → Alder/Theo warm; quiet → Maple keeps it). She points you to the purring past the big meadow: Cat-topia.

**Chapter 2 — Cat-topia.** Catkins, leader of Cat-topia, walks out of the fog at the crystal meadow and teaches the **Meow Pow Wow** (`meow_taught`, +5 mana). The resonator wants three shards (quest `spark`). The second spark → the cave shakes → the **catship** and the **litter catapults**: the Grump ships crash into the Wastes; you get 5 Litter Boxes (throwable stink, stuns Grumps). The Commander (Combat 3 gate) leaves the brass locket → **locket** decision → Finn at the lake.

**Chapter 3 — Mount Prismatica.** The mountain is Prismatica: its top is in space (the moon pad). First night on it: **Big Jim's campfire** (heals, he camps with you). The pass: the **crystal babies** ("bee bop boo baby") — cursed, not evil; four spawn, the leader must be *turned back* with the Meow Pow Wow (flag `babies_calm`), and **Coldy** joins with the **sacred key**. Above the clouds: the **finargles** (purple eye-light dazes you) and the Crystal Knight — Grandfather Auk. Decision **knight_mercy** (Nova tries first → `auk_ally`; fight → Knight's Shard +1 damage).

**Chapter 4 — The Finargles and the Merkitties.** After the Knight the finargles take you: **crystal prison**, Fennimore's telepathic question (decision **fennimore**: tell her the truth → `fennimore_doubt` → she can be turned at the finale; say nothing → `fennimore_sure`). Coldy drills the floor with the spell; the uphill stream; the waterfall; you wake at the lake. **Mer and the merkitties** hide you from the spies and share their magic: `mermaid_gift` (a tail in any water, swim and dive anywhere), Mer joins, and Big Jim screams. The teleporter wants three refined crystals; the bell (Alder's gold clapper, `bell_rung`); the night before: everyone at the gate.

**C7 canon pass:** see docs/PENGUIN-ARC.md "C7 canon pass" (converted Crystopia crystals, 21-year bell timeline, Celestica/Crystopia, Catkins the guardian, Nova's dream p2_nova_dream, Fennimore p3_whisper/p4_prison, elders p5_elder_*).

**Chapter 5 — The Heart of Mount Prismatica.** The spire is the Dark Crystal; **Fennimore** rises beside him (finargle_elder boss). If she doubted, she hesitates (`fennimore_turnable`). The bell halves his shell; Auk holds the shards off; a bitter companion stands with him. Ending **revert** (make the heart: two crystals, both crying; Fennimore's light goes out and she is just a fuzzy thing with no mouth to say sorry) or **shatter**. Epilogue: she plants herself in the field; the old dog comes home; two penguins on the fence. "Today there's turnips."

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
