import re, openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
A="/tmp/audit_c10/20.txt"; S="/tmp/audit_c10/15.txt"
lines=open(A).read().splitlines()
i=lines.index("== TABLE (tab-separated; paste straight into a sheet) ==")
rows=[]
for l in lines[i+1:]:
    if l.startswith("=="): break
    if "\t" in l: rows.append(l.split("\t"))
hdr=rows[0]; data=rows[1:]
wb=openpyxl.Workbook()
F=Font(name="Arial",size=10); B=Font(name="Arial",size=10,bold=True,color="FFFFFF"); T=Font(name="Arial",size=14,bold=True)
fill=PatternFill("solid",fgColor="5B3A29"); band=PatternFill("solid",fgColor="F6EEDF")
thin=Side(style="thin",color="D9C7A8"); box=Border(bottom=thin)
def head(ws,r,cols):
    for c,v in enumerate(cols,1):
        x=ws.cell(r,c,v); x.font=B; x.fill=fill; x.alignment=Alignment(wrap_text=True,vertical="center")
# Progress
ws=wb.active; ws.title="Progress"
ws["A1"]="Dreams progress after 10 CONDUCT loops (2026-11-18)"; ws["A1"].font=T
ws["A2"]="Status key: done | done with stand-in art | partial | not started. % done = rough estimate (Claude's judgement) of the finished game for that row."; ws["A2"].font=Font(name="Arial",size=9,italic=True)
head(ws,4,hdr)
for r,row in enumerate(data,5):
    for c,v in enumerate(row[:6],1):
        if c==6:
            try: v=float(v)/100.0
            except: v=None
        x=ws.cell(r,c,v); x.font=F; x.alignment=Alignment(wrap_text=True,vertical="top"); x.border=box
        if c==6: x.number_format="0%"
        if r%2==0: x.fill=band
last=4+len(data)
ws.cell(last+2,1,"Overall (average of rows)").font=Font(name="Arial",size=10,bold=True)
x=ws.cell(last+2,6,f"=AVERAGE(F5:F{last})"); x.number_format="0%"; x.font=Font(name="Arial",size=10,bold=True)
ws.cell(last+3,1,"Rows done").font=F; ws.cell(last+3,6,f'=COUNTIF(C5:C{last},"done*")').font=F
ws.cell(last+4,1,"Rows that need something from Tom").font=F
ws.cell(last+5,1,"Whole-game estimate (systems ~90%, story ~80%, side stories 0%, art ~70%, music ~45%, co-op ~70%)").font=F
x=ws.cell(last+5,6,0.65); x.number_format="0%"; x.font=Font(name="Arial",size=10,color="0000FF")
ws.cell(last+6,1,"(The row average is higher because each finished system counts as one row; the whole-game figure weights the missing story, art and music.)").font=Font(name="Arial",size=9,italic=True); ws.cell(last+4,6,f'=COUNTIFS(E5:E{last},"<>No")').font=F
for c,w in zip("ABCDEF",[16,48,22,60,24,9]): ws.column_dimensions[c].width=w
ws.freeze_panes="A5"
# Art status per file
w2=wb.create_sheet("Art files")
w2["A1"]="Art prompt files still needed (nothing uploaded since w344)"; w2["A1"].font=T
st=open(S).read().splitlines()
j=[k for k,l in enumerate(st) if l.startswith("File | Title")][0]
head(w2,3,["File","Title","Prompts","Images","Still needed","Received","Superseded","Optional"])
r=4
for l in st[j+1:]:
    if l.startswith("TOTAL") or not l.strip(): 
        if l.startswith("TOTAL 17–29"): break
        continue
    p=[x.strip() for x in l.split("|")]
    if len(p)<8: continue
    vals=[p[0].replace(' (new, draft below)',' (new)'),p[1]]+[int(re.match(r"\d+",p[k]).group()) if re.match(r"\d+",p[k]) else 0 for k in (2,3,4,5)]+[p[6],p[7]]
    for c,v in enumerate(vals,1):
        x=w2.cell(r,c,v); x.font=F; x.alignment=Alignment(wrap_text=True,vertical="top"); x.border=box
    r+=1
w2.cell(r,1,"TOTAL").font=Font(name="Arial",size=10,bold=True)
for c in (3,4,5,6):
    L=get_column_letter(c); x=w2.cell(r,c,f"=SUM({L}4:{L}{r-1})"); x.font=Font(name="Arial",size=10,bold=True)
