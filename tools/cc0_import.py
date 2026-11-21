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
    "step_grass": ("sfx", ["different-steps-on-wood-stone-leaves-gravel-and-mud/*leaves01*", "different-steps-on-wood-stone-leaves-gravel-and-mud/*leaves02*", "50-rpg-sound-effects/*footstep01*"], {"cap": 0.45}),
    "step_dirt": ("sfx", ["fantasy-sound-effects-tinysized-sfx/*soil-steps-01*", "50-rpg-sound-effects/*footstep03*", "50-rpg-sound-effects/*footstep05*"], {"cap": 0.45}),
    "step_sand": ("sfx", ["fantozzis-footsteps-grasssand-stone/*SandL1*", "fantozzis-footsteps-grasssand-stone/*SandR2*", "fantozzis-footsteps-grasssand-stone/*SandL3*"], {"cap": 0.45}),
    "step_stone": ("sfx", ["fantozzis-footsteps-grasssand-stone/*StoneL1*", "fantozzis-footsteps-grasssand-stone/*StoneR2*", "fantozzis-footsteps-grasssand-stone/*StoneL3*"], {"cap": 0.45}),
    "step_wood": ("sfx", ["100-cc0-sfx-2/*footstep_wood_01*", "100-cc0-sfx-2/*footstep_wood_02*", "100-cc0-sfx-2/*footstep_wood_03*"], {"cap": 0.45}),
    "step_snow": ("sfx", ["4-dry-snow-steps/*01*", "4-dry-snow-steps/*02*", "9-wet-snow-steps/*03*"], {"cap": 0.5}),
    "step_water": ("sfx", ["100-cc0-sfx-2/*footstep_wet_01*", "100-cc0-sfx-2/*footstep_wet_02*", "100-cc0-sfx-2/*footstep_wet_03*"], {"cap": 0.5}),
    "step_mud": ("sfx", ["fantasy-sound-effects-tinysized-sfx/*mud-steps-01*", "fantasy-sound-effects-tinysized-sfx/*mud-steps-02*", "fantasy-sound-effects-tinysized-sfx/*mud-steps-03*"], {"cap": 0.5}),
    "step_gravel": ("sfx", ["different-steps-on-wood-stone-leaves-gravel-and-mud/*gravel*", "42-snow-and-gravel-footsteps/*gravel_02*", "42-snow-and-gravel-footsteps/*gravel_05*"], {"cap": 0.5}),
    "step_leaves": ("sfx", ["20-rustles-dry-leaves/*rustle04*", "20-rustles-dry-leaves/*rustle07*", "20-rustles-dry-leaves/*rustle09*"], {"cap": 0.5}),
    # --- combat ------------------------------------------------------------
    "swing": ("sfx", ["bigsoundbank/0128", "swish-bamboo-stick-weapon-swhoshes/*swosh-03*", "swish-bamboo-stick-weapon-swhoshes/*swosh-08*"], {"cap": 0.45, "slice": True, "min": 0.08, "floor": -26}),  # C6: real air swishes with 1-6 kHz body (old swishes were 96% sub-350 Hz)
    "swing_heavy": ("sfx", ["swish-bamboo-stick-weapon-swhoshes/*swosh-05*", "swish-bamboo-stick-weapon-swhoshes/*swosh-12*", "swish-bamboo-stick-weapon-swhoshes/*swosh-20*"], {"cap": 0.7}),
    "hit": ("sfx", ["37-hitspunches/hit01*", "37-hitspunches/hit04*", "37-hitspunches/hit07*"], {"cap": 0.5}),
    "crit": ("sfx", ["150-combat-sound-effects/*Impact_01*", "37-hitspunches/hit24*", "10-impactshield-blocks/impact.1.*"], {"cap": 0.8}),
    "hurt": ("sfx", ["12-wet-towel-hittingfallingpunching-floor-sounds/*"], {"cap": 0.45, "slice": True, "af": "highpass=f=180,equalizer=f=1800:t=o:w=1.5:g=4"}),  # C6: soft bonk, not the strike pack
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
    "timber": ("sfx", ["tree-chop-fall-thud/*", "bigsoundbank/2750"], {"cap": 2.5, "slice": True, "takes": 2, "gap": 0.4, "floor": -28, "min": 0.8}),  # C6: both takes are a real tree fall
    "pick": ("sfx", ["80-cc0-rpg-sfx/stones_01*", "80-cc0-rpg-sfx/stones_02*", "100-cc0-sfx-2/*stones_01*"], {"cap": 0.6}),
    "rock_break": ("sfx", ["breaking-rock/*", "100-cc0-sfx-2/*stones_02*", "100-cc0-sfx-2/*stones_03*"], {"cap": 1.0}),
    "dig": ("sfx", ["shovel-sound/*", "fantasy-sound-effects-tinysized-sfx/*soil-steps-01*"], {"cap": 0.8}),
    "plant": ("sfx", ["20-rustles-dry-leaves/*rustle01*", "20-rustles-dry-leaves/*rustle02*", "20-rustles-dry-leaves/*rustle03*"], {"cap": 0.5}),
    "harvest": ("sfx", ["20-rustles-dry-leaves/*rustle10*", "20-rustles-dry-leaves/*rustle12*", "20-rustles-dry-leaves/*rustle15*"], {"cap": 0.6}),
    "water": ("sfx", ["fantasy-sound-effects-tinysized-sfx/*water-pour-01*", "40-cc0-water-splash-slime-sfx/loop_water_02*"], {"cap": 1.2}),
    "drop": ("sfx", ["fantasy-sound-effects-tinysized-sfx/*water-drop-01*", "fantasy-sound-effects-tinysized-sfx/*water-drop-02*", "fantasy-sound-effects-tinysized-sfx/*water-drop-03*"], {"cap": 0.6}),
    "splash": ("sfx", ["6-short-water-splashes/*01*", "6-short-water-splashes/*03*", "40-cc0-water-splash-slime-sfx/splash_02*"], {"cap": 1.0}),
    "fish_escape": ("sfx", ["40-cc0-water-splash-slime-sfx/splash_10*", "40-cc0-water-splash-slime-sfx/splash_12*"], {"cap": 1.0}),
    "cast": ("sfx", ["swish-bamboo-stick-weapon-swhoshes/*swosh-10*", "swish-bamboo-stick-weapon-swhoshes/*swosh-15*"], {"cap": 0.7}),
    "reel": ("sfx", ["bigsoundbank/1437", "bigsoundbank/1436"], {"cap": 0.7, "slice": True, "chunk": True, "takes": 2}),  # C6: a real fishing reel, softer than the ratchet
    "bubble": ("sfx", ["40-cc0-water-splash-slime-sfx/bubble_01*", "40-cc0-water-splash-slime-sfx/bubble_02*", "40-cc0-water-splash-slime-sfx/bubble_03*"], {"cap": 0.8}),
    "crate_break": ("sfx", ["35-wooden-crackshitsdestructions/crack01*", "35-wooden-crackshitsdestructions/crack04*", "100-cc0-metal-and-wood-sfx/wood_breaking_01*"], {"cap": 1.0}),
    "twig": ("sfx", ["fantasy-sound-effects-tinysized-sfx/*wood-twigs-break-01*", "fantasy-sound-effects-tinysized-sfx/*wood-twigs-break-02*"], {"cap": 0.6}),
    "door": ("sfx", ["door-open-door-close-set/*DoorOpen01*", "door-open-door-close-set/*DoorOpen03*", "door-open-door-close-set/*DoorOpen05*"], {"cap": 1.2}),
    "door_close": ("sfx", ["door-open-door-close-set/*DoorClose01*", "door-open-door-close-set/*DoorClose03*", "door-open-door-close-set/*DoorClose05*"], {"cap": 1.2}),
    "locked": ("sfx", ["door-lock-sounds/LockedDoorHandleJiggle*"], {"cap": 1.0}),
    "unlock": ("sfx", ["door-lock-sounds/UnlockDoor*", "100-cc0-metal-and-wood-sfx/lock_open_01*"], {"cap": 1.0}),
    "chest_open": ("sfx", ["100-cc0-sfx/wooded_box_open*", "open-chest-sfx/*"], {"cap": 1.2}),
    "chest_close": ("sfx", ["bigsoundbank/0053"], {"cap": 0.7, "slice": True, "takes": 2, "min": 0.1}),
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
    "tools": ("sfx", ["68-workshop-sounds/*tool clatter*", "100-cc0-metal-and-wood-sfx/wood_hammer_02*", "100-cc0-metal-and-wood-sfx/tools_05*"], {"cap": 1.2}),
    "drill": ("sfx", ["68-workshop-sounds/*drill short 1*", "68-workshop-sounds/*drill short 2*"], {"cap": 1.2}),
    "pot": ("sfx", ["50-rpg-sound-effects/metalPot1*", "50-rpg-sound-effects/metalPot2*", "50-rpg-sound-effects/metalPot3*"], {"cap": 0.8}),
    "cooking": ("sfx", ["boiling-water-loops/cooking_without_cover*"], {"cap": 2.0}),
    "fireworks": ("sfx", ["25-cc0-bang-firework-sfx/fw_01*", "25-cc0-bang-firework-sfx/fw_03*", "25-cc0-bang-firework-sfx/fw_05*"], {"cap": 2.5}),
    "pop": ("sfx", ["3-pop-sounds/pop1*", "3-pop-sounds/pop2*", "3-pop-sounds/pop3*"], {"cap": 0.5}),
    "stink": ("sfx", ["40-cc0-water-splash-slime-sfx/slime_04*", "40-cc0-water-splash-slime-sfx/slime_09*"], {"cap": 1.0}),  # C6: squelch with mid body, not filtered hiss
    "cave_in": ("sfx", ["cave-in/*"], {"cap": 3.0}),
    "typing": ("sfx", ["keyboard-soundpack-1-typing-and-single-keystrokes/*human_vel-001*", "keyboard-soundpack-1-typing-and-single-keystrokes/*human_vel-004*"], {"cap": 1.2}),
    "keypress": ("sfx", ["keyboard-soundpack-1-typing-and-single-keystrokes/*keypress-001*", "keyboard-soundpack-1-typing-and-single-keystrokes/*keypress-005*", "keyboard-soundpack-1-typing-and-single-keystrokes/*keypress-009*"], {"cap": 0.3}),
    "terminal": ("sfx", ["50-cc0-sci-fi-sfx/terminal_01*", "50-cc0-sci-fi-sfx/terminal_02*", "50-cc0-sci-fi-sfx/terminal_03*"], {"cap": 1.0}),
    "beep": ("sfx", ["50-cc0-sci-fi-sfx/beep_01*", "50-cc0-sci-fi-sfx/beep_02*", "50-cc0-sci-fi-sfx/beep_03*"], {"cap": 0.6}),
    "servo": ("sfx", ["60-cc0-sci-fi-sfx/sfx_05a*", "60-cc0-sci-fi-sfx/sfx_05b*"], {"cap": 0.6}),  # C6: two motor takes (the old 12 kHz whine take is gone)
    "power_off": ("sfx", ["machine-shutting-down/*"], {"cap": 2.0}),
    "power_up": ("sfx", ["50-cc0-retro-synth-sfx/power_up_01*", "50-cc0-retro-synth-sfx/power_up_03*"], {"cap": 1.2}),
    "car_door": ("sfx", ["cardoorsfx/door_closing*", "cardoorsfx/door_opening*"], {"cap": 1.2}),
    "car_start": ("sfx", ["car-engine-start-01/generic_car_startengine.*"], {"cap": 2.5}),
    "siren": ("sfx", ["sirens-and-alarm-noise/*"], {"cap": 3.0}),
    "alarm": ("sfx", ["alarm-2/*", "30-cc0-sfx-loops/alarm_01*"], {"cap": 2.0}),
    "horn": ("sfx", ["bicycle-horn/*"], {"cap": 1.0}),  # comic honk only: battle entrances use war_horn, cars car_horn
    "war_horn": ("sfx", ["their-coming-generic-horn-sound/*theircoming_0*", "their-coming-generic-horn-sound/*theircoming3*"], {"cap": 2.4}),
    "war_horn_gang": ("sfx", ["bigsoundbank/2721"], {"cap": 1.4, "slice": True, "takes": 1, "min": 0.3}),
    "car_horn": ("sfx", ["bigsoundbank/0558", "bigsoundbank/2721"], {"cap": 0.9, "slice": True, "min": 0.15}),
    "war_drum": ("sfx", ["horde-war-drums-loop/*"], {"cap": 2.2}),
    "beat_tick": ("sfx", ["bigsoundbank/0007"], {"cap": 0.2, "slice": True, "takes": 2, "min": 0.01, "af": "highpass=f=300"}),
    "dice_roll": ("sfx", ["bigsoundbank/0581", "bigsoundbank/0582"], {"cap": 1.1, "slice": True, "gap": 0.25, "min": 0.3}),
    "shot_smg": ("sfx", ["bigsoundbank/0437", "bigsoundbank/0482"], {"cap": 0.28, "slice": True, "min": 0.03, "af": "highpass=f=90"}),
    "knockout": ("sfx", ["bigsoundbank/0551"], {"cap": 0.5, "slice": True, "min": 0.03, "layer": ["12-wet-towel-hittingfallingpunching-floor-sounds/*", 0.11, -3.0]}),  # C13 (c13_07-11): the hit plus a body fall under it
    "boss_down": ("sfx", ["muffled-distant-explosion/*", "cave-in/*"], {"cap": 0.9}),
    "whistle": ("sfx", ["bigsoundbank/1170"], {"cap": 1.0, "slice": True, "takes": 2, "min": 0.2}),
    "town_bell": ("sfx", ["bigsoundbank/0830"], {"cap": 5.5, "slice": True, "takes": 1, "gap": 1.5, "min": 1.0, "floor": -40}),
    "town_bell_far": ("sfx", ["bigsoundbank/0830"], {"cap": 5.5, "slice": True, "takes": 1, "gap": 1.5, "min": 1.0, "floor": -40, "post": "lowpass=f=1600,aecho=0.8:0.7:180|420:0.35|0.22,volume=-6dB"}),
    "fairy_ring": ("sfx", ["bigsoundbank/0040"], {"cap": 2.4, "slice": True, "takes": 1, "gap": 0.5, "min": 0.8, "af": "asetrate=29400,aresample=44100,highpass=f=400"}),
    "sparkle": ("sfx", ["bigsoundbank/0040"], {"cap": 0.6, "slice": True, "gap": 0.03, "min": 0.08, "af": "asetrate=14700,aresample=44100,highpass=f=500"}),  # ~1.6 octaves down: shimmer centred 2-5 kHz  # C6: real chimes (the ACE bell cuts had no shimmer)
    "heartbeat": ("sfx", ["bigsoundbank/0218"], {"cap": 0.9, "slice": True, "takes": 1, "gap": 0.25, "min": 0.2, "post": "highpass=f=60,equalizer=f=1500:t=o:w=1.5:g=8"}),  # C6: audible on a phone
    "saw": ("sfx", ["bigsoundbank/0559", "bigsoundbank/0016"], {"cap": 1.6, "slice": True, "gap": 0.2, "min": 0.3}),
    "scythe": ("sfx", ["bigsoundbank/0127"], {"cap": 0.4, "slice": True, "min": 0.06}),
    "harvest_pluck": ("sfx", ["bigsoundbank/1074"], {"cap": 0.3, "slice": True, "min": 0.02}),
    "swim": ("sfx", ["bigsoundbank/1514"], {"cap": 0.8, "slice": True, "gap": 0.15, "min": 0.2}),
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
    # C6 P5 cue names (calls made before the files existed)
    "horse_whinny": ("sfx", ["bigsoundbank/0460"], {"cap": 2.0, "slice": True, "takes": 1, "gap": 0.3, "min": 0.4}),
    "step_hoof": ("sfx", ["bigsoundbank/1854"], {"cap": 0.22, "slice": True, "min": 0.03, "gap": 0.03}),
    "step_swim": ("sfx", ["bigsoundbank/1514"], {"cap": 0.6, "slice": True, "gap": 0.15, "min": 0.2, "af": "volume=-4dB"}),
    "step_wheels": ("sfx", ["bigsoundbank/1634"], {"cap": 0.8, "slice": True, "chunk": True, "takes": 2, "af": "lowpass=f=5000"}),
    "beast_down": ("sfx", ["80-cc0-creture-sfx-2/die_01*", "80-cc0-creture-sfx-2/die_02*", "80-cc0-creture-sfx-2/die_03*"], {"cap": 1.0}),
    "boss_fall": ("sfx", ["bigsoundbank/1022", "cave-in/*"], {"cap": 1.6, "slice": True, "takes": 2, "gap": 0.3, "min": 0.4}),
    "status_tick": ("sfx", ["bigsoundbank/0007"], {"cap": 0.15, "slice": True, "takes": 2, "min": 0.01, "af": "highpass=f=600,volume=-6dB"}),
    "stone_grind": ("sfx", ["bigsoundbank/0580"], {"cap": 2.0, "slice": True, "takes": 1, "gap": 0.4, "min": 0.6, "af": "lowpass=f=4000"}),
    "plant_pat": ("sfx", ["fantasy-sound-effects-tinysized-sfx/*soil-steps-01*", "shovel-sound/*"], {"cap": 0.3, "slice": True, "min": 0.04}),
    "yawn": ("sfx", ["80-cc0-creature-sfx/breath*", "80-cc0-creture-sfx-2/breath_02*"], {"cap": 1.4}),
    "bow": ("sfx", ["bigsoundbank/0549", "bigsoundbank/0548"], {"cap": 0.5, "slice": True, "gap": 0.1, "min": 0.05}),
    "whinny": ("sfx", ["bigsoundbank/0460"], {"cap": 2.0, "slice": True, "takes": 1, "gap": 0.3, "min": 0.4}),
    "hoof": ("sfx", ["bigsoundbank/1854"], {"cap": 0.22, "slice": True, "min": 0.03, "gap": 0.03}),
    "rooster": ("sfx", ["bigsoundbank/0283", "bigsoundbank/0104"], {"cap": 2.6, "slice": True, "takes": 2, "gap": 0.35, "min": 0.6}),
    "moo": ("sfx", ["bigsoundbank/0845"], {"cap": 1.8, "slice": True, "gap": 0.3, "min": 0.4}),
    "cluck": ("sfx", ["bigsoundbank/0978", "bigsoundbank/1039", "bigsoundbank/0453"], {"cap": 0.9, "slice": True, "gap": 0.12, "min": 0.1}),
    "peep": ("sfx", ["bigsoundbank/0430", "bigsoundbank/0431", "bigsoundbank/0672"], {"cap": 0.5, "slice": True, "gap": 0.05, "min": 0.05}),
    "quack": ("sfx", ["bigsoundbank/0276"], {"cap": 0.8, "slice": True, "gap": 0.1, "min": 0.1}),
    # C11a P5 ranch voices (all BigSoundBank CC0): pig (mouth imitation, cartoon-friendly), bees, rabbits stamping.
    "oink": ("sfx", ["bigsoundbank/1658", "bigsoundbank/1659"], {"cap": 1.0, "slice": True, "gap": 0.2, "min": 0.15}),
    "buzz": ("sfx", ["bigsoundbank/1000", "bigsoundbank/1001"], {"cap": 1.4, "slice": True, "gap": 0.3, "min": 0.4}),
    "thump": ("sfx", ["bigsoundbank/1376"], {"cap": 0.35, "slice": True, "gap": 0.08, "min": 0.03}),
    "bleat": ("sfx", ["bigsoundbank/0880", "bigsoundbank/1377"], {"cap": 1.4, "slice": True, "gap": 0.2, "min": 0.3}),
    # --- mega travel (C4 P4): derived mixes of the CC0 bell dings + the air whoosh ---
    "airship_whoosh": ("sfx", ["air-whoosh/whoosh2_0.*"], {"cap": 2.6}),
    "sled_bells": ("sfx", ["bell-dingschimes/sled_jingle.*"], {"cap": 2.2}),
    "train_depart": ("sfx", ["bell-dingschimes/station_depart.*"], {"cap": 3.2}),
    "snore": ("sfx", ["80-cc0-creature-sfx/snore*", "80-cc0-creture-sfx-2/snore_02*"], {"cap": 2.0}),
    # --- ambience spots (Ambience plays these off to the side) ---------------
    "thunder": ("spot", ["100-cc0-sfx-2/*thunder_01*"], {"cap": 5.0}),
    "drip": ("spot", ["fantasy-sound-effects-tinysized-sfx/*water-drop-02*", "fantasy-sound-effects-tinysized-sfx/*water-drop-03*"], {"cap": 0.8}),
    "bird_chirp": ("spot", ["birdcricketfrog-and-mosquito-sounds/bird.*", "birdcricketfrog-and-mosquito-sounds/bird2*"], {"cap": 2.0}),
    "owl": ("spot", ["birdcricketfrog-and-mosquito-sounds/birdNight*"], {"cap": 2.5}),
    "penguin_chatter": ("spot", ["penguin-sounds/penguin_02*"], {"cap": 2.5}),
    "gull": ("spot", ["solo-seagull-sound-effects/*Ambient%202*", "solo-seagull-sound-effects/*Ambient%204*"], {"cap": 2.0}),
    "crow@spot": ("spot", ["crow-caw/*"], {"cap": 1.6}),
    "frog@spot": ("spot", ["frog-croaks/croak_01*", "frog-croaks/croak_03*"], {"cap": 1.2}),
    "rooster@spot": ("spot", ["bigsoundbank/0283", "bigsoundbank/0104"], {"cap": 2.6, "slice": True, "takes": 2, "gap": 0.35, "min": 0.6}),
    "hens": ("spot", ["bigsoundbank/0282", "bigsoundbank/0978"], {"cap": 3.5, "slice": True, "takes": 2, "gap": 0.6, "min": 1.0, "floor": -34}),
    "cow": ("spot", ["bigsoundbank/3221"], {"cap": 3.0, "slice": True, "takes": 2, "gap": 0.5, "min": 0.8}),
    "town_bell@spot": ("spot", ["bigsoundbank/0830"], {"cap": 6.0, "slice": True, "takes": 1, "gap": 1.5, "min": 1.0, "floor": -40, "post": "lowpass=f=2400"}),
    "cicada": ("spot", ["swamp-environment-audio/cicada_1*", "swamp-environment-audio/cicada_2*"], {"cap": 4.0}),
    "insect": ("spot", ["insect-sounds/insect1*", "insect-sounds/insect3*"], {"cap": 2.5}),
    "wave": ("spot", ["beach-ocean-waves/wave_01*", "beach-ocean-waves/wave_03*"], {"cap": 6.0}),
    # --- C11b P6: creature voices (cv_<group>, never a name an effect already uses: c11b_14-01) --------
    # All ages: soft hoots, chirrs, burbles and snorts; never roar/growl/monster/scream files.
    "cv_ostrich": ("sfx", ["80-cc0-creture-sfx-2/misc_10*", "80-cc0-creture-sfx-2/misc_11*", "80-cc0-creture-sfx-2/misc_12*"], {"cap": 0.9, "af": "asetrate=44100*0.7,aresample=44100,lowpass=f=3000"}),
    "cv_emu": ("sfx", ["80-cc0-creture-sfx-2/misc_11*", "80-cc0-creture-sfx-2/misc_10*"], {"cap": 0.8, "af": "asetrate=44100*0.85,aresample=44100,lowpass=f=3200"}),
    "cv_komodo": ("sfx", ["80-cc0-creature-sfx/nose.*", "80-cc0-creature-sfx/breath.*"], {"cap": 0.8, "af": "highpass=f=200"}),
    "cv_moon": ("sfx", ["80-cc0-creature-sfx/alien_02*", "80-cc0-creature-sfx/alien_03*", "80-cc0-creture-sfx-2/alien_08*"], {"cap": 0.9}),
    "cv_merkitty": ("sfx", ["80-cc0-creature-sfx/cute_02*", "80-cc0-creature-sfx/cute_06*", "80-cc0-creature-sfx/burble_01*"], {"cap": 0.8}),
    "cv_gloam": ("sfx", ["insect-sounds/insect0*", "insect-sounds/insect4*"], {"cap": 1.0, "af": "highpass=f=400"}),
    "cv_frost": ("sfx", ["80-cc0-creature-sfx/ooh.*", "80-cc0-creture-sfx-2/weird_07*"], {"cap": 0.9, "af": "asetrate=44100*0.9,aresample=44100"}),
    "cv_sky": ("sfx", ["bird-chirping-sounds/birdchirping071414.wav"], {"cap": 0.7, "slice": True, "takes": 2, "min": 0.12, "floor": -28}),
    # --- C11b P6: ranch machine cues (c11b_14-09) ---------------------------------------------------
    "egg_crack": ("sfx", ["7-eating-crunches/crunch.2.*", "7-eating-crunches/crunch.4.*", "7-eating-crunches/crunch.5.*"], {"cap": 0.25, "af": "asetrate=44100*1.3,aresample=44100,highpass=f=300"}),
    "feeder_fill": ("sfx", ["68-workshop-sounds/*rummaging through nails*", "68-workshop-sounds/*tool rummaging*"], {"cap": 1.0, "af": "lowpass=f=2400"}),
    # --- ambience beds (loops) ------------------------------------------------
    "rain_light": ("bed", ["amb-rain-loop-1/amb_rain_loop_1.*"], {}),
    "rain_heavy": ("bed", ["amb-rain-loop-2/amb_rain2.*"], {}),
    "birds_day": ("bed", ["park-ambiences/park_ambience_birds*"], {}),
    "birds_dawn": ("bed", ["bigsoundbank/0100"], {}),  # C6: 48 s forest dawn chorus (was a 1.3 s loop)
    "crickets": ("bed", ["crickets-ambient-noise-loopable/*", "bigsoundbank/1020"], {"join": True}),
    "frogs": ("bed", ["swamp-environment-audio/swamp.*"], {}),
    "wind_soft": ("bed", ["park-ambiences/park_ambience_wind*"], {}),
    "wind_strong": ("bed", ["bigsoundbank/0625"], {}),
    "cave": ("bed", ["loopable-dungeon-ambience/*"], {}),
    "hearth": ("bed", ["fireplace-sound-loop/*"], {}),
    "campfire": ("bed", ["bigsoundbank/3322", "fire-crackling/fire-1.*"], {"join": True}),
    "water_lap": ("bed", ["park-ambiences/park_ambience_river*"], {}),
    "river": ("bed", ["sea-and-river-wave-sounds/Vistula.*"], {}),
    "waves": ("bed", ["bigsoundbank/0266"], {}),
    "city_hum": ("bed", ["high-traffic-road-sounds/*"], {}),
    "neon_street": ("bed", ["scifi-city-ambient-loop/busy_cyberworld.*"], {}),
    "jungle_insects": ("bed", ["swamp-environment-audio/cicada_1*", "swamp-environment-audio/bug_1*", "swamp-environment-audio/cricket_1*"], {"join": True}),
    "marsh": ("bed", ["bigsoundbank/0691"], {}),
    "basement_drips": ("bed", ["dripping-water-loop/*"], {}),
    "boiling": ("bed", ["bigsoundbank/0149", "bigsoundbank/0492"], {"join": True}),
    "aviary_room": ("bed", ["bird-chirping-sounds/birdchirping071414.wav"], {"af": "volume=-6dB"}),  # C11b P6 (c11b_14-04)
    "terrarium_room": ("bed", ["30-cc0-sfx-loops/ambient_02*", "30-cc0-sfx-loops/noise_01*"], {"join": True, "af": "lowpass=f=1800"}),
    "machines": ("bed", ["bigsoundbank/0502", "30-cc0-sfx-loops/machine_03*"], {}),
    "purr_loop": ("bed", ["bigsoundbank/0436", "cat-purr-meow/cat_purrsleepy_loop*"], {"join": True}),
    # C6: real recordings for the last synth placeholders, plus room tones
    "town_day": ("bed", ["bigsoundbank/3542"], {"af": "lowpass=f=5000"}),
    "crowd": ("bed", ["bigsoundbank/0825"], {}),
    "rain_roof": ("bed", ["bigsoundbank/1293", "bigsoundbank/1294"], {"join": True, "af": "lowpass=f=3200"}),
    "leaves": ("bed", ["bigsoundbank/0904"], {}),
    "lava": ("bed", ["bigsoundbank/0491", "bigsoundbank/0149"], {"join": True, "af": "asetrate=30870,aresample=44100,lowpass=f=4000"}),
    "room_shop": ("bed", ["bigsoundbank/2561"], {"af": "lowpass=f=6000"}),
    "room_chapel": ("bed", ["bigsoundbank/0506"], {"af": "lowpass=f=3000,volume=-4dB"}),
    # --- gangster arc money (Round 13): bills, not crystal chimes ------------
    "cash_pickup": ("sfx", ["202-more-sound-effects/Money_20*", "202-more-sound-effects/Money_22*", "202-more-sound-effects/Money_24*"], {"cap": 0.6}),
    "cash_register": ("sfx", ["purchasing-sound-effect/*", "202-more-sound-effects/Money_36*", "202-more-sound-effects/Money_18*"], {"cap": 1.3}),
    # --- C13 P5: casino, arcade, decks, vehicles, ranch, story (contract section 3) ------------
    "card_deal": ("sfx", ["54-casino-sound-effects-cards-dice-chips/card-slide-1*", "54-casino-sound-effects-cards-dice-chips/card-slide-3*", "54-casino-sound-effects-cards-dice-chips/card-slide-5*"], {"cap": 0.5, "slice": True, "min": 0.05, "floor": -40}),
    "card_flip": ("sfx", ["54-casino-sound-effects-cards-dice-chips/card-place-1*", "54-casino-sound-effects-cards-dice-chips/card-place-2*", "54-casino-sound-effects-cards-dice-chips/card-place-3*"], {"cap": 0.4, "slice": True, "min": 0.05, "floor": -40}),
    "chip_clack": ("sfx", ["54-casino-sound-effects-cards-dice-chips/chip-lay-1*", "54-casino-sound-effects-cards-dice-chips/chip-lay-2*", "54-casino-sound-effects-cards-dice-chips/chip-lay-3*"], {"cap": 0.5, "slice": True, "min": 0.05, "floor": -40}),
    "chips_stack": ("sfx", ["54-casino-sound-effects-cards-dice-chips/chips-stack-1*", "54-casino-sound-effects-cards-dice-chips/chips-stack-3*", "54-casino-sound-effects-cards-dice-chips/chips-handle-2*"], {"cap": 0.8, "slice": True, "min": 0.1, "gap": 0.2, "floor": -40}),
    "roulette_spin": ("sfx", ["bigsoundbank/0858"], {"cap": 1.4, "slice": True, "chunk": True, "takes": 2, "af": "lowpass=f=3500"}),
    "roulette_ball": ("sfx", ["bigsoundbank/2242", "bigsoundbank/2243"], {"cap": 0.25, "slice": True, "min": 0.02, "af": "highpass=f=500"}),
    "slot_spin": ("sfx", ["bigsoundbank/0317"], {"cap": 1.2, "slice": True, "chunk": True, "takes": 2, "af": "highpass=f=400,lowpass=f=4000"}),
    "slot_stop": ("sfx", ["bigsoundbank/0794"], {"cap": 0.15, "slice": True, "min": 0.02}),
    "target_tin": ("sfx", ["bigsoundbank/0246", "bigsoundbank/0247", "bigsoundbank/0248"], {"cap": 0.4, "slice": True, "min": 0.03, "af": "highpass=f=300"}),
    "claw_move": ("sfx", ["bigsoundbank/1606"], {"cap": 0.6, "slice": True, "chunk": True, "takes": 2, "af": "lowpass=f=4500"}),
    "claw_drop": ("sfx", ["bigsoundbank/0543"], {"cap": 0.45, "slice": True, "min": 0.03, "af": "asetrate=44100*1.4,aresample=44100,highpass=f=300,volume=-3dB"}),
    "skee_roll": ("sfx", ["bowling-ball-rolling/*"], {"cap": 1.2, "af": "asetrate=61740,aresample=44100,highpass=f=150"}),
    "ticket_out": ("sfx", ["bigsoundbank/3264", "bigsoundbank/3286", "bigsoundbank/3287"], {"cap": 0.35, "slice": True, "chunk": True, "af": "highpass=f=250"}),
    "cabinet_coin": ("sfx", ["bigsoundbank/0339", "bigsoundbank/0340"], {"cap": 0.45, "slice": True, "min": 0.03, "af": "highpass=f=400"}),
    "step_carpet": ("sfx", ["bigsoundbank/0373"], {"cap": 0.35, "slice": True, "min": 0.05, "af": "lowpass=f=2500"}),
    "step_metal": ("sfx", ["100-cc0-sfx-2/*footstep_01*", "100-cc0-sfx-2/*footstep_02*"], {"cap": 0.45, "slice": True, "min": 0.06, "post": "highpass=f=250,aecho=0.8:0.5:7|13:0.45|0.3,equalizer=f=3200:t=o:w=1:g=5"}),
    "step_ice": ("sfx", ["4-dry-snow-steps/*03*", "4-dry-snow-steps/*04*", "4-dry-snow-steps/*01*"], {"cap": 0.4, "slice": True, "min": 0.08, "floor": -40, "af": "asetrate=44100*1.15,aresample=44100,highpass=f=900"}),
    "scooter_ride": ("sfx", ["bigsoundbank/0533"], {"cap": 1.2, "slice": True, "chunk": True, "takes": 2, "af": "highpass=f=150"}),
    "motor_loop": ("sfx", ["bigsoundbank/0281"], {"cap": 1.5, "slice": True, "chunk": True, "takes": 2, "af": "highpass=f=120"}),
    "sled_snow": ("sfx", ["bigsoundbank/0208"], {"cap": 0.8, "slice": True, "chunk": True, "takes": 3, "af": "lowpass=f=5000"}),
    "milk": ("sfx", ["bigsoundbank/0324", "bigsoundbank/0325", "bigsoundbank/0326"], {"cap": 0.35, "slice": True, "min": 0.04, "af": "lowpass=f=4000"}),
    "shear": ("sfx", ["bigsoundbank/0008"], {"cap": 0.35, "slice": True, "min": 0.04}),
    "egg_collect": ("sfx", ["35-wooden-crackshitsdestructions/impactwood02*", "35-wooden-crackshitsdestructions/impactwood04*", "35-wooden-crackshitsdestructions/impactwood06*"], {"cap": 0.2, "af": "asetrate=44100*1.6,aresample=44100,lowpass=f=5000,volume=-4dB"}),
    "howl_far": ("sfx", ["bigsoundbank/2450", "bigsoundbank/2451"], {"cap": 3.0, "slice": True, "takes": 1, "min": 0.6, "gap": 0.3, "af": "asetrate=33075,aresample=44100", "post": "lowpass=f=1400,aecho=0.8:0.6:240|520:0.4|0.25,volume=-4dB"}),
    "cv_crystal_baby": ("sfx", ["80-cc0-creature-sfx/cute_03*", "80-cc0-creature-sfx/cute_05*", "80-cc0-creature-sfx/cute_08*"], {"cap": 0.7, "af": "asetrate=44100*1.35,aresample=44100,highpass=f=500,aecho=0.6:0.4:60:0.3"}),
    "pet_howl": ("sfx", ["bigsoundbank/2450", "bigsoundbank/2451"], {"cap": 1.6, "slice": True, "takes": 2, "min": 0.4, "gap": 0.3}),
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
        if pack == "bigsoundbank":
            f = "bigsoundbank/" + rest[:4] + ".ogg"
            if f in allf and f not in out:
                out.append(f)
            continue
        hits = sorted(f for f in allf if f.split("/")[0] == pack and fnmatch.fnmatch(os.path.basename(f), rest.split("/")[-1]))
        if hits and hits[0] not in out:
            out.append(hits[0])
    return out


