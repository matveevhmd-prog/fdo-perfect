// Вузол K6sm «Preview Text» (W2.7): текст перегляду з результатів розбору файлу й koshtorys_ingest_draft. Без LLM, числа лише з SQL і парсера.
var P = null;
try { P = $('Parse And Validate').item.json; } catch (e) { P = null; }
if (!P) { try { P = $('AN: Parse Visit').item.json; } catch (e2) { P = null; } }
var R = ($json && $json.r) ? $json.r : null;
var NL = String.fromCharCode(10);
var esc = function (s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); };
var fmt = function (n) { if (n === null || n === undefined) return '—'; var s = String(Math.round(Number(n))); return s.replace(/[0-9](?=([0-9]{3})+$)/g, '$& '); };
var dd = function (iso) { var p = String(iso).split('-'); return p[2] + '.' + p[1] + '.' + p[0]; };
var sg = function (n) { var x = Math.round(Number(n) * 100) / 100; return (x > 0 ? '+' : '') + String(x).replace('.', ','); };
if (!P) { return { json: { ok: false, preview_text: '⛔ <b>Кошторис не розібрано</b>' } }; }
var pid = P.project_id;
if (P.read_error) { return { json: { ok: false, project_id: pid, preview_text: '⛔ <b>Не вдалося прочитати Кошторис</b>' + NL + NL + 'Вкладку «' + esc(P.sheet) + '» не знайдено або немає доступу до файлу.' } }; }
var L = [];
var v = P.view || {};
L.push('📐 <b>Кошторис ' + esc(pid) + ' — перегляд</b>');
L.push('');
L.push('💰 <b>Гроші</b>');
L.push('• Контракт (без ПДВ): ' + fmt(v.contract) + ' грн');
L.push('• Рентабельність_план: ' + (v.rent_pct === null || v.rent_pct === undefined ? '—' : v.rent_pct + '%'));
if (P.kind === 'visit') { L.push('• Ціна виїзду: ' + fmt(v.price) + ' грн'); }
L.push('');
if (P.kind === 'stages') {
  L.push('⏱ <b>Години (план): ' + fmt(v.hours) + ' год</b>');
  ['МБР', 'ЕП', 'П', 'Р', 'АН'].forEach(function (s) { L.push('• ' + s + ': ' + (v.stages ? v.stages[s] : '—')); });
} else {
  L.push('⏱ <b>Години (план): ' + fmt(P.payload ? P.payload.totals.hours : null) + ' год</b>');
  L.push('• Виїздів: ' + fmt(v.visits));
  L.push('• Годин на виїзд: ' + fmt(v.hours));
}
L.push('');
var ok = !!(P.ok && R && R.ok && !R.same_as_current);
if (R) {
  L.push('🔄 <b>Що зміниться</b>');
  if (R.same_as_current) { L.push('• Змін немає: файл збігається з чинною затвердженою версією'); }
  else if (!R.diff) { L.push('• Це перша версія Кошториса проєкту'); }
  else {
    var d = R.diff.delta || {};
    L.push('• Версія ' + esc(R.diff.from.version_no) + ' → ' + esc(R.diff.to.version_no));
    L.push('• Контракт: ' + sg(d.contract) + ' грн');
    L.push('• Години: ' + sg(d.hours));
    L.push('• Собівартість: ' + sg(d.bac) + ' грн');
    L.push((Number(d.profit_pct_pp) < 0 ? '🔴 ' : '🟢 ') + 'Рентабельність: ' + sg(d.profit_pct_pp) + ' п.п.');
    var rows = R.diff.rows || [];
    rows.slice(0, 5).forEach(function (x) {
      var hf = x.hours_from, ht = x.hours_to;
      var what = x.change === 'added' ? 'додано' : (x.change === 'removed' ? 'прибрано' : 'змінено');
      L.push('• ' + esc(x.stage) + ' · ' + esc(x.section) + ' · ' + esc(x.who) + ': ' + what + (hf !== null || ht !== null ? ' (' + (hf === null ? '—' : hf) + ' → ' + (ht === null ? '—' : ht) + ' год)' : ''));
    });
    if (rows.length > 5) { L.push('• … ще рядків: ' + (rows.length - 5)); }
  }
  L.push('');
}
if (P.kind === 'stages' && v.acts) {
  L.push('📅 <b>Підписання актів (план)</b>');
  if (v.acts.length) { v.acts.forEach(function (a, i) { if (i) L.push(''); L.push('<b>Стадія ' + esc(a['стадія']) + '</b>'); L.push('• Дата акту: ' + dd(a['дата_план'])); L.push('• Ймовірність підписання: ' + (a['ймовірність_план'] ? a['ймовірність_план'] + ' з 10' : '—')); }); } else { L.push('• немає'); }
  L.push('');
  L.push('📄 <b>Видача документації (план)</b>');
  if (v.docs.length) { v.docs.forEach(function (a, i) { if (i) L.push(''); L.push('<b>Стадія ' + esc(a['стадія']) + '</b>'); L.push('• Дедлайн видачі: ' + dd(a['дата_план'])); L.push('• Ймовірність видачі: ' + (a['ймовірність_план'] ? a['ймовірність_план'] + ' з 10' : '—')); }); } else { L.push('• немає'); }
  L.push('');
}
L.push('🔍 <b>Перевірки</b>');
(P.checks || []).forEach(function (c) { L.push((c.ok ? '✅' : (c.type === 'warn' ? '⚠️' : '❌')) + ' ' + esc(c.label) + (!c.ok && c.where ? ' — ' + esc(c.where) : '')); });
if (R && R.checks) { R.checks.forEach(function (c) { if (!c.ok) { L.push('❌ Підсумок файлу не збігається з рядками: ' + esc(c.name) + ' (файл ' + esc(c.file) + ', рядки ' + esc(c.rows) + ')'); } }); }
if (R && R.warnings) { R.warnings.forEach(function (w) { if (w.code === 'W-T2' && P.kind === 'visit') return; L.push('⚠️ ' + esc(w.text)); }); }
L.push('');
if (R && R.same_as_current) { L.push('🎯 <b>Що зробити:</b> нічого, змін у файлі немає.'); }
else if (ok) { L.push('🎯 <b>Що зробити:</b> надішліть «затвердити», щоб записати план, або «скасувати».'); }
else { L.push('⛔ <b>Запис неможливий:</b> виправте Кошторис і надішліть команду ще раз.'); }
return { json: { ok: ok, project_id: pid, kind: P.kind, version_id: R ? R.version_id : null, mode: P.mode, preview_text: L.join(NL) } };
