// Запуск оцінки: node scripts/eval/run_eval.js <файл-відповіді-LLM.json|.txt> [stop_reason] [питання] [fixture]
// Не викликає LLM і не чіпає n8n/Supabase: перевіряє вже отриману відповідь модели.
const fs = require('fs'), path = require('path');
const checks = require('./checks.js');
const root = path.join(__dirname, '..', 'chat_card');
const respFile = process.argv[2];
if (!respFile) { console.error('usage: run_eval.js <response> [stop] [question] [fixture]'); process.exit(2); }
const raw = fs.readFileSync(respFile, 'utf8');
const stop = process.argv[3] || 'end_turn';
const q = process.argv[4] || 'Що в нас відбувається?';
const fixture = process.argv[5] || path.join(__dirname, 'fixtures', 'chat_data_2026-11-19.json');
const variant = process.env.CODE_VARIANT || 'p2e';
const data = JSON.parse(fs.readFileSync(fixture, 'utf8'));
const brbCode = fs.readFileSync(path.join(root, 'Build_Request_Body.' + variant + '.js'), 'utf8');
const sanCode = fs.readFileSync(path.join(root, 'Sanitize_Reply.' + variant + '.js'), 'utf8');
const brb = new Function('$input', '$', brbCode)({ first: () => ({ json: data }) }, () => ({ item: { json: { message: { text: q, chat: { id: 1 } } } }, first: () => ({ json: {} }) }))[0].json;
const sanItems = new Function('$input', '$', sanCode)({ first: () => ({ json: { content: [{ text: raw }], stop_reason: stop } }) }, () => ({ first: () => ({ json: brb }) }));
const san = { text: sanItems.map(i => i.json.text).join('\n') };
const chunkLens = sanItems.map(i => i.json.text.length);
const J = checks.parseStrict(raw) || {};
const res = checks.run({ raw, stop, brb, final: san.text, chunks: chunkLens });
const pass = res.filter(r => r.ok).length;
const usage = process.env.TOKENS_IN ? { in: +process.env.TOKENS_IN, out: +process.env.TOKENS_OUT } : null;
const out = { response: path.basename(respFile), stop, question: q, fixture: path.basename(fixture), pass, total: res.length, results: res, final_len: san.text.length, messages: chunkLens.length, chunk_lens: chunkLens, tokens: usage };
console.log('Відповідь: ' + out.response + ' | stop=' + stop + ' | пройдено ' + pass + ' з ' + res.length);
res.forEach(r => console.log((r.ok ? '✅' : '❌') + ' ' + r.id + ' ' + r.name + (r.detail ? ' — ' + r.detail : '')));
if (process.env.OUT) { fs.writeFileSync(process.env.OUT, JSON.stringify(out, null, 1)); console.log('звіт: ' + process.env.OUT); }
if (process.env.SHOW) console.log('\n' + san.text);
