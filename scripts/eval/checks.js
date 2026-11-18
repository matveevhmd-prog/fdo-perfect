// Автоперевірки відповіді чат-картки ARCHI (план PLAN_ANALYTICS_RACI §2.2). Чисті функції, без мережі.
// Вхід: raw (текст LLM), stop (stop_reason), brb (вихід Build Request Body), final (текст після Sanitize Reply).
function nums(s){ var m = String(s).match(/\d+(?:\s\d{3})*(?:[.,]\d+)?/g) || []; return m.map(function(x){ return x.replace(/\s/g,'').replace(',','.'); }); }
function wc(s){ return String(s||'').trim().split(/\s+/).filter(Boolean).length; }
function parseStrict(raw){
  var t = String(raw).trim().replace(/^```(?:json)?/i,'').replace(/```\s*$/,'').trim();
  try { return JSON.parse(t); } catch(e){ return null; }
}
function run(ctx){
  var res = [], raw = ctx.raw, final = ctx.final, brb = ctx.brb, cd = brb.cardData;
  var J = parseStrict(raw);
  function add(id, name, ok, detail){ res.push({ id:id, name:name, ok:!!ok, detail:detail||'' }); }
  add('C1','JSON розбирається без відновлення', !!J, J ? '' : 'потрібен parseLoose або відповідь обрізана');
  add('C2','Модель завершила відповідь (stop_reason=end_turn)', ctx.stop === 'end_turn', 'stop_reason=' + ctx.stop);
  var cards = (J && J.cards) || {};
  var miss = cd.order.filter(function(id){ return !cards[id]; });
  add('C3','Є картка на кожен проєкт у вибірці', !miss.length, miss.length ? 'немає: ' + miss.join(', ') : '');
  // числа
  var allowed = {}; nums(cd.pfacts || '').forEach(function(n){ allowed[n]=1; });
  cd.order.forEach(function(id){ nums(cd.cards[id].facts).forEach(function(n){ allowed[n]=1; }); });
  var badN = [], totalN = 0;
  cd.order.forEach(function(id){
    var own = {}; nums(cd.cards[id].facts).forEach(function(n){ own[n]=1; });
    ['insight','impact','action'].forEach(function(f){
      var v = cards[id] && cards[id][f]; if (!v) return;
      nums(v).forEach(function(n){ totalN++; if (!own[n]) badN.push(id + '.' + f + ':' + n); });
    });
  });
  if (J && J.portfolio) {
    var ptxt = [J.portfolio.headline, J.portfolio.pipeline].concat(J.portfolio.priorities || []).join(' ');
    nums(ptxt).forEach(function(n){ totalN++; if (!allowed[n]) badN.push('portfolio:' + n); });
  }
  add('C4','Усі числа відповіді є у фактах (немає вигаданих)', !badN.length, badN.length ? badN.length + ' з ' + totalN + ': ' + badN.slice(0,6).join(', ') : totalN + ' чисел перевірено');
  // довжини
  var longF = [];
  cd.order.forEach(function(id){ var c = cards[id]||{}; if (wc(c.insight)>30) longF.push(id+'.insight='+wc(c.insight)); if (wc(c.impact)>30) longF.push(id+'.impact='+wc(c.impact)); if (wc(c.action)>45) longF.push(id+'.action='+wc(c.action)); });
  add('C5','Ліміти довжини: insight/impact ≤30, action ≤45 слів', !longF.length, longF.join(', '));
  add('C6','Фінальне повідомлення ≤ 3900 символів і не скорочене', final.length <= 3900 && !/відповідь скорочено/.test(final), 'довжина ' + final.length);
  add('C7','Немає markdown-залишків і зламаних тегів', !/(\*\*|^#{1,6}\s|```)/m.test(final), '');
  var forb = final.match(/(Залишок_план|Залишок_прогноз|\bCPI\b|\bSPI\b)/g);
  add('C8','Заборонені терміни відсутні (п. 1, п. 14)', !forb, forb ? forb.join(',') : '');
  // B-28
  var stopBad = [];
  cd.order.forEach(function(id){ var c = cards[id]||{}; var t = [c.insight,c.impact].join(' '); if (/⛔/.test((cd.cards[id].icon||'') + cd.cards[id].facts) && /(обвал|просад|впав|знизил)[а-яіїєґ]*\s+(рентабельн|маржин)|через\s+зупинк[а-яіїєґ]+[^.]*рентабельн/i.test(t)) stopBad.push(id); });
  add('C9','B-28(3): зупинка не подається як причина падіння рентабельності', !stopBad.length, stopBad.join(', '));
  var resBad = [];
  cd.order.forEach(function(id){ var c = cards[id]||{}; if (/(людей|архітектор|ресурс)/i.test(c.insight||'') && /Фіндиректор/.test(c.action||'') && !/(ПМ|ГАП|Головн\w+ конструктор)/.test(c.action||'')) resBad.push(id); });
  add('C10','B-28(4): запит на ресурси адресовано ПМ/ГАП/Головному конструктору', !resBad.length, resBad.join(', '));
  var penalty = final.match(/штраф[а-яіїєґ]*[^.\n]{0,30}\d/gi);
  add('C11','Немає вигаданих сум штрафів (даних про штрафи немає)', !penalty, penalty ? penalty.join('|') : '');
  var probNeed = (final.match(/🚧[\s\S]*?(?=💡)/g) || []).filter(function(b){ return /Потрібно/.test(b); }).length;
  add('C12','B-28(2): у блоці «Проблеми» немає «Потрібно» (пропозицій рішень)', probNeed === 0, probNeed + ' блоків');
  var port = (final.split('━━━━━━━━━━━━')[0] || '');
  var pl = port.split('\n').filter(function(l){ return /^(🔴|🟡|🟢|⛔|❓)/.test(l); });
  var withNames = pl.filter(function(l){ return /[A-Z0-9]{2,}-\d+|DEMO-\d+/.test(l); });
  add('C13','B-28(1): блок портфеля однотипний, ❓ є, назв проєктів у лічильниках немає', pl.some(function(l){ return /^❓/.test(l); }) && !withNames.length, 'рядків лічильників ' + pl.length + ', з назвами ' + withNames.length + ', ❓: ' + pl.some(function(l){ return /^❓/.test(l); }));
  var routed = cd.order.filter(function(id){ return cd.cards[id].route; });
  var routeBad = routed.filter(function(id){ var c = cards[id]||{}; return !c.action; });
  add('C14','Для кожного проєкту з порадою рушія є Action', !routeBad.length, routeBad.join(', '));
  var rej = [];
  cd.order.forEach(function(id){ ['insight','impact','action'].forEach(function(f){ var v = cards[id] && cards[id][f]; if (v && final.indexOf(String(v).trim().slice(0,500).replace(/&/g,'&amp;')) < 0) rej.push(id+'.'+f); }); });
  add('C15','Код прийняв усі поля LLM (жодне не замінено шаблоном)', !rej.length, rej.join(', '));
  return res;
}
module.exports = { run: run, parseStrict: parseStrict, nums: nums, wc: wc };
