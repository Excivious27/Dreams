# Dreams: Steam Content Survey and IARC draft answers (S1 P5, 2026-11-20)

Status: **staged**. Entered by Claude in Chrome in the Steamworks session (docs/STEAM.md, Part A "Store page").
Answers are drawn from the real game; `python3 tools/ratings_facts_check.py` (check.sh) re-derives the facts each
answer depends on and fails with "ratings.md answer X is now false" if the game drifts. Survey answers lock after
Valve approves them (changes go through Steam Support), so any later content change (casino, co-op chat, new
weapons) means a review of this file first.

## Decision waiting on Tom: the Gilded Ace casino (s1_13-01)

The gangster arc has a casino (tools/gen_casino.py: Gilded Slots, Roulette, Blackjack, Big or Small, Video Poker),
played with in-game cash only: no real money, no purchase, no cash-out, daily stake caps.

- **Option A, keep it as it is.** Answer "Simulated gambling: yes, traditional casino games, in-game currency only".
  Likely outcome: PEGI 18 / USK 18 in Europe and Germany under IARC (PEGI rates simulated gambling that teaches
  traditional casino games at 18 since 2020), ESRB-style T. The store page can then not be pitched as all-ages.
- **Option B (recommended), make it fantastical.** Rename and reskin the tables away from real casino forms
  (invented symbols, no 7/BAR/cherries; a wheel without roulette numbers or red/black; a card duel with invented
  suits and no blackjack/poker hand names; the building becomes e.g. "The Gilded Parlour"). Maths stays in
  scripts/casino_rules.gd. Likely outcome: PEGI 12 / USK 12 / E10+.
- **Option C, switch it off in store builds** (a build flag; the door says "closed for renovation"). Same ratings as B
  but the content is gone from the Steam build.

Until Tom picks, every answer below is written for Option B with the Option A difference marked **[A]**.

## Steam Content Survey: General content

| Topic | Answer | Evidence |
|---|---|---|
| Violence | Yes, frequent, player-initiated, stylised. Penguin arc: swords, lances and spells against fantasy creatures (Grumps, slimes, golems, wisps, crystal foes); a calming spell turns some Grumps friendly. Gangster arc: melee weapons and firearms (Six-Shooter, Gold Revolver, Scattergun, Tommy Gun, using "rounds") against thugs, rivals and robots. | data/items.json tools (scattergun, tommy_gun, gold_revolver); audio/sfx/shot*.ogg; scripts/enemy.gd |
| Blood and gore | None. No blood, gore, dismemberment or bodies: defeated foes vanish in a puff, people are knocked out and wake up, the player is "knocked out" and wakes at the clinic. The Marked never die. | scripts/enemy.gd `_die`; CLAUDE.md content rules |
| Violence against animals | None. Beasts are driven off and never harvested; nothing drops meat, pelts or bones; farm animals are rehomed, never slaughtered or sold for meat. | tools/animal_rule_test.py; scripts/ranch.gd `rehome` |
| Fear | Mild: spooky wisps and ghosts, a marsh witch, dark mines. No jump scares, no horror. | |
| Sexual content and nudity | None. Romance is dating and marriage (no gender checks, one partner), with no kissing scenes and no nudity. | scripts/romance.gd |
| Language | None. No profanity; mild teasing only ("shut up" once, affectionate). | data/*.json scan in ratings_facts_check.py |
| Alcohol | Reference only. Wine, ales and ciders are craftable trade goods (sold and gifted); nobody drinks them, no effects. An inn has decorative taps. | tools/drink_rule_test.py |
| Tobacco and drugs | None. | tools/gen_casino.py BANNED list; Racket has no drugs |
| Gambling | Simulated, in-game cash only, no real money, no cash-out, no purchase. **[A]** traditional casino games (slots, roulette, blackjack, poker). **[B]** invented games of chance. Arcade prize games use earned tickets only. | tools/gen_casino.py; scripts/casino_rules.gd |
| Crime themes | Gangster arc: counterfeit bills and "heat", a laundromat, fencing goods, a smuggler boss. Told in an all-ages tone. | scripts/racket.gd |
| Humour | Mild slapstick. | |

## Steam Content Survey: Mature content

Leave every box unchecked (Some Nudity or Sexual Content, Frequent Violence or Gore, Adult Only Sexual Content,
Gratuitous Sexual Content). General Mature Content: unchecked under Option B/C; **[A]** consider checking it with the
line below.

Description of mature content (paste only if a box is checked): "Stylised, bloodless combat with swords, spells and
cartoon firearms; simulated casino games played with in-game money only; references to alcohol as a trade good."

## IARC questionnaire (entered through Steamworks)

| Question | Answer |
|---|---|
| Users interact online | Yes: optional online co-op, invite by room code (later Steam invites), up to 8 players. No text or voice chat. Player-chosen names (character, town, pet, ranch animals) are visible to co-op partners. Name filter and host kick: **not yet in the game** (s1_13-03 / s1_13-10, staged for the co-op package); answer "no moderation tools" until they ship. |
| Shares location | No. |
| Digital purchases | No in-game purchases, no DLC, no ads, no loot boxes. |
| Unrestricted internet | No. The game only talks to its own co-op relay (and, on web, fetches its own music files). |
| Personal data | None collected; see docs/steam-store/privacy.md. |

## Expected ratings (not entered anywhere: Steam/IARC assign them)

| Board | Option B / C | Option A |
|---|---|---|
| ESRB-style (IARC) | E10+ (Fantasy Violence, Alcohol Reference, Users Interact) | T (adds Simulated Gambling) |
| PEGI | 12 (non-realistic violence against human-like characters) | 18 (simulated gambling of traditional casino games) |
| USK | 12 | 18 |
| ClassInd (Brazil) | 12 (violence, criminal acts) | 14 |

Do NOT enter any PEGI/USK rating in the Steamworks Ratings section unless a real board review happened.

## Open items (staged)

- s1_13-03 / s1_13-10: name filter for every typed name + host kick + 6-character room codes. Touches
  scripts/net.gd, scripts/title.gd, scripts/puppet.gd, scripts/team_animals.gd and server/server.js, which belong to
  the co-op and title packages this round; `scripts/name_filter.gd` + `tools/name_filter_test.gd` are in the repo
  ready for those hooks.
- Beasts still "poof" when beaten (scripts/enemy.gd `_die`); a flee tween for wolf/hound/crab/serpent/eel would
  match the "driven off" wording better.
- Item names "Blood Orange" (fruit), skill "Rare Bloodlines" and "Sal's lifeblood" are harmless but could be renamed
  for a clean "no blood" scan.
