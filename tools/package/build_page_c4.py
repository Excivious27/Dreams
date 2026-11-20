import csv, html, markdown, re, sys
D='/home/claude/dreams'; N=sys.argv[1] if len(sys.argv)>1 else '2'
inv=[r for r in csv.reader(open(f'{D}/docs/inventory.csv'))]
rows=[]
for r in inv[1:]:
    if r and r[0]=='Outstanding': break
    if len(r)>3 and r[3].strip().isdigit(): rows.append(r)
tot=round(sum(int(r[3]) for r in rows)/len(rows))
areas={}
for r in rows: areas.setdefault(r[0],[]).append(int(r[3]))
abars=''.join(f'<div class="bar"><span class="l">{html.escape(a)}</span><span class="t"><i style="width:{round(sum(v)/len(v))}%"></i></span><span class="n">{round(sum(v)/len(v))}%</span></div>' for a,v in sorted(areas.items(),key=lambda x:-sum(x[1])/len(x[1])))
st={'done':'ok','rough':'mid','missing':'no'}
systab='<div class="scroll"><table class="stack"><thead><tr><th>Area</th><th>System</th><th>Status</th><th>Done</th><th>Left</th><th>Notes</th></tr></thead><tbody>'+''.join(f'<tr><td>{html.escape(r[0])}</td><td>{html.escape(r[1])}</td><td class="{st.get(r[2],"")}">{r[2]}</td><td class="num">{r[3]}%</td><td class="num">{100-int(r[3])}%</td><td>{html.escape(r[5])}</td></tr>' for r in rows)+'</tbody></table></div>'
md=lambda p: markdown.markdown(open(p).read(),extensions=['tables'])
guide=md(f'{D}/docs/guides/GUIDE-2{4+int(N)}.md')
report=md(f'{D}/docs/reports/CONDUCT-{N}.md')
plan=md('/home/claude/dreams/tools/package/plan.md')
tp=md('/home/claude/dreams/docs/TOM-PLAYTEST-2026-11-19.md')
secs=[('progress','Progress'),('guide','Guide'),('report','Report'),('notes','Your notes'),('plan','Plan'),('art','Art prompts')]
page=f'''<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Dreams CONDUCT {N}</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link href="https://fonts.googleapis.com/css2?family=Pixelify+Sans:wght@600&family=Nunito:wght@400;700&display=swap" rel="stylesheet">
<style>
/* VOICE: a farm-game ledger, warm and plain. IDEA: the in-game quest board. PICTURE: the big progress meter as a crop row. COLOUR and TYPE: meadow green, wheat gold, bark ink; Pixelify Sans titles, Nunito text. LAYOUT: sticky tab row, one section at a time. */
:root{{color-scheme:light dark;--bg:light-dark(#f7f3e6,#17201a);--ink:light-dark(#2b2118,#ece6d6);--green:light-dark(#2f6b3f,#5fae72);--gold:#e8b13a;--line:light-dark(#d9ccb0,#33443a);--card:light-dark(#fffdf6,#1f2a22)}}
:root[data-theme=light]{{color-scheme:light}}:root[data-theme=dark]{{color-scheme:dark}}
*{{box-sizing:border-box;min-width:0}}body{{margin:0;background:var(--bg);color:var(--ink);font:16px/1.55 Nunito,system-ui,sans-serif;overflow-x:clip}}
header{{background:var(--green);color:#fff;padding:22px max(5vw,16px) 18px}}header h1{{font:600 clamp(28px,5vw,44px)/1.05 "Pixelify Sans",sans-serif;margin:0 0 6px}}header p{{margin:0;opacity:.9}}
nav{{position:sticky;top:0;z-index:5;display:flex;gap:6px;overflow-x:auto;padding:8px max(5vw,16px);background:var(--bg);border-bottom:1px solid var(--line)}}
nav a{{flex:none;padding:10px 14px;border-radius:10px;color:var(--ink);text-decoration:none;font-weight:700;min-height:44px}}nav a.on{{background:var(--green);color:#fff}}
main{{max-width:1000px;margin:0 auto;padding:18px max(4vw,14px) 60px}}section{{display:none}}section.on{{display:block}}
.meter{{display:grid;grid-template-columns:auto minmax(0,1fr);gap:18px;align-items:center;background:var(--card);border:1px solid var(--line);border-radius:16px;padding:18px}}
.big{{font:600 clamp(52px,12vw,96px)/1 "Pixelify Sans",sans-serif;color:var(--green)}}.row{{height:30px;border-radius:8px;background:var(--line);overflow:hidden;position:relative}}.row i{{position:absolute;inset:0 auto 0 0;background:repeating-linear-gradient(90deg,var(--green) 0 14px,#3f8a52 14px 16px)}}
.row b{{position:absolute;right:8px;top:4px;font-size:13px}}.sub{{margin:6px 0 0;font-size:15px}}
.bars{{margin:18px 0}}.bar{{display:grid;grid-template-columns:8.5em minmax(0,1fr) 3em;gap:10px;align-items:center;margin:6px 0}}.bar .t{{height:14px;background:var(--line);border-radius:7px;overflow:hidden}}.bar i{{display:block;height:100%;background:var(--gold)}}.bar .n{{text-align:right;font-weight:700}}
h2{{font:600 26px/1.1 "Pixelify Sans",sans-serif;margin:28px 0 10px}}h3{{margin:22px 0 8px}}
table{{border-collapse:collapse;width:100%;font-size:14px;margin:10px 0}}th{{background:var(--green);color:#fff;text-align:left;padding:6px}}td{{border-bottom:1px solid var(--line);padding:6px;vertical-align:top}}td.num{{text-align:right;white-space:nowrap}}
td.ok{{color:var(--green);font-weight:700}}td.mid{{color:#b7791f;font-weight:700}}td.no{{color:#c0392b;font-weight:700}}
a{{color:var(--green)}}.scroll{{overflow-x:auto}}.none{{background:var(--card);border:2px dashed var(--line);border-radius:14px;padding:20px;font-size:18px}}
@media(max-width:600px){{.meter{{grid-template-columns:1fr}}table{{font-size:13px}}.stack thead{{display:none}}.stack tr{{display:grid;padding-block:10px}}.stack td{{display:flow-root;border:0;padding:3px 0;padding-inline-start:6.5em}}.stack td::before{{content:attr(data-l);float:inline-start;width:6em;margin-inline-start:-6.5em;font-weight:700}}}}
</style></head><body>
<header><h1>Dreams, after CONDUCT {N}</h1><p>Mega regions rebalanced and explorable (hidden pockets, secret ways, pin cards, boss themes), difficulty modes and day length, gangster Space. Everything you need, in one place.</p></header>
<nav>{''.join(f'<a href="#{i}" data-s="{i}">{t}</a>' for i,t in secs)}</nav>
<main>
<section id="s-progress"><div class="meter"><div class="big">{tot}%</div><div><div class="row"><i style="width:{tot}%"></i><b>{100-tot}% to go</b></div><p class="sub">Whole game done. Mega regions reached 88%, difficulty and day length are done. The total dipped because hazards/jumping/lava (C20) and The General Store (C21) now count at 0%; the systems already built average about 83%.</p></div></div>
<div class="bars">{abars}</div><h2>Every system</h2>{systab}</section>
<section id="s-guide">{guide}</section>
<section id="s-report">{report}</section>
<section id="s-notes">{tp}</section>
<section id="s-plan">{plan}</section>
<section id="s-art"><h2>Art prompts</h2><div class="none">No art prompts are needed. The image tool made every picture this round (Thornmother, Sun Colossus, gangster bosses, desert foes, casino guard, rail bot, boss cards, hidden-area kit, station kit, alien trees, stalls, cloud-stone cliffs, glass decals, firefly glows, Gloam NPC walks). The fuzzy-building redraws are next, in CONDUCT 5.</div></section>
</main>
<script>{{
const show=()=>{{const h=(location.hash||'#progress').slice(1);const id=document.getElementById('s-'+h)?h:'progress';document.querySelectorAll('section').forEach(s=>s.classList.toggle('on',s.id==='s-'+id));document.querySelectorAll('nav a').forEach(a=>a.classList.toggle('on',a.dataset.s===id));window.scrollTo(0,0)}};
addEventListener('hashchange',show);show();
for(const t of document.querySelectorAll('table')){{if(!t.classList.contains('stack'))t.classList.add('stack');const hs=[...t.rows[0].cells].map(c=>c.textContent);for(const r of [...t.rows].slice(1))[...r.cells].forEach((c,i)=>c.dataset.l=hs[i]||'')}}
}}</script></body></html>'''
open('/home/claude/pkg/index.html','w').write(page); print('ok',tot,len(page))
