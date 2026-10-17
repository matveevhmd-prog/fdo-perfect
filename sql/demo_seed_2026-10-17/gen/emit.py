# -*- coding: utf-8 -*-
import json, datetime as dt
import sim
from scen import S
from spec import *
from texts import T
def q(s): return 'NULL' if s is None else '$q$' + str(s) + '$q$'
def js(o): return "$j$" + json.dumps(o, ensure_ascii=False, separators=(',', ':')) + "$j$::jsonb"
DEMO = [p for p in S if p['id'].startswith('DEMO')]
ALL = [p['id'] for p in S]
TASK = {('МБР','Керівник проекту'):'ГП (Генеральний план)',('ЕП','Архітектор (сеньйор)'):'АР (Архітектурні рішення)',('ЕП','Головний конструктор'):'ГК - Головний Конструктор',('ЕП','ГІП'):'ГІП',
        ('П','Архітектор (юніор)'):'АР (Архітектурні рішення)',('П','Головний конструктор'):'КР (Конструктивні рішення)',('Р','Архітектор (юніор)'):'АР (Архітектурні рішення)',('Р','Головний конструктор'):'ПОБ - Проект організації будівництва'}
def task(s, r): return TASK.get((s, r), 'Проєктні роботи (' + s + ')')

def sql_archive():
    ids = ",".join("'%s'" % i for i in ALL + ['DEMO-05-АН'])
    return ("update public.time_log set \"статус\"='archived_20261017' where project_id in (%s) and \"статус\"='confirmed';\n"
            "update public.money_log set \"статус\"='archived_20261017' where project_id in (%s) and \"статус\"='confirmed';\n" % (ids, ids))

def sql_time():
    out = []
    groups = [S[:7], S[7:]]
    for grp in groups:
        rr = []; mx = []; seen_demo = set()
        for p in grp:
            rr += [{"pid": r[0], "st": r[1], "d": r[2].isoformat(), "h": r[3]} for r in sim.time_rows(p)]
            for s in sim.stages_of(p):
                for role, fr in sim.mixof(p, s).items():
                    if p['id'].startswith('DEMO'):
                        if (s, role) in seen_demo: continue
                        seen_demo.add((s, role)); mx.append(('DEMO', s, role, fr, task(s, role)))
                    else: mx.append((p['id'], s, role, fr, task(s, role)))
        vals = ",".join("(%s,%s,%s,%s,%s)" % (q(a), q(b), q(c), d, q(e)) for a, b, c, d, e in mx)
        out.append("insert into public.time_log(project_id,\"дата\",\"стадія\",\"виконавець\",\"завдання_розділ\",\"години\",\"статус\",source)\n"
                   "select r.pid, r.d::date, r.st, m.role, m.task, round(r.h*m.frac,1), 'confirmed', 'demo'\n"
                   "from jsonb_to_recordset($j$%s$j$::jsonb) as r(pid text, st text, d text, h numeric)\n"
                   "join (values %s) as m(pid, st, role, frac, task) on (m.pid=r.pid or (m.pid='DEMO' and r.pid like 'DEMO-%%')) and m.st=r.st;\n" % (json.dumps(rr, ensure_ascii=False, separators=(',', ':')), vals))
    return out

def sql_money():
    rows = []
    for p in S: rows += sim.money_rows(p)
    v = ",\n".join("(%s,'%s',%s,%s,%s,%s,'confirmed','demo')" % (q(r[0]), r[1].isoformat(), q(r[2]), q(r[3]), r[4], q(r[5])) for r in rows)
    return "insert into public.money_log(project_id,\"дата\",\"стадія\",\"контрагент\",\"сума\",\"тип\",\"статус\",source) values\n" + v + ";\n"

def plan_vals(p):
    C = sum(p['contract'].values()); team = sum(p['team'].values()); sub = sum(p['sub'].values()); bac = team + sub
    return dict(C=round(C, 2), team=round(team, 2), sub=round(sub, 2), bac=round(bac, 2), profit=round(C - bac, 2), rent=round((C - bac) / C * 1000) / 10 if False else round((C - bac) / C * 100, 1),
                hours=sum(p['hours'].values()), hs={s: p['hours'].get(s, 0) for s in STAGES})
