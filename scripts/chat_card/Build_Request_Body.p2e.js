function toNum(v){
  if (v === null || v === undefined || v === '' || v === '—') return null;
  if (typeof v === 'number') return v;
  var s = String(v).trim();
  if (s === '—' || s === '') return null;
  var n = parseFloat(s.replace(/\s/g,'').replace(',', '.'));
  return isNaN(n) ? null : n;
}
function fmtUAH(v){ if (v===null||v===undefined) return '—'; return Math.round(v).toLocaleString('uk-UA') + 'грн'; }
function fmtPct(v){ if (v===null||v===undefined) return '—'; return (v>0?'+':'') + v.toFixed(v===Math.round(v)?0:1).replace('.',',') + '%'; }
function fmtRatio(v){ if (v===null||v===undefined) return '—'; return v.toFixed(2).replace('.', ','); }

// Статуси, кольори і сигнали порахував 'Build MiniApp Data' — той самий код і ті самі пороги, що в Owner View.
// ШІ тут тільки формулює висновки, нічого не перераховує.
const data = $input.first().json;
const R = data.rules || {};
const RENT_DROP_PP = R.RENT_DROP_PP, RENT_DROP_PP_RED = R.RENT_DROP_PP_RED, PROFIT_YELLOW_PCT = R.PROFIT_YELLOW_PCT, PROFIT_RED_PCT = R.PROFIT_RED_PCT, CPI_RED = R.CPI_RED, CPI_YELLOW = R.CPI_YELLOW, ETC_YELLOW = R.ETC_YELLOW, ETC_RED = R.ETC_RED, UNPAID_YELLOW = R.UNPAID_YELLOW, UNPAID_RED = R.UNPAID_RED;
const ICON = { red: '🔴', yellow: '🟡', green: '🟢' };
const projects = data.projects || [];
const FACTS = data.facts || null;   // П2e: факти SQL archi_card_facts (відхилення прибутку, концентрація, блокери)
function h(v){ return v===null||v===undefined ? '—' : (Math.round(v*10)/10) + 'г'; }

const lineBlocks = projects.map(function(p){
  var l1 = (p.blocker ? '⛔' : ICON[p.status]) + ' <b>' + p.id + '</b>';
  var l2 = '⏱ ETC_план:' + h(p.planHrs) + ' Фактичний_час:' + h(p.factHrs) + ' ETC_факт:' + h(p.rawEtcPlan) + ' ETC_прогноз:' + h(p.rawEtcForecast);
  var l3 = '💰 Прибуток_план→Прибуток_прогноз: ' + p.profitPlanFmt + ' → ' + p.profitForecastFmt + '  📈 Рентабельність_план→Рентабельність_прогноз: ' + p.rentPlanFmt + ' → ' + p.rentForecastFmt;
  var unpaid = Math.max(0, (p.rawQ||0) - (p.rawP||0));
  var unpaidPct = p.contract > 0 ? Math.round(unpaid / p.contract * 100) : null;
  var l4 = '📦 Виконано:' + p.executedWorkFmt + ' Акти:' + p.actsFmt + ' Оплачено:' + p.receivedFmt + '  ' + (unpaid > 0 ? 'Не оплачено:' + fmtUAH(unpaid) + (unpaidPct !== null ? ' (' + unpaidPct + '% контракту)' : '') + (p.cls && p.cls.received ? ' ' + ICON[p.cls.received] : '') : 'Не оплачено: немає (не показувати в картці)') + '  Ефективність_гроші_ПМ:' + p.cpiFmt + '  Ефективність_гроші_години:' + (p.noForecast ? 'немає (ПМ не дав ETC)' : p.cpiHFmt);
  var l4b = '🗓 Звіт ПМа за тиждень: ' + (p.wr && p.wr.week ? p.wr.week : 'не подавався') + (p.noForecast ? '  ⚠️ ПРОГНОЗУ НЕМАЄ: ПМ не дав ETC_прогноз — Прогноз_прибутку/Рентабельність_прогноз/ETC_Total НЕ існують, не оцінюй їх' + (p.lastConfirmedForecast ? '; останній підтверджений прогноз рентабельності ' + p.lastConfirmedForecast : '') : '');
  var l4c = (p.wr && p.wr.problems ? 'Проблеми (зі звіту ПМа): ' + String(p.wr.problems).slice(0, 400) : '') + (p.wr && p.wr.help ? (p.wr.problems ? String.fromCharCode(10) : '') + 'Прохання ПМа до власника: ' + String(p.wr.help).slice(0, 400) : '');
  var l5 = 'Сигнали (пораховано кодом): ' + (p.signals.length ? p.signals.map(function(s){ return (s.b ? '⛔' : ICON[s.c]) + ' ' + s.t; }).join('; ') : 'немає');
  return [l1,l2,l3,l4,l4b].concat(l4c ? [l4c] : []).concat([l5]).join(String.fromCharCode(10));
});
const lines = lineBlocks.join(String.fromCharCode(10,10));

// Підсумок портфеля рахує код — ШІ лише цитує (лічильники, переліки)
const idsBy = function(st){ return projects.filter(function(p){ return p.status === st; }).map(function(p){ return p.id; }).join(', ') || '—'; };
const noFcIds = projects.filter(function(p){ return p.noForecast; }).map(function(p){ return p.id; }).join(', ') || '—';
const summary = 'Проєктів: ' + projects.length + '. 🔴 ' + (data.counts ? data.counts.red : 0) + ' (' + idsBy('red') + '); 🟡 ' + (data.counts ? data.counts.yellow : 0) + ' (' + idsBy('yellow') + '); 🟢 ' + (data.counts ? data.counts.green : 0) + ' (' + idsBy('green') + '); ⛔ блокер: ' + (data.counts ? data.counts.blocked : 0) + ' (' + (projects.filter(function(p){ return p.blocker; }).map(function(p){ return p.id; }).join(', ') || '—') + '). Позначка ⛔ — ЛИШЕ цим проєктам; решта мають колір зі свого рядка. Без прогнозу від ПМа: ' + noFcIds + '.';
const text = $('Telegram Trigger').item.json.message?.text || $('Telegram Trigger').item.json.message?.caption || 'Надіслано файл без тексту.';


