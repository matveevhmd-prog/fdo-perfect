#!/usr/bin/env python3
"""П2h (20.11.2026): виправлення верстки П2g за скрінами власника і сирою відповіддю моделі (виконання 9693).
Дефекти: (1) Insight дублює «Проблеми», коли відповідь моделі відхилено (FORBID/числа) і спрацьовує запасний текст; (2) фрагмент після «;» у заголовку «Висновку» без маркера;
(3) вступ «Тези для дзвінка…» оформлено як пункт, тези з малої літери, теза повторює Impact; (4) немає візуальних акцентів (жирним — числа з одиницями й коди проєктів).
Будує Sanitize_Reply.p2h.js з p2g; Build_Request_Body.p2h.js = p2g без змін."""
import os, shutil
here = os.path.dirname(os.path.abspath(__file__))
def rep(s, old, new):
    assert s.count(old) == 1, ('anchor count', s.count(old), old[:90])
    return s.replace(old, new)
shutil.copyfile(os.path.join(here, 'Build_Request_Body.p2g.js'), os.path.join(here, 'Build_Request_Body.p2h.js'))
s = open(os.path.join(here, 'Sanitize_Reply.p2g.js'), encoding='utf-8').read()

# 1. помічники: акценти, нормалізація для дедуплікації, велика літера
s = rep(s, "function blk(arr, ico, name, text){",
"""function emph(x){
  return String(x)
    .replace(/(^|[^\\w\\-])((?:[A-Z]{2,}-\\d+|\\d{2}-\\d{2,3}))(?![\\w\\-])/g, '$1<b>$2</b>')
    .replace(/([−+\\-]?\\d[\\d ]*(?:[.,]\\d+)?)( ?(?:грн|дн\\.|днів|дні|день|год|г|%|п\\.п\\.))/g, '<b>$1$2</b>');
}
function nrm(x){ return String(x).toLowerCase().replace(/<[^>]+>/g, '').replace(/[^а-яіїєґa-z0-9]/g, ''); }
function capFirst(x){ x = String(x); return x.charAt(0).toUpperCase() + x.slice(1); }
function blk(arr, ico, name, text){""")
s = rep(s, "arr.push((i > 0 && /^[а-яіїєґa-z]/.test(l) ? '↳ ' : '• ') + l); }); }",
           "arr.push((i > 0 && /^[а-яіїєґa-z]/.test(l) ? '↳ ' : '• ') + emph(l)); }); }")
s = rep(s, "ss.forEach(function(l, i){ arr.push(i === 0 ? first + l : '↳ ' + l); }); }",
           "ss.forEach(function(l, i){ arr.push(i === 0 ? first + emph(l) : '↳ ' + emph(l)); }); }")

# 2. «Висновок»: заголовок жирним, продовження через «↳», порожній рядок перед пріоритетами
s = rep(s, "      if (hd) splitSent(hd).forEach(function(l){ out.push(l); });\n",
"      if (hd) splitSent(hd).forEach(function(l, i){ out.push(i === 0 ? '<b>' + l + '</b>' : '↳ ' + emph(l)); });\n      if (hd && pr.length) out.push('');\n")

# 3. Insight не дублює «Проблеми»
s = rep(s, "    blk(out, '💡', 'Insight', ins);\n",
"    var insDup = (ins === c.fbInsight) && c.problems.join('\\n').indexOf(String(c.fbInsight)) >= 0;   // запасний Insight = рядок «Проблем» — не повторюємо\n    if (!insDup) blk(out, '💡', 'Insight', ins);\n")

# 4. Action «дзвінок»: вступ окремим рядком, тези з великої літери, без повторів Insight/Impact
s = rep(s, "        if (rt.type === 'call') splitSent(tx).forEach(function(l){ out.push('• ' + l); });\n",
"""        if (rt.type === 'call') {
          var seen = nrm((insDup ? '' : ins) + ' ' + (imp || '')), th = splitSent(tx), intro = null;
          var mi = /^(Тези для дзвінка[^:]*?)(?::\\s*(.*))?$/i.exec(th[0] || '');
          if (mi) { intro = mi[1] + (mi[2] ? ':' : ''); th[0] = mi[2] || ''; th = th.filter(Boolean); }
          if (intro) out.push(intro);
          th.filter(function(l){ var n = nrm(l); return n.length < 12 || seen.indexOf(n) < 0; }).forEach(function(l){ out.push('• ' + emph(capFirst(l))); });
        }
""")
open(os.path.join(here, 'Sanitize_Reply.p2h.js'), 'w', encoding='utf-8').write(s)
print('OK', len(s))
