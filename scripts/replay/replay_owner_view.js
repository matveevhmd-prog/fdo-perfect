// ARCHI replay: проганяє код вузлів із workflows/DEMO_Archi_Agent_Core.json на живих даних (вивантаження SQL) у Chromium.
// Запуск: node scripts/replay/replay_owner_view.js <live_data.json> <out_dir>
// live_data.json = {metrics, grid, ov} — результати запитів вузлів Fetch All Project Metrics, Fetch Weekly Snapshots For Grid,
// Fetch Project Metrics (MiniApp) (див. docs/RELEASE_PLAN.md §88). Telegram initData не потрібен: вебхук підміняється.
const path=require('path');
const WF=JSON.parse(require('fs').readFileSync(path.join(__dirname,'..','..','workflows','DEMO_Archi_Agent_Core.json'),'utf8'));
const CODE=n=>WF.nodes.find(x=>x.name===n).parameters.jsCode;
const OUT=process.argv[3]||'.'; process.chdir(OUT);
const fs=require('fs'); const { chromium } = require('/opt/node-tools/node_modules/playwright');
const D=JSON.parse(fs.readFileSync(path.resolve(process.argv[2]),'utf8'));
const W=x=>x.map(j=>({json:j}));
const split=new Function('$input','$',CODE('AN: Split Stage Rows'))({all:()=>W(D.ov)},()=>({all:()=>[]}));
const stub=(name)=>({ all:()=> name==='Fetch Project Metrics (MiniApp)'?W(D.ov):[], first:()=>({json:{kp_month:0,kp_year:0}}) });
const dataOut=new Function('$input','$',CODE('Build MiniApp Data'))({all:()=>split},stub);
let attached;
try { attached=new Function('$input','$',CODE('AN: Attach Block'))({all:()=>dataOut, first:()=>dataOut[0]},stub); } catch(e){ console.log('AN attach error',e.message); attached=dataOut; }
const DATA=attached[0].json;
const html=new Function(CODE('Build MiniApp HTML'))()[0].json.html.replace('<script src="https://telegram.org/js/telegram-web-app.js"></script>','<script>window.Telegram={WebApp:{initData:"x",ready(){},expand(){}}};</script>');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium',args:['--no-sandbox']});
 const p=await b.newPage({viewport:{width:420,height:1400}}); const errs=[]; p.on('pageerror',e=>errs.push(String(e)));
 await p.route('**/webhook/demo-archi-owner-view-data**',r=>r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(DATA)}));
 await p.setContent(html,{waitUntil:'domcontentloaded'}); await p.waitForSelector('.tab');
 await p.click('.tab[data-tab="etc"]');
 const groups=await p.evaluate(()=>[...document.querySelectorAll('.group-row')].map(g=>g.querySelector('.name').innerText+' = '+g.querySelector('.count').innerText));
 const members=await p.evaluate(()=>{ const v=DATA.views.etc.groupProjects; return Object.fromEntries(Object.entries(v).map(([k,a])=>[k,a.map(x=>x.id+' ('+x.value+')')])); });
 await p.screenshot({path:'ov_hours.png'});
 const cards={};
 for (const id of ['DEMO-03','DEMO-05','DEMO-07','DEMO-06']){
   await p.evaluate(id=>showCardById(id),id);
   cards[id]=await p.evaluate(()=>({ sig:[...document.querySelectorAll('.card-top .sig')].map(s=>s.innerText), stages:[...document.querySelectorAll('.block.pfc')].filter(b=>b.querySelector('.stg-head')).map(b=>{ const h=b.querySelector('.stg-head b').innerText; const r=[...b.querySelectorAll('.tr')].find(t=>t.innerText.startsWith('ETC')); return h+' | '+(r?r.innerText.replace(/\s+/g,' ')+' | клас='+(r.className.replace('tr','').trim()||'без кольору'):''); }), done:[...document.querySelectorAll('.stg-ok')].length, etcTotal:(()=>{ const t=[...document.querySelectorAll('.tr')].find(x=>x.innerText.startsWith('ETC_Total')); return t?t.innerText.replace(/\s+/g,' ')+' | клас='+(t.className.replace('tr','').trim()||'без кольору'):null; })() }));
   if(id==='DEMO-03') await p.screenshot({path:'ov_demo03.png',fullPage:true});
 }
 console.log(JSON.stringify({groups,members,cards,errs},null,1));
 await b.close();
})();
