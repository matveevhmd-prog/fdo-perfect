-- W2 M5a (24.11.2026): рядок «команда, середня ставка» (формат реального Кошториса: т-дн × ставка по стадіях, RELEASE_PLAN §35)
-- і підтримка нагляду (contract_type='visit') у функціях Кошториса. Формул плану не змінює.

-- 1. Рядок internal: або посада з rates, або середня ставка рядка.
ALTER TABLE public.koshtorys_rows DROP CONSTRAINT IF EXISTS koshtorys_rows_kind_chk;
ALTER TABLE public.koshtorys_rows ADD CONSTRAINT koshtorys_rows_kind_chk CHECK (
  (kind = 'internal' AND hours IS NOT NULL AND hours >= 0 AND (posada IS NOT NULL OR rate_uah_hour IS NOT NULL))
  OR (kind = 'subcontract' AND counterparty IS NOT NULL AND hours IS NULL));

-- 2. Підсумки: стадії або нагляд.
CREATE OR REPLACE FUNCTION public.koshtorys_totals(p_company uuid, p_version_id bigint) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path = public AS $f$
DECLARE v koshtorys_versions%ROWTYPE; h numeric; ci numeric; cs numeric; han numeric; stg jsonb;
        rate numeric; bac numeric; profit numeric; ppct numeric; vh numeric; rh numeric; rc numeric;
BEGIN
  SELECT * INTO v FROM koshtorys_versions WHERE company_id = p_company AND id = p_version_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'koshtorys: версію % компанії % не знайдено', p_version_id, p_company; END IF;
  IF v.visits_count IS NOT NULL THEN
    vh := v.visits_count * coalesce(v.visit_hours, 0);
    ci := round(vh * coalesce(v.visit_rate_uah_hour, 0), 2);
    SELECT coalesce(sum(hours), 0), coalesce(sum(cost_uah), 0) INTO rh, rc FROM koshtorys_rows WHERE version_id = p_version_id AND stage = 'АН';
    profit := v.contract_amount - ci;
    ppct := CASE WHEN v.contract_amount > 0 THEN round(profit / v.contract_amount * 100, 1) END;
    RETURN jsonb_build_object(
      'kind', 'visit', 'project_id', v.project_id, 'version_no', v.version_no, 'status', v.status,
      'contract', v.contract_amount, 'contract_by_visits', v.visits_count * coalesce(v.visit_price_uah, 0),
      'visits', v.visits_count, 'visit_price', v.visit_price_uah, 'visit_hours', v.visit_hours,
      'hours', trim_scale(vh), 'hours_an', 0, 'cost_internal', ci, 'cost_sub', 0, 'bac', ci,
      'rate', v.visit_rate_uah_hour, 'profit', profit, 'profit_pct', ppct,
      'rows_hours', trim_scale(rh), 'rows_cost', round(rc, 2));
  END IF;
  SELECT coalesce(sum(hours) FILTER (WHERE kind='internal' AND stage<>'АН'),0),
         coalesce(sum(cost_uah) FILTER (WHERE kind='internal' AND stage<>'АН'),0),
         coalesce(sum(cost_uah) FILTER (WHERE kind='subcontract' AND stage<>'АН'),0),
         coalesce(sum(hours) FILTER (WHERE kind='internal' AND stage='АН'),0)
    INTO h, ci, cs, han FROM koshtorys_rows WHERE version_id = p_version_id;
  SELECT jsonb_object_agg(s, trim_scale(coalesce((SELECT sum(r.hours) FROM koshtorys_rows r
           WHERE r.version_id = p_version_id AND r.kind='internal' AND r.stage = s), 0)))
    INTO stg FROM unnest(ARRAY['МБР','ЕП','П','Р']) AS s;
  rate := CASE WHEN h > 0 THEN round(ci / h, 2) END;
  bac := round(ci, 2) + round(cs, 2);
  profit := v.contract_amount - bac;
  ppct := CASE WHEN v.contract_amount > 0 THEN round(profit / v.contract_amount * 100, 1) END;
  RETURN jsonb_build_object(
    'kind', 'stages', 'project_id', v.project_id, 'version_no', v.version_no, 'status', v.status,
    'contract', v.contract_amount, 'hours', trim_scale(h), 'hours_an', trim_scale(han), 'hours_by_stage', stg,
    'cost_internal', round(ci, 2), 'cost_sub', round(cs, 2), 'bac', bac,
    'rate', rate, 'profit', profit, 'profit_pct', ppct);
END $f$;

