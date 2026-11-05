import { workflow, node, trigger, newCredential, expr } from '@n8n/workflow-sdk';

const everyFiveMinutes = trigger({
  type: 'n8n-nodes-base.scheduleTrigger',
  version: 1.4,
  config: { name: 'Every 5 Minutes', parameters: { rule: { interval: [{ field: 'minutes', minutesInterval: 5 }] } }, output: [{}] }
});

const manualTest = trigger({
  type: 'n8n-nodes-base.manualTrigger',
  version: 1,
  config: { name: 'Manual Test', output: [{}] }
});

const findDueOwners = node({
  type: 'n8n-nodes-base.postgres',
  version: 2.8,
  config: {
    name: 'Find Due Owners',
    parameters: { resource: 'database', operation: 'executeQuery', query: "SELECT ('' || telegram_user_id) AS chat_id, ('' || company_id) AS company_id, false AS force FROM public.owner_prefs WHERE enabled AND EXTRACT(isodow FROM (now() AT TIME ZONE tz)) = ANY (days) AND (now() AT TIME ZONE tz)::time >= brief_time AND (now() AT TIME ZONE tz)::time < brief_time + interval '30 minutes' AND last_sent_on IS DISTINCT FROM (now() AT TIME ZONE tz)::date" },
    credentials: { postgres: newCredential('Postgres account') },
    output: [{ chat_id: '304884647', company_id: '00000000-0000-4000-8000-000000000001', force: false }]
  }
});

const testRecipient = node({
  type: 'n8n-nodes-base.postgres',
  version: 2.8,
  config: {
    name: 'Test Recipient',
    parameters: { resource: 'database', operation: 'executeQuery', query: "SELECT ('' || ua.telegram_user_id) AS chat_id, ('' || c.company_id) AS company_id, true AS force FROM public.user_access ua, public.companies c WHERE ua.role = 'operator' AND c.code = 'DEMO' ORDER BY ua.id LIMIT 1" },
    credentials: { postgres: newCredential('Postgres account') },
    output: [{ chat_id: '304884647', company_id: '00000000-0000-4000-8000-000000000001', force: true }]
  }
});

const loadBrief = node({
  type: 'n8n-nodes-base.postgres',
  version: 2.8,
  config: {
    name: 'Load Brief',
    parameters: {
      resource: 'database',
      operation: 'executeQuery',
      query: "SELECT $1::text AS chat_id, $2::text AS company_id, $3::boolean AS force, public.archi_morning_brief($2::uuid) AS brief",
      options: { queryReplacement: expr('{{ [ String($json.chat_id), String($json.company_id), $json.force === true ] }}') }
    },
    credentials: { postgres: newCredential('Postgres account') },
    output: [{ chat_id: '304884647', company_id: '00000000-0000-4000-8000-000000000001', force: true, brief: { actions: [], horizon_7d: [] } }]
  }
});

