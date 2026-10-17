# -*- coding: utf-8 -*-
# 17.10.2026: тижневі знімки з текстами, прив'язаними до фактів проєкту (без грошових сум), final_message за шаблоном для ВСІХ тижнів.
import datetime as dt, re
import sim
from scen import S
from spec import *
import emit
from emit import q, js, ddmm

def num(x, nd=1):
    if x is None: return '—'
    s_ = ('%.*f' % (nd, x)).rstrip('0').rstrip('.')
    return s_
def final_message(p, sn, sm):
    """Шаблон з WR: Build WR Prompt (docs/WEEKLY_REPORT_FORM.md §1): без грошових сум, дати ДД.ММ.РРРР."""
    w = sn['w']; stl = [s for s in STAGES if s in sn['rd']]
    end = sim.wk(w) + dt.timedelta(days=6)
    L = []
    L.append('Рентабельність_Total: план %s%% / прогноз %s' % (num(sm['rent_plan']), '—' if sm['rent_fc'] is None else num(sm['rent_fc']) + '%'))
    L.append('ETC_Total: план %sг / факт %sг / прогноз %s' % (num(sum(sim.planh(p, s) for s in stl)), num(sm['etc_fact']), '—' if sm['etc'] is None else num(sm['etc']) + 'г'))
    L.append('')
    avg = round(sum(sn['rd'][s] for s in stl) / len(stl))
    L.append('<b>1. Готовність (%%)_Total</b>: прогноз %s%%' % avg)
    for s in STAGES:
        if s not in sn['rd']: continue
        i = STAGES.index(s) + 1; r = sn['rd'][s]
        if r >= 100: L.append('1.%d. Стадія %s: 🟢' % (i, s)); continue
        L.append('1.%d. Стадія %s: прогноз %s%%' % (i, s, r))
        A = sim.H(p, s, w); pl = sim.planh(p, s)
        L.append('1.%d.1. ETC_Стадія %s: план %sг / факт %sг / прогноз %s' % (i, s, num(pl), num(pl - A), ('—' if s not in sn['etc'] else num(sn['etc'][s]) + 'г')))
        plan_d = ddmm(p['sched'][s][0].isoformat()) if s in p['sched'] else '—'
        L.append('1.%d.2. Дедлайн %s: план %s / прогноз %s' % (i, s, plan_d, ddmm(sn['dl'][s])))
        if s in sn['gap']: L.append('⚖️ Готовність не збігається з годинами: ПМ %s%% / за годинами %s%%' % (sn['gap'][s]['pm'], sn['gap'][s]['hours']))
    L.append('')
    L.append('<b>2. Акти</b>')
    for s in STAGES:
        if s not in sn['rd']: continue
        i = STAGES.index(s) + 1
        if s in p.get('acts', {}) and p['acts'][s] <= end: L.append('2.%d. Стадія %s: ✅ (підписаний)' % (i, s))
        elif s in p.get('acts', {}): L.append('2.%d. Стадія %s: %s / %s/10' % (i, s, ddmm(p['acts'][s].isoformat()), sn['ap']))
        elif s in p['sched']: L.append('2.%d. Стадія %s: %s / %s/10' % (i, s, ddmm(p['sched'][s][1].isoformat()), sn['ap']))
        else: L.append('2.%d. Стадія %s: —' % (i, s))
    L.append('2.5. Ймовірність видачі документації (оцінка ПМ): %s/10' % sn['dp'])
    L.append('')
    L.append('<b>3. КОМЕНТАРІ ПМ</b>'); L.append('1. ' + sn['comment'])
    L.append('')
    L.append('<b>4. ПРОБЛЕМИ</b>')
    k = 0
    if sn['bl'] and sn['bl'].get('types'):
        k += 1; L.append('%d. ⛔ Блокер з %s: %s — %s' % (k, ddmm(sn['bl']['since']), ', '.join(sn['bl']['types']), sn['bl'].get('need') or '—'))
    for x in sn['problems'].split('\n'):
        k += 1; L.append('%d. %s' % (k, x))
    L.append('')
    L.append('<b>5. ДОПОМОГА</b>')
    L.append('(не потрібно)' if sn['help'].lower().startswith('не потрібна') else '1. ' + sn['help'])
    L.append('')
    L.append('<b>6. ПЛАН НА ТИЖДЕНЬ</b>')
    for j, x in enumerate(sn['plans'].split('\n'), 1):
        L.append(x if x.startswith('🔴') else '%d. %s' % (j, x))
    return '\n'.join(L)

def week_sum(p, sn):
    w = sn['w']; stl = list(sn['rd'].keys())
    C = sum(p['contract'].values()); bac = sum(p['team'].values()) + sum(p['sub'].values()); bacsub = sum(p['sub'].values())
    A = {s: sim.H(p, s, w) for s in stl}
    hc = sum(A[s] * sim.cph(p, s) for s in stl)
    end = sim.wk(w) + dt.timedelta(days=6)
    subpaid = sum(r[4] for r in sim.money_rows(p) if r[5] == 'оплата_субпідряднику' and r[1] <= end)
    AC = hc + subpaid
    etc_ok = all(s in sn['etc'] for s in stl)
    tot = sum(sn['etc'][s] for s in stl) if etc_ok else None
    out = dict(rent_plan=round((C - bac) / C * 100, 1), etc_fact=round(sum(sim.planh(p, s) - A[s] for s in stl)), etc=tot, rent_fc=None)
    if etc_ok: out['rent_fc'] = round((C - (AC + tot * p['rate'] + max(bacsub - subpaid, 0))) / C * 100, 1)
    return out
