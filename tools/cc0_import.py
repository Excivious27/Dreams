#!/usr/bin/env python3
"""Bring CC0 sound packs (downloaded from OpenGameArt) into the game.

    python3 tools/cc0_import.py [--src /tmp/cc0/dl] [--dry DIR]

Every pack used is CC0 (public domain) or dual-licensed with CC0 as an option;
tools/cc0_sources.json records each pack's page, author and licence, and this
script refuses any file whose pack is not in it. MAP below says which files
become which game sound:

  sfx   -> audio/sfx/<name>.ogg (+ <name>_2.ogg, <name>_3.ogg variations). Mono,
           trimmed, peak-normalised, capped at --cap seconds with a short fade.
  spot  -> audio/amb/spot_<name>.ogg (one-shots Ambience plays off to the side).
  bed   -> audio/amb/<name>.ogg: a seamless loop (several files are joined with
           crossfades when a pack only has short takes), quiet (-26 LUFS).

Names written go into audio/sfx/REAL.txt / audio/amb/REAL.txt so the
placeholder generators never overwrite them. A sound with an ACE version
(tools/ace_kits.py) is left alone: those are listed in audio/sfx/ACE.txt.
"""
import argparse, fnmatch, json, os, subprocess, sys, tempfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# name: (kind, [patterns relative to the CC0 root], options)
MAP = {
    # --- footsteps ---------------------------------------------------------
    "step_grass": ("sfx", ["different-steps-on-wood-stone-leaves-gravel-and-mud/*leaves01*", "different-steps-on-wood-stone-leaves-gravel-and-mud/*leaves02*", "fantozzis-footsteps-grasssand-stone/*SandR1*"], {"cap": 0.4}),  # no boot steps on grass (Tom: "clomping")
    "heartbeat": ("sfx", ["heartbeat-single-sound/heartbeat*"], {"cap": 1.1}),
    "whimper": ("sfx", ["dog-sounds-pauliuw/sad_dog.*", "dog-sounds-pauliuw/sad_dog_1.*"], {"cap": 1.6, "af": "highpass=f=250,afftdn=nf=-40,agate=threshold=0.02:ratio=3"}),
    "step_dirt": ("sfx", ["fantasy-sound-effects-tinysized-sfx/*soil-steps-01*", "100-cc0-sfx-2/sfx100v2_footstep_01*", "100-cc0-sfx-2/sfx100v2_footstep_02*"], {"cap": 0.45}),  # soft soil, not boots
    "step_sand": ("sfx", ["fantozzis-footsteps-grasssand-stone/*SandL1*", "fantozzis-footsteps-grasssand-stone/*SandR2*", "fantozzis-footsteps-grasssand-stone/*SandL3*"], {"cap": 0.45}),
    "step_stone": ("sfx", ["fantozzis-footsteps-grasssand-stone/*StoneL1*", "fantozzis-footsteps-grasssand-stone/*StoneR2*", "fantozzis-footsteps-grasssand-stone/*StoneL3*"], {"cap": 0.45}),
    "step_wood": ("sfx", ["100-cc0-sfx-2/*footstep_wood_01*", "100-cc0-sfx-2/*footstep_wood_02*", "100-cc0-sfx-2/*footstep_wood_03*"], {"cap": 0.45}),
    "step_snow": ("sfx", ["4-dry-snow-steps/*01*", "4-dry-snow-steps/*02*", "9-wet-snow-steps/*03*"], {"cap": 0.5}),
    "step_water": ("sfx", ["100-cc0-sfx-2/*footstep_wet_01*", "100-cc0-sfx-2/*footstep_wet_02*", "100-cc0-sfx-2/*footstep_wet_03*"], {"cap": 0.5}),
    "step_mud": ("sfx", ["fantasy-sound-effects-tinysized-sfx/*mud-steps-01*", "fantasy-sound-effects-tinysized-sfx/*mud-steps-02*", "fantasy-sound-effects-tinysized-sfx/*mud-steps-03*"], {"cap": 0.5}),
    "step_gravel": ("sfx", ["different-steps-on-wood-stone-leaves-gravel-and-mud/*gravel*", "42-snow-and-gravel-footsteps/*gravel_02*", "42-snow-and-gravel-footsteps/*gravel_05*"], {"cap": 0.5}),
    "step_leaves": ("sfx", ["20-rustles-dry-leaves/*rustle04*", "20-rustles-dry-leaves/*rustle07*", "20-rustles-dry-leaves/*rustle09*"], {"cap": 0.5}),
    # --- combat ------------------------------------------------------------
    "swing": ("sfx", ["swishes-sound-pack/swish-1.*", "swishes-sound-pack/swish-2.*", "swishes-sound-pack/swish-3.*"], {"cap": 0.5}),
    "swing_heavy": ("sfx", ["swish-bamboo-stick-weapon-swhoshes/*swosh-05*", "swish-bamboo-stick-weapon-swhoshes/*swosh-12*", "swish-bamboo-stick-weapon-swhoshes/*swosh-20*"], {"cap": 0.7}),
    "hit": ("sfx", ["37-hitspunches/hit01*", "37-hitspunches/hit04*", "37-hitspunches/hit07*"], {"cap": 0.5}),
    "crit": ("sfx", ["150-combat-sound-effects/*Impact_01*", "150-combat-sound-effects/*Impact_02*", "10-impactshield-blocks/impact.1.*"], {"cap": 0.8}),
    "hurt": ("sfx", ["37-hitspunches/hit12*", "37-hitspunches/hit15*", "37-hitspunches/hit18*"], {"cap": 0.5}),
    "block": ("sfx", ["10-impactshield-blocks/impact.2.*", "10-impactshield-blocks/impact.3.*", "10-impactshield-blocks/impact.4.*"], {"cap": 0.6}),
    "sword_clash": ("sfx", ["20-sword-sound-effects-attacks-and-clashes/sword_clash.1.*", "20-sword-sound-effects-attacks-and-clashes/sword_clash.2.*", "20-sword-sound-effects-attacks-and-clashes/sword_clash.3.*"], {"cap": 0.8}),
    "unsheathe": ("sfx", ["rpg-sound-pack/sword-unsheathe.*", "rpg-sound-pack/sword-unsheathe2.*", "rpg-sound-pack/sword-unsheathe3.*"], {"cap": 0.8}),
    "die": ("sfx", ["rpg-sound-pack/bubble.*", "rpg-sound-pack/bubble2*", "3-pop-sounds/3pops*"], {"cap": 0.6}),
    "thud": ("sfx", ["35-wooden-crackshitsdestructions/impactwood01*", "35-wooden-crackshitsdestructions/impactwood05*", "35-wooden-crackshitsdestructions/impactwood09*"], {"cap": 0.6}),
    "stun": ("sfx", ["150-combat-sound-effects/*Retro Electric Short 03*", "150-combat-sound-effects/*Retro Electric Short 17*"], {"cap": 0.8}),
    "zap": ("sfx", ["150-combat-sound-effects/*ElectroZap*", "150-combat-sound-effects/*EnergyZap*", "150-combat-sound-effects/*PowerZap_01*"], {"cap": 0.9}),
    "emp": ("sfx", ["150-combat-sound-effects/*EMP_01*", "150-combat-sound-effects/*EMP_02*", "150-combat-sound-effects/*EMP_03*"], {"cap": 1.6}),
    "shot": ("sfx", ["gunshots/*22%20Pistol*", "gunshot-sound-effect/*", "25-cc0-bang-firework-sfx/shot_01*"], {"cap": 0.8}),
    "shot_shotgun": ("sfx", ["gunshot-sounds/shotty*", "25-cc0-bang-firework-sfx/shot_02*"], {"cap": 1.0}),
    "shot_rifle": ("sfx", ["gunshot-sounds/mosin*", "gunshot-sounds/sks*", "gunshot-sounds/cz*"], {"cap": 1.0}),
    "reload": ("sfx", ["gun-reload-sounds/gunreload1*", "2-gun-reloads/gun_reload.1*", "2-gun-reloads/gun_reload.2*"], {"cap": 1.4}),
    "dry_click": ("sfx", ["50-rpg-sound-effects/metalClick*", "small-metal-clasp-open-close-switching/*"], {"cap": 0.4}),
    "cannon": ("sfx", ["25-cc0-bang-firework-sfx/cannon_01*", "25-cc0-bang-firework-sfx/cannon_02*", "25-cc0-bang-firework-sfx/cannon_03*"], {"cap": 1.6}),
    "boom": ("sfx", ["25-cc0-bang-firework-sfx/bang_01*", "25-cc0-bang-firework-sfx/bang_04*", "25-cc0-bang-firework-sfx/bang_07*"], {"cap": 1.6}),
    "laser": ("sfx", ["150-combat-sound-effects/*Laser Pistol 1*", "150-combat-sound-effects/*Laser Pistol 2*", "150-combat-sound-effects/*Laser Pistol 3*"], {"cap": 0.8}),
    "slime": ("sfx", ["80-cc0-rpg-sfx/creature_slime_01*", "80-cc0-rpg-sfx/creature_slime_02*", "80-cc0-rpg-sfx/creature_slime_03*"], {"cap": 0.8}),
    "monster": ("sfx", ["80-cc0-rpg-sfx/creature_monster_01*", "80-cc0-rpg-sfx/creature_monster_02*", "80-cc0-rpg-sfx/creature_monster_03*"], {"cap": 1.2}),
    "roar": ("sfx", ["80-cc0-rpg-sfx/creature_roar_01*", "80-cc0-rpg-sfx/creature_roar_02*", "80-cc0-rpg-sfx/creature_roar_03*"], {"cap": 2.0}),
    "stomp": ("sfx", ["80-cc0-creture-sfx-2/stomp_01*", "rpg-sound-pack/giant1*", "rpg-sound-pack/giant3*"], {"cap": 1.2}),
    "spirit": ("sfx", ["rpg-sound-pack/shade1.*", "rpg-sound-pack/shade5.*", "rpg-sound-pack/shade9.*"], {"cap": 1.2}),
    "bug": ("sfx", ["80-cc0-creature-sfx/bug_01*", "80-cc0-creature-sfx/bug_02*", "80-cc0-creature-sfx/bug_03*"], {"cap": 0.8}),
    "bat": ("sfx", ["bat-screeches/bat_01*", "bat-screeches/bat_02*", "bat-screeches/bat_03*"], {"cap": 0.8}),
    "growl": ("sfx", ["bear-growls/bear_01*", "bear-growls/bear_02*"], {"cap": 1.5}),
    "grunt": ("sfx", ["80-cc0-creature-sfx/grunt_01*", "80-cc0-creature-sfx/grunt_02*", "80-cc0-creature-sfx/grunt_03*"], {"cap": 0.8}),
    "critter": ("sfx", ["80-cc0-creature-sfx/cute_01*", "80-cc0-creature-sfx/cute_04*", "80-cc0-creature-sfx/cute_07*"], {"cap": 0.8}),
    # --- magic -------------------------------------------------------------
    "spell": ("sfx", ["80-cc0-rpg-sfx/spell_01*", "80-cc0-rpg-sfx/spell_02*", "rpg-sound-pack/magic1*"], {"cap": 1.4}),
    "spell_fire": ("sfx", ["150-combat-sound-effects/*Fire Spell Impact 1*", "150-combat-sound-effects/*Fire Spell Impact 2*", "150-combat-sound-effects/*Fire Spell Impact 3*"], {"cap": 1.4}),
    "spell_ice": ("sfx", ["150-combat-sound-effects/*Ice Spell Impact 1*", "150-combat-sound-effects/*Ice Spell Impact 2*", "ice-spells/ice*"], {"cap": 1.4}),
    "spell_lightning": ("sfx", ["150-combat-sound-effects/*Lightning Spell Impact 1*", "150-combat-sound-effects/*Lightning Spell Impact 2*", "150-combat-sound-effects/*Lightning Spell Impact 3*"], {"cap": 1.4}),
    "spell_nature": ("sfx", ["150-combat-sound-effects/*Plant Spell Impact 1*", "150-combat-sound-effects/*Plant Spell Impact 2*", "150-combat-sound-effects/*Plant Spell Impact 3*"], {"cap": 1.4}),
    "spell_earth": ("sfx", ["150-combat-sound-effects/*Earth Spell Impact 1*", "150-combat-sound-effects/*Earth Spell Impact 2*", "150-combat-sound-effects/*Earth Spell Impact 3*"], {"cap": 1.4}),
    "spell_dark": ("sfx", ["3-dark-magic-spells/fout-01*", "3-dark-magic-spells/fout-02*", "3-dark-magic-spells/fout-03*"], {"cap": 1.6}),
    "heal": ("sfx", ["cure-magic/Cure1*", "cure-magic/Cure3*", "magic-words-healing-sound-effect/health_restore*"], {"cap": 1.6}),
    "teleport": ("sfx", ["50-cc0-sci-fi-sfx/teleport_01*", "50-cc0-sci-fi-sfx/teleport_02*"], {"cap": 1.6}),
    "freeze": ("sfx", ["freeze-spell-0/*", "ice-spells/coldsnap*"], {"cap": 1.4}),
    "drain": ("sfx", ["energy-drain/*"], {"cap": 1.6}),
    # --- tools, farm, world -------------------------------------------------
    "chop": ("sfx", ["50-rpg-sound-effects/chop*", "100-cc0-metal-and-wood-sfx/wood_hit_01*", "100-cc0-metal-and-wood-sfx/wood_hit_04*"], {"cap": 0.6}),
    "timber": ("sfx", ["tree-chop-fall-thud/*", "100-cc0-metal-and-wood-sfx/wood_falling_01*"], {"cap": 2.5}),
    "pick": ("sfx", ["80-cc0-rpg-sfx/stones_01*", "80-cc0-rpg-sfx/stones_02*", "100-cc0-sfx-2/*stones_01*"], {"cap": 0.6}),
    "rock_break": ("sfx", ["breaking-rock/*", "100-cc0-sfx-2/*stones_02*", "100-cc0-sfx-2/*stones_03*"], {"cap": 1.0}),
    "dig": ("sfx", ["shovel-sound/*", "fantasy-sound-effects-tinysized-sfx/*soil-steps-01*"], {"cap": 0.8}),
    "plant": ("sfx", ["20-rustles-dry-leaves/*rustle01*", "20-rustles-dry-leaves/*rustle02*", "20-rustles-dry-leaves/*rustle03*"], {"cap": 0.5}),
    "harvest": ("sfx", ["20-rustles-dry-leaves/*rustle10*", "20-rustles-dry-leaves/*rustle12*", "20-rustles-dry-leaves/*rustle15*"], {"cap": 0.6}),
    "water": ("sfx", ["fantasy-sound-effects-tinysized-sfx/*water-pour-01*", "fantasy-sound-effects-tinysized-sfx/*water-vial-fill-01*"], {"cap": 1.2}),
    "drop": ("sfx", ["fantasy-sound-effects-tinysized-sfx/*water-drop-01*", "fantasy-sound-effects-tinysized-sfx/*water-drop-02*", "fantasy-sound-effects-tinysized-sfx/*water-drop-03*"], {"cap": 0.6}),
    "splash": ("sfx", ["6-short-water-splashes/*01*", "6-short-water-splashes/*03*", "40-cc0-water-splash-slime-sfx/splash_02*"], {"cap": 1.0}),
    "fish_escape": ("sfx", ["40-cc0-water-splash-slime-sfx/splash_10*", "40-cc0-water-splash-slime-sfx/splash_12*"], {"cap": 1.0}),
    "cast": ("sfx", ["swish-bamboo-stick-weapon-swhoshes/*swosh-10*", "swish-bamboo-stick-weapon-swhoshes/*swosh-15*"], {"cap": 0.7}),
    "reel": ("sfx", ["68-workshop-sounds/*ratchet1*", "68-workshop-sounds/*ratchet2*"], {"cap": 0.8}),
    "bubble": ("sfx", ["40-cc0-water-splash-slime-sfx/bubble_01*", "40-cc0-water-splash-slime-sfx/bubble_02*", "40-cc0-water-splash-slime-sfx/bubble_03*"], {"cap": 0.8}),
    "crate_break": ("sfx", ["35-wooden-crackshitsdestructions/crack01*", "35-wooden-crackshitsdestructions/crack04*", "100-cc0-metal-and-wood-sfx/wood_breaking_01*"], {"cap": 1.0}),
    "twig": ("sfx", ["fantasy-sound-effects-tinysized-sfx/*wood-twigs-break-01*", "fantasy-sound-effects-tinysized-sfx/*wood-twigs-break-02*"], {"cap": 0.6}),
    "door": ("sfx", ["door-open-door-close-set/*DoorOpen01*", "door-open-door-close-set/*DoorOpen03*", "door-open-door-close-set/*DoorOpen05*"], {"cap": 1.2}),
    "door_close": ("sfx", ["door-open-door-close-set/*DoorClose01*", "door-open-door-close-set/*DoorClose03*", "door-open-door-close-set/*DoorClose05*"], {"cap": 1.2}),
    "locked": ("sfx", ["door-lock-sounds/LockedDoorHandleJiggle*"], {"cap": 1.0}),
    "unlock": ("sfx", ["door-lock-sounds/UnlockDoor*", "100-cc0-metal-and-wood-sfx/lock_open_01*"], {"cap": 1.0}),
    "chest_open": ("sfx", ["100-cc0-sfx/wooded_box_open*", "80-cc0-rpg-sfx/lock_01*"], {"cap": 1.2}),
    "gate": ("sfx", ["100-cc0-metal-and-wood-sfx/metal_open_01*", "100-cc0-metal-and-wood-sfx/wood_squeak_01*"], {"cap": 1.4}),
    "keys": ("sfx", ["100-cc0-metal-and-wood-sfx/keys_01*", "100-cc0-metal-and-wood-sfx/keys_03*"], {"cap": 1.0}),
    "glass": ("sfx", ["100-cc0-sfx/glass_01*", "100-cc0-sfx/glass_02*", "100-cc0-sfx/glass_03*"], {"cap": 1.0}),
    "drink": ("sfx", ["202-more-sound-effects/Drink_01*", "202-more-sound-effects/Drink_02*", "202-more-sound-effects/Drink_03*"], {"cap": 1.2}),
    "eat": ("sfx", ["7-eating-crunches/crunch.1.*", "7-eating-crunches/crunch.3.*", "apple-bite/*"], {"cap": 0.8}),
    "coin": ("sfx", ["80-cc0-rpg-sfx/item_coins_01*", "80-cc0-rpg-sfx/item_coins_02*", "80-cc0-rpg-sfx/item_coins_03*"], {"cap": 0.8}),
    "cash": ("sfx", ["purchasing-sound-effect/*", "202-more-sound-effects/Money_01*", "202-more-sound-effects/Money_05*"], {"cap": 1.2}),
    "gem": ("sfx", ["80-cc0-rpg-sfx/item_gem_01*", "80-cc0-rpg-sfx/item_gem_02*", "80-cc0-rpg-sfx/item_gem_03*"], {"cap": 1.0}),
    "pickup": ("sfx", ["80-cc0-rpg-sfx/item_misc_01*", "80-cc0-rpg-sfx/item_misc_02*", "80-cc0-rpg-sfx/item_misc_03*"], {"cap": 0.6}),
    "cloth": ("sfx", ["202-more-sound-effects/Cloth_01*", "202-more-sound-effects/Cloth_03*", "rpg-sound-pack/cloth.*"], {"cap": 0.7}),
    "equip": ("sfx", ["fantasy-weapons-and-apparel-sfx-library/*belt-buckle-01*", "fantasy-weapons-and-apparel-sfx-library/*belt-buckle-03*", "rpg-sound-pack/chainmail1*"], {"cap": 0.8}),
    "page": ("sfx", ["book-flip-sounds/BookFlip1.*", "book-flip-sounds/BookFlip3.*", "book-flip-sounds/BookFlip5.*"], {"cap": 0.8}),
    "book": ("sfx", ["50-rpg-sound-effects/bookOpen*", "50-rpg-sound-effects/bookClose*"], {"cap": 0.8}),
    "map": ("sfx", ["opening-and-closing-a-map-sounds/snd_use_map*", "opening-and-closing-a-map-sounds/snd_close_map*"], {"cap": 1.0}),
    "mail": ("sfx", ["100-cc0-sfx/paper_01*", "100-cc0-sfx/paper_02*"], {"cap": 0.8}),
    "hammer": ("sfx", ["100-cc0-metal-and-wood-sfx/wood_hammer_01*", "100-cc0-metal-and-wood-sfx/wood_hammer_02*", "100-cc0-metal-and-wood-sfx/hammer_01*"], {"cap": 0.6}),
    "anvil": ("sfx", ["hammer-on-anvil/*", "blacksmiths-hammer/blacksmithhammer.*", "100-cc0-metal-and-wood-sfx/metal_hit_01*"], {"cap": 1.0}),
    "tools": ("sfx", ["68-workshop-sounds/*tool clatter*", "68-workshop-sounds/*tool rummaging*", "100-cc0-metal-and-wood-sfx/tools_01*"], {"cap": 1.2}),
    "drill": ("sfx", ["68-workshop-sounds/*drill short 1*", "68-workshop-sounds/*drill short 2*"], {"cap": 1.2}),
    "pot": ("sfx", ["50-rpg-sound-effects/metalPot1*", "50-rpg-sound-effects/metalPot2*", "50-rpg-sound-effects/metalPot3*"], {"cap": 0.8}),
    "cooking": ("sfx", ["boiling-water-loops/cooking_without_cover*"], {"cap": 2.0}),
    "fireworks": ("sfx", ["25-cc0-bang-firework-sfx/fw_01*", "25-cc0-bang-firework-sfx/fw_03*", "25-cc0-bang-firework-sfx/fw_05*"], {"cap": 2.5}),
    "pop": ("sfx", ["3-pop-sounds/pop1*", "3-pop-sounds/pop2*", "bubbles-pop/*"], {"cap": 0.5}),
    "stink": ("sfx", ["58-random-sound-effects/Fizz_01*", "58-random-sound-effects/Fizz_02*"], {"cap": 1.2}),
    "cave_in": ("sfx", ["cave-in/*"], {"cap": 3.0}),
    "typing": ("sfx", ["keyboard-soundpack-1-typing-and-single-keystrokes/*human_vel-001*", "keyboard-soundpack-1-typing-and-single-keystrokes/*human_vel-004*"], {"cap": 1.2}),
    "keypress": ("sfx", ["keyboard-soundpack-1-typing-and-single-keystrokes/*keypress-001*", "keyboard-soundpack-1-typing-and-single-keystrokes/*keypress-005*", "keyboard-soundpack-1-typing-and-single-keystrokes/*keypress-009*"], {"cap": 0.3}),
    "terminal": ("sfx", ["50-cc0-sci-fi-sfx/terminal_01*", "50-cc0-sci-fi-sfx/terminal_02*", "50-cc0-sci-fi-sfx/terminal_03*"], {"cap": 1.0}),
    "beep": ("sfx", ["50-cc0-sci-fi-sfx/beep_01*", "50-cc0-sci-fi-sfx/beep_02*", "50-cc0-sci-fi-sfx/beep_03*"], {"cap": 0.6}),
    "servo": ("sfx", ["quick-drill-fix/*", "60-cc0-sci-fi-sfx/sfx_05a*"], {"cap": 1.0}),
    "power_off": ("sfx", ["machine-shutting-down/*"], {"cap": 2.0}),
    "power_up": ("sfx", ["50-cc0-retro-synth-sfx/power_up_01*", "50-cc0-retro-synth-sfx/power_up_03*"], {"cap": 1.2}),
    "car_door": ("sfx", ["cardoorsfx/door_closing*", "cardoorsfx/door_opening*"], {"cap": 1.2}),
    "car_start": ("sfx", ["car-engine-start-01/generic_car_startengine.*"], {"cap": 2.5}),
    "siren": ("sfx", ["sirens-and-alarm-noise/*"], {"cap": 3.0}),
    "alarm": ("sfx", ["alarm-2/*", "30-cc0-sfx-loops/alarm_01*"], {"cap": 2.0}),
    "horn": ("sfx", ["bicycle-horn/*"], {"cap": 1.0}),
    "cards": ("sfx", ["58-random-sound-effects/Card_Swipe_01*", "58-random-sound-effects/Cards_Riffle_Shuffle_01*"], {"cap": 1.2}),
    "clap": ("sfx", ["58-random-sound-effects/Hand_Clap_01*", "58-random-sound-effects/Hand_Clap_02*"], {"cap": 0.6}),
    # --- animals -------------------------------------------------------------
    "bark": ("sfx", ["80-cc0-creature-sfx/barking_01*", "80-cc0-creature-sfx/barking_02*", "dog-barking-mono/*"], {"cap": 0.9}),
    "meow": ("sfx", ["cat-purr-meow/cat_softmew*", "cat-purr-meow/cat_mewfood*", "kitten-mew/kitten_mew-1.*"], {"cap": 1.2}),
    "purr": ("sfx", ["cat-purr-meow/cat_purractive_loop*"], {"cap": 3.0}),
    "sheep": ("sfx", ["sheep-baa/sheep_baa.*"], {"cap": 1.5}),
    "penguin": ("sfx", ["penguin-sounds/penguin_01*", "penguin-sounds/penguin_02*"], {"cap": 1.5}),
    "crow": ("sfx", ["crow-caw/*", "crow/*"], {"cap": 1.2}),
    "frog": ("sfx", ["frog-croaks/croak_02*", "frog-croaks/croak_03*", "frog-croaks/croak_04*"], {"cap": 1.0}),
    "seagull": ("sfx", ["solo-seagull-sound-effects/*Ambient%201*", "solo-seagull-sound-effects/*Ambient%203*", "solo-seagull-sound-effects/*Ambient%205*"], {"cap": 1.6}),
    "horse": ("sfx", ["horse-trotting/*"], {"cap": 2.0}),
    "snore": ("sfx", ["80-cc0-creature-sfx/snore*", "80-cc0-creture-sfx-2/snore_02*"], {"cap": 2.0}),
    # --- ambience spots (Ambience plays these off to the side) ---------------
    "thunder": ("spot", ["100-cc0-sfx-2/*thunder_01*"], {"cap": 5.0}),
    "drip": ("spot", ["fantasy-sound-effects-tinysized-sfx/*water-drop-02*", "fantasy-sound-effects-tinysized-sfx/*water-drop-03*"], {"cap": 0.8}),
    "bird_chirp": ("spot", ["birdcricketfrog-and-mosquito-sounds/bird.*", "birdcricketfrog-and-mosquito-sounds/bird2*"], {"cap": 2.0}),
    "owl": ("spot", ["birdcricketfrog-and-mosquito-sounds/birdNight*"], {"cap": 2.5}),
    "penguin_chatter": ("spot", ["penguin-sounds/penguin_02*"], {"cap": 2.5}),
    "gull": ("spot", ["solo-seagull-sound-effects/*Ambient%202*", "solo-seagull-sound-effects/*Ambient%204*"], {"cap": 2.0}),
    "crow": ("spot", ["crow-caw/*"], {"cap": 1.6}),
    "frog": ("spot", ["frog-croaks/croak_01*", "frog-croaks/croak_03*"], {"cap": 1.2}),
    "cicada": ("spot", ["swamp-environment-audio/cicada_1*", "swamp-environment-audio/cicada_2*"], {"cap": 4.0}),
    "insect": ("spot", ["insect-sounds/insect1*", "insect-sounds/insect3*"], {"cap": 2.5}),
    "wave": ("spot", ["beach-ocean-waves/wave_01*", "beach-ocean-waves/wave_03*"], {"cap": 6.0}),
    # --- ambience beds (loops) ------------------------------------------------
    "rain_light": ("bed", ["amb-rain-loop-1/amb_rain_loop_1.*"], {}),
    "rain_heavy": ("bed", ["amb-rain-loop-2/amb_rain2.*"], {}),
    "birds_day": ("bed", ["park-ambiences/park_ambience_birds*"], {}),
    "birds_dawn": ("bed", ["bird-chirping-sounds/birdchirping071414.*"], {}),
    "crickets": ("bed", ["crickets-ambient-noise-loopable/*"], {}),
    "frogs": ("bed", ["swamp-environment-audio/swamp.*"], {}),
    "wind_soft": ("bed", ["park-ambiences/park_ambience_wind*"], {}),
    "wind_strong": ("bed", ["wind-whoosh-loop/*"], {}),
    "cave": ("bed", ["loopable-dungeon-ambience/*"], {}),
    "hearth": ("bed", ["fireplace-sound-loop/*"], {}),
    "campfire": ("bed", ["fire-crackling/fire-1.*"], {}),
    "water_lap": ("bed", ["park-ambiences/park_ambience_river*"], {}),
    "river": ("bed", ["sea-and-river-wave-sounds/Vistula.*"], {}),
    "waves": ("bed", ["beach-ocean-waves/wave_01*", "beach-ocean-waves/wave_02*", "beach-ocean-waves/wave_03*", "beach-ocean-waves/wave_04*"], {"join": True}),
    "city_hum": ("bed", ["high-traffic-road-sounds/*"], {}),
    "neon_street": ("bed", ["scifi-city-ambient-loop/busy_cyberworld.*"], {}),
    "jungle_insects": ("bed", ["swamp-environment-audio/cicada_1*", "swamp-environment-audio/bug_1*", "swamp-environment-audio/cricket_1*"], {"join": True}),
    "marsh": ("bed", ["swamp-environment-audio/atmosphere_1*"], {}),
    "basement_drips": ("bed", ["dripping-water-loop/*"], {}),
    "boiling": ("bed", ["boiling-water-loops/cooking_with_cover*"], {}),
    "machines": ("bed", ["30-cc0-sfx-loops/machine_03*"], {}),
    "purr_loop": ("bed", ["cat-purr-meow/cat_purrsleepy_loop*"], {}),
}