// ===== Маршрутизація питань власника (Q1–Q10): кожне питання має СВОЮ відповідь і СВОЇ дані, пораховані кодом =====
const NL = String.fromCharCode(10);
const qn = String(text).toLowerCase();
function detectIntent(){
  if (/запала/.test(qn)) return 'q2';
  if (/що в нас.*відбува|що відбува/.test(qn)) return 'q1';
  if (/чи потрібно мені|мені зараз щось|щось робити/.test(qn)) return 'q3';
  if (/зарплат/.test(qn)) return 'q4';
  if (/касов|касового розриву/.test(qn)) return 'q5';
  if (/на який час|є робота|завантаж/.test(qn)) return 'q6';
  if (/річн|план по прибутк|плану по прибутк/.test(qn)) return 'q7';
  if (/дедлайн|пройоба/.test(qn)) return 'q8';
  if (/ключов|якірн|прилетіти/.test(qn)) return 'q9';
  if (/нарад|пообіцяли/.test(qn)) return 'q10';
  return 'generic';
}
const intent = detectIntent();
function r1(v){ return (Math.round(v*10)/10).toString().replace('.', ','); }
const sevOrder = { red: 0, yellow: 1, green: 2 };
function numOK(v){ return v !== null && v !== undefined && !isNaN(v); }
function margins(p){
  var out = [];
  if (!p.noForecast && numOK(p.rentPlan) && numOK(p.rentForecast) && numOK(RENT_DROP_PP_RED)) { var drop = (p.rentPlan - p.rentForecast) * 100; out.push('Рентабельність_прогноз нижче плану на ' + r1(drop) + ' п.п.; 🔴 з ' + RENT_DROP_PP_RED + ' п.п. (запас ' + r1(RENT_DROP_PP_RED - drop) + ' п.п.)'); }
  if (p.contract > 0 && numOK(UNPAID_RED)) { var up = Math.max(0, (p.rawQ||0) - (p.rawP||0)) / p.contract * 100; out.push('Не оплачено ' + Math.round(up) + '% контракту; 🔴 з ' + Math.round(UNPAID_RED*100) + '% (запас ' + Math.round(UNPAID_RED*100 - up) + ' п.п.)'); }
  if (numOK(p.cpi) && numOK(CPI_RED)) out.push('Ефективність виконання (гроші) ' + fmtRatio(p.cpi) + '; 🔴 нижче ' + fmtRatio(CPI_RED) + ' (запас ' + r1(p.cpi - CPI_RED) + ')');
  if (p.rawEtcPlan && numOK(p.rawEtcForecast) && numOK(ETC_RED)) { var g = (p.rawEtcForecast - p.rawEtcPlan) / p.rawEtcPlan * 100; out.push('ETC_прогноз відносно ETC_факт: ' + r1(g) + '%; 🔴 з ' + Math.round(ETC_RED*100) + '% (запас ' + r1(ETC_RED*100 - g) + ' п.п.)'); }
  return out;
}
function sigLines(p, re){ return (p.signals || []).filter(function(s){ return re.test(s.t); }).map(function(s){ return s.t; }); }
function pmAsk(p){ return (p.wr && p.wr.help) ? String(p.wr.help).slice(0, 300) : ''; }
function pmProb(p){ return (p.wr && p.wr.problems) ? String(p.wr.problems).slice(0, 300) : ''; }

var focus = '';
var playbook = '';
const GENERIC_CARD = 'ФОРМАТ відповіді про проєкти (дослівно за зразком, підстав свої значення з даних):' + NL +
'Станом на ДД.ММ.РРРР' + NL + NL +
'📊 <b>Портфель:</b> N проєктів' + NL + '🔴 a · 🟡 b · 🟢 c · ⛔ блокер: d' + NL + '(окремим рядком — «Без прогнозу від ПМа: …», якщо такі є)' + NL + NL +
'━━━━━━━━━━━━' + NL + NL +
'[emoji з даних] <b>DEMO-07</b>' + NL + NL +
'⏱ <b>Години</b>' + NL + '• ETC_план: Xг · Фактичний_час: Yг' + NL + '• ETC_факт: Zг · ETC_прогноз: Wг' + NL + NL +
'💰 <b>Гроші</b>' + NL + '• Прибуток_план → Прибуток_прогноз: N → M грн' + NL + '• Рентабельність_план → Рентабельність_прогноз: X% → Y%' + NL + '• Не оплачено: K грн (P% контракту) [емодзі] — РЯДОК ЛИШЕ ЯКЩО K > 0' + NL + NL +
'💡 <b>Insight:</b> [1-2 речення; факти ТІЛЬКИ з рядків «Проблеми»/«Сигнали»]' + NL + '⚠️ <b>Impact:</b> [1 речення]' + NL + '🎯 <b>Action:</b> [1 крок із «Прохання ПМа», інакше «уточнити в ПМа»]' + NL + NL +
'━━━━━━━━━━━━' + NL + NL + '(наступний проєкт — той самий шаблон; максимум 3)' + NL + NL +
'📌 <b>Загальний висновок</b>' + NL + '• [що найкритичніше]' + NL + '• [які проєкти не увійшли в деталі]';
const NONPROJ = 'Формат: <b>короткий заголовок</b>; 2–5 пунктів «•», кожен — одна думка в один-два рядки; порожній рядок; 🎯 <b>Що зробити:</b> 1 рядок. НЕ використовуй шаблон картки проєкту (⏱ Години / 💰 Гроші), якщо не просили конкретні проєкти. Починай з рядка «Станом на ДД.ММ.РРРР».';