def make_sfx(src, dst, cap, mono=True, lufs=None, af_pre=""):
    d = dur(src)
    tmp = dst + ".tmp.wav"
    trim = (af_pre + "," if af_pre else "") + "silenceremove=start_periods=1:start_threshold=-50dB,areverse,silenceremove=start_periods=1:start_threshold=-50dB,areverse"
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
    out = dst + ".new.ogg"
    run("ffmpeg", "-hide_banner", "-y", "-i", tmp, "-af", af, "-c:a", "libvorbis", "-q:a", "4", out)
    os.remove(tmp)
    if os.path.exists(dst):
        os.remove(dst)  # hardlinked across worktrees: never write through
    os.rename(out, dst)


SR = 44100
BED_LUFS = -26.0      # every bed lands here (K-weighted, so sub-bass counts for little)
BED_MIN = 24.0        # beds shorter than this are rebuilt from shuffled slices
BED_MAX = 48.0
# phone speakers roll off under ~200 Hz: cut the rumble, lift presence a little
BED_SHAPE = "highpass=f=120:p=2,equalizer=f=2500:t=o:w=2:g=2.5"


def load(path, af="", ch=1, sr=SR):
    import numpy as np
    cmd = ["ffmpeg", "-v", "quiet", "-i", path]
    if af:
        cmd += ["-af", af]
    cmd += ["-ac", str(ch), "-ar", str(sr), "-f", "f32le", "-"]
    x = np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, np.float32).copy()
    return x.reshape(-1, ch) if ch > 1 else x


