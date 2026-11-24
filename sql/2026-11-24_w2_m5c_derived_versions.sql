-- W2 M5c (24.11.2026): версія 1 Кошториса для 22-24, 24-11, 24-37, 24-52 за підсумками project_metrics (p. 40 D-2, правило сесії 9; source='demo_derived').
-- Правило генерації (SQL, не підстановка): команда — по рядку на стадію з годинами etc_plan_by_stage; ставка рядка = real_rate_team_hour; вартість = години × ставка (формат реального Кошториса: т-дн × ставка).
-- Субпідряд — лише гроші, без годин і без розподілу по стадіях: у project_metrics є тільки підсумок (cost_plan_subcontract), тому один рядок «Субпідряд (за підсумками)» без стадії.
-- Посади й розділи невідомі: рядок «команда, середня ставка», розділ «Усього по стадії (за підсумками)».
-- Атомарно: годин точно, ставка точно, вартість ≤ 1 грн; інакше відкат.
DO $m5c$
DECLARE c uuid := '00000000-0000-4000-8000-000000000001'; n int; bad int;
BEGIN
  IF EXISTS (SELECT 1 FROM public.koshtorys_versions WHERE company_id = c AND project_id IN ('22-24','24-11','24-37','24-52')) THEN
    RAISE EXCEPTION 'M5c: версії цих проєктів вже є, завантаження зупинено';
  END IF;
  INSERT INTO public.koshtorys_versions (company_id, project_id, version_no, status, kind, contract_amount, source, note)
  SELECT p.company_id, p.project_id, 1, 'draft', 'initial', p.contract_amount, 'demo_derived',
         'Демо: рядки згенеровано за підсумками project_metrics (середня ставка, стадії). Не затвердження власника.'
    FROM public.project_metrics p WHERE p.company_id = c AND p.project_id IN ('22-24','24-11','24-37','24-52');
  GET DIAGNOSTICS n = ROW_COUNT;
  INSERT INTO public.koshtorys_rows (version_id, company_id, project_id, stage, section, kind, counterparty, hours, rate_uah_hour, cost_uah, sort_order)
  WITH team AS (
    SELECT p.project_id, s.stage, s.ord, (p.etc_plan_by_stage ->> s.stage)::numeric AS h, p.real_rate_team_hour AS rate
      FROM public.project_metrics p
      CROSS JOIN (VALUES ('МБР', 1), ('ЕП', 2), ('П', 3), ('Р', 4)) AS s(stage, ord)
     WHERE p.company_id = c AND p.project_id IN ('22-24','24-11','24-37','24-52')
       AND coalesce((p.etc_plan_by_stage ->> s.stage)::numeric, 0) > 0),
  lines AS (
    SELECT project_id, stage, ord, 'Усього по стадії (за підсумками)' AS section, 'internal' AS kind, NULL::text AS cp, h AS hours, rate, round(h * rate, 2) AS cost FROM team
    UNION ALL
    SELECT p.project_id, NULL, 9, 'Субпідряд (за підсумками)', 'subcontract', 'Субпідряд (за підсумками)', NULL, NULL, p.cost_plan_subcontract
      FROM public.project_metrics p
     WHERE p.company_id = c AND p.project_id IN ('22-24','24-11','24-37','24-52') AND coalesce(p.cost_plan_subcontract, 0) > 0)
  SELECT v.id, c, l.project_id, l.stage, l.section, l.kind, l.cp, l.hours, l.rate, l.cost,
         row_number() OVER (PARTITION BY l.project_id ORDER BY l.ord)
    FROM lines l JOIN public.koshtorys_versions v ON v.company_id = c AND v.project_id = l.project_id AND v.version_no = 1;
  UPDATE public.koshtorys_versions SET status = 'approved', approved_at = now()
   WHERE company_id = c AND version_no = 1 AND source = 'demo_derived';
  SELECT count(*) INTO bad FROM public.project_metrics p
    JOIN public.koshtorys_versions v ON v.company_id = p.company_id AND v.project_id = p.project_id AND v.status = 'approved'
    CROSS JOIN LATERAL (SELECT public.koshtorys_preview(c, v.id) AS pv) x
   WHERE p.company_id = c AND p.project_id IN ('22-24','24-11','24-37','24-52')
     AND ((x.pv -> 'totals' ->> 'hours')::numeric <> p.planned_hours
          OR (x.pv -> 'totals' ->> 'contract')::numeric <> p.contract_amount
          OR (x.pv -> 'totals' ->> 'rate')::numeric <> p.real_rate_team_hour
          OR abs((x.pv -> 'totals' ->> 'cost_internal')::numeric - p.cost_plan_team) > 1
          OR abs((x.pv -> 'totals' ->> 'cost_sub')::numeric - p.cost_plan_subcontract) > 1
          OR abs((x.pv -> 'totals' ->> 'profit')::numeric - p.profit_plan) > 1);
  IF n <> 4 OR bad > 0 THEN RAISE EXCEPTION 'M5c: створено % версій, розбіжностей з project_metrics: %', n, bad; END IF;
END $m5c$;
