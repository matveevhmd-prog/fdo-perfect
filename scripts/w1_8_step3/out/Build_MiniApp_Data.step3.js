function toNum(v){
  if (v === null || v === undefined || v === '' || v === '—') return null;
  if (typeof v === 'number') return v;
  var s = String(v).trim();
  if (s === '—' || s === '') return null;
  var n = parseFloat(s.replace(/\s/g,'').replace(',', '.'));
  return isNaN(n) ? null : n;
}
function fmtPct(v){ if (v===null||v===undefined) return '—'; return (v>0?'+':'') + v.toFixed(v===Math.round(v)?0:1).replace('.',',') + '%'; }
function fmtUAH(v){ if (v===null||v===undefined) return '—'; return Math.round(v).toLocaleString('uk-UA') + ' грн'; }
function fmtHrs(v){ if (v===null||v===undefined) return '—'; return (Math.round(v*10)/10).toLocaleString('uk-UA',{maximumFractionDigits:1}) + ' год'; }
function fmtRatio(v){ if (v===null||v===undefined) return '—'; return v.toFixed(2).replace('.', ','); }
function fmtDate(s){ if (!s) return '—'; var p = String(s).slice(0,10).split('-'); return p.length===3 ? (p[2]+'.'+p[1]+'.'+p[0]) : String(s); }
function fmtDay(v){ if (!v) return null; var d = new Date(v); if (isNaN(d)) return null; return d.toLocaleDateString('uk-UA', { timeZone: 'Europe/Kyiv', day: '2-digit', month: '2-digit', year: 'numeric' }); }
function maxTs(rows){ var best = null; rows.forEach(function(r){ var t = r && r.data_updated_at ? new Date(r.data_updated_at).getTime() : NaN; if (!isNaN(t) && (best === null || t > best)) best = t; }); return best === null ? null : new Date(best).toISOString(); }
function days(a, b){ if (!a || !b) return null; return Math.round((new Date(String(a).slice(0,10)) - new Date(String(b).slice(0,10))) / 86400000); }
function obj(v){ if (!v) return {}; if (typeof v === 'string') { try { return JSON.parse(v); } catch(e) { return {}; } } return v; }
function isEmptyText(t){ if (!t) return true; var s = String(t).trim().toLowerCase().replace(/[.\s]/g,''); return s === '' || s === 'немає' || s === 'непотрібна' || s === 'непотрібно' || s === '(беззауважень)' || s === '(непотрібно)'; }
function worst(a, b){ var r = {red:3, yellow:2, green:1, '':0}; return (r[a]||0) >= (r[b]||0) ? a : b; }

// Пороги — єдина таблиця archi_thresholds (її ж читає чат власника); тут лише запасні значення
const metricsRows = $input.all().map(function(i){ return i.json; });
const RULES = obj((metricsRows[0] || {}).rules);
// W1.8 крок 3: кольори, сигнали, групи й лічильники рахує SQL (archi_project_signals, archi_portfolio_cards); тут лише відображення
const SQLC = obj((metricsRows[0] || {}).cards);
if (metricsRows.length && (!SQLC.counts || !SQLC.groups || !SQLC.hero)) throw new Error('W1.8: archi_portfolio_cards не повернула картки портфеля');
const SIG_ORDER = ['rent', 'etc_gap', 'unpaid', 'cpi', 'optimistic', 'slips', 'doc_prob', 'help', 'plan_exec', 'readiness_gap', 'blocker', 'no_weekly_report', 'no_forecast'];
function rule(k, d){ var v = toNum(RULES[k]); return v === null ? d : v; }
// План рентабельності — з Кошторису по кожному проєкту (рішення власника); колір = відхилення прогнозу від ЦЬОГО плану
const RENT_DROP_PP = rule('rent_drop_pp', 5);
const RENT_DROP_PP_RED = rule('rent_drop_pp_red', 10);
const PROFIT_YELLOW_PCT = rule('profit_yellow_pct', 5);
const PROFIT_RED_PCT = rule('profit_red_pct', 10);
const CPI_RED = rule('cpi_red', 0.85), CPI_YELLOW = rule('cpi_yellow', 0.95);
const ETC_RED = rule('etc_red', 0.10), ETC_YELLOW = rule('etc_yellow', 0.05);
const SLIP_RED_DAYS = rule('slip_red_days', 14);
const UNPAID_YELLOW = rule('unpaid_yellow', 0.10), UNPAID_RED = rule('unpaid_red', 0.25);
const DOC_RED = rule('doc_prob_red', 3), DOC_YELLOW = rule('doc_prob_yellow', 6);
const STAGES = ['МБР','ЕП','П','Р'];
const BLOCK_RED_DAYS = rule('block_red_days', 14);
const BLOCK_LABEL = { 'люди': 'немає вільних людей', 'гроші': 'немає грошей на аванс / субпідряд', 'замовник': 'чекаємо замовника', 'інше': 'інше' };
const OPT_ETC_DROP = rule('opt_etc_drop', 0.40), OPT_READY_MAX = rule('opt_ready_max', 50);
const TODAY = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Kyiv' });   // дата за Києвом (UTC давав «вчора» з 00:00 до 03:00)