SOURCES = os.path.join(ROOT, "tools", "cc0_sources.json")


def run(*a):
    return subprocess.run(a, check=True, capture_output=True, text=True)


def dur(p):
    return float(run("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", p).stdout.strip())


def files_for(root, pats):
    allf = []
    for dp, _, fs in os.walk(root):
        if "__MACOSX" in dp:
            continue
        for f in fs:
            if f.lower().endswith((".ogg", ".wav", ".mp3", ".flac")):
                allf.append(os.path.relpath(os.path.join(dp, f), root))
    out = []
    for p in pats:
        # match the pack folder plus anything below it (archives unpack into <pack>/<zip>_x/...)
        pack, rest = p.split("/", 1)
        hits = sorted(f for f in allf if f.split("/")[0] == pack and fnmatch.fnmatch(os.path.basename(f), rest.split("/")[-1]))
        if hits and hits[0] not in out:
            out.append(hits[0])
    return out


def make_sfx(src, dst, cap, mono=True, lufs=None, pre=""):
    d = dur(src)
    tmp = dst + ".tmp.wav"
    trim = (pre + "," if pre else "") + "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse"
    run("ffmpeg", "-hide_banner", "-y", "-i", src, "-af", trim, "-ac", "1" if mono else "2", "-ar", "44100", tmp)
    d = dur(tmp)
    fo = min(0.08, d / 4) if d <= cap else 0.15
    end = min(d, cap)
    af = f"atrim=0:{end},afade=t=in:d=0.004,afade=t=out:st={max(0.0, end - fo)}:d={fo}"
    if lufs is None:
        af += ",alimiter=limit=0.89:level=false,volume=0dB"
        # peak-normalise
        p = subprocess.run(["ffmpeg", "-hide_banner", "-i", tmp, "-af", af + ",volumedetect", "-f", "null", "-"], capture_output=True, text=True).stderr
        mx = 0.0
        for line in p.splitlines():
            if "max_volume" in line:
                mx = float(line.split(":")[1].split("dB")[0])
        af += f",volume={-1.0 - mx:.2f}dB"
    else:
        af += f",loudnorm=I={lufs}:TP=-2:LRA=11"
    # Audio files are hardlinked across worktrees: never write into one in place.
    out = dst + ".new.ogg"
    run("ffmpeg", "-hide_banner", "-y", "-i", tmp, "-af", af, "-c:a", "libvorbis", "-q:a", "4", out)
    os.remove(tmp)
    if os.path.exists(dst):
        os.remove(dst)
    os.rename(out, dst)