const buildRequest = node({
  type: 'n8n-nodes-base.code',
  version: 2,
  config: {
    name: 'Build LLM Request',
    parameters: { mode: 'runOnceForEachItem', language: 'javaScript', jsCode: "const j = $json;\nconst brief = j.brief || {};\nconst actions = Array.isArray(brief.actions) ? brief.actions : [];\nconst fmtD = function (s) { const m = String(s).slice(0, 10).split('-'); return m.length === 3 ? m[2] + '.' + m[1] + '.' + m[0] : String(s); };\nconst fmtV = function (v) {\n  if (v === null || v === undefined) return '';\n  if (typeof v === 'number') return (Math.round(v * 10) / 10).toLocaleString('uk-UA').replace(new RegExp('[' + String.fromCharCode(160, 8239) + ']', 'g'), ' ');\n  if (Array.isArray(v)) return v.map(fmtV).join(', ');\n  if (typeof v === 'object') return JSON.stringify(v);\n  const s = String(v);\n  return /^\\d{4}-\\d{2}-\\d{2}/.test(s) ? fmtD(s) : s;\n};\nconst ff = function (facts) { const o = {}; Object.keys(facts || {}).forEach(function (k) { const x = fmtV(facts[k]); if (x !== '') o[k] = x; }); return o; };\nconst items = actions.map(function (a) { return { rank: a.rank, project_id: a.project_id, kind: a.kind, facts: ff(a.facts), advice: a.advice }; });\nconst SYSTEM = \"Ти — начальник штабу власника архітектурної компанії. Власник не має часу думати над кожним питанням: ти думаєш за нього і даєш конкретні кроки на сьогодні. Це не аналітика і не звіт, це план дій на день.\\n\\nВхід: JSON {today, actions}. actions — дії, які система вже відібрала й упорядкувала за пріоритетом. Кожна дія: rank, project_id, kind (тип події), facts (єдине джерело чисел і дат), advice (to_role — кому, mode — у якій формі, purpose — мета).\\n\\nЗначення ключів facts: days — днів простою; since — стоїть з дати; types — причини блокера (люди, гроші, замовник); need — що потрібно для розблокування (слова ПМа); stage — стадія (МБР, ЕП, П, Р); date — дата за планом; days_to — днів до дати (мінус = прострочено на стільки днів); amount — сума, грн; probability — ймовірність з 10; gap_hours — на скільки годин ETC_прогноз більший за ETC_факт; gap_pct_bac — це % від плану проєкту; etc_fact, etc_forecast — ETC у годинах; plan_pct, forecast_pct — рентабельність за планом і за прогнозом ПМа, %; quote — слова ПМа з розділу «Проблеми» тижневого звіту; action, owner, deadline — дія, відповідальний і термін із журналу нарад; week_start — тиждень звіту.\\n\\nЗавдання: для КОЖНОЇ дії, з тим самим rank і в тому самому порядку, напиши три поля.\\nheadline — що власнику зробити сьогодні: дієслово наказового способу, до 70 символів. Приклад: «Зателефонувати керівнику замовника по 24-11».\\nwhy — одна причина з одним-двома числами з facts, до 110 символів.\\nmessage — готовий текст, який власник може надіслати або сказати, до 300 символів, від першої особи власника, адресат — advice.to_role. Структура: (1) що сталося, факт із числом; (2) що саме ти очікуєш у відповідь; (3) до якого терміну: «сьогодні до 15:00» або «завтра до 12:00».\\nДля mode «нарада 1×1»: message — запрошення на нараду з двома-трьома питаннями до обговорення.\\nДля mode «дзвінок замовнику» і «рішення про ресурс»: message — короткі тези, що сказати або що вирішити, 2–3 пункти.\\n\\nЖорсткі правила:\\n1. Числа, суми, дати, номери проєктів — лише з facts і project_id цієї дії. Нічого не вигадуй, не округлюй, не додавай. Немає в facts — не пиши.\\n2. Не здогадуйся про причини. Якщо причини в facts немає — проси адресата пояснити причину.\\n3. Не оцінюй людей. Пиши про факти й очікуваний результат. Один лист — одне прохання.\\n4. Терміни: ETC (ніколи не «залишок»), ПМ, акт, аванс, субпідрядник.\\n5. Один рядок — одна думка. Без markdown, HTML і емодзі.\\n6. Для kind sub_blocked: facts.quote — слова ПМа; передай суть, не додавай сум і дат, яких немає.\\n7. Якщо даних для повідомлення замало, message починається з «Уточнити:» і містить питання адресату.\\n\\nПриклад (числа умовні, лише для стилю):\\nВхід: rank 1, project_id Х-01, kind act_due, facts {stage: П, date: 01.10.2026, days_to: -5, amount: 100 000}, advice {to_role: Фіндиректор, mode: повідомлення}\\nВихід: {\\\"rank\\\":1,\\\"headline\\\":\\\"Фіндиректору: з'ясувати прострочений акт по Х-01\\\",\\\"why\\\":\\\"Акт П на 100 000 грн прострочений на 5 днів (план 01.10.2026)\\\",\\\"message\\\":\\\"Акт П по Х-01 на 100 000 грн прострочений на 5 днів. Прошу з'ясувати причину і назвати дату оплати. Очікую відповідь сьогодні до 15:00.\\\"}\\n\\nВихід: лише JSON без пояснень і без ```:\\n{\\\"top_line\\\":\\\"одне речення, що найважливіше сьогодні, до 110 символів\\\",\\\"items\\\":[{\\\"rank\\\":1,\\\"headline\\\":\\\"...\\\",\\\"why\\\":\\\"...\\\",\\\"message\\\":\\\"...\\\"}]}\";\nconst user = JSON.stringify({ today: fmtD(brief.as_of), actions: items });\nconst body = JSON.stringify({ model: 'claude-sonnet-4-6', max_tokens: 2000, temperature: 0.2, system: SYSTEM, messages: [{ role: 'user', content: user }] });\nreturn { json: { chat_id: j.chat_id, company_id: j.company_id, force: j.force, brief: brief, items_fmt: items, body: body } };\n" },
    output: [{ chat_id: '304884647', company_id: '00000000-0000-4000-8000-000000000001', force: true, brief: {}, items_fmt: [], body: '{}' }]
  }
});

