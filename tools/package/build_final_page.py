import re, html, markdown, openpyxl
D="/home/claude/dreams/docs"
head=open(__import__("os").path.join(__import__("os").path.dirname(__file__),"page_template.html")).read()
style=head[head.index("<style>"):head.index("</style>")+8]
script=head[head.index("<script>"):head.index("</script>")+9]
extra="<style>table.prog{border-collapse:collapse;font-size:12px;width:100%}table.prog td,table.prog th{border-bottom:1px solid #d9c7a8;padding:4px 6px;vertical-align:top;text-align:left}table.prog th{background:#5b3a29;color:#fff;position:sticky;top:0}.pct{white-space:nowrap;font-weight:bold}.st-done{color:#2e6b2e}.st-partial{color:#a0601a}.st-not{color:#a02020}.skip{text-decoration:line-through;opacity:.6}.wrap{overflow-x:auto}</style>"
order=[30,19,23,24,25,26,27,28,29,20,21,22,17,18]
wb=openpyxl.load_workbook("Dreams-Progress-Round12-Art.xlsx",data_only=True)
n=[0]
def prompts(md):
    out,buf=[],[]
    def flush():
        if buf:
            n[0]+=1
            t="\n".join(l[2:] if l.startswith("> ") else "" for l in buf)
            out.append(f'\n<div class="prompt"><button onclick="cp(\'a_{n[0]}\',this)">Copy</button><div id="a_{n[0]}" style="white-space:pre-wrap">{html.escape(t.strip())}</div></div>\n')
            buf.clear()
    for l in md.splitlines():
        if l.startswith(">"): buf.append(l)
        else: flush(); out.append(l)
    flush(); return "\n".join(out)
def table(ws, first, cols, pctcol=None, stcol=None):
    rows=['<div class="wrap"><table class="prog"><tr>'+"".join(f"<th>{html.escape(str(ws.cell(first,c).value))}</th>" for c in cols)+"</tr>"]
    r=first+1
    while ws.cell(r,cols[0]).value not in (None,"") and not str(ws.cell(r,1).value).startswith(("Overall","TOTAL","Still needed")):
        cells=[]
        for c in cols:
            v=ws.cell(r,c).value
            if c==pctcol and isinstance(v,(int,float)): cells.append(f'<td class="pct">{round(v*100)}%</td>'); continue
            cls=""
            if c==stcol:
                s=str(v)
                cls=' class="st-done"' if s.startswith("done") else (' class="st-partial"' if "partial" in s else (' class="st-not"' if "not" in s else ""))
                if s.startswith("no longer"): cls=' class="skip"'
            cells.append(f"<td{cls}>{html.escape(str(v if v is not None else ''))}</td>")
        rows.append("<tr>"+"".join(cells)+"</tr>"); r+=1
    rows.append("</table></div>"); return "\n".join(rows), r
P=wb["Progress"]; pt,pr=table(P,4,[1,2,3,4,5,6],pctcol=6,stcol=3)
A=wb["Art files"]; at,ar=table(A,3,[1,2,3,4,5,7,8])
B=wb["Art by prompt"]; bt,br=table(B,3,[1,2,3,4],stcol=4)
O=wb["Open decisions"]; ot,orr=table(O,3,[1,2])
Lp=wb["10 loops"]; lt,lr=table(Lp,3,[1,2,3,4,5])
R12=wb["Round 12 art"]; r12t,r12r=table(R12,2,[1,2,3,4],stcol=2)
R11=wb["Round 11"]; rt,rr=table(R11,3,[1,2,3,4],stcol=3)
AU=wb["Audio"]; aut,aur=table(AU,4,[1,2,3,4,5])
summary=f"<p><b>Whole game: about 77% done</b> (systems ~93%, main story ~80%, side stories 0%, art ~95%, audio ~98%, co-op ~70%). Average of the {pr-5} rows below: {round(P.cell(pr+1,6).value*100)}%. Images still needed: 0. Every prompt is drawn and in the game.</p>"
sections=[("guide","All-in-one guide",markdown.markdown(prompts(open(f"{D}/guides/GUIDE-24.md").read()),extensions=["tables"])),
 ("progress","Progress sheet","<h1>Progress sheet</h1>"+summary+"<p>The same sheet (with formulas) is attached in the chat as Dreams-Progress-Round12-Art.xlsx.</p>"+pt),
 ("round12","Round 12 art","<h1>Round 12: the art round</h1><p>All 179 images from Prompts 17-30 drawn with the image tool, plus 16 redraws and fills, all sliced into the game. No prompt files are left to paste.</p>"+r12t),
 ("round11","Round 11","<h1>Round 11 and region campaigns</h1>"+rt),
 ("audio","Audio","<h1>Audio: every track and sound</h1><p>61 ACE Music tracks, 45 ACE jingles/UI sounds, 300+ CC0 recordings and 40 ambience pieces. Say \"swap &lt;name&gt;\" to hear the other version of any track.</p>"+aut),
 ("decisions","Open decisions","<h1>Open decisions and asks</h1><p>Nothing here has an answer recorded yet; the game runs on the defaults.</p>"+ot),
 ("loops","10 loops","<h1>The 10 loops</h1>"+lt)]
for k in []:
    sections.append((f"p{k}",f"Prompts {k}",markdown.markdown(prompts(open(f"{D}/ART-PROMPTS-{k}.md").read()),extensions=["tables"])))
body=['<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Dreams — Everything after Round 11, audio and the art round: guide, progress, art</title>',style,extra,"</head><body>",
 "<nav>"+"".join(f'<a href="#{i}">{t}</a>' for i,t,_ in sections)+"</nav>"]
for i,t,h in sections: body.append(f'<section id="{i}">{h}</section>')
body.append(script+"</body></html>")
open("dreams_final.html","w").write("\n".join(body)); print("prompts",n[0],"progress rows",pr-5,"images rows",br-4)
