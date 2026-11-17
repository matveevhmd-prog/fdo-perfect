#!/usr/bin/env python3
"""П2e: будує Build_Request_Body.p2e.js і Sanitize_Reply.p2e.js з p2d-версій (код живого n8n 34f82ff5)."""
import os
here = os.path.dirname(os.path.abspath(__file__))
def rep(s, old, new):
    assert s.count(old) == 1, ('anchor count', s.count(old), old[:70])
    return s.replace(old, new)

b = open(os.path.join(here, 'Build_Request_Body.p2d.js')).read()
b = rep(b, "const projects = data.projects || [];\n",
        "const projects = data.projects || [];\nconst FACTS = data.facts || null;   // П2e: факти SQL archi_card_facts (відхилення прибутку, концентрація, блокери)\n")
b = rep(b, "function buildCard(p){\n",
"""var ROUTE_LABEL = { command: 'доручення', propose: 'запит варіантів', call: 'дзвінок власника' };
function routeOf(p){ var f = FACTS && FACTS.projects && FACTS.projects[p.id]; return (f && f.route) || null; }
function routeLine(p){ var r = routeOf(p); return r ? 'Маршрут дії (правило SQL, п. 32): ' + (ROUTE_LABEL[r.type] || r.type) + ' → ' + r.to + '; підстава: ' + r.basis : ''; }
function contractLine(p){ return p.contract > 0 ? 'Контракт: ' + Math.round(p.contract).toLocaleString('uk-UA') + ' грн' : ''; }
function gapLine(p){
  var f = FACTS && FACTS.projects && FACTS.projects[p.id];
  if (!f || f.profit_gap === null || f.profit_gap === undefined) return '';
  return 'Відхилення прибутку (прогноз − план): ' + (f.profit_gap < 0 ? '−' : '+') + Math.abs(f.profit_gap).toLocaleString('uk-UA') + ' грн' + (f.gap_share_pct ? '; частка в сумі збиткових відхилень портфеля: ' + f.gap_share_pct + '%' : '');
}
function buildCard(p){
""")
b = rep(b, "fbAction: pmAsk(p) ? pmAsk(p) : 'уточнити в ПМа'\n  };", "fbAction: pmAsk(p) ? pmAsk(p) : 'уточнити в ПМа',\n    route: routeOf(p)\n  };")
b = rep(b, "pmAsk(p), String(p.id)].join(' ');", "pmAsk(p), gapLine(p), contractLine(p), p.blocker && p.blocker.need ? String(p.blocker.need) : '', String(p.id)].join(' ');")
# CARD_MODE блок
a = b.index("// П2c/П2d: режим картки")
z = b.index("const body = JSON.stringify({")
new_block = r"""// П2e: режим картки — ШІ-аналітик Archi: факти SQL і коду → висновки по проєктах і портфелю (JSON)
var userText = text; var maxTok = 2600;
if (CARD_MODE) {
  var cardBlocks = lineBlocks.map(function(blk, i){
    var p = projects[i];
    if (CARD_DATA.order.indexOf(p.id) < 0) return null;
    return blk + (p.blocker && p.blocker.need ? NL + 'Потрібно (зі звіту ПМа про блокер): ' + String(p.blocker.need).slice(0, 300) : '') + (contractLine(p) ? NL + contractLine(p) : '') + (gapLine(p) ? NL + gapLine(p) : '') + (routeLine(p) ? NL + routeLine(p) : '');
  }).filter(Boolean).join(NL + NL);
  var P = data.pfc || {}, PF = FACTS && FACTS.portfolio;
  function sgn(v){ return (v < 0 ? '−' : '+') + Math.abs(v).toLocaleString('uk-UA') + ' грн'; }
  var unpaidAll = projects.reduce(function(s, p){ return s + Math.max(0, (p.rawQ||0) - (p.rawP||0)); }, 0);
  var asks = projects.filter(function(p){ return pmAsk(p); }).map(function(p){ return p.id + ' — ' + pmAsk(p); });
  var portLines = [
    'Проєктів: ' + projects.length + '; 🔴 ' + (data.counts ? data.counts.red : 0) + '; 🟡 ' + (data.counts ? data.counts.yellow : 0) + '; 🟢 ' + (data.counts ? data.counts.green : 0) + '; ⛔ ' + (data.counts ? data.counts.blocked : 0) + '. Без прогнозу ПМа: ' + noFcIds + '.',
    'Річний план бюро: Прибуток план ' + fmtUAH(P.planProfit || 0) + ', прогноз ' + fmtUAH(P.forecastProfit || 0) + '.'
  ];
  if (PF) {
    portLines.push('Сума збиткових відхилень прибутку проєктів (прогноз − план): ' + fmtUAH(PF.neg_total) + '; сума додатних: ' + fmtUAH(PF.pos_total) + '; різниця: ' + sgn(PF.net_gap) + '.');
    if (PF.top_loss && PF.top_loss.length) portLines.push('Найбільші збитки: ' + PF.top_loss.map(function(x){ return x.id + ' ' + sgn(x.gap) + ' (' + x.share_pct + '%)'; }).join('; ') + '.');
    if (PF.top_gain) portLines.push('Найбільше додатне відхилення: ' + PF.top_gain.id + ' ' + sgn(PF.top_gain.gap) + '.');
    if (PF.blocked) portLines.push('Заблоковано проєктів: ' + PF.blocked.count + '; контракти заблокованих: ' + fmtUAH(PF.blocked.contract_sum) + '; причини: люди — ' + PF.blocked.reasons['люди'] + ', гроші — ' + PF.blocked.reasons['гроші'] + ', замовник — ' + PF.blocked.reasons['замовник'] + '.');
  }
  portLines.push('Виконано і не оплачено клієнтами: ' + fmtUAH(unpaidAll) + (P.unpaidHours ? ' (' + Math.round(P.unpaidHours) + ' год)' : '') + '.');
  portLines.push('Пайплайн продажів: КП надіслано за рік ' + (P.kpYearSent || 0) + ' з плану ' + (P.kpPlanYear || 0) + '; за місяць ' + (P.kpMonthSent || 0) + '; прогноз договорів з КП ' + (P.kpProjectedContracts || 0) + '.');
  portLines.push('Workload годин: план ' + Math.round(P.planHours || 0) + ', факт ' + Math.round(P.factHours || 0) + ', прогноз (Σ ETC_прогноз) ' + Math.round(P.forecastHours || 0) + '.');
  if (asks.length) portLines.push('Прохання ПМів до власника: ' + asks.join('; ') + '.');
  CARD_DATA.pfacts = portLines.join(NL);
  system = 'Ти — Archi, ШІ-аналітик власника архітектурного бюро (радник COO). Українською. Твоя робота — аналіз і поради, а не переказ цифр: поясни причину, наслідок і дію.' + NL + NL +
    'ДАНІ АКТУАЛЬНІ НА: ' + (data.asOf || '—') + NL + NL +
    'ФАКТИ ПО ПРОЄКТАХ (порахували SQL і код):' + NL + NL + cardBlocks + NL + NL +
    'ФАКТИ ПО ПОРТФЕЛЮ І ПАЙПЛАЙНУ:' + NL + CARD_DATA.pfacts + NL + NL +
    'ЩО НАПИСАТИ:' + NL +
    'Для кожного названого проєкту: insight — головна причина проблеми, пояснена зв\'язком фактів (не повторюй картку); impact — наслідок для грошей чи термінів, обов\'язково з числом із фактів ЦЬОГО проєкту; action — готовий текст, який власник копіює й надсилає (п. 32). Адресат і тип — з рядка «Маршрут дії» (його задав SQL, не змінюй): «доручення» — коротке повідомлення адресату: що зробити і який результат прислати; «запит варіантів» — повідомлення ПМу: підготувати кілька варіантів і зателефонувати власнику; «дзвінок власника» — кілька тез для розмови через «;». Зміст бери з «Потрібно» або «Прохання ПМа», якщо вони є; інакше — з фактів. Вигаданих дат не став; термін — «до наступної наради».' + NL +
    'Для портфеля: headline — головний висновок про стан справ; priorities — 2–3 пріоритети в порядку впливу на гроші; pipeline — що кажуть дані про продажі й завантаження команди.' + NL + NL +
    'ПРАВИЛА ПРАВДИ:' + NL +
    '1. Числа бери ТІЛЬКИ з фактів вище, записуй у тому самому вигляді (напр. «217 360 грн», «50%»). Не округлюй, не рахуй нових сум, не вживай «тис.» і «млн».' + NL +
    '2. Причинний зв\'язок — лише між наведеними фактами. Якщо даних не вистачає — прямо скажи, чого бракує. Причин, людей, дат, яких немає у фактах, не вигадуй.' + NL +
    '3. Для годин: ETC_план / ETC_факт / ETC_прогноз; слово «залишок» заборонене. Колір і сигнали не перераховуй.' + NL +
    '4. Стиль: insight і impact до 30 слів; action до 45 слів, без звертання за іменем (імен у даних немає), без нумерації й маркерів усередині полів.' + NL + NL +
    'ФОРМАТ ВІДПОВІДІ — ЛИШЕ JSON, без пояснень і markdown:' + NL +
    '{"portfolio":{"headline":"…","priorities":["…","…"],"pipeline":"…"},"cards":{"<ID проєкту>":{"insight":"…","impact":"…","action":"…"}}}' + NL +
    'Ключі cards — рівно ці проєкти: ' + CARD_DATA.order.join(', ') + '.';
  userText = 'Питання власника: ' + text + NL + NL + 'Відповідь — ЛИШЕ JSON за схемою, без тексту до і після, без markdown.';
  maxTok = 2400;
}

"""
b = b[:a] + new_block + b[z:]
# 17.11.2026: дата оновлення даних по кожному проєкту в картці (п. 26, LAYOUT_STANDARD п. 8; власник)
b = rep(b, "    icon: p.blocker ? '⛔' : ICON[p.status],\n    hours: hours,", "    icon: p.blocker ? '⛔' : ICON[p.status],\n    updated: p.dataUpdated || DASH,   // дата оновлення даних проєкту (п. 26, LAYOUT_STANDARD п. 8)\n    hours: hours,")
open(os.path.join(here, 'Build_Request_Body.p2e.js'), 'w').write(b)

