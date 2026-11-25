// Вузол K6sm «Commit Result» (W2.7): результат koshtorys_commit_draft.
var inp = $('Normalize Input').item.json;
var NL = String.fromCharCode(10);
var esc = function (s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); };
var r = $json.r;
var pid = inp.project_id;
if ($json.error || !r) {
  var msg = String(($json.error && ($json.error.message || $json.error)) || 'невідома помилка').slice(0, 300);
  return { json: { ok: false, committed: false, project_id: pid, preview_text: '⛔ <b>План ' + esc(pid) + ' не записано</b>' + NL + NL + esc(msg) } };
}
if (r.status === 'no_draft') { return { json: { ok: false, committed: false, project_id: pid, preview_text: '⛔ <b>План ' + esc(pid) + ' не записано</b>' + NL + NL + esc(r.message) } }; }
if (r.status === 'already_approved') { return { json: { ok: true, committed: false, project_id: pid, preview_text: 'ℹ️ <b>План ' + esc(pid) + ' уже затверджено</b>' } }; }
var h = r.plan && r.plan.hours;
return { json: { ok: true, committed: true, project_id: pid, planned_hours: h, version_no: r.version_no, preview_text: '✅ <b>План ' + esc(pid) + ' затверджено, версія ' + esc(r.version_no) + '</b>' + NL + NL + '⏱ Години (план): ' + esc(h) + ' год' + NL + '📅 Рядків графіка: ' + esc(r.schedule_rows) + NL + NL + 'ℹ️ Факт і тижневі звіти не змінено.' } };
