// Тести вузла `WR: Parse Agent Output` (варіант Б, CLAUDE.md п. 9; RELEASE_PLAN §104–§111).
// Запуск: node tests/wr_parse_agent_output/run.js   (без залежностей; код вузла береться з workflows/DEMO_Archi_Agent_Core.json)
// Це тести логіки на макеті (fixture), не live-даних.
const fs = require('fs');
const path = require('path');
const wf = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'workflows', 'DEMO_Archi_Agent_Core.json'), 'utf8'));
const node = wf.nodes.find(function (n) { return n.name === 'WR: Parse Agent Output'; });
if (!node) { console.error('FAIL: вузол WR: Parse Agent Output не знайдено'); process.exit(2); }
const CODE = node.parameters.jsCode;

const PLAN = { 'МБР': 100, 'ЕП': 210, 'П': 337, 'Р': 486 };             // ETC_план по стадіях (макет)
const HOURS = { 'МБР': 100, 'ЕП': 247, 'П': 257, 'Р': 41 };              // actual_hours_live: дає розбіжність < 20 п.п. у сценарії «Фінал»
const SD = {}; Object.keys(HOURS).forEach(function (k) { SD[k] = { actual_hours_live: HOURS[k] }; });

function run(opts) {
  const fi = { mem_text: opts.src || '', inbox_text: '' };
  const data = {
    'WR: Fetch Inbox': fi,
    'WR: Build WR Prompt': { auto: { stages: opts.planDl || {} }, act_probability_auto: 3 },
    'WR: Fetch Project Metrics Static': { etc_plan_by_stage: opts.plan === undefined ? PLAN : opts.plan, stage_data: opts.stageData || {} },
    'WR: Hard Logic Engine': { execution_mode: opts.mode || 'send_inbox', project_id: 'DEMO-03', payload: '' }
  };
  const $ = function (name) { return { first: function () { return { json: data[name] || {} }; }, all: function () { return []; } }; };
  const $now = { startOf: function () { return { plus: function () { return { toFormat: function () { return '2026-10-26'; } }; } }; } };
  const $input = { first: function () { return { json: { output: JSON.stringify(opts.out) } }; } };
  return new Function('$', '$input', '$now', CODE)($, $input, $now)[0].json;
}
const clone = function (o) { return JSON.parse(JSON.stringify(o)); };
function unsupported(r) {
  const b = (r.pre_blocks || []).find(function (x) { return x.indexOf('Не підтверджено вашим текстом') >= 0; });
  return b ? b.split('\n').filter(function (l) { return l.indexOf('• ') === 0; }).map(function (l) { return l.slice(2); }) : [];
}
const GOOD = {
  stage_readiness: { 'МБР': 100, 'ЕП': 95, 'П': 70, 'Р': 10 },
  etc_forecast_hours_stage: { 'МБР': 0, 'ЕП': 13, 'П': 110, 'Р': 370 },
  deadline_forecast_stage: { 'ЕП': '2026-11-06', 'П': '2026-11-20', 'Р': '2026-11-30' },
  doc_probability: 8, blocker_types: [], blocker_since: null, plans_next_week: '1) закрити ЕП; 2) почати Р'
};
const FULL = 'МБР завершено\nЕП 95%, годин ще 13, дедлайн 06.11.2026\nП 70%, годин ще 110, дедлайн 20.11.2026\nР 10%, годин ще 370, дедлайн 30.11.2026\nДокументація 8\nБлокера немає\nПлан: 1) закрити ЕП; 2) почати Р';
const mk = function (patch) { return Object.assign(clone(GOOD), patch || {}); };

let pass = 0, fail = 0;
function t(name, cond, info) { if (cond) { pass++; } else { fail++; console.log('FAIL  ' + name + (info !== undefined ? '  → ' + JSON.stringify(info) : '')); } }
const has = function (list, s) { return list.some(function (x) { return x.indexOf(s) >= 0; }); };

// 1. Повний коректний текст — нічого не відхиляється
let r = run({ src: FULL, out: clone(GOOD) });
t('01 повний текст: 0 відхилень', unsupported(r).length === 0, unsupported(r));
t('01 готовність збережена', r.stage_readiness && r.stage_readiness['ЕП'] === 95 && r.stage_readiness['Р'] === 10, r.stage_readiness);
t('01 ETC_прогноз разом 493', r.etc_total_forecast === 493, r.etc_total_forecast);
t('01 блокер «немає» прийнято', r.blocker && Array.isArray(r.blocker.types) && r.blocker.types.length === 0, r.blocker);