-- 3. Перевірка підсумків: для нагляду додатково внутрішні перевірки (контракт = виїзди × ціна; рядок = параметри).
CREATE OR REPLACE FUNCTION public.koshtorys_preview(p_company uuid, p_version_id bigint, p_file_totals jsonb DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path = public AS $f$
DECLARE t jsonb := koshtorys_totals(p_company, p_version_id); checks jsonb := '[]'::jsonb; ok boolean := true;
        k text; tol numeric; fv numeric; rv numeric; good boolean; s text;
BEGIN
  IF p_file_totals IS NOT NULL THEN
    FOREACH k IN ARRAY ARRAY['hours','cost_internal','cost_sub','contract'] LOOP
      IF p_file_totals ? k THEN
        tol := CASE WHEN k IN ('cost_internal','cost_sub') THEN 1.00 ELSE 0 END;
        fv := (p_file_totals ->> k)::numeric; rv := (t ->> k)::numeric;
        good := abs(fv - rv) <= tol;
        checks := checks || jsonb_build_array(jsonb_build_object('name', k, 'file', fv, 'rows', rv, 'tolerance', tol, 'ok', good));
        ok := ok AND good;
      END IF;
    END LOOP;
    IF p_file_totals ? 'hours_by_stage' AND t ->> 'kind' = 'stages' THEN
      FOREACH s IN ARRAY ARRAY['МБР','ЕП','П','Р'] LOOP
        IF (p_file_totals -> 'hours_by_stage') ? s THEN
          fv := (p_file_totals -> 'hours_by_stage' ->> s)::numeric; rv := (t -> 'hours_by_stage' ->> s)::numeric;
          good := fv = rv;
          checks := checks || jsonb_build_array(jsonb_build_object('name', 'hours_' || s, 'file', fv, 'rows', rv, 'tolerance', 0, 'ok', good));
          ok := ok AND good;
        END IF;
      END LOOP;
    END IF;
  END IF;
  IF t ->> 'kind' = 'visit' THEN
    good := (t ->> 'contract')::numeric = (t ->> 'contract_by_visits')::numeric;
    checks := checks || jsonb_build_array(jsonb_build_object('name', 'contract_by_visits', 'file', t -> 'contract', 'rows', t -> 'contract_by_visits', 'tolerance', 0, 'ok', good));
    ok := ok AND good;
    good := (t ->> 'rows_hours')::numeric = (t ->> 'hours')::numeric;
    checks := checks || jsonb_build_array(jsonb_build_object('name', 'visit_rows_hours', 'file', t -> 'hours', 'rows', t -> 'rows_hours', 'tolerance', 0, 'ok', good));
    ok := ok AND good;
    good := abs((t ->> 'rows_cost')::numeric - (t ->> 'cost_internal')::numeric) <= 1.00;
    checks := checks || jsonb_build_array(jsonb_build_object('name', 'visit_rows_cost', 'file', t -> 'cost_internal', 'rows', t -> 'rows_cost', 'tolerance', 1.00, 'ok', good));
    ok := ok AND good;
  END IF;
  RETURN jsonb_build_object('ok', ok, 'checks_provided', p_file_totals IS NOT NULL, 'checks', checks, 'totals', t);
END $f$;

-- 4. Затвердження: стадії й нагляд.
CREATE OR REPLACE FUNCTION public.koshtorys_approve(p_company uuid, p_version_id bigint, p_approved_by bigint DEFAULT NULL, p_file_totals jsonb DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SET search_path = public AS $f$
DECLARE v koshtorys_versions%ROWTYPE; ctype text; pv jsonb; t jsonb;
BEGIN
  SELECT * INTO v FROM koshtorys_versions WHERE company_id = p_company AND id = p_version_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'koshtorys_approve: версію % компанії % не знайдено', p_version_id, p_company; END IF;
  IF v.status = 'approved' THEN
    RETURN jsonb_build_object('status', 'already_approved', 'project_id', v.project_id, 'version_no', v.version_no);
  END IF;
  IF v.status <> 'draft' THEN RAISE EXCEPTION 'koshtorys_approve: версія має статус %, затвердити можна лише чернетку', v.status; END IF;
  SELECT coalesce(contract_type, 'stages') INTO ctype FROM project_metrics WHERE company_id = p_company AND project_id = v.project_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'koshtorys_approve: проєкт % компанії % не знайдено в project_metrics', v.project_id, p_company; END IF;
  IF ctype NOT IN ('stages', 'visit') THEN RAISE EXCEPTION 'koshtorys_approve: тип договору % не підтримується', ctype; END IF;
  pv := koshtorys_preview(p_company, p_version_id, p_file_totals);
  t := pv -> 'totals';
  IF t ->> 'kind' <> ctype THEN RAISE EXCEPTION 'koshtorys_approve: версія типу %, а проєкт типу %', t ->> 'kind', ctype; END IF;
  IF NOT (pv ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'koshtorys_approve: підсумки не збігаються з рядками: %', pv -> 'checks';
  END IF;
  IF (t ->> 'hours')::numeric <= 0 THEN RAISE EXCEPTION 'koshtorys_approve: у версії немає годин'; END IF;
  UPDATE koshtorys_versions SET status = 'superseded'
   WHERE company_id = p_company AND project_id = v.project_id AND status = 'approved';
  UPDATE koshtorys_versions SET status = 'approved', approved_by = p_approved_by, approved_at = now()
   WHERE id = p_version_id;
  IF ctype = 'stages' THEN
    UPDATE project_metrics SET
      contract_amount = v.contract_amount,
      planned_hours = (t ->> 'hours')::numeric,
      planned_hours_by_stage = (t -> 'hours_by_stage') || jsonb_build_object('АН', (t ->> 'hours_an')::numeric),
      etc_plan_by_stage = t -> 'hours_by_stage',
      real_rate_team_hour = (t ->> 'rate')::numeric,
      cost_plan_team = (t ->> 'cost_internal')::numeric,
      cost_plan_subcontract = (t ->> 'cost_sub')::numeric,
      bac = (t ->> 'bac')::numeric,
      profit_plan = (t ->> 'profit')::numeric,
      profitability_plan_pct = (t ->> 'profit_pct')::numeric
     WHERE company_id = p_company AND project_id = v.project_id;
  ELSE
    UPDATE project_metrics SET
      contract_amount = v.contract_amount,
      visits_plan = v.visits_count,
      visit_price = v.visit_price_uah,
      visit_hours = v.visit_hours,
      planned_hours = (t ->> 'hours')::numeric,
      real_rate_team_hour = (t ->> 'rate')::numeric,
      cost_plan_team = (t ->> 'cost_internal')::numeric,
      cost_plan_subcontract = 0,
      bac = (t ->> 'bac')::numeric,
      profit_plan = (t ->> 'profit')::numeric,
      profitability_plan_pct = (t ->> 'profit_pct')::numeric
     WHERE company_id = p_company AND project_id = v.project_id;
  END IF;
  RETURN jsonb_build_object('status', 'approved', 'project_id', v.project_id, 'version_no', v.version_no, 'plan', t);
END $f$;

-- 5. Різниця версій: рядок із середньою ставкою не має посади.
CREATE OR REPLACE FUNCTION public.koshtorys_diff(p_company uuid, p_from bigint, p_to bigint) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path = public AS $f$
DECLARE a jsonb := koshtorys_totals(p_company, p_from); b jsonb := koshtorys_totals(p_company, p_to); lines jsonb;
BEGIN
  IF a ->> 'project_id' <> b ->> 'project_id' THEN RAISE EXCEPTION 'koshtorys_diff: версії належать різним проєктам'; END IF;
  WITH fr AS (
    SELECT stage, section, coalesce(posada, counterparty, 'команда (середня ставка)') AS who, sum(hours) h, sum(cost_uah) c
      FROM koshtorys_rows WHERE version_id = p_from GROUP BY 1, 2, 3),
  tt AS (
    SELECT stage, section, coalesce(posada, counterparty, 'команда (середня ставка)') AS who, sum(hours) h, sum(cost_uah) c
      FROM koshtorys_rows WHERE version_id = p_to GROUP BY 1, 2, 3)
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'stage', coalesce(tt.stage, fr.stage), 'section', coalesce(tt.section, fr.section), 'who', coalesce(tt.who, fr.who),
           'change', CASE WHEN fr.stage IS NULL THEN 'added' WHEN tt.stage IS NULL THEN 'removed' ELSE 'changed' END,
           'hours_from', fr.h, 'hours_to', tt.h, 'cost_from', fr.c, 'cost_to', tt.c)
         ORDER BY coalesce(tt.stage, fr.stage), coalesce(tt.section, fr.section)), '[]'::jsonb)
    INTO lines
    FROM fr FULL JOIN tt ON tt.stage = fr.stage AND tt.section = fr.section AND tt.who = fr.who
   WHERE fr.stage IS NULL OR tt.stage IS NULL
      OR coalesce(fr.h, 0) <> coalesce(tt.h, 0) OR coalesce(fr.c, 0) <> coalesce(tt.c, 0);
  RETURN jsonb_build_object(
    'project_id', a ->> 'project_id',
    'from', jsonb_build_object('id', p_from, 'version_no', a -> 'version_no'),
    'to', jsonb_build_object('id', p_to, 'version_no', b -> 'version_no'),
    'delta', jsonb_build_object(
      'hours', (b ->> 'hours')::numeric - (a ->> 'hours')::numeric,
      'cost_internal', (b ->> 'cost_internal')::numeric - (a ->> 'cost_internal')::numeric,
      'cost_sub', (b ->> 'cost_sub')::numeric - (a ->> 'cost_sub')::numeric,
      'bac', (b ->> 'bac')::numeric - (a ->> 'bac')::numeric,
      'contract', (b ->> 'contract')::numeric - (a ->> 'contract')::numeric,
      'profit', (b ->> 'profit')::numeric - (a ->> 'profit')::numeric,
      'profit_pct_pp', (b ->> 'profit_pct')::numeric - (a ->> 'profit_pct')::numeric),
    'from_totals', a, 'to_totals', b, 'rows', lines);
END $f$;