def save(x, dst, ch=1, sr=SR, q=4, af=""):
    """numpy float32 -> ogg through a temp file; removes dst first (hardlinks)."""
    import numpy as np
    tmp = dst + ".tmp.ogg"
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ac", str(ch), "-ar", str(sr), "-i", "-"]
    if af:
        cmd += ["-af", af]
    cmd += ["-c:a", "libvorbis", "-q:a", str(q), tmp]
    subprocess.run(cmd, input=np.ascontiguousarray(x, np.float32).tobytes(), check=True, capture_output=True)
    if os.path.exists(dst):
        os.remove(dst)
    os.rename(tmp, dst)


def lufs(path):
    """Integrated loudness (ffmpeg ebur128)."""
    e = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
    val = -70.0
    for line in e.splitlines():
        line = line.strip()
        if line.startswith("I:") and "LUFS" in line:
            val = float(line.split()[1])
    return val


def events(x, sr=SR, floor_db=-30.0, gap=0.08, min_len=0.05, pre=0.004):
    """Onsets in a mono take: [(start, end, peak)] of stretches louder than floor_db under the file's peak."""
    import numpy as np
    w = max(1, int(sr * 0.01))
    env = np.sqrt(np.convolve(x.astype(np.float64) ** 2, np.ones(w) / w, "same"))
    pk = env.max() + 1e-12
    on = env > pk * 10 ** (floor_db / 20)
    out, i, n = [], 0, len(x)
    while i < n:
        if not on[i]:
            i += 1
            continue
        j = i
        while j < n:
            k = j
            while k < n and on[k]:
                k += 1
            nxt = k
            while nxt < n and not on[nxt] and nxt - k < gap * sr:
                nxt += 1
            j = k
            if nxt >= n or not on[nxt]:
                break
            j = nxt
        if (j - i) / sr >= min_len:
            out.append((max(0, i - int(pre * sr)), min(n, j + int(0.03 * sr)), float(env[i:j].max())))
        i = j + 1
    return out