const projects = [];
metricsRows.forEach(function(row){
  var id = String(row['project_id'] || '').trim();
  if (!id) return;
  var rentF = toNum(row['profitability_forecast_pct']);
  var noFc = (rentF === null);   // рішення власника 10.10.2026: прогноз лише від ПМа; нема ETC → прогнозу нема, завжди 🔴
  var rentP = toNum(row['profitability_plan_pct']);
  var profitP = toNum(row['profit_plan']), profitF = toNum(row['profit_forecast']);
  var etcPlan = toNum(row['hours_remaining']), etcF = toNum(row['etc_forecast_total_hours']);
  // ETC_план / ETC_факт по 4 стадіях (МБР/ЕП/П/Р, без АН) — те саме визначення, що в тижневому звіті ПМа:
  // ETC_план = план стадії; ETC_факт = ETC_план − Фактичний_час по стадії; Total = сума стадій (рішення власника 16.10.2026)
  var sdat0 = obj(row['stage_data']), etcPlanAll = 0, etcFactAll = 0, hasStg = false;
  STAGES.forEach(function(s){ var d = sdat0[s]; if (!d) return; var ep0 = toNum(d.etc_plan_hours); if (ep0 === null) return; hasStg = true; etcPlanAll += ep0; etcFactAll += (ep0 - (toNum(d.actual_hours_live) || 0)); });
  if (hasStg) { etcPlan = Math.round(etcFactAll * 10) / 10; etcPlanAll = Math.round(etcPlanAll * 10) / 10; } else { etcPlanAll = null; }
  // Виконані роботи = Собівартість_факт: Фактичний_час × ставка + оплачені субпідрядники (рішення власника 16.10.2026; було: контракт × готовність)
  var Q = toNum(row['actual_cost']), S = toNum(row['acts_amount']), P = toNum(row['money_received']);
  // Прибуток факт = підписані акти − собівартість факт; лише проєкти з надходженням коштів (рішення власника 11.10.2026)
  var profitFact = (P !== null && P > 0 && S !== null && Q !== null) ? (S - Q) : null;
  var cpi = toNum(row['cpi_classic_evm']);
  // CPI за годинами (рішення власника 16.10.2026): готовність за годинами = Фактичний_час / (Фактичний_час + ETC_прогноз) по 4 стадіях; EV = контракт × ця готовність; CPI_години = EV / Собівартість_факт. Є лише коли ПМ дав ETC по всіх стадіях
  var contractN = toNum(row['contract_amount']) || 0;
  var hoursDone = 0; STAGES.forEach(function(s){ var d = sdat0[s]; if (d) hoursDone += toNum(d.actual_hours_live) || 0; });
  var cpiH = (etcF !== null && Q !== null && Q > 0 && contractN > 0 && (hoursDone + etcF) > 0) ? ((contractN * hoursDone / (hoursDone + etcF)) / Q) : null;
  // Рентабельність у двох проекціях (рішення власника 16.10.2026): від контракту (прибуток / контракт) і від собівартості (прибуток / собівартість); факт: прибуток факт / підписані акти і / Собівартість_факт
  var r1p = function(v){ return v === null ? null : Math.round(v * 10) / 10; };
  var rentCostPlan = (profitP !== null && contractN - profitP > 0) ? r1p(profitP / (contractN - profitP) * 100) : null;
  var rentCostFc = (!noFc && profitF !== null && contractN - profitF > 0) ? r1p(profitF / (contractN - profitF) * 100) : null;
  var rentContractFact = (profitFact !== null && S !== null && S > 0) ? r1p(profitFact / S * 100) : null;
  var rentCostFact = (profitFact !== null && Q !== null && Q > 0) ? r1p(profitFact / Q * 100) : null;
  var sg = obj(row['sig']);
  if (!sg.project_id) throw new Error('W1.8: archi_project_signals не повернула проєкт ' + id);
  var cls = Object.assign({}, obj(sg.cls));
  var signals = [];
  var sdat = obj(row['stage_data']);

  // Тижневий звіт ПМа
  var wr = null;
  var blocker = null;
  if (row['wr_week']) {
    var rd = obj(row['wr_readiness']), et = obj(row['wr_etc']), dl = obj(row['wr_deadlines']), dp = obj(row['doc_deadlines_plan']), gp = obj(row['wr_gap']);
    var stSig = obj(row['stage_etc_signal']);   // S-04 по стадіях — колір рахує SQL (archi_report_today.stage_etc_signal)
    var stages = STAGES.map(function(s){
      var slip = dp[s] ? days(dl[s], dp[s]) : null;
      var c = obj(sg.stage_cls)[s] || '';
      return { stage: s, readiness: rd[s] !== undefined ? rd[s] + '%' + (gp[s] ? ' (за год. ' + gp[s].hours + '%)' : '') : '—', etc: et[s] !== undefined ? et[s] + ' год' : '—', deadline: fmtDate(dl[s]), planDeadline: dp[s] ? fmtDate(dp[s]) : null, cls: c,
        rdN: rd[s] !== undefined ? Number(rd[s]) : null, etcN: et[s] !== undefined ? Number(et[s]) : null, etcPlanN: (sdat[s] ? toNum(sdat[s].etc_plan_hours) : null), etcFactN: (sdat[s] && toNum(sdat[s].etc_plan_hours) !== null ? Math.round((toNum(sdat[s].etc_plan_hours) - (toNum(sdat[s].actual_hours_live) || 0)) * 10) / 10 : null), gapHours: gp[s] ? gp[s].hours : null, slip: slip, etcSig: (stSig[s] === 'red' || stSig[s] === 'yellow') ? stSig[s] : '',
        absent: !!(sdat[s] && toNum(sdat[s].etc_plan_hours) === 0) };
    }).filter(function(x){ return !x.absent; });
    var docProb = toNum(row['wr_doc_prob']);
    var docCls = sg.doc_cls || '';
    var problems = isEmptyText(row['wr_problems']) ? null : String(row['wr_problems']);
    var help = isEmptyText(row['wr_help']) ? null : String(row['wr_help']);
    // PX-01: виконання плану тижня (рахує SQL archi_plan_execution; пороги plan_exec_red/plan_exec_yellow у archi_thresholds)
    var peSig = row['pe_signal'];
    var bl = obj(row['wr_blocker']);
    if (bl && Array.isArray(bl.types) && bl.types.length) {
      var bDays = bl.since ? days(TODAY, bl.since) : null;
      var etcTotal = STAGES.reduce(function(s, x){ return s + (Number(et[x]) || 0); }, 0);
      var endPlan = dp['Р'] || null;
      var weeksLeft = endPlan ? days(endPlan, TODAY) / 7 : null;
      var pace = (weeksLeft !== null && weeksLeft > 0) ? Math.round(etcTotal / weeksLeft) : null;
      var bSig = (sg.signals || []).filter(function(x){ return x.code === 'blocker'; })[0];
      var bCls = bSig ? bSig.c : 'yellow';
      var typesText = bl.types.map(function(t){ return BLOCK_LABEL[t] || t; }).join('; ');
      blocker = { cls: bCls, days: bDays, sinceFmt: fmtDate(bl.since), typesText: typesText, need: bl.need || null, etcTotal: etcTotal,
        endPlanFmt: endPlan ? fmtDate(endPlan) : '—', weeksLeftFmt: weeksLeft === null ? '—' : (weeksLeft > 0 ? String(Math.round(weeksLeft * 10) / 10).replace('.', ',') + ' тиж.' : 'дедлайн минув'),
        paceFmt: pace === null ? (weeksLeft !== null && weeksLeft <= 0 ? 'дедлайн Р вже минув' : '—') : pace + ' год/тиж.' };
    }
    wr = { week: fmtDate(row['wr_week']), stages: stages, actProb: toNum(row['wr_act_prob']), docProb: docProb, docCls: docCls,
           problems: problems, help: help, plans: row['wr_plans'] ? String(row['wr_plans']).split('\n').filter(Boolean) : [],
           planExec: (toNum(row['pe_total']) > 0) ? { total: toNum(row['pe_total']), done: toNum(row['pe_done']), notDone: toNum(row['pe_not_done']), noAnswer: toNum(row['pe_no_answer']), pending: toNum(row['pe_pending']), pct: toNum(row['pe_pct']), signal: row['pe_signal'] || null, carry: toNum(row['pe_carry']) } : null };
  }

  // Приріст готовності проти витрат команди (CLAUDE.md п. 11): рахує SQL-вʼю archi_weekly_progress (інтервал між двома останніми знімками); тут лише відображення
  var wpCost = toNum(row['wp_cost']);
  var wpObj = (row['wp_prev_week'] && wpCost !== null) ? { prev: fmtDate(row['wp_prev_week']), week: fmtDate(row['wr_week']), readyPrev: toNum(row['wp_ready_prev']), ready: toNum(row['wp_ready']), dReadyPP: toNum(row['wp_d_ready_pp']), hours: toNum(row['wp_hours']), cost: wpCost, value: toNum(row['wp_value']), result: toNum(row['wp_result']), idx: toNum(row['wp_idx']), signal: row['wp_signal'] || '', budget: toNum(row['wp_budget']), customer: toNum(row['wp_customer']), owner: toNum(row['wp_owner']), reserve: Math.max(0, (toNum(row['wp_budget']) || 0) - (toNum(row['wp_customer']) || 0)), hist: (function(){ var h = row['wp_hist']; if (typeof h === 'string') { try { h = JSON.parse(h); } catch(e) { h = null; } } return (h || []).map(function(x){ return { week: fmtDate(String(x[0]).slice(0,10)), hours: Number(x[3]) || 0, cost: Number(x[4]) || 0, budget: Number(x[5]) || 0, customer: Number(x[6]) || 0, owner: Number(x[7]) || 0 }; }); })() } : null;

  var lastFcFmt = null;
  if (noFc) {
    var fcPct = toNum(row['forecast_confirmed_pct']);
    if (fcPct !== null) lastFcFmt = fmtPct(fcPct) + (row['forecast_confirmed_week'] ? ' (звіт за ' + fmtDate(row['forecast_confirmed_week']) + ')' : '');
    var missSt = [];
    if (row['wr_week']) {
      var rd2 = obj(row['wr_readiness']), et2 = obj(row['wr_etc']);
      missSt = STAGES.filter(function(s){ return !(Number(rd2[s]) >= 100) && (et2[s] === undefined || et2[s] === null); });
    }
    var why = !row['wr_week'] ? 'ПМ не подав жодного тижневого звіту' : ('ПМ не дав ETC по ' + (missSt.length ? missSt.join(', ') : 'стадіях'));
  }
  var sigText = function(s) {
    var a = s.args || {};
    switch (s.code) {
      case 'rent': return a.loss ? ('Рентабельність прогноз ' + fmtPct(rentF) + ' — проєкт у збитку') : ('Рентабельність план ' + fmtPct(rentP) + ' (Кошторис) → прогноз ' + fmtPct(rentF) + ': на ' + String(Math.round(a.drop_pp * 10) / 10).replace('.', ',') + ' п.п. нижче плану');
      case 'etc_gap': return 'Ще потрібно ' + fmtHrs(etcF) + ' — ETC_факт перевищено на ' + fmtHrs(toNum(a.gap_hours)) + ' (' + Math.round(toNum(a.gap_pct_bac)) + '% плану проєкту)';
      case 'unpaid': return 'Виконано і не оплачено ' + fmtUAH(toNum(a.amount)) + ' (' + a.pct + '% контракту)';
      case 'cpi': return 'Ефективність виконання (гроші) ' + fmtRatio(toNum(a.value)) + ' — перевитрата: на 1 грн витрат ' + fmtRatio(toNum(a.value)) + ' грн освоєного за готовністю ПМа';
      case 'optimistic': return 'Оптимістичний прогноз ПМа: ' + (a.stages || []).map(function(x){ return 'стадія ' + x.stage + ' — ETC на ' + x.drop + '% нижче плану при готовності ' + x.ready + '%'; }).join('; ');
      case 'slips': return 'Терміни: ' + (a.slips || []).map(function(x){ return x.stage + ' пізніше плану на ' + x.days + ' дн.'; }).join(', ');
      case 'doc_prob': return 'Ймовірність видачі документації ' + a.prob + '/10';
      case 'help': return 'ПМ просить допомоги власника';
      case 'plan_exec': return 'Виконання плану тижня ' + a.pct + '%: виконано ' + a.done + ' з ' + a.total + (Number(row['pe_not_done']) + Number(row['pe_no_answer']) > 0 ? ', перенесено ' + (Number(row['pe_not_done']) + Number(row['pe_no_answer'])) : '');
      case 'readiness_gap': { var g = obj(a.gap), ks = Object.keys(g); return 'Готовність за оцінкою ПМ не збігається з годинами: ' + ks.map(function(k){ return k + ' ' + g[k].pm + '% проти ' + g[k].hours + '% за годинами'; }).join(', ') + ' (ПМ підтвердив' + (g[ks[0]] && g[ks[0]].note ? ': ' + g[ks[0]].note : '') + ')'; }
      case 'blocker': return 'Проєкт стоїть' + (a.days !== null && a.days !== undefined ? ' ' + a.days + ' дн. (з ' + fmtDate(a.since) + ')' : '') + ': ' + (a.types || []).map(function(t){ return BLOCK_LABEL[t] || t; }).join('; ');
      case 'no_weekly_report': return 'ПМ ще не подавав тижневий звіт';
      case 'no_forecast': return 'Прогноз відсутній: ' + why + (lastFcFmt ? '. Останній підтверджений прогноз рентабельності ' + lastFcFmt : '');
    }
    throw new Error('W1.8: невідомий код сигналу ' + s.code);
  };
  (sg.signals || []).slice().sort(function(x, y){ return SIG_ORDER.indexOf(x.code) - SIG_ORDER.indexOf(y.code); }).forEach(function(s){
    var o = { c: s.c, t: sigText(s) }; if (s.b) o.b = true; signals.push(o);
  });
  signals.sort(function(a,b){ return ((a.b?0:2) + (a.c==='red'?0:1)) - ((b.b?0:2) + (b.c==='red'?0:1)); });
  projects.push({
    id: id, name: id, dataUpdated: fmtDay(row['data_updated_at']) || '—',
    status: sg.status, reds: sg.reds, yellows: sg.yellows, signals: signals, cls: cls, wr: wr, blocker: blocker,
    contract: toNum(row['contract_amount']), contractFmt: fmtUAH(toNum(row['contract_amount'])),
    rentPlan: rentP !== null ? rentP/100 : null, rentPlanFmt: fmtPct(rentP),
    noForecast: noFc, lastConfirmedForecast: lastFcFmt,
    rentForecast: noFc ? null : rentF/100, rentForecastFmt: noFc ? ('🔴 Прогноз відсутній' + (lastFcFmt ? ' (останній: ' + lastFcFmt + ')' : '')) : fmtPct(rentF),
    profitPlan: profitP, profitPlanFmt: fmtUAH(profitP),
    profitForecast: noFc ? null : profitF, profitForecastFmt: noFc ? '🔴 Прогноз відсутній' : fmtUAH(profitF),
    profitFact: profitFact, profitFactFmt: profitFact === null ? '—' : fmtUAH(profitFact),
    executedWorkFmt: fmtUAH(Q), receivedFmt: fmtUAH(P), actsFmt: fmtUAH(S),
    moneyToCompleteTeamFmt: fmtUAH(toNum(row['money_to_completion_team'])),
    moneyToCompleteSubFmt: fmtUAH(toNum(row['money_to_completion_subcontract'])),
    etcPlanFmt: fmtHrs(etcPlan), etcFactFmt: fmtHrs(etcPlan), etcPlanTotFmt: fmtHrs(etcPlanAll), etcForecastFmt: noFc ? '🔴 Не подано ПМом' : fmtHrs(etcF), etc: etcF,
    cpi: cpi, cpiFmt: fmtRatio(cpi), cpiH: cpiH, cpiHFmt: fmtRatio(cpiH),
    rentContractPlanFmt: fmtPct(rentP), rentContractFactFmt: fmtPct(rentContractFact), rentContractForecastFmt: noFc ? '—' : fmtPct(rentF),
    rentCostPlanFmt: fmtPct(rentCostPlan), rentCostFactFmt: fmtPct(rentCostFact), rentCostForecastFmt: fmtPct(rentCostFc),
    planHrs: (etcPlanAll !== null ? etcPlanAll : toNum(row['planned_hours'])), factHrs: toNum(row['actual_hours']),
    rawQ: Q, rawS: S, rawP: P, rawEtcPlan: etcPlan, rawEtcForecast: etcF, wp: wpObj
  });
});

