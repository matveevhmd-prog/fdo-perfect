-- Тести W2 M4. Запускати ПІСЛЯ створення функцій у тій самій транзакції; усе скасовується RAISE EXCEPTION у кінці (результат у тексті винятку).
DO $t$
DECLARE c uuid := '00000000-0000-4000-8000-000000000001'; res text := ''; r jsonb; v1 bigint; v2 bigint; v3 bigint;
  before jsonb; after jsonb; diffs text; n int; proj text; ok boolean; d jsonb; old_h numeric; old_c numeric; rt numeric; exp_c numeric; cnt_app int; st1 text;
BEGIN
  -- A1/A17: перевірка підсумків по проєкту проти project_metrics для всіх 10 демо-версій
  n := 0;
  FOR proj IN SELECT 'DEMO-' || lpad(g::text, 2, '0') FROM generate_series(1, 10) g LOOP
    SELECT id INTO v1 FROM koshtorys_versions WHERE company_id = c AND project_id = proj AND version_no = 1;
    r := koshtorys_preview(c, v1, (SELECT jsonb_build_object('hours', planned_hours, 'cost_internal', cost_plan_team,
                 'cost_sub', cost_plan_subcontract, 'contract', contract_amount) FROM project_metrics WHERE company_id = c AND project_id = proj));
    IF (r ->> 'ok')::boolean THEN n := n + 1; END IF;
  END LOOP;
  res := res || 'A1 перевірка підсумків ok у ' || n || ' з 10; ';
  -- негативи й допуск (DEMO-01)
  SELECT id INTO v1 FROM koshtorys_versions WHERE company_id = c AND project_id = 'DEMO-01' AND version_no = 1;
  r := koshtorys_preview(c, v1, '{"hours": 593}'::jsonb);            res := res || 'N1 години +1 відхилено: ' || (NOT (r ->> 'ok')::boolean) || '; ';
  r := koshtorys_preview(c, v1, '{"cost_internal": 348549.86}'::jsonb); res := res || 'N2 вартість +2 відхилено: ' || (NOT (r ->> 'ok')::boolean) || '; ';
  r := koshtorys_preview(c, v1, '{"cost_internal": 348548.36}'::jsonb); res := res || 'N3 вартість +0.5 дозволено: ' || (r ->> 'ok')::boolean || '; ';
  r := koshtorys_preview(c, v1, '{"hours_by_stage": {"МБР": 41}}'::jsonb); res := res || 'N4 години стадії +1 відхилено: ' || (NOT (r ->> 'ok')::boolean) || '; ';

  -- A4 і A6: ідемпотентність та еквівалентність плану; DEMO-01 (збіг рядків 0,00) і DEMO-02 (розбіжність 0,03)
  FOREACH proj IN ARRAY ARRAY['DEMO-01', 'DEMO-02'] LOOP
    SELECT id INTO v1 FROM koshtorys_versions WHERE company_id = c AND project_id = proj AND version_no = 1;
    r := koshtorys_approve(c, v1);
    res := res || proj || ' A4 повторне затвердження: ' || (r ->> 'status') || '; ';
    SELECT to_jsonb(p) - 'updated_at' INTO before FROM project_metrics p WHERE company_id = c AND project_id = proj;
    INSERT INTO koshtorys_versions (company_id, project_id, version_no, status, kind, contract_amount, source, note)
      SELECT company_id, project_id, 2, 'draft', 'change', contract_amount, 'demo', 'тест' FROM koshtorys_versions WHERE id = v1 RETURNING id INTO v2;
    INSERT INTO koshtorys_rows (version_id, company_id, project_id, stage, section, kind, posada, counterparty, hours, rate_uah_hour, cost_uah, sort_order)
      SELECT v2, company_id, project_id, stage, section, kind, posada, counterparty, hours, rate_uah_hour, cost_uah, sort_order FROM koshtorys_rows WHERE version_id = v1;
    r := koshtorys_approve(c, v2);
    SELECT to_jsonb(p) - 'updated_at' INTO after FROM project_metrics p WHERE company_id = c AND project_id = proj;
    SELECT string_agg(b.key || ' ' || b.value::text || ' -> ' || a.value::text, ', ') INTO diffs
      FROM jsonb_each(before) b JOIN jsonb_each(after) a USING (key) WHERE a.value IS DISTINCT FROM b.value;
    SELECT count(*) INTO cnt_app FROM koshtorys_versions WHERE company_id = c AND project_id = proj AND status = 'approved';
    SELECT status INTO st1 FROM koshtorys_versions WHERE id = v1;
    res := res || proj || ' A6 змінені колонки: [' || coalesce(diffs, 'жодної') || ']; затверджених ' || cnt_app || ', v1 ' || st1 || '; ';
  END LOOP;

  -- A17: невірні підсумки файлу блокують затвердження, чернетка й план лишаються
  SELECT id INTO v1 FROM koshtorys_versions WHERE company_id = c AND project_id = 'DEMO-03' AND version_no = 1;
  INSERT INTO koshtorys_versions (company_id, project_id, version_no, status, kind, contract_amount, source, note)
    SELECT company_id, project_id, 2, 'draft', 'change', contract_amount, 'demo', 'тест' FROM koshtorys_versions WHERE id = v1 RETURNING id INTO v3;
  INSERT INTO koshtorys_rows (version_id, company_id, project_id, stage, section, kind, posada, counterparty, hours, rate_uah_hour, cost_uah, sort_order)
    SELECT v3, company_id, project_id, stage, section, kind, posada, counterparty, hours, rate_uah_hour, cost_uah, sort_order FROM koshtorys_rows WHERE version_id = v1;
  SELECT to_jsonb(p) - 'updated_at' INTO before FROM project_metrics p WHERE company_id = c AND project_id = 'DEMO-03';
  BEGIN PERFORM koshtorys_approve(c, v3, NULL, '{"hours": 9999}'::jsonb); ok := false; EXCEPTION WHEN others THEN ok := true; END;
  SELECT to_jsonb(p) - 'updated_at' INTO after FROM project_metrics p WHERE company_id = c AND project_id = 'DEMO-03';
  SELECT status INTO st1 FROM koshtorys_versions WHERE id = v3;
  res := res || 'A17 затвердження з невірними підсумками відхилено: ' || ok || ', чернетка: ' || st1 || ', план без змін: ' || (before = after) || '; ';

  -- A5: різниця версій проти ручного розрахунку (DEMO-04: +10 годин у рядку П / АР / Архітектор (юніор))
  SELECT id INTO v1 FROM koshtorys_versions WHERE company_id = c AND project_id = 'DEMO-04' AND version_no = 1;
  INSERT INTO koshtorys_versions (company_id, project_id, version_no, status, kind, contract_amount, source, note)
    SELECT company_id, project_id, 2, 'draft', 'change', contract_amount, 'demo', 'тест' FROM koshtorys_versions WHERE id = v1 RETURNING id INTO v2;
  INSERT INTO koshtorys_rows (version_id, company_id, project_id, stage, section, kind, posada, counterparty, hours, rate_uah_hour, cost_uah, sort_order)
    SELECT v2, company_id, project_id, stage, section, kind, posada, counterparty, hours, rate_uah_hour, cost_uah, sort_order FROM koshtorys_rows WHERE version_id = v1;
  d := koshtorys_diff(c, v1, v2);
  res := res || 'A5a ідентичні версії: різниця годин ' || (d -> 'delta' ->> 'hours') || ', рядків ' || jsonb_array_length(d -> 'rows') || '; ';
  SELECT hours, cost_uah, rate_uah_hour INTO old_h, old_c, rt FROM koshtorys_rows WHERE version_id = v2 AND stage = 'П' AND section LIKE 'АР%' AND posada = 'Архітектор (юніор)';
  exp_c := round((old_h + 10) * rt, 2) - old_c;
  UPDATE koshtorys_rows SET hours = hours + 10, cost_uah = round((hours + 10) * rate_uah_hour, 2)
   WHERE version_id = v2 AND stage = 'П' AND section LIKE 'АР%' AND posada = 'Архітектор (юніор)';
  d := koshtorys_diff(c, v1, v2);
  res := res || 'A5b години: ' || (d -> 'delta' ->> 'hours') || ' (очікувано 10), вартість: ' || (d -> 'delta' ->> 'cost_internal') || ' (очікувано ' || exp_c
       || '), рядків у різниці: ' || jsonb_array_length(d -> 'rows') || ', зміна профіту, п.п.: ' || (d -> 'delta' ->> 'profit_pct_pp');
  RAISE EXCEPTION 'ТЕСТИ M4 (скасовано): %', res;
END $t$;
