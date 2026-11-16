const fs=require('fs');
const data=JSON.parse(fs.readFileSync('data_out.json','utf8'));
function run(file,q){const f=new Function('$input','$',fs.readFileSync(file,'utf8'));
 return f({first:()=>({json:data})},()=>({item:{json:{message:{text:q,chat:{id:1}}}},first:()=>({json:{}})}))[0].json;}
const orig=(()=>{const d=JSON.parse(fs.readFileSync('/home/user/fdo-perfect/workflows/DEMO_Archi_Agent_Core.json','utf8'));
 fs.writeFileSync('brb_orig.js',d.nodes.find(n=>n.name==='Build Request Body').parameters.jsCode);return 'brb_orig.js';})();
let diff=0;
for(let i=1;i<=10;i++){}
for(const q of ['Що в нас відбувається?','Що по DEMO-05?','Які ризики по портфелю?','Чи є небезпечні дедлайни?','Чи потрібно мені зараз щось робити?','Чи є гроші на зарплату?','Чи є небезпека касового розриву?','На який час у команди є робота?','Чи виконуємо ми річний план по прибутку?','Що пообіцяли замовнику на останній нараді?','Привіт']){
 const a=run(orig,q),b=run('brb_new.js',q);
 const same=a.body===b.body, card=!!a.cardData;
 console.log((same?'SAME ':'DIFF ')+(card?'[card] ':'[other]')+q);
}
