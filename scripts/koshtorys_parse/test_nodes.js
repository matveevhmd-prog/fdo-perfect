// Офлайн-прогін кодів вузлів K6sm (preview/commit) з імітацією $ і $json.
var fs = require('fs'); var P = require('./parse.js');
var S = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
function run(file, dollar, json) { return new Function('$', '$json', fs.readFileSync(file, 'utf8'))(dollar, json); }
var inp = { project_id: 'DEMO-01', company_id: 'c', spreadsheet_id: 'F', sheet: 'DEMO-01', mode: 'preview', telegram_user_id: '1' };
var parsed = Object.assign({}, inp, P.parseStages(S['DEMO-01'], S['Графік_оплат'], inp));
var D = function (name) { return { item: { json: name === 'Parse And Validate' ? parsed : (name === 'Normalize Input' ? inp : null) } }; };
var dollar = function (name) { if (name === 'AN: Parse Visit') throw new Error('not executed'); return D(name); };
var R = { same_as_current: false, ok: true, version_id: 5, checks: [], warnings: [{ code: 'W-T2', text: 'Статус у файлі: Чернетка' }, { code: 'W-SECTION', text: 'Розділ поза довідником: X' }],
  diff: { from: { version_no: 1 }, to: { version_no: 2 }, delta: { contract: 0, hours: 8, bac: 1200.5, profit_pct_pp: -0.3 }, rows: [{ stage: 'МБР', section: 'ГП', who: 'Керівник проекту', change: 'changed', hours_from: 24, hours_to: 32 }] } };
var out = run('node_preview_text.js', dollar, { r: R }).json; console.log(out.ok); console.log(out.preview_text);
var o2 = run('node_preview_text.js', dollar, { r: { same_as_current: true, ok: true } }).json; console.log('--- same:', o2.ok, o2.preview_text.split('\n').slice(-2).join(' | '));
var bad = JSON.parse(JSON.stringify(S['DEMO-01'])); bad[10][5] = 5000;
parsed = Object.assign({}, inp, P.parseStages(bad, S['Графік_оплат'], inp));
var o3 = run('node_preview_text.js', dollar, {}).json; console.log('--- bad:', o3.ok); console.log(o3.preview_text.split('\n').filter(function (l) { return l.indexOf('❌') >= 0 || l.indexOf('⛔') >= 0; }).join('\n'));
var c = run('node_commit_result.js', dollar, { r: { status: 'approved', version_no: 2, schedule_rows: 4, plan: { hours: 592 } } }).json; console.log('--- commit:', c.ok, c.preview_text.split('\n')[0]);
var c2 = run('node_commit_result.js', dollar, { error: { message: 'koshtorys_approve: підсумки не збігаються' } }).json; console.log('--- commit err:', c2.ok, c2.preview_text.split('\n').pop());