s = open(os.path.join(here, 'Sanitize_Reply.p2d.js')).read()
# 1. прибрати фільтр слів П2d; замінити перевіркою «Impact має число із фактів цього проєкту»
old_filter = "    if (imp && /ризик|погірш|зафіксу|залишаться|залишатися|залишиться|призвед|загроз|буде|будуть|може |можуть|ймовірно/i.test(imp)) imp = null;\n"
s = rep(s, old_filter, "    if (imp && !cardNums(imp).some(function(n){ return allowed[n]; })) imp = null;   // П2e: Impact без числа з фактів проєкту — вигадка\n")
# 2. блок портфеля
s = rep(s, "  out.push('', '━━━━━━━━━━━━', '');\n  cd.order.forEach(function(id){",
"""  var jp = (jc.__portfolio || null);
  if (jp && cd.pfacts) {
    var allowedP = {}; cardNums(cd.pfacts).forEach(function(n){ allowedP[n] = 1; });
    cd.order.forEach(function(id){ cardNums(cd.cards[id].facts).forEach(function(n){ allowedP[n] = 1; }); });
    var okP = function(v, mx){ if (typeof v !== 'string' || !v.trim()) return null; var bad = cardNums(v).some(function(n){ return !allowedP[n]; }); return bad ? null : v.trim().slice(0, mx); };
    var hd = okP(jp.headline, 260);
    if (hd) {
      var pr = (Array.isArray(jp.priorities) ? jp.priorities : []).slice(0, 3).map(function(x){ return okP(x, 240); }).filter(Boolean);
      var pl = okP(jp.pipeline, 240);
      out.push('', '🧭 <b>Висновок Archi</b>', hd);
      pr.forEach(function(x, i){ out.push('• ' + (i === 0 ? 'Спершу: ' : '') + x); });
      if (pl) out.push('📈 ' + pl);
    }
  }
  out.push('', '━━━━━━━━━━━━', '');
  cd.order.forEach(function(id){""")
