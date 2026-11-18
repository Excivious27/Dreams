# Dreams — Art Prompts 28: what the loop-9 audit found

WHAT THIS COVERS, most important first: dialogue faces for six villagers whose portrait is a different person from the one walking around town (Marlowe, Orla, Ivy, Tam, Benno, Sel); fight poses for three dog breeds, so a pet stays the same dog when it fights (golden, collie, husky).

RULES THAT APPLY TO EVERY IMAGE: 1536×1024, 16-bit pixel art, clean 1px dark outlines, warm saturated Stardew Valley / Sun Haven palette, flat #FF00FF magenta background, NO GRID LINES, NO TEXT OR LABELS OR NUMBERS anywhere (not under, above or beside any piece), no watermark, NO LETTERBOXING. At least 24 px of clear magenta between separate pieces. All ages: nothing gory.

PORTRAIT RULE: dialogue portraits 96×96, head and shoulders, facing slightly right, soft vignette, no frame, the same framing and painting style as the existing villager portraits (attach portraits/npc_old_moss/neutral and portraits/npc_granite/neutral for the style). One villager per row, 12 expressions left to right in this order: NEUTRAL, HAPPY, SAD, ANGRY, SURPRISED, TIRED, LAUGHING, WORRIED, DETERMINED, SLEEPY, SICK (pale, a little green, never gross), IN LOVE (blushing, soft eyes). Cells at x = 24 + N×120 (12 columns), y = 24 + M×120. The face, hair, hat, clothes and colours must be the SAME PERSON as the attached walking sprite: copy them exactly, only bigger and more detailed.

PET ROW RULE: 64×64 cells at x = 24 + N×88, y = 24 + M×88, the animal about 40 px long with its paws on the bottom edge of the cell, all facing right, every frame the same size, one breed per row. Each row, left to right: BITE ×4 (lunge and snap), BARK ×2, HURT ×2 (flinch, eyes squeezed shut, no blood), LIMP ×4 (one paw up, tail down), GUARD ×2 (planted low, hackles up, ears back), HOWL ×2. The dog must be EXACTLY the same dog as the attached sheet: same coat colours and markings, same size and build, same collar or none.

---

## BATCH 1 — Villager faces that match the walkers (2 images)

Six villagers talk with a face that belongs to someone else: the lighthouse keeper is an old bearded man in a yellow raincoat, but his portrait is a young man in a leather jacket; the bank teller wears a green visor and glasses, but her portrait is a blonde witch; and so on. These two sheets redraw their faces from the sprites the game already walks around.

> IMAGE "w479_villager_faces_a.png": THREE VILLAGERS by the PORTRAIT RULE (96×96, 12 expressions per row in the order given, x = 24 + N×120, y = 24 + M×120), attach characters/npc_marlowe/idle, characters/npc_orla/idle and characters/npc_ivy/idle. Row 0 MARLOWE, the old lighthouse keeper: a big bushy white beard and moustache, a ruddy nose, bushy white brows, a yellow sou'wester rain hat and a yellow oilskin raincoat over a dark green knitted sweater, a brass lantern glowing warm at the bottom edge of the frame. Row 1 ORLA, the miller: a sturdy, strong woman, auburn hair tied under a white kerchief, a sleeveless purple top, a white apron dusted with flour, a smudge of flour on one cheek, friendly and no-nonsense. Row 2 IVY, the bank teller: bright red hair in two buns, a green visor cap, round glasses, a white shirt with a green tie and a dark brown waistcoat, the corner of a ledger book held up at the bottom edge, neat and precise. Nothing else in the picture.

> IMAGE "w480_villager_faces_b.png": THREE VILLAGERS by the PORTRAIT RULE (96×96, 12 expressions per row in the order given, x = 24 + N×120, y = 24 + M×120), attach characters/npc_tam/idle, characters/npc_benno/idle and characters/npc_sel/idle. Row 0 TAM, the shepherd: warm brown skin, short curly brown hair, a thick cream sheepskin collar over a green coat and a pink tunic, the curled top of a wooden shepherd's crook beside the shoulder (no apples, no bandana). Row 1 BENNO, the stable hand: a young man with short dark hair under a wide straw hat, a cream shirt with rolled sleeves and a brown vest, a coil of rope over one shoulder, a bit of straw stuck to the hat. Row 2 SEL, the ruins scholar: purple hair, round glasses, a deep-purple hooded cloak with gold trim (hood up, framing the face), the glowing violet crystal head of a staff beside the shoulder, curious and clever. Nothing else in the picture.

## BATCH 2 — Dogs that stay the same dog in a fight (1 image)

When your pet fights, three breeds turn into a different dog: the black-and-white collie becomes a sable collie, the pale golden becomes a deep-gold fluffy one, and the husky has no fight poses at all. This sheet draws the fight poses for the dogs the game already uses.

> IMAGE "w481_dog_fight_match.png": FIGHT POSES by the PET ROW RULE (64×64 cells, x = 24 + N×88, y = 24 + M×88, 16 frames per row in the order given), drawn from the attached sheets: attach animals/dog_golden/idle, animals/dog_collie/idle and animals/dog_husky/idle. Row 0 THE GOLDEN: the pale apricot short-coated dog with floppy ears exactly as in its sheet. Row 1 THE COLLIE: the black-and-white border collie with the white chest, white paws and white muzzle stripe exactly as in its sheet (NOT a brown sable collie). Row 2 THE HUSKY: the pale grey-and-white husky with the pricked ears and curled tail exactly as in its sheet. Nothing else in the picture.

======================================================================
COVERAGE TABLE (file → what it fixes → code name the slicer should write)
w479  faces for Marlowe, Orla, Ivy → portraits/npc_marlowe|npc_orla|npc_ivy/<12 moods> (slice_world.py: `_portrait_rows("w479_villager_faces_a.png", ["portraits/npc_marlowe", "portraits/npc_orla", "portraits/npc_ivy"], rows_n=3)`, mood names from EXPR; run after w131). Code: none (dialogue.gd prefers npc_<id>).
w480  faces for Tam, Benno, Sel → portraits/npc_tam|npc_benno|npc_sel/<12 moods> (same call with "w480_villager_faces_b.png"; run after the w336 PORTRAIT_ROWS and the npc_sel cut at slice_world.py:5364 so it wins). Code: none.
w481  dog fight poses → animals/dog_golden|dog_collie|dog_husky/bite|bark2|hurt|limp|guard|howl (slice_world.py: new w481 with `_peng_rows(..., 3)` and the w192 _pup_strips layout; run after w192). Code: none (pet.gd picks the strips up by name).

LEFT OUT ON PURPOSE
- Catkins' face: the right portrait (portraits/catkins, the hooded dark cat) already exists; a grey-cat npc_catkins overrides it (code fix, audit 15 #2).
- Orla's and Benno's life poses (wave, sit, talk...): drawn already on w157; the slicer merged their two rows (audit 15 #1).
- Pip, Lumi, Wren, Alder and the other first-wave villagers: their new walking sheets (20 w437–w441, 23 w465) are drawn FROM their portraits, so they will match.
- Old Moss and Granite: portrait and sprite already match.
- Cat fight poses: the cats were drawn doing dig/fetch/beg on w193, and the game uses them that way.
- Amethyst ore, the fountain, the moon ground and everything else from 17–27 still waiting: asked already; nothing new has been uploaded since loop 2.
