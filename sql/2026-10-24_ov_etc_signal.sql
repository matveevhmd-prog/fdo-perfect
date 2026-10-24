-- ARCHI 24.10.2026 (RELEASE_PLAN §89): Owner View читає сигнал ETC (S-04) з SQL — єдине обчислення.
-- archi_report_today + etc_gap_pct_bac (Δ ÷ BAC, %) і stage_etc_signal (jsonb: колір S-04 по стадіях, archi_vac_signal(Δ стадії, план стадії)).
-- Решта вʼю без змін (як у sql/2026-10-22_evm_decisions.sql). Без видалень обʼєктів.

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
    public.archi_flow_idx_signal(a.acts_plan_idx) AS acts_plan_signal,
    CASE WHEN COALESCE(m.planned_hours, 0) > 0 AND m.actual_hours IS NOT NULL AND m.etc_forecast_total_hours IS NOT NULL
         THEN round(100 * round(m.etc_forecast_total_hours - round(m.planned_hours - m.actual_hours, 1), 1) / m.planned_hours, 1) END AS etc_gap_pct_bac,
    ( SELECT jsonb_object_agg(s.key, public.archi_vac_signal(
                (s.value ->> 'etc_forecast_hours')::numeric - ((s.value ->> 'etc_plan_hours')::numeric - COALESCE((s.value ->> 'actual_hours_live')::numeric, 0)),
                (s.value ->> 'etc_plan_hours')::numeric))
        FROM jsonb_each(m.stage_data) s(key, value)
       WHERE s.key = ANY (ARRAY['МБР'::text, 'ЕП'::text, 'П'::text, 'Р'::text])
         AND (s.value ->> 'etc_forecast_hours') IS NOT NULL
         AND COALESCE((s.value ->> 'etc_plan_hours')::numeric, 0) > 0) AS stage_etc_signal
   FROM public.project_metrics m
   CROSS JOIN LATERAL public.archi_acts_plan(m.project_id, COALESCE((m.data_updated_at AT TIME ZONE 'Europe/Kyiv')::date, CURRENT_DATE)) a;
