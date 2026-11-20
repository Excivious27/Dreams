import csv, re, openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
D='/home/claude/dreams'
wb=openpyxl.Workbook()
H=Font(name='Arial',bold=True,color='FFFFFF'); HF=PatternFill('solid',fgColor='5B3A29')
N=Font(name='Arial',size=10); B=Font(name='Arial',size=10,bold=True); T=Font(name='Arial',size=14,bold=True)
W=Alignment(wrap_text=True,vertical='top'); thin=Side(style='thin',color='D9C7A8')
def sheet(ws,headers,rows,widths,title=None):
    r0=1
    if title:
        ws.cell(1,1,title).font=T; r0=3
    for c,h in enumerate(headers,1):
        x=ws.cell(r0,c,h); x.font=H; x.fill=HF; x.alignment=W
    for i,row in enumerate(rows,r0+1):
        for c,v in enumerate(row,1):
            x=ws.cell(i,c,v); x.font=N; x.alignment=W; x.border=Border(bottom=thin)
    for c,w in enumerate(widths,1): ws.column_dimensions[get_column_letter(c)].width=w
    ws.freeze_panes=ws.cell(r0+1,1)
    return r0
inv=[r for r in csv.reader(open(f'{D}/docs/inventory.csv'))]
hdr=inv[0]; body=inv[1:]
sysrows=[]
for r in body:
    if r[0]=='Outstanding': break
    if len(r)>3 and r[3].strip().isdigit(): sysrows.append(r)
# Systems
ws=wb.active; ws.title='Overview'
s2=wb.create_sheet('Systems')
rows=[[r[0],r[1],r[2],int(r[3])/100,None,r[4],r[5]] for r in sysrows]
r0=sheet(s2,['Area','System / feature','Status','% done','% remaining','Tests','Notes'],rows,[12,48,10,9,11,34,60])
for i in range(r0+1,r0+1+len(rows)):
    s2.cell(i,4).number_format='0%'; s2.cell(i,5,f'=1-D{i}').number_format='0%'; s2.cell(i,5).font=N
last=r0+len(rows)
# Overview
ws.cell(1,1,'Dreams: progress after CONDUCT 4 (2026-11-19)').font=T
ws.cell(3,1,'Whole game % done').font=B; ws.cell(3,2,f"=AVERAGE(Systems!D{r0+1}:D{last})").number_format='0%'
ws.cell(4,1,'Whole game % remaining').font=B; ws.cell(4,2,'=1-B3').number_format='0%'
ws.cell(5,1,'Note').font=B; ws.cell(5,2,'Mega regions reached 88%; difficulty and day length done. The total dipped because the hazards/lava (C20) and General Store (C21) systems now count at 0%; built systems average about 83%.').alignment=W
areas=sorted(set(r[0] for r in sysrows))
ws.cell(7,1,'Area').font=H; ws.cell(7,1).fill=HF; ws.cell(7,2,'% done').font=H; ws.cell(7,2).fill=HF; ws.cell(7,3,'% remaining').font=H; ws.cell(7,3).fill=HF; ws.cell(7,4,'Systems').font=H; ws.cell(7,4).fill=HF
for i,a in enumerate(areas,8):
    ws.cell(i,1,a).font=N
    ws.cell(i,2,f'=AVERAGEIF(Systems!A{r0+1}:A{last},A{i},Systems!D{r0+1}:D{last})').number_format='0%'
    ws.cell(i,3,f'=1-B{i}').number_format='0%'
    ws.cell(i,4,f'=COUNTIF(Systems!A{r0+1}:A{last},A{i})')
ws.column_dimensions['A'].width=26; ws.column_dimensions['B'].width=70; ws.column_dimensions['C'].width=12; ws.column_dimensions['D'].width=10
ws.freeze_panes='A8'
# CONDUCT 2 tab from report tables
rep=open(f'{D}/docs/reports/CONDUCT-4.md').read()
def mdtable(sec):
    part=rep.split(sec,1)[1]
    out=[]
    for l in part.splitlines():
        if l.startswith('|') and not l.startswith('|---'):
            out.append([c.strip() for c in l.strip('|').split('|')])
        elif out and not l.startswith('|'): break
    return out[0],out[1:]
