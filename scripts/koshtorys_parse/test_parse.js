// Офлайн-тест парсера на листах DEMO_M0.1_Koshtorys: node test_parse.js <sheets.json>
var fs = require('fs'); var P = require('./parse.js');
var S = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
var exp = { 'DEMO-01': [750000, 592, 348547.86, 200000], 'DEMO-02': [405000, 474, 279190.26, 45000], 'DEMO-03': [882000, 1108, 652405.79, 98000], 'DEMO-04': [549000, 642, 377881.59, 61000], 'DEMO-05': [1035000, 1300, 765560.19, 115000], 'DEMO-06': [288000, 337, 198495.05, 32000], 'DEMO-07': [702000, 882, 519277.18, 78000], 'DEMO-08': [945000, 1108, 652405.79, 105000], 'DEMO-09': [468000, 549, 323433.6, 52000], 'DEMO-10': [801000, 938, 552155.52, 89000] };
var expV = { 'DEMO-01-АН': [75000, 50, 55213.5], 'DEMO-04-АН': [75000, 50, 55213.5], 'DEMO-05-АН': [75000, 50, 55213.5], 'DEMO-08-АН': [75000, 50, 55213.5] };
var pass = 0, fail = 0;
function t(name, cond, extra) { if (cond) { pass++; } else { fail++; console.log('ПРОВАЛ:', name, extra || ''); } }
var clone = function (x) { return JSON.parse(JSON.stringify(x)); };
function inp(pid) { return { project_id: pid, spreadsheet_id: 'F', sheet: pid }; }
function failedIds(res) { return res.checks.filter(function (c) { return !c.ok && c.type !== 'warn'; }).map(function (c) { return c.id; }); }
// Позитивні: 10 листів проєктів
Object.keys(exp).forEach(function (pid) {
  var res = P.parseStages(S[pid], S['Графік_оплат'], inp(pid)); var e = exp[pid]; var p = res.payload;
  var sumH = 0, sumC = 0, sumS = 0; p.rows.forEach(function (r) { sumH += r.hours || 0; sumC += r.cost || 0; sumS += r.sub || 0; });
  t(pid + ' ok', res.ok, JSON.stringify(failedIds(res)) + JSON.stringify(res.errors));
  t(pid + ' контракт', p.totals.contract === e[0], p.totals.contract);
  t(pid + ' години W1', p.totals.hours === e[1], p.totals.hours);
  t(pid + ' Σ годин рядків = W1', Math.abs(sumH - e[1]) < 0.01, sumH);
  t(pid + ' команда G7', Math.abs(p.totals.cost_internal - e[2]) < 1, p.totals.cost_internal);
  t(pid + ' Σ вартості рядків ≈ G7', Math.abs(sumC - e[2]) < 1, sumC);
  t(pid + ' субпідряд H7 і Σ рядків', Math.abs(p.totals.cost_sub - e[3]) < 1 && Math.abs(sumS - e[3]) < 1, p.totals.cost_sub + '/' + sumS);
  t(pid + ' 12 рядків', p.rows.length === 12, p.rows.length);
  t(pid + ' T2', p.status === 'Чернетка', p.status);
  t(pid + ' рядок АН з 0 год прийнято', p.rows.some(function (r) { return r.stage === 'АН' && r.hours === 0; }));
  t(pid + ' графік', p.schedule.length > 0, p.schedule.length);
});
// Позитивні: 4 листи нагляду
Object.keys(expV).forEach(function (pid) {
  var res = P.parseVisit(S[pid], inp(pid)); var e = expV[pid];
  t(pid + ' ok', res.ok, JSON.stringify(failedIds(res)));
  t(pid + ' контракт/години/вартість', res.payload.totals.contract === e[0] && res.payload.totals.hours === e[1] && Math.abs(res.payload.totals.cost_internal - e[2]) < 0.01, JSON.stringify(res.payload.totals));
});
// Негативні фікстури на DEMO-01
var base = S['DEMO-01'], G = S['Графік_оплат'], pid = 'DEMO-01';
var neg = function (name, mut, expectId) {
  var sh = clone(base); mut(sh); var res = P.parseStages(sh, G, inp(pid));
  t('НЕГ ' + name + ' → блок ' + expectId, !res.ok && failedIds(res).indexOf(expectId) >= 0, JSON.stringify(failedIds(res)));
};
neg('години і субпідряд в одному рядку', function (s) { s[10][5] = 5000; }, 'K12');            // рядок 11: D=24 і F=5000
neg('рядок без годин і без грошей', function (s) { s[19][5] = ''; }, 'K12');                   // рядок 20 підрядника: F прибрано
neg('субпідряд без назви підрядника', function (s) { s[19][2] = ''; }, 'K12');
neg('немає рядка TOTAL стадії П', function (s) { s[20][1] = 'не TOTAL'; }, 'K2');
neg('годин у TOTAL ≠ сумі рядків', function (s) { s[12][3] = 99; }, 'K13');
neg('невідомий контракт D7', function (s) { s[6][3] = 123; }, 'K3');
neg('чужа вкладка', function (s) { s[0][0] = 'DEMO-99'; }, 'K1');
neg('ставка 0', function (s) { s[4][0] = 0; }, 'K8');
neg('файл більший за діапазон', function (s) { while (s.length < 300) s.push([]); s[299] = ['x']; }, 'K14');
// Додатковий рядок усередині блоку (вставка в рядок 12): старий парсер з номерами рядків ламався, новий має пройти, якщо суми оновлено
(function () {
  var sh = clone(base);
  sh.splice(11, 0, ['', 'ГІП', 'ГІП', 10, 5000, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 'МБР']);
  sh[13][3] = 50; sh[13][4] = sh[13][4] + 5000;                         // TOTAL МБР тепер у рядку 14
  var res = P.parseStages(sh, G, inp(pid));
  t('Додатковий рядок у блоці: блоки знайдено без зашитих номерів', res.payload.rows.length === 13 && !failedIds(res).some(function (x) { return x === 'K2' || x === 'K12' || x === 'K13'; }), JSON.stringify(failedIds(res)));
})();
// Нагляд: негативні
var nv = function (name, mut, id) { var v = clone(S['DEMO-01-АН']); mut(v); var res = P.parseVisit(v, inp('DEMO-01-АН')); t('НЕГ нагляд ' + name + ' → ' + id, !res.ok && failedIds(res).indexOf(id) >= 0, JSON.stringify(failedIds(res))); };
nv('контракт ≠ виїзди × ціна', function (v) { v[6][1] = 80000; }, 'A4');
nv('немає основного проєкту', function (v) { v[1][1] = ''; }, 'A2');
console.log('пройшло:', pass, 'провалів:', fail);
process.exit(fail ? 1 : 0);
