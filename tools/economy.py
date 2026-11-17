#!/usr/bin/env python3
"""Economy workbook: crops, energy, money sinks and the sim curves.
   python3 tools/economy.py [sim_penguins.csv] [sim_gangsters.csv] → docs/economy.xlsx"""
import csv, json, sys
from openpyxl import Workbook
from openpyxl.chart import LineChart, Reference
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.comments import Comment

items = json.load(open("data/items.json"))
crops = json.load(open("data/crops.json"))
builds = json.load(open("data/buildings.json"))
seeds = {v["crop"]: k for k, v in items.items() if v.get("type") == "seed"}
F = "Arial"
H = Font(name=F, bold=True, color="FFFFFF"); HF = PatternFill("solid", fgColor="3B2F5C")
B = Font(name=F); BLUE = Font(name=F, color="0000FF")

def header(ws, row, names):
    for i, n in enumerate(names, 1):
        c = ws.cell(row=row, column=i, value=n); c.font = H; c.fill = HF; c.alignment = Alignment(wrap_text=True)

wb = Workbook()
ws = wb.active; ws.title = "Crops"
ws["A1"] = "Crops — profit per tile per day (seed bought at 1.5× value, sold at value). Blue = data from data/*.json; edit there, not here."; ws["A1"].font = Font(name=F, bold=True)
ws["A2"] = "Season length (days)"; ws["B2"] = 28; ws["B2"].font = BLUE
ws["C2"] = "Buy markup"; ws["D2"] = 1.5; ws["D2"].font = BLUE
cols = ["Crop", "Season", "Tier", "Grow days", "Regrow", "Seed value", "Seed cost", "Sell value", "Harvests / season", "Profit / season / tile", "Profit / day / tile", "Energy / season / tile", "Profit per energy"]
header(ws, 4, cols)
r = 5
for cid, cd in crops.items():
    sid = seeds.get(cid, "")
    ws.cell(r, 1, cd["name"]).font = B
    ws.cell(r, 2, cd.get("season", "any")).font = B
    ws.cell(r, 3, cd.get("tier", 1)).font = BLUE
    ws.cell(r, 4, cd["days"]).font = BLUE
    ws.cell(r, 5, cd.get("regrow", 0)).font = BLUE
    ws.cell(r, 6, items.get(sid, {}).get("value", 0)).font = BLUE
    ws.cell(r, 7, f"=ROUND(F{r}*$D$2,0)").font = B
    ws.cell(r, 8, items.get(cd["yield"], {}).get("value", 0)).font = BLUE
    ws.cell(r, 9, f"=IF(E{r}>0,1+INT(($B$2-D{r})/E{r}),INT($B$2/D{r}))").font = B
    ws.cell(r, 10, f"=IF(E{r}>0,I{r}*H{r}-G{r},I{r}*(H{r}-G{r}))").font = B
    ws.cell(r, 11, f"=ROUND(J{r}/$B$2,2)").font = B
    ws.cell(r, 12, f"=IF(E{r}>0,3+1+2*$B$2,I{r}*(3+1)+2*$B$2)").font = B
    ws.cell(r, 13, f"=ROUND(J{r}/L{r},2)").font = B
    r += 1
ws.cell(r + 1, 1, "Energy: hoe 3, plant 1, water 2 per tile per day (GameState.ENERGY_COST). A regrow crop is hoed and planted once a season.").font = Font(name=F, italic=True)
ws["L4"].comment = Comment("hoe 3 + plant 1 per planting, water 2 per day of the season", "sim")
for col, w in zip("ABCDEFGHIJKLM", [14, 9, 6, 10, 8, 10, 10, 10, 12, 14, 12, 14, 12]): ws.column_dimensions[col].width = w

ws2 = wb.create_sheet("Energy & field")
ws2["A1"] = "How big a field one day's energy waters"; ws2["A1"].font = Font(name=F, bold=True)
header(ws2, 3, ["Farming levels", "Max energy", "Water cost", "Tiles waterable (70% of energy)", "Hoe cost", "Plant cost"])
for i, lv in enumerate([0, 5, 10, 15, 20, 30]):
    r = 4 + i
    ws2.cell(r, 1, lv).font = BLUE; ws2.cell(r, 2, f"=100+3*A{r}").font = B; ws2.cell(r, 3, 2).font = BLUE
    ws2.cell(r, 4, f"=INT(B{r}*0.7/C{r})").font = B; ws2.cell(r, 5, 3).font = BLUE; ws2.cell(r, 6, 1).font = BLUE
ws2["A11"] = "Max energy = 100 + 3 per skill level gained (all skills) + perks + gear (GameState.max_energy)."; ws2["A11"].font = Font(name=F, italic=True)
for col, w in zip("ABCDEF", [14, 12, 11, 28, 10, 10]): ws2.column_dimensions[col].width = w