def fade(x, fin=0.004, fout=0.08, sr=SR):
    import numpy as np
    x = x.copy()
    a, b = min(len(x) // 4, int(fin * sr)), min(len(x) // 3, int(fout * sr))
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)[:, None] if x.ndim > 1 else np.linspace(1, 0, b)
    return x


def peak_norm(x, db=-1.0):
    import numpy as np
    m = float(np.max(np.abs(x))) + 1e-9
    return (x * (10 ** (db / 20) / m)).astype(np.float32)


def sliced_takes(full, opt, n=3):
    """Cut up to n separate takes (single calls/hits) out of longer recordings.
    Picks the loudest events, round-robin over the source files so takes differ."""
    import numpy as np
    cap = float(opt.get("cap", 1.5))
    lo = float(opt.get("min", 0.08))
    per = []
    for f in full:
        x = load(f, opt.get("af", ""))
        if "seg" in opt:
            x = x[int(opt["seg"][0] * SR):int(opt["seg"][1] * SR)]
        if opt.get("chunk"):
            # continuous sounds (a reel, a motor): the loudest cap-long windows, not onsets
            w = int(cap * SR)
            ev = [(i, i + w, float(np.sqrt(np.mean(x[i:i + w] ** 2)))) for i in range(0, max(1, len(x) - w), w)]
        else:
            ev = [e for e in events(x, floor_db=float(opt.get("floor", -30.0)), gap=float(opt.get("gap", 0.08)), min_len=min(lo, 0.02))
                  if (e[1] - e[0]) / SR >= lo]
        ev.sort(key=lambda e: -e[2])
        top = ev[0][2] if ev else 0
        ev = [e for e in ev if e[2] > top * 0.3]  # skip the faint background ones
        per.append([(x, e) for e in ev])
    takes, k = [], 0
    while len(takes) < n and any(per):
        lst = per[k % len(per)]
        if lst:
            x, (s0, s1, _) = lst.pop(0)
            seg = x[s0:min(s1, s0 + int(cap * SR))]
            takes.append(peak_norm(fade(seg, fout=min(0.08, len(seg) / SR / 3) if s1 - s0 <= cap * SR else 0.12)))
        k += 1
    return takes