function sqlGroup(k, valFn){ var G = obj(obj(SQLC.groups)[k]); var byId = {}; projects.forEach(function(p){ byId[p.id] = p; }); function m(ids){ return (ids || []).map(function(id){ var p = byId[id]; return p ? { id: p.id, name: p.name, value: valFn(p) } : null; }).filter(Boolean); } return { critical: m(G.critical), attention: m(G.attention), normal: m(G.normal) }; }
function mk(defs, g){ return defs.map(function(d){ return Object.assign({}, d, { count: g[d.id].length, value: g[d.id].length }); }); }

const rentG = sqlGroup('rent', function(p){ return p.noForecast ? 'прогноз відсутній' : p.rentForecastFmt; });
const rentDefs = [
  {id:'critical', label:'Нижче плану або збиток', sub:'прогноз рентабельності нижче плану з Кошторису' + (RENT_DROP_PP_RED > 0 ? ' більше ніж на ' + RENT_DROP_PP_RED + ' п.п.' : '') + ', < 0% або прогноз відсутній (ПМ не дав ETC)', color:'red'},
  {id:'attention', label:'Під загрозою', sub:'прогноз нижче плану з Кошторису більше ніж на ' + RENT_DROP_PP + ' п.п.', color:'yellow'},
  {id:'normal', label:'Норма', sub:'прогноз не нижче плану з Кошторису', color:'green'}
].filter(function(d){ return d.id !== 'attention' || RENT_DROP_PP < RENT_DROP_PP_RED; });
const profitG = sqlGroup('profit', function(p){ return p.noForecast ? 'прогноз відсутній' : p.profitForecastFmt; });
const profitDefs = [
  {id:'critical', label:'Нижче плану або збиток', sub:'прибуток прогноз нижче плану' + (PROFIT_RED_PCT > 0 ? ' більше ніж на ' + PROFIT_RED_PCT + '%' : '') + ', < 0 або прогноз відсутній', color:'red'},
  {id:'attention', label:'Відхилення > ' + PROFIT_YELLOW_PCT + '%', sub:'прибуток нижче плану', color:'yellow'},
  {id:'normal', label:'Норма', sub:'прибуток прогноз не нижче плану', color:'green'}
].filter(function(d){ return d.id !== 'attention' || PROFIT_YELLOW_PCT < PROFIT_RED_PCT; });
const volG = sqlGroup('volume', function(p){ return fmtUAH(Math.max(0,(p.rawQ||0)-(p.rawP||0))); });
const volDefs = [
  {id:'critical', label:'Багато роботи без оплати', sub:'не оплачено > ' + (UNPAID_RED*100) + '% контракту', color:'red'},
  {id:'attention', label:'Робота випереджає оплату', sub:'не оплачено ' + (UNPAID_YELLOW*100) + '–' + (UNPAID_RED*100) + '% контракту', color:'yellow'},
  {id:'normal', label:'Оплата встигає за роботою', sub:'не оплачено ≤ ' + (UNPAID_YELLOW*100) + '% контракту', color:'green'}
];
const etcG = sqlGroup('etc', function(p){ return p.noForecast ? 'ETC не подано' : fmtHrs((p.rawEtcForecast||0)-(p.rawEtcPlan||0)); });
const etcDefs = [
  {id:'critical', label:(ETC_RED > 0 ? 'ETC_факт перевищено більше ніж на ' + Math.round(ETC_RED*100) + '% плану проєкту' : 'План − (факт + ETC_прогноз) < 0 — перевитрата годин') + ' або ETC не подано', color:'red'},
  {id:'attention', label:(ETC_YELLOW < ETC_RED ? 'ETC_факт перевищено на ' + Math.round(ETC_YELLOW*100) + '–' + Math.round(ETC_RED*100) + '% плану проєкту або оптимістичний прогноз ПМа' : 'Оптимістичний прогноз ПМа'), color:'yellow'},
  {id:'normal', label:'У межах плану', color:'green'}
];
const evmG = sqlGroup('evm', function(p){ return p.cpiFmt; });
const evmDefs = [
  {id:'critical', label:'Ефективність < ' + fmtRatio(CPI_RED) + ' — перевитрата', color:'red'},
  {id:'attention', label:'Ефективність ' + fmtRatio(CPI_RED) + '–' + fmtRatio(CPI_YELLOW) + ' — на межі', color:'yellow'},
  {id:'normal', label:'Ефективність ≥ ' + fmtRatio(CPI_YELLOW) + ' — норма', color:'green'}
].filter(function(d){ return d.id !== 'attention' || CPI_RED < CPI_YELLOW; });

