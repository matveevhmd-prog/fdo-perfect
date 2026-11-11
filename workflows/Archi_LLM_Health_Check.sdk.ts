// ARCHI: LLM Health Check — n8n workflow Sna7JWxq3BpRDJIs (11.11.2026).
// Щодня 07:30 (Europe/Kyiv): мінімальний запит до Anthropic і OpenAI; збій (рахунок, ключ) — сповіщення оператору в Telegram.
// Credentials: Postgres account 9RgEysuE2hzWIIQq, Anthropic account U5Ts0Bmqulc3foVf, OpenAI account 9qDhoEmmVrxSI3JS, Telegram account 4 jDGC5deJSU6Bjk2J.
import { workflow, node, trigger, ifElse, newCredential, expr } from '@n8n/workflow-sdk';

const EVAL_JS = "const esc = function (s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); };\nconst op = $('Get Operator').first().json.chat_id;\nconst chk = function (name, r) { const e = r && r.error; if (e) { return { name: name, ok: false, reason: String(e.description || e.message || 'помилка').slice(0, 160) }; } return { name: name, ok: true, reason: '' }; };\nconst a = chk('Anthropic (чат власника, брифінг)', $('Check Anthropic').first().json);\nconst o = chk('OpenAI (звіт ПМа, імпорт, зустрічі, голос, фото)', $('Check OpenAI').first().json);\nconst bad = [a, o].filter(function (x) { return !x.ok; });\nconst lines = bad.map(function (x) { return '• ' + esc(x.name) + ': ' + esc(x.reason); });\nconst text = bad.length ? '⚠️ <b>Перевірка моделей: є збій</b>\\n\\n' + lines.join('\\n') + '\\n\\n🎯 <b>Що зробити:</b> перевірте рахунок і ключ провайдера. До виправлення брифінг іде за шаблонами, чат і звіт ПМа не відповідають.' : '';\nreturn { json: { chat_id: op, failed: bad.length, text: text, anthropic_ok: a.ok, openai_ok: o.ok } };";

const daily = trigger({ type: 'n8n-nodes-base.scheduleTrigger', version: 1.4, config: { name: 'Daily 07:30', parameters: { rule: { interval: [{ field: 'days', daysInterval: 1, triggerAtHour: 7, triggerAtMinute: 30 }] } }, output: [{}] } });
const manual = trigger({ type: 'n8n-nodes-base.manualTrigger', version: 1, config: { name: 'Manual Test', output: [{}] } });

const getOperator = node({ type: 'n8n-nodes-base.postgres', version: 2.8, config: { name: 'Get Operator', parameters: { resource: 'database', operation: 'executeQuery', query: "SELECT ('' || telegram_user_id) AS chat_id FROM public.user_access WHERE role = 'operator' ORDER BY id LIMIT 1" }, credentials: { postgres: newCredential('Postgres account') }, output: [{ chat_id: '1' }] } });

const checkAnthropic = node({ type: 'n8n-nodes-base.httpRequest', version: 4.5, config: { name: 'Check Anthropic', onError: 'continueRegularOutput', parameters: { method: 'POST', url: 'https://api.anthropic.com/v1/messages', authentication: 'predefinedCredentialType', nodeCredentialType: 'anthropicApi', sendHeaders: true, headerParameters: { parameters: [{ name: 'anthropic-version', value: '2023-06-01' }] }, sendBody: true, contentType: 'raw', rawContentType: 'application/json', body: '{"model":"claude-sonnet-4-6","max_tokens":1,"messages":[{"role":"user","content":"ok"}]}', options: { timeout: 30000 } }, credentials: { anthropicApi: newCredential('Anthropic account') }, output: [{}] } });

const checkOpenAI = node({ type: 'n8n-nodes-base.httpRequest', version: 4.5, config: { name: 'Check OpenAI', onError: 'continueRegularOutput', parameters: { method: 'POST', url: 'https://api.openai.com/v1/chat/completions', authentication: 'predefinedCredentialType', nodeCredentialType: 'openAiApi', sendBody: true, contentType: 'raw', rawContentType: 'application/json', body: '{"model":"gpt-4o","max_tokens":1,"messages":[{"role":"user","content":"ok"}]}', options: { timeout: 30000 } }, credentials: { openAiApi: newCredential('OpenAI account') }, output: [{}] } });

const evaluate = node({ type: 'n8n-nodes-base.code', version: 2, config: { name: 'Evaluate', parameters: { mode: 'runOnceForEachItem', language: 'javaScript', jsCode: EVAL_JS }, output: [{ chat_id: '1', failed: 1, text: 'x' }] } });

const anyFailure = ifElse({ version: 2.2, config: { name: 'Any Failure?', parameters: { conditions: { options: { caseSensitive: true, leftValue: '', typeValidation: 'loose' }, conditions: [{ leftValue: expr('{{ $json.failed }}'), operator: { type: 'number', operation: 'gt' }, rightValue: 0 }], combinator: 'and' } } } });

const sendAlert = node({ type: 'n8n-nodes-base.telegram', version: 1.2, config: { name: 'Send Alert', parameters: { resource: 'message', operation: 'sendMessage', chatId: expr('{{ $json.chat_id }}'), text: expr('{{ $json.text }}'), additionalFields: { appendAttribution: false, parse_mode: 'HTML' } }, credentials: { telegramApi: newCredential('Telegram account 4') }, output: [{}] } });

export default workflow('Sna7JWxq3BpRDJIs', 'ARCHI: LLM Health Check')
  .add(daily).to(getOperator)
  .add(manual).to(getOperator)
  .add(getOperator).to(checkAnthropic).to(checkOpenAI).to(evaluate).to(anyFailure.onTrue(sendAlert));
