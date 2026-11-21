#!/usr/bin/env python3
"""C16b P4: the battle reward ladder -> data/battle_rewards.json (read by BattleRewards,
scripts/battle_rewards.gd). Runs in regen_data.sh right after gen_battles (reads
data/battles.json, data/decor.json, data/items.json).

Tom's ask: progressively tiered rewards that make battles almost critical but never
essential. Nothing here is story-required (checked below against story/quest needs).

Ladder per campaign (both arcs):
  stars per battle node, 1-3: 1 = won, 2 = won with every ally standing (no player KO
    and >= half your tickets left), 3 = also under the node's par time.
    Paid on rank-up only: 2 stars +40% of the node's crystals, 3 stars +60% + a Supply chest.
  rematch: a node already won pays 20% of its crystals + strategist XP once a day.
  first clear (gate): a tier chest + the campaign's trophy decor (DecorSources.grant).
  mastery (every node at 3 stars): a Commander chest + a mastery piece (decor; three
    campaigns also give the old legacy uniques: Aurora Blade, Prism Lance, Tommy Gun).
  chests: Supply / Field / War / Commander, a material bundle + a chance at chest decor.
  mastery track per arc: total stars thresholds pay strategist XP and money.
  battle bonds: allies in the line-up when a campaign is won earn a bond (cap 2) that
    Companion/Crew can read through BattleRewards.bond(name) (add-only).
"""
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def load(p):
    with open(os.path.join(ROOT, p)) as f:
        return json.load(f)


BATTLES = load("data/battles.json")["_campaigns"]
DECOR = load("data/decor.json")["items"]
ITEMS = load("data/items.json")
ITEMS = ITEMS.get("items", ITEMS)

STAR_PAY = {"2": 0.4, "3": 0.6}
REMATCH = {"share": 0.2, "xp_win": 60, "xp_rank": 100}
PAR_BASE = {"skirmish": 150, "siege": 210, "escort": 180, "defend": 180, "boss": 200, "gate": 240}

# Chest tiers (by campaign tier); items per arc (gangsters swap crystal goods for parts).
CHESTS = {
    "supply": {"name": "Supply Chest", "name_gang": "Supply Crate", "tier": 1, "money": 120,
               "items": {"potion": 2, "copper_bar": 3}, "arc_items": {"penguins": {"crystal_refined": 1}, "gangsters": {"servo": 2}},
               "decor_pool": "chest_t1", "decor_chance": 0.25},
    "field": {"name": "Field Chest", "name_gang": "Field Crate", "tier": 2, "money": 300,
              "items": {"greater_potion": 2, "iron_bar": 4}, "arc_items": {"penguins": {"crystal_refined": 2}, "gangsters": {"servo": 3, "data_chip": 1}},
              "decor_pool": "chest_t2", "decor_chance": 0.3},
    "war": {"name": "War Chest", "name_gang": "Strongbox", "tier": 3, "money": 650,
            "items": {"gold_bar": 3, "pearl": 1}, "arc_items": {"penguins": {"crystal_refined": 3}, "gangsters": {"servo": 5, "data_chip": 2}},
            "decor_pool": "chest_t3", "decor_chance": 0.35},
    "commander": {"name": "Commander's Chest", "name_gang": "Kingpin's Safe", "tier": 5, "money": 1400,
                  "items": {"crystal_battery": 2, "ruby": 1, "emerald": 1}, "arc_items": {"penguins": {"crystal_refined": 4}, "gangsters": {"servo": 6, "data_chip": 3}},
                  "decor_pool": "chest_t4", "decor_chance": 0.5},
}
FIRST_CHEST = {1: "supply", 2: "field", 3: "war", 4: "war", 5: "commander"}
GOLD_NODE_CHEST = "supply"
MASTERY_CHEST = "commander"
LEGACY_TOOLS = {"c_wastes": {"penguins": "aurora_blade"}, "c_sky": {"penguins": "prism_lance"},
                "c_countryside": {"gangsters": "tommy_gun"}}
TRACK = [{"at": 10, "xp": 200, "money": 500}, {"at": 30, "xp": 400, "money": 1200},
         {"at": 60, "xp": 700, "money": 2500}, {"at": 100, "xp": 1000, "money": 4000}]
TROPHY_WORDS = ("trophy", "medal", "cup", "statue", "banner", "flag", "shield", "crest", "plaque", "orrery", "globe", "telescope")
TROPHY_SUBS = ("statue", "trophy", "banner", "flag", "plaque", "sign", "bust", "shield", "lantern", "clock")


