const fs=require('fs');const S=process.argv[2];
const data=JSON.parse(fs.readFileSync(S+'/data_out.json','utf8'));
function runBRB(q){
  const f=new Function('$input','$',fs.readFileSync(S+'/new/Build_Request_Body.js','utf8'));
  return f({first:()=>({json:data})},(n)=>({item:{json:{message:{text:q,chat:{id:1}}}},first:()=>({json:{}})}))[0].json;
}
function runSan(brb,llm){
  const f=new Function('$input','$',fs.readFileSync(S+'/new/Sanitize_Reply.js','utf8'));
  return f({first:()=>({json:{content:[{text:llm}]}})},(n)=>({first:()=>({json:brb})}))[0].json.text;
}
module.exports={runBRB,runSan,data};
if(require.main===module){
 const q=process.argv[3]||'Що в нас відбувається?';
 const b=runBRB(q); console.log('cardData order:',b.cardData&&b.cardData.order);
 const ids=b.cardData.order; const good={cards:{}}; ids.forEach(i=>good.cards[i]={insight:'Є відхилення від плану за сигналами.',impact:'Ризик перевитрати.',action:'уточнити в ПМа'});
 const t=runSan(b,'```json\n'+JSON.stringify(good)+'\n```'); console.log(t.length); console.log(t);
 console.log('=== fallback (bad json) ==='); const t2=runSan(b,'не json'); console.log(t2.length); console.log(t2.split('\n').filter(l=>/Insight|Action/.test(l)).join('\n'));
 console.log('=== LLM invented number ==='); const bad={cards:{}}; ids.forEach(i=>bad.cards[i]={insight:'Втрати 777777 грн',impact:'x',action:'уточнити в ПМа'});
 console.log(runSan(b,JSON.stringify(bad)).split('\n').filter(l=>/Insight/.test(l)).join('\n'));
}
