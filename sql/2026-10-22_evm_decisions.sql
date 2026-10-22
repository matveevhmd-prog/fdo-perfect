-- ARCHI 22.10.2026 (RELEASE_PLAN §86): рішення власника по самоаудиту (R1–R5, статусна дата). Без видалень обʼєктів.
-- R1: archi_ready_gap_signal — в обидва боки за модулем (узгодженість прогнозу ПМа), поріг wr_ready_gap_pp (10 п.п.).
-- R2: archi_vac_signal(Δ, BAC) — ETC Δ ≤ 0 → green; Δ > 0 — частка від BAC: etc_yellow 5% / etc_red 10% (EVM: VAC/BAC).
-- R3: exec_idx = Готовність ПМа ÷ Витрачено (CPI у годинах, EV/AC); колір archi_flow_idx_signal (<0,9 жовтий, <0,7 червоний).
-- R4: acts_plan_idx = Σ сума_план підписаних актів ÷ Σ сума_план актів, запланованих на статусну дату (payment_schedule);
--     acts_to_ev лишається як WIP (виставлено ÷ освоєне) без кольору (acts_to_ev_signal = NULL).
-- Статусна дата (власник): дата оновлення даних = data_updated_at (Europe/Kyiv); у вʼю історії — кінець тижня знімка.
-- R5: виняток «ETC Δ без кольору при готовності ≥ 100%» прибрано.

CREATE OR REPLACE FUNCTION public.archi_ready_gap_signal(p_pp numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT CASE
  WHEN p_pp IS NULL THEN NULL
  WHEN abs(p_pp) >= COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'wr_ready_gap_pp'), 10) THEN 'red'
  ELSE 'green' END
$$;

CREATE OR REPLACE FUNCTION public.archi_vac_signal(p_gap numeric, p_bac numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT CASE
  WHEN p_gap IS NULL OR COALESCE(p_bac, 0) <= 0 THEN NULL
  WHEN p_gap <= 0 THEN 'green'
  WHEN p_gap / p_bac > COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'etc_red'), 0.10) THEN 'red'
  WHEN p_gap / p_bac > COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'etc_yellow'), 0.05) THEN 'yellow'
  ELSE 'green' END
$$;

CREATE OR REPLACE FUNCTION public.archi_acts_plan(p_project text, p_asof date)
RETURNS TABLE(acts_due integer, acts_done integer, acts_plan_idx numeric)
LANGUAGE sql STABLE AS $$
WITH d AS (
  SELECT p."сума_план" AS amt,
         EXISTS (SELECT 1 FROM public.money_log x
                 WHERE x.project_id = p.project_id AND x."стадія" = p."стадія" AND x."тип" = 'акт_підписаний'
                   AND x."статус" = 'confirmed' AND x."дата" <= p_asof) AS signed
  FROM public.payment_schedule p
  WHERE p.project_id = p_project AND p."подія" = 'акт' AND p."дата_план" <= p_asof
)
SELECT count(*)::int,
       (count(*) FILTER (WHERE signed))::int,
       CASE WHEN count(*) > 0 AND COALESCE(sum(amt), 0) > 0
            THEN round(COALESCE(sum(amt) FILTER (WHERE signed), 0) / sum(amt), 2) END
FROM d
$$;

CREATE OR REPLACE VIEW public.archi_snapshot_history AS
SELECT s.project_id, s.week_start,
       x.rent_plan_pct, x.rent_forecast_pct, x.eac_hours_pct, x.cpi, x.etc_plan_hours, x.etc_fact_hours,
       x.etc_forecast_hours, x.etc_gap_hours,
       public.archi_vac_signal(x.etc_gap_hours, x.etc_plan_hours) AS etc_gap_signal,
       e.spent_pct, e.ready_pm_pct, e.ready_fc_pct, e.ready_gap_pp, e.ready_gap_signal,
       e.eff_hours_idx, e.eff_signal, e.acts_to_ev, e.paid_to_acts,
       NULL::text AS acts_to_ev_signal,
       public.archi_flow_idx_signal(e.paid_to_acts) AS paid_to_acts_signal,
       CASE WHEN e.spent_pct > 0 AND e.ready_pm_pct IS NOT NULL THEN round(e.ready_pm_pct / e.spent_pct, 2) END AS exec_idx,
       public.archi_flow_idx_signal(CASE WHEN e.spent_pct > 0 AND e.ready_pm_pct IS NOT NULL THEN round(e.ready_pm_pct / e.spent_pct, 2) END) AS exec_signal,
       a.acts_due, a.acts_done, a.acts_plan_idx,
       public.archi_flow_idx_signal(a.acts_plan_idx) AS acts_plan_signal
FROM public.wr_weekly_snapshots s
CROSS JOIN LATERAL public.archi_snapshot_metrics(s.project_id, s.week_start, s."готовність_pct", s."залишок_прогноз_по_стадіях") x
CROSS JOIN LATERAL public.archi_snapshot_evm(s.project_id, s.week_start, s."готовність_pct", s."залишок_прогноз_по_стадіях") e
CROSS JOIN LATERAL public.archi_acts_plan(s.project_id, s.week_start + 6) a;

