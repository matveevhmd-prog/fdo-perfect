-- ARCHI 19.10.2026: показники пп. 1, 2, 3, 9 по тижнях для динаміки в Weekly Render
-- (рішення власника: 13 рядків в усіх колонках, історія з реальних даних, не вигадана).
-- Єдине обчислення в SQL: ті самі формули, що archi_recalc_stages, але на кінець тижня знімка
-- (дата <= week_start + 6) і з даними знімка того тижня.
-- Відкат: DROP TRIGGER archi_snap_metrics ON public.wr_weekly_snapshots;
--         DROP FUNCTION public.archi_snap_metrics_trg(); DROP FUNCTION public.archi_snapshot_metrics(text,date,jsonb,jsonb);
--         ALTER TABLE public.wr_weekly_snapshots DROP COLUMN rent_plan_pct, DROP COLUMN rent_forecast_pct,
--           DROP COLUMN eac_hours_pct, DROP COLUMN cpi, DROP COLUMN etc_plan_hours, DROP COLUMN etc_fact_hours;

-- ===================== КРОК 1. Структура (виконати одним запуском) =====================
ALTER TABLE public.wr_weekly_snapshots
  ADD COLUMN IF NOT EXISTS rent_plan_pct numeric,
  ADD COLUMN IF NOT EXISTS rent_forecast_pct numeric,
  ADD COLUMN IF NOT EXISTS eac_hours_pct numeric,
  ADD COLUMN IF NOT EXISTS cpi numeric,
  ADD COLUMN IF NOT EXISTS etc_plan_hours numeric,
  ADD COLUMN IF NOT EXISTS etc_fact_hours numeric;

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

CREATE OR REPLACE FUNCTION public.archi_snap_metrics_trg() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM public.archi_snapshot_metrics(NEW.project_id, NEW.week_start, NEW."готовність_pct", NEW."залишок_прогноз_по_стадіях");
  NEW.rent_plan_pct := r.rent_plan_pct; NEW.rent_forecast_pct := r.rent_forecast_pct; NEW.eac_hours_pct := r.eac_hours_pct;
  NEW.cpi := r.cpi; NEW.etc_plan_hours := r.etc_plan_hours; NEW.etc_fact_hours := r.etc_fact_hours;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS archi_snap_metrics ON public.wr_weekly_snapshots;
CREATE TRIGGER archi_snap_metrics BEFORE INSERT OR UPDATE ON public.wr_weekly_snapshots
  FOR EACH ROW EXECUTE FUNCTION public.archi_snap_metrics_trg();

-- ===================== КРОК 2. Бекфіл історії (один рядок = один проєкт; якщо таймаут — запускати по 3–4 рядки) =====================
UPDATE public.wr_weekly_snapshots SET week_start = week_start WHERE project_id = '22-24';
UPDATE public.wr_weekly_snapshots SET week_start = week_start WHERE project_id = '24-11';
UPDATE public.wr_weekly_snapshots SET week_start = week_start WHERE project_id = '24-52';
UPDATE public.wr_weekly_snapshots SET week_start = week_start WHERE project_id = 'DEMO-01';
UPDATE public.wr_weekly_snapshots SET week_start = week_start WHERE project_id = 'DEMO-02';
UPDATE public.wr_weekly_snapshots SET week_start = week_start WHERE project_id = 'DEMO-03';
UPDATE public.wr_weekly_snapshots SET week_start = week_start WHERE project_id = 'DEMO-04';
UPDATE public.wr_weekly_snapshots SET week_start = week_start WHERE project_id = 'DEMO-05';
UPDATE public.wr_weekly_snapshots SET week_start = week_start WHERE project_id = 'DEMO-06';
UPDATE public.wr_weekly_snapshots SET week_start = week_start WHERE project_id = 'DEMO-07';
UPDATE public.wr_weekly_snapshots SET week_start = week_start WHERE project_id = 'DEMO-08';
UPDATE public.wr_weekly_snapshots SET week_start = week_start WHERE project_id = 'DEMO-09';
UPDATE public.wr_weekly_snapshots SET week_start = week_start WHERE project_id = 'DEMO-10';

-- ===================== КРОК 3. Перевірка (має повернути 0 розбіжностей для тижня 2026-10-12) =====================
-- SELECT s.project_id, s.rent_forecast_pct, t.rent_forecast_pct AS today, s.eac_hours_pct, t.eac_hours_pct AS today_eac, s.cpi, t.cpi AS today_cpi
-- FROM public.wr_weekly_snapshots s JOIN public.archi_report_today t USING (project_id) WHERE s.week_start = '2026-10-12';
