# -*- coding: utf-8 -*-
import sim
from scen import S
from spec import *
def summarize(p):
    t = sim.time_rows(p); m = sim.money_rows(p); sn = sim.snapshots(p)
    C = sum(p['contract'].values()); bacteam = sum(p['team'].values()); bacsub = sum(p['sub'].values()); bac = bacteam + bacsub
    A = {s: sum(r[3] for r in t if r[1] == s) for s in sim.stages_of(p)}
    hrs_cost = sum(A[s] * sim.cph(p, s) for s in A)
    subpaid = sum(r[4] for r in m if r[5] == 'оплата_субпідряднику')
    AC = hrs_cost + subpaid
    acts = sum(r[4] for r in m if r[5] == 'акт_підписаний'); rec = sum(r[4] for r in m if r[5] == 'надходження_від_замовника')
    last = sn[-1] if sn else None
    out = dict(id=p['id'], scen=p['scen'], C=round(C), AC=round(AC), acts=round(acts), rec=round(rec), hrs=round(sum(A.values())))
    if last:
        stl = sim.stages_of(p)
        etc_ok = all(s in last['etc'] for s in stl)
        etc_tot = sum(last['etc'][s] for s in stl) if etc_ok else None
        pl = sum(sim.planh(p, s) for s in stl)
        pct = sum(last['rd'][s] / 100 * sim.planh(p, s) for s in stl) / pl
        out['pct'] = round(pct * 100, 1)
        out['cpi'] = round(bac * pct / AC, 2) if AC else None
        if etc_ok:
            cf = AC + etc_tot * p['rate'] + max(bacsub - subpaid, 0)
            out['etc'] = etc_tot; out['rent_fc'] = round((C - cf) / C * 100, 1)
        else: out['etc'] = None; out['rent_fc'] = None
        out['rent_plan'] = round((C - bac) / C * 100, 1)
        etcplan = sum(sim.planh(p, s) for s in stl); etcfact = sum(sim.planh(p, s) - A[s] for s in stl)
        out['etc_fact'] = round(etcfact); out['gap'] = list(last['gap'].keys()); out['bl'] = last['bl'] and last['bl'].get('types')
    out['unpaid%'] = round((AC - rec) / C * 100, 1); out['actlag%'] = round((AC - acts) / C * 100, 1)
    return out
if __name__ == '__main__':
    for p in S: print(summarize(p))