def arc_ok(item_arc, camp_arc):
    if camp_arc == "both":
        return item_arc in ("", None)
    return item_arc in ("", None, camp_arc)


def pick_decor(tier, camp_arc, used, salt, trophy=False):
    """A deterministic trophy pick: decor of this tier (or the nearest) that fits the arc,
    trophy-like subs first, never one already used by another campaign."""
    for dt in [tier, tier + 1, tier - 1, tier + 2, tier - 2, tier + 3, tier - 3]:
        pool = sorted(k for k, v in DECOR.items()
                      if int(v.get("tier", 0)) == dt and arc_ok(v.get("arc", ""), camp_arc)
                      and v.get("cat") == "decor" and v.get("rarity") != "mythic" and k not in used
                      and not k.startswith(("dc_show_", "dc_u_")))
        first = [k for k in pool if str(DECOR[k].get("sub", "")) in TROPHY_SUBS
                 or any(w in (k + " " + str(DECOR[k].get("name", ""))).lower() for w in TROPHY_WORDS)]
        for cand in ((first,) if trophy else (first, pool)):
            if cand:
                k = cand[salt % len(cand)]
                used.add(k)
                return k
    if trophy:
        return pick_decor(tier, camp_arc, used, salt)
    return ""


def main():
    used = set()
    camps = {}
    for i, (cid, c) in enumerate(sorted(BATTLES["list"].items())):
        tier = int(c.get("tier", 1))
        nodes = {}
        for n in c.get("nodes", []):
            if not n.get("reward"):
                continue
            nodes[n["id"]] = {"crystals": int(n["reward"].get("crystals", 0)),
                              "par": PAR_BASE.get(n.get("type", "skirmish"), 180) + 15 * tier}
        camps[cid] = {
            "tier": tier, "arc": c.get("arc", "both"),
            "max_stars": 3 * len(nodes), "nodes": nodes,
            "first_clear": {"chest": FIRST_CHEST[tier], "trophy": pick_decor(tier, c.get("arc", "both"), used, i, True)},
            "mastery": {"chest": MASTERY_CHEST, "decor": pick_decor(min(5, tier + 1), c.get("arc", "both"), used, i + 7),
                        "tool": LEGACY_TOOLS.get(cid, {})},
        }
    out = {"_doc": "C16b P4 battle reward ladder (tools/gen_battle_rewards.py; BattleRewards). Never edit by hand.",
           "star_pay": STAR_PAY, "rematch": REMATCH, "chests": CHESTS, "gold_node_chest": GOLD_NODE_CHEST,
           "track": TRACK, "bond_cap": 2, "campaigns": camps}
    # Sanity: every item and decor exists; arc items fit their arc; nothing story-required.
    bad = []
    for ck, ch in CHESTS.items():
        for it in ch["items"]:
            if it not in ITEMS:
                bad.append("chest %s item %s" % (ck, it))
            elif ITEMS[it].get("arc") not in (None, ""):
                bad.append("chest %s item %s is arc-only, use arc_items" % (ck, it))
        for a, d in ch["arc_items"].items():
            for it in d:
                if it not in ITEMS or ITEMS[it].get("arc") not in (None, "", a):
                    bad.append("chest %s %s item %s" % (ck, a, it))
    for cid, cd in camps.items():
        for k in (cd["first_clear"]["trophy"], cd["mastery"]["decor"]):
            if k not in DECOR:
                bad.append("%s decor %r" % (cid, k))
        for a, t in cd["mastery"]["tool"].items():
            if t not in ITEMS or ITEMS[t].get("arc") not in (None, "", a):
                bad.append("%s tool %s" % (cid, t))
    story = json.dumps([load("data/story.json"), load("data/story_gang.json")])
    for cid, cd in camps.items():
        for k in (cd["first_clear"]["trophy"], cd["mastery"]["decor"]):
            if '"%s"' % k in story:
                bad.append("%s ladder decor %s is named by the story" % (cid, k))
    if bad:
        print("gen_battle_rewards: " + "; ".join(bad))
        sys.exit(1)
    with open(os.path.join(ROOT, "data/battle_rewards.json"), "w") as f:
        json.dump(out, f, indent=1, sort_keys=True)
        f.write("\n")
    print("gen_battle_rewards: %d campaigns, %d chests" % (len(camps), len(CHESTS)))


if __name__ == "__main__":
    main()
