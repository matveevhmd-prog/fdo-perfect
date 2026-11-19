#!/usr/bin/env python3
"""W1.8 крок 3: генерує нову версію коду `Build MiniApp Data` (кольори й сигнали читаються з SQL) і нові запити метрик.
Вхід: workflows/DEMO_Archi_Agent_Core.json (живий експорт, версія 730b080f). Вихід: scripts/w1_8_step3/out/*.
Правило: кожна заміна має збігтись рівно один раз, інакше скрипт зупиняється (чернетка не вигадується)."""
import json, os, re, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(os.path.dirname(__file__), 'out'); os.makedirs(OUT, exist_ok=True)
WF = json.load(open(os.path.join(ROOT, 'workflows', 'DEMO_Archi_Agent_Core.json'), encoding='utf-8'))
N = {n['name']: n for n in WF['nodes']}
code = N['Build MiniApp Data']['parameters']['jsCode']

def once(s, a, b, label):
    if s.count(a) != 1:
        sys.exit('ЗБІЙ «%s»: збігів %d (очікувався 1)' % (label, s.count(a)))
    return s.replace(a, b)

def cut(s, start, end, repl, label):
    i = s.find(start)
    if i < 0 or s.count(start) != 1: sys.exit('ЗБІЙ «%s»: початок, збігів %d' % (label, s.count(start)))
    j = s.find(end, i)
    if j < 0: sys.exit('ЗБІЙ «%s»: кінець не знайдено' % label)
    return s[:i] + repl + s[j + len(end):]

# 0. читання карток портфеля з SQL
code = once(code, "const RULES = obj((metricsRows[0] || {}).rules);",
"""const RULES = obj((metricsRows[0] || {}).rules);
// W1.8 крок 3: кольори, сигнали, групи й лічильники рахує SQL (archi_project_signals, archi_portfolio_cards); тут лише відображення
const SQLC = obj((metricsRows[0] || {}).cards);
if (metricsRows.length && (!SQLC.counts || !SQLC.groups || !SQLC.hero)) throw new Error('W1.8: archi_portfolio_cards не повернула картки портфеля');
const SIG_ORDER = ['rent', 'etc_gap', 'unpaid', 'cpi', 'optimistic', 'slips', 'doc_prob', 'help', 'plan_exec', 'readiness_gap', 'blocker', 'no_weekly_report', 'no_forecast'];""", 'RULES')

# 1. клас і сигнали проєкту з SQL (замість правил у коді)
code = cut(code, "  var signals = [];\n  var cls = {};", "    if (cls.etc === 'green') cls.etc = 'yellow';\n  }\n",
"""  var sg = obj(row['sig']);
  if (!sg.project_id) throw new Error('W1.8: archi_project_signals не повернула проєкт ' + id);
  var cls = Object.assign({}, obj(sg.cls));
  var signals = [];
  var sdat = obj(row['stage_data']);
""", 'cls/signals block')

# 2. тижневий звіт: класи стадій, документація, блокер — з SQL
code = once(code, "    var slips = [];\n", "", 'slips var')
code = cut(code, "      var c = '';\n      if (slip !== null", "        if (c === 'red' || c === 'yellow') slips.push({ s: s, d: slip, c: c });\n      }\n",
           "      var c = obj(sg.stage_cls)[s] || '';\n", 'stage cls')
code = cut(code, "    if (slips.length) {\n", "      signals.push({c: sc, t: 'Терміни: ' + slips.map(function(x){ return x.s + ' пізніше плану на ' + x.d + ' дн.'; }).join(', ')});\n    }\n", "", 'slips signal')
code = once(code, "    var docCls = docProb === null ? '' : (docProb <= DOC_RED ? 'red' : (docProb <= DOC_YELLOW ? 'yellow' : 'green'));\n    if (docCls === 'red') signals.push({c:'red', t:'Ймовірність видачі документації ' + docProb + '/10'});\n",
            "    var docCls = sg.doc_cls || '';\n", 'doc cls')
code = once(code, "    if (help) signals.push({c:'yellow', t:'ПМ просить допомоги власника'});\n", "", 'help signal')
code = re.sub(r"    if \(peSig === 'red' \|\| peSig === 'yellow'\) signals\.push\(\{c: peSig, t: [^\n]*\n", "", code, count=1)
code = re.sub(r"    var gapSt = Object\.keys\(gp\);\n    if \(gapSt\.length\) signals\.push\([^\n]*\n", "", code, count=1)
code = once(code, "      var bCls = (bDays !== null && bDays >= BLOCK_RED_DAYS) ? 'red' : 'yellow';\n",
            "      var bSig = (sg.signals || []).filter(function(x){ return x.code === 'blocker'; })[0];\n      var bCls = bSig ? bSig.c : 'yellow';\n", 'blocker cls')
