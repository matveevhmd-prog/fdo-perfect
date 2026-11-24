#!/usr/bin/env python3
"""П2g (19.11.2026, п. 4 власника «все стовпчиком»): верстку блоків Insight / Impact / Action і «Висновок Archi» виконує КОД (Sanitize Reply), а не промпт.
Будує Sanitize_Reply.p2g.js з p2f; Build_Request_Body.p2g.js = p2f без змін (потрібен для стенду scripts/eval, CODE_VARIANT=p2g)."""
import os, shutil
here = os.path.dirname(os.path.abspath(__file__))
def rep(s, old, new):
    assert s.count(old) == 1, ('anchor count', s.count(old), old[:90])
    return s.replace(old, new)
shutil.copyfile(os.path.join(here, 'Build_Request_Body.p2f.js'), os.path.join(here, 'Build_Request_Body.p2g.js'))
s = open(os.path.join(here, 'Sanitize_Reply.p2f.js'), encoding='utf-8').read()

# 1. помічники верстки: речення — окремі рядки, «;» не склеює показники
s = rep(s, "var DBG = {};",
"""var ABBR = ['дн', 'год', 'тиж', 'грн', 'п', 'пп', 'тис', 'т', 'ін', 'р', 'ст', 'напр', 'рр', 'млн', 'млрд'];
function splitSent(t, noClause){
  var x = String(t).replace(/\\s+/g, ' ').trim(), out = [], cur = '';
  for (var i = 0; i < x.length; i++) {
    var ch = x.charAt(i); cur += ch;
    if (x.charAt(i + 1) !== ' ') continue;
    if (ch === ';') { out.push(cur.slice(0, -1).trim()); cur = ''; continue; }
    if (ch === '.' || ch === '!' || ch === '?') {
      var w = cur.slice(0, -1).split(/[\\s(]/).pop().toLowerCase().replace(/[^а-яіїєґa-z.]/g, '').replace(/\\./g, '');
      if (ABBR.indexOf(w) < 0 && /[А-ЯІЇЄҐA-Z«"]/.test(x.charAt(i + 2))) { out.push(cur.trim()); cur = ''; }
    }
  }
  if (cur.trim()) out.push(cur.trim());
  var res = [];
  out.filter(Boolean).forEach(function(l){ var k = noClause ? -1 : l.indexOf(' — '); if (k < 0 && !noClause) k = l.indexOf(': '); if (!noClause && l.length > 120 && k > 25 && k < l.length - 25) { res.push(l.slice(0, k)); res.push(l.slice(k + (l.charAt(k) === ':' ? 2 : 3))); } else res.push(l); });
  return res;
}
function blk(arr, ico, name, text){ arr.push('', ico + ' <b>' + name + '</b>'); splitSent(text).forEach(function(l, i){ arr.push((i > 0 && /^[а-яіїєґa-z]/.test(l) ? '↳ ' : '• ') + l); }); }
function bulletWithRest(arr, first, text){ var ss = splitSent(text); ss.forEach(function(l, i){ arr.push(i === 0 ? first + l : '↳ ' + l); }); }
var DBG = {};""")

# 1б. заборонені висновки відхиляє КОД (знахідки 4 і 11; п. 10): завантаження команди й оцінні слова про причини
s = rep(s, "var DBG = {};", "var FORBID = /(недозавантаж|перезавантаж|завантажен[аоіи]? (менш|більш)|потужност\\S* команд|з вини|вин[аиі] замовник|бездіяльн|недбал|халатн)/i;\nvar DBG = {};")
s = rep(s, "var okP = function(v, mx){ if (typeof v !== 'string' || !v.trim()) return null;", "var okP = function(v, mx){ if (typeof v !== 'string' || !v.trim() || FORBID.test(v)) return null;")
s = rep(s, "function ok(v){ if (typeof v !== 'string' || !v.trim()) return null;", "function ok(v){ if (typeof v !== 'string' || !v.trim() || FORBID.test(v)) return null;")

# 2. «Висновок Archi»: заголовок — рядки, пріоритети — «•» + «↳», конвеєр — 📈
s = rep(s, "      if (hd) out.push(hd);\n      pr.forEach(function(x, i){ out.push('• ' + (i === 0 ? 'Спершу: ' : '') + x); });\n      if (pl) out.push('📈 ' + pl);",
"      if (hd) splitSent(hd).forEach(function(l){ out.push(l); });\n      pr.forEach(function(x, i){ bulletWithRest(out, '• ' + (i === 0 ? 'Спершу: ' : ''), x); });\n      if (pl) bulletWithRest(out, '📈 ', pl);")

# 3. Insight / Impact: окремі блоки з порожнім рядком і «•»
s = rep(s, "    out.push('', '💡 <b>Insight:</b> ' + ins);\n    if (imp) out.push('⚠️ <b>Impact:</b> ' + imp);\n",
"    blk(out, '💡', 'Insight', ins);\n    if (imp) blk(out, '⚠️', 'Impact', imp);\n")

# 3б. «Проблеми»: перелік причин через «;» (код Build Request Body) — окремі рядки
s = rep(s, "    out = out.concat(c.problems);\n", "    c.problems.forEach(function(l){ var pr = String(l).split('; '); out.push(pr[0]); pr.slice(1).forEach(function(x){ out.push('↳ ' + x); }); });\n")

# 4. Action: заголовок окремим рядком; «дзвінок» — тези рядками; доручення/запит — готовий текст у лапках
old = s[s.index("    if (routed) {"):s.index("  });\n  var restKeys")]
new = """    if (routed) {
      var RL = { command: 'доручення', propose: 'запит варіантів', call: 'дзвінок власника' };
      routes.forEach(function(rt, ri){
        var tx = ri === 0 ? act : acts[ri];
        if (!tx) return;   // немає тексту від LLM для маршруту — не вигадуємо
        out.push('', '🎯 <b>Action · ' + (RL[rt.type] || rt.type) + (rt.to && rt.to !== 'власник' ? ' → ' + rt.to : '') + '</b>');
        if (rt.type === 'call') splitSent(tx).forEach(function(l){ out.push('• ' + l); });
        else { var ql = splitSent(tx, true); ql[0] = '«' + ql[0]; ql[ql.length - 1] += '»'; ql.forEach(function(l){ out.push(l); }); }
      });
      out.push('', '━━━━━━━━━━━━', '');
    } else { blk(out, '🎯', 'Action', act); out.push('', '━━━━━━━━━━━━', ''); }
"""
s = s.replace(old, new)
open(os.path.join(here, 'Sanitize_Reply.p2g.js'), 'w', encoding='utf-8').write(s)
print('OK', len(s))
