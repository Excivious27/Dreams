#!/usr/bin/env python3
"""Build Tom's CONDUCT package: python3 tools/package/build_package.py <N> [outdir]
N like 10b. Reads docs/reports/CONDUCT-<N>.md, the latest docs/guides/GUIDE-*.md,
docs/inventory.csv, tools/package/plan.md (+ docs/TOM-PLAYTEST-2026-11-19.md) and writes
<outdir>/Dreams-Progress-CONDUCT-<N>.xlsx and <outdir>/index.html (outdir default /home/claude/pkg).
Per-round words: TEXTS[N] if present, else taken from the report's first paragraph.
Timing extras ("CI first-run result", "CI minutes", "agents per effort", "images used",
"ACE credits used") get a Timing tab when the report's timing table carries them."""
import csv, html, os, re, sys, datetime
import markdown, openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

D=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
N=sys.argv[1]; OUT=sys.argv[2] if len(sys.argv)>2 else '/home/claude/pkg'
os.makedirs(OUT,exist_ok=True)
REPORT=f'{D}/docs/reports/CONDUCT-{N}.md'
GUIDE=max((f for f in os.listdir(f'{D}/docs/guides') if re.fullmatch(r'GUIDE-\d+\.md',f)),key=lambda f:int(f[6:-3]))
GNUM=GUIDE[6:-3]; GUIDE=f'{D}/docs/guides/{GUIDE}'
PLAN=f'{D}/tools/package/plan.md'; TP=f'{D}/docs/TOM-PLAYTEST-2026-11-19.md'
rep=open(REPORT).read()
DATE=(re.search(r'\((\d{4}-\d\d-\d\d)\)',rep.splitlines()[0]) or [None,datetime.date.today().isoformat()])[1]

