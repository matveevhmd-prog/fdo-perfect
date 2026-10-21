-- ARCHI 21.10.2026 (RELEASE_PLAN §82): три рішення власника після §81. Без видалень обʼєктів.
-- 1) Ефективність годин (E-05) — симетрично відносно 1,00: червоний < idx_red (0,7) або > 2 − idx_red (1,3); жовтий < idx_yellow (0,9) або > 2 − idx_yellow (1,1).
-- 2) Оплата ÷ акти (E-07): > 1 (аванс) — жовтий; нижче — пороги idx_yellow / idx_red.
-- 3) ETC Δ: для повністю виконаного проєкту (готовність ПМа ≥ 100%) колір не рахується (NULL).
-- Вʼю archi_snapshot_history і archi_report_today: ті самі колонки, змінені лише вирази сигналів.

CREATE OR REPLACE FUNCTION public.archi_idx_signal(p numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT CASE
  WHEN p IS NULL THEN NULL
  WHEN p < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_red'), 0.7)
    OR p > 2 - COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_red'), 0.7) THEN 'red'
  WHEN p < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_yellow'), 0.9)
    OR p > 2 - COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_yellow'), 0.9) THEN 'yellow'
  ELSE 'green' END
$$;

CREATE OR REPLACE FUNCTION public.archi_paid_idx_signal(p numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT CASE
  WHEN p IS NULL THEN NULL
  WHEN p > 1 THEN 'yellow'
  ELSE public.archi_flow_idx_signal(p) END
$$;

CREATE OR REPLACE VIEW public.archi_snapshot_history AS
SELECT s.project_id, s.week_start,
       x.rent_plan_pct, x.rent_forecast_pct, x.eac_hours_pct, x.cpi, x.etc_plan_hours, x.etc_fact_hours,
       x.etc_forecast_hours, x.etc_gap_hours,
       CASE WHEN e.ready_pm_pct >= 100 THEN NULL ELSE x.etc_gap_signal END AS etc_gap_signal,
       e.spent_pct, e.ready_pm_pct, e.ready_fc_pct, e.ready_gap_pp, e.ready_gap_signal,
       e.eff_hours_idx, e.eff_signal, e.acts_to_ev, e.paid_to_acts,
       public.archi_flow_idx_signal(e.acts_to_ev) AS acts_to_ev_signal,
       public.archi_paid_idx_signal(e.paid_to_acts) AS paid_to_acts_signal
FROM public.wr_weekly_snapshots s
CROSS JOIN LATERAL public.archi_snapshot_metrics(s.project_id, s.week_start, s."готовність_pct", s."залишок_прогноз_по_стадіях") x
CROSS JOIN LATERAL public.archi_snapshot_evm(s.project_id, s.week_start, s."готовність_pct", s."залишок_прогноз_по_стадіях") e;

CREATE OR REPLACE VIEW public.archi_report_today AS
 SELECT project_id,
    data_updated_at,
    profitability_plan_pct AS rent_plan_pct,
    profitability_forecast_pct AS rent_forecast_pct,
    planned_hours,
    actual_hours,
    ( SELECT sum(e.value::numeric) AS sum
           FROM jsonb_each_text(m.etc_plan_by_stage) e(key, value)
          WHERE e.key = ANY (ARRAY['МБР'::text, 'ЕП'::text, 'П'::text, 'Р'::text])) AS etc_plan_hours,
    CASE WHEN planned_hours IS NOT NULL AND actual_hours IS NOT NULL THEN round(planned_hours - actual_hours, 1) END AS etc_fact_hours,
    etc_forecast_total_hours AS etc_forecast_hours,
    CASE WHEN COALESCE(planned_hours, 0) > 0 AND actual_hours IS NOT NULL AND etc_forecast_total_hours IS NOT NULL THEN round((actual_hours + etc_forecast_total_hours) / planned_hours * 1000) / 10 END AS eac_hours_pct,
    cpi_classic_evm AS cpi,
    nearest_act_date AS act_date,
    nearest_act_probability AS act_prob,
    nearest_doc_deadline AS doc_date,
    doc_issuance_probability AS doc_prob,
    CASE WHEN planned_hours IS NOT NULL AND actual_hours IS NOT NULL AND etc_forecast_total_hours IS NOT NULL THEN round(etc_forecast_total_hours - round(planned_hours - actual_hours, 1), 1) END AS etc_gap_hours,
    CASE WHEN earned_value_contract IS NOT NULL AND COALESCE(contract_amount, 0) > 0 AND earned_value_contract >= contract_amount THEN NULL
         ELSE public.archi_etc_gap_signal(
              CASE WHEN planned_hours IS NOT NULL AND actual_hours IS NOT NULL THEN round(planned_hours - actual_hours, 1) END,
              etc_forecast_total_hours) END AS etc_gap_signal,
    CASE WHEN COALESCE(planned_hours, 0) > 0 AND actual_hours IS NOT NULL THEN round(100 * actual_hours / planned_hours, 1) END AS spent_pct,
    CASE WHEN earned_value_contract IS NOT NULL AND COALESCE(contract_amount, 0) > 0 THEN round(100 * earned_value_contract / contract_amount, 1) END AS ready_pm_pct,
    CASE WHEN etc_forecast_total_hours IS NOT NULL AND actual_hours IS NOT NULL AND actual_hours + etc_forecast_total_hours > 0 THEN round(100 * actual_hours / (actual_hours + etc_forecast_total_hours), 1) END AS ready_fc_pct,
    CASE WHEN earned_value_contract IS NOT NULL AND COALESCE(contract_amount, 0) > 0 AND etc_forecast_total_hours IS NOT NULL AND actual_hours IS NOT NULL AND actual_hours + etc_forecast_total_hours > 0
         THEN round(round(100 * earned_value_contract / contract_amount, 1) - round(100 * actual_hours / (actual_hours + etc_forecast_total_hours), 1), 1) END AS ready_gap_pp,
    public.archi_ready_gap_signal(
        CASE WHEN earned_value_contract IS NOT NULL AND COALESCE(contract_amount, 0) > 0 AND etc_forecast_total_hours IS NOT NULL AND actual_hours IS NOT NULL AND actual_hours + etc_forecast_total_hours > 0
             THEN round(round(100 * earned_value_contract / contract_amount, 1) - round(100 * actual_hours / (actual_hours + etc_forecast_total_hours), 1), 1) END) AS ready_gap_signal,
    CASE WHEN COALESCE(planned_hours, 0) > 0 AND etc_forecast_total_hours IS NOT NULL AND actual_hours IS NOT NULL AND actual_hours + etc_forecast_total_hours > 0 THEN round(planned_hours / (actual_hours + etc_forecast_total_hours), 2) END AS eff_hours_idx,
    public.archi_idx_signal(
        CASE WHEN COALESCE(planned_hours, 0) > 0 AND etc_forecast_total_hours IS NOT NULL AND actual_hours IS NOT NULL AND actual_hours + etc_forecast_total_hours > 0 THEN round(planned_hours / (actual_hours + etc_forecast_total_hours), 2) END) AS eff_signal,
    CASE WHEN earned_value_contract > 0 THEN round(acts_amount / earned_value_contract, 2) END AS acts_to_ev,
    CASE WHEN acts_amount > 0 THEN round(money_received / acts_amount, 2) END AS paid_to_acts,
    public.archi_flow_idx_signal(CASE WHEN earned_value_contract > 0 THEN round(acts_amount / earned_value_contract, 2) END) AS acts_to_ev_signal,
    public.archi_paid_idx_signal(CASE WHEN acts_amount > 0 THEN round(money_received / acts_amount, 2) END) AS paid_to_acts_signal
   FROM project_metrics m;