const callAnthropic = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.5,
  config: {
    name: 'Call Anthropic',
    onError: 'continueRegularOutput',
    parameters: {
      method: 'POST',
      url: 'https://api.anthropic.com/v1/messages',
      authentication: 'predefinedCredentialType',
      nodeCredentialType: 'anthropicApi',
      sendHeaders: true,
      headerParameters: { parameters: [{ name: 'anthropic-version', value: '2023-06-01' }] },
      sendBody: true,
      contentType: 'raw',
      rawContentType: 'application/json',
      body: expr('{{ $json.body }}'),
      options: { timeout: 90000 }
    },
    credentials: { anthropicApi: newCredential('Anthropic account') },
    output: [{ content: [{ type: 'text', text: '{}' }] }]
  }
});

const renderBrief = node({
  type: 'n8n-nodes-base.code',
  version: 2,
  config: {
    name: 'Validate And Render',
    parameters: { mode: 'runOnceForEachItem', language: 'javaScript', jsCode: "const src = $('Build LLM Request').item.json;\nconst brief = src.brief || {};\nconst actions = Array.isArray(brief.actions) ? brief.actions : [];\nconst itemsFmt = src.items_fmt || [];\nconst esc = function (s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); };\nconst fmtD = function (s) { const m = String(s).slice(0, 10).split('-'); return m.length === 3 ? m[2] + '.' + m[1] + '.' + m[0] : String(s); };\nconst fmtN = function (v) { return (Math.round(Number(v) * 10) / 10).toLocaleString('uk-UA').replace(new RegExp('[' + String.fromCharCode(160, 8239) + ']', 'g'), ' '); };\n\nlet parsed = null;\ntry {\n  const arr = Array.isArray($json.content) ? $json.content : [];\n  let t = arr.filter(function (c) { return c.type === 'text'; }).map(function (c) { return c.text; }).join('').trim();\n  t = t.replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();\n  parsed = JSON.parse(t);\n} catch (e) { parsed = null; }\nconst llmItems = parsed && Array.isArray(parsed.items) ? parsed.items : [];\n\nconst ids = {};\nactions.forEach(function (a) { ids[a.project_id] = 1; });\n(brief.horizon_7d || []).forEach(function (h) { ids[h.project_id] = 1; });\nconst SPS = ' ' + String.fromCharCode(160, 8239);\nconst NUM = new RegExp('\\\\d+(?:[' + SPS + ']\\\\d{3})*(?:[.,]\\\\d+)*', 'g');\nconst norm = function (t) { return t.replace(new RegExp('[' + SPS + ']', 'g'), '').replace(/,/g, '.'); };\nconst tokens = function (s) { return (String(s).match(NUM) || []).map(norm); };\nconst strip = function (s) {\n  let t = String(s);\n  Object.keys(ids).forEach(function (id) { t = t.split(id).join(' '); });\n  return t.replace(/\\b\\d{1,2}:\\d{2}\\b/g, ' ').replace(/1×1/g, ' ');\n};\nconst allowedFor = function (fa) {\n  const set = {}; const nums = {};\n  const add = function (tk) { set[tk] = 1; if ((tk.match(/\\./g) || []).length <= 1 && isFinite(parseFloat(tk))) nums[parseFloat(tk)] = 1; };\n  tokens(JSON.stringify(fa.facts)).forEach(function (tk) {\n    add(tk);\n    const m = /^(\\d{2})\\.(\\d{2})\\.\\d{4}$/.exec(tk);\n    if (m) { add(m[1] + '.' + m[2]); }\n  });\n  add('10');\n  return { set: set, nums: nums };\n};\nconst numbersOk = function (text, al) {\n  return tokens(strip(text)).every(function (tk) {\n    if (al.set[tk]) return true;\n    return (tk.match(/\\./g) || []).length <= 1 && isFinite(parseFloat(tk)) && al.nums[parseFloat(tk)] === 1;\n  });\n};\nconst itemOk = function (it, a, fa) {\n  if (!it || it.rank !== a.rank) return false;\n  if (typeof it.headline !== 'string' || typeof it.why !== 'string' || typeof it.message !== 'string') return false;\n  if (!it.headline.trim() || !it.why.trim() || !it.message.trim()) return false;\n  if (it.headline.length > 90 || it.why.length > 140 || it.message.length > 360) return false;\n  const all = it.headline + ' ' + it.why + ' ' + it.message;\n  if (/залишок/i.test(all)) return false;\n  const bad = Object.keys(ids).some(function (id) { return id !== a.project_id && all.indexOf(id) >= 0; });\n  if (bad) return false;\n  return numbersOk(all, allowedFor(fa));\n};\n\nconst fallback = function (a, fa) {\n  const f = fa.facts || {}; const p = a.project_id; const pu = (a.advice && a.advice.purpose) || '';\n  if (pu === 'blocker_customer') return { headline: 'Зателефонувати замовнику по ' + p, why: 'Проєкт стоїть ' + f.days + ' дн. (з ' + f.since + ')', message: 'Проєкт ' + p + ' стоїть ' + f.days + ' дн., очікуємо рішення замовника. Прошу назвати дату рішення. Очікую відповідь сьогодні.' };\n  if (pu === 'blocker_money') return { headline: 'Фіндиректору: зняти блок по ' + p, why: 'Проєкт стоїть ' + f.days + ' дн. (з ' + f.since + '), причина: гроші', message: 'Проєкт ' + p + ' стоїть ' + f.days + ' дн. через гроші. Прошу з’ясувати причину і назвати дату фінансування. Очікую відповідь сьогодні.' };\n  if (pu === 'blocker_people') return { headline: 'Вирішити по ресурсу для ' + p, why: 'Проєкт стоїть ' + f.days + ' дн. (з ' + f.since + '), причина: люди', message: 'Проєкт ' + p + ' стоїть ' + f.days + ' дн. через ресурс. Рішення: перенести людину або погодити нову дату із замовником.' };\n  if (pu === 'sub_payment') return { headline: 'Фіндиректору: розібрати оплату підряднику по ' + p, why: 'ПМ у звіті: ' + String(f.quote || '').slice(0, 90), message: 'У звіті ПМа по ' + p + ' проблема з підрядником. Прошу з’ясувати причину і назвати дату оплати. Очікую відповідь сьогодні.' };\n  if (pu === 'act_overdue') return { headline: 'Фіндиректору: з’ясувати прострочений акт по ' + p, why: 'Акт ' + f.stage + ' на ' + f.amount + ' грн, дата за планом ' + f.date, message: 'Акт ' + f.stage + ' по ' + p + ' на ' + f.amount + ' грн має дату ' + f.date + '. Прошу з’ясувати причину і назвати дату оплати. Очікую відповідь сьогодні.' };\n  if (pu === 'act_soon') return { headline: 'Нагадати ПМу про акт по ' + p, why: 'Акт ' + f.stage + ' за планом ' + f.date, message: 'Акт ' + f.stage + ' по ' + p + ' за планом ' + f.date + '. Прошу підтвердити готовність до підписання. Очікую відповідь сьогодні.' };\n  if (pu === 'doc_deadline') return { headline: 'Перевірити видачу документації по ' + p, why: 'Дедлайн ' + f.stage + ': ' + f.date, message: 'Дедлайн документації ' + f.stage + ' по ' + p + ' — ' + f.date + '. Прошу підтвердити, що встигаємо. Очікую відповідь сьогодні.' };\n  if (pu === 'meeting_action') return { headline: 'Нагадати про дію з наради по ' + p, why: 'Термін: ' + f.deadline, message: 'Дія з наради по ' + p + ': ' + String(f.action || '').slice(0, 120) + '. Термін ' + f.deadline + '. Прошу підтвердити виконання.' };\n  if (pu === 'etc_over') return { headline: 'Нарада 1×1 з ПМом по ' + p, why: 'ETC_прогноз більший за ETC_факт на ' + f.gap_hours + ' год', message: 'По ' + p + ' ETC_прогноз перевищує ETC_факт на ' + f.gap_hours + ' год. Прошу підготувати причини і план, як повернути прогноз у межі. Нарада завтра до 12:00.' };\n  if (pu === 'rent_below_plan') return { headline: 'Нарада 1×1 з ПМом по ' + p, why: 'Рентабельність: план ' + f.plan_pct + '%, прогноз ' + f.forecast_pct + '%', message: 'По ' + p + ' прогноз рентабельності ' + f.forecast_pct + '% при плані ' + f.plan_pct + '%. Прошу підготувати причини і дії. Нарада завтра до 12:00.' };\n  if (pu === 'forecast_missing') return { headline: 'Попросити ПМа дати прогноз по ' + p, why: 'Прогнозу рентабельності немає', message: 'По ' + p + ' немає прогнозу. Прошу подати ETC_прогноз у тижневому звіті. Очікую сьогодні до 15:00.' };\n  return { headline: 'Нагадати ПМу про звіт по ' + p, why: 'За поточний тиждень звіту немає', message: 'По ' + p + ' немає тижневого звіту. Прошу подати сьогодні до 15:00.' };\n};\n\nlet fb = 0;\nconst out = actions.map(function (a, i) {\n  const fa = itemsFmt[i] || { facts: {} };\n  const cand = llmItems.find(function (x) { return x && x.rank === a.rank; });\n  if (itemOk(cand, a, fa)) return { a: a, it: { headline: cand.headline, why: cand.why, message: cand.message } };\n  fb += 1;\n  return { a: a, it: fallback(a, fa) };\n});\n\nconst emoji = function (a) {\n  if (a.kind === 'blocker') return '⛔';\n  if (a.kind === 'sub_blocked' || (a.advice && (a.advice.purpose === 'act_overdue' || a.advice.purpose === 'blocker_money'))) return '💰';\n  if (a.kind === 'etc_red' || a.kind === 'rent_below') return '🔴';\n  return '🟡';\n};\nconst asOf = brief.data_updated_at ? fmtD(String(brief.data_updated_at).slice(0, 10)) : fmtD(brief.as_of);\nconst head = 'Станом на ' + asOf + '\\n\\n📋 <b>Ранковий брифінг · ' + fmtD(brief.as_of) + '</b>\\n\\n<b>План дій на день</b>';\nconst blocks = out.map(function (o, i) {\n  return '\\n\\n' + emoji(o.a) + ' <b>' + (i + 1) + '. ' + esc(o.it.headline) + '</b>\\n• Кому: ' + esc((o.a.advice || {}).to_role) + ' · ' + esc((o.a.advice || {}).mode) + '\\n• Чому: ' + esc(o.it.why) + '\\n✍️ <i>' + esc(o.it.message) + '</i>';\n});\nconst hz = (brief.horizon_7d || []).slice(0, 4).map(function (h) {\n  const f = h.facts || {};\n  return '• ' + fmtD(f.date).slice(0, 5) + ' · ' + esc(h.project_id) + ' · ' + (h.kind === 'act_due' ? 'акт ' : 'документація ') + esc(f.stage) + (h.kind === 'act_due' && f.amount ? ' · ' + fmtN(f.amount) + ' грн' : '');\n});\nlet top = parsed && typeof parsed.top_line === 'string' && parsed.top_line.length <= 130 && numbersOk(parsed.top_line, { set: (function () { const s = { '10': 1 }; out.forEach(function (o) { Object.keys(allowedFor(itemsFmt[o.a.rank - 1] || { facts: {} }).set).forEach(function (k) { s[k] = 1; }); }); return s; })(), nums: {} }) ? parsed.top_line : '';\nif (!top) top = out.length ? out[0].it.headline : 'Критичних дій на сьогодні немає';\nconst tail = (hz.length ? '\\n\\n<b>Горить за 7 днів</b>\\n' + hz.join('\\n') : '') + '\\n\\n🎯 <b>Головне:</b> ' + esc(top);\nlet text = out.length ? head + blocks.join('') + tail : head + '\\n\\n• Критичних дій на сьогодні немає' + tail;\nwhile (text.length > 4000 && blocks.length > 1) { blocks.pop(); text = head + blocks.join('') + tail; }\nreturn { json: { chat_id: src.chat_id, company_id: src.company_id, force: src.force, text: text, llm_ok: !!parsed, fallback_items: fb, actions_count: actions.length } };\n" },
    output: [{ chat_id: '304884647', company_id: '00000000-0000-4000-8000-000000000001', force: true, text: 'Станом на 01.11.2026', llm_ok: true, fallback_items: 0, actions_count: 5 }]
  }
});