ws3 = wb.create_sheet("Sinks")
ws3["A1"] = "Where the money goes"; ws3["A1"].font = Font(name=F, bold=True)
header(ws3, 3, ["Thing", "Tier / step", "Crystals", "Unlock"])
r = 4
for k, v in builds.items():
    if k.startswith("_"): continue
    for t in v.get("tiers", []):
        if int(t.get("permit", 0)) > 0:
            ws3.cell(r, 1, k).font = B; ws3.cell(r, 2, t.get("name")).font = B; ws3.cell(r, 3, t.get("permit")).font = BLUE; ws3.cell(r, 4, json.dumps(t.get("unlock", {}))).font = B; r += 1
for k in ["iron_sword", "steel_sword", "crystal_sword"]:
    ws3.cell(r, 1, "weapon").font = B; ws3.cell(r, 2, items[k]["name"]).font = B; ws3.cell(r, 3, f"=ROUND({items[k]['value']}*1.5,0)").font = B; ws3.cell(r, 4, f"tier {items[k].get('tier',1)}").font = B; r += 1
ws3.cell(r, 1, "TOTAL").font = Font(name=F, bold=True); ws3.cell(r, 3, f"=SUM(C4:C{r-1})").font = Font(name=F, bold=True)
for col, w in zip("ABCD", [14, 18, 11, 40]): ws3.column_dimensions[col].width = w

enemies = json.load(open("data/enemies.json"))
tiers = json.load(open("data/tiers.json"))["tiers"]
ws4 = wb.create_sheet("Combat")
ws4["A1"] = "Enemies: scaled HP, hits to kill with the sword of their tier, expected drop value"; ws4["A1"].font = Font(name=F, bold=True)
header(ws4, 3, ["Enemy", "Tier", "Base HP", "Tier HP mult", "Scaled HP", "Armor", "Sword dmg at tier", "Hits to kill", "Drop EV (crystals)", "EV per HP"])
sword_at = {0: 2 + 0, 1: 2 + 1, 2: 4 + 2, 3: 6 + 3, 4: 9 + 4, 5: 9 + 6}
ws4["L3"] = "Sword dmg by tier (wood 2 / copper tier, iron 4, steel 6, crystal 9 + tool tier)"; ws4["L3"].font = Font(name=F, italic=True)
for i, t in enumerate(range(6)):
    ws4.cell(4 + i, 12, t).font = BLUE; ws4.cell(4 + i, 13, sword_at[t]).font = BLUE
r = 4
for k, v in enemies["enemies"].items():
    t = int(v.get("tier", 0)); d = enemies["drops"].get(k, [])
    ev = sum(items.get(i, {}).get("value", 0) * p * n for i, p, n in d) * tiers[t]["loot"]
    ws4.cell(r, 1, k).font = B; ws4.cell(r, 2, t).font = BLUE; ws4.cell(r, 3, v["hp"]).font = BLUE
    ws4.cell(r, 4, tiers[t]["hp"]).font = BLUE; ws4.cell(r, 5, f"=ROUND(C{r}*D{r},0)").font = B
    ws4.cell(r, 6, tiers[t]["armor"]).font = BLUE
    ws4.cell(r, 7, f"=INDEX($M$4:$M$9,MATCH(B{r},$L$4:$L$9,0))").font = B
    ws4.cell(r, 8, f"=ROUNDUP(E{r}/MAX(1,G{r}-F{r}),0)").font = B
    ws4.cell(r, 9, round(ev, 1)).font = BLUE; ws4.cell(r, 10, f"=ROUND(I{r}/E{r},2)").font = B
    r += 1
for col, w in zip("ABCDEFGHIJ", [20, 6, 9, 12, 10, 7, 16, 11, 16, 10]): ws4.column_dimensions[col].width = w

def sim_sheet(name, path):
    s = wb.create_sheet(name)
    rows = list(csv.reader(open(path)))
    header(s, 1, rows[0])
    for i, row in enumerate(rows[1:], 2):
        for j, v in enumerate(row, 1):
            c = s.cell(i, j, int(v) if v.lstrip("-").isdigit() else v); c.font = B
    ch = LineChart(); ch.title = name + " — crystals by day (farming only, optimal bot)"; ch.roundedCorners = False
    ch.y_axis.title = "crystals"; ch.x_axis.title = "day"; ch.x_axis.delete = False; ch.y_axis.delete = False
    ch.add_data(Reference(s, min_col=3, min_row=1, max_row=len(rows)), titles_from_data=True)
    ch.set_categories(Reference(s, min_col=1, min_row=2, max_row=len(rows)))
    ch.legend.overlay = False; ch.title.overlay = False; ch.width = 22; ch.height = 9
    s.add_chart(ch, "M2")
    for col in "ABCDEFGHIJK": s.column_dimensions[col].width = 11
    return s

sims = sys.argv[1:] or ["/tmp/sim_penguins.csv", "/tmp/sim_gangsters.csv"]
for p in sims:
    sim_sheet("Sim " + p.split("sim_")[-1].replace(".csv", ""), p)
wb.save("docs/economy.xlsx"); print("docs/economy.xlsx")