LIVE = {  # значення з живого archi_recalc (live SQL 17.10.2026) для останнього тижня — звіт має збігатися з Owner View
 'DEMO-01': (24.4, 260.1), 'DEMO-02': (None, 201.5), 'DEMO-03': (1.3, 497.7), 'DEMO-04': (25.8, 76.5), 'DEMO-05': (7.4, 979.5), 'DEMO-06': (9.3, 112.9),
 'DEMO-07': (-11.1, 404.3), 'DEMO-08': (21.8, 31.0), 'DEMO-09': (15.5, 344.5), 'DEMO-10': (16.3, 347.9), '22-24': (11.4, 307.2), '24-11': (15.1, 353.5), '24-52': (41.2, 2047.5)}
def sql_snaps():
    chunks = []
    cols = 'project_id, week_start, session_id, "готовність_pct", "залишок_прогноз_год", "ймовірність_акту", "ймовірність_документації", plans_next_week, problems, help_needed, pm_comment, final_message, "залишок_прогноз_по_стадіях", "дедлайн_прогноз_по_стадіях", "блокер", "розбіжність_готовності", created_at'
    upd = ", ".join('%s = EXCLUDED.%s' % (c.strip(), c.strip()) for c in cols.split(',') if c.strip() not in ('project_id', 'week_start'))
    for p in S:
        sns = sim.snapshots(p)
        if not sns: continue
        vals = []
        for sn in sns:
            etc = sn['etc']; stl = list(sn['rd'].keys())
            tot = sum(etc[s] for s in stl) if all(s in etc for s in stl) else None
            sm = week_sum(p, sn)
            if sn is sns[-1] and p['id'] in LIVE: sm['rent_fc'], sm['etc_fact'] = LIVE[p['id']]
            fm = final_message(p, sn, sm) if (sn is sns[-1] or p['id'] == 'DEMO-01') else None
            vals.append("(%s,'%s','304884647',%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'%sT10:00:00+00')" % (
                q(p['id']), sn['week'], js(sn['rd']), 'NULL' if tot is None else tot, sn['ap'], sn['dp'], q(sn['plans']), q(sn['problems']), q(sn['help']), q(sn['comment']), q(fm),
                js(etc), js(sn['dl']), js(sn['bl']) if sn['bl'] is not None else 'NULL', js(sn['gap']) if sn['gap'] else 'NULL',
                (dt.date.fromisoformat(sn['week']) + dt.timedelta(days=4)).isoformat()))
        chunks.append((p['id'], "insert into public.wr_weekly_snapshots(%s) values\n%s\non conflict (project_id, week_start) do update set %s;\n" % (cols, ",\n".join(vals), upd)))
    return chunks
def sql_items(only=None):
    vals = []; keys = set()
    for p in S:
        if only and p['id'] != only: continue
        tags = p['tag']
        sns_ = sim.snapshots(p)
        for idx, sn in enumerate(sns_):
            nxt = (dt.date.fromisoformat(sn['week']) + dt.timedelta(days=7)).isoformat()
            nxt_sn = sns_[idx + 1] if idx + 1 < len(sns_) else None
            for k, line in enumerate(sn['plans'].split('\n'), 1):
                text = re.sub(r'^🔴 \d+: ', '', line)
                if sn['w'] == 7: stt = 'pending'
                else:
                    stt = 'not_done' if (k == 1 and nxt_sn and nxt_sn.get('carried')) else 'done'
                vals.append("(%s,'%s',%s,%s,'%s')" % (q(p['id']), nxt, k, q(text), stt))
    return ("insert into public.wr_plan_items(project_id, week_start, item_number, item_text, status) values\n" + ",\n".join(vals) +
            "\non conflict (project_id, week_start, item_number) do update set item_text=EXCLUDED.item_text, status=EXCLUDED.status;\n")
def sql_items_project(pid):
    pre = "update public.wr_plan_items set project_id = 'ARCH-' || project_id where project_id = %s and week_start between date '2026-09-07' and date '2026-10-19';\n" % q(pid)
    return pre + sql_items(pid)
if __name__ == '__main__':
    import os
    O = '../out/'
    for pid, t in sql_snaps(): open(O + '05_snap_%s.sql' % pid.replace('-', '_'), 'w').write(t)
    open(O + '06_items.sql', 'w').write(sql_items())
    for p in S:
        if sim.snapshots(p): open(O + '06_items_%s.sql' % p['id'].replace('-', '_'), 'w').write(sql_items_project(p['id']))
    for f in sorted(os.listdir(O)):
        if f.startswith('05_') or f.startswith('06_'): print(f, os.path.getsize(O + f))