// 2. Вигадані значення відхиляються
let o = clone(GOOD); o.stage_readiness['ЕП'] = 97; o.etc_forecast_hours_stage['Р'] = 400; o.deadline_forecast_stage['П'] = '2026-11-25'; o.doc_probability = 9;
r = run({ src: FULL, out: o }); let u = unsupported(r);
t('02 вигадані 4 значення відхилено', has(u, 'готовність ЕП') && has(u, 'ETC_прогноз Р') && has(u, 'дедлайн П') && has(u, 'документації'), u);
t('02 правдиві значення лишились', r.stage_readiness['П'] === 70 && r.etc_forecast_stage['ЕП'] === 13, r.stage_readiness);

// 3. Порожній текст ПМа — відхиляється все
r = run({ src: '', out: clone(GOOD) }); u = unsupported(r);
t('03 порожній текст: готовність, ETC, дедлайни, документація відхилено', has(u, 'готовність ЕП') && has(u, 'ETC_прогноз П') && has(u, 'дедлайн Р') && has(u, 'документації'), u);

// 4. Дати словами і «без змін» для планової дати
o = mk({ deadline_forecast_stage: { 'ЕП': '2026-11-06', 'П': '2026-11-20', 'Р': '2026-11-30' } });
r = run({ src: 'Дедлайн ЕП 6 листопада, П 20 листопада, Р без змін. ЕП 95, П 70, Р 10, МБР завершено. Годин: ЕП 13, П 110, Р 370. Документація 8. Блокера немає', out: o, planDl: { 'Р': { deadlinePlanDate: '2026-11-30T00:00:00.000Z' } } });
t('04 дати словами й «без змін» прийнято', unsupported(r).length === 0, unsupported(r));

// 5. Десяткові через кому
r = run({ src: 'ЕП ще 13,5 годин; готовність 95,5%', out: { stage_readiness: { 'ЕП': 95.5 }, etc_forecast_hours_stage: { 'ЕП': 13.5 } } });
t('05 десяткові 13,5 і 95,5 прийнято', unsupported(r).length === 0, unsupported(r));

// 6. День і місяць дати не підтверджують число годин і відсотків
r = run({ src: 'дедлайн ЕП 13.11.2026', out: { stage_readiness: { 'ЕП': 11 }, etc_forecast_hours_stage: { 'ЕП': 13 } } });
t('06 13.11 не підтверджує 13 год і 11%', has(unsupported(r), 'готовність ЕП') && has(unsupported(r), 'ETC_прогноз ЕП'), unsupported(r));

// 7. Привʼязка до стадії: слова нуль/завершено/без змін діють лише по назві стадії
const base = 'ЕП 95%, годин ЕП 13\nП 70, годин П 110\nР 10, годин Р 370\nДокументація 8\n';
const MB = function (extra) { return run({ src: base + extra, out: mk({ blocker_types: [] }) }); };
u = unsupported(MB('Блокера немає'));
t('07a «Блокера немає» не підтверджує МБР 100% і ETC МБР 0', has(u, 'готовність МБР') && has(u, 'ETC_прогноз МБР'), u);
u = unsupported(MB('МБР завершено\nБлокера немає'));
t('07b «МБР завершено» підтверджує МБР', !has(u, 'МБР'), u);
u = unsupported(run({ src: base + 'ЕП завершено\nБлокера немає', out: mk() }));
t('07c «ЕП завершено» не підтверджує МБР', has(u, 'готовність МБР'), u);
u = unsupported(run({ src: base + 'по МБР годин нема\nБлокера немає', out: mk() }));
t('07d «по МБР годин нема» підтверджує ETC МБР 0, але не готовність 100%', !has(u, 'ETC_прогноз МБР') && has(u, 'готовність МБР'), u);
const dl = mk(); const PD = { 'Р': { deadlinePlanDate: '2026-11-30T00:00:00.000Z' } };
u = unsupported(run({ src: 'МБР завершено\nЕП 95, П 70, Р 10\nГодин ЕП 13, П 110, Р 370\nДедлайн ЕП 06.11.2026, дедлайн П 20.11.2026, дедлайн Р без змін\nДокументація 8\nБлокера немає', out: dl, planDl: PD }));
t('07e «дедлайн Р без змін» підтверджує плановий дедлайн Р', !has(u, 'дедлайн Р'), u);
u = unsupported(run({ src: 'МБР завершено\nЕП 95, П 70, Р 10\nГодин ЕП 13, П 110, Р 370\nДедлайн ЕП без змін, дедлайн П 20.11.2026, дедлайн ЕП 06.11.2026\nДокументація 8\nБлокера немає', out: mk(), planDl: PD }));
t('07f «без змін» про ЕП не підтверджує дедлайн Р', has(u, 'дедлайн Р'), u);

