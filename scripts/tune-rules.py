"""局の勝ち・負け・流局の割合を Python で試す（ルールと相手の強さの調整用）。使い方: python3 scripts/tune-rules.py"""
import random, sys, itertools
sys.path.insert(0,'.')
from kitchen_data import INGREDIENTS, BASE, PRO
ids=[i[0] for i in INGREDIENTS]; K=len(ids); idx={k:n for n,k in enumerate(ids)}
def check(rs):
    seen={}
    for r in rs:
        assert len(set(r[4]))==3, r[0]
        for x in r[4]: assert x in idx,(r[0],x)
        key=frozenset(r[4])
        assert key not in seen, (r[0], seen.get(key))
        seen[key]=r[0]
    assert len({r[0] for r in rs})==len(rs)
check(BASE+PRO)
print('base',len(BASE),'pro',len(PRO))
from collections import Counter
cnt=Counter(x for r in BASE for x in r[4]); print(sorted(cnt.items(), key=lambda a:a[1]))
def recipes(pro): return [tuple(sorted(idx[x] for x in r[4])) for r in (BASE+PRO if pro else BASE)]
def complete(c, R, byfirst):
    # c: list counts len K, total 14
    for p in range(K):
        if c[p]>=2:
            c[p]-=2
            ok=melds(c,4,byfirst)
            c[p]+=2
            if ok: return True
    return False
def melds(c,n,byfirst):
    if n==0: return True
    i=next((k for k in range(K) if c[k]>0),None)
    if i is None: return False
    if c[i]>=3:
        c[i]-=3; ok=melds(c,n-1,byfirst); c[i]+=3
        if ok: return True
    for r in byfirst[i]:
        if all(c[x]>0 for x in r):
            for x in r: c[x]-=1
            ok=melds(c,n-1,byfirst)
            for x in r: c[x]+=1
            if ok: return True
    return False
def mkbyfirst(R):
    b=[[] for _ in range(K)]
    for r in R: b[r[0]].append(r)
    return b
def score(c,t,R,inrec):
    s=4*(c[t]-1)
    for r in inrec[t]:
        k=sum(1 for x in r if x!=t and c[x]>0)
        s+= [0,2,6][k]
    return s
def discard(c,R,inrec,rng,careless):
    tiles=[k for k in range(K) if c[k]>0]
    if rng.random()<careless: return rng.choice(tiles)
    return min(tiles,key=lambda t:(score(c,t,R,inrec), -t))
def game(seed,careless=0.5,pro=False):
    rng=random.Random(seed); R=recipes(pro); bf=mkbyfirst(R)
    inrec=[[r for r in R if k in r] for k in range(K)]
    wall=[k for k in range(K) for _ in range(4)]; rng.shuffle(wall)
    hands=[[0]*K for _ in range(4)]
    for p in range(4):
        for _ in range(13): hands[p][wall.pop()]+=1
    turn=0; draws=0
    while wall:
        p=turn%4; h=hands[p]; t=wall.pop(); h[t]+=1; draws+=1
        if complete(h,R,bf): return ('you' if p==0 else 'cpu', draws)
        d=discard(h,R,inrec,rng, 0.0 if p==0 else careless); h[d]-=1
        if p!=0:
            hands[0][d]+=1
            if complete(hands[0],R,bf): hands[0][d]-=1; return ('ron',draws)
            hands[0][d]-=1
        turn+=1
    return ('draw',draws)
for care in [0.3,0.6]:
  for pro in [False,True]:
    res=Counter(); dr=[]
    for s in range(400):
        r,d=game(s,care,pro); res[r]+=1; dr.append(d)
    print(care,pro,dict(res), sum(dr)/len(dr))
