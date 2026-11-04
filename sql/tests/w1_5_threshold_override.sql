-- ARCHI W1.5: тест перевизначення порогів. Запускати в Supabase SQL Editor; завжди скасовується — результат у T_RESULT.
DO $$
declare A uuid := '00000000-0000-4000-8000-0000000000a1'; D uuid := '00000000-0000-4000-8000-000000000001'; res text := '';
begin
  insert into companies(company_id,code,name,kind) values (A,'T_A','тест A','client');
  -- без перевизначення: відхилення ETC 12,5 на BAC 100 за порогом etc_red = 0 → червоне
  res := res || 'до: DEMO=' || archi_vac_signal(D,12.5,100) || ', A=' || archi_vac_signal(A,12.5,100) || '; ';
  insert into company_thresholds(company_id,key,value) values (A,'etc_red',0.20),(A,'etc_yellow',0.10);
  res := res || 'після (A: etc_red=0.20, etc_yellow=0.10): DEMO=' || archi_vac_signal(D,12.5,100) || ', A=' || archi_vac_signal(A,12.5,100) || '; ';
  res := res || 'archi_rules: A.etc_red=' || (archi_rules(A)->>'etc_red') || ', DEMO.etc_red=' || (archi_rules(D)->>'etc_red') || '; ';
  raise exception 'T_RESULT: %', res;
end $$;
