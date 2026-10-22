#!/usr/bin/env python3
"""Перевірка «єдиної форми звіту» (WEEKLY_REPORT_FORM §1–2): підписи й нумерація пп. 1–12 мають збігатися
в чаті ПМа (WR: Render Report) і в Weekly Render (Build Weekly Render HTML) у workflows/DEMO_Archi_Agent_Core.json.
Запуск: python3 scripts/check_report_form.py  (код виходу 1 — є розбіжності)."""
import json, sys, pathlib

root = pathlib.Path(__file__).resolve().parent.parent
wf = json.loads((root / 'workflows' / 'DEMO_Archi_Agent_Core.json').read_text(encoding='utf-8'))
code = {n['name']: n['parameters'].get('jsCode', '') for n in wf['nodes']}
chat, html = code['WR: Render Report'], code['Build Weekly Render HTML']

# Фрагменти, що мають бути в обох контурах: (№ і підпис, ключ у чаті, ключ у Weekly Render)
FORM = [
    ('1. Рентабельність',          "'1. Рентабельність'",          '1. Рентабельність'),
    ('2. ETC, год',                "'2. ETC, год'",                '2. ETC, год'),
    ('3. Готовність',               "'3. Готовність'",               '3. Готовність'),
    ('4–6. Стадія ЕП/П/Р',          "NUM_AT = { 'ЕП': 4, 'П': 5, 'Р': 6 }", "numberedStages.forEach(function(s, idx){ rows.push('<div class=\"m-row\"><span class=\"m-label\">'+(4+idx)+'. Стадія '"),
    ('7. Акт',                     "'7. Акт'",                     '7. Акт'),
    ('8. Документація',            "'8. Документація'",            '8. Документація'),
    ('9. Проблеми',                '9. Проблеми',                  "textRow(9, 'Проблеми'"),
    ('10. Допомога',               '10. Допомога',                 "textRow(10, 'Допомога'"),
    ('11. План на тиждень',        '11. План на тиждень',          '11. План на тиждень'),
    ('12. Коментар ПМ',            '12. Коментар ПМ',              "textRow(12, 'Коментар ПМ'"),
]
bad = 0
for name, k_chat, k_html in FORM:
    ok_c, ok_h = k_chat in chat, k_html in html
    print(('OK  ' if ok_c and ok_h else 'FAIL'), name, '' if ok_c else '| немає в чаті', '' if ok_h else '| немає у Weekly Render')
    bad += (not ok_c) + (not ok_h)
# Застарілі шаблонні підписи не мають повертатися
for stale in ('Готовність (%)_Total', 'КОМЕНТАРІ ПМ', '6. ПЛАН НА ТИЖДЕНЬ', '4. ПРОБЛЕМИ'):
    for nm, c in (('WR: Build WR Prompt', code['WR: Build WR Prompt']), ('WR: Render Report', chat)):
        if stale in c:
            print('FAIL застарілий підпис «%s» у %s' % (stale, nm)); bad += 1
print('Розбіжностей:', bad)
sys.exit(1 if bad else 0)