const fcProjects = projects.filter(function(p){ return !p.noForecast; });
const noFcCount = projects.length - fcProjects.length;
const avgRentForecast = fcProjects.length ? fcProjects.reduce(function(s,p){ return s+p.rentForecast; }, 0) / fcProjects.length : 0;
const avgRentPlan = fcProjects.length ? fcProjects.reduce(function(s,p){ return s+(p.rentPlan||0); }, 0) / fcProjects.length : 0;
const totalProfitPlan = fcProjects.reduce(function(s,p){ return s+(p.profitPlan||0); }, 0);
const totalProfitForecast = fcProjects.reduce(function(s,p){ return s+(p.profitForecast||0); }, 0);
const totalContract = projects.reduce(function(s,p){ return s+(p.contract||0); }, 0);
const volumeGapSum = projects.map(function(p){ return (p.rawQ||0) - (p.rawP||0); }).filter(function(v){ return v>0; }).reduce(function(s,v){ return s+v; }, 0);
const etcGapValues = fcProjects.map(function(p){ return (p.rawEtcForecast||0) - (p.rawEtcPlan||0); });
const etcGapAvg = etcGapValues.length ? etcGapValues.reduce(function(s,v){ return s+v; },0)/etcGapValues.length : 0;
const cpiValues = projects.map(function(p){ return p.cpi; }).filter(function(v){ return v!==null && v!==undefined; });
const cpiAvg = cpiValues.length ? cpiValues.reduce(function(s,v){ return s+v; },0)/cpiValues.length : 0;
function heroCls(v, red, yellow, higherIsBetter){ if (v===null) return ''; v = Math.round(v * 100) / 100; return higherIsBetter ? (v < red ? 'red' : (v < yellow ? 'yellow' : 'green')) : (v > red ? 'red' : (v > yellow ? 'yellow' : 'green')); }