TEXTS={'10b':dict(blurb='Decor, part 2: restyle the farmhouse, decorate the yard, Tess the carpenter, the casino The Gilded Ace with its limits, and the wardrobe on every hero. Everything you need, in one place.',meter='Whole game done. Exteriors, yard decor, the casino, the wardrobe and decor shops moved up this round. Hazards/lava (C20), The General Store (C21) and the marina (C14) still count at 0% until they run.',art="No art prompts are needed. This round's pictures (outdoor decor, casino symbols, apparel, house parts) were made by Claude through the image tool: nothing for you to render.",overview='CONDUCT 10b finished decor: 61 farmhouse styles, yard decorating with 169 outdoor pieces, Tess the carpenter, the casino The Gilded Ace (every bet returns under 99%, limits on), the wardrobe on every hero, art fixes and real shop rotation. CI passed on c10b2. Systems for later CONDUCTs (C14, C20, C21) count at 0% until they run.',
  plan=[['C1','First 3 hours, both arcs','done'],['C2','Rec Center, arcade, community farm + your playtest notes','done'],['C3','Battle campaigns','done'],['C4','Mega regions + difficulty + day length','done'],['C5','Home-world look and feel','done'],['C6','Audio and music','done'],['C7','Story, quests, writing + dating/marriage','done'],['C8','Economy, progression, balance + Collections','done'],['C9','Release readiness','done'],['C10a','Decor and cosmetics (half 1)','done'],['C10b','Decor and cosmetics (half 2)','done'],['C11a','Ranching and livestock (half 1)','next'],['C11b','Ranching, trainable team animals (half 2)',''],['C12','Writing, story, dialogue (thorough)',''],['C13','Audio depth (alternate area/season soundtracks, full audit)',''],['C14','Aesthetic quality of the world',''],['C15','Seasons (festivals, holidays, seasonal content)',''],['C16','Progression and balance across 3 years',''],['C17','Multiplayer (versus/co-op, then your ~$4/month server)',''],['C18a','Cutscenes: Crystopia intro, story scenes',''],['C18b','Cutscenes: night and side-event scenes',''],['C19','Trading cards (packs, binder, trading, regions)',''],['C20','Hazards, jumping and flight, lava region, mine hazards',''],['C21','The General Store side arc',''],['C22','Polish pass + code cleanup',''],['C23','One consistent art direction',''],['End','Final package and artifact page','']],mins={'C1':'~240','C2':'~240','C3':'~188','C4':'~105 to merge','C5':'~95','C6':'~120','C7':'~200','C8':'~200','C9':'~220','C10a':'~190','C10b':'~280'}),
  '11a':dict(blurb="Ranching, part 1: 9 farm animals in both arcs, coops, barns, hutches, sties and beehives with tiers, feeding, grazing and the silo, goods with stars, babies and the incubator, the Ranching skill tree, team animals and overnight chores. Everything you need, in one place.",meter='Whole game done. Ranching (animals, homes, the Ranching tree, ranch goods, team animals, chores, ranch letters and shows) moved up this round. Hazards/lava (C20), The General Store (C21) and the marina (C14) still count at 0% until they run.',art="No art prompts are needed. This round's pictures (new animals and babies, team poses, coop/barn/hutch/sty/apiary tiers with snow and night looks, barn and coop pieces, product icons, stations, skill icons) were made by Claude through the image tool: nothing for you to render.",overview='CONDUCT 11a built ranching: 9 classic animals in both arcs, 5 homes with tiers plus the silo, grazing and hay, petting and friendship, goods with silver and gold stars, breeding with no gender checks and the incubator, rehoming to Tam\'s high pasture (never sold for meat), the 14th skill tree (Ranching), the Mayo Machine and Honey Extractor, team animals with lessons, overnight chores, Bramble, the Animal Show and Best Egg, and market stalls. Systems for later CONDUCTs (C14, C20, C21) count at 0% until they run.',
  plan=[['C1','First 3 hours, both arcs','done'],['C2','Rec Center, arcade, community farm + your playtest notes','done'],['C3','Battle campaigns','done'],['C4','Mega regions + difficulty + day length','done'],['C5','Home-world look and feel','done'],['C6','Audio and music','done'],['C7','Story, quests, writing + dating/marriage','done'],['C8','Economy, progression, balance + Collections','done'],['C9','Release readiness','done'],['C10a','Decor and cosmetics (half 1)','done'],['C10b','Decor and cosmetics (half 2)','done'],['C11a','Ranching and livestock (half 1)','done'],['C11b','Ranching, trainable team animals (half 2)','next'],['C12','Writing, story, dialogue (thorough)',''],['C13','Audio depth (alternate area/season soundtracks, full audit)',''],['C14','Aesthetic quality of the world',''],['C15','Seasons (festivals, holidays, seasonal content)',''],['C16','Progression and balance across 3 years',''],['C17','Multiplayer (versus/co-op, then your ~$4/month server)',''],['C18a','Cutscenes: Crystopia intro, story scenes',''],['C18b','Cutscenes: night and side-event scenes',''],['C19','Trading cards (packs, binder, trading, regions)',''],['C20','Hazards, jumping and flight, lava region, mine hazards',''],['C21','The General Store side arc',''],['C22','Polish pass + code cleanup',''],['C23','One consistent art direction',''],['End','Final package and artifact page','']],mins={'C1':'~240','C2':'~240','C3':'~188','C4':'~105 to merge','C5':'~95','C6':'~120','C7':'~200','C8':'~200','C9':'~220','C10a':'~190','C10b':'~280','C11a':'~200 + final CI'}),
  '12':dict(blurb='Writing, story and dialogue: story scenes that know your hero, choices that come back later, festival days on the plaza, a side-story list in your journal, letters from people in town that match what happened, and gift refusal messages. Everything you need, in one place.',meter='Whole game done. The penguin and gangster stories, side stories, festivals, villagers, dating, endings and letters moved up this round, plus three new writing rows. Hazards/lava (C20), The General Store (C21) and the marina (C14) still count at 0% until they run.',art='No art prompts are needed. This round was all writing: no pictures or music were made (0 images, 0 ACE credits).',overview='CONDUCT 12 was a writing pass over both arcs: 18 auditors found 379 issues, 7 fix packages and an integration pass fixed them. Story scenes know which hero you play, choices are answered later (tell the town, the crystal, the locket, crew loyalty), villagers talk about weather, time and festival days, the Quests tab lists side stories and the compass follows them, letters match who is in town, and gifts can be refused with a message. New checkers stop spoilers and style drift. Calls waiting: Juniper as a romance candidate, renaming the kid Pip.',
  plan=[['C1', 'First 3 hours, both arcs', 'done'], ['C2', 'Rec Center, arcade, community farm + your playtest notes', 'done'], ['C3', 'Battle campaigns', 'done'], ['C4', 'Mega regions + difficulty + day length', 'done'], ['C5', 'Home-world look and feel', 'done'], ['C6', 'Audio and music', 'done'], ['C7', 'Story, quests, writing + dating/marriage', 'done'], ['C8', 'Economy, progression, balance + Collections', 'done'], ['C9', 'Release readiness', 'done'], ['C10a', 'Decor and cosmetics (half 1)', 'done'], ['C10b', 'Decor and cosmetics (half 2)', 'done'], ['C11a', 'Ranching and livestock (half 1)', 'done'], ['C11b', 'Ranching, trainable team animals (half 2)', 'done'], ['S1', 'Steam prep (no account needed)', 'done'], ['C12', 'Writing, story, dialogue (thorough)', 'done'], ['C13', 'Audio depth (alternate area/season soundtracks, full audit)', 'next'], ['C14', 'Aesthetic quality of the world', ''], ['C15', 'Seasons (festivals, holidays, seasonal content)', ''], ['C16', 'Progression and balance across 3 years', ''], ['C17', 'Multiplayer (versus/co-op, then your ~$4/month server)', ''], ['C18a', 'Cutscenes: Crystopia intro, story scenes', ''], ['C18b', 'Cutscenes: night and side-event scenes', ''], ['C19', 'Trading cards (packs, binder, trading, regions)', ''], ['C20', 'Hazards, jumping and flight, lava region, mine hazards', ''], ['C21', 'The General Store side arc', ''], ['C22', 'Polish pass + code cleanup', ''], ['C23', 'One consistent art direction', ''], ['End', 'Final package and artifact page', '']],mins={'C1': '~240', 'C2': '~240', 'C3': '~188', 'C4': '~105 to merge', 'C5': '~95', 'C6': '~120', 'C7': '~200', 'C8': '~200', 'C9': '~220', 'C10a': '~190', 'C10b': '~280', 'C11a': '~200 + final CI', 'C11b': '~485 wall clock', 'S1': '~200 wall clock', 'C12': '~150 wall clock + final CI'}),
  '13':dict(blurb='Audio depth: music that changes with the season, time of day, weather, weekday and story; the gangster arc gets its own farm, town and valley songs, jingles and menu sounds; a song for every festival, the casino, the museum and the crew venues; story mood songs; and new sound options (mono, softer loud sounds, captions, separate sliders). Everything you need, in one place.',meter='Whole game done. Seven new audio rows this round: music resolver, song library, jingles, sound effects, ambience, audio accessibility and co-op audio. Hazards/lava (C20), The General Store (C21) and the marina (C14) still count at 0% until they run.',art='No art prompts are needed. This round was all sound: 140 new or replaced songs, 20 jingles and a gang menu kit (ACE Music, 380 credits, 64 left until Dec 1), 22 CC0 sound effects and 0 images.',overview='CONDUCT 13 was an audio pass over both arcs: 18 auditors found 398 issues, and 6 fix packages plus a hook integration pass fixed them. One song resolver picks by arc, season, time of day, weather, weekday and story, with daily takes. The gangster arc has its own songs, jingles and UI sounds. Every festival, interior and crew venue has a song, and so do the story moods and the final bosses. Options gained mono, reduce loud sounds, captions and Voices/UI/Footsteps sliders. Every room has a background sound, and co-op has join and leave sounds. No new calls for Tom.',
  plan=[['C1', 'First 3 hours, both arcs', 'done'], ['C2', 'Rec Center, arcade, community farm + your playtest notes', 'done'], ['C3', 'Battle campaigns', 'done'], ['C4', 'Mega regions + difficulty + day length', 'done'], ['C5', 'Home-world look and feel', 'done'], ['C6', 'Audio and music', 'done'], ['C7', 'Story, quests, writing + dating/marriage', 'done'], ['C8', 'Economy, progression, balance + Collections', 'done'], ['C9', 'Release readiness', 'done'], ['C10a', 'Decor and cosmetics (half 1)', 'done'], ['C10b', 'Decor and cosmetics (half 2)', 'done'], ['C11a', 'Ranching and livestock (half 1)', 'done'], ['C11b', 'Ranching, trainable team animals (half 2)', 'done'], ['S1', 'Steam prep (no account needed)', 'done'], ['C12', 'Writing, story, dialogue (thorough)', 'done'], ['C13', 'Audio depth (alternate area/season soundtracks, full audit)', 'done'], ['C14', 'Aesthetic quality of the world', 'next'], ['C15', 'Seasons (festivals, holidays, seasonal content)', ''], ['C16', 'Progression and balance across 3 years', ''], ['C17', 'Multiplayer (versus/co-op, then your ~$4/month server)', ''], ['C18a', 'Cutscenes: Crystopia intro, story scenes', ''], ['C18b', 'Cutscenes: night and side-event scenes', ''], ['C19', 'Trading cards (packs, binder, trading, regions)', ''], ['C20', 'Hazards, jumping and flight, lava region, mine hazards', ''], ['C21', 'The General Store side arc', ''], ['C22', 'Polish pass + code cleanup', ''], ['C23', 'One consistent art direction', ''], ['End', 'Final package and artifact page', '']],mins={'C1': '~240', 'C2': '~240', 'C3': '~188', 'C4': '~105 to merge', 'C5': '~95', 'C6': '~120', 'C7': '~200', 'C8': '~200', 'C9': '~220', 'C10a': '~190', 'C10b': '~280', 'C11a': '~200 + final CI', 'C11b': '~485 wall clock', 'S1': '~200 wall clock', 'C12': '~150 wall clock + final CI', 'C13': '~120 wall clock + final CI'}),
  'S1':dict(blurb="Steam prep: Windows and Linux builds, 60 achievements, Steam Deck screens and controller play, desktop window options, Steam co-op, store text and pictures, and a one-session list for the day your Steamworks account is ready. Everything you need, in one place.",meter='Whole game done. Steam readiness: 92% done, 4% staged waiting on your Steamworks account, 4% not started. The phone/web game is unchanged. Hazards/lava (C20), The General Store (C21) and the marina (C14) still count at 0% until they run.',art="No art prompts are needed. This round's pictures (60 achievement badges, Steam capsules, library art, logo and app icon) were made by Claude through the image tool: nothing for you to render.",overview='CONDUCT S1 got Dreams ready for Steam as far as it can go without the account: Windows and Linux builds in CI with boot tests, GodotSteam behind a safe service, 60 achievements with a title-screen list, rich presence, a Steam co-op transport, Deck readability and controller typing, desktop window options, a Steam Input draft, the upload pipeline (switched off), store text, capsule art, screenshots, a trailer job, ratings and AI disclosure drafts, a name check and docs/STEAM.md. Steam readiness 92% done / 4% staged / 4% not started. Decisions waiting: title, casino, studio name, price, uploader inbox.',
  plan=[['C1','First 3 hours, both arcs','done'],['C2','Rec Center, arcade, community farm + your playtest notes','done'],['C3','Battle campaigns','done'],['C4','Mega regions + difficulty + day length','done'],['C5','Home-world look and feel','done'],['C6','Audio and music','done'],['C7','Story, quests, writing + dating/marriage','done'],['C8','Economy, progression, balance + Collections','done'],['C9','Release readiness','done'],['C10a','Decor and cosmetics (half 1)','done'],['C10b','Decor and cosmetics (half 2)','done'],['C11a','Ranching and livestock (half 1)','done'],['C11b','Ranching, trainable team animals (half 2)','done'],['S1','Steam prep (no account needed)','done'],['C12','Writing, story, dialogue (thorough)','next'],['C13','Audio depth (alternate area/season soundtracks, full audit)',''],['C14','Aesthetic quality of the world',''],['C15','Seasons (festivals, holidays, seasonal content)',''],['C16','Progression and balance across 3 years',''],['C17','Multiplayer (versus/co-op, then your ~$4/month server)',''],['C18a','Cutscenes: Crystopia intro, story scenes',''],['C18b','Cutscenes: night and side-event scenes',''],['C19','Trading cards (packs, binder, trading, regions)',''],['C20','Hazards, jumping and flight, lava region, mine hazards',''],['C21','The General Store side arc',''],['C22','Polish pass + code cleanup',''],['C23','One consistent art direction',''],['End','Final package and artifact page','']],mins={'C1':'~240','C2':'~240','C3':'~188','C4':'~105 to merge','C5':'~95','C6':'~120','C7':'~200','C8':'~200','C9':'~220','C10a':'~190','C10b':'~280','C11a':'~200 + final CI','C11b':'~485 wall clock','S1':'~200 wall clock'},steam=dict(done=92,staged=4,todo=4,rows=[['01','Windows/Linux builds, CI, sizes, boot test','done','',100],['02','GodotSteam + SteamService, safe no-ops','done','live test with the real App ID',90],['03','Achievements, part A','done','entry in Steamworks',90],['04','Achievements, part B + title list + icons','done','icon upload',90],['05','Backend switch, cloud paths, rich presence','done','Auto-Cloud + presence upload',90],['06','Steam co-op transport','done in code (fake Steam tests)','two-account live test; physics interpolation not started',75],['07','Deck readability','done','',100],['08','Controller-only + Steam keyboard','done (word prompts)','Deck keyboard check; icon glyphs not started',85],['09','Steam Input config + perf','done (Deck perf ok)','official config + Deck review',90],['10','Desktop window/display','done','',100],['11','Upload pipeline','done, switched off','builder account + secrets',90],['12','Store text','drafts','',95],['13','Ratings + AI disclosure','drafts','casino decision (Tom)',90],['14','Capsule art','12 assets','logo after the title pick',95],['15','Screenshots + trailer','11 screenshots, trailer job','trailer not rendered yet',80],['16','Name check','7 alternatives','title pick (Tom)',90],['17','Steamworks handoff brief','docs/STEAM.md','',100],['18','Web build safety','guard + web-export job','',100]])),
  '11b':dict(blurb="Ranching, part 2: 32 new creatures (exotics in both arcs, fantastic creatures in the penguin arc, lab strains in the gangster arc), new homes, creatures you earn, the Gene Splicer, animal shows with ribbons and medals, helper chores with fair limits, deeper team animals, and a fixed battle training. Everything you need, in one place.",meter='Whole game done. Ranching (creatures, homes, gifts, shows, breeding, voices), helper automation, team animals and battle training moved up this round. Hazards/lava (C20), The General Store (C21) and the marina (C14) still count at 0% until they run.',art="No art prompts are needed. This round's pictures (32 new creatures with babies, rare looks and team poses, new homes with snow and night looks, gangster coop and barn looks, goods and UI icons, stations, ribbons, chore icons) were made by Claude through the image tool: nothing for you to render.",overview='CONDUCT 11b finished ranching: 8 exotics in both arcs (sold by Hazel, Tam and Posy once the right home is built), 16 fantastic creatures in the penguin arc and 8 lab strains in the gangster arc (made at the new Gene Splicer), creatures earned from colonies, mega region jobs, bosses, the Moon, heart gifts and side stories, new homes (Exotic Enclosure, Aviary, Terrarium, Tide Pool, Ember Pit, Star Dome, Grand Barn), animal shows with ribbons, a trophy and medals, breeding with named rare looks and family lines, helper chores with spots and a nightly cap, CHECK and lessons for team animals, a voice for every creature, and a battle training you can always leave. Systems for later CONDUCTs (C14, C20, C21) count at 0% until they run.',
  plan=[['C1','First 3 hours, both arcs','done'],['C2','Rec Center, arcade, community farm + your playtest notes','done'],['C3','Battle campaigns','done'],['C4','Mega regions + difficulty + day length','done'],['C5','Home-world look and feel','done'],['C6','Audio and music','done'],['C7','Story, quests, writing + dating/marriage','done'],['C8','Economy, progression, balance + Collections','done'],['C9','Release readiness','done'],['C10a','Decor and cosmetics (half 1)','done'],['C10b','Decor and cosmetics (half 2)','done'],['C11a','Ranching and livestock (half 1)','done'],['C11b','Ranching, trainable team animals (half 2)','done'],['S1','Steam prep (no account needed)','next'],['C12','Writing, story, dialogue (thorough)',''],['C13','Audio depth (alternate area/season soundtracks, full audit)',''],['C14','Aesthetic quality of the world',''],['C15','Seasons (festivals, holidays, seasonal content)',''],['C16','Progression and balance across 3 years',''],['C17','Multiplayer (versus/co-op, then your ~$4/month server)',''],['C18a','Cutscenes: Crystopia intro, story scenes',''],['C18b','Cutscenes: night and side-event scenes',''],['C19','Trading cards (packs, binder, trading, regions)',''],['C20','Hazards, jumping and flight, lava region, mine hazards',''],['C21','The General Store side arc',''],['C22','Polish pass + code cleanup',''],['C23','One consistent art direction',''],['End','Final package and artifact page','']],mins={'C1':'~240','C2':'~240','C3':'~188','C4':'~105 to merge','C5':'~95','C6':'~120','C7':'~200','C8':'~200','C9':'~220','C10a':'~190','C10b':'~280','C11a':'~200 + final CI','C11b':'~485 wall clock'})}
