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
function parseCardJson(s){
  var t = String(s).trim().replace(/^```(?:json)?/i, '').replace(/```\s*$/, '').trim();
  var i = t.indexOf('{'), j = t.lastIndexOf('}');
  if (i < 0 || j <= i) return null;
  try { var o = JSON.parse(t.slice(i, j + 1)); return (o && o.cards && typeof o.cards === 'object') ? o.cards : null; } catch (e) { return null; }
}
function composeCard(cd, rawText){
  var jc = parseCardJson(rawText) || {};
  var NLc = String.fromCharCode(10);
  var out = ['Станом на ' + cd.asOf, '', '📊 <b>Портфель:</b> ' + cd.total + ' проєктів', '🔴 ' + (cd.counts.red || 0), '🟡 ' + (cd.counts.yellow || 0), '🟢 ' + (cd.counts.green || 0), '⛔ блокер: ' + (cd.counts.blocked || 0)];
  if (cd.noFc && cd.noFc !== '—') out.push('Без прогнозу від ПМа: ' + cd.noFc);
  out.push('', '━━━━━━━━━━━━', '');
  cd.order.forEach(function(id){
    var c = cd.cards[id], j = jc[id] || {}, fb = false;
    var allowed = {}; cardNums(c.facts).forEach(function(n){ allowed[n] = 1; });
    function ok(v){ if (typeof v !== 'string' || !v.trim()) return null; var bad = cardNums(v).some(function(n){ return !allowed[n]; }); return bad ? null : v.trim().slice(0, 400); }
    var ins = ok(j.insight), imp = ok(j.impact), act = ok(j.action);
    if (imp && /ризик|погірш|зафіксу|залишаться|залишатися|залишиться|призвед|загроз|буде|будуть|може |можуть|ймовірно/i.test(imp)) imp = null;
    if (!ins) { ins = c.fbInsight; fb = true; }
    if (!act) { act = c.fbAction; fb = true; }
    out.push(c.icon + ' <b>' + id + '</b>', '', '⏱ <b>Години</b>');
    out = out.concat(c.hours);
    out.push('', '💰 <b>Гроші</b>');
    out = out.concat(c.money);
    out.push('', '🚧 <b>Проблеми</b>');
    out = out.concat(c.problems);
    out.push('', '💡 <b>Insight:</b> ' + ins);
    if (imp) out.push('⚠️ <b>Impact:</b> ' + imp);
    out.push('🎯 <b>Action:</b> ' + act, '', '━━━━━━━━━━━━', '');
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
// обрізати по межі абзацу (ліміт Telegram 4096)
if (t.length > 3900) { const cut = t.lastIndexOf('\n\n', 3850); t = (cut > 1500 ? t.slice(0, cut) : t.slice(0, 3850)) + '\n\n… (відповідь скорочено — уточніть питання, і я розгорну)'; }
// збалансувати теги
const stack = [];
t = t.replace(/<(\/?)(b|i|u|s|code)>/g, function (m, slash, name) {
  if (!slash) { stack.push(name); return m; }
  const idx = stack.lastIndexOf(name);
  if (idx < 0) return '';
  const out = stack.splice(idx).reverse().slice(0, -1).map(function (n) { return '</' + n + '>'; }).join('') ;
  return out + m;
});
while (stack.length) t += '</' + stack.pop() + '>';
return [{ json: { text: t } }];