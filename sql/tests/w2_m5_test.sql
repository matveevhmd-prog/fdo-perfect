-- Тести W2 M5. Запускати в одній транзакції ПІСЛЯ M5a, M5b; усе скасовується RAISE EXCEPTION (результат у тексті винятку).
DO $t$
DECLARE c uuid := '00000000-0000-4000-8000-000000000001'; res text := ''; proj text; v1 bigint; v2 bigint; before jsonb; after jsonb; diffs text; r jsonb; ok boolean; n int; old_h numeric; new_h numeric; old_e jsonb; new_e jsonb; an_h text;
BEGIN
  SELECT count(*) INTO n FROM koshtorys_versions WHERE company_id = c AND status = 'approved';
  res := res || 'Затверджених версій: ' || n || ' (очікувано 14); ';
  FOREACH proj IN ARRAY ARRAY['DEMO-01-АН','DEMO-04-АН','DEMO-05-АН','DEMO-08-АН'] LOOP
    SELECT id INTO v1 FROM koshtorys_versions WHERE company_id = c AND project_id = proj AND version_no = 1;
    r := koshtorys_approve(c, v1);
    SELECT to_jsonb(p) - 'updated_at' INTO before FROM project_metrics p WHERE company_id = c AND project_id = proj;
    INSERT INTO koshtorys_versions (company_id, project_id, version_no, status, kind, contract_amount, source, note,
                                    visits_count, visit_price_uah, visit_hours, visit_rate_uah_hour)
      SELECT company_id, project_id, 2, 'draft', 'change', contract_amount, source, 'тест', visits_count, visit_price_uah, visit_hours, visit_rate_uah_hour
        FROM koshtorys_versions WHERE id = v1 RETURNING id INTO v2;
    INSERT INTO koshtorys_rows (version_id, company_id, project_id, stage, section, kind, posada, counterparty, hours, rate_uah_hour, cost_uah, sort_order)
      SELECT v2, company_id, project_id, stage, section, kind, posada, counterparty, hours, rate_uah_hour, cost_uah, sort_order FROM koshtorys_rows WHERE version_id = v1;
    r := koshtorys_approve(c, v2);
    SELECT to_jsonb(p) - 'updated_at' INTO after FROM project_metrics p WHERE company_id = c AND project_id = proj;
    SELECT string_agg(b.key || ' ' || b.value::text || ' -> ' || a.value::text, ', ') INTO diffs
      FROM jsonb_each(before) b JOIN jsonb_each(after) a USING (key) WHERE a.value IS DISTINCT FROM b.value;
    res := res || proj || ' A6 змінені колонки: [' || coalesce(diffs, 'жодної') || ']; ';
  END LOOP;
  -- нагляд: рядок не збігається з параметрами -> затвердження відхилено
  SELECT id INTO v1 FROM koshtorys_versions WHERE company_id = c AND project_id = 'DEMO-01-АН' AND version_no = 2;
  SELECT id INTO v2 FROM koshtorys_versions WHERE company_id = c AND project_id = 'DEMO-04-АН' AND version_no = 2;
  INSERT INTO koshtorys_versions (company_id, project_id, version_no, status, kind, contract_amount, source, note, visits_count, visit_price_uah, visit_hours, visit_rate_uah_hour)
    SELECT company_id, project_id, 3, 'draft', 'change', contract_amount, source, 'тест', visits_count, visit_price_uah, visit_hours, visit_rate_uah_hour FROM koshtorys_versions WHERE id = v1 RETURNING id INTO v1;
  INSERT INTO koshtorys_rows (version_id, company_id, project_id, stage, section, kind, posada, hours, rate_uah_hour, cost_uah, sort_order)
    SELECT v1, company_id, project_id, stage, section, kind, posada, hours + 5, rate_uah_hour, cost_uah, sort_order FROM koshtorys_rows WHERE version_id = (SELECT id FROM koshtorys_versions WHERE company_id = c AND project_id = 'DEMO-01-АН' AND version_no = 2);
  BEGIN PERFORM koshtorys_approve(c, v1); ok := false; EXCEPTION WHEN others THEN ok := true; END;
  res := res || 'Нагляд: рядок із чужими годинами відхилено: ' || ok || '; ';
  -- нагляд: контракт не дорівнює виїзди × ціна -> відхилено
  INSERT INTO koshtorys_versions (company_id, project_id, version_no, status, kind, contract_amount, source, note, visits_count, visit_price_uah, visit_hours, visit_rate_uah_hour)
    SELECT company_id, project_id, 3, 'draft', 'change', contract_amount + 1000, source, 'тест', visits_count, visit_price_uah, visit_hours, visit_rate_uah_hour FROM koshtorys_versions WHERE id = v2 RETURNING id INTO v1;
  INSERT INTO koshtorys_rows (version_id, company_id, project_id, stage, section, kind, posada, hours, rate_uah_hour, cost_uah, sort_order)
    SELECT v1, company_id, project_id, stage, section, kind, posada, hours, rate_uah_hour, cost_uah, sort_order FROM koshtorys_rows WHERE version_id = v2;
  BEGIN PERFORM koshtorys_approve(c, v1); ok := false; EXCEPTION WHEN others THEN ok := true; END;
  res := res || 'Нагляд: контракт ≠ виїзди × ціна відхилено: ' || ok || '; ';
  -- тип версії не збігається з типом проєкту -> відхилено
  SELECT id INTO v1 FROM koshtorys_versions WHERE company_id = c AND project_id = 'DEMO-01' AND version_no = 1;
  INSERT INTO koshtorys_versions (company_id, project_id, version_no, status, kind, contract_amount, source, note, visits_count, visit_price_uah, visit_hours, visit_rate_uah_hour)
    SELECT company_id, project_id, 2, 'draft', 'change', contract_amount, source, 'тест', 10, 7500, 5, 1104.27 FROM koshtorys_versions WHERE id = v1 RETURNING id INTO v2;
  BEGIN PERFORM koshtorys_approve(c, v2); ok := false; EXCEPTION WHEN others THEN ok := true; END;
  res := res || 'Версія нагляду на проєкті зі стадіями відхилена: ' || ok || '; ';
  -- регресія M3/M4 (до Н-7: тест Н-7 змінює DEMO-02)
  n := 0;
  FOR proj IN SELECT 'DEMO-' || lpad(g::text, 2, '0') FROM generate_series(1, 10) g LOOP
    r := koshtorys_preview(c, (SELECT id FROM koshtorys_versions WHERE company_id = c AND project_id = proj AND version_no = 1),
          (SELECT jsonb_build_object('hours', planned_hours, 'cost_internal', cost_plan_team, 'cost_sub', cost_plan_subcontract, 'contract', contract_amount) FROM project_metrics WHERE company_id = c AND project_id = proj));
    IF (r ->> 'ok')::boolean THEN n := n + 1; END IF;
  END LOOP;
  res := res || 'Регресія M4: перевірка підсумків ok у ' || n || ' з 10';
  -- Н-7: години АН основного проєкту входять у planned_hours (D-02), але не в etc_plan_by_stage (D-03)
  SELECT id INTO v1 FROM koshtorys_versions WHERE company_id = c AND project_id = 'DEMO-02' AND version_no = 1;
  SELECT planned_hours, etc_plan_by_stage INTO old_h, old_e FROM project_metrics WHERE company_id = c AND project_id = 'DEMO-02';
  INSERT INTO koshtorys_versions (company_id, project_id, version_no, status, kind, contract_amount, source, note)
    SELECT company_id, project_id, 3, 'draft', 'change', contract_amount, source, 'тест' FROM koshtorys_versions WHERE id = v1 RETURNING id INTO v2;
  INSERT INTO koshtorys_rows (version_id, company_id, project_id, stage, section, kind, posada, counterparty, hours, rate_uah_hour, cost_uah, sort_order)
    SELECT v2, company_id, project_id, stage, section, kind, posada, counterparty,
           CASE WHEN stage = 'АН' THEN 10 ELSE hours END, rate_uah_hour, CASE WHEN stage = 'АН' THEN round(10 * rate_uah_hour, 2) ELSE cost_uah END, sort_order
      FROM koshtorys_rows WHERE version_id = v1;
  PERFORM koshtorys_approve(c, v2);
  SELECT planned_hours, etc_plan_by_stage, planned_hours_by_stage -> 'АН' INTO new_h, new_e, an_h FROM project_metrics WHERE company_id = c AND project_id = 'DEMO-02';
  res := res || 'Н-7 години АН: planned_hours ' || old_h || ' -> ' || new_h || ' (очікувано +10), етапи без змін: ' || (old_e = new_e) || ', АН у планах стадій: ' || an_h || '; ';
  RAISE EXCEPTION 'ТЕСТИ M5 (скасовано): %', res;
END $t$;