def _first_para():
    for b in rep.split('\n\n')[1:]:
        if b.strip() and not b.startswith('#'): return re.sub(r'\*\*','',b.strip())
    return ''
T=dict(TEXTS.get(N,{}))
T.setdefault('blurb',_first_para()); T.setdefault('meter','Whole game done.')
T.setdefault('art','No art prompts are needed this round.'); T.setdefault('overview',_first_para())

def mdtable(text,sec):
    if sec not in text: return [],[]
    out=[]
    for l in text.split(sec,1)[1].splitlines():
        if l.startswith('|') and not l.startswith('|---'): out.append([c.strip() for c in l.strip('|').split('|')])
        elif out and not l.startswith('|'): break
    return (out[0],out[1:]) if out else ([],[])
if 'plan' not in T:
    pr_=[r for r in mdtable(open(PLAN).read(),'## The plan')[1]]
    lab=lambda c:('C'+c) if c[:1].isdigit() else c.capitalize()
    T['plan']=[[lab(r[0]),r[1],r[2] if len(r)>2 else ''] for r in pr_]
    T['mins']={}

inv=[r for r in csv.reader(open(f'{D}/docs/inventory.csv'))]
sysrows=[]
for r in inv[1:]:
    if r and r[0]=='Outstanding': break
    if len(r)>3 and r[3].strip().isdigit(): sysrows.append(r)

