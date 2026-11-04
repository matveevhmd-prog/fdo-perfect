-- ARCHI W1: тест ізоляції T2/T3 + M6 (03.11.2026). Запускати в Supabase SQL Editor. Завжди відкочується: результат у тексті помилки T_RESULT.
DO $$
declare
  A uuid := '00000000-0000-4000-8000-0000000000a1';
  B uuid := '00000000-0000-4000-8000-0000000000b1';
  D uuid := '00000000-0000-4000-8000-000000000001';
  P text; res text := ''; n int; v numeric; vd numeric;
begin
  insert into companies(company_id,code,name,kind) values (A,'T_A','тест A','client'),(B,'T_B','тест B','client');
  select project_id into P from project_metrics where company_id=D order by project_id limit 1;
  res := res || 'P=' || P || '; ';
  create temp table t on commit drop as select * from project_metrics where company_id=D and project_id=P;
  update t set company_id=A; insert into project_metrics select * from t;
  update t set company_id=B, contract_amount=999; insert into project_metrics select * from t;
  select count(*) into n from project_metrics where project_id=P; res := res || 'T3 однаковий код у 3 компаніях: рядків=' || n || '; ';
  select contract_amount into vd from project_metrics where company_id=D and project_id=P;
  insert into project_metrics(company_id,project_id,contract_amount) values (B,P,777) on conflict (company_id,project_id) do update set contract_amount=excluded.contract_amount;
  select contract_amount into v from project_metrics where company_id=A and project_id=P;
  res := res || 'T3 ON CONFLICT B не зачепив A: ' || (v is not distinct from vd)::text || '; ';
  select contract_amount into v from project_metrics where company_id=B and project_id=P;
  res := res || 'B оновлено: ' || (v=777)::text || '; ';
  select count(*) into n from archi_report_today where project_id=P; res := res || 'T2 report_today по P=' || n || '; ';
  select count(*) into n from archi_report_today where company_id=A and project_id=P; res := res || 'A=' || n || '; ';
  select count(*) into n from archi_report_today where company_id=B and project_id=P; res := res || 'B=' || n || '; ';
  select count(*) into n from archi_report_today where company_id=A; res := res || 'A усього=' || n || '; ';
  select count(*) into n from archi_report_today where company_id=D; res := res || 'DEMO усього=' || n || '; ';
  begin insert into project_metrics(project_id) values ('X-NOCO'); res := res || 'M6 без company_id: ПРОЙШОВ(ПОМИЛКА); '; exception when not_null_violation then res := res || 'M6 без company_id: відхилено OK; '; end;
  begin insert into wr_weekly_snapshots(company_id,project_id,week_start) values (A,P,'2099-01-05'),(B,P,'2099-01-05'); res := res || 'snapshots однаковий тиждень A і B: OK; '; exception when others then res := res || 'snapshots помилка: ' || sqlerrm || '; '; end;
  begin insert into evm_packages(company_id,project_id,baseline_no,package_code) values (B,'NO-SUCH-PROJECT',1,'x'); res := res || 'FK evm: ПРОЙШОВ(ПОМИЛКА); '; exception when foreign_key_violation then res := res || 'FK evm: відхилено OK; '; when others then res := res || 'FK evm інша помилка: ' || sqlerrm || '; '; end;
  raise exception 'T_RESULT: %', res;
end $$;
