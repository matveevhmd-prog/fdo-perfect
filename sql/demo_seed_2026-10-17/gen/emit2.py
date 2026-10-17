# -*- coding: utf-8 -*-
import datetime as dt
import sim
from scen import S
from spec import *
from emit import q, js
ANV = 10; PRICE = 7500; VH = 5; RATE = 1104.27
AN = {
 'DEMO-08-АН': dict(parent='DEMO-08', visits=[(D(2026,7,7),5.0),(D(2026,7,14),5.0),(D(2026,7,21),4.5),(D(2026,7,28),5.0),(D(2026,8,4),5.5),(D(2026,8,11),5.0),(D(2026,8,18),5.0),(D(2026,8,25),4.5),(D(2026,9,1),5.0),(D(2026,9,8),5.0)], paid=10),
 'DEMO-04-АН': dict(parent='DEMO-04', visits=[(D(2026,8,18),5.5),(D(2026,8,25),5.5),(D(2026,9,1),5.5),(D(2026,9,8),5.5),(D(2026,9,15),5.5),(D(2026,9,22),5.5)], paid=4),
 'DEMO-05-АН': dict(parent='DEMO-05', visits=[(D(2026,9,29),8.0),(D(2026,10,2),8.0),(D(2026,10,6),8.0),(D(2026,10,9),8.0)], paid=3),
 'DEMO-01-АН': dict(parent='DEMO-01', visits=[], paid=0),
}
def sql_an():
    L = []
    plan = dict(c=ANV*PRICE, team=round(ANV*VH*RATE, 2))
    profit = plan['c'] - plan['team']; rent = round(profit / plan['c'] * 100, 1)
    for pid, a in AN.items():
        L.append("insert into public.project_metrics(project_id, contract_type, parent_project_id, visits_plan, visit_price, visit_hours, real_rate_team_hour, contract_amount, planned_hours, bac, cost_plan_team, cost_plan_subcontract, profit_plan, profitability_plan_pct) values (%s,'visit',%s,%d,%d,%s,%s,%d,%s,%s,%s,0,%s,%s) on conflict (project_id) do update set parent_project_id=EXCLUDED.parent_project_id, visits_plan=EXCLUDED.visits_plan, visit_price=EXCLUDED.visit_price, visit_hours=EXCLUDED.visit_hours, real_rate_team_hour=EXCLUDED.real_rate_team_hour, contract_amount=EXCLUDED.contract_amount, planned_hours=EXCLUDED.planned_hours, bac=EXCLUDED.bac, cost_plan_team=EXCLUDED.cost_plan_team, profit_plan=EXCLUDED.profit_plan, profitability_plan_pct=EXCLUDED.profitability_plan_pct;" %
                 (q(pid), q(a['parent']), ANV, PRICE, VH, RATE, plan['c'], ANV*VH, plan['team'], plan['team'], profit, rent))
    tv, mv = [], []
    for pid, a in AN.items():
        for d, h in a['visits']:
            tv.append("(%s,'%s','АН','ГАП',$q$Виїзд на об’єкт (авторський нагляд)$q$,%s,'confirmed','demo')" % (q(pid), d.isoformat(), h))
            mv.append("(%s,'%s','АН',$q$Замовник$q$,%d,'акт_підписаний','confirmed','demo')" % (q(pid), (d + dt.timedelta(days=1)).isoformat(), PRICE))
        for i in range(a['paid']):
            d = a['visits'][i][0] + dt.timedelta(days=11)
            mv.append("(%s,'%s',NULL,$q$Замовник$q$,%d,'надходження_від_замовника','confirmed','demo')" % (q(pid), d.isoformat(), PRICE))
    L.append("insert into public.time_log(project_id,\"дата\",\"стадія\",\"виконавець\",\"завдання_розділ\",\"години\",\"статус\",source) values\n" + ",\n".join(tv) + ";")
    L.append("insert into public.money_log(project_id,\"дата\",\"стадія\",\"контрагент\",\"сума\",\"тип\",\"статус\",source) values\n" + ",\n".join(mv) + ";")
    return "\n".join(L) + "\n"