def build_page():
    rows=sysrows
    tot=round(sum(int(r[3]) for r in rows)/len(rows))
    areas={}
    for r in rows: areas.setdefault(r[0],[]).append(int(r[3]))
    abars=''.join(f'<div class="bar"><span class="l">{html.escape(a)}</span><span class="t"><i style="width:{round(sum(v)/len(v))}%"></i></span><span class="n">{round(sum(v)/len(v))}%</span></div>' for a,v in sorted(areas.items(),key=lambda x:-sum(x[1])/len(x[1])))
    st={'done':'ok','rough':'mid','missing':'no'}
    systab='<div class="scroll"><table class="stack"><thead><tr><th>Area</th><th>System</th><th>Status</th><th>Done</th><th>Left</th><th>Notes</th></tr></thead><tbody>'+''.join(f'<tr><td>{html.escape(r[0])}</td><td>{html.escape(r[1])}</td><td class="{st.get(r[2],"")}">{r[2]}</td><td class="num">{r[3]}%</td><td class="num">{100-int(r[3])}%</td><td>{html.escape(r[5])}</td></tr>' for r in rows)+'</tbody></table></div>'
    md=lambda p: markdown.markdown(open(p).read(),extensions=['tables'])
    guide=md(GUIDE); report=md(REPORT); plan=md(PLAN); tp=md(TP) if os.path.exists(TP) else ''
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
<header><h1>Dreams, after CONDUCT {N}</h1><p>{T['blurb']}</p></header>
<nav>{''.join(f'<a href="#{i}" data-s="{i}">{t}</a>' for i,t in secs)}</nav>
<main>
<section id="s-progress"><div class="meter"><div class="big">{tot}%</div><div><div class="row"><i style="width:{tot}%"></i><b>{100-tot}% to go</b></div><p class="sub">{T['meter']}</p></div></div>
<div class="bars">{abars}</div><h2>Every system</h2>{systab}</section>
<section id="s-guide">{guide}</section>
<section id="s-report">{report}</section>
<section id="s-notes">{tp}</section>
<section id="s-plan">{plan}</section>
<section id="s-art"><h2>Art prompts</h2><div class="none">{T['art']}</div></section>
</main>
<script>{{
const show=()=>{{const h=(location.hash||'#progress').slice(1);const id=document.getElementById('s-'+h)?h:'progress';document.querySelectorAll('section').forEach(s=>s.classList.toggle('on',s.id==='s-'+id));document.querySelectorAll('nav a').forEach(a=>a.classList.toggle('on',a.dataset.s===id));window.scrollTo(0,0)}};
addEventListener('hashchange',show);show();
for(const t of document.querySelectorAll('table')){{if(!t.classList.contains('stack'))t.classList.add('stack');const hs=[...t.rows[0].cells].map(c=>c.textContent);for(const r of [...t.rows].slice(1))[...r.cells].forEach((c,i)=>c.dataset.l=hs[i]||'')}}
}}</script></body></html>'''
    open(f'{OUT}/index.html','w').write(page); print('page ok',tot,len(page))

H=Font(name='Arial',bold=True,color='FFFFFF'); HF=PatternFill('solid',fgColor='5B3A29')
NF=Font(name='Arial',size=10); B=Font(name='Arial',size=10,bold=True); TF=Font(name='Arial',size=14,bold=True)
W=Alignment(wrap_text=True,vertical='top'); thin=Side(style='thin',color='D9C7A8')
def sheet(ws,headers,rows,widths,title=None):
    r0=1
    if title: ws.cell(1,1,title).font=TF; r0=3
    for c,h in enumerate(headers,1):
        x=ws.cell(r0,c,h); x.font=H; x.fill=HF; x.alignment=W
    for i,row in enumerate(rows,r0+1):
        for c,v in enumerate(row,1):
            x=ws.cell(i,c,v); x.font=NF; x.alignment=W; x.border=Border(bottom=thin)
    for c,w in enumerate(widths,1): ws.column_dimensions[get_column_letter(c)].width=w
    ws.freeze_panes=ws.cell(r0+1,1)
    return r0

TIMING_EXTRAS=['CI first-run result','CI minutes','agents per effort','images used','ACE credits used']
def build_xlsx():
    wb=openpyxl.Workbook()
    ws=wb.active; ws.title='Overview'
    s2=wb.create_sheet('Systems')
    rows=[[r[0],r[1],r[2],int(r[3])/100,None,r[4],r[5]] for r in sysrows]
    r0=sheet(s2,['Area','System / feature','Status','% done','% remaining','Tests','Notes'],rows,[12,48,10,9,11,34,60])
    for i in range(r0+1,r0+1+len(rows)):
        s2.cell(i,4).number_format='0%'; s2.cell(i,5,f'=1-D{i}').number_format='0%'; s2.cell(i,5).font=NF
    last=r0+len(rows)
    ws.cell(1,1,f'Dreams: progress after CONDUCT {N} ({DATE})').font=TF
    ws.cell(3,1,'Whole game % done').font=B; ws.cell(3,2,f"=AVERAGE(Systems!D{r0+1}:D{last})").number_format='0%'
    ws.cell(4,1,'Whole game % remaining').font=B; ws.cell(4,2,'=1-B3').number_format='0%'
    ws.cell(5,1,'Note').font=B; ws.cell(5,2,T['overview']).alignment=W
    areas=sorted(set(r[0] for r in sysrows))
    for c,h in enumerate(['Area','% done','% remaining','Systems'],1):
        ws.cell(7,c,h).font=H; ws.cell(7,c).fill=HF
    for i,a in enumerate(areas,8):
        ws.cell(i,1,a).font=NF
        ws.cell(i,2,f'=AVERAGEIF(Systems!A{r0+1}:A{last},A{i},Systems!D{r0+1}:D{last})').number_format='0%'
        ws.cell(i,3,f'=1-B{i}').number_format='0%'
        ws.cell(i,4,f'=COUNTIF(Systems!A{r0+1}:A{last},A{i})')
    if 'steam' in T:
        st_=T['steam']; ws.cell(6,1,'Steam readiness').font=B
        ws.cell(6,2,f"done {st_['done']}% / staged (waiting on the account) {st_['staged']}% / not started {st_['todo']}%").alignment=W
    for k,w in zip('ABCD',[26,70,12,10]): ws.column_dimensions[k].width=w
    ws.freeze_panes='A8'
    h1,r1=mdtable(rep,'## Audit'); h2,r2=mdtable(rep,'## Fix packages')
    s3=wb.create_sheet(f'CONDUCT {N}')
    sheet(s3,['Area / package','Found / fixed'],[[x[0],x[1]] for x in r1]+[['','']]+[[x[0],x[1]] for x in r2],[34,120],f'CONDUCT {N}: audit findings, then fix packages')
    g=open(GUIDE).read(); items=[]; sec=''
    for l in g.splitlines():
        if l.startswith('## '): sec=l[3:]
        m=re.match(r'^(\d+)\. (.*)',l)
        if m and not sec.startswith('What to test') and not sec.startswith('Already'): items.append([int(m.group(1)),sec,re.sub(r'\*\*','',m.group(2))])
    s4=wb.create_sheet('Still needed from Tom')
    sheet(s4,['#','Group','Question (default runs until you answer)','Your answer'],[[a,b,c,''] for a,b,c in items],[5,30,90,30],f'Still needed from Tom (Guide {GNUM})')
    for i in range(4,4+len(items)): s4.cell(i,4).fill=PatternFill('solid',fgColor='FFF2A8')
    pr=[]
    if os.path.exists(TP):
        tp=open(TP).read()
        pr=[[c.strip() for c in l.strip('|').split('|')] for l in tp.splitlines() if l.startswith('| ') and not l.startswith('| #')]
        done={1,2,3,4,7,8,9,10,12,13,14,15,16,17,18,20,21}
        s5=wb.create_sheet('Your playtest notes')
        sheet(s5,['#','Note','Status','Where'],[[int(p[0]),p[1],'done (C2)' if int(p[0]) in done else 'started; continues',p[2]] for p in pr],[5,90,18,22],f'Your phone playtest notes ({len(pr)})')
    if 'steam' in T:
        st_=T['steam']; s8=wb.create_sheet('Steam readiness')
        r8=sheet(s8,['#','Spec item','Done','Staged / not started','% done','% remaining'],[[a,b,c,d,e/100,None] for a,b,c,d,e in st_['rows']],[5,44,30,46,9,11],f"Steam readiness: done {st_['done']}% / staged {st_['staged']}% / not started {st_['todo']}%")
        for i in range(r8+1,r8+1+len(st_['rows'])):
            s8.cell(i,5).number_format='0%'; s8.cell(i,6,f'=1-E{i}').number_format='0%'; s8.cell(i,6).font=NF
        n8=r8+len(st_['rows'])
        s8.cell(n8+1,2,'Overall (average)').font=B; s8.cell(n8+1,5,f'=AVERAGE(E{r8+1}:E{n8})').number_format='0%'; s8.cell(n8+1,6,f'=1-E{n8+1}').number_format='0%'
    s6=wb.create_sheet('Plan')
    plan=[r+[T['mins'].get(r[0],'')] for r in T['plan']]
    sheet(s6,['CONDUCT','Focus','Status','Minutes (all in)'],plan,[10,70,12,18],'The plan (target ~90 minutes each from C5)')
    # Timing extras: only when the report's timing table carries them
    th,tr=mdtable(rep,'## Timing')
    low=lambda s:re.sub(r'\*','',s).strip().lower()
    want=[x.lower() for x in TIMING_EXTRAS]
    if th and (any(low(h) in want for h in th) or any(r and low(r[0]) in want for r in tr)):
        s7=wb.create_sheet('Timing')
        sheet(s7,[re.sub(r'\*','',h) for h in th],[[re.sub(r'\*\*','',c) for c in r] for r in tr],[50]+[18]*(len(th)-1),f'CONDUCT {N}: timing')
    path=f'{OUT}/Dreams-Progress-CONDUCT-{N}.xlsx'; wb.save(path); print('xlsx ok',len(sysrows),len(items),len(pr))

build_xlsx(); build_page()
