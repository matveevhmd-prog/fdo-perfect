# -*- coding: utf-8 -*-
import json, datetime as dt, hashlib
from scen import S
from spec import *
from texts import T, pick, GAP_NOTE
TODAY = D(2026, 10, 21)
def iso(d): return d.isoformat()
def mixof(p, s): return p['mixall'] if p.get('mixall') else MIX[s]
def cph(p, s): return sum(RATES[r] * f for r, f in mixof(p, s).items())
def planh(p, s): return p['hours'].get(s, 0) or 0
def H(p, s, w):
    pl = planh(p, s)
    if not pl: return 0.0
    pr = p['prog'].get(s, [0] * 8)[w]
    base = p['eff'].get(s, 1.0) * pl * pr / 100.0
    ex = sum(h for ww, h in p.get('extra', {}).get(s, {}).items() if ww <= w)
    return base + ex
def r05(x): return round(x * 2) / 2.0
def stages_of(p): return [s for s in STAGES if planh(p, s) > 0]

def time_rows(p):
    rows = []  # (pid, stage, date, hours)
    for s in stages_of(p):
        prev = 0.0
        for w in range(0, 8):
            cur = H(p, s, w); inc = cur - prev; prev = cur
            inc = r05(inc)
            if inc <= 0: continue
            if w == 0:
                ds = []; d = p['start']
                while d <= D(2026, 8, 28):
                    ds.append(d); d += dt.timedelta(days=7)
                ds = [x for x in ds if x.weekday() == 2] or [p['start'] + dt.timedelta(days=(2 - p['start'].weekday()) % 7)]
                ds = ds[-6:] if len(ds) > 6 else ds
                n = len(ds)
                parts = [r05(inc / n)] * n; parts[-1] = r05(inc - sum(parts[:-1]))
                for d, h in zip(ds, parts):
                    if h > 0: rows.append((p['id'], s, d, h))
            else:
                d = wk(w) + dt.timedelta(days=2)
                rows.append((p['id'], s, d, inc))
    return rows

def money_rows(p):
    C = sum(p['contract'].values())
    rows = []  # (pid, date, stage|None, counterparty|None, amount, type)
    if p.get('adv'):
        d, pct = p['adv']; rows.append((p['id'], d, None, 'Замовник', R2(C * pct), 'надходження_від_замовника'))
    for s, d in p.get('acts', {}).items():
        a = p['contract'][s]
        rows.append((p['id'], d, s, 'Замовник', R2(a), 'акт_підписаний'))
        if p.get('pay_ratio', 0) > 0:
            pd_ = d + dt.timedelta(days=p.get('pay_lag', 10))
            rows.append((p['id'], pd_, None, 'Замовник', R2(a * p['pay_ratio'] * (1 - (p['adv'][1] if p.get('adv') else 0))), 'надходження_від_замовника'))
    for d, pct in p.get('receipts_extra', []):
        rows.append((p['id'], d, None, 'Замовник', R2(C * pct), 'надходження_від_замовника'))
    for d, s, fr in p.get('subpay', []):
        rows.append((p['id'], d, s, SUBC, R2(p['sub'][s] * fr), 'оплата_субпідряднику'))
    return [r for r in rows if r[1] <= TODAY]
def R2(x): return round(x, 2)

def finish_week(p, s):
    pr = p['prog'].get(s, [0] * 8)
    for w in range(0, 8):
        if pr[w] >= 100: return w
    return None

def active_stage(p, w):
    for s in stages_of(p):
        if p['prog'].get(s, [0] * 8)[w] < 100: return s
    return stages_of(p)[-1]

def snapshots(p):
    out = []
    ws = p.get('weeks', list(range(1, 8)))
    st = stages_of(p)
    for w in ws:
        rd, etc, dl, gap = {}, {}, {}, {}
        for s in st:
            pr = p['prog'][s][w]
            b = p.get('bias', {}).get(s, [0] * 8)[w]
            r = 100 if pr >= 100 else max(0, min(99, round(pr + b)))
            rd[s] = r
            if (s, w) in p.get('noans', set()): pass
            elif r >= 100: etc[s] = 0
            else:
                rem = p['eff'].get(s, 1.0) * planh(p, s) * (1 - pr / 100.0)
                mode = p.get('etc_mode', {}).get(s)
                if mode and mode[0] == 'opt': rem *= mode[1]
                etc[s] = max(5, int(round(rem / 5.0) * 5))
            fw = finish_week(p, s)
            if r >= 100 and fw is not None and fw <= w and pr >= 100:
                d = wk(max(fw, 1)) + dt.timedelta(days=4) if fw >= 1 else p['dl_plan'][s] - dt.timedelta(days=10)
                dl[s] = iso(min(d, p['dl_plan'][s]) if fw == 0 else d)
            else:
                slip = p.get('dl_slip', {}).get(s)
                dl[s] = iso(p['dl_plan'][s] + dt.timedelta(days=(slip[w - 1] if slip else 0)))
            if r < 100 and s in etc:
                A = H(p, s, w); tot = A + etc[s]
                hp = A / tot * 100 if tot > 0 else None
                if hp is not None and abs(r - hp) >= 20: gap[s] = {'pm': r, 'hours': int(round(hp)), 'note': GAP_NOTE}
        tag = p['tag'][w - 1]
        t = T[tag]; S_ = active_stage(p, w)
        fmt = lambda x: x.replace('{S}', S_)
        problems = fmt(pick(t['problems'], p['id'], w, 'p'))
        help_ = fmt(pick(t['help'], p['id'], w, 'h'))
        plans = []
        for k in range(2 + (1 if w % 2 == 0 else 0)):
            x = fmt(t['plans'][(k + w + len(p['id'])) % len(t['plans'])])
            if x not in plans: plans.append(x)
        comment = fmt(pick(t['comment'], p['id'], w, 'c'))
        if ('Р', w) in p.get('noans', set()): problems = problems + '\n❓ Відповіді нема (ПМ): ETC Р'
        bl = None
        if w >= 2 or p.get('blocker', {}).get(w): bl = {'types': []}
        if p.get('blocker', {}).get(w):
            since, types = p['blocker'][w]
            bl = {'types': types, 'since': since, 'need': help_}
        ap = p['act_prob'][w - 1]; dp_ = p['doc_prob'][w - 1]
        out.append(dict(pid=p['id'], w=w, week=iso(wk(w)), rd=rd, etc=etc, dl=dl, gap=gap, ap=ap, dp=dp_, bl=bl,
                        plans='\n'.join(plans), problems=problems, help=help_, comment=comment, tag=tag, S=S_))
    return out
