# -*- coding: utf-8 -*-
# Сценарії демо-даних ARCHI (17.10.2026). Час: тижні 1..7 = пн 31.08 … пн 12.10; "сьогодні" демо = 21.10.2026.
import datetime as dt, openpyxl
D = dt.date
W0 = D(2026, 8, 31)
def wk(k): return W0 + dt.timedelta(days=7 * (k - 1))
STAGES = ['МБР', 'ЕП', 'П', 'Р']
RATES = {'Керівник проекту': 654.27, 'Головний конструктор': 674.87, 'ГІП': 724.37, 'Архітектор (юніор)': 446.57,
         'Архітектор (мідл)': 769.87, 'Архітектор (сеньйор)': 855.17, 'ГАП': 1104.27}
MIX = {'МБР': {'Керівник проекту': 1.0},
       'ЕП': {'Архітектор (сеньйор)': .642, 'Головний конструктор': .215, 'ГІП': .143},
       'П': {'Архітектор (юніор)': .666, 'Головний конструктор': .334},
       'Р': {'Архітектор (юніор)': .615, 'Головний конструктор': .385}}
SUBC = 'Субпідрядник «ІнжПроект»'

_wb = openpyxl.load_workbook('/tmp/claude-0/-home-user-fdo-perfect/f5da2c65-e669-5d8b-be61-f6dfeb4b4bb0/scratchpad/xl/k.xlsx', data_only=True)
def demo_plan(pid):
    ws = _wb[pid]
    rows = {'МБР': (2, 13), 'ЕП': (3, 17), 'П': (4, 21), 'Р': (5, 25)}
    hours = {s: ws.cell(r[1], 4).value for s, r in rows.items()}
    contract = {s: round(ws.cell(r[0], 4).value, 2) for s, r in rows.items()}
    sub = {s: round(ws.cell(r[0], 8).value or 0, 2) for s, r in rows.items()}
    team = {s: round(ws.cell(r[0], 7).value or 0, 2) for s, r in rows.items()}
    rate = round(sum(team.values()) / sum(hours.values()), 2)
    return dict(hours=hours, contract=contract, sub=sub, team=team, rate=rate)

def mk(pid, **kw):
    p = demo_plan(pid)
    p.update(id=pid); p.update(kw); return p

def interp(v):  # список з 8 значень прогресу
    return v

PROJECTS = []