def make_bed(srcs, dst, join, xf=2.5, maxlen=48.0):
    t = tempfile.mkdtemp(prefix="bed_")
    parts = []
    for i, s in enumerate(srcs if join else srcs[:1]):
        p = os.path.join(t, f"p{i}.wav")
        run("ffmpeg", "-hide_banner", "-y", "-i", s, "-ac", "2", "-ar", "44100", "-af",
            "silenceremove=start_periods=1:start_threshold=-60dB,areverse,silenceremove=start_periods=1:start_threshold=-60dB,areverse", p)
        parts.append(p)
    cur = parts[0]
    for i, p in enumerate(parts[1:]):
        nxt = os.path.join(t, f"j{i}.wav")
        x = min(xf, dur(cur) / 3, dur(p) / 3)
        run("ffmpeg", "-hide_banner", "-y", "-i", cur, "-i", p, "-filter_complex", f"acrossfade=d={x}:c1=tri:c2=tri", nxt)
        cur = nxt
    d = dur(cur)
    if d > maxlen:
        c2 = os.path.join(t, "cut.wav")
        run("ffmpeg", "-hide_banner", "-y", "-i", cur, "-af", f"atrim=0:{maxlen}", c2)
        cur, d = c2, maxlen
    x = min(xf, d / 4)
    loop = os.path.join(t, "loop.wav")
    flt = (f"[0:a]atrim=0:{x},asetpts=PTS-STARTPTS[h];[0:a]atrim={x}:{d - x},asetpts=PTS-STARTPTS[b];"
           f"[0:a]atrim={d - x}:{d},asetpts=PTS-STARTPTS[tl];[tl][h]acrossfade=d={x}:c1=tri:c2=tri[j];[b][j]concat=n=2:v=0:a=1[o]")
    run("ffmpeg", "-hide_banner", "-y", "-i", cur, "-filter_complex", flt, "-map", "[o]", loop)
    out = dst + ".new.ogg"
    run("ffmpeg", "-hide_banner", "-y", "-i", loop, "-af", "loudnorm=I=-26:TP=-3:LRA=11", "-ar", "32000", "-c:a", "libvorbis", "-q:a", "1", out)
    if os.path.exists(dst):
        os.remove(dst)  # hardlinked: replace, never write through
    os.rename(out, dst)


