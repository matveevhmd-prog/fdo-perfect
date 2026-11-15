// ===== П2b: картка проєкту збирається кодом (кольори з cls SQL), LLM пише лише insight/impact/action =====
const DASH = '—';
function fn1(v){ return (Math.round(v*10)/10).toLocaleString('uk-UA', { maximumFractionDigits: 1 }); }
function fMoney(v){ if (v===null||v===undefined||isNaN(v)) return DASH; return (v<0 ? '−' : '') + Math.round(Math.abs(v)).toLocaleString('uk-UA') + ' грн'; }
function fPctF(v){ if (v===null||v===undefined||isNaN(v)) return DASH; var x = Math.round(v*1000)/10; return (x<0 ? '−' : (x>0 ? '+' : '')) + Math.abs(x).toLocaleString('uk-UA', { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + '%'; }
function fHrs(v){ return (v===null||v===undefined||isNaN(v)) ? DASH : fn1(v) + ' г'; }
function fHrsSigned(v){ return (v===null||v===undefined||isNaN(v)) ? DASH : (v<0 ? '−' : (v>0 ? '+' : '')) + fn1(Math.abs(v)) + ' г'; }
const mentionedIds = projects.filter(function(p){ return String(text).toUpperCase().indexOf(String(p.id).toUpperCase()) >= 0; }).map(function(p){ return p.id; });
const CARD_MODE = (intent === 'q1') || mentionedIds.length > 0;
function cardRank(p){ return (p.blocker ? 0 : (sevOrder[p.status] === undefined ? 3 : sevOrder[p.status] + 1)); }
function cardSort(a, b){
  var d = cardRank(a) - cardRank(b); if (d) return d;
  var ra = numOK(a.rentForecast) ? a.rentForecast : 1e9, rb = numOK(b.rentForecast) ? b.rentForecast : 1e9;
  return ra - rb;
}
function neg(c, v){ return c; }   // колір лише з cls (SQL); код не перераховує
function mark(c){ return c ? ' ' + ICON[c] : ''; }
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
  var facts = [hours.join(' '), money.join(' '), probs.join(' '), (p.signals||[]).map(function(s){ return s.t; }).join(' '), pmAsk(p), String(p.id)].join(' ');
  var topSig = (p.signals||[]).filter(function(s){ return s.c === 'red' || s.c === 'yellow'; })[0];
  return {
    id: p.id,
    icon: p.blocker ? '⛔' : ICON[p.status],
    hours: hours, money: money, problems: probs,
    facts: facts,
    fbInsight: topSig ? topSig.t : 'Відхилень від плану за сигналами немає.',
    fbAction: pmAsk(p) ? pmAsk(p) : 'уточнити в ПМа'
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
