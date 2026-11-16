const {runBRB,runSan}=require('/home/user/fdo-perfect/scripts/chat_card/harness.js');
const b=runBRB('Що в нас відбувається?'); const j=JSON.parse(b.body);
console.log('system chars',j.system.length,'max_tokens',j.max_tokens);
require('fs').writeFileSync('sys_p2e.txt',j.system);
const good={portfolio:{headline:"Збитки зосереджені: DEMO-07 дає 50% збиткових відхилень, а портфель тримає 24-52 (+203 495 грн).",priorities:["Вирішити оплату додаткових змін по DEMO-07: 217 360 грн збитку і 174 812 грн не оплачено.","Розблокувати DEMO-05 і 24-11: заблоковано контрактів на 1 616 000 грн."],pipeline:"Воронка порожня: КП за рік 0 з плану 70, тому нових договорів на підтримку завантаження немає."},
 cards:{"DEMO-05":{insight:"Проєкт стоїть через брак людей і грошей на аванс.",impact:"Відхилення прибутку −78 123 грн (18% збитків портфеля), терміни П і Р пізніше плану на 90 і 84 дні.",action:"Перевести архітектора з іншого проєкту і профінансувати аванс."},"24-11":{insight:"Проєкт чекає замовника.",impact:"Заблоковано контракт на 581 000 грн; стадія Р пізніше плану на 28 днів.",action:"Власнику вийти на керівника замовника."},"DEMO-07":{insight:"Додаткові узгодження збільшили трудомісткість стадії П.",impact:"Прогноз збитку: відхилення прибутку −217 360 грн, не оплачено 174 812 грн.",action:"Обговорити із замовником оплату додаткових змін."}}};
function run(label,o){const t=runSan(b,JSON.stringify(o));console.log('=====',label,'len',t.length);return t;}
const t=run('good',good); console.log(t);
const bad=JSON.parse(JSON.stringify(good)); bad.portfolio.headline='Втрати становлять 999 000 грн.'; bad.cards['DEMO-07'].impact='Збиток зросте до 777 777 грн.'; bad.cards['24-11'].impact='Проєкт може погіршитись.';
const t2=run('bad',bad); console.log(t2.split('\n').filter(l=>/Висновок|Impact|Спершу|Пайплайн|📈/.test(l)).join('\n'));
