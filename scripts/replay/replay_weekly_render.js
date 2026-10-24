// ARCHI replay: проганяє код вузлів із workflows/DEMO_Archi_Agent_Core.json на живих даних (вивантаження SQL) у Chromium.
// Запуск: node scripts/replay/replay_weekly_render.js <live_data.json> <out_dir>
// live_data.json = {metrics, grid, ov} — результати запитів вузлів Fetch All Project Metrics, Fetch Weekly Snapshots For Grid,
// Fetch Project Metrics (MiniApp) (див. docs/RELEASE_PLAN.md §88). Telegram initData не потрібен: вебхук підміняється.
const path=require('path');
const WF=JSON.parse(require('fs').readFileSync(path.join(__dirname,'..','..','workflows','DEMO_Archi_Agent_Core.json'),'utf8'));
const CODE=n=>WF.nodes.find(x=>x.name===n).parameters.jsCode;
const OUT=process.argv[3]||'.'; process.chdir(OUT);
const fs=require('fs'); const { chromium } = require('/opt/node-tools/node_modules/playwright');
const D=JSON.parse(fs.readFileSync(path.resolve(process.argv[2]),'utf8'));
const wrData=new Function('$input','$',CODE('Build Weekly Render Data'))({all:()=>D.grid.map(j=>({json:j}))},(n)=>({all:()=>D.metrics.map(j=>({json:j}))}))[0].json;
fs.writeFileSync('wr_out.json',JSON.stringify(wrData));
const html=new Function(CODE('Build Weekly Render HTML'))()[0].json.html.replace('<script src="https://telegram.org/js/telegram-web-app.js"></script>','<script>window.Telegram={WebApp:{initData:"x",ready(){},expand(){}}};</script>');
(async()=>{
 const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium',args:['--no-sandbox']});
 const p=await b.newPage({viewport:{width:1400,height:1000}}); const errs=[]; p.on('pageerror',e=>errs.push(String(e)));
 await p.route('**/webhook/demo-archi-weekly-render-data**',r=>r.fulfill({status:200,contentType:'application/json',body:JSON.stringify(wrData)}));
 await p.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
 await p.setContent(html,{waitUntil:'domcontentloaded'}); await p.waitForSelector('td.proj-col');
 const res=await p.evaluate(()=>{ const out={}; document.querySelectorAll('#tbl tr').forEach((tr,i)=>{ if(!i) return; const id=tr.querySelector('td.proj-col').childNodes[0].textContent.trim(); const td=[...tr.querySelectorAll('td')].pop(); const rows=[...td.querySelectorAll('.m-row,.etc-sub')].map(el=>{ const lab=el.children[0].innerText.trim(); const val=el.children[1].innerText.replace(/\s+/g,' ').trim(); const colEl=el.querySelector('.sg-red,.sg-yellow,.sg-green'); return [lab,val,colEl?colEl.className.replace(/.*sg-/,''):(el.classList.contains('sg-red')?'red':'')]; }); out[id]={rows, text: td.innerText}; }); return {out, head:document.getElementById('sub').innerText}; });
 fs.writeFileSync('wr_dom.json',JSON.stringify(res));
 await p.screenshot({path:'wr_desk.png'});
 console.log('header:',res.head,'| projects:',Object.keys(res.out).length,'| errors:',errs);
 await b.close();
})();