def sql_plan():
    out = []
    for p in DEMO:
        v = plan_vals(p)
        hs = dict(v['hs']); hs['АН'] = 0
        out.append("update public.project_metrics set contract_amount=%s, cost_plan_team=%s, cost_plan_subcontract=%s, bac=%s, profit_plan=%s, profitability_plan_pct=%s, planned_hours=%s, planned_hours_by_stage=%s, etc_plan_by_stage=%s, real_rate_team_hour=%s where project_id=%s;" %
                   (v['C'], v['team'], v['sub'], v['bac'], v['profit'], v['rent'], v['hours'], js(hs), js(v['hs']), p['rate'], q(p['id'])))
    # графік оплат: оновлення за ключем (проєкт, стадія, подія)
    sv = []
    for p in S:
        for s, (docd, actd) in p['sched'].items():
            amt = round(p['contract'][s] * 1.2, 2)
            ap = p['act_prob'][-1] if p['act_prob'] else 6; dpp = p['doc_prob'][-1] if p['doc_prob'] else 6
            st_ = 'оплачено' if (s in p.get('acts', {}) and p.get('pay_ratio', 0) > 0) else 'заплановано'
            sv.append("(%s,%s,'акт','%s',%s,%s,%s)" % (q(p['id']), q(s), actd.isoformat(), amt, ap, q(st_)))
            sv.append("(%s,%s,'документація','%s',NULL,%s,NULL)" % (q(p['id']), q(s), docd.isoformat(), dpp))
    out.append("update public.payment_schedule ps set \"дата_план\"=v.d::date, \"сума_план\"=v.sm, \"ймовірність_план\"=v.pr, \"статус_план\"=v.stt from (values\n" + ",\n".join(sv) +
               "\n) as v(pid, st, ev, d, sm, pr, stt) where ps.project_id=v.pid and ps.\"стадія\"=v.st and ps.\"подія\"=v.ev;")
    return "\n".join(out) + "\n"


import report
def ddmm(iso): d = dt.date.fromisoformat(iso); return d.strftime('%d.%m.%Y')
def final_message(p, sn, sm):
    L = []
    L.append('📝 <b>Звіт ПМа · %s</b>' % p['id']); L.append('Тиждень з %s' % ddmm(sn['week'])); L.append('')
    L.append('<b>Рентабельність_Total</b>'); L.append('• План: %s%%' % str(sm['rent_plan']).replace('.', ','))
    L.append('• Прогноз: %s' % ('🔴 немає (ПМ не дав ETC)' if sm.get('rent_fc') is None else str(sm['rent_fc']).replace('.', ',') + '%'))
    L.append(''); L.append('⏱ <b>ETC_Total</b>')
    stl = list(sn['rd'].keys()); plan_h = sum(sim.planh(p, s) for s in stl)
    L.append('• План: %sг' % round(plan_h)); L.append('• Факт: %sг' % sm['etc_fact'])
    L.append('• Прогноз: %s' % ('—' if sm['etc'] is None else '%sг' % sm['etc']))
    L.append(''); L.append('<b>1. Готовність</b>')
    for s in stl:
        r = sn['rd'][s]
        if r >= 100: L.append('• %s: 🟢 100%%' % s); continue
        L.append('• %s: %s%%' % (s, r))
        A = sim.H(p, s, sn['w'])
        L.append('  ETC: план %sг / факт %sг / прогноз %s' % (round(sim.planh(p, s)), round(sim.planh(p, s) - A), ('❓ відповіді нема' if s not in sn['etc'] else '%sг' % sn['etc'][s])))
        L.append('  Дедлайн: план %s / прогноз %s' % (ddmm(iso_(p['dl_plan'][s])), ddmm(sn['dl'][s])))
        if s in sn['gap']: L.append('  ⚖️ Розбіжність: ПМ %s%% / за годинами %s%%' % (sn['gap'][s]['pm'], sn['gap'][s]['hours']))
    L.append(''); L.append('<b>2. Акти</b>')
    for s in stl:
        if s in p.get('acts', {}) and p['acts'][s] <= dt.date.fromisoformat(sn['week']) + dt.timedelta(days=6): L.append('• %s: ✅ підписаний' % s)
        elif s in p['sched']: L.append('• %s: %s · %s/10' % (s, ddmm(p['sched'][s][1].isoformat()), sn['ap']))
    L.append('• Ймовірність видачі документації: %s/10' % sn['dp'])
    L.append(''); L.append('<b>3. Коментарі ПМ</b>'); L.append(sn['comment'])
    L.append(''); L.append('<b>4. Проблеми</b>')
    if sn['bl'] and sn['bl'].get('types'): L.append('⛔ Блокер з %s: %s' % (ddmm(sn['bl']['since']), ', '.join(sn['bl']['types'])))
    for x in sn['problems'].split('\n'): L.append('• ' + x)
    L.append(''); L.append('<b>5. Допомога</b>'); L.append('• ' + sn['help'])
    L.append(''); L.append('<b>6. План на тиждень</b>')
    for x in sn['plans'].split('\n'): L.append('• ' + x)
    return '\n'.join(L)
