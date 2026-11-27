-- Тести W2 M6. Запускати в одній транзакції ПІСЛЯ M6; усе скасовується RAISE EXCEPTION (результат у тексті винятку).
-- Payload збирається з live-даних (затверджена версія + project_metrics + payment_schedule): це «файл», що збігається з планом.
CREATE FUNCTION pg_temp.mkpayload(c uuid, proj text) RETURNS jsonb LANGUAGE sql AS $m$
  SELECT CASE WHEN pm.contract_type = 'visit' THEN
    jsonb_build_object('kind','visit','spreadsheet_id','TESTFILE','sheet',proj,'status','Чернетка',
      'totals', jsonb_build_object('hours',pm.planned_hours,'cost_internal',pm.cost_plan_team,'cost_sub',0,'contract',pm.contract_amount),
      'visit', jsonb_build_object('visits',pm.visits_plan,'price',pm.visit_price,'hours',pm.visit_hours,'rate',pm.real_rate_team_hour,
                                  'cost',pm.cost_plan_team,'contract',pm.contract_amount))
  ELSE
    jsonb_build_object('kind','stages','spreadsheet_id','TESTFILE','sheet',proj,'status','Чернетка','contract',pm.contract_amount,'rate',pm.real_rate_team_hour,
      'totals', jsonb_build_object('hours',pm.planned_hours,'cost_internal',pm.cost_plan_team,'cost_sub',pm.cost_plan_subcontract,'contract',pm.contract_amount,'hours_by_stage',pm.etc_plan_by_stage),
      'rows', (SELECT jsonb_agg(jsonb_build_object('stage',r.stage,'section',r.section,'executor',coalesce(r.posada,r.counterparty),'hours',r.hours,
                 'cost',CASE WHEN r.kind='internal' THEN r.cost_uah END,'sub',CASE WHEN r.kind='subcontract' THEN r.cost_uah END,'src_row',r.sort_order) ORDER BY r.sort_order)
                 FROM koshtorys_rows r JOIN koshtorys_versions v ON v.id = r.version_id AND v.status = 'approved' WHERE v.company_id = c AND v.project_id = proj),
      'schedule', (SELECT coalesce(jsonb_agg(jsonb_build_object('стадія',"стадія",'подія',"подія",'дата_план',"дата_план"::text,'сума_план',"сума_план",
                 'ймовірність_план',"ймовірність_план",'статус_план',"статус_план")),'[]'::jsonb) FROM payment_schedule WHERE company_id = c AND project_id = proj))
  END FROM project_metrics pm WHERE pm.company_id = c AND pm.project_id = proj
$m$;

DO $t$
DECLARE c uuid := '00000000-0000-4000-8000-000000000001'; res text := ''; proj text; pl jsonb; pl2 jsonb; r jsonb; r2 jsonb; before jsonb; after jsonb; diffs text;
        n1 int; n2 int; ok boolean; h0 numeric; c0 numeric; dc numeric; ph0 numeric; ph1 numeric; nd int; badchk text;