const addPortfolio = node({
  type: 'n8n-nodes-base.code',
  version: 2,
  config: {
    name: 'Add Portfolio Block',
    parameters: { mode: 'runOnceForEachItem', language: 'javaScript', jsCode: "const brief = $('Load Brief').item.json.brief || {};\nconst p = brief.portfolio || {};\nconst rows = [['⛔ Проєкти стоять', p.blocked], ['💰 Субпідрядник чекає аванс', p.sub_blocked], ['🔴 Прострочені акти', p.acts_overdue], ['🟡 Акти в найближчі 7 днів', p.acts_soon], ['🔴 ETC_прогноз більший за ETC_факт', p.etc_red], ['🔴 Рентабельність прогнозу нижче плану', p.rent_below], ['🔴 Немає прогнозу ПМа', p.no_forecast], ['🟡 Немає звіту за поточний тиждень', p.no_report]];\nconst lines = ['• Проєктів у роботі: ' + (brief.projects_total == null ? '—' : brief.projects_total)];\nrows.forEach(function (r) { if (Number(r[1]) > 0) lines.push('• ' + r[0] + ': ' + r[1]); });\nconst block = '📊 <b>Стан портфеля</b>\\n' + lines.join('\\n');\nconst marker = '<b>План дій на день</b>';\nlet text = String($json.text || '');\nconst next = text.indexOf(marker) >= 0 ? text.replace(marker, block + '\\n\\n' + marker) : text;\nif (next.length <= 4000) text = next;\nreturn { json: Object.assign({}, $json, { text: text, portfolio_block: next.length <= 4000 }) };\n" },
    output: [{ chat_id: '304884647', company_id: '00000000-0000-4000-8000-000000000001', force: true, text: 'Станом на 01.11.2026', portfolio_block: true }]
  }
});

