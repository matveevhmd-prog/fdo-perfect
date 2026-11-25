// Вузол K6sm (W2.7), створено з scripts/koshtorys_parse/parse.js. Не редагувати тут: джерело — parse.js.
function parseVisit(values, inp) {
  var checks = [];
  var add = function (id, label, ok, where) { checks.push({ id: id, label: label, ok: !!ok, type: 'block', where: where || '' }); };
  var cell = function (r, c) { var row = (values || [])[r - 1] || []; var x = row[c]; return (x === undefined || x === '') ? null : x; };
  var n = function (r) { var x = cell(r, 1); if (x === null) return null; var k = Number(x); return isNaN(k) ? null : k; };
  var tol = function (a, b, t) { return a !== null && b !== null && Math.abs(a - b) <= t; };
  var r2 = function (x) { return x === null ? null : Math.round(x * 100) / 100; };
  var pid = inp.project_id;
  var parent = cell(2, 1);
  var visits = n(3), price = n(4), hours = n(5), rate = n(6), contract = n(7), hrsPlan = n(8), cost = n(9), profit = n(10), rent = n(11);
  add('A1', 'Вкладка належить договору ' + pid, cell(1, 0) === pid, 'A1');
  add('A2', 'Вказано основний проєкт (назва вкладки = проєкт-АН)', parent !== null && pid === String(parent) + '-АН', 'B2');
  add('A3', 'Виїздів, ціна, години на виїзд і ставка більші за 0', visits > 0 && price > 0 && hours > 0 && rate > 0, 'B3:B6');
  add('A4', 'Контракт дорівнює виїздів × ціна', tol(contract, visits * price, 1), 'B7');
  add('A5', 'Години дорівнюють виїздів × години на виїзд', tol(hrsPlan, visits * hours, 0.01), 'B8');
  add('A6', 'Собівартість дорівнює години × ставка', tol(cost, hrsPlan * rate, 1), 'B9');
  add('A7', 'Прибуток сходиться', tol(profit, (contract || 0) - (cost || 0), 1), 'B10');
  var ok = checks.every(function (c) { return c.ok; });
  var payload = {
    kind: 'visit', spreadsheet_id: inp.spreadsheet_id, sheet: inp.sheet,
    totals: { hours: hrsPlan, cost_internal: r2(cost), cost_sub: 0, contract: r2(contract) },
    visit: { visits: visits, price: price, hours: hours, rate: rate, cost: r2(cost), contract: r2(contract) }
  };
  return { ok: ok, kind: 'visit', checks: checks, errors: [], payload: payload, view: { parent: parent, visits: visits, price: price, hours: hours, contract: contract, rent_pct: rent === null ? null : Math.round(rent * 1000) / 10 } };
}

var inp = $('Normalize Input').item.json;
var base = { project_id: inp.project_id, company_id: inp.company_id, spreadsheet_id: inp.spreadsheet_id, sheet: inp.sheet, mode: inp.mode, telegram_user_id: inp.telegram_user_id };
if ($json.error || !$json.values) { return { json: Object.assign({}, base, { ok: false, kind: 'visit', read_error: true, checks: [], errors: [], payload: null }) }; }
var res = parseVisit($json.values, inp);
return { json: Object.assign({}, base, res) };