def iso_(d): return d.isoformat()

def sql_snaps():
    chunks = []
    cols = 'project_id, week_start, session_id, "готовність_pct", "залишок_прогноз_год", "ймовірність_акту", "ймовірність_документації", plans_next_week, problems, help_needed, pm_comment, final_message, "залишок_прогноз_по_стадіях", "дедлайн_прогноз_по_стадіях", "блокер", "розбіжність_готовності", created_at'
    upd = ", ".join('%s = EXCLUDED.%s' % (c.strip(), c.strip()) for c in cols.split(',') if c.strip() not in ('project_id', 'week_start'))
    for p in S:
        sns = sim.snapshots(p)
        if not sns: continue
        sm = report.summarize(p)
        vals = []
        for i, sn in enumerate(sns):
            last = (i == len(sns) - 1)
            etc = sn['etc']; stl = list(sn['rd'].keys())
            tot = sum(etc[s] for s in stl) if all(s in etc for s in stl) else None
            fm = final_message(p, sn, sm) if last else None
            vals.append("(%s,'%s','304884647',%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'%sT10:00:00+00')" % (
                q(p['id']), sn['week'], js(sn['rd']), 'NULL' if tot is None else tot, sn['ap'], sn['dp'], q(sn['plans']), q(sn['problems']), q(sn['help']), q(sn['comment']), q(fm),
                js(etc), js(sn['dl']), js(sn['bl']) if sn['bl'] is not None else 'NULL', js(sn['gap']) if sn['gap'] else 'NULL',
                (dt.date.fromisoformat(sn['week']) + dt.timedelta(days=4)).isoformat()))
        chunks.append((p['id'], "insert into public.wr_weekly_snapshots(%s) values\n%s\non conflict (project_id, week_start) do update set %s;\n" % (cols, ",\n".join(vals), upd)))
    return chunks

def sql_items():
    vals = []
    for p in S:
        sns = sim.snapshots(p)
        for sn in sns:
            nxt = (dt.date.fromisoformat(sn['week']) + dt.timedelta(days=7)).isoformat()
            lines = sn['plans'].split('\n')
            for k, line in enumerate(lines, 1):
                if sn['w'] == 7: stt = 'pending'
                else:
                    bad = sn['tag'] in ('blocked', 'overrun', 'unpaid', 'cust', 'silent', 'exam', 'slow') and k == 1
                    stt = 'not_done' if bad else 'done'
                vals.append("(%s,'%s',%s,%s,'%s')" % (q(p['id']), nxt, k, q(line), stt))
    return ("insert into public.wr_plan_items(project_id, week_start, item_number, item_text, status) values\n" + ",\n".join(vals) +
            "\non conflict (project_id, week_start, item_number) do update set item_text=EXCLUDED.item_text, status=EXCLUDED.status;\n")

if __name__ == '__main__':
    import os
    O = 'out/'
    open(O + '01_archive.sql', 'w').write(sql_archive())
    for i, t in enumerate(sql_time()): open(O + '02_time_%d.sql' % (i + 1), 'w').write(t)
    open(O + '03_money.sql', 'w').write(sql_money())
    open(O + '04_plan.sql', 'w').write(sql_plan())
    for pid, t in sql_snaps(): open(O + '05_snap_%s.sql' % pid.replace('-', '_'), 'w').write(t)
    open(O + '06_items.sql', 'w').write(sql_items())
    for f in sorted(os.listdir(O)): print(f, os.path.getsize(O + f))
