// Валідатор відповіді чату (B-17, 13.11.2026): прибирає мета-текст LLM і дубльовані версії відповіді.
// Цей файл — еталон; той самий код стоїть у вузлі `Sanitize Reply` між рядками-маркерами validate.
// <validate>
function validateReply(t) {
  var META = /(використано теги markdown|виправляю нижче|у правильному форматі|markdown замість html|ось виправлен|виправлена версі)/i;
  var lines = String(t).split('\n').filter(function (l) { return !META.test(l); });
  t = lines.join('\n');
  // дублі: кожна відповідь починається «Станом на ДД.ММ.РРРР»; кілька таких заголовків = кілька версій однієї відповіді
  var re = /^[ \t]*Станом на \d{2}\.\d{2}\.\d{4}[ \t]*$/gm;
  var idx = [], m;
  while ((m = re.exec(t)) !== null) idx.push(m.index);
  if (idx.length > 1) {
    var parts = idx.map(function (s, i) { return t.slice(s, i + 1 < idx.length ? idx[i + 1] : t.length).replace(/[\s━─\-]+$/g, '').trim(); });
    var longest = parts.reduce(function (a, b) { return b.length > a.length ? b : a; }, '');
    var last = parts[parts.length - 1];
    t = last.length >= longest.length * 0.6 ? last : longest;   // остання версія, якщо вона не обрізана; інакше найповніша
  }
  return t.replace(/\n{3,}/g, '\n\n').trim();
}
// </validate>
if (typeof module !== 'undefined') module.exports = { validateReply: validateReply };
