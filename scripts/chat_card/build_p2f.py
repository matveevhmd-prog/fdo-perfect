#!/usr/bin/env python3
"""П2f (B-28, 19.11.2026): будує *.p2f.js з *.p2e.js. Зміни: портфель «емодзі число» + ❓; «Проблеми» без «Потрібно»; кілька маршрутів дій на проєкт; правила про простій."""
import os
here = os.path.dirname(os.path.abspath(__file__))
def rep(s, old, new):
    assert s.count(old) == 1, ('anchor count', s.count(old), old[:80])
    return s.replace(old, new)

b = open(os.path.join(here, 'Build_Request_Body.p2e.js')).read()
# 1. маршрути: масив із SQL (archi_card_facts.routes), запасний варіант — одиночний route
b = rep(b, "function routeOf(p){ var f = FACTS && FACTS.projects && FACTS.projects[p.id]; return (f && f.route) || null; }",
"function routesOf(p){ var f = FACTS && FACTS.projects && FACTS.projects[p.id]; if (!f) return []; if (Array.isArray(f.routes) && f.routes.length) return f.routes; return f.route ? [f.route] : []; }")
b = rep(b, "function routeLine(p){ var r = routeOf(p); return r ? 'Маршрут дії (правило SQL, п. 32): ' + (ROUTE_LABEL[r.type] || r.type) + ' → ' + r.to + '; підстава: ' + r.basis : ''; }",
"function routeLine(p){ var rs = routesOf(p); if (!rs.length) return ''; return 'Маршрути дій (правило SQL, п. 32; кількість action = кількості маршрутів, порядок той самий): ' + rs.map(function(r, i){ return (i + 1) + ') ' + (ROUTE_LABEL[r.type] || r.type) + ' → ' + r.to + (r.reason ? '; причина блокера: ' + r.reason : '') + '; підстава: ' + r.basis; }).join(' '); }")
b = rep(b, "    route: routeOf(p)\n  };", "    routes: routesOf(p)\n  };")
# 2. «Проблеми» — лише факти (B-28 п. 2); «Потрібно» лишається у фактах для LLM (рядок із need додається в cardBlocks)
b = rep(b, "  if (p.blocker && p.blocker.need) probs.push('• Потрібно: ' + p.blocker.need);\n", "")
# 3. лічильник ❓
b = rep(b, "noFc: noFcIds, summaryFacts: summary };", "noFc: noFcIds, noFcN: projects.filter(function(p){ return p.noForecast; }).length, summaryFacts: summary };")
# 4. промпт
b = rep(b, "action — готовий текст, який власник копіює й надсилає (п. 32). Адресат і тип — з рядка «Маршрут дії» (його задав SQL, не змінюй): ",
 "actions — масив готових текстів, які власник копіює й надсилає (п. 32), по одному на кожен маршрут із рядка «Маршрути дій» у тому самому порядку (їх задав SQL, не змінюй адресата й тип; два маршрути — дві окремі дії різним адресатам, ресурси — запит людей, гроші — запит коштів; жодної дії для адресата, якого немає в маршрутах): ")
b = rep(b, "'4. Стиль: insight і impact до 30 слів; action до 45 слів, без звертання за іменем (імен у даних немає), без нумерації й маркерів усередині полів.' + NL + NL +",
 "'4. Стиль: insight і impact до 30 слів; кожен action до 45 слів, без звертання за іменем (імен у даних немає), без нумерації й маркерів усередині полів.' + NL +\n    '5. Простій (⛔ блокер) не споживає ресурсів і НЕ знижує рентабельність чи прибуток: не пиши, що зупинка обвалила рентабельність. Ризик простою — перенос термінів і порушення умов договору. Про штрафи: умов і сум санкцій у даних немає — сум не вигадуй, можна лише сказати, що даних про санкції немає.' + NL +\n    '6. Блокер із двома причинами — дві окремі причини в insight і дві окремі дії; не змішуй проблеми з пропозиціями рішень: insight описує причину, дія — що робити.' + NL + NL +")
b = rep(b, "Не округлюй, не рахуй нових сум, не вживай «тис.» і «млн».'", "Не округлюй, не рахуй нових сум, не вживай «тис.» і «млн». Не додавай, не віднімай і не ділі числа з фактів (суми кількох проєктів, частки, різниці дат); дні простою бери лише з числа «N дн.» у фактах, не рахуй від дат; якщо потрібного числа немає у фактах — опиши словами без числа.'")
b = rep(b, "Для портфеля: headline — головний висновок про стан справ; priorities — 2–3 пріоритети в порядку впливу на гроші; pipeline — що кажуть дані про продажі й завантаження команди.", "Для портфеля: headline — головний висновок про стан справ (до 35 слів); priorities — 2–3 пріоритети в порядку впливу на гроші (кожен до 35 слів); pipeline — що кажуть дані про продажі й завантаження команди (до 40 слів).")
b = rep(b, '"cards":{"<ID проєкту>":{"insight":"…","impact":"…","action":"…"}}}', '"cards":{"<ID проєкту>":{"insight":"…","impact":"…","actions":["…"]}}}')
b = rep(b, "  maxTok = 2400;\n}", "  maxTok = 2600;\n}")
open(os.path.join(here, 'Build_Request_Body.p2f.js'), 'w').write(b)