const views = {
  rent: { title: 'Рентабельність', heroL: { label: 'План (середня' + (noFcCount ? ', тільки проєкти з прогнозом' : '') + ')', value: (avgRentPlan*100).toFixed(0)+'%' }, heroR: { label: 'Прогноз (середня)' + (noFcCount ? ' · без прогнозу: ' + noFcCount : ''), value: (avgRentForecast*100).toFixed(0)+'%', cls: SQLC.hero.rent }, groups: mk(rentDefs, rentG), groupProjects: rentG },
  profit: { title: 'Прибуток', heroL: { label: 'План', value: fmtUAH(totalProfitPlan) }, heroR: { label: 'Прогноз' + (noFcCount ? ' · без прогнозу: ' + noFcCount : ''), value: fmtUAH(totalProfitForecast), cls: SQLC.hero.profit }, groups: mk(profitDefs, profitG), groupProjects: profitG },
  volume: { title: 'Роботи, акти, гроші', heroL: { label: 'Виконано і не оплачено', value: fmtUAH(volumeGapSum), cls: SQLC.hero.volume }, heroR: { label: 'Проєктів з розривом', value: volG.critical.length + volG.attention.length }, groups: mk(volDefs, volG), groupProjects: volG },
  etc: { title: 'Скільки годин ще потрібно', heroL: { label: 'Середній розрив до плану', value: fmtHrs(etcGapAvg), cls: SQLC.hero.etc }, heroR: { label: 'Проєктів з перевищенням', value: etcG.critical.length + etcG.attention.length }, groups: mk(etcDefs, etcG), groupProjects: etcG },
  evm: { title: 'Ефективність (гроші)', heroL: { label: 'Середня ефективність (гроші, за готовністю ПМа)', value: fmtRatio(cpiAvg), cls: SQLC.hero.evm }, heroR: { label: 'Проєктів з ефективністю < ' + fmtRatio(CPI_RED), value: evmG.critical.length }, groups: mk(evmDefs, evmG), groupProjects: evmG }
};

