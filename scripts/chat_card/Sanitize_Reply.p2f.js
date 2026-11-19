const raw = ($input.first().json.content && $input.first().json.content[0] && $input.first().json.content[0].text) ? String($input.first().json.content[0].text) : 'Не вдалося отримати відповідь. Спробуйте ще раз.';
// <validate>
function validateReply(t) {
  var META = /(використано теги markdown|виправляю нижче|у правильному форматі|markdown замість html|ось виправлен|виправлена версі)/i;
  var lines = String(t).split('\n').filter(function (l) { return !META.test(l); });
  t = lines.join('\n');
  // дублі: кожна відповідь починається «Станом на ДД.ММ.РРРР»; кілька таких заголовків = кілька версій однієї відповіді
  var re = /^[ \t]*Станом на \d{2}\.\d{2}\.\d{4}[ \t]*$/gm;
  var idx = [], m;
  while ((m = re.exec(t)) !== null) idx.push(m.index);
  if (idx.length > 1) {
    var parts = idx.map(function (s, i) { return t.slice(s, i + 1 < idx.length ? idx[i + 1] : t.length).replace(/[\s━─\-]+$/g, '').trim(); });
    var longest = parts.reduce(function (a, b) { return b.length > a.length ? b : a; }, '');
    var last = parts[parts.length - 1];
    t = last.length >= longest.length * 0.6 ? last : longest;   // остання версія, якщо вона не обрізана; інакше найповніша
  }
  return t.replace(/\n{3,}/g, '\n\n').trim();
}
// </validate>
// ===== П2б: складання картки з JSON LLM + дані коду; запасний шаблон без LLM =====
function cardNums(s){ var m = String(s).match(/\d+(?:\s\d{3})*(?:[.,]\d+)?/g) || []; return m.map(function(x){ return x.replace(/\s/g, '').replace(',', '.'); }); }
function parseLoose(s){
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
function parseCardJson(s){
  var t = String(s).trim().replace(/^```(?:json)?/i, '').replace(/```\s*$/, '').trim();
  var i = t.indexOf('{'), j = t.lastIndexOf('}');
  if (i < 0 || j <= i) return null;
  try { var o = parseLoose(t.slice(i, j + 1)); if (!(o && o.cards && typeof o.cards === 'object')) return null; var r = o.cards; Object.defineProperty(r, '__portfolio', { value: (o.portfolio && typeof o.portfolio === 'object') ? o.portfolio : null, enumerable: false }); return r; } catch (e) { return null; }
}
function composeCard(cd, rawText){
  var jc = parseCardJson(rawText) || {};
  var NLc = String.fromCharCode(10);
  var out = ['Станом на ' + cd.asOf, '', '📊 <b>Портфель:</b> ' + cd.total + ' проєктів', '🔴 ' + (cd.counts.red || 0), '🟡 ' + (cd.counts.yellow || 0), '🟢 ' + (cd.counts.green || 0), '⛔ ' + (cd.counts.blocked || 0), '❓ ' + (cd.noFcN || 0)];
  var jp = (jc.__portfolio || null);
  if (jp && cd.pfacts) {
    var allowedP = {}; cardNums(cd.pfacts).forEach(function(n){ allowedP[n] = 1; });
    cd.order.forEach(function(id){ cardNums(cd.cards[id].facts).forEach(function(n){ allowedP[n] = 1; }); });
    var okP = function(v, mx){ if (typeof v !== 'string' || !v.trim()) return null; var bad = cardNums(v).some(function(n){ return !allowedP[n]; }); if (bad) return null; var tv = v.trim(); if (tv.length <= mx) return tv; var cp = tv.slice(0, mx), dot = Math.max(cp.lastIndexOf('. '), cp.lastIndexOf('; ')); return dot > mx * 0.5 ? cp.slice(0, dot + 1) : null; };
    var hd = okP(jp.headline, 320);
    var pr = (Array.isArray(jp.priorities) ? jp.priorities : []).slice(0, 3).map(function(x){ return okP(x, 300); }).filter(Boolean);
    var pl = okP(jp.pipeline, 320);
    if (hd || pr.length || pl) {
      out.push('', '🧭 <b>Висновок Archi</b>');
      if (hd) out.push(hd);
      pr.forEach(function(x, i){ out.push('• ' + (i === 0 ? 'Спершу: ' : '') + x); });
      if (pl) out.push('📈 ' + pl);
    }
  }
  out.push('', '━━━━━━━━━━━━', '');
  cd.order.forEach(function(id){
    var c = cd.cards[id], j = jc[id] || {}, fb = false;
    var allowed = {}; cardNums(c.facts).forEach(function(n){ allowed[n] = 1; });
    function ok(v){ if (typeof v !== 'string' || !v.trim()) return null; var bad = cardNums(v).some(function(n){ return !allowed[n]; }); return bad ? null : v.trim().slice(0, 500); }
    var ins = ok(j.insight), imp = ok(j.impact);
    var rawActs = Array.isArray(j.actions) ? j.actions : (j.action ? [j.action] : []);
    var acts = rawActs.map(ok);
    if (imp && !cardNums(imp).some(function(n){ return allowed[n]; })) imp = null;   // П2e: Impact без числа з фактів проєкту — вигадка
    if (!ins) { ins = c.fbInsight; fb = true; }
    var routes = Array.isArray(c.routes) ? c.routes : [];
    var act = acts[0] || null;
    var routed = !!(act && routes.length);
    if (!act) { act = c.fbAction; fb = true; }
    out.push(c.icon + ' <b>' + id + '</b>', 'Дані оновлено ' + (c.updated || '—'), '', '⏱ <b>Години</b>');
    out = out.concat(c.hours);
    out.push('', '💰 <b>Гроші</b>');
    out = out.concat(c.money);
    out.push('', '🚧 <b>Проблеми</b>');
    out = out.concat(c.problems);
    out.push('', '💡 <b>Insight:</b> ' + ins);
    if (imp) out.push('⚠️ <b>Impact:</b> ' + imp);
    if (routed) {
      var RL = { command: 'доручення', propose: 'запит варіантів', call: 'дзвінок власника' };
      routes.forEach(function(rt, ri){
        var tx = ri === 0 ? act : acts[ri];
        if (!tx) return;   // немає тексту від LLM для маршруту — не вигадуємо
        out.push('🎯 <b>Action · ' + (RL[rt.type] || rt.type) + (rt.to && rt.to !== 'власник' ? ' → ' + rt.to : '') + ':</b>', '«' + tx + '»', '');
      });
      out.push('━━━━━━━━━━━━', '');
    } else out.push('🎯 <b>Action:</b> ' + act, '', '━━━━━━━━━━━━', '');
  });
  var restKeys = Object.keys(cd.rest);
  if (restKeys.length) { out.push('📌 <b>Не в деталях</b>'); restKeys.forEach(function(k){ out.push('• ' + k + ' ' + cd.rest[k].join(', ')); }); }
  return out.join(NLc).replace(/\n{3,}/g, NLc + NLc).trim();
}

let cardD = null; try { cardD = $('Build Request Body').first().json.cardData || null; } catch (e) { cardD = null; }
let t = cardD ? composeCard(cardD, raw) : validateReply(raw);   // B-17: мета-текст LLM і дублі версій
// Markdown → HTML (Telegram parse_mode HTML приймає лише обмежений набір тегів)
t = t.replace(/^[ \t]*-{3,}[ \t]*$/gm, '━━━━━━━━━━━━');
t = t.replace(/^#{1,6}[ \t]*(.+)$/gm, '<b>$1</b>');
t = t.replace(/\*\*([^*\n]+)\*\*/g, '<b>$1</b>').replace(/__([^_\n]+)__/g, '<b>$1</b>');
t = t.replace(/^[ \t]*[-*][ \t]+/gm, '• ').replace(/`([^`\n]+)`/g, '$1');
t = t.replace(/\n{3,}/g, '\n\n').trim();
// екранувати все, що не є дозволеним тегом (напр. «< 0%», «A & B»), інакше Telegram відхилить повідомлення
const ALLOWED = ['b', 'i', 'u', 's', 'code'];
t = t.replace(/&(?!(amp|lt|gt|quot);)/g, '&amp;');
t = t.replace(/<(\/?)([a-zA-Z0-9]+)[^>]*>|</g, function (m, slash, name) {
  if (name && ALLOWED.indexOf(name.toLowerCase()) >= 0) return '<' + slash + name.toLowerCase() + '>';
  return '&lt;';
});
// колір заголовка картки проєкту — лише з коду (⛔/🔴/🟡/🟢 з Build Request Body), не з LLM (рішення власника 29.10.2026)
let icons = {};
try { icons = $('Build Request Body').first().json.icons || {}; } catch (e) { icons = {}; }
t = t.replace(/^([ \t]*(?:\d+\.[ \t]*)?)(⛔|🔴|🟡|🟢)([ \t]*<b>[ \t]*)([A-Za-zА-Яа-яІіЇїЄєҐґ0-9_-]+)/gm, function (m, pre, emo, mid, id) {
  return pre + (icons[id] || emo) + mid + id;
});
// розбити на кілька повідомлень по межі між картками (ліміт Telegram 4096; B-28: дві дії на проєкт збільшують картку)
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