s = open(os.path.join(here, 'Sanitize_Reply.p2e.js')).read()
# портфель: «емодзі число», ❓ замість списку назв
s = rep(s, "var out = ['Станом на ' + cd.asOf, '', '📊 <b>Портфель:</b> ' + cd.total + ' проєктів', '🔴 ' + (cd.counts.red || 0), '🟡 ' + (cd.counts.yellow || 0), '🟢 ' + (cd.counts.green || 0), '⛔ блокер: ' + (cd.counts.blocked || 0)];\n  if (cd.noFc && cd.noFc !== '—') out.push('Без прогнозу від ПМа: ' + cd.noFc);",
 "var out = ['Станом на ' + cd.asOf, '', '📊 <b>Портфель:</b> ' + cd.total + ' проєктів', '🔴 ' + (cd.counts.red || 0), '🟡 ' + (cd.counts.yellow || 0), '🟢 ' + (cd.counts.green || 0), '⛔ ' + (cd.counts.blocked || 0), '❓ ' + (cd.noFcN || 0)];")
# дії по маршрутах
s = rep(s, "    var ins = ok(j.insight), imp = ok(j.impact), act = ok(j.action);",
 "    var ins = ok(j.insight), imp = ok(j.impact);\n    var rawActs = Array.isArray(j.actions) ? j.actions : (j.action ? [j.action] : []);\n    var acts = rawActs.map(ok);")
s = rep(s, "    var routed = !!(act && c.route);\n    if (!act) { act = c.fbAction; fb = true; }\n",
 "    var routes = Array.isArray(c.routes) ? c.routes : [];\n    var act = acts[0] || null;\n    var routed = !!(act && routes.length);\n    if (!act) { act = c.fbAction; fb = true; }\n")
old = s[s.index("    if (routed) {"):s.index("  });\n  var restKeys")]
new = """    if (routed) {
      var RL = { command: 'доручення', propose: 'запит варіантів', call: 'дзвінок власника' };
      routes.forEach(function(rt, ri){
        var tx = ri === 0 ? act : acts[ri];
        if (!tx) return;   // немає тексту від LLM для маршруту — не вигадуємо
        out.push('🎯 <b>Action · ' + (RL[rt.type] || rt.type) + (rt.to && rt.to !== 'власник' ? ' → ' + rt.to : '') + ':</b>', '«' + tx + '»', '');
      });
      out.push('━━━━━━━━━━━━', '');
    } else out.push('🎯 <b>Action:</b> ' + act, '', '━━━━━━━━━━━━', '');
"""
s = s.replace(old, new)

# --- 19.11.2026: обрізання без розриву речення і розбиття довгої відповіді на кілька повідомлень Telegram ---
s = rep(s, "return bad ? null : v.trim().slice(0, mx); };",
 "if (bad) return null; var tv = v.trim(); if (tv.length <= mx) return tv; var cp = tv.slice(0, mx), dot = Math.max(cp.lastIndexOf('. '), cp.lastIndexOf('; ')); return dot > mx * 0.5 ? cp.slice(0, dot + 1) : null; };")
s = rep(s, "var hd = okP(jp.headline, 260);", "var hd = okP(jp.headline, 320);")
s = rep(s, "okP(x, 240); }).filter(Boolean);", "okP(x, 300); }).filter(Boolean);")
s = rep(s, "var pl = okP(jp.pipeline, 240);", "var pl = okP(jp.pipeline, 320);")
old_tail = s[s.index("// обрізати по межі абзацу"):]
new_tail = r"""// розбити на кілька повідомлень по межі між картками (ліміт Telegram 4096; B-28: дві дії на проєкт збільшують картку)
var chunks = [t];
if (cardD && t.length > 3900) {
  var SEP = '\n\n━━━━━━━━━━━━\n\n', parts = t.split(SEP), cur = '';
  chunks = [];
  parts.forEach(function (p) { var add = (cur ? SEP : '') + p; if (cur && (cur + add).length > 3800) { chunks.push(cur); cur = p; } else cur += add; });
  if (cur) chunks.push(cur);
  chunks = chunks.map(function (c) { return c.replace(/[\s━]+$/, ''); });
}
const stopR = String(($input.first().json || {}).stop_reason || '');
function finish(c) {
  // обрізати по межі абзацу (ліміт Telegram 4096)
  if (c.length > 3900) { const cut = c.lastIndexOf('\n\n', 3850); c = (cut > 1500 ? c.slice(0, cut) : c.slice(0, 3850)) + '\n\n… (відповідь скорочено — уточніть питання, і я розгорну)'; }
  // збалансувати теги
  const stack = [];
  c = c.replace(/<(\/?)(b|i|u|s|code)>/g, function (m, slash, name) {
    if (!slash) { stack.push(name); return m; }
    const idx = stack.lastIndexOf(name);
    if (idx < 0) return '';
    const out = stack.splice(idx).reverse().slice(0, -1).map(function (n) { return '</' + n + '>'; }).join('') ;
    return out + m;
  });
  while (stack.length) c += '</' + stack.pop() + '>';
  return c;
}
return chunks.map(function (c) { return { json: { text: finish(c), llm_stop: stopR }, pairedItem: { item: 0 } }; });
"""
s = s.replace(old_tail, new_tail)
open(os.path.join(here, 'Sanitize_Reply.p2f.js'), 'w').write(s)
print('ok', len(b), len(s))