code = re.sub(r"      signals\.push\(\{ c: bCls, b: true, t: 'Проєкт стоїть'[^\n]*\n", "", code, count=1)
code = once(code, "  } else {\n    if (!noFc) signals.push({c:'yellow', t:'ПМ ще не подавав тижневий звіт'});\n  }\n", "  }\n", 'no weekly report')
code = re.sub(r"    signals\.push\(\{c:'red', t:'Прогноз відсутній: ' \+ why[^\n]*\n", "", code, count=1)

# 3. побудова сигналів за кодом з SQL і підсумок
code = once(code, "  signals.sort(function(a,b){",
"""  var sigText = function(s) {
    var a = s.args || {};
    switch (s.code) {
      case 'rent': return a.loss ? ('Рентабельність прогноз ' + fmtPct(rentF) + ' — проєкт у збитку') : ('Рентабельність план ' + fmtPct(rentP) + ' (Кошторис) → прогноз ' + fmtPct(rentF) + ': на ' + String(Math.round(a.drop_pp * 10) / 10).replace('.', ',') + ' п.п. нижче плану');
      case 'etc_gap': return 'Ще потрібно ' + fmtHrs(etcF) + ' — ETC_факт перевищено на ' + fmtHrs(toNum(a.gap_hours)) + ' (' + Math.round(toNum(a.gap_pct_bac)) + '% плану проєкту)';
      case 'unpaid': return 'Виконано і не оплачено ' + fmtUAH(toNum(a.amount)) + ' (' + a.pct + '% контракту)';
      case 'cpi': return 'Ефективність виконання (гроші) ' + fmtRatio(toNum(a.value)) + ' — перевитрата: на 1 грн витрат ' + fmtRatio(toNum(a.value)) + ' грн освоєного за готовністю ПМа';
      case 'optimistic': return 'Оптимістичний прогноз ПМа: ' + (a.stages || []).map(function(x){ return 'стадія ' + x.stage + ' — ETC на ' + x.drop + '% нижче плану при готовності ' + x.ready + '%'; }).join('; ');
      case 'slips': return 'Терміни: ' + (a.slips || []).map(function(x){ return x.stage + ' пізніше плану на ' + x.days + ' дн.'; }).join(', ');
      case 'doc_prob': return 'Ймовірність видачі документації ' + a.prob + '/10';
      case 'help': return 'ПМ просить допомоги власника';
      case 'plan_exec': return 'Виконання плану тижня ' + a.pct + '%: виконано ' + a.done + ' з ' + a.total + (Number(row['pe_not_done']) + Number(row['pe_no_answer']) > 0 ? ', перенесено ' + (Number(row['pe_not_done']) + Number(row['pe_no_answer'])) : '');
      case 'readiness_gap': { var g = obj(a.gap), ks = Object.keys(g); return 'Готовність за оцінкою ПМ не збігається з годинами: ' + ks.map(function(k){ return k + ' ' + g[k].pm + '% проти ' + g[k].hours + '% за годинами'; }).join(', ') + ' (ПМ підтвердив' + (g[ks[0]] && g[ks[0]].note ? ': ' + g[ks[0]].note : '') + ')'; }
      case 'blocker': return 'Проєкт стоїть' + (a.days !== null && a.days !== undefined ? ' ' + a.days + ' дн. (з ' + fmtDate(a.since) + ')' : '') + ': ' + (a.types || []).map(function(t){ return BLOCK_LABEL[t] || t; }).join('; ');
      case 'no_weekly_report': return 'ПМ ще не подавав тижневий звіт';
      case 'no_forecast': return 'Прогноз відсутній: ' + why + (lastFcFmt ? '. Останній підтверджений прогноз рентабельності ' + lastFcFmt : '');
    }
    throw new Error('W1.8: невідомий код сигналу ' + s.code);
  };
  (sg.signals || []).slice().sort(function(x, y){ return SIG_ORDER.indexOf(x.code) - SIG_ORDER.indexOf(y.code); }).forEach(function(s){
    var o = { c: s.c, t: sigText(s) }; if (s.b) o.b = true; signals.push(o);
  });
  signals.sort(function(a,b){""", 'sort')
code = once(code, "  var reds = signals.filter(function(s){ return s.c==='red'; }).length;\n  var yellows = signals.length - reds;\n", "", 'reds/yellows')
code = once(code, "status: reds ? 'red' : (yellows ? 'yellow' : 'green'), reds: reds, yellows: yellows,", "status: sg.status, reds: sg.reds, yellows: sg.yellows,", 'status')