const attention = (SQLC.attention || []).map(function(a){ var p = projects.filter(function(x){ return x.id === a.id; })[0]; return { id: a.id, status: a.status, blocked: !!a.blocked, reds: a.reds, yellows: a.yellows, top: p && p.signals.length ? p.signals[0].t : '' }; });

// Проєкти (рішення власника 15.10.2026): рядок моніторить виконання річного плану по кількості проєктів. План = річний план; Факт = проєкти з підписаним договором; Прогноз = Факт + КП × конверсія
const pfcFactProjects = metricsRows.filter(function(r){ return toNum(r['contract_amount']) !== null || !!r['contract_file_url']; }).length;
const pfcFactHours = Math.round(metricsRows.reduce(function(s,r){ var hasC = toNum(r['contract_amount']) !== null || !!r['contract_file_url']; return s + (hasC ? (toNum(r['actual_hours'])||0) : 0); }, 0));
// Години, не покриті оплатою: витрачені години × частка собівартості, яку не покрито надходженням коштів (алярм власника 15.10.2026)
const pfcUnpaidHours = Math.round(metricsRows.reduce(function(s,r){ var h = toNum(r['actual_hours'])||0, cst = toNum(r['actual_cost'])||0, P = toNum(r['money_received'])||0; return s + ((h > 0 && cst > 0) ? h * Math.max(0, 1 - P / cst) : 0); }, 0));

// Прибуток факт = підписані акти − собівартість факт (рішення власника 11.10.2026); лише проєкти з надходженням коштів (Факт)
const pfcFactProfit = Math.round(metricsRows.reduce(function(s,r){ return s + (((toNum(r['money_received'])||0) > 0) ? ((toNum(r['acts_amount'])||0) - (toNum(r['actual_cost'])||0)) : 0); }, 0));
const pfcForecastProfit = Math.round(metricsRows.reduce(function(s,r){ var v = toNum(r['profit_forecast']); return s + (v === null ? 0 : v); }, 0));

// Рентабельність портфеля — на базі собівартості (рішення власника 14.10.2026: 25% від ЗП + витрати): прибуток / собівартість. План — archi_thresholds.plan_year_rent_pct; факт = прибуток факт / собівартість факт (проєкти з надходженням); прогноз = Σ прибуток прогнозу / Σ (контракт − прибуток прогнозу) по проєктах з прогнозом ПМа
const pfcFactCost = metricsRows.reduce(function(s,r){ return s + (((toNum(r['money_received'])||0) > 0) ? (toNum(r['actual_cost'])||0) : 0); }, 0);
const pfcFcCost = metricsRows.reduce(function(s,r){ var pf = toNum(r['profit_forecast']); return s + (pf === null ? 0 : ((toNum(r['contract_amount'])||0) - pf)); }, 0);
const pfcRentFact = pfcFactCost > 0 ? Math.round(pfcFactProfit / pfcFactCost * 1000) / 10 : null;
const pfcRentForecast = pfcFcCost > 0 ? Math.round(pfcForecastProfit / pfcFcCost * 1000) / 10 : null;
// Рентабельність портфеля від контракту (16.10.2026): план = plan_year_profit / plan_year_contract; факт = прибуток факт / підписані акти (проєкти з надходженням); прогноз = Σ прибуток прогнозу / Σ контракт (проєкти з прогнозом)
const pfcFactActs = metricsRows.reduce(function(s,r){ return s + (((toNum(r['money_received'])||0) > 0) ? (toNum(r['acts_amount'])||0) : 0); }, 0);
const pfcFcContract = metricsRows.reduce(function(s,r){ return s + (toNum(r['profit_forecast']) === null ? 0 : (toNum(r['contract_amount'])||0)); }, 0);
const pfcRentContractPlan = rule('plan_year_contract', 0) > 0 ? Math.round(rule('plan_year_profit', 0) / rule('plan_year_contract', 0) * 1000) / 10 : null;
const pfcRentContractFact = pfcFactActs > 0 ? Math.round(pfcFactProfit / pfcFactActs * 1000) / 10 : null;
const pfcRentContractForecast = pfcFcContract > 0 ? Math.round(pfcForecastProfit / pfcFcContract * 1000) / 10 : null;

