// W1.8 крок 3: еквівалентність старого коду `Build MiniApp Data` (n8n 730b080f) і нового (out/Build_MiniApp_Data.step3.js) на тих самих живих рядках.
// Запуск: node scripts/w1_8_step3/equivalence.js <live_ov.json> — рядки містять sig і cards (запит out/q_miniapp.sql). Дозволені розбіжності — лише 2А.
const fs=require('fs'),path=require('path');
const WF=JSON.parse(fs.readFileSync(path.join(__dirname,'..','..','workflows','DEMO_Archi_Agent_Core.json'),'utf8'));
const OLD=WF.nodes.find(x=>x.name==='Build MiniApp Data').parameters.jsCode, SPL=WF.nodes.find(x=>x.name==='AN: Split Stage Rows').parameters.jsCode;
const NEW=fs.readFileSync(path.join(__dirname,'out','Build_MiniApp_Data.step3.js'),'utf8');
const D=JSON.parse(fs.readFileSync(process.argv[2],'utf8')); const W=x=>x.map(j=>({json:j}));
const stub=()=>({all:()=>[],first:()=>({json:D.kp})});
const split=new Function('$input','$',SPL)({all:()=>W(D.ov)},stub);
const run=c=>new Function('$input','$',c)({all:()=>split},stub)[0].json;
const o=run(OLD), n=run(NEW);
let diffs=0; const say=(...a)=>{diffs++;console.log('РОЗБІЖНІСТЬ',...a)};
const canon=v=>Array.isArray(v)?v.map(canon):(v&&typeof v==='object'?Object.keys(v).sort().reduce((r,k)=>(r[k]=canon(v[k]),r),{}):v);
const eq=(a,b)=>JSON.stringify(canon(a))===JSON.stringify(canon(b));
// проєкти
const oP={},nP={}; o.projects.forEach(p=>oP[p.id]=p); n.projects.forEach(p=>nP[p.id]=p);
if(!eq(Object.keys(oP),Object.keys(nP))) say('склад проєктів',Object.keys(oP),Object.keys(nP));
Object.keys(oP).forEach(id=>{ const a=oP[id],b=nP[id]; if(!b) return;
  ['status','reds','yellows'].forEach(k=>{ if(a[k]!==b[k]) say(id,k,a[k],'→',b[k]); });
  if(!eq(a.cls,b.cls)) say(id,'cls',JSON.stringify(a.cls),'→',JSON.stringify(b.cls));
  if(!eq(a.signals,b.signals)) say(id,'signals\n   було:',JSON.stringify(a.signals.map(s=>s.c+':'+s.t)),'\n   стало:',JSON.stringify(b.signals.map(s=>s.c+':'+s.t)));
  const sa=(a.wr&&a.wr.stages||[]).map(s=>s.stage+s.cls), sb=(b.wr&&b.wr.stages||[]).map(s=>s.stage+s.cls); if(!eq(sa,sb)) say(id,'stage cls',sa,sb);
  if((a.wr&&a.wr.docCls)!==(b.wr&&b.wr.docCls)) say(id,'docCls',a.wr&&a.wr.docCls,b.wr&&b.wr.docCls);
  if((a.blocker&&a.blocker.cls)!==(b.blocker&&b.blocker.cls)) say(id,'blocker.cls',a.blocker&&a.blocker.cls,b.blocker&&b.blocker.cls);
  const strip=p=>{const c=JSON.parse(JSON.stringify(p)); ['status','reds','yellows','cls','signals'].forEach(k=>delete c[k]); if(c.wr){delete c.wr.docCls; (c.wr.stages||[]).forEach(s=>delete s.cls);} if(c.blocker) delete c.blocker.cls; return c;};
  if(!eq(strip(a),strip(b))) { const x=strip(a),y=strip(b); Object.keys(x).forEach(k=>{ if(!eq(x[k],y[k])) say(id,'поле',k); }); }
});
// групи, hero, лічильники, увага
Object.keys(o.views).forEach(k=>{ ['critical','attention','normal'].forEach(g=>{ const A=JSON.stringify(o.views[k].groupProjects[g]),B=JSON.stringify(n.views[k].groupProjects[g]); if(A!==B) say('група',k,g,o.views[k].groupProjects[g].map(x=>x.id),'→',n.views[k].groupProjects[g].map(x=>x.id)); });
  ['heroL','heroR'].forEach(h=>{ if(!eq(o.views[k][h],n.views[k][h])) say('hero',k,h,JSON.stringify(o.views[k][h]),'→',JSON.stringify(n.views[k][h])); });
  if(!eq(o.views[k].groups,n.views[k].groups)) say('groups(лічильники)',k); });
if(!eq(o.counts,n.counts)) say('counts',JSON.stringify(o.counts),'→',JSON.stringify(n.counts));
if(!eq(o.attention,n.attention)) say('attention\n   було:',JSON.stringify(o.attention.map(a=>[a.id,a.status,a.blocked,a.reds,a.yellows])),'\n   стало:',JSON.stringify(n.attention.map(a=>[a.id,a.status,a.blocked,a.reds,a.yellows])));
const rest=d=>{const c=Object.assign({},d); ['projects','views','counts','attention'].forEach(k=>delete c[k]); return c;};
if(!eq(rest(o),rest(n))) say('решта даних (pfc/rules/...)');
console.log(diffs?('Розбіжностей: '+diffs):'Розбіжностей немає'); console.log('нові counts',JSON.stringify(n.counts));
// «потребують уваги»: для проєктів, чий статус не змінився через 2А, поле top (текст першого сигналу) має збігатись
const oA={}; o.attention.forEach(a=>oA[a.id]=a); let topDiff=0;
n.attention.forEach(a=>{ const b=oA[a.id]; if(b && b.status===a.status && b.top!==a.top){ topDiff++; console.log('top відрізняється',a.id,'\n  було:',b.top,'\n  стало:',a.top); } });
console.log('top-розбіжностей (без зміни статусу):',topDiff);