def layered(x, root, layer, i=0):
    """C13: mix a second CC0 sound under a take (opt layer = [pattern, delay s, dB]), e.g. a body fall
    under a knockout hit. Take i uses the i-th loudest event of the layer file."""
    import numpy as np
    fs = files_for(root, [layer[0]])
    if not fs:
        return x
    y = load(os.path.join(root, fs[0]))
    ev = sorted(events(y, floor_db=-30.0, gap=0.15, min_len=0.05), key=lambda e: -e[2])
    if ev:
        s0, s1, _ = ev[i % len(ev)]
        y = y[s0:min(s1, s0 + int(0.6 * SR))]
    y = fade(y, fout=min(0.12, len(y) / SR / 3)) * (10 ** (float(layer[2]) / 20)) * (float(np.max(np.abs(x))) / (float(np.max(np.abs(y))) + 1e-9))
    d = int(float(layer[1]) * SR)
    out = np.zeros(max(len(x), d + len(y)), dtype=np.float32)
    out[:len(x)] += x
    out[d:d + len(y)] += y
    return peak_norm(out)


def seamless(x, xf):
    """Equal-power tail-into-head loop: the result's end flows straight into its start."""
    import numpy as np
    n, k = len(x), int(xf * SR)
    k = min(k, n // 4)
    t = np.linspace(0, np.pi / 2, k)
    fi, fo = np.sin(t), np.cos(t)
    if x.ndim > 1:
        fi, fo = fi[:, None], fo[:, None]
    y = x[k:].copy()
    y[-k:] = x[n - k:] * fo + x[:k] * fi
    return y


def make_bed(srcs, dst, join, xf=1.5, af="", maxlen=BED_MAX, minlen=BED_MIN, seed=7):
    """Seamless loop of at least `minlen` s: join every source (or slice and shuffle a short one),
    shape for phone speakers, level to BED_LUFS."""
    import numpy as np
    rng = np.random.default_rng(seed)
    parts = []
    for s in (srcs if join else srcs[:1]):
        x = load(s, ",".join(f for f in (af, BED_SHAPE) if f), ch=2)
        e = np.abs(x).max(axis=1)
        nz = np.nonzero(e > e.max() * 0.003)[0]
        if len(nz):
            x = x[nz[0]:nz[-1] + 1]
        parts.append(x)
    total = sum(len(p) for p in parts) / SR

    def xjoin(a, b, d=0.5):
        k = min(int(d * SR), len(a) // 3, len(b) // 3)
        t = np.linspace(0, np.pi / 2, k)[:, None]
        return np.concatenate([a[:-k], a[-k:] * np.cos(t) + b[:k] * np.sin(t), b[k:]])

    if total >= minlen:
        cur = parts[0]
        for p in parts[1:]:
            cur = xjoin(cur, p, 1.5)
        if len(cur) > maxlen * SR:
            off = int(min(len(cur) - maxlen * SR, len(cur) * 0.1))
            cur = cur[off:off + int(maxlen * SR)]
    else:
        # short pack: shuffled 4-8 s slices (each from a random spot) crossfaded into a 30 s bed
        cur = None
        while cur is None or len(cur) < 30 * SR:
            p = parts[int(rng.integers(len(parts)))]
            L = min(len(p), int(rng.uniform(4, 8) * SR))
            o = int(rng.integers(0, max(1, len(p) - L)))
            seg = p[o:o + L]
            cur = seg if cur is None else xjoin(cur, seg, min(0.6, len(seg) / SR / 4))
    y = seamless(cur, min(xf, len(cur) / SR / 6))
    y = peak_norm(y, -3.0)
    tmp = dst + ".lv.ogg"
    save(y, tmp, ch=2, q=2)
    g = BED_LUFS - lufs(tmp)
    os.remove(tmp)
    y = y * 10 ** (g / 20)
    m = float(np.max(np.abs(y)))
    if m > 0.7:  # true-peak headroom: soft-limit the rare spike instead of dropping the bed
        y = np.tanh(y / 0.7) * 0.7
    save(y.astype(np.float32), dst, ch=2, sr=SR, q=1, af="aresample=32000")
    secs = round(len(y) / SR, 1)
    bed_log(os.path.basename(dst)[:-4], dst, secs)
    return secs


BED_LOG = os.path.join(ROOT, "audio", "amb", "BED_LOG.json")


def bed_log(name, path, secs):
    import hashlib
    log = json.load(open(BED_LOG)) if os.path.exists(BED_LOG) else {}
    log[name] = {"secs": secs, "lufs": round(lufs(path), 1), "target": BED_LUFS,
                 "md5": hashlib.md5(open(path, "rb").read()).hexdigest()}
    _replace(BED_LOG, json.dumps(log, indent=1, sort_keys=True))


def level_beds():
    """Gain-only pass for beds that cc0_import did not build (make_ambience / make_rec_audio):
    bring each to BED_LUFS so Ambience's dB offsets mean the same thing for every bed."""
    import glob, hashlib
    import numpy as np
    log = json.load(open(BED_LOG)) if os.path.exists(BED_LOG) else {}
    for p in sorted(glob.glob(os.path.join(ROOT, "audio", "amb", "*.ogg"))):
        name = os.path.basename(p)[:-4]
        if name.startswith("spot_"):
            continue
        if name in log and log[name].get("md5") == hashlib.md5(open(p, "rb").read()).hexdigest():
            continue
        x = seamless(load(p, ch=2), 1.0)  # the generated beds were cut, not crossfaded: one tail-into-head pass
        g = BED_LUFS - lufs(p)
        y = x * 10 ** (g / 20)
        if float(np.max(np.abs(y))) > 0.7:
            y = np.tanh(y / 0.7) * 0.7
        save(y.astype(np.float32), p, ch=2, q=1, af="aresample=32000")
        bed_log(name, p, round(len(y) / SR, 1))
        print(f"  levelled bed {name}: {g:+.1f} dB, {len(y) / SR:.1f} s")


def _replace(path, text):
    """Write via a temp file + rename: audio/ files may be hardlinked elsewhere."""
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    if os.path.exists(path):
        os.remove(path)
    os.rename(tmp, path)


def add_real(path, names):
    old = open(path).read() if os.path.exists(path) else ""
    have = {l.strip() for l in old.splitlines() if l.strip() and not l.startswith("#")}
    new = sorted(set(names) - have)
    if new:
        _replace(path, old + ("" if old.endswith("\n") or not old else "\n") + "".join(n + "\n" for n in new))


def fetch(dst, packs):
    """Download each pack's files from its OpenGameArt page (cc0_sources.json) into dst/<pack>/,
    unpacking archives into <pack>/<archive>_x/. Packs already present are skipped."""
    import re, urllib.request, urllib.parse, zipfile
    src = json.load(open(SOURCES))
    bsb = sorted(p for p in packs if p.startswith("bigsoundbank/"))
    if bsb:
        out = os.path.join(dst, "bigsoundbank")
        os.makedirs(out, exist_ok=True)
        for p in bsb:
            sid = p.split("/", 1)[1][:4]
            fn = os.path.join(out, sid + ".ogg")
            if os.path.exists(fn):
                continue
            try:
                urllib.request.urlretrieve(f"https://bigsoundbank.com/UPLOAD/ogg/{sid}.ogg", fn)
            except Exception as e:  # noqa: BLE001
                print("  bigsoundbank failed", sid, e)
        print(f"  bigsoundbank: {len(bsb)} sounds")
        bsb_titles([p.split("/", 1)[1][:4] for p in bsb])
    for pack in sorted(p for p in packs if "/" not in p):
        info = src.get(pack)
        if not info or not info.get("cc0"):
            print("  no cc0 source for", pack)
            continue
        out = os.path.join(dst, pack)
        if os.path.isdir(out) and os.listdir(out):
            continue
        os.makedirs(out, exist_ok=True)
        try:
            html = urllib.request.urlopen(info["page"], timeout=60).read().decode("utf-8", "replace")
        except Exception as e:  # noqa: BLE001
            print("  page failed", pack, e)
            continue
        links = []
        for m in re.finditer(r'href="(https://opengameart\.org/sites/default/files/[^"]+)"', html):
            u = m.group(1)
            if re.search(r"\.(zip|7z|ogg|wav|mp3|flac|tar\.gz)$", u, re.I) and u not in links:
                links.append(u)
        for u in links:
            fn = os.path.join(out, urllib.parse.unquote(u.rsplit("/", 1)[1]))
            try:
                with urllib.request.urlopen(u, timeout=300) as r, open(fn, "wb") as fh:
                    fh.write(r.read())
            except Exception as e:  # noqa: BLE001
                print("  download failed", u, e)
                continue
            low = fn.lower()
            try:
                if low.endswith(".zip"):
                    zipfile.ZipFile(fn).extractall(fn[:-4] + "_x")
                elif low.endswith(".7z"):
                    import py7zr
                    py7zr.SevenZipFile(fn).extractall(fn[:-3] + "_x")
                elif low.endswith(".tar.gz"):
                    import tarfile
                    tarfile.open(fn).extractall(fn[:-7] + "_x")
            except Exception as e:  # noqa: BLE001
                print("  unpack failed", fn, e)
        print(f"  fetched {pack}: {len(links)} files")


def bsb_titles(ids):
    """C13 (c13_14-11): give every BigSoundBank id a title + page in tools/bsb_titles.json, read from
    the sound's own page, so credits never fall back to a bare '#NNNN'."""
    import re, urllib.request
    path = os.path.join(ROOT, "tools", "bsb_titles.json")
    t = json.load(open(path)) if os.path.exists(path) else {}
    added = 0
    for sid in sorted(set(ids)):
        if sid in t:
            continue
        try:
            html = urllib.request.urlopen(f"https://bigsoundbank.com/detail-{sid}.html", timeout=30).read().decode("utf-8", "replace")
        except Exception as e:  # noqa: BLE001
            print("  bigsoundbank title failed", sid, e)
            continue
        m = re.search(r"https://bigsoundbank\.com/([a-z0-9-]+)-s%s\.html" % sid, html)
        if not m:
            continue
        words = m.group(1).replace("-", " ")
        t[sid] = [words[:1].upper() + words[1:], m.group(0)]
        added += 1
    if added:
        _replace(path, json.dumps(t, indent=1, sort_keys=True) + "\n")


def write_credits():
    """Rebuild docs/AUDIO-CREDITS.md from audio/ACE_LOG.json, audio/CC0_USED.json, tools/cc0_sources.json
    and tools/bsb_titles.json, so every shipped sound has a row."""
    import glob
    ace = json.load(open(os.path.join(ROOT, "audio", "ACE_LOG.json")))
    used = json.load(open(os.path.join(ROOT, "audio", "CC0_USED.json")))
    src = json.load(open(SOURCES))
    bsbt = json.load(open(os.path.join(ROOT, "tools", "bsb_titles.json")))
    music = {os.path.basename(p)[:-4] for p in glob.glob(os.path.join(ROOT, "audio", "music", "*.ogg"))}
    L = ["# Dreams: audio sources", "",
         "This file is generated by `python3 tools/cc0_import.py --credits` (from audio/ACE_LOG.json, audio/CC0_USED.json, tools/cc0_sources.json). Edit those, then rerun.", "",
         "## Music, jingles and instrument sounds: ACE Music", "",
         "Made for Dreams with ACE Music (acemusic.ai) on Tom's account. Each track lists the version used; the other version is kept in audio/ACE_LOG.json and can be swapped with `python3 tools/ace_batch.py --swap <name>`.", "",
         "| Game name | Kind | ACE song page |", "|---|---|---|"]
    for name in sorted(ace):
        e = ace[name]
        page = next((v.get("page", "") for v in e.get("versions", []) if v.get("id") == e.get("chosen")), "")
        L.append(f"| {name} | {e.get('kind', 'music')} | {page} |")
    tom = sorted(m for m in music if m not in ace and m in ("title", "arc_penguins", "arc_gangsters"))
    if tom:
        L += ["", "Title and arc themes (" + ", ".join(tom) + "): Tom's own uploads (made with ACE Music; originals in audio/incoming/)."]
    other = sorted(m for m in music if m not in ace and m not in tom)
    if other:
        L += ["", "Other music files (placeholders from tools/make_audio.py until a render replaces them): " + ", ".join(other) + "."]
    L += ["", "## Recorded sound effects and ambience: CC0", "",
          "Every source below is CC0 (public domain), or dual-licensed with CC0 as one choice. No credit is required; it is given anyway.", "",
          "| Source | Author | Licence | Used for |", "|---|---|---|---|"]
    by_pack, bsb = {}, {}
    for name, files in used.items():
        for f in files:
            pack = f.split("/")[0]
            if pack == "bigsoundbank":
                bsb.setdefault(f.split("/")[1][:4], set()).add(name)
            else:
                by_pack.setdefault(pack, set()).add(name)
    for pack in sorted(by_pack, key=lambda k: src.get(k, {}).get("title", k).lower()):
        i = src.get(pack, {})
        lic = "/".join(i.get("licenses", ["CC0"]))
        L.append(f"| [{i.get('title', pack)}]({i.get('page', '')}) | {i.get('author', '?')} | {lic} | {', '.join(sorted(by_pack[pack]))} |")
    for sid in sorted(bsb):
        t, page = (bsbt.get(sid) or [f"#{sid}", "https://bigsoundbank.com/"])
        L.append(f"| [BigSoundBank #{sid} {t}]({page}) | Joseph Sardin | CC0 | {', '.join(sorted(bsb[sid]))} |")
    _replace(os.path.join(ROOT, "docs", "AUDIO-CREDITS.md"), "\n".join(L) + "\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="/tmp/cc0/dl")
    ap.add_argument("--dry", default="")
    ap.add_argument("--only", default="")
    ap.add_argument("--fetch", action="store_true", help="download the packs MAP needs first")
    ap.add_argument("--level-beds", action="store_true", help="only level the beds not built here to -26 LUFS")
    ap.add_argument("--credits", action="store_true", help="only rebuild docs/AUDIO-CREDITS.md")
    a = ap.parse_args()
    if a.credits:
        write_credits()
        return
    if a.level_beds:
        level_beds()
        return
    src = json.load(open(SOURCES))
    if a.fetch:
        packs = {(p if p.startswith("bigsoundbank/") else p.split("/")[0]) for n, (_, pats, o) in MAP.items()
                 if not a.only or n in a.only.split(",") for p in pats + ([o["layer"][0]] if o.get("layer") else [])}
        fetch(a.src, packs)
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
            secs = make_bed(full, os.path.join(amb_dir, f"{name}.ogg"), opt.get("join", False), af=opt.get("af", ""))
            print(f"  bed {name}: {secs} s")
            done_amb.append(name)
        else:
            base = (name if kind == "sfx" else "spot_" + name.split("@")[0])
            base = base.split("@")[0]
            out_dir = sfx_dir if kind == "sfx" else amb_dir
            if opt.get("slice"):
                takes = sliced_takes(full, opt, int(opt.get("takes", 3)))
                if opt.get("layer"):
                    takes = [layered(x, a.src, opt["layer"], i) for i, x in enumerate(takes)]
                    fs = fs + files_for(a.src, [opt["layer"][0]])
                for i, x in enumerate(takes):
                    nm = base if i == 0 else f"{base}_{i + 1}"
                    save(x, os.path.join(out_dir, nm + ".ogg"), af=opt.get("post", ""))
                    (done_sfx if kind == "sfx" else done_amb).append(nm)
            else:
                for i, f in enumerate(full[:3]):
                    nm = base if i == 0 else f"{base}_{i + 1}"
                    make_sfx(f, os.path.join(out_dir, nm + ".ogg"), float(opt.get("cap", 1.5)), af_pre=opt.get("af", ""))
                    (done_sfx if kind == "sfx" else done_amb).append(nm)
        used[name.replace("@", "_")] = fs
    if not a.dry:
        add_real(os.path.join(ROOT, "audio", "sfx", "REAL.txt"), done_sfx)
        add_real(os.path.join(ROOT, "audio", "amb", "REAL.txt"), done_amb)
        up = os.path.join(ROOT, "audio", "CC0_USED.json")
        allused = json.load(open(up)) if os.path.exists(up) else {}
        allused.update(used)  # --only runs keep every other sound's record
        _replace(up, json.dumps(allused, indent=1, sort_keys=True))
        write_credits()
    print(f"sfx {len(done_sfx)}  amb {len(done_amb)}  missing: {missing}")


if __name__ == "__main__":
    main()
