-- W2 M4 (22.11.2026): функції Кошториса: підсумки, перевірка підсумків файлу, затвердження, різниця версій (CLAUDE.md п. 41).
-- Формул плану тут немає: суми й округлення відтворюють уже наявний стан project_metrics (години точно, вартість з допуском 1 грн).
-- Затвердження пише ВХІДНІ колонки плану; перерахунок прогнозу виконує наявний тригер archi_recalc_plan -> archi_recalc.
-- Стадія АН основного проєкту не входить у години й BAC (F-23). Проєкти нагляду (contract_type='visit') — у M5, тут явна відмова.
-- Функції SECURITY INVOKER; виконання відкликано в anon і authenticated (RLS на koshtorys_* без політик).

CREATE OR REPLACE FUNCTION public.koshtorys_totals(p_company uuid, p_version_id bigint) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path = public AS $f$
DECLARE v koshtorys_versions%ROWTYPE; h numeric; ci numeric; cs numeric; han numeric; stg jsonb;
        rate numeric; bac numeric; profit numeric; ppct numeric;
BEGIN
  SELECT * INTO v FROM koshtorys_versions WHERE company_id = p_company AND id = p_version_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'koshtorys: версію % компанії % не знайдено', p_version_id, p_company; END IF;
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
    'project_id', v.project_id, 'version_no', v.version_no, 'status', v.status,
    'contract', v.contract_amount, 'hours', trim_scale(h), 'hours_an', trim_scale(han), 'hours_by_stage', stg,
    'cost_internal', round(ci, 2), 'cost_sub', round(cs, 2), 'bac', bac,
    'rate', rate, 'profit', profit, 'profit_pct', ppct);
END $f$;

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
    IF p_file_totals ? 'hours_by_stage' THEN
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
  RETURN jsonb_build_object('ok', ok, 'checks_provided', p_file_totals IS NOT NULL, 'checks', checks, 'totals', t);
END $f$;

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
  IF ctype <> 'stages' THEN RAISE EXCEPTION 'koshtorys_approve: проєкти нагляду (%) підтримуються в кроці M5', ctype; END IF;
  pv := koshtorys_preview(p_company, p_version_id, p_file_totals);
  IF NOT (pv ->> 'ok')::boolean THEN
    RAISE EXCEPTION 'koshtorys_approve: підсумки файлу не збігаються з рядками: %', pv -> 'checks';
  END IF;
  t := pv -> 'totals';
  IF (t ->> 'hours')::numeric <= 0 THEN RAISE EXCEPTION 'koshtorys_approve: у версії немає годин'; END IF;
  UPDATE koshtorys_versions SET status = 'superseded'
   WHERE company_id = p_company AND project_id = v.project_id AND status = 'approved';
  UPDATE koshtorys_versions SET status = 'approved', approved_by = p_approved_by, approved_at = now()
   WHERE id = p_version_id;
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
  RETURN jsonb_build_object('status', 'approved', 'project_id', v.project_id, 'version_no', v.version_no, 'plan', t);
END $f$;

CREATE OR REPLACE FUNCTION public.koshtorys_diff(p_company uuid, p_from bigint, p_to bigint) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path = public AS $f$
DECLARE a jsonb := koshtorys_totals(p_company, p_from); b jsonb := koshtorys_totals(p_company, p_to); lines jsonb;
BEGIN
  IF a ->> 'project_id' <> b ->> 'project_id' THEN RAISE EXCEPTION 'koshtorys_diff: версії належать різним проєктам'; END IF;
  WITH fr AS (
    SELECT stage, section, coalesce(posada, counterparty) AS who, sum(hours) h, sum(cost_uah) c
      FROM koshtorys_rows WHERE version_id = p_from GROUP BY 1, 2, 3),
  tt AS (
    SELECT stage, section, coalesce(posada, counterparty) AS who, sum(hours) h, sum(cost_uah) c
      FROM koshtorys_rows WHERE version_id = p_to GROUP BY 1, 2, 3)
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'stage', coalesce(tt.stage, fr.stage), 'section', coalesce(tt.section, fr.section), 'who', coalesce(tt.who, fr.who),
           'change', CASE WHEN fr.stage IS NULL THEN 'added' WHEN tt.stage IS NULL THEN 'removed' ELSE 'changed' END,
           'hours_from', fr.h, 'hours_to', tt.h, 'cost_from', fr.c, 'cost_to', tt.c)
         ORDER BY coalesce(tt.stage, fr.stage), coalesce(tt.section, fr.section)), '[]'::jsonb)
    INTO lines
    FROM fr FULL JOIN tt ON tt.stage = fr.stage AND tt.section = fr.section AND tt.who IS NOT DISTINCT FROM fr.who
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

REVOKE ALL ON FUNCTION public.koshtorys_totals(uuid, bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.koshtorys_preview(uuid, bigint, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.koshtorys_approve(uuid, bigint, bigint, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.koshtorys_diff(uuid, bigint, bigint) FROM PUBLIC, anon, authenticated;
