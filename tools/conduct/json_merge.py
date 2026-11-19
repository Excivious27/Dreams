import json,subprocess,sys
def g(stage,p):
    try: return json.loads(subprocess.check_output(['git','show',f':{stage}:{p}']))
    except Exception: return None
def merge(b,o,t):
    if isinstance(o,dict) and isinstance(t,dict):
        b=b if isinstance(b,dict) else {}
        out=dict(o)
        for k,v in t.items():
            if k not in o: out[k]=v
            elif o[k]!=v:
                if b.get(k)==o[k]: out[k]=v
                elif b.get(k)==v: pass
                else: out[k]=merge(b.get(k),o[k],v)
        for k in list(out):
            if k in b and k not in t and o.get(k)==b[k]: del out[k]
        return out
    if isinstance(o,list) and isinstance(t,list):
        out=list(o)
        for x in t:
            if x not in out: out.append(x)
        return out
    return o
for p in sys.argv[1:]:
    b,o,t=g(1,p),g(2,p),g(3,p)
    head=subprocess.check_output(['git','show',f':2:{p}']).decode()
    ind=1 if head.startswith('{\n "') else (2 if head.startswith('{\n  "') else None)
    m=merge(b,o,t)
    with open(p,'w') as f:
        json.dump(m,f,indent=ind,ensure_ascii=False); f.write('\n')
    print(p,'ok')
