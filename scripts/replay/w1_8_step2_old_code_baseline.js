// W1.8 крок 2: еталон — старий код n8n (AN: Split Stage Rows + Build MiniApp Data) на живих рядках. Запуск: node scripts/replay/w1_8_step2_old_code_baseline.js <live_ov.json> <out.json>
// live_ov.json = {ov: рядки запиту «Fetch Project Metrics (MiniApp)», kp}. Порівняти з archi_portfolio_cards (знімок sql/tests/w1_8_step2_portfolio_cards_snapshot_2026-11-19.json): розбіжності дозволені лише 2А.
const fs=require('fs'),path=require('path');
const WF=JSON.parse(fs.readFileSync('/home/user/fdo-perfect/workflows/DEMO_Archi_Agent_Core.json','utf8'));
const CODE=n=>WF.nodes.find(x=>x.name===n).parameters.jsCode;
const D=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const W=x=>x.map(j=>({json:j}));
const stub0=()=>({all:()=>[],first:()=>({json:D.kp})});
const split=new Function('$input','$',CODE('AN: Split Stage Rows'))({all:()=>W(D.ov)},stub0);
const out=new Function('$input','$',CODE('Build MiniApp Data'))({all:()=>split},stub0);
const d=out[0].json;
const res={counts:d.counts,attention:d.attention.map(a=>[a.id,a.status,a.blocked,a.reds,a.yellows]),
 groups:Object.fromEntries(Object.entries(d.views).map(([k,v])=>[k,Object.fromEntries(Object.entries(v.groupProjects).map(([g,a])=>[g,a.map(x=>x.id).sort()]))])),
 hero:Object.fromEntries(Object.entries(d.views).map(([k,v])=>[k,{L:v.heroL.cls||null,R:v.heroR.cls||null,Lv:v.heroL.value,Rv:v.heroR.value}])),
 projects:d.projects.map(p=>[p.id,p.status,p.reds,p.yellows,JSON.stringify(p.cls)])};
fs.writeFileSync(process.argv[3],JSON.stringify(res,null,1));
console.log(JSON.stringify({counts:res.counts,n:d.projects.length,hero:res.hero}));
