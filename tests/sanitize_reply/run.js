const { validateReply } = require('./validate.js');
let fail = 0;
function eq(name, a, b) { if (a !== b) { fail++; console.log('FAIL', name, '\n--- got ---\n' + a + '\n--- want ---\n' + b); } else console.log('ok  ', name); }
const body = 'Станом на 13.11.2026\n\nТак, 6 проєктів мають порушені терміни.\n\n• DEMO-05: П пізніше плану на 90 дн.\n\n🎯 Що зробити: уточнити дати.';
const meta = 'Використано теги Markdown замість HTML — виправляю нижче у правильному форматі.';
// 1. тричі та сама відповідь із мета-текстом (Q8 13.11.2026)
const q8 = body.replace('• DEMO-05', '**• DEMO-05**') + '\n\n' + meta + '\n\n━━━━━━━━━━━━\n\n' + body + '\n\n━━━━━━━━━━━━\n\n' + body;
eq('q8 тричі + мета', validateReply(q8), body);
// 2. нормальна відповідь без змін
eq('одна версія', validateReply(body), body);
// 3. мета-рядок без дубля
eq('лише мета', validateReply(body + '\n' + meta), body);
// 4. остання версія обрізана — береться найповніша
eq('остання обрізана', validateReply(body + '\n\n' + 'Станом на 13.11.2026\n\nТак'), body);
// 5. відповідь без заголовка «Станом на» не чіпається
eq('без заголовка', validateReply('Даних немає.\n\n🎯 Що зробити: надати залишки.'), 'Даних немає.\n\n🎯 Що зробити: надати залишки.');
process.exit(fail ? 1 : 0);