BEGIN
  -- T1: «файл» = чинний план: перегляд без відмінностей, затвердження не змінює project_metrics
  FOREACH proj IN ARRAY ARRAY['DEMO-01','DEMO-05','DEMO-08','DEMO-01-АН','DEMO-04-АН'] LOOP
    pl := pg_temp.mkpayload(c, proj);
    SELECT count(*) INTO n1 FROM payment_schedule WHERE company_id = c AND project_id = proj;
    SELECT to_jsonb(p) - 'updated_at' INTO before FROM project_metrics p WHERE company_id = c AND project_id = proj;
    r := koshtorys_ingest_draft(c, proj, pl, 111);
    SELECT string_agg(x ->> 'name', ',') INTO badchk FROM jsonb_array_elements(r -> 'checks') x WHERE NOT (x ->> 'ok')::boolean;
    res := res || proj || ' T1 ingest ok=' || (r ->> 'ok') || ' same=' || (r ->> 'same_as_current') || ' рядків різниці=' || jsonb_array_length(r -> 'diff' -> 'rows')
           || ' Δbac=' || (r -> 'diff' -> 'delta' ->> 'bac') || ' Δhours=' || (r -> 'diff' -> 'delta' ->> 'hours') || ' невдалі перевірки=[' || coalesce(badchk, '') || '] попереджень=' || jsonb_array_length(r -> 'warnings') || '; ';
    r2 := koshtorys_commit_draft(c, proj, 111);
    SELECT to_jsonb(p) - 'updated_at' INTO after FROM project_metrics p WHERE company_id = c AND project_id = proj;
    SELECT string_agg(b.key || ' ' || b.value::text || ' -> ' || a.value::text, ', ') INTO diffs
      FROM jsonb_each(before) b JOIN jsonb_each(after) a USING (key) WHERE a.value IS DISTINCT FROM b.value;
    SELECT count(*) INTO n2 FROM payment_schedule WHERE company_id = c AND project_id = proj;
    res := res || proj || ' T1 commit=' || (r2 ->> 'status') || ' графік ' || n1 || '→' || n2 || ' змінені колонки: [' || coalesce(diffs, 'жодної') || ']; ';
    -- T2: той самий файл ще раз: змін немає, чернетка не створюється
    r := koshtorys_ingest_draft(c, proj, pl, 111);
    res := res || proj || ' T2 same_as_current=' || (r ->> 'same_as_current') || '; ';
  END LOOP;

  -- T3: у файлі +8 год у першому рядку першої стадії; контракт той самий
  proj := 'DEMO-02';
  pl := pg_temp.mkpayload(c, proj);
  h0 := (pl -> 'rows' -> 0 ->> 'hours')::numeric; c0 := (pl -> 'rows' -> 0 ->> 'cost')::numeric; dc := round(8 * c0 / h0, 2);
  pl2 := jsonb_set(pl, '{rows,0,hours}', to_jsonb(h0 + 8));
  pl2 := jsonb_set(pl2, '{rows,0,cost}', to_jsonb(c0 + dc));
  pl2 := jsonb_set(pl2, '{totals,hours}', to_jsonb((pl -> 'totals' ->> 'hours')::numeric + 8));
  pl2 := jsonb_set(pl2, '{totals,cost_internal}', to_jsonb((pl -> 'totals' ->> 'cost_internal')::numeric + dc));
  pl2 := jsonb_set(pl2, ARRAY['totals','hours_by_stage', pl2 -> 'rows' -> 0 ->> 'stage'], to_jsonb((pl -> 'totals' -> 'hours_by_stage' ->> (pl2 -> 'rows' -> 0 ->> 'stage'))::numeric + 8));
  SELECT planned_hours INTO ph0 FROM project_metrics WHERE company_id = c AND project_id = proj;
  r := koshtorys_ingest_draft(c, proj, pl2, 111);
  res := res || 'T3 ingest ok=' || (r ->> 'ok') || ' рядків різниці=' || jsonb_array_length(r -> 'diff' -> 'rows') || ' Δhours=' || (r -> 'diff' -> 'delta' ->> 'hours') || ' version_no=' || (r ->> 'version_no') || '; ';
  r2 := koshtorys_commit_draft(c, proj, 111);
  SELECT planned_hours INTO ph1 FROM project_metrics WHERE company_id = c AND project_id = proj;
  res := res || 'T3 commit=' || (r2 ->> 'status') || ' planned_hours ' || ph0 || '→' || ph1 || ' (очікувано +8); ';

  -- T4: підсумок файлу не збігається з рядками: перегляд ok=false, затвердження відхилено, графік і план не змінились
  proj := 'DEMO-03';
  pl := pg_temp.mkpayload(c, proj);
  pl2 := jsonb_set(pl, '{totals,hours}', to_jsonb((pl -> 'totals' ->> 'hours')::numeric + 1));
  SELECT count(*) INTO n1 FROM payment_schedule WHERE company_id = c AND project_id = proj;
  SELECT to_jsonb(p) - 'updated_at' INTO before FROM project_metrics p WHERE company_id = c AND project_id = proj;
  r := koshtorys_ingest_draft(c, proj, pl2, 111);
  BEGIN PERFORM koshtorys_commit_draft(c, proj, 111); ok := false; EXCEPTION WHEN others THEN ok := true; END;
  SELECT count(*) INTO n2 FROM payment_schedule WHERE company_id = c AND project_id = proj;
  SELECT to_jsonb(p) - 'updated_at' INTO after FROM project_metrics p WHERE company_id = c AND project_id = proj;
  res := res || 'T4 ingest ok=' || (r ->> 'ok') || ', затвердження відхилено: ' || ok || ', графік ' || n1 || '→' || n2 || ', project_metrics без змін: ' || (before = after) || '; ';

  -- T5: рядок і з годинами, і з субпідрядом → відхилено
  pl2 := jsonb_set(pl, '{rows,0,sub}', to_jsonb(1000));
  BEGIN PERFORM koshtorys_ingest_draft(c, proj, pl2, 111); ok := false; EXCEPTION WHEN others THEN ok := true; END;
  res := res || 'T5 години+субпідряд в одному рядку відхилено: ' || ok || '; ';

  -- T6: розділ поза довідником і виконавець без ставки → лише попередження
  pl2 := jsonb_set(jsonb_set(pl, '{rows,0,section}', to_jsonb('ТЕСТ-РОЗДІЛ'::text)), '{rows,0,executor}', to_jsonb('Новий фахівець'::text));
  r := koshtorys_ingest_draft(c, proj, pl2, 111);
  res := res || 'T6 ok=' || (r ->> 'ok') || ' попередження: ' || (r -> 'warnings')::text || '; ';

  -- T7: чернетка замінюється, а не накопичується; чернетка одна
  r := koshtorys_ingest_draft(c, proj, pl, 111);
  SELECT count(*) INTO nd FROM koshtorys_versions WHERE company_id = c AND project_id = proj AND status = 'draft';
  res := res || 'T7 чернеток після двох різних переглядів: ' || nd || ' (очікувано 1); ';

  -- T8: тип файлу не збігається з проєктом; проєкту немає; затвердження без чернетки
  BEGIN PERFORM koshtorys_ingest_draft(c, 'DEMO-01', pg_temp.mkpayload(c, 'DEMO-01-АН'), 111); ok := false; EXCEPTION WHEN others THEN ok := true; END;
  res := res || 'T8 файл нагляду на проєкті зі стадіями відхилено: ' || ok || '; ';
  BEGIN PERFORM koshtorys_ingest_draft(c, 'NO-SUCH', pl, 111); ok := false; EXCEPTION WHEN others THEN ok := true; END;
  res := res || 'T8 проєкту немає відхилено: ' || ok || '; ';
  r := koshtorys_commit_draft(c, 'DEMO-04', 111);
  res := res || 'T8 commit без чернетки: ' || (r ->> 'status') || '; ';

  -- T9: знімок файлу затвердженої версії не змінюється
  BEGIN UPDATE koshtorys_versions SET file_totals = '{}'::jsonb WHERE company_id = c AND project_id = 'DEMO-01' AND status = 'approved'; ok := false; EXCEPTION WHEN others THEN ok := true; END;
  res := res || 'T9 зміна file_totals затвердженої версії відхилена: ' || ok;
  RAISE EXCEPTION 'ТЕСТИ M6 (скасовано): %', res;
END $t$;