if (intent === 'q2') {
  var cand = projects.filter(function(p){ return p.status !== 'red'; }).sort(function(a,b){ return (sevOrder[a.status]||0) - (sevOrder[b.status]||0) || (b.yellows||0) - (a.yellows||0); });
  var burning = projects.filter(function(p){ return p.status === 'red'; }).map(function(p){ return p.id; }).join(', ') || '—';
  focus = 'ЗАПИТ «Де може запалати?» — КАНДИДАТИ (проєкти, що ЩЕ НЕ 🔴; код порахував, скільки лишилось до 🔴):' + NL + NL +
    (cand.length ? cand.map(function(p){ return ICON[p.status] + ' ' + p.id + NL + (margins(p).map(function(m){ return '  - ' + m; }).join(NL) || '  - даних про запас немає') + NL + '  - Сигнали: ' + (p.signals.length ? p.signals.map(function(s){ return s.t; }).join('; ') : 'немає') + (pmAsk(p) ? NL + '  - Прохання ПМа: ' + pmAsk(p) : ''); }).join(NL + NL) : '(немає: усі проєкти вже 🔴)') + NL + NL + 'ВЖЕ 🔴 (НЕ розбирати, лише перелічити одним рядком): ' + burning;
  playbook = 'ЯК ВІДПОВІДАТИ на «Де може запалати?»: це про проєкти, які ЩЕ НЕ горять, але можуть спалахнути. НЕ повторюй картки з відповіді «Що відбувається», НЕ розписуй проєкти, що вже 🔴. Візьми КАНДИДАТІВ (макс. 3; найближчі до 🔴 першими). Якщо кандидатів немає — скажи прямо «усі проєкти вже 🔴, запалати нічому» і назви ⛔/найгостріші одним рядком.' + NL + NL + 'ДІЮ бери ЛИШЕ з «Прохання ПМа»; якщо її немає — напиши рівно «уточнити в ПМа», жодних власних порад (напр. «ініціювати оплату») і жодних гіпотез виду «якщо…». Формат:' + NL + 'Станом на ДД.ММ.РРРР' + NL + NL + '🔥 <b>Де може запалати</b>' + NL + 'Вже горять (не розбираю): [перелік з ВЖЕ 🔴]' + NL + NL + '━━━━━━━━━━━━' + NL + NL + '[emoji] <b>DEMO-XX</b>' + NL + '• Що вже насторожує: [з сигналів]' + NL + '• Найближчий тригер до 🔴: [з «запас»]' + NL + '• 🎯 Що зробити: [1 крок; з «Прохання ПМа», інакше «уточнити в ПМа»]' + NL + NL + '(наступний кандидат — той самий шаблон)';
} else if (intent === 'q3') {
  var decisions = projects.filter(function(p){ return pmAsk(p) || p.blocker || p.noForecast; }).sort(function(a,b){ return (b.blocker?1:0) - (a.blocker?1:0) || (sevOrder[a.status]||0) - (sevOrder[b.status]||0); });
  focus = 'ЗАПИТ «Чи потрібно мені зараз щось робити?» — РІШЕННЯ ДЛЯ ВЛАСНИКА (зі звітів ПМа: прохання, блокери, відсутні прогнози):' + NL + NL +
    (decisions.length ? decisions.map(function(p, i){ return (i+1) + '. ' + (p.blocker ? '⛔' : ICON[p.status]) + ' ' + p.id + (p.blocker ? ' [стоїть ' + (p.blocker.days !== null ? p.blocker.days + ' дн.' : '') + ': ' + p.blocker.typesText + ']' : '') + (pmAsk(p) ? NL + '   Прохання ПМа: ' + pmAsk(p) : '') + (p.noForecast ? NL + '   Прогноз відсутній: ПМ не дав ETC_прогноз' : ''); }).join(NL) : '(прохань і блокерів немає)');
  playbook = 'ЯК ВІДПОВІДАТИ на «Чи потрібно мені зараз щось робити?»: перший рядок — «Так» або «Ні, втручання не потрібне» з причиною. Далі — нумерований список рішень (макс. 8) ЛИШЕ зі списку РІШЕННЯ ДЛЯ ВЛАСНИКА, найтерміновіші перші; кожен пункт: проєкт, що вирішити, чия це вимога (ПМ чи блокер проєкту); слово «код» не вживати. Включи КОЖЕН пункт зі списку (нічого не пропускай) і НЕ оцінюй, чи потрібне втручання власника. Жодних власних приміток наприкінці. НЕ додавай нічого, чого немає в списку. НЕ повторюй картки проєктів. ' + NONPROJ;
} else if (intent === 'q4') {
  var unp4 = projects.filter(function(p){ return (p.rawQ||0) - (p.rawP||0) > 0 && p.contract > 0; }).map(function(p){ var u = (p.rawQ||0) - (p.rawP||0); return { id: p.id, u: u, pct: Math.round(u / p.contract * 100), icon: p.cls && p.cls.received ? ICON[p.cls.received] : '' }; }).sort(function(a,b){ return b.u - a.u; });
  var unp4Sum = unp4.reduce(function(s,x){ return s + x.u; }, 0);
  focus = 'ЗАПИТ «Чи є гроші на зарплату?» — Не оплачено: ' + unp4.map(function(x){ return x.id + ' ' + fmtUAH(x.u) + ' (' + x.pct + '% контракту) ' + x.icon; }).join('; ') + '. Разом: ' + fmtUAH(unp4Sum) + ' (цитуй це число, не рахуй сам).';
  playbook = 'ЯК ВІДПОВІДАТИ на «Чи є гроші на зарплату?»: у даних НЕМАЄ залишків коштів на рахунках, тому відповісти цифрою неможливо. Перший рядок: «Даних немає: залишку коштів на рахунках у системі немає». Далі «•»: що саме потрібно (залишки по рахунках, графік платежів і зарплатний фонд); що ВЖЕ відомо — лише рядки «Не оплачено» з даних вище: список «проєкт — сума (% контракту) колір», потім «Разом»; БЕЗ пункту про «Оплачено від замовників» і без висновку про зарплату. ' + NONPROJ;
} else if (intent === 'q5') {
  var unpaidRows = projects.filter(function(p){ return (p.rawQ||0) - (p.rawP||0) > 0 && p.contract > 0; }).map(function(p){ var u = (p.rawQ||0) - (p.rawP||0); return { id: p.id, u: u, pct: Math.round(u / p.contract * 100), icon: p.cls && p.cls.received ? ICON[p.cls.received] : '' }; }).sort(function(a,b){ return b.u - a.u; });
  var unpaidSum = unpaidRows.reduce(function(s,x){ return s + x.u; }, 0);
  focus = 'ЗАПИТ «Чи є небезпека касового розриву?» — що відомо: Виконано і не оплачено у портфелі: ' + fmtUAH(unpaidSum) + '. По проєктах (від більшого): ' + (unpaidRows.slice(0,5).map(function(x){ return x.id + ' ' + fmtUAH(x.u) + ' (' + x.pct + '% контракту) ' + x.icon; }).join('; ') || 'немає') + '.';
  playbook = 'ЯК ВІДПОВІДАТИ на «Чи є небезпека касового розриву?»: у даних є лише «виконано і не оплачено» (компанія кредитує клієнтів), НЕМАЄ графіка платежів, залишків і зарплатного фонду. Перший рядок: чесно — «Повної картини немає: …», далі «•» — лише відомий розрив з даних вище (топ-3 проєкти), і що потрібно, щоб відповісти. ' + NONPROJ;
} else if (intent === 'q6') {
  var etcSum = projects.filter(function(p){ return !p.noForecast && numOK(p.rawEtcForecast); }).reduce(function(s,p){ return s + p.rawEtcForecast; }, 0);
  var P6 = data.pfc || {};
  var hf = function(v){ return Math.round(v||0).toLocaleString('uk-UA') + ' год'; };
  focus = 'ЗАПИТ «На який час у команди є робота?» — що відомо (код, ті самі цифри, що рядок «Workload» в Owner View):' + NL +
    '• Workload план на рік: ' + hf(P6.planHours) + NL +
    '• Workload факт (проєкти з договором): ' + hf(P6.factHours) + NL +
    '• Workload прогноз (завантаження команди = Σ ETC_прогноз по всіх проєктах; без відпрацьованого часу і без нових договорів): ' + hf(P6.forecastHours) + NL +
    ((P6.unpaidHours||0) > 0 ? '• З факту не оплачено клієнтами: ' + hf(P6.unpaidHours) + ' 🔴' + NL : '') +
    '• Робота, що лишилась по проєктах з прогнозом (Σ ETC_прогноз): ' + hf(etcSum) + NL +
    '• Проєкти БЕЗ прогнозу від ПМа (години невідомі): ' + noFcIds + NL +
    'Потужності команди (людей, годин на тиждень) у даних НЕМАЄ.';
  playbook = 'ЯК ВІДПОВІДАТИ на «На який час у команди є робота?»: заголовок, далі «•» стовпчиком: Σ ETC_прогноз як обсяг роботи, що лишився; Workload план / факт / прогноз на рік дослівно з даних (не перераховуй); рядок «не оплачено» — лише якщо він є в даних, з 🔴. ПЕРЕВЕДЕННЯ В ТИЖНІ/МІСЯЦІ без потужності команди неможливе — скажи це прямо. Окремим пунктом — проєкти без прогнозу (обсяг невідомий). ' + NONPROJ;
} else if (intent === 'q7') {
  var P7 = data.pfc || {};
  var pctS = function(v){ return v === null || v === undefined ? '—' : String(v).replace('.', ',') + '%'; };
  var planP = P7.planProfit || 0, fcP = P7.forecastProfit || 0;
  var share = planP > 0 ? Math.round(fcP / planP * 100) : null;
  var nfCount = projects.filter(function(p){ return p.noForecast; }).length;
  var verdict = planP > 0 ? (fcP >= planP ? 'Так: прогноз прибутку покриває річний план' : 'Поки що ні: прогноз прибутку = ' + share + '% річного плану') : 'Річний план по прибутку не задано';
  focus = 'ЗАПИТ «Чи виконуємо ми річний план по прибутку?» — що відомо (код, ті самі цифри, що таблиця портфеля в Owner View):' + NL +
    'ВИСНОВОК (пораховано кодом): ' + verdict + NL +
    '• Прибуток план на рік: ' + fmtUAH(planP) + NL +
    '• Прибуток факт (проєкти з надходженням, акти − собівартість): ' + fmtUAH(P7.factProfit || 0) + NL +
    '• Прибуток прогноз (Σ по проєктах з прогнозом): ' + fmtUAH(fcP) + NL +
    '• Рентабельність бізнесу від контракту (прибуток / контракт; факт — прибуток / підписані акти): план ' + pctS(P7.planRentContractPct) + ' · факт ' + pctS(P7.factRentContractPct) + ' · прогноз ' + pctS(P7.forecastRentContractPct) + NL +
    '• Рентабельність бізнесу від собівартості (прибуток / собівартість): план ' + pctS(P7.planRentPct) + ' · факт ' + pctS(P7.factRentPct) + ' · прогноз ' + pctS(P7.forecastRentPct) + NL +
    '• Проєкти: план ' + (P7.planProjects||0) + ' · факт (підписані договори) ' + (P7.factProjects||0) + ' · прогноз (договори + КП×' + (P7.kpConversionPct||0) + '%) ' + (P7.forecastProjects||0) + NL +
    'ОБМЕЖЕННЯ: прогноз прибутку включає лише проєкти з підписаним договором і прогнозом ПМа; майбутні договори з КП у прибуток НЕ входять' + (nfCount ? '; без прогнозу від ПМа (не враховано): ' + noFcIds : '') + '.';
  playbook = 'ЯК ВІДПОВІДАТИ на «Чи виконуємо ми річний план по прибутку?»: перший рядок — ВИСНОВОК дослівно з даних. Далі «•» стовпчиком: Прибуток план / факт / прогноз; Рентабельність бізнесу від контракту і від собівартості — кожна план / факт / прогноз; Проєкти план / факт / прогноз — цифри дослівно, НЕ перераховуй. Окремим пунктом — ОБМЕЖЕННЯ. Не кажи, що плану в даних немає: він є. ' + NONPROJ;
} else if (intent === 'q8') {
  var dlRows = projects.map(function(p){ var t = sigLines(p, /^Терміни:/); var d = sigLines(p, /документац/).filter(function(x){ return !/мовірність/i.test(x); }); if (!t.length && !d.length) return null; var all = t.concat(d); var mx = 0; all.join(' ').replace(/(\d+)\s*дн/g, function(m, n){ mx = Math.max(mx, +n); return m; }); return { mx: mx, s: (p.blocker ? '⛔' : ICON[p.status]) + ' ' + p.id + ': ' + all.map(function(x){ return String(x).replace(/\.+$/, ''); }).join('; ') }; }).filter(Boolean).sort(function(a, b){ return b.mx - a.mx; });
  var dl = dlRows.map(function(x){ return x.s; });
  var dlHead = dl.length ? 'Так, ' + dl.length + ' ' + (dl.length % 10 === 1 && dl.length % 100 !== 11 ? 'проєкт має' : (dl.length % 10 >= 2 && dl.length % 10 <= 4 && (dl.length % 100 < 12 || dl.length % 100 > 14) ? 'проєкти мають' : 'проєктів мають')) + ' порушені терміни.' : 'Ні, порушених термінів у сигналах немає.';
  focus = 'ЗАПИТ «Чи є пройобані або небезпечні дедлайни?» — проєкти з порушеними термінами (з сигналів, пораховано кодом, від найбільшого прострочення; лічильник: ' + dl.length + '):' + NL + (dl.join(NL) || '(порушених термінів у сигналах немає)');
  playbook = 'ЯК ВІДПОВІДАТИ на «Чи є небезпечні дедлайни?»: перший рядок після дати — дослівно «' + dlHead + '» (число НЕ перераховуй). Далі «•» по КОЖНОМУ проєкту зі списку, у тому самому порядку і з тим самим емодзі: проєкт, стадія, на скільки днів. Не винось жоден проєкт зі списку окремим рядком («на межі» тощо). НЕ вигадуй дат і НЕ додавай власних оцінок (напр. «ризик росту»). ' + NONPROJ;
} else if (intent === 'q9') {
  var q9 = projects.filter(function(p){ return pmProb(p) || ((p.rawQ||0) - (p.rawP||0) > 0 && p.contract > 0); }).map(function(p){ var u = (p.rawQ||0) - (p.rawP||0); return ICON[p.status] + ' ' + p.id + ': ' + (pmProb(p) ? 'Проблеми ПМа: ' + pmProb(p) : '') + (u > 0 && p.contract > 0 ? (pmProb(p) ? ' | ' : '') + 'Не оплачено: ' + fmtUAH(u) + ' (' + Math.round(u / p.contract * 100) + '% контракту)' : ''); });
  focus = 'ЗАПИТ «ключовий/якірний замовник» — ЩО ВІДОМО ПО ПРОЄКТАХ (кожен факт належить ЛИШЕ своєму проєкту):' + NL + q9.join(NL);
  playbook = 'Кожен пункт — один проєкт; факти бери ТІЛЬКИ з його власного рядка вище, НЕ переноси факти між проєктами. '+ 'ЯК ВІДПОВІДАТИ на «За що нам може прилетіти від ключового / якірного замовника?»: позначки «якірний замовник» у даних НЕМАЄ. Перший рядок: «Не визначено: у даних немає позначки ключового замовника». Далі «•»: що потрібно, щоб відповісти (позначити проєкти/замовників, виручка по замовнику); що ВЖЕ видно ризикового по замовниках: лише з рядків «Проблеми (зі звіту ПМа)» (напр. замовник не передає дані, не підписав акт) — без вигаданих деталей і без своїх оцінок (напр. «акт під загрозою») — лише те, що є в рядках. ' + NONPROJ;
} else if (intent === 'q10') {
  var mt = data.meetings || [];
  var todayIso = new Date().toISOString().slice(0, 10);
  focus = 'ЗАПИТ «Що пообіцяли замовнику на останній нараді?» — ЖУРНАЛ ЗУСТРІЧЕЙ (meeting_log, ' + mt.length + ' записів, найновіші перші; журнал фіксує рішення/дії нарад):' + NL + (mt.length ? mt.map(function(m){ var dl = m.deadline ? String(m.deadline).slice(0, 10) : null; return '- ' + m.project_id + ' | нарада ' + String(m.mdate || '—').slice(0, 10) + ' | учасники: ' + (m.participants || '—') + ' | домовленість: ' + (m.action || '—') + ' | відповідальний: ' + (m.owner || '—') + ' | дедлайн: ' + (dl || 'не вказано') + (dl && dl < todayIso ? ' [ПРОСТРОЧЕНО]' : ''); }).join(NL) : '(журнал порожній)');
  playbook = 'ЯК ВІДПОВІДАТИ на «Що пообіцяли замовнику на останній нараді?»: дані — ЖУРНАЛ ЗУСТРІЧЕЙ вище. Якщо журнал порожній — «Даних немає: журнал зустрічей порожній» і як його заповнити (режим «🤝 Зустріч»). Інакше: перший рядок — «Остання нарада в журналі: <дата>, <проєкти>». Далі <b>заголовок проєкту</b> і «•» по домовленостях: «• що саме»; під кожною — окремі рядки «Відповідальний: …» і «Дедлайн: …» (символ «|» не використовуй); прострочені — з 🔴 і словом «прострочено». Окремим пунктом чесно зазнач: журнал фіксує рішення і дії нарад, а не окремо «обіцянки замовнику»; нарад по проєктах, яких немає в журналі, система не бачить. Дат, учасників і домовленостей НЕ вигадуй. 🎯 Що зробити: для прострочених — «уточнити у відповідального». ' + NONPROJ;
} else {
  playbook = GENERIC_CARD + NL + NL + 'Для відповіді НЕ про конкретні проєкти: ' + NONPROJ;
}
// ===== П2b: картка проєкту збирається кодом (кольори з cls SQL), LLM пише лише insight/impact/action =====
const DASH = '—';
function fn1(v){ return (Math.round(v*10)/10).toLocaleString('uk-UA', { maximumFractionDigits: 1 }); }
function fMoney(v){ if (v===null||v===undefined||isNaN(v)) return DASH; return (v<0 ? '−' : '') + Math.round(Math.abs(v)).toLocaleString('uk-UA') + ' грн'; }
function fPctF(v){ if (v===null||v===undefined||isNaN(v)) return DASH; var x = Math.round(v*1000)/10; return (x<0 ? '−' : (x>0 ? '+' : '')) + Math.abs(x).toLocaleString('uk-UA', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + '%'; }
function fHrs(v){ return (v===null||v===undefined||isNaN(v)) ? DASH : fn1(v) + ' г'; }
function fHrsSigned(v){ return (v===null||v===undefined||isNaN(v)) ? DASH : (v<0 ? '−' : (v>0 ? '+' : '')) + fn1(Math.abs(v)) + ' г'; }
const mentionedIds = projects.filter(function(p){ return String(text).toUpperCase().indexOf(String(p.id).toUpperCase()) >= 0; }).map(function(p){ return p.id; });
const CARD_MODE = (intent === 'q1') || (intent === 'generic' && mentionedIds.length > 0);
function cardRank(p){ return (p.blocker ? 0 : (sevOrder[p.status] === undefined ? 3 : sevOrder[p.status] + 1)); }
function cardSort(a, b){
  var d = cardRank(a) - cardRank(b); if (d) return d;
  var ra = numOK(a.rentForecast) ? a.rentForecast : 1e9, rb = numOK(b.rentForecast) ? b.rentForecast : 1e9;
  return ra - rb;
}
function neg(c, v){ return c; }   // колір лише з cls (SQL); код не перераховує
function mark(c){ return c ? ' ' + ICON[c] : ''; }
var ROUTE_LABEL = { command: 'доручення', propose: 'запит варіантів', call: 'дзвінок власника' };
function routeOf(p){ var f = FACTS && FACTS.projects && FACTS.projects[p.id]; return (f && f.route) || null; }
function routeLine(p){ var r = routeOf(p); return r ? 'Маршрут дії (правило SQL, п. 32): ' + (ROUTE_LABEL[r.type] || r.type) + ' → ' + r.to + '; підстава: ' + r.basis : ''; }
function contractLine(p){ return p.contract > 0 ? 'Контракт: ' + Math.round(p.contract).toLocaleString('uk-UA') + ' грн' : ''; }
function gapLine(p){
  var f = FACTS && FACTS.projects && FACTS.projects[p.id];
  if (!f || f.profit_gap === null || f.profit_gap === undefined) return '';
  return 'Відхилення прибутку (прогноз − план): ' + (f.profit_gap < 0 ? '−' : '+') + Math.abs(f.profit_gap).toLocaleString('uk-UA') + ' грн' + (f.gap_share_pct ? '; частка в сумі збиткових відхилень портфеля: ' + f.gap_share_pct + '%' : '');
}
function buildCard(p){
  var cl = p.cls || {};
  var unpaid = Math.max(0, (p.rawQ||0) - (p.rawP||0));
  var gap = (p.noForecast || !numOK(p.rawEtcPlan) || !numOK(p.rawEtcForecast)) ? null : (p.rawEtcPlan - p.rawEtcForecast);
  var hours = [
    '• ETC_план: ' + fHrs(p.planHrs),
    '• Фактичний_час: ' + fHrs(p.factHrs),
    '• ETC_факт: ' + fHrs(p.rawEtcPlan),
    '• ETC_прогноз: ' + (p.noForecast ? 'немає (ПМ не дав)' : fHrs(p.rawEtcForecast)) + (p.noForecast ? ' 🔴' : ''),
    '• Різниця ETC: ' + (gap === null ? DASH : fHrsSigned(gap)) + (gap === null ? '' : mark(neg(cl.etc, gap)))
  ];
  var money = [
    '• Прибуток_план: ' + fMoney(p.profitPlan),
    '• Прибуток_прогноз: ' + (p.noForecast ? 'немає (ПМ не дав)' : fMoney(p.profitForecast)) + (p.noForecast ? ' 🔴' : mark(neg(cl.profit, p.profitForecast))),
    '• Рентабельність_план: ' + fPctF(p.rentPlan),
    '• Рентабельність_прогноз: ' + (p.noForecast ? 'немає (ПМ не дав)' : fPctF(p.rentForecast)) + (p.noForecast ? ' 🔴' : mark(neg(cl.rent, p.rentForecast)))
  ];
  if (unpaid > 0) money.push('• Не оплачено: ' + fMoney(unpaid) + (p.contract > 0 ? ' (' + Math.round(unpaid / p.contract * 100) + '% контракту)' : '') + mark(cl.received));
  if (numOK(p.cpi)) money.push('• Ефективність виконання (гроші): ' + fmtRatio(p.cpi) + mark(cl.cpi));
  var probs = [];
  if (p.blocker) probs.push('• ⛔ Проєкт стоїть' + (p.blocker.days !== null && p.blocker.days !== undefined ? ' ' + p.blocker.days + ' дн.' : '') + (p.blocker.sinceFmt ? ' (з ' + p.blocker.sinceFmt + ')' : '') + ': ' + p.blocker.typesText);
  if (p.blocker && p.blocker.need) probs.push('• Потрібно: ' + p.blocker.need);
  if (p.wr && p.wr.problems) probs.push('• ' + String(p.wr.problems).slice(0, 300));
  if (!probs.length) probs.push('• немає');
  var facts = [hours.join(' '), money.join(' '), probs.join(' '), (p.signals||[]).map(function(s){ return s.t; }).join(' '), pmAsk(p), gapLine(p), contractLine(p), p.blocker && p.blocker.need ? String(p.blocker.need) : '', String(p.id)].join(' ');
  var topSig = (p.signals||[]).filter(function(s){ return s.c === 'red' || s.c === 'yellow'; })[0];
  return {
    id: p.id,
    icon: p.blocker ? '⛔' : ICON[p.status],
    hours: hours, money: money, problems: probs,
    facts: facts,
    fbInsight: topSig ? topSig.t : 'Відхилень від плану за сигналами немає.',
    fbAction: pmAsk(p) ? pmAsk(p) : 'уточнити в ПМа',
    route: routeOf(p)
  };
}
var CARD_DATA = null;
if (CARD_MODE) {
  var pool = mentionedIds.length ? projects.filter(function(p){ return mentionedIds.indexOf(p.id) >= 0; }) : projects.slice();
  var picked = pool.slice().sort(cardSort).slice(0, 3);
  var pickedIds = picked.map(function(p){ return p.id; });
  var restGroups = {};
  projects.filter(function(p){ return pickedIds.indexOf(p.id) < 0; }).sort(cardSort).forEach(function(p){ var k = p.blocker ? '⛔' : ICON[p.status]; (restGroups[k] = restGroups[k] || []).push(p.id); });
  CARD_DATA = { order: pickedIds, cards: {}, rest: restGroups, asOf: data.asOf || DASH, counts: data.counts || {}, total: projects.length, noFc: noFcIds, summaryFacts: summary };
  picked.forEach(function(p){ CARD_DATA.cards[p.id] = buildCard(p); });
}
const CARD_JSON_PLAYBOOK = 'ФОРМАТ ВІДПОВІДІ — ЛИШЕ JSON, без пояснень і без markdown. Картку (заголовок, години, гроші, кольори, числа) збирає код; ти пишеш тільки текст висновків для проєктів: ' + (CARD_DATA ? CARD_DATA.order.join(', ') : '') + '. Схема: {"cards":{"<ID проєкту>":{"insight":"1-2 речення","impact":"1 речення","action":"1 крок"}}}. Правила: факти й числа ТІЛЬКИ з рядків «Проблеми», «Прохання ПМа», «Сигнали» і показників цього проєкту; якщо дії в даних немає — action: «уточнити в ПМа»; жодних нових чисел; слово «код» не вживати; один ключ на кожен названий проєкт.';

const LAYOUT = 'ВЕРСТКА (рішення власника 11.10.2026 — це ВАЖЛИВО): відповідь має читатися з першого погляду. КОЖЕН показник — з НОВОГО рядка, ніколи кілька показників в один рядок через пробіли. Між блоками — порожній рядок. Теми розділяй підзаголовками <b>…</b>. Списки — через «•». Один рядок = одна думка (до ~90 символів). Ніякого Markdown (**, #, ---), лише теги <b> та <i>. Кольори — емодзі 🔴🟡🟢. КОЖНЕ питання має СВОЮ відповідь за своїм сценарієм нижче: ніколи не копіюй структуру відповіді на інше питання.';

if (CARD_MODE) playbook = CARD_JSON_PLAYBOOK;
let system = 'Ти — стратегічний COO-радник власника архітектурного бізнесу (Archi). Відповідаєш українською мовою на рівні операційного директора.' + String.fromCharCode(10) +
'Дані живі — читаються з project_metrics (план з Кошторису, факт з журналів годин і грошей, прогноз зі звіту ПМа) при кожному запиті, ' + projects.length + ' проєктів.' + String.fromCharCode(10,10) +
'ДАНІ АКТУАЛЬНІ НА: ' + (data.asOf || '—') + '. Починай відповідь рядком «Станом на ' + (data.asOf || '—') + '».' + String.fromCharCode(10) +
'ПІДСУМОК ПОРТФЕЛЯ (пораховано кодом — цитуй дослівно, лічильники НЕ перераховуй): ' + summary + String.fromCharCode(10,10) +
'ДАНІ ПО ПРОЄКТАХ:' + String.fromCharCode(10,10) +
lines + String.fromCharCode(10,10) +
(focus ? focus + String.fromCharCode(10,10) : '') +
'НОРМАТИВИ:' + String.fromCharCode(10) +
'- Рентабельність_план — з Кошторису, окремо по кожному проєкту: це рішення власника, яку рентабельність прийняти за план. Не порівнюй її з «нормою по галузі» і не оцінюй сам план. Рентабельність_прогноз: < 0% або нижче Рентабельність_план' + (RENT_DROP_PP_RED > 0 ? ' більше ніж на ' + RENT_DROP_PP_RED + ' п.п.' : ' (будь-яке відхилення вниз)') + ' — 🔴 (єдине правило розбіжності план/прогноз)' + (RENT_DROP_PP < RENT_DROP_PP_RED ? '; нижче більше ніж на ' + RENT_DROP_PP + ' п.п. — 🟡' : '') + '; інакше — 🟢.' + String.fromCharCode(10) +
'- Прибуток_план vs Прибуток_прогноз (теж єдине правило розбіжності план/прогноз): збиток або прогноз нижче плану' + (PROFIT_RED_PCT > 0 ? ' більше ніж на ' + PROFIT_RED_PCT + '%' : ' (будь-яке відхилення вниз)') + ' — 🔴' + (PROFIT_YELLOW_PCT < PROFIT_RED_PCT ? '; нижче більше ніж на ' + PROFIT_YELLOW_PCT + '% — 🟡' : '') + '; інакше — 🟢.' + String.fromCharCode(10) +
'- Ефективність_гроші_ПМ (Ефективність виконання, гроші = освоєно за готовністю ПМа ÷ фактичні витрати; освоєно = бюджет × готовність ПМ, це НЕ «Виконані роботи»); Ефективність_гроші_години — те саме, але готовність = Фактичний_час / (Фактичний_час + ETC_прогноз), є лише коли ПМ дав ETC; це показники методології Archi — НЕ називай їх «CPI» чи «EVM» (класичний EVM — окрема вкладка, ще не побудована); пороги однакові, не змішуй дві оцінки: < ' + CPI_RED + ' — 🔴 перевитрата; ' + CPI_RED + '–' + CPI_YELLOW + ' — 🟡 на межі; ≥ ' + CPI_YELLOW + ' — 🟢 норма.' + String.fromCharCode(10) +
'- Розрив обсягів: якщо Виконано більше за Оплачено на ' + Math.round(UNPAID_YELLOW*100) + '% контракту (🟡) або ' + Math.round(UNPAID_RED*100) + '% (🔴) — компанія кредитує клієнта власним коштом, це касовий ризик.' + String.fromCharCode(10) +
'- Розрив годин = ETC_план − (Фактичний_час + ETC_прогноз) = ETC_факт − ETC_прогноз; від\'ємний — перевитрата: ' + (ETC_RED > 0 ? 'більше ніж на ' + Math.round(ETC_RED*100) + '% плану — 🔴' : 'будь-яке від\'ємне значення — 🔴') + (ETC_YELLOW < ETC_RED ? ', більше ніж на ' + Math.round(ETC_YELLOW*100) + '% — 🟡' : '') + '. Показуй розрив зі знаком мінус, якщо прогноз перевищує ETC_факт.' + String.fromCharCode(10) +
'- Будь-яке від\'ємне значення (прибуток, рентабельність, розрив) показуй з 🔴 перед ним (рішення власника 29.10.2026).' + String.fromCharCode(10) +
'- Колір проєкту і перелік сигналів бери ТІЛЬКИ з даних вище (їх порахував код за цими ж порогами, так само, як в Owner View). Сам колір не перераховуй і сигналів не вигадуй. ⛔ — проєкт стоїть (блокер).' + String.fromCharCode(10,10) +
'ГЛОСАРІЙ ПОКАЗНИКІВ (СУВОРО, без винятків):' + String.fromCharCode(10) +
'Кожен показник має РІВНО ОДНУ базову назву і завжди вживається лише з суфіксами _план / _факт / _прогноз. Заборонено вигадувати нові назви, синоніми чи альтернативні формулювання для існуючих показників — навіть якщо питання користувача сформульоване інакше.' + String.fromCharCode(10) +
'Дозволені базові назви показників і ЛИШЕ вони:' + String.fromCharCode(10) +
'- Контракт (сума договору, без план/факт/прогноз)' + String.fromCharCode(10) +
'- ETC_план (години з Кошторису), Фактичний_час, ETC_факт (= ETC_план − Фактичний_час), ETC_прогноз (оцінка команди у тижневому звіті). Назви "Залишок_план/Залишок_прогноз" застарілі й заборонені.' + String.fromCharCode(10) +
'- Прибуток_план, Прибуток_прогноз' + String.fromCharCode(10) +
'- Рентабельність_план, Рентабельність_прогноз' + String.fromCharCode(10) +
'- Виконано (Виконані роботи = Собівартість_факт: Фактичний_час × ставка + оплачені субпідрядники), Акти (підписані), Оплачено (отримано від замовника) — грошові суми, без план/факт/прогноз' + String.fromCharCode(10) +
'- Ефективність_гроші_ПМ, Ефективність_гроші_години (коефіцієнти, без план/факт/прогноз)' + String.fromCharCode(10) +
'- Річний план бюро (таблиця портфеля Owner View): Проєкти, Workload (год), Прибуток, Рентабельність бізнесу — у двох проєкціях: від контракту (= прибуток / контракт) і від собівартості (= прибуток / собівартість); Рентабельність проєкту (_план/_прогноз у даних проєктів) — від контракту. Кожен показник — план / факт / прогноз' + String.fromCharCode(10) +
'Якщо для відповіді на питання власника не вистачає показника з цього переліку — скажи прямо, що даних немає, НЕ вигадуй нову метрику і НЕ давай їй власну назву.' + String.fromCharCode(10,10) +
'ПРАВИЛА:' + String.fromCharCode(10) +
'1. Якщо проекту немає у списку вище — чесно скажи, що він не в перевіреному наборі, НЕ вигадуй дані.' + String.fromCharCode(10) +
'2. МАКСИМУМ 3 проекти з повним Insight-Impact-Action в одній відповіді (Telegram-повідомлення обмежене 4096 символами — більше фізично не влізе). Якщо запитали конкретні проєкти і їх більше 3 — обери 3 найкритичніші з названих (спершу ⛔ і 🔴, потім 🟡; всередині — найнижча Рентабельність_прогноз). Якщо запит загальний ("що по проєктах") — візьми 3 найкритичніші з усього портфеля (спершу ⛔ і 🔴, потім 🟡), решту згадай одним рядком у Загальному висновку без I-I-A.' + String.fromCharCode(10) +
'3. Insight/Impact/Action будуй ТІЛЬКИ на основі наведених цифр вище. Якщо для конкретного висновку не вистачає даних — не вигадуй, пропусти цей пункт.' + String.fromCharCode(10) +
'4. Кожен Insight/Impact/Action — 1-2 речення, стисло. Не більше 700 символів на весь блок одного проєкту.' + String.fromCharCode(10) +
'5. Це правило застосовується ДО ВСІХ відповідей, не тільки формату Insight-Impact-Action — включно довільні питання типу "скільки ще грошей/часу", "коли здамо" тощо. Терміни з ГЛОСАРІЯ вживай однаково завжди.' + String.fromCharCode(10,10) +
'ДОДАТКОВІ ПРАВИЛА (рішення власника 10.10.2026):' + String.fromCharCode(10) +
'6. ПРОГНОЗ ТІЛЬКИ ВІД ПМа. Якщо в даних проєкту «ПРОГНОЗУ НЕМАЄ» — це 🔴 завжди: напиши «Прогноз відсутній: ПМ не дав ETC_прогноз», НЕ оцінюй прибуток/рентабельність/ETC_Total сам, НЕ підставляй плановий ETC. Дія — отримати ETC_прогноз від ПМа. Останній підтверджений прогноз (якщо є) називай окремо і з датою.' + String.fromCharCode(10) +
'7. Слово «залишок» у значенні годин ЗАБОРОНЕНЕ — лише ETC_план / ETC_факт / ETC_прогноз. (У значенні коштів на рахунках слово допустиме, але таких даних немає.)' + String.fromCharCode(10) +
'8. Лічильники (скільки проєктів 🔴/🟡/🟢/⛔) бери ЛИШЕ з рядка «ПІДСУМОК ПОРТФЕЛЯ». Колір «не оплачено» бери з позначки біля «Не оплачено:» — не вирішуй його сам.' + String.fromCharCode(10) +
'9. Немає даних — так і скажи. Приклади: «чи є гроші на зарплату» (залишку коштів на рахунках у даних немає — перелічи, що потрібно: залишки по рахунках; без цифр); «якірний/ключовий замовник» (такої позначки в даних немає — «не визначено», запропонуй, звідки її взяти); «що пообіцяли замовнику на останній нараді» (протоколів нарад у цьому контексті немає — «даних немає»). НІКОЛИ не посилайся на розділи звітів, яких немає в даних вище.' + String.fromCharCode(10,10) +
'10. Причини, Impact і Action бери ТІЛЬКИ з рядків «Проблеми (зі звіту ПМа)», «Прохання ПМа до власника» і «Сигнали». НЕ вигадуй причин, наслідків і дій, яких там немає (напр. «переробляти», «втрачені години»). Якщо дії в даних немає — Action: «уточнити в ПМа».' + String.fromCharCode(10,10) +
LAYOUT + NL + NL + playbook;

// П2e: режим картки — ШІ-аналітик Archi: факти SQL і коду → висновки по проєктах і портфелю (JSON)
var userText = text; var maxTok = 2600;
if (CARD_MODE) {
  var cardBlocks = lineBlocks.map(function(blk, i){
    var p = projects[i];
    if (CARD_DATA.order.indexOf(p.id) < 0) return null;
    return blk + (p.blocker && p.blocker.need ? NL + 'Потрібно (зі звіту ПМа про блокер): ' + String(p.blocker.need).slice(0, 300) : '') + (contractLine(p) ? NL + contractLine(p) : '') + (gapLine(p) ? NL + gapLine(p) : '') + (routeLine(p) ? NL + routeLine(p) : '');
  }).filter(Boolean).join(NL + NL);
  var P = data.pfc || {}, PF = FACTS && FACTS.portfolio;
  function sgn(v){ return (v < 0 ? '−' : '+') + Math.abs(v).toLocaleString('uk-UA') + ' грн'; }
  var unpaidAll = projects.reduce(function(s, p){ return s + Math.max(0, (p.rawQ||0) - (p.rawP||0)); }, 0);
  var asks = projects.filter(function(p){ return pmAsk(p); }).map(function(p){ return p.id + ' — ' + pmAsk(p); });
  var portLines = [
    'Проєктів: ' + projects.length + '; 🔴 ' + (data.counts ? data.counts.red : 0) + '; 🟡 ' + (data.counts ? data.counts.yellow : 0) + '; 🟢 ' + (data.counts ? data.counts.green : 0) + '; ⛔ ' + (data.counts ? data.counts.blocked : 0) + '. Без прогнозу ПМа: ' + noFcIds + '.',
    'Річний план бюро: Прибуток план ' + fmtUAH(P.planProfit || 0) + ', прогноз ' + fmtUAH(P.forecastProfit || 0) + '.'
  ];
  if (PF) {
    portLines.push('Сума збиткових відхилень прибутку проєктів (прогноз − план): ' + fmtUAH(PF.neg_total) + '; сума додатних: ' + fmtUAH(PF.pos_total) + '; різниця: ' + sgn(PF.net_gap) + '.');
    if (PF.top_loss && PF.top_loss.length) portLines.push('Найбільші збитки: ' + PF.top_loss.map(function(x){ return x.id + ' ' + sgn(x.gap) + ' (' + x.share_pct + '%)'; }).join('; ') + '.');
    if (PF.top_gain) portLines.push('Найбільше додатне відхилення: ' + PF.top_gain.id + ' ' + sgn(PF.top_gain.gap) + '.');
    if (PF.blocked) portLines.push('Заблоковано проєктів: ' + PF.blocked.count + '; контракти заблокованих: ' + fmtUAH(PF.blocked.contract_sum) + '; причини: люди — ' + PF.blocked.reasons['люди'] + ', гроші — ' + PF.blocked.reasons['гроші'] + ', замовник — ' + PF.blocked.reasons['замовник'] + '.');
  }
  portLines.push('Виконано і не оплачено клієнтами: ' + fmtUAH(unpaidAll) + (P.unpaidHours ? ' (' + Math.round(P.unpaidHours) + ' год)' : '') + '.');
  portLines.push('Пайплайн продажів: КП надіслано за рік ' + (P.kpYearSent || 0) + ' з плану ' + (P.kpPlanYear || 0) + '; за місяць ' + (P.kpMonthSent || 0) + '; прогноз договорів з КП ' + (P.kpProjectedContracts || 0) + '.');
  portLines.push('Workload годин: план ' + Math.round(P.planHours || 0) + ', факт ' + Math.round(P.factHours || 0) + ', прогноз (Σ ETC_прогноз) ' + Math.round(P.forecastHours || 0) + '.');
  if (asks.length) portLines.push('Прохання ПМів до власника: ' + asks.join('; ') + '.');
  CARD_DATA.pfacts = portLines.join(NL);
  system = 'Ти — Archi, ШІ-аналітик власника архітектурного бюро (радник COO). Українською. Твоя робота — аналіз і поради, а не переказ цифр: поясни причину, наслідок і дію.' + NL + NL +
    'ДАНІ АКТУАЛЬНІ НА: ' + (data.asOf || '—') + NL + NL +
    'ФАКТИ ПО ПРОЄКТАХ (порахували SQL і код):' + NL + NL + cardBlocks + NL + NL +
    'ФАКТИ ПО ПОРТФЕЛЮ І ПАЙПЛАЙНУ:' + NL + CARD_DATA.pfacts + NL + NL +
    'ЩО НАПИСАТИ:' + NL +
    'Для кожного названого проєкту: insight — головна причина проблеми, пояснена зв\'язком фактів (не повторюй картку); impact — наслідок для грошей чи термінів, обов\'язково з числом із фактів ЦЬОГО проєкту; action — готовий текст, який власник копіює й надсилає (п. 32). Адресат і тип — з рядка «Маршрут дії» (його задав SQL, не змінюй): «доручення» — коротке повідомлення адресату: що зробити і який результат прислати; «запит варіантів» — повідомлення ПМу: підготувати кілька варіантів і зателефонувати власнику; «дзвінок власника» — кілька тез для розмови через «;». Зміст бери з «Потрібно» або «Прохання ПМа», якщо вони є; інакше — з фактів. Вигаданих дат не став; термін — «до наступної наради».' + NL +
    'Для портфеля: headline — головний висновок про стан справ; priorities — 2–3 пріоритети в порядку впливу на гроші; pipeline — що кажуть дані про продажі й завантаження команди.' + NL + NL +
    'ПРАВИЛА ПРАВДИ:' + NL +
    '1. Числа бери ТІЛЬКИ з фактів вище, записуй у тому самому вигляді (напр. «217 360 грн», «50%»). Не округлюй, не рахуй нових сум, не вживай «тис.» і «млн».' + NL +
    '2. Причинний зв\'язок — лише між наведеними фактами. Якщо даних не вистачає — прямо скажи, чого бракує. Причин, людей, дат, яких немає у фактах, не вигадуй.' + NL +
    '3. Для годин: ETC_план / ETC_факт / ETC_прогноз; слово «залишок» заборонене. Колір і сигнали не перераховуй.' + NL +
    '4. Стиль: insight і impact до 25 слів; action до 40 слів, без звертання за іменем (імен у даних немає), без нумерації й маркерів усередині полів.' + NL + NL +
    'ФОРМАТ ВІДПОВІДІ — ЛИШЕ JSON, без пояснень і markdown:' + NL +
    '{"portfolio":{"headline":"…","priorities":["…","…"],"pipeline":"…"},"cards":{"<ID проєкту>":{"insight":"…","impact":"…","action":"…"}}}' + NL +
    'Ключі cards — рівно ці проєкти: ' + CARD_DATA.order.join(', ') + '.';
  userText = 'Питання власника: ' + text + NL + NL + 'Відповідь — ЛИШЕ JSON за схемою, без тексту до і після, без markdown.';
  maxTok = 1300;
}

const body = JSON.stringify({
  model: 'claude-sonnet-4-6',
  max_tokens: maxTok,
  temperature: 0.2,
  system: system,
  messages: [{ role: 'user', content: userText }]
});

const icons = {}; projects.forEach(function(p){ icons[p.id] = p.blocker ? '⛔' : ICON[p.status]; });
return [{ json: { body: body, chat_id: $('Telegram Trigger').item.json.message.chat.id, icons: icons, cardData: CARD_DATA } }];