w2.cell(r+2,1,"Note: Prompts 29's 'still needed' counts only its firm images (8); its 4 optional images are listed in the Optional column.").font=Font(name="Arial",size=9,italic=True)
for c,w in zip("ABCDEFGH",[10,44,9,9,12,10,34,40]): w2.column_dimensions[c].width=w
# Art by prompt
w3=wb.create_sheet("Art by prompt")
w3["A1"]="Every image, by prompt (✗ = no longer needed, ○ = optional, ~ = partly have)"; w3["A1"].font=T
head(w3,3,["Prompt","What","Image","Status"])
r=4
k=[n for n,l in enumerate(st) if l.startswith("Per prompt")][0]
for l in st[k+1:]:
    if l.startswith("TOM MUST"): break
    m=re.match(r"(\d+-\d+) (.*?): (.*)",l)
    if not m: continue
    for img in [x.strip() for x in re.split(r",\s*(?=[✗○~]?w\d)",m.group(3))]:
        stt="still needed"
        if img.startswith("✗"): stt="no longer needed"
        elif img.startswith("○"): stt="optional"
        elif img.startswith("~"): stt="partly have; rest needed"
        name=img.lstrip("✗○~").split(" ")[0]
        note=img[len(img.lstrip("✗○~").split(" ")[0])+ (1 if img[0] in "✗○~" else 0):].strip()
        for c,v in enumerate([m.group(1),m.group(2),name,stt+(" "+note if note else "")],1):
            x=w3.cell(r,c,v); x.font=F; x.border=box; x.alignment=Alignment(wrap_text=True,vertical="top")
        r+=1
w3.cell(r+1,1,"Still needed (rows)").font=Font(name="Arial",size=10,bold=True)
w3.cell(r+1,4,f'=COUNTIF(D4:D{r-1},"still needed*")+COUNTIF(D4:D{r-1},"partly*")').font=Font(name="Arial",size=10,bold=True)
for c,w in zip("ABCD",[9,40,38,60]): w3.column_dimensions[c].width=w
w3.freeze_panes="A4"
# Decisions
w4=wb.create_sheet("Open decisions")
w4["A1"]="Tom's open decisions and asks (no answers recorded yet; defaults run until you say otherwise)"; w4["A1"].font=T
head(w4,3,["Group","Item"])
d0=lines.index("== TOM'S OPEN DECISIONS AND QUESTIONS (Guides 11-21) ==")
grp=""; r=4
for l in lines[d0+2:]:
    if l.startswith("== METHOD"): break
    if re.match(r"^[ABC]\. ",l): grp=l; continue
    if not l.strip(): continue
    for c,v in enumerate([grp,l.strip()],1):
        x=w4.cell(r,c,v); x.font=F; x.border=box; x.alignment=Alignment(wrap_text=True,vertical="top")
    r+=1
w4.column_dimensions["A"].width=34; w4.column_dimensions["B"].width=110
# Loops
w5=wb.create_sheet("10 loops")
w5["A1"]="What each CONDUCT loop did"; w5["A1"].font=T
head(w5,3,["Loop","Guide","Prompts","Bots after fixes","Highlights"])
L=[(1,13,"20","0 errors / 0 fails","Animal goods quality, overflow to chest, Sal/Big Jim, pup menu, fishing, caps, gentler early HP, stable skill unlocks"),
(2,14,"21","0 / 0","Orla/Granite, deep-floor caps, keeper ramp, HUD pointer, ground layer, rounder water, skill icons by name"),
(3,15,"22","0 / 0","Hut exits + check, 81 armour recipes, builds use chest materials, gutter-free floors, merkitties, catship panels"),
(4,16,"23","0 / 0","Sun Haven slot bag and chests, room side walls, one-body water, 23 all-ages lines, USE/CHECK buttons, clock box"),
(5,17,"24","0 / 0","~200 fixes: 8 new unlocks, Iron Gut, resume where you stood, item icons/names, mine chunk drawing, heart quests"),
(6,18,"25","0 / 0","Baked map ground (8-45x fewer draw calls), Big Coop/Barn/Silo, food cap, ore 1 in 6, 412 re-cut art files"),
(7,19,"26","0 game errors","Sell-box crash, perf patch, shared energy allowance, kill pay cap, bounded pathing, 173 re-cut files"),
(8,20,"27","0 / 0","Perf patch, tighter kill pay, rest half bar, co-op timers, farm debris, regions, quest timing, 623 re-cut files"),
(9,21,"28","0 / 0","Perf patch, co-op clock, stuck enemies, Fresh Rounds, plateaus, creator outfits/hair, 1,075 re-cut files"),
(10,22,"29","0 / 0","Perf + edge patches, co-op day stamps, unwon battle cap, renames keep points, tidy builds, 576 re-cut files, combined page")]
for r,row in enumerate(L,4):
    for c,v in enumerate(row,1):
        x=w5.cell(r,c,v); x.font=F; x.border=box; x.alignment=Alignment(wrap_text=True,vertical="top")
for c,w in zip("ABCDE",[6,7,9,18,100]): w5.column_dimensions[c].width=w
wb.save("Dreams-Progress-after-10-loops.xlsx"); print("rows",len(data))
