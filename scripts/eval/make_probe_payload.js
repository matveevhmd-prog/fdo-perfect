// Готує тіло запиту для probe-workflow (W15.1б): node scripts/eval/make_probe_payload.js [variant] [питання] > payload.json
const fs = require('fs'), path = require('path');
const root = path.join(__dirname, '..', 'chat_card');
const variant = process.argv[2] || 'p2f', q = process.argv[3] || 'Що в нас відбувається?';
const data = JSON.parse(fs.readFileSync(process.env.FIXTURE || path.join(__dirname, 'fixtures', 'chat_data_2026-11-19.json'), 'utf8'));
const code = fs.readFileSync(path.join(root, 'Build_Request_Body.' + variant + '.js'), 'utf8');
const brb = new Function('$input', '$', code)({ first: () => ({ json: data }) }, () => ({ item: { json: { message: { text: q, chat: { id: 1 } } } }, first: () => ({ json: {} }) }))[0].json;
const req = JSON.parse(brb.body);
const out = { model: process.env.MODEL || req.model, max_tokens: req.max_tokens, system: req.system, user: req.messages[0].content };
if (typeof req.temperature === 'number' && !process.env.NO_TEMP) out.temperature = req.temperature;
process.stdout.write(JSON.stringify(out));