def sql_items():
    bad = []
    for p in S:
        for sn in sim.snapshots(p):
            if sn['tag'] in ('blocked', 'overrun', 'unpaid', 'cust', 'silent', 'exam', 'slow') and sn['w'] < 7:
                bad.append("(%s,'%s')" % (q(p['id']), sn['week']))
    return ("insert into public.wr_plan_items(project_id, week_start, item_number, item_text, status)\n"
            "select s.project_id, (s.week_start + 7), t.n::int, t.line,\n"
            " case when s.week_start = date '2026-10-12' then 'pending'\n"
            "      when t.n = 1 and (s.project_id, s.week_start::text) in (values %s) then 'not_done' else 'done' end\n"
            "from public.wr_weekly_snapshots s cross join lateral unnest(string_to_array(s.plans_next_week, E'\\n')) with ordinality as t(line, n)\n"
            "where s.session_id = '304884647' and s.plans_next_week is not null and s.week_start between date '2026-08-31' and date '2026-10-12'\n"
            "on conflict (project_id, week_start, item_number) do update set item_text = EXCLUDED.item_text, status = EXCLUDED.status;\n") % ",".join(bad)

def sql_misc():
    L = []
    kp = [(D(2026,1,15),24),(D(2026,2,13),26),(D(2026,3,16),31),(D(2026,4,15),28),(D(2026,5,15),33),(D(2026,6,15),27),(D(2026,7,15),22),(D(2026,8,14),29),(D(2026,9,15),30)]
    L.append("insert into public.kp_log(logged_at, count, telegram_user_id) values\n" + ",\n".join("('%sT09:00:00+00',%d,304884647)" % (d.isoformat(), c) for d, c in kp) + ";")
    m = [('DEMO-05', D(2026,10,13), 'Андрій, ПМ DEMO-05, ГАП', 'Виділити архітектора на стадію ЕП і профінансувати аванс субпідряднику', 'Андрій', D(2026,10,16)),
         ('DEMO-05', D(2026,10,13), 'Андрій, ПМ DEMO-05, ГАП', 'Надіслати замовнику лист із новим графіком відновлення робіт', 'ПМ DEMO-05', D(2026,10,15)),
         ('DEMO-06', D(2026,10,9), 'ПМ DEMO-06, експерт, ГІП', 'Усунути зауваження експертизи по пожежній безпеці та повторно подати стадію П', 'ГІП', D(2026,10,23)),
         ('DEMO-03', D(2026,10,12), 'ПМ DEMO-03, замовник', 'Підписати додаткову угоду на змінений обсяг стадії П', 'ПМ DEMO-03', D(2026,10,26)),
         ('DEMO-10', D(2026,10,14), 'Андрій, ПМ DEMO-10, фінансовий директор замовника', 'Замовник сплачує акти ЕП і П до 28.10', 'Замовник', D(2026,10,28)),
         ('DEMO-07', D(2026,10,15), 'Андрій, ПМ DEMO-07', 'Підготувати розрахунок збитку і варіанти перегляду кошторису', 'ПМ DEMO-07', D(2026,10,22)),
         ('24-11', D(2026,10,8), 'ПМ 24-11, представник замовника', 'Замовник погоджує планувальне рішення В-2 до 30.10', 'Замовник', D(2026,10,30)),
         ('22-24', D(2026,10,14), 'ПМ 22-24, бухгалтер замовника', 'Узгодити проміжний акт на виконаний обсяг стадії Р', 'ПМ 22-24', D(2026,10,28))]
    L.append("insert into public.meeting_log(project_id, \"дата\", \"учасники\", \"рішення_дія\", \"відповідальний\", \"дедлайн\", source) values\n" + ",\n".join(
        "(%s,'%s',%s,%s,%s,'%s','demo')" % (q(a), b.isoformat(), q(c), q(d), q(e), f.isoformat()) for a, b, c, d, e, f in m) + ";")
    return "\n".join(L) + "\n"
if __name__ == '__main__':
    open('out/07_an.sql', 'w').write(sql_an()); open('out/06_items.sql', 'w').write(sql_items()); open('out/08_misc.sql', 'w').write(sql_misc())
    import os
    for f in ('07_an.sql', '06_items.sql', '08_misc.sql'): print(f, os.path.getsize('out/' + f))