// Виконання портфеля (власник 29.10.2026: «скільки роботи зроблено відповідно до спаленого часу»): Факт = E-08 «Ефективність виконання» = Σ EV_год ÷ Σ AC_год (EV_год = готовність ПМа × BAC; готовність ПМа = earned_value_contract ÷ контракт, E-02), План = 1,00;
// Прогноз = E-05 «Ефективність годин» = Σ BAC ÷ Σ (AC + ETC_прогноз) по проєктах з ETC від ПМа. Агрегація по портфелю — зважена за годинами, окремого рішення власника немає
// BAC і AC годин — канон стадій (CLAUDE.md п. 14, рішення 4; FORMULAS §0, F-23): BAC = Σ плану 4 стадій (МБР, ЕП, П, Р), AC = Σ годин цих стадій (stage_data), як у SQL-вʼю archi_report_today
function stgBacAc(r){ var sd = obj(r['stage_data']), b = 0, a = 0, has = false; STAGES.forEach(function(s){ var x = sd[s]; if (!x) return; var p = toNum(x.etc_plan_hours); if (p === null) return; has = true; b += p; a += toNum(x.actual_hours_live) || 0; }); return has ? { bac: b, ac: a } : null; }
const pfcExecAgg = (function(){ var ev = 0, ac = 0; metricsRows.forEach(function(r){ var h = stgBacAc(r), c = toNum(r['contract_amount']), e = toNum(r['earned_value_contract']); if (h && h.bac > 0 && c !== null && c > 0 && e !== null) { ev += e / c * h.bac; ac += h.ac; } }); return ac > 0 ? Math.round(ev / ac * 100) / 100 : null; })();
const pfcEffFcAgg = (function(){ var b = 0, eac = 0; metricsRows.forEach(function(r){ var h = stgBacAc(r), etc = toNum(r['etc_forecast_total_hours']); if (h && h.bac > 0 && etc !== null) { b += h.bac; eac += h.ac + etc; } }); return eac > 0 ? Math.round(b / eac * 100) / 100 : null; })();

// Приріст готовності проти витрат команди по портфелю (CLAUDE.md п. 11, FORMULAS P-10): Σ по проєктах, що мають два знімки; вартість приросту = приріст готовності × контракт; витрати = години команди × ставка (SQL archi_weekly_progress)
const pfcWp = (function(){
  var n = 0, hours = 0, cost = 0, value = 0, contract = 0, wkMax = null, budget = 0, customer = 0, owner = 0, hist = {};
  metricsRows.forEach(function(r){
    var c = toNum(r['wp_cost']); if (!r['wp_prev_week'] || c === null) return;
    n += 1; hours += toNum(r['wp_hours']) || 0; cost += c; value += toNum(r['wp_value']) || 0; contract += toNum(r['contract_amount']) || 0;
    budget += toNum(r['wp_budget']) || 0; customer += toNum(r['wp_customer']) || 0; owner += toNum(r['wp_owner']) || 0;
    var w = String(r['wr_week'] || '').slice(0, 10); if (w && (wkMax === null || w > wkMax)) wkMax = w;
  });
  // История по тижнях: брутто Σ по проєктах за week_start (перевитрата одного проєкту НЕ гаситься економією іншого)
  metricsRows.forEach(function(r){
    var h = r['wp_hist']; if (typeof h === 'string') { try { h = JSON.parse(h); } catch(e) { h = null; } }
    (h || []).forEach(function(x){ var k = String(x[0]).slice(0, 10); var o = hist[k] || (hist[k] = { week: k, hours: 0, cost: 0, budget: 0, customer: 0, owner: 0 }); o.hours += Number(x[3]) || 0; o.cost += Number(x[4]) || 0; o.budget += Number(x[5]) || 0; o.customer += Number(x[6]) || 0; o.owner += Number(x[7]) || 0; });
  });
  var histArr = Object.keys(hist).sort().map(function(k){ var o = hist[k]; return { week: fmtDate(o.week), hours: Math.round(o.hours), cost: Math.round(o.cost), budget: Math.round(o.budget), customer: Math.round(o.customer), owner: Math.round(o.owner) }; });
  if (n === 0) return null;
  return { n: n, hours: Math.round(hours * 10) / 10, cost: Math.round(cost), value: Math.round(value), result: Math.round(value - cost),
           dReadyPP: contract > 0 ? Math.round(value / contract * 1000) / 10 : null, idx: cost > 0 ? Math.round(value / cost * 100) / 100 : null, weekTo: fmtDate(wkMax), budget: Math.round(budget), customer: Math.round(customer), owner: Math.round(owner), reserve: Math.round(budget - customer), hist: histArr };
})();

// КП — окрема воронка, поки без окремої таблиці по кожному КП — лише місячна лічилка (kp_log) з бота ('КП: N')
let kpMonthSent = 0, kpYearSent = 0;
try { var kpj1 = (($('Fetch KP Log Sum (MiniApp)').first() || {}).json || {}); kpMonthSent = Number(kpj1.kp_month) || 0; kpYearSent = Number(kpj1.kp_year) || 0; } catch(e1) {
  try { var kpj2 = (($('Fetch KP Log Sum (Chat)').first() || {}).json || {}); kpMonthSent = Number(kpj2.kp_month) || 0; kpYearSent = Number(kpj2.kp_year) || 0; } catch(e2) { kpMonthSent = 0; kpYearSent = 0; }
}
const KP_CONVERSION_PCT = 20; // конверсія КП→Договір: 1 з 5 (рішення власника 16.10.2026; було 25% — припущення 03.10.2026)
// Прогноз нових договорів за рік = КП, надіслані за рік ÷ 5 (власник 28.10.2026): його ж беруть прогнози «Договори, підписано» і «Проєкти» (у Workload НЕ входить — CLAUDE.md п. 10)
const kpYearContracts = Math.round(kpYearSent * KP_CONVERSION_PCT / 100);
// План КП (рік) = План проєктів ÷ конверсія (70 ÷ 20% = 350); план договорів з КП = План проєктів
const kpPlanYear = KP_CONVERSION_PCT > 0 ? Math.round(rule('plan_year_projects', 0) / (KP_CONVERSION_PCT / 100)) : null;
const pfcForecastProjects = pfcFactProjects + kpYearContracts;
// Workload прогноз = ПРОГНОЗ ЗАВАНТАЖЕННЯ КОМАНДИ = Σ ETC_прогноз (етс від ПМів) по всіх проєктах; відпрацьований час НЕ входить, нові договори з КП НЕ входять (власник 29.10.2026: «на скільки часу в команди ще є робота, а не скільки вже зроблено»)
const pfcForecastHours = Math.round(metricsRows.reduce(function(s,r){ return s + (toNum(r['etc_forecast_total_hours'])||0); }, 0));

