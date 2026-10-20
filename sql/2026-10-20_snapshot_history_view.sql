-- ARCHI 20.10.2026 (міграція archi_snapshot_history_view_20261020): історія показників пп. 1, 2, 3, 9 по тижнях знімків для Weekly Render.
-- Єдине обчислення в SQL: ті самі формули, що archi_recalc_stages, але на кінець тижня знімка (дата <= week_start + 6) і з даними знімка того тижня.
-- Без колонок, тригерів і бекфілу: рахується при читанні (не дублюється, не застаріває при виправленні time_log/money_log).
-- Відкат: DROP VIEW public.archi_snapshot_history; DROP FUNCTION public.archi_snapshot_metrics(text,date,jsonb,jsonb);
CREATE OR REPLACE FUNCTION public.archi_snapshot_metrics(p_project text, p_week date, p_rd jsonb, p_et jsonb)
RETURNS TABLE(rent_plan_pct numeric, rent_forecast_pct numeric, eac_hours_pct numeric, cpi numeric, etc_plan_hours numeric, etc_fact_hours numeric)
LANGUAGE sql STABLE AS $$
WITH m AS (
  SELECT * FROM public.project_metrics WHERE project_id = p_project AND COALESCE(contract_type, 'stages') = 'stages'
),
st AS (SELECT unnest(ARRAY['МБР','ЕП','П','Р']) AS s),
hrs AS (
  SELECT t."стадія" AS s, sum(t."години") AS h,
         sum(t."години" * COALESCE(r.razom_grn_god, m.real_rate_team_hour)) AS cost
  FROM public.time_log t CROSS JOIN m LEFT JOIN public.rates r ON r.posada = t."виконавець"
  WHERE t.project_id = p_project AND t."статус" = 'confirmed' AND t."дата" <= p_week + 6
  GROUP BY 1
),
tot AS (SELECT COALESCE(sum(h), 0) AS act_h, COALESCE(sum(cost), 0) AS team_cost FROM hrs),
sub AS (
  SELECT COALESCE(sum("сума"), 0) AS sub_paid FROM public.money_log
  WHERE project_id = p_project AND "статус" = 'confirmed' AND "тип" = 'оплата_субпідряднику' AND "дата" <= p_week + 6
),
ps AS (
  SELECT st.s, COALESCE((m.etc_plan_by_stage ->> st.s)::numeric, 0) AS plan_h,
         COALESCE((p_et ->> st.s)::numeric,
                  CASE WHEN (p_rd ->> st.s)::numeric >= 100 OR (m.etc_plan_by_stage IS NOT NULL AND COALESCE((m.etc_plan_by_stage ->> st.s)::numeric, 0) = 0) THEN 0 END) AS etc_f,
         COALESCE((p_rd ->> st.s)::numeric,
                  CASE WHEN m.etc_plan_by_stage IS NOT NULL AND COALESCE((m.etc_plan_by_stage ->> st.s)::numeric, 0) = 0 THEN 100 END) AS rd_f
  FROM m CROSS JOIN st
),
agg AS (
  SELECT CASE WHEN count(etc_f) = 4 THEN sum(etc_f) END AS etc_total,
         CASE WHEN count(rd_f) = 4 AND sum(plan_h) > 0 THEN sum(rd_f / 100 * plan_h) / sum(plan_h) END AS pct_complete,
         sum(plan_h) AS plan_all
  FROM ps
),
f AS (
  SELECT m.profitability_plan_pct AS rpp, m.contract_amount, m.bac, m.planned_hours, m.real_rate_team_hour AS rate,
         GREATEST(COALESCE(m.cost_plan_subcontract, 0) - sub.sub_paid, 0) AS mtc_sub,
         round(tot.team_cost + sub.sub_paid, 2) AS actual_cost, tot.act_h, agg.etc_total, agg.pct_complete, agg.plan_all
  FROM m CROSS JOIN tot CROSS JOIN sub CROSS JOIN agg
)
SELECT f.rpp,
       round((f.contract_amount - round(f.actual_cost + f.etc_total * f.rate + f.mtc_sub, 2)) / NULLIF(f.contract_amount, 0) * 100, 1),
       CASE WHEN COALESCE(f.planned_hours, 0) > 0 AND f.etc_total IS NOT NULL THEN round((f.act_h + f.etc_total) / f.planned_hours * 1000) / 10 END,
       round(round(f.bac * f.pct_complete, 2) / NULLIF(f.actual_cost, 0), 4),
       f.plan_all,
       CASE WHEN f.planned_hours IS NOT NULL THEN round(f.planned_hours - f.act_h, 1) END
FROM f;
$$;

CREATE OR REPLACE VIEW public.archi_snapshot_history AS
SELECT s.project_id, s.week_start,
       x.rent_plan_pct, x.rent_forecast_pct, x.eac_hours_pct, x.cpi, x.etc_plan_hours, x.etc_fact_hours
FROM public.wr_weekly_snapshots s
CROSS JOIN LATERAL public.archi_snapshot_metrics(s.project_id, s.week_start, s."готовність_pct", s."залишок_прогноз_по_стадіях") x;