# 4. групи вкладок з SQL
code = once(code, "function groupBy(fn){ var g = {critical:[], attention:[], normal:[]}; projects.forEach(function(p){ var r = fn(p); if (r) g[r[0]].push({ id:p.id, name:p.name, value:r[1] }); }); return g; }",
"function sqlGroup(k, valFn){ var G = obj(obj(SQLC.groups)[k]); var byId = {}; projects.forEach(function(p){ byId[p.id] = p; }); function m(ids){ return (ids || []).map(function(id){ var p = byId[id]; return p ? { id: p.id, name: p.name, value: valFn(p) } : null; }).filter(Boolean); } return { critical: m(G.critical), attention: m(G.attention), normal: m(G.normal) }; }", 'groupBy')
code = re.sub(r"const rentG = groupBy\(function\(p\)\{[^\n]*\n", "const rentG = sqlGroup('rent', function(p){ return p.noForecast ? 'прогноз відсутній' : p.rentForecastFmt; });\n", code, count=1)
code = re.sub(r"const profitG = groupBy\(function\(p\)\{[^\n]*\n", "const profitG = sqlGroup('profit', function(p){ return p.noForecast ? 'прогноз відсутній' : p.profitForecastFmt; });\n", code, count=1)
code = re.sub(r"const volG = groupBy\(function\(p\)\{[^\n]*\n", "const volG = sqlGroup('volume', function(p){ return fmtUAH(Math.max(0,(p.rawQ||0)-(p.rawP||0))); });\n", code, count=1)
code = re.sub(r"const etcG = groupBy\(function\(p\)\{[^\n]*\n", "const etcG = sqlGroup('etc', function(p){ return p.noForecast ? 'ETC не подано' : fmtHrs((p.rawEtcForecast||0)-(p.rawEtcPlan||0)); });\n", code, count=1)
code = re.sub(r"const evmG = groupBy\(function\(p\)\{[^\n]*\n", "const evmG = sqlGroup('evm', function(p){ return p.cpiFmt; });\n", code, count=1)
if 'groupBy(' in code: sys.exit('ЗБІЙ: лишився groupBy')

# 5. hero-класи з SQL
code = once(code, "cls: (avgRentForecast < 0 || (avgRentPlan - avgRentForecast) * 100 > RENT_DROP_PP_RED) ? 'red' : ((avgRentPlan - avgRentForecast) * 100 > RENT_DROP_PP ? 'yellow' : 'green') }", "cls: SQLC.hero.rent }", 'hero rent')
code = once(code, "cls: (function(){ if (totalProfitForecast < 0) return 'red'; var dev = totalProfitPlan ? (totalProfitPlan-totalProfitForecast)/totalProfitPlan*100 : null; if (dev !== null && dev > PROFIT_RED_PCT) return 'red'; if (dev !== null && dev > PROFIT_YELLOW_PCT) return 'yellow'; return 'green'; })() }", "cls: SQLC.hero.profit }", 'hero profit')
code = once(code, "cls: volumeGapSum > 0 ? 'yellow' : 'green' }", "cls: SQLC.hero.volume }", 'hero volume')
code = once(code, "cls: etcGapAvg > 0 ? 'yellow' : 'green' }", "cls: SQLC.hero.etc }", 'hero etc')
code = once(code, "cls: heroCls(cpiAvg, CPI_RED, CPI_YELLOW, true) }", "cls: SQLC.hero.evm }", 'hero evm')

# 6. «потребують уваги» і лічильники з SQL
code = cut(code, "const attention = projects.filter(function(p){ return p.status !== 'green'; })", "top: p.signals.length ? p.signals[0].t : '' }; });\n",
"const attention = (SQLC.attention || []).map(function(a){ var p = projects.filter(function(x){ return x.id === a.id; })[0]; return { id: a.id, status: a.status, blocked: !!a.blocked, reds: a.reds, yellows: a.yellows, top: p && p.signals.length ? p.signals[0].t : '' }; });\n", 'attention')
code = re.sub(r"  counts: \{ red: projects\.filter[^\n]*\n", "  counts: SQLC.counts,\n", code, count=1)
if 'SQLC.counts,' not in code: sys.exit('ЗБІЙ: counts')
open(os.path.join(OUT, 'Build_MiniApp_Data.step3.js'), 'w', encoding='utf-8').write(code)

# 7. запити метрик: додати sig і cards (обидва шляхи — Mini App і чат)
def wrap(q):
    q = q.strip().rstrip(';')
    assert q.startswith('SELECT m.project_id,'), q[:40]
    q = q.replace('SELECT m.project_id,', "SELECT (SELECT e FROM sg, jsonb_array_elements(sg.j) e WHERE e->>'project_id' = m.project_id) AS sig, (SELECT j FROM cd) AS cards, m.project_id,", 1)
    return "WITH sg AS (SELECT public.archi_project_signals($1::uuid) AS j), cd AS (SELECT public.archi_portfolio_cards($1::uuid) AS j) " + q + ";"
for nm, fn in (('Fetch Project Metrics (MiniApp)', 'q_miniapp.sql'), ('Fetch Project Metrics (Chat)', 'q_chat.sql')):
    open(os.path.join(OUT, fn), 'w', encoding='utf-8').write(wrap(N[nm]['parameters']['query']))
print('OK: код', len(code), 'байт; запити записано')