// Колір прогнозу року проти плану (власник 24.10.2026: «прогноз по року має бути червоним, має кидатися в очі»). 🟢 = прогноз ≥ плану.
// idxSig — індекс ÷ план з порогами idx_yellow / idx_red (ті самі, що archi_idx_signal у SQL; з 30.10.2026 обидва = 1,00, порівняння по округленому до 0,01)
const IDX_YELLOW = rule('idx_yellow', 0.9), IDX_RED = rule('idx_red', 0.7);
function idxSig(f, p){ if (f === null || f === undefined || !(p > 0)) return ''; var r = Math.round(f / p * 100) / 100; return r < IDX_RED ? 'red' : (r < IDX_YELLOW ? 'yellow' : 'green'); }
function ppSig(f, p){ if (f === null || f === undefined || p === null || p === undefined) return ''; var d = Math.round((p - f) * 10) / 10; return (f < 0 || d > RENT_DROP_PP_RED) ? 'red' : (d > RENT_DROP_PP ? 'yellow' : 'green'); }
// п. 15 (власник, 30.10.2026): одна логіка для всіх рядків таблиці портфеля — Різниця = результат − план; від'ємна → 🔴, ≥ 0 → 🟢, жовтого немає.
// Результат: Проєкти, Прибуток, Рентабельність, Договори з КП — прогноз; Workload — факт + прогноз (прогноз = лише робота, що лишилась, п. 10); Зроблено ÷ витрачено — прогноз (план 1,00).
function dSig(d){ return (d === null || d === undefined || isNaN(d)) ? '' : (d < 0 ? 'red' : 'green'); }
const PLAN_PROJECTS = rule('plan_year_projects', 0), PLAN_HOURS = rule('plan_year_hours', 0), PLAN_PROFIT = rule('plan_year_profit', 0);
const pfcDiff = { projects: PLAN_PROJECTS > 0 ? pfcForecastProjects - PLAN_PROJECTS : null, hours: PLAN_HOURS > 0 ? pfcFactHours + pfcForecastHours - PLAN_HOURS : null,
  effFc: pfcEffFcAgg == null ? null : Math.round((pfcEffFcAgg - 1) * 100) / 100, profit: PLAN_PROFIT > 0 ? pfcForecastProfit - PLAN_PROFIT : null,
  rentContract: (pfcRentContractForecast == null || pfcRentContractPlan == null) ? null : Math.round((pfcRentContractForecast - pfcRentContractPlan) * 10) / 10,
  kpContracts: PLAN_PROJECTS > 0 ? kpYearContracts - PLAN_PROJECTS : null };
const pfcFcSig = { projects: dSig(pfcDiff.projects), kpContracts: dSig(pfcDiff.kpContracts), effFc: dSig(pfcDiff.effFc), effFact: idxSig(pfcExecAgg, 1), hours: dSig(pfcDiff.hours),
  rentContract: dSig(pfcDiff.rentContract), rentCost: ppSig(pfcRentForecast, rule('plan_year_rent_pct', 0)), profit: dSig(pfcDiff.profit) };

if (pfcWp) { pfcWp.sig = idxSig(pfcWp.idx, 1); }
const data = {
  asOf: fmtDay(maxTs(metricsRows)) || '—',
  projects: projects, attention: attention,
  counts: SQLC.counts,
  totalContract: totalContract, totalContractFmt: fmtUAH(totalContract),
  pfc: { planProjects: rule('plan_year_projects', 0), planHours: rule('plan_year_hours', 0), planProfit: rule('plan_year_profit', 0), planRentPct: rule('plan_year_rent_pct', 0), factRentPct: pfcRentFact, forecastRentPct: pfcRentForecast, planRentContractPct: pfcRentContractPlan, factRentContractPct: pfcRentContractFact, forecastRentContractPct: pfcRentContractForecast, factProfit: pfcFactProfit, forecastProfit: pfcForecastProfit, factProjects: pfcFactProjects, forecastProjects: pfcForecastProjects, factHours: pfcFactHours, unpaidHours: pfcUnpaidHours, forecastHours: pfcForecastHours, kpMonthSent: kpMonthSent, kpYearSent: kpYearSent, kpPlanYear: kpPlanYear, kpConversionPct: KP_CONVERSION_PCT, kpProjectedContracts: kpYearContracts, execIdx: pfcExecAgg, effFcIdx: pfcEffFcAgg, wp: pfcWp, fcSig: pfcFcSig, diff: pfcDiff },
  rules: { OPT_ETC_DROP: OPT_ETC_DROP, OPT_READY_MAX: OPT_READY_MAX, RENT_DROP_PP: RENT_DROP_PP, RENT_DROP_PP_RED: RENT_DROP_PP_RED, PROFIT_YELLOW_PCT: PROFIT_YELLOW_PCT, PROFIT_RED_PCT: PROFIT_RED_PCT, CPI_RED: CPI_RED, CPI_YELLOW: CPI_YELLOW, ETC_RED: ETC_RED, ETC_YELLOW: ETC_YELLOW, UNPAID_YELLOW: UNPAID_YELLOW, UNPAID_RED: UNPAID_RED, SLIP_RED_DAYS: SLIP_RED_DAYS, BLOCK_RED_DAYS: BLOCK_RED_DAYS },
  views: views
};
return [{ json: data }];