# 3. parseCardJson: віддавати також portfolio
s = rep(s, "try { var o = JSON.parse(t.slice(i, j + 1)); return (o && o.cards && typeof o.cards === 'object') ? o.cards : null; } catch (e) { return null; }",
        "try { var o = parseLoose(t.slice(i, j + 1)); if (!(o && o.cards && typeof o.cards === 'object')) return null; var r = o.cards; Object.defineProperty(r, '__portfolio', { value: (o.portfolio && typeof o.portfolio === 'object') ? o.portfolio : null, enumerable: false }); return r; } catch (e) { return null; }")
s = rep(s, "    if (!act) { act = c.fbAction; fb = true; }\n", "    var routed = !!(act && c.route);\n    if (!act) { act = c.fbAction; fb = true; }\n")
s = rep(s, "    out.push('🎯 <b>Action:</b> ' + act, '', '━━━━━━━━━━━━', '');",
"    if (routed) {\n      var RL = { command: 'доручення', propose: 'запит варіантів', call: 'дзвінок власника' };\n      out.push('🎯 <b>Action · ' + (RL[c.route.type] || c.route.type) + (c.route.to && c.route.to !== 'власник' ? ' → ' + c.route.to : '') + ':</b>', '«' + act + '»', '', '━━━━━━━━━━━━', '');\n    } else out.push('🎯 <b>Action:</b> ' + act, '', '━━━━━━━━━━━━', '');")
s = rep(s, "    out.push(c.icon + ' <b>' + id + '</b>', '', '⏱ <b>Години</b>');", "    out.push(c.icon + ' <b>' + id + '</b>', 'Дані оновлено ' + (c.updated || '—'), '', '⏱ <b>Години</b>');")
# 17.11.2026: розбір обірваного JSON (stop_reason max_tokens): повні картки виживають, обірвана відкидається
s = rep(s, "function parseCardJson(s){", r"""function parseLoose(s){
  try { return JSON.parse(s); } catch (e) {}
  var st = [], inS = false, esc = false, cands = [];
  for (var k = 0; k < s.length; k++) {
    var ch = s.charAt(k);
    if (inS) { if (esc) esc = false; else if (ch === '\\') esc = true; else if (ch === '"') inS = false; continue; }
    if (ch === '"') inS = true;
    else if (ch === '{') st.push('}');
    else if (ch === '[') st.push(']');
    else if (ch === '}' || ch === ']') { st.pop(); cands.push([k, st.slice().reverse().join('')]); }
  }
  for (var m = cands.length - 1; m >= 0; m--) { try { return JSON.parse(s.slice(0, cands[m][0] + 1) + cands[m][1]); } catch (e2) {} }
  throw new Error('bad json');
}
function parseCardJson(s){""")
# 17.11.2026 (крок 1): поле до 500 символів (було 400) і причина зупинки моделі в виході вузла для журналу
s = rep(s, "return bad ? null : v.trim().slice(0, 400); }", "return bad ? null : v.trim().slice(0, 500); }")
s = rep(s, "return [{ json: { text: t } }];", "return [{ json: { text: t, llm_stop: String(($input.first().json || {}).stop_reason || '') } }];")
open(os.path.join(here, 'Sanitize_Reply.p2e.js'), 'w').write(s)
print('ok', len(b), len(s))