// 8. Блокер: «немає» / є / тип / дата — лише зі слів ПМа
const BB = 'МБР завершено\nЕП 95%, годин ЕП 13\nП 70%, годин П 110\nР 10%, годин Р 370\nДокументація 8\n';
const bl = function (txt, types, since) { return unsupported(run({ src: BB + txt, out: mk({ blocker_types: types, blocker_since: since }) })).filter(function (l) { return l.indexOf('блокер') >= 0; }); };
t('08a «Блокера немає» → прийнято', bl('Блокера немає', [], null).length === 0);
t('08b LLM вигадав «немає» без слів ПМа → відхилено', bl('План: 1) закрити ЕП', [], null).length === 1);
t('08c LLM вигадав блокер «гроші» при «Блокера немає» → відхилено', bl('Блокера немає', ['гроші'], '2026-10-20').length >= 1);
t('08d «Є блокер: чекаємо оплату з 20.10.2026» + гроші → прийнято', bl('Є блокер: чекаємо оплату з 20.10.2026', ['гроші'], '2026-10-20').length === 0);
t('08e тип «люди» без слів про людей → відхилено', has(bl('Є блокер: чекаємо оплату з 20.10.2026', ['гроші', 'люди'], '2026-10-20'), 'люди'));
t('08f «Нічого не зупиняє роботу» → «немає» прийнято', bl('Нічого не зупиняє роботу', [], null).length === 0);
t('08g дата блокера не з тексту → відхилено', has(bl('Є блокер: чекаємо оплату', ['гроші'], '2026-10-20'), 'з дати'));

// 9. Стадія поза договором (ETC_план 0): не питається і не шумить у «не підтверджено»
u = unsupported(run({ src: 'ЕП 95%, годин ЕП 13\nП 70%, годин П 110\nР 10%, годин Р 370\nБлокера немає', out: mk({ stage_readiness: { 'МБР': 100, 'ЕП': 95, 'П': 70, 'Р': 10 } }), plan: { 'МБР': 0, 'ЕП': 210, 'П': 337, 'Р': 486 } }));
t('09 МБР поза договором не потрапляє в «не підтверджено»', !has(u, 'МБР'), u);

// 10. План наступного тижня ділиться по «;» і «1)»
r = run({ src: FULL, out: clone(GOOD) });
t('10 план: два нові пункти', r.plan_next_items.length === 2 && r.plan_next_items[0].text === 'закрити ЕП' && r.plan_next_items[1].text === 'почати Р', r.plan_next_items);

// 11. «Фінал» із повним комплектом прийнято; дата завершеної стадії (МБР) не зберігається
r = run({ src: FULL, out: mk({ deadline_forecast_stage: { 'МБР': '2026-10-01', 'ЕП': '2026-11-06', 'П': '2026-11-20', 'Р': '2026-11-30' } }), mode: 'generate_final', stageData: SD });
t('11a «Фінал» з повним комплектом прийнято', r.tag === 'FINAL_REPORT', { tag: r.tag, pre: r.pre_blocks });
t('11b дата завершеної стадії МБР не зберігається', r.deadline_forecast_stage && r.deadline_forecast_stage['МБР'] === undefined, r.deadline_forecast_stage);

// 12. «Фінал» не приймається без підтвердженого (вигаданого) блокера й документації
r = run({ src: 'МБР завершено\nЕП 95%, годин ЕП 13, дедлайн 06.11.2026\nП 70%, годин П 110, дедлайн 20.11.2026\nР 10%, годин Р 370, дедлайн 30.11.2026\nПлан: 1) закрити ЕП', out: clone(GOOD), mode: 'generate_final', stageData: SD });
t('12 «Фінал» без документації й блокера не прийнято', r.tag === 'DRAFT' && r.pre_blocks.join(' ').indexOf('Фінал не прийнято') >= 0, { tag: r.tag });

// 13. Прогнозна дата незавершеної стадії в минулому: «Фінал» не приймається
r = run({ src: FULL.replace('20.11.2026', '02.10.2026'), out: mk({ deadline_forecast_stage: { 'ЕП': '2026-11-06', 'П': '2026-10-02', 'Р': '2026-11-30' } }), mode: 'generate_final', stageData: SD });
t('13 минула дата П: «Фінал» не прийнято', r.tag === 'DRAFT' && r.pre_blocks.join(' ').indexOf('вже минула') >= 0, { tag: r.tag });

console.log((fail ? 'FAIL' : 'OK') + ': пройдено ' + pass + ', провалено ' + fail);
process.exit(fail ? 1 : 0);