def add_real(path, names):
    have = set()
    if os.path.exists(path):
        have = {l.strip() for l in open(path) if l.strip() and not l.startswith("#")}
    new = sorted(set(names) - have)
    if not new:
        return
    txt = open(path).read() if os.path.exists(path) else ""
    if txt and not txt.endswith("\n"):
        txt += "\n"
    with open(path + ".new", "w") as f:  # hardlinked: write a new file, then swap it in
        f.write(txt + "".join(n + "\n" for n in new))
    os.replace(path + ".new", path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="/tmp/cc0/dl")
    ap.add_argument("--dry", default="")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    src = json.load(open(SOURCES))
    ace = set()
    acef = os.path.join(ROOT, "audio", "sfx", "ACE.txt")
    if os.path.exists(acef):
        ace = {l.strip() for l in open(acef) if l.strip() and not l.startswith("#")}
    sfx_dir = a.dry or os.path.join(ROOT, "audio", "sfx")
    amb_dir = a.dry or os.path.join(ROOT, "audio", "amb")
    done_sfx, done_amb, used, missing = [], [], {}, []
    for name, (kind, pats, opt) in MAP.items():
        if a.only and name not in a.only.split(","):
            continue
        if kind == "sfx" and name in ace:
            continue
        fs = files_for(a.src, pats)
        fs = [f for f in fs if src.get(f.split("/")[0], {}).get("cc0")]
        if not fs:
            missing.append(name)
            continue
        full = [os.path.join(a.src, f) for f in fs]
        if kind == "bed":
            make_bed(full, os.path.join(amb_dir, f"{name}.ogg"), opt.get("join", False))
            done_amb.append(name)
        else:
            base = name if kind == "sfx" else "spot_" + name
            out_dir = sfx_dir if kind == "sfx" else amb_dir
            for i, f in enumerate(full[:3]):
                nm = base if i == 0 else f"{base}_{i + 1}"
                make_sfx(f, os.path.join(out_dir, nm + ".ogg"), float(opt.get("cap", 1.5)), pre=str(opt.get("af", "")))
                (done_sfx if kind == "sfx" else done_amb).append(nm)
        used[name] = fs
    if not a.dry:
        add_real(os.path.join(ROOT, "audio", "sfx", "REAL.txt"), done_sfx)
        add_real(os.path.join(ROOT, "audio", "amb", "REAL.txt"), done_amb)
        up = os.path.join(ROOT, "audio", "CC0_USED.json")
        allu = json.load(open(up)) if os.path.exists(up) else {}
        allu.update(used)  # --only must not drop the rest
        json.dump(allu, open(up + ".new", "w"), indent=1, sort_keys=True)
        os.replace(up + ".new", up)
    print(f"sfx {len(done_sfx)}  amb {len(done_amb)}  missing: {missing}")


if __name__ == "__main__":
    main()
