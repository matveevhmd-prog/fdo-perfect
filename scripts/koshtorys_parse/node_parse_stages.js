// Вузол K6sm (W2.7), створено з scripts/koshtorys_parse/parse.js. Не редагувати тут: джерело — parse.js.
function parseStages(sheetVals, grafVals, inp) {
  var checks = [];
  var add = function (id, label, ok, type, where) { checks.push({ id: id, label: label, ok: !!ok, type: type || 'block', where: where || '' }); };
  var colIdx = function (L) { var n = 0; for (var i = 0; i < L.length; i++) { n = n * 26 + (L.charCodeAt(i) - 64); } return n - 1; };
  var cellAt = function (ref) {
    var m = ref.match(/^([A-Z]+)([0-9]+)$/);
    var row = sheetVals[parseInt(m[2], 10) - 1] || [];
    var v = row[colIdx(m[1])];
    return (v === undefined || v === '') ? null : v;
  };
  var numAt = function (ref) { var v = cellAt(ref); if (v === null) return null; var n = Number(v); return isNaN(n) ? null : n; };
  var isNum = function (v) { return typeof v === 'number' && !isNaN(v); };
  var r2 = function (n) { return n === null ? null : Math.round(n * 100) / 100; };
  var tol = function (a, b, t) { return a !== null && b !== null && Math.abs(a - b) <= t; };
  var STAGES = ['МБР', 'ЕП', 'П', 'Р', 'АН'];
  var pid = inp.project_id;

  add('K1', 'Вкладка належить проєкту ' + pid, cellAt('A1') === pid, 'block', 'A1');

  // 1. Блоки стадій за маркером TOTAL (колонка B). Рядки даних — від рядка 10 (заголовки в 9).
  var rows = [];
  var errs = [];
  var blocks = {};
  var dupStage = false, unknownStage = false;
  var start = 10;
  for (var r = 10; r <= sheetVals.length; r++) {
    var row = sheetVals[r - 1] || [];
    var B = row[1];
    if (B === 'TOTAL') {
      var st = row[0];
      if (STAGES.indexOf(st) < 0) { unknownStage = true; add('K2a', 'Невідома стадія в рядку TOTAL', false, 'block', 'A' + r); start = r + 1; continue; }
      if (blocks[st]) { dupStage = true; }
      var sumD = 0, sumE = 0, sumF = 0, nrows = 0;
      for (var q = start; q < r; q++) {
        var rw = sheetVals[q - 1] || [];
        var sec = rw[1], exe = rw[2], D = rw[3], E = rw[4], F = rw[5];
        var empty = (sec === undefined || sec === '') && (exe === undefined || exe === '') && (D === undefined || D === '') && (F === undefined || F === '');
        if (empty) continue;
        var hasD = isNum(D), hasF = isNum(F) && F > 0;
        var bad = '';
        if (hasD && D > 0 && hasF) { bad = 'години в D' + q + ' і субпідряд у F' + q + ' в одному рядку (правило J2)'; }
        else if (!hasD && !hasF) { bad = 'немає ні годин (D' + q + '), ні суми субпідряду (F' + q + ')'; }
        else if (hasD && hasF) { bad = 'D' + q + ' = 0 і F' + q + ' > 0 в одному рядку (правило J2)'; }
        else if (hasF && (exe === undefined || exe === '')) { bad = 'субпідряд без назви підрядника (C' + q + ')'; }
        if (bad) { errs.push({ row: q, text: 'Рядок ' + q + ': ' + bad }); continue; }
        rows.push({ stage: st, section: (sec === undefined || sec === '') ? null : String(sec), executor: (exe === undefined || exe === '') ? null : String(exe),
                    hours: hasD ? D : null, cost: hasD ? (isNum(E) ? E : null) : null, sub: hasD ? null : F, src_row: q });
        if (hasD && !isNum(E)) { errs.push({ row: q, text: 'Рядок ' + q + ': немає вартості внутрішньої (E' + q + ')' }); }
        nrows++;
        sumD += hasD ? D : 0; sumE += isNum(E) && hasD ? E : 0; sumF += hasF ? F : 0;
      }
      var tD = isNum(row[3]) ? row[3] : 0, tE = isNum(row[4]) ? row[4] : 0, tF = isNum(row[5]) ? row[5] : 0;
      blocks[st] = { total_row: r, rows: nrows, hours: tD, sum_hours: sumD, cost: tE, sum_cost: sumE, sub: tF, sum_sub: sumF };
      start = r + 1;
    }
  }
  add('K2', 'Усі п\'ять стадій (МБР, ЕП, П, Р, АН) на місці, кожна один раз', STAGES.every(function (s) { return !!blocks[s]; }) && !dupStage && !unknownStage, 'block', 'колонка B: TOTAL');
  add('K12', 'Кожен рядок — або години команди, або гроші підрядника', errs.length === 0, 'block', errs.slice(0, 3).map(function (e) { return e.text; }).join('; '));
  var blockOk = true, blockWhere = '';
  STAGES.forEach(function (s) {
    var b = blocks[s]; if (!b) return;
    if (!tol(b.hours, b.sum_hours, 0.01) || !tol(b.cost, b.sum_cost, 1) || !tol(b.sub, b.sum_sub, 1)) {
      blockOk = false; blockWhere += (blockWhere ? '; ' : '') + 'стадія ' + s + ' (рядок ' + b.total_row + '): рядки ' + r2(b.sum_hours) + ' год / ' + r2(b.sum_cost) + ' / ' + r2(b.sum_sub) + ', TOTAL ' + r2(b.hours) + ' / ' + r2(b.cost) + ' / ' + r2(b.sub);
    }
  });
  add('K13', 'Сума рядків кожної стадії дорівнює її TOTAL', blockOk, 'block', blockWhere);
  var lastRowNonEmpty = sheetVals.length >= 300 && (sheetVals[299] || []).some(function (x) { return x !== '' && x !== undefined; });
  add('K14', 'Файл вміщується в діапазон читання (300 рядків)', !lastRowNonEmpty, 'block', 'A1:X300');

  // 2. Шапка: рядки 2–6 стадій, TOTAL рядок 7 (мануал §3).
  var sumH = function (col, a, b) { var s = 0; for (var i = a; i <= b; i++) { s += numAt(col + i) || 0; } return s; };
  var D7 = numAt('D7'), E7 = numAt('E7'), F7 = numAt('F7'), G7 = numAt('G7'), H7 = numAt('H7'), A3 = numAt('A3'), A5 = numAt('A5'), W1 = numAt('W1');
  add('K3', 'Контракт > 0 і дорівнює сумі стадій', D7 > 0 && tol(D7, sumH('D', 2, 6), 1), 'block', 'D7');
  add('K4', 'Собівартість сходиться (команда + субпідряд)', tol(G7, sumH('G', 2, 6), 1) && tol(H7, sumH('H', 2, 6), 1) && tol(E7, (G7 || 0) + (H7 || 0), 1), 'block', 'E7, G7, H7');
  add('K5', 'Прибуток і рентабельність сходяться', tol(F7, (D7 || 0) - (E7 || 0), 1) && D7 > 0 && tol(A3, F7 / D7, 0.0005), 'block', 'F7, A3');
  var hoursStage = {}, hoursAll = 0;
  STAGES.forEach(function (s) { hoursStage[s] = blocks[s] ? blocks[s].hours : 0; hoursAll += hoursStage[s]; });
  add('K6', 'План годин (W1) дорівнює сумі стадій', tol(W1, hoursAll, 0.5), 'block', 'W1');
  add('K7', 'Години МБР, ЕП, П, Р більші за 0', hoursStage['МБР'] > 0 && hoursStage['ЕП'] > 0 && hoursStage['П'] > 0 && hoursStage['Р'] > 0, 'block', 'TOTAL стадій');
  add('K8', 'Ставка більша за 0', A5 > 0, 'block', 'A5');

  // 3. Графік оплат (без змін відносно K9–K11 старої версії).
  var hdr = (grafVals[0] || []).map(function (x) { return String(x === undefined || x === null ? '' : x).trim(); });
  var ci = function (n) { return hdr.indexOf(n); };
  var cP = ci('ProjectID'), cS = ci('Стадія'), cD = ci('Дата_план'), cSum = ci('Сума_план'), cPr = ci('Ймовірність_10'), cSt = ci('Статус'), cM = ci('Дедлайн_документації_план'), cN = ci('Ймовірність_видачі_10');
  var schedule = [], badRows = 0;
  var okProb = function (p) { return p === undefined || p === '' || p === null || (typeof p === 'number' && p >= 1 && p <= 10); };
  var serialToISO = function (n) { return new Date(Date.UTC(1899, 11, 30) + Math.round(n) * 86400000).toISOString().slice(0, 10); };
  grafVals.slice(1).forEach(function (rw) {
    if (!rw || rw[cP] !== pid) return;
    var stg = rw[cS], d = rw[cD], p = rw[cPr];
    if (STAGES.indexOf(stg) < 0 || typeof d !== 'number' || !okProb(p)) { badRows++; return; }
    schedule.push({ 'стадія': stg, 'подія': 'акт', 'дата_план': serialToISO(d), 'сума_план': typeof rw[cSum] === 'number' ? rw[cSum] : null, 'ймовірність_план': typeof p === 'number' ? Math.round(p) : null, 'статус_план': rw[cSt] || null });
    var m = cM >= 0 ? rw[cM] : undefined;
    if (typeof m === 'number') {
      var n = rw[cN];
      if (!okProb(n)) { badRows++; return; }
      schedule.push({ 'стадія': stg, 'подія': 'документація', 'дата_план': serialToISO(m), 'сума_план': null, 'ймовірність_план': typeof n === 'number' ? Math.round(n) : null, 'статус_план': null });
    }
  });
  var acts = schedule.filter(function (x) { return x['подія'] === 'акт'; });
  var docs = schedule.filter(function (x) { return x['подія'] === 'документація'; });
  add('K9', 'Графік оплат: є акти, дати й ймовірності коректні', cP >= 0 && acts.length > 0 && badRows === 0, 'block', 'аркуш Графік_оплат');
  add('K10', 'Є дедлайни документації', docs.length > 0, 'warn', '');
  var actSum = acts.reduce(function (a, x) { return a + (x['сума_план'] || 0); }, 0);
  add('K11', 'Сума актів не більша за контракт з ПДВ', actSum <= (D7 || 0) * 1.2 + 1, 'warn', '');

  var ok = checks.every(function (c) { return c.ok || c.type === 'warn'; });
  var stages4 = {}; ['МБР', 'ЕП', 'П', 'Р'].forEach(function (s) { stages4[s] = hoursStage[s]; });
  var status = cellAt('T2');
  var payload = {
    kind: 'stages', spreadsheet_id: inp.spreadsheet_id, sheet: inp.sheet, status: status, contract: r2(D7), rate: A5,
    totals: { hours: W1, cost_internal: r2(G7), cost_sub: r2(H7), contract: r2(D7), hours_by_stage: stages4 },
    rows: rows, schedule: schedule
  };
  return { ok: ok, kind: 'stages', checks: checks, errors: errs, payload: payload, view: { contract: D7, rent_pct: A3 === null ? null : Math.round(A3 * 1000) / 10, hours: W1, stages: hoursStage, acts: acts, docs: docs } };
}


var inp = $('Normalize Input').item.json;
var base = { project_id: inp.project_id, company_id: inp.company_id, spreadsheet_id: inp.spreadsheet_id, sheet: inp.sheet, mode: inp.mode, telegram_user_id: inp.telegram_user_id };
if ($json.error || !$json.valueRanges) { return { json: Object.assign({}, base, { ok: false, kind: 'stages', read_error: true, checks: [], errors: [], payload: null }) }; }
var vr = $json.valueRanges;
var res = parseStages((vr[0] && vr[0].values) || [], (vr[1] && vr[1].values) || [], inp);
return { json: Object.assign({}, base, res) };
