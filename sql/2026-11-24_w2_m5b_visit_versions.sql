-- W2 M5b (24.11.2026): версія 1 Кошториса для проєктів нагляду (contract_type='visit') компанії DEMO: DEMO-01/04/05/08-АН.
-- Параметри з project_metrics: виїзди, ціна виїзду, години на виїзд, ставка; один рядок ГАП. Атомарно: розбіжність із project_metrics = відкат.
DO $m5b$
DECLARE c uuid := '00000000-0000-4000-8000-000000000001'; n int; bad int;
BEGIN
  IF EXISTS (SELECT 1 FROM public.koshtorys_versions v JOIN public.project_metrics p USING (company_id, project_id)
              WHERE v.company_id = c AND p.contract_type = 'visit') THEN
    RAISE EXCEPTION 'M5b: версії нагляду вже є, завантаження зупинено';
  END IF;
  INSERT INTO public.koshtorys_versions (company_id, project_id, version_no, status, kind, contract_amount, source, note,
                                         visits_count, visit_price_uah, visit_hours, visit_rate_uah_hour)
  SELECT p.company_id, p.project_id, 1, 'draft', 'initial', p.contract_amount, 'demo',
         'Демо: початкова версія нагляду. Не затвердження власника.',
         p.visits_plan, p.visit_price, p.visit_hours, p.real_rate_team_hour
    FROM public.project_metrics p WHERE p.company_id = c AND p.contract_type = 'visit';
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO public.koshtorys_rows (version_id, company_id, project_id, stage, section, kind, posada, hours, rate_uah_hour, cost_uah, sort_order)
  SELECT v.id, c, v.project_id, 'АН', 'ГАП', 'internal', 'ГАП', v.visits_count * v.visit_hours, r.razom_grn_god,
         round(v.visits_count * v.visit_hours * v.visit_rate_uah_hour, 2), 1
    FROM public.koshtorys_versions v JOIN public.rates r ON r.company_id = c AND r.posada = 'ГАП'
   WHERE v.company_id = c AND v.version_no = 1 AND v.source = 'demo' AND v.visits_count IS NOT NULL;
  UPDATE public.koshtorys_versions SET status = 'approved', approved_at = now()
   WHERE company_id = c AND version_no = 1 AND source = 'demo' AND visits_count IS NOT NULL;
  SELECT count(*) INTO bad FROM public.project_metrics p
    JOIN public.koshtorys_versions v ON v.company_id = p.company_id AND v.project_id = p.project_id AND v.status = 'approved'
    CROSS JOIN LATERAL (SELECT public.koshtorys_preview(c, v.id) AS pv) x
   WHERE p.company_id = c AND p.contract_type = 'visit'
     AND (NOT (x.pv ->> 'ok')::boolean
          OR (x.pv -> 'totals' ->> 'hours')::numeric <> p.planned_hours
          OR (x.pv -> 'totals' ->> 'contract')::numeric <> p.contract_amount
          OR (x.pv -> 'totals' ->> 'rate')::numeric <> p.real_rate_team_hour
          OR abs((x.pv -> 'totals' ->> 'bac')::numeric - p.bac) > 1
          OR abs((x.pv -> 'totals' ->> 'profit')::numeric - p.profit_plan) > 1);
  IF n = 0 OR bad > 0 THEN RAISE EXCEPTION 'M5b: створено % версій, розбіжностей з project_metrics: %', n, bad; END IF;
END $m5b$;