CREATE OR REPLACE VIEW public.archi_report_today AS
 SELECT m.project_id,
    m.data_updated_at,
    m.profitability_plan_pct AS rent_plan_pct,
    m.profitability_forecast_pct AS rent_forecast_pct,
    m.planned_hours,
    m.actual_hours,
    ( SELECT sum(e.value::numeric) AS sum
           FROM jsonb_each_text(m.etc_plan_by_stage) e(key, value)
          WHERE e.key = ANY (ARRAY['МБР'::text, 'ЕП'::text, 'П'::text, 'Р'::text])) AS etc_plan_hours,
    CASE WHEN m.planned_hours IS NOT NULL AND m.actual_hours IS NOT NULL THEN round(m.planned_hours - m.actual_hours, 1) END AS etc_fact_hours,
    m.etc_forecast_total_hours AS etc_forecast_hours,
    CASE WHEN COALESCE(m.planned_hours, 0) > 0 AND m.actual_hours IS NOT NULL AND m.etc_forecast_total_hours IS NOT NULL THEN round((m.actual_hours + m.etc_forecast_total_hours) / m.planned_hours * 1000) / 10 END AS eac_hours_pct,
    m.cpi_classic_evm AS cpi,
    m.nearest_act_date AS act_date,
    m.nearest_act_probability AS act_prob,
    m.nearest_doc_deadline AS doc_date,
    m.doc_issuance_probability AS doc_prob,
    CASE WHEN m.planned_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND m.etc_forecast_total_hours IS NOT NULL THEN round(m.etc_forecast_total_hours - round(m.planned_hours - m.actual_hours, 1), 1) END AS etc_gap_hours,
    public.archi_vac_signal(
        CASE WHEN m.planned_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND m.etc_forecast_total_hours IS NOT NULL THEN round(m.etc_forecast_total_hours - round(m.planned_hours - m.actual_hours, 1), 1) END,
        m.planned_hours) AS etc_gap_signal,
    CASE WHEN COALESCE(m.planned_hours, 0) > 0 AND m.actual_hours IS NOT NULL THEN round(100 * m.actual_hours / m.planned_hours, 1) END AS spent_pct,
    CASE WHEN m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0) > 0 THEN round(100 * m.earned_value_contract / m.contract_amount, 1) END AS ready_pm_pct,
    CASE WHEN m.etc_forecast_total_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND m.actual_hours + m.etc_forecast_total_hours > 0 THEN round(100 * m.actual_hours / (m.actual_hours + m.etc_forecast_total_hours), 1) END AS ready_fc_pct,
    CASE WHEN m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0) > 0 AND m.etc_forecast_total_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND m.actual_hours + m.etc_forecast_total_hours > 0
         THEN round(round(100 * m.earned_value_contract / m.contract_amount, 1) - round(100 * m.actual_hours / (m.actual_hours + m.etc_forecast_total_hours), 1), 1) END AS ready_gap_pp,
    public.archi_ready_gap_signal(
        CASE WHEN m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0) > 0 AND m.etc_forecast_total_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND m.actual_hours + m.etc_forecast_total_hours > 0
             THEN round(round(100 * m.earned_value_contract / m.contract_amount, 1) - round(100 * m.actual_hours / (m.actual_hours + m.etc_forecast_total_hours), 1), 1) END) AS ready_gap_signal,
    CASE WHEN COALESCE(m.planned_hours, 0) > 0 AND m.etc_forecast_total_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND m.actual_hours + m.etc_forecast_total_hours > 0 THEN round(m.planned_hours / (m.actual_hours + m.etc_forecast_total_hours), 2) END AS eff_hours_idx,
    public.archi_idx_signal(
        CASE WHEN COALESCE(m.planned_hours, 0) > 0 AND m.etc_forecast_total_hours IS NOT NULL AND m.actual_hours IS NOT NULL AND m.actual_hours + m.etc_forecast_total_hours > 0 THEN round(m.planned_hours / (m.actual_hours + m.etc_forecast_total_hours), 2) END) AS eff_signal,
    CASE WHEN m.earned_value_contract > 0 THEN round(m.acts_amount / m.earned_value_contract, 2) END AS acts_to_ev,
    CASE WHEN m.acts_amount > 0 THEN round(m.money_received / m.acts_amount, 2) END AS paid_to_acts,
    NULL::text AS acts_to_ev_signal,
    public.archi_flow_idx_signal(CASE WHEN m.acts_amount > 0 THEN round(m.money_received / m.acts_amount, 2) END) AS paid_to_acts_signal,
    CASE WHEN COALESCE(m.planned_hours, 0) > 0 AND m.actual_hours IS NOT NULL AND m.actual_hours > 0 AND m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0) > 0
         THEN round(round(100 * m.earned_value_contract / m.contract_amount, 1) / NULLIF(round(100 * m.actual_hours / m.planned_hours, 1), 0), 2) END AS exec_idx,
    public.archi_flow_idx_signal(
        CASE WHEN COALESCE(m.planned_hours, 0) > 0 AND m.actual_hours IS NOT NULL AND m.actual_hours > 0 AND m.earned_value_contract IS NOT NULL AND COALESCE(m.contract_amount, 0) > 0
             THEN round(round(100 * m.earned_value_contract / m.contract_amount, 1) / NULLIF(round(100 * m.actual_hours / m.planned_hours, 1), 0), 2) END) AS exec_signal,
    a.acts_due, a.acts_done, a.acts_plan_idx,
    public.archi_flow_idx_signal(a.acts_plan_idx) AS acts_plan_signal
   FROM public.project_metrics m
   CROSS JOIN LATERAL public.archi_acts_plan(m.project_id, COALESCE((m.data_updated_at AT TIME ZONE 'Europe/Kyiv')::date, CURRENT_DATE)) a;
