const {runBRB,runSan,data}=require('./harness.js');
const rows=Object.fromEntries(require('./chat_rows.json').map(r=>[r.project_id,r]));
const col=l=>{const m=l&&l.match(/(🔴|🟡|🟢)\s*$/);return m?m[1]:'—'};
const IC={red:'🔴',yellow:'🟡',green:'🟢'};
let bad=0,maxLen=0;
console.log('id | etc card/SQL etc_gap | profit card | rent card | cpi card/SQL eff | unpaid card/cls | hours plan/fact raw vs card | profit plan raw vs card');
for(const p of data.projects){
  const b=runBRB('Що по '+p.id+'?'); const c=b.cardData.cards[p.id]; const r=rows[p.id];
  const e=col(c.hours[4]),pr=col(c.money[1]),rn=col(c.money[3]);
  const cp=c.money.find(l=>l.startsWith('• Ефективність'));const un=c.money.find(l=>l.startsWith('• Не оплачено'));
  const etcSQL=r.etc_gap_signal?IC[r.etc_gap_signal]:'(нет)';const effSQL=r.eff_signal?IC[r.eff_signal]:'(нет)';
  const okE=(p.noForecast?true:e===etcSQL), okC=(cp?col(cp)===IC[p.cls.cpi]:true);
  const planOK=c.hours[0].includes((Math.round(r.planned_hours*10)/10).toLocaleString('uk-UA',{maximumFractionDigits:1}));
  const factOK=c.hours[1].includes((Math.round(r.actual_hours*10)/10).toLocaleString('uk-UA',{maximumFractionDigits:1}));
  const profOK=c.money[0].includes(Math.round(Math.abs(r.profit_plan)).toLocaleString('uk-UA'));
  if(!(okE&&okC&&planOK&&factOK&&profOK))bad++;
  const llm={cards:{[p.id]:{insight:'x',impact:'y',action:'уточнити в ПМа'}}};
  const t=runSan(b,JSON.stringify(llm)); maxLen=Math.max(maxLen,t.length);
  console.log([p.id,e+'/'+etcSQL+(okE?'':' ✗'),pr+'(cls '+IC[p.cls.profit]+')',rn+'(cls '+IC[p.cls.rent]+')',(cp?col(cp):'—')+'/'+effSQL+(okC?'':' ✗'),(un?col(un):'—')+'/'+(p.cls.received?IC[p.cls.received]:'—'),planOK&&factOK?'ok':'✗',profOK?'ok':'✗'].join(' | '));
}
// 3 найгірші картки — максимальна довжина
const b=runBRB('Що в нас відбувається?'); const ids=b.cardData.order; const j={cards:{}}; ids.forEach(i=>j.cards[i]={insight:'я'.repeat(390),impact:'я'.repeat(390),action:'я'.repeat(390)});
console.log('mismatch rows:',bad,'| max 1 картка:',maxLen,'| 3 картки з макс. текстом LLM:',runSan(b,JSON.stringify(j)).length);
