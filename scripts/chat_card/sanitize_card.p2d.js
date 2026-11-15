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
