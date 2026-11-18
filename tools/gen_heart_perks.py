#!/usr/bin/env python3
"""Writes data/heart_perks.json: what each villager's heart perk actually does,
for every perk that isn't hand-coded elsewhere (has_friend_perk in scripts/).
Also rewrites those perk texts in data/npcs.json to say exactly what happens.

Each entry: text, and any of
  give   {item: n}   handed over once, when the heart level is first reached
  weekly {item: n}   arrives every Monday morning (day % 7 == 1) from then on
  season {item: n}   arrives on the first day of each season
  bonus  {hp|energy|mana: n}  one-time permanent max bonus
  flag   name        read by code: no_clinic_fee, quiet_steps,
                     ride_fast, skill_point, fog_lift, wisp_safe, soup
Run: python3 tools/gen_heart_perks.py
"""
import json, re, glob, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = {
 "maple": {"6": ("Maple sends a seed pack each season", {"season": {"#seedpack": 1}}),
           "10": ("Maple gifts a Golden Watering Can's worth of growth: 3 Growth Elixirs", {"give": {"growth_elixir": 3}})},
 "gideon": {"6": ("Gideon forges you a free Copper Ring", {"give": {"copper_ring": 1}}),
            "10": ("Gideon's last lesson: +20 max health", {"bonus": {"hp": 20}})},
 "wren": {"4": ("Wren leaves Energy Tea on your step each week", {"weekly": {"energy_tea": 2}}),
          "6": ("Wren brews you a free potion each week", {"weekly": {"potion": 1}}),
          "10": ("Wren teaches you to hold more magic: +20 max mana", {"bonus": {"mana": 20}})},
 "alder": {"2": ("Town records: the mayor sends a Map Scrap", {"give": {"map_scrap": 1}}),
           "6": ("A building grant: ◆500 toward your next plans", {"give": {"#gold": 500}}),
           "10": ("Keys to the city: ◆1000 from the town purse", {"give": {"#gold": 1000}})},
 "sal": {"2": ("Sal tells you where the loot is: a Map Scrap and a Luck Potion", {"give": {"map_scrap": 1, "luck_potion": 1}}),
         "4": ("Sal teaches you to walk quiet: enemies notice you later", {"flag": "quiet_steps"}),
         "6": ("Sal's spare kit: 2 Greater Potions", {"give": {"greater_potion": 2}}),
         "8": ("Sal's contacts slip you ◆300", {"give": {"#gold": 300}}),
         "10": ("Sal's old charm: a Dream Charm", {"give": {"dream_charm": 1}})},
 "finn": {"4": ("Finn's bait is free: 10 Bait every week", {"weekly": {"bait": 10}}),
          "6": ("Finn's secret spot: a Golden Float", {"give": {"golden_float": 1}}),
          "10": ("Finn's best tackle: 3 Golden Floats", {"give": {"golden_float": 3}})},
 "lumi": {"2": ("Lumi gives you paints for your sign", {"give": {"paint": 3}}),
          "4": ("Lumi sells you paints at cost: 3 Paint each week", {"weekly": {"paint": 3}}),
          "6": ("A portrait of you hangs in the hall (+10 max energy, you feel proud)", {"bonus": {"energy": 10}}),
          "8": ("Lumi teaches you to see: +10 max energy", {"bonus": {"energy": 10}}),
          "10": ("Lumi paints the Dream mural: a Dream Charm", {"give": {"dream_charm": 1}})},
 "theo": {"6": ("Theo translates the ruin stones: a Memory Tea", {"give": {"memory_tea": 2}}),
          "10": ("Theo's thesis: one free skill point in every tree", {"flag": "skill_point"})},
 "hazel": {"2": ("Hazel shares seeds: a seed pack each week", {"weekly": {"#seedpack": 1}}),
           "10": ("Hazel's heirloom seeds: 5 Dream Seeds", {"give": {"dream_seed": 5}})},
 "bram": {"2": ("Bram's breakfast: a Tea each week", {"weekly": {"tea": 1}}),
          "4": ("Free soup at the inn: +30 energy once a day", {"flag": "soup"}),
          "6": ("Bram's pies: 2 Orchard Pies", {"give": {"orchard_pie": 2}}),
          "8": ("Bram's stories: a Map Scrap", {"give": {"map_scrap": 1}})},
 "posy": {"4": ("Posy bakes for you: a Berry Pie each week", {"weekly": {"berry_pie": 1}}),
          "6": ("Posy's recipes: 2 Cakes", {"give": {"cake": 2}}),
          "10": ("Posy's best: a Wishfruit Cake each week", {"weekly": {"wishfruit_cake": 1}})},
 "juniper": {"10": ("Juniper teaches Second Wind: +30 max health", {"bonus": {"hp": 30}})},
 "rook": {"2": ("Rook shows tracks: a Pelt each week", {"weekly": {"pelt": 1}}),
          "6": ("Rook's map of the quarry path: a Map Scrap", {"give": {"map_scrap": 1}}),
          "8": ("Rook's field kit: 2 Greater Potions", {"give": {"greater_potion": 2}}),
          "10": ("Rook's lucky arrowhead: a Light Charm", {"give": {"light_charm": 1}})},
 "pip": {"2": ("Pip finds you coins: ◆20 each week", {"weekly": {"#gold": 20}}),
         "4": ("Pip's treasure map: a Map Scrap", {"give": {"map_scrap": 1}}),
         "6": ("Pip's secret: the fountain wish works (a Luck Potion)", {"give": {"luck_potion": 1}}),
         "8": ("Pip's gang brings you shells each week", {"weekly": {"seashell": 3}}),
         "10": ("Pip's lucky charm", {"give": {"paw_charm": 1}})},
 "wren_jr": {"2": ("Wren jr shares forage spots: a Tea Leaf each week", {"weekly": {"tea_leaf": 2}}),
             "4": ("A frog friend (it eats the bugs: +10 max energy)", {"bonus": {"energy": 10}}),
             "6": ("Wren jr's garden: flower seeds each week", {"weekly": {"#seedpack": 1}}),
             "8": ("Wren jr's potion lesson: 2 Mana Potions", {"give": {"mana_potion": 2}}),
             "10": ("Wren jr's wish: a Wishfruit", {"give": {"wishfruit": 2}})},
 "tobin": {"2": ("Tobin trades shells: 3 each week", {"weekly": {"seashell": 3}}),
           "4": ("Tobin's beach map: a Map Scrap", {"give": {"map_scrap": 1}}),
           "6": ("Tobin's kite day: +10 max energy", {"bonus": {"energy": 10}}),
           "8": ("Tobin's crew finds you ◆30 a week", {"weekly": {"#gold": 30}}),
           "10": ("Tobin's compass: a Light Charm", {"give": {"light_charm": 1}})},
 "mabel": {"2": ("Mabel shares a secret: a Memory Tea", {"give": {"memory_tea": 1}}),
           "4": ("Mabel's flower crown: +10 max energy", {"bonus": {"energy": 10}}),
           "6": ("Mabel's songs: +10 max mana", {"bonus": {"mana": 10}}),
           "8": ("Mabel's diary: a Herbal Tea each week", {"weekly": {"herbal_tea": 1}}),
           "10": ("Mabel's wish: a Wonder Elixir", {"give": {"wonder_elixir": 1}})},
 "marlowe": {"2": ("Marlowe sells you lamp oil: 2 each week", {"weekly": {"lamp_oil": 2}}),
             "4": ("Marlowe's charts: a Golden Float", {"give": {"golden_float": 1}}),
             "6": ("Night fishing at the lighthouse: 10 Bait each week", {"weekly": {"bait": 10}}),
             "8": ("Marlowe tells the story of the crystal: a Moonlight Elixir", {"give": {"moonlight_elixir": 1}}),
             "10": ("Marlowe's old tackle box: 3 Golden Floats", {"give": {"golden_float": 3}})},
 "orla": {"2": ("Orla's spare flour: 3 each week", {"weekly": {"flour": 3}}),
          "4": ("Orla sells wheat seed at cost: a seed pack each week", {"weekly": {"#seedpack": 1}}),
          "6": ("Orla's cornmeal: 3 each week", {"weekly": {"cornmeal": 3}}),
          "8": ("The mill works for you: 5 Flour each week", {"weekly": {"flour": 5}}),
          "10": ("Orla's heirloom grain: 5 Dream Seeds", {"give": {"dream_seed": 5}})},
 "benno": {"4": ("Benno's saddle care: your horse runs 10% faster", {"flag": "ride_fast"}),
           "6": ("Benno's oats: +20 max energy", {"bonus": {"energy": 20}}),
           "8": ("Benno's spare tack sells for ◆250", {"give": {"#gold": 250}}),
           "10": ("Benno's llama wool: 3 Wool each week", {"weekly": {"sheep_wool": 3}})},
 "ivy": {"4": ("Ivy's small loan you never have to pay back: ◆400", {"give": {"#gold": 400}}),
         "8": ("Ivy's insurance: no clinic fee when you collapse", {"flag": "no_clinic_fee"}),
         "10": ("Ivy's vault: a Sapphire each week", {"weekly": {"sapphire": 1}})},
 "tam": {"2": ("Tam's wool: 2 each week", {"weekly": {"sheep_wool": 2}}),
         "4": ("Tam's sheepdog finds forage: a Tea Leaf each week", {"weekly": {"tea_leaf": 2}}),
         "6": ("Tam gives you a lamb's worth of wool: 5 Wool", {"give": {"sheep_wool": 5}}),
         "8": ("Tam's cider: 2 each week", {"weekly": {"cider": 2}}),
         "10": ("Tam's hills: 2 Golden Apples", {"give": {"golden_apple": 2}})},
 "old_moss": {"2": ("Moss shows safe paths: marsh wisps leave you be", {"flag": "wisp_safe"}),
              "4": ("Bog iron: 3 each week", {"weekly": {"bog_iron": 3}}),
              "6": ("Moss's lantern: the marsh fog lifts near you", {"flag": "fog_lift"}),
              "8": ("Marsh gas jars: 2 each week", {"weekly": {"marsh_gas": 2}}),
              "10": ("Moss's secret: a Growth Elixir each week", {"weekly": {"growth_elixir": 1}})},
 "granite": {"2": ("Granite's crew drops off stone: 10 each week", {"weekly": {"stone": 10}}),
             "4": ("Granite sells dynamite at cost: 2 each week", {"weekly": {"dynamite": 2}}),
             "6": ("Granite's spare ore: 5 Copper each week", {"weekly": {"copper": 5}}),
             "8": ("Granite's crew clears rockslides: 3 Dynamite", {"give": {"dynamite": 3}}),
             "10": ("The deep quarry: 2 Sapphires", {"give": {"sapphire": 2}})},
 "sel": {"2": ("Sel reads the first rune: a Memory Tea", {"give": {"memory_tea": 1}}),
         "4": ("+10 max mana", {"bonus": {"mana": 10}}),
         "6": ("Sel opens the stone door: 2 Mana Potions", {"give": {"mana_potion": 2}}),
         "8": ("Sel's translation: +10 max mana", {"bonus": {"mana": 10}}),
         "10": ("Sel's staff: +20 max mana", {"bonus": {"mana": 20}})},
}
items = json.load(open(os.path.join(ROOT, "data/items.json")))
npcs = json.load(open(os.path.join(ROOT, "data/npcs.json")))
src = "".join(open(f).read() for f in glob.glob(os.path.join(ROOT, "scripts/*.gd")))
coded = set(re.findall(r'has_friend_perk\("([a-z_]+)", (\d+)\)', src))
out = {"_": "Heart perks run by scripts/perks.gd. Generated by tools/gen_heart_perks.py."}
for npc, levels in P.items():
    assert npc in npcs, npc
    for h, (text, fx) in levels.items():
        assert (npc, h) not in coded, ("already hand-coded", npc, h)
        for k in ("give", "weekly", "season"):
            for it in fx.get(k, {}):
                assert it.startswith("#") or it in items, ("missing item", npc, h, it)
        out.setdefault(npc, {})[h] = dict(fx, text=text)
        npcs[npc].setdefault("perks", {})[h] = text
# Birthdays: spread through the year, never two on one day, none on festival days.
SEASONS = ["spring", "summer", "fall", "winter"]
order = sorted(npcs)
for i, npc in enumerate(order):
    season = SEASONS[i % 4]
    day = 3 + (i // 4) * 4 + (i % 3)
    npcs[npc]["birthday"] = [season, day]
json.dump(out, open(os.path.join(ROOT, "data/heart_perks.json"), "w"), indent=1)
json.dump(npcs, open(os.path.join(ROOT, "data/npcs.json"), "w"), indent=1, ensure_ascii=False)
print("perks:", sum(len(v) for k, v in out.items() if k != "_"))