h1,r1=mdtable('## Audit'); h2,r2=mdtable('## Fix packages')
s3=wb.create_sheet('CONDUCT 4')
sheet(s3,['Area / package','Found / fixed'],[[x[0],x[1]] for x in r1]+[['','']]+[[x[0],x[1]] for x in r2],[34,120],'CONDUCT 4: audit findings, then fix packages')
# Still needed from Tom
g=open(f'{D}/docs/guides/GUIDE-28.md').read()
items=[]
sec=''
for l in g.splitlines():
    if l.startswith('## '): sec=l[3:]
    m=re.match(r'^(\d+)\. (.*)',l)
    if m and not sec.startswith('What to test') and not sec.startswith('Already'): items.append([int(m.group(1)),sec,re.sub(r'\*\*','',m.group(2))])
s4=wb.create_sheet('Still needed from Tom')
sheet(s4,['#','Group','Question (default runs until you answer)','Your answer'],[[a,b,c,''] for a,b,c in items],[5,30,90,30],'Still needed from Tom (Guide 28)')
for i in range(4,4+len(items)): s4.cell(i,4).fill=PatternFill('solid',fgColor='FFF2A8')
# Playtest notes
tp=open('/home/claude/dreams/docs/TOM-PLAYTEST-2026-11-19.md').read()
pr=[[c.strip() for c in l.strip('|').split('|')] for l in tp.splitlines() if l.startswith('| ') and not l.startswith('| #')]
done={1,2,3,4,7,8,9,10,12,13,14,15,16,17,18,20,21}
s5=wb.create_sheet('Your playtest notes')
sheet(s5,['#','Note','Status','Where'],[[int(p[0]),p[1],'done (C2)' if int(p[0]) in done else 'started; continues',p[2]] for p in pr],[5,90,18,22],'Your phone playtest notes (21)')
# Plan
s6=wb.create_sheet('Plan')
plan=[['C1','First 3 hours, both arcs','done'],['C2','Rec Center, arcade, community farm + your playtest notes','done'],['C3','Battle campaigns','done'],['C4','Mega regions + difficulty + day length','done'],['C5','Home-world look and feel','next'],['C6','Audio and music',''],['C7','Story, quests, writing',''],['C8','Economy, progression, balance',''],['C9','Release readiness',''],['C10a','Decor and cosmetics (half 1)',''],['C10b','Decor and cosmetics (half 2)',''],['C11a','Ranching and livestock (half 1)',''],['C11b','Ranching, trainable team animals (half 2)',''],['C12','Writing, story, dialogue (thorough)',''],['C13','Audio depth (alternate area/season soundtracks, full audit)',''],['C14','Aesthetic quality of the world',''],['C15','Seasons (festivals, holidays, seasonal content)',''],['C16','Progression and balance across 3 years',''],['C17','Multiplayer (versus/co-op, then your ~$4/month server)',''],['C18a','Cutscenes: Crystopia intro, story scenes',''],['C18b','Cutscenes: night and side-event scenes',''],['C19','Trading cards (packs, binder, trading, regions)',''],['C20','Hazards, jumping and flight, lava region, mine hazards',''],['C21','The General Store side arc',''],['C22','Polish pass + code cleanup',''],['C23','One consistent art direction',''],['End','Final package and artifact page','']]
MINS={'C1': '~240', 'C2': '~240', 'C3': '~188', 'C4': '~105 to merge'}
plan=[r+[MINS.get(r[0],'')] for r in plan]
sheet(s6,['CONDUCT','Focus','Status','Minutes (all in)'],plan,[10,70,12,18],'The plan (target ~90 minutes each from C5)')
wb.save('/home/claude/pkg/Dreams-Progress-CONDUCT-4.xlsx'); print('ok', len(sysrows), len(items), len(pr))
