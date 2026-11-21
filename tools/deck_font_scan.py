#!/usr/bin/env python3
"""S1 P3 (s1_07-01): Steam Deck drawn-text floor. Fails when a draw_string /
draw_string_outline / draw_multiline_string call in scripts/ passes a literal
font size 5-7 instead of DisplayMode.df(n) (7 is 8.3 px cap at 1280x800, under
Valve 9 px). --write wraps them.  python3 tools/deck_font_scan.py [--write]"""
import re,sys,glob
FN={'draw_string(':5,'draw_string_outline(':5,'draw_multiline_string(':5,'draw_multiline_string_outline(':5}
def split_args(s,i):
    # s[i] is just after '('; return list of (start,end) arg spans and close index
    depth=0; spans=[]; st=i; j=i; instr=None
    while j<len(s):
        c=s[j]
        if instr:
            if c=='\\': j+=2; continue
            if c==instr: instr=None
        elif c in '"\'': instr=c
        elif c in '([{': depth+=1
        elif c in ')]}':
            if depth==0: spans.append((st,j)); return spans,j
            depth-=1
        elif c==',' and depth==0: spans.append((st,j)); st=j+1
        j+=1
    return None,None
tot=0; per={}
for f in sorted(glob.glob('scripts/*.gd')):
    s=open(f).read(); out=[]; pos=0; n=0
    for m in re.finditer(r'\b(draw_string_outline\(|draw_multiline_string_outline\(|draw_multiline_string\(|draw_string\()',s):
        if m.start()<pos: continue
        spans,close=split_args(s,m.end())
        if not spans or len(spans)<6: continue
        a,b=spans[5]; arg=s[a:b]
        if re.fullmatch(r'\s*[5-7]\s*',arg):
            lead=arg[:len(arg)-len(arg.lstrip())]
            out.append(s[pos:a]+lead+'DisplayMode.df(%s)'%arg.strip()); pos=b; n+=1
    if n:
        out.append(s[pos:]); 
        if '--write' in sys.argv: open(f,'w').write(''.join(out))
        per[f]=n; tot+=n
if '--write' in sys.argv:
    print('deck_font_scan: wrapped %d sizes %s' % (tot, per))
else:
    for f, n in per.items():
        print('  %s: %d draw_string size(s) 5-7 not through DisplayMode.df' % (f, n))
    print('deck_font_scan: %d unwrapped' % tot)
    sys.exit(1 if tot else 0)