const sendBrief = node({
  type: 'n8n-nodes-base.telegram',
  version: 1.2,
  config: {
    name: 'Send Brief',
    parameters: {
      resource: 'message',
      operation: 'sendMessage',
      chatId: expr('{{ $json.chat_id }}'),
      text: expr('{{ $json.text }}'),
      additionalFields: { appendAttribution: false, parse_mode: 'HTML' }
    },
    credentials: { telegramApi: newCredential('Telegram account 4') },
    output: [{ ok: true, result: { message_id: 1 } }]
  }
});

const markSent = node({
  type: 'n8n-nodes-base.postgres',
  version: 2.8,
  config: {
    name: 'Mark Sent',
    parameters: {
      resource: 'database',
      operation: 'executeQuery',
      query: "UPDATE public.owner_prefs SET last_sent_on = (now() AT TIME ZONE tz)::date, updated_at = now() WHERE telegram_user_id = $1::bigint AND company_id = $2::uuid AND $3::boolean = false RETURNING telegram_user_id",
      options: { queryReplacement: expr('{{ [ String($("Validate And Render").item.json.chat_id), String($("Validate And Render").item.json.company_id), $("Validate And Render").item.json.force === true ] }}') }
    },
    credentials: { postgres: newCredential('Postgres account') },
    output: [{ telegram_user_id: '304884647' }]
  }
});

export default workflow('archi-morning-brief', 'ARCHI: Morning Brief')
  .add(everyFiveMinutes)
  .to(findDueOwners)
  .to(loadBrief)
  .to(buildRequest)
  .to(callAnthropic)
  .to(renderBrief)
  .to(addPortfolio)
  .to(sendBrief)
  .to(markSent)
  .add(manualTest)
  .to(testRecipient)
  .to(loadBrief);
