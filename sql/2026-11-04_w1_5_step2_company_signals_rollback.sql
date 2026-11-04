-- Відкат W1.5 крок 2 (виконувати в Supabase SQL Editor). Порядок: в'ю → функції снапшота → DROP нових сигналів.
CREATE OR REPLACE VIEW public.archi_snapshot_history AS
SELECT s.project_id,
    s.week_start,
    x.rent_plan_pct,
    x.rent_forecast_pct,
    x.eac_hours_pct,
    x.cpi,
    x.etc_plan_hours,
    x.etc_fact_hours,
    x.etc_forecast_hours,
    x.etc_gap_hours,
    archi_vac_signal(x.etc_gap_hours, x.etc_plan_hours) AS etc_gap_signal,
    e.spent_pct,
    e.ready_pm_pct,
    e.ready_fc_pct,
    e.ready_gap_pp,
    e.ready_gap_signal,
    e.eff_hours_idx,
    e.eff_signal,
    e.acts_to_ev,
    e.paid_to_acts,
    NULL::text AS acts_to_ev_signal,
    archi_flow_idx_signal(e.paid_to_acts) AS paid_to_acts_signal,
        CASE
            WHEN ((e.spent_pct > (0)::numeric) AND (e.ready_pm_pct IS NOT NULL)) THEN round((e.ready_pm_pct / e.spent_pct), 2)
            ELSE NULL::numeric
        END AS exec_idx,
    archi_flow_idx_signal(
        CASE
            WHEN ((e.spent_pct > (0)::numeric) AND (e.ready_pm_pct IS NOT NULL)) THEN round((e.ready_pm_pct / e.spent_pct), 2)
            ELSE NULL::numeric
        END) AS exec_signal,
    a.acts_due,
    a.acts_done,
    a.acts_plan_idx,
    archi_flow_idx_signal(a.acts_plan_idx) AS acts_plan_signal,
    s.company_id
   FROM (((wr_weekly_snapshots s
     CROSS JOIN LATERAL archi_snapshot_metrics(s.company_id, s.project_id, s.week_start, s."готовність_pct", s."залишок_прогноз_по_стадіях") x(rent_plan_pct, rent_forecast_pct, eac_hours_pct, cpi, etc_plan_hours, etc_fact_hours, etc_forecast_hours, etc_gap_hours, etc_gap_signal))
     CROSS JOIN LATERAL archi_snapshot_evm(s.company_id, s.project_id, s.week_start, s."готовність_pct", s."залишок_прогноз_по_стадіях") e(spent_pct, ready_pm_pct, ready_fc_pct, ready_gap_pp, ready_gap_signal, eff_hours_idx, eff_signal, acts_to_ev, paid_to_acts))
     CROSS JOIN LATERAL archi_acts_plan(s.company_id, s.project_id, (s.week_start + 6)) a(acts_due, acts_done, acts_plan_idx));
CREATE OR REPLACE VIEW public.archi_weekly_progress AS
WITH h AS (
         SELECT archi_snapshot_history.company_id,
            archi_snapshot_history.project_id,
            archi_snapshot_history.week_start,
            archi_snapshot_history.ready_pm_pct,
            lag(archi_snapshot_history.week_start) OVER w AS prev_week,
            lag(archi_snapshot_history.ready_pm_pct) OVER w AS prev_ready
           FROM archi_snapshot_history
          WINDOW w AS (PARTITION BY archi_snapshot_history.company_id, archi_snapshot_history.project_id ORDER BY archi_snapshot_history.week_start)
        ), i AS (
         SELECT h.company_id,
            h.project_id,
            h.week_start,
            h.prev_week,
            h.prev_ready,
            h.ready_pm_pct AS ready,
            m.contract_amount,
            m.real_rate_team_hour AS rate0
           FROM (h
             JOIN project_metrics m ON (((m.company_id = h.company_id) AND (m.project_id = h.project_id))))
          WHERE ((h.prev_week IS NOT NULL) AND (h.ready_pm_pct IS NOT NULL) AND (h.prev_ready IS NOT NULL))
        ), c AS (
         SELECT i.company_id,
            i.project_id,
            i.week_start,
            i.prev_week,
            i.prev_ready,
            i.ready,
            i.contract_amount,
            i.rate0,
            hrs.hours,
            hrs.cost
           FROM (i
             LEFT JOIN LATERAL ( SELECT COALESCE(sum(t."години"), (0)::numeric) AS hours,
                    COALESCE(sum((t."години" * COALESCE(r.razom_grn_god, i.rate0))), (0)::numeric) AS cost
                   FROM (time_log t
                     LEFT JOIN rates r ON (((r.posada = t."виконавець") AND (r.company_id = t.company_id))))
                  WHERE ((t.company_id = i.company_id) AND (t.project_id = i.project_id) AND (t."статус" = 'confirmed'::text) AND (t."дата" > (i.prev_week + 6)) AND (t."дата" <= (i.week_start + 6)))) hrs ON (true))
        )
 SELECT project_id,
    week_start,
    prev_week,
    round(prev_ready, 1) AS ready_prev_pct,
    round(ready, 1) AS ready_pct,
    round((ready - prev_ready), 1) AS d_ready_pp,
    round(hours, 1) AS hours,
    round(cost) AS cost_uah,
    contract_amount,
    round((((ready - prev_ready) / (100)::numeric) * contract_amount)) AS value_uah,
    round(((((ready - prev_ready) / (100)::numeric) * contract_amount) - cost)) AS result_uah,
        CASE
            WHEN (cost > (0)::numeric) THEN round(((((ready - prev_ready) / (100)::numeric) * contract_amount) / cost), 2)
            ELSE NULL::numeric
        END AS idx,
    archi_flow_idx_signal(
        CASE
            WHEN (cost > (0)::numeric) THEN round(((((ready - prev_ready) / (100)::numeric) * contract_amount) / cost), 2)
            ELSE NULL::numeric
        END) AS signal,
    round(((GREATEST((ready - prev_ready), (0)::numeric) / (100)::numeric) * contract_amount)) AS budget_uah,
    round(LEAST(cost, ((GREATEST((ready - prev_ready), (0)::numeric) / (100)::numeric) * contract_amount))) AS customer_money_uah,
    round(GREATEST((cost - ((GREATEST((ready - prev_ready), (0)::numeric) / (100)::numeric) * contract_amount)), (0)::numeric)) AS owner_money_uah,
    company_id
   FROM c;
CREATE OR REPLACE VIEW public.archi_report_today AS
SELECT m.project_id,
    m.data_updated_at,
    m.profitability_plan_pct AS rent_plan_pct,
    m.profitability_forecast_pct AS rent_forecast_pct,
    m.planned_hours,
    m.actual_hours,
    ( SELECT sum((e.value)::numeric) AS sum
           FROM jsonb_each_text(m.etc_plan_by_stage) e(key, value)
          WHERE (e.key = ANY (ARRAY['МБР'::text, 'ЕП'::text, 'П'::text, 'Р'::text]))) AS etc_plan_hours,
        CASE
            WHEN ((b.bac_h IS NOT NULL) AND (b.ac_h IS NOT NULL)) THEN round((b.bac_h - b.ac_h), 1)
            ELSE NULL::numeric
        END AS etc_fact_hours,
    m.etc_forecast_total_hours AS etc_forecast_hours,
        CASE
            WHEN ((COALESCE(b.bac_h, (0)::numeric) > (0)::numeric) AND (b.ac_h IS NOT NULL) AND (m.etc_forecast_total_hours IS NOT NULL)) THEN (round((((b.ac_h + m.etc_forecast_total_hours) / b.bac_h) * (1000)::numeric)) / (10)::numeric)
            ELSE NULL::numeric
        END AS eac_hours_pct,
    m.cpi_classic_evm AS cpi,
    m.nearest_act_date AS act_date,
    m.nearest_act_probability AS act_prob,
    m.nearest_doc_deadline AS doc_date,
    m.doc_issuance_probability AS doc_prob,
        CASE
            WHEN ((b.bac_h IS NOT NULL) AND (b.ac_h IS NOT NULL) AND (m.etc_forecast_total_hours IS NOT NULL)) THEN round((m.etc_forecast_total_hours - round((b.bac_h - b.ac_h), 1)), 1)
            ELSE NULL::numeric
        END AS etc_gap_hours,
    archi_vac_signal(
        CASE
            WHEN ((b.bac_h IS NOT NULL) AND (b.ac_h IS NOT NULL) AND (m.etc_forecast_total_hours IS NOT NULL)) THEN round((m.etc_forecast_total_hours - round((b.bac_h - b.ac_h), 1)), 1)
            ELSE NULL::numeric
        END, b.bac_h) AS etc_gap_signal,
        CASE
            WHEN ((COALESCE(b.bac_h, (0)::numeric) > (0)::numeric) AND (b.ac_h IS NOT NULL)) THEN round((((100)::numeric * b.ac_h) / b.bac_h), 1)
            ELSE NULL::numeric
        END AS spent_pct,
        CASE
            WHEN ((m.earned_value_contract IS NOT NULL) AND (COALESCE(m.contract_amount, (0)::numeric) > (0)::numeric)) THEN round((((100)::numeric * m.earned_value_contract) / m.contract_amount), 1)
            ELSE NULL::numeric
        END AS ready_pm_pct,
        CASE
            WHEN ((m.etc_forecast_total_hours IS NOT NULL) AND (b.ac_h IS NOT NULL) AND ((b.ac_h + m.etc_forecast_total_hours) > (0)::numeric)) THEN round((((100)::numeric * b.ac_h) / (b.ac_h + m.etc_forecast_total_hours)), 1)
            ELSE NULL::numeric
        END AS ready_fc_pct,
        CASE
            WHEN ((m.earned_value_contract IS NOT NULL) AND (COALESCE(m.contract_amount, (0)::numeric) > (0)::numeric) AND (m.etc_forecast_total_hours IS NOT NULL) AND (b.ac_h IS NOT NULL) AND ((b.ac_h + m.etc_forecast_total_hours) > (0)::numeric)) THEN round((round((((100)::numeric * m.earned_value_contract) / m.contract_amount), 1) - round((((100)::numeric * b.ac_h) / (b.ac_h + m.etc_forecast_total_hours)), 1)), 1)
            ELSE NULL::numeric
        END AS ready_gap_pp,
    archi_ready_gap_signal(
        CASE
            WHEN ((m.earned_value_contract IS NOT NULL) AND (COALESCE(m.contract_amount, (0)::numeric) > (0)::numeric) AND (m.etc_forecast_total_hours IS NOT NULL) AND (b.ac_h IS NOT NULL) AND ((b.ac_h + m.etc_forecast_total_hours) > (0)::numeric)) THEN round((round((((100)::numeric * m.earned_value_contract) / m.contract_amount), 1) - round((((100)::numeric * b.ac_h) / (b.ac_h + m.etc_forecast_total_hours)), 1)), 1)
            ELSE NULL::numeric
        END) AS ready_gap_signal,
        CASE
            WHEN ((COALESCE(b.bac_h, (0)::numeric) > (0)::numeric) AND (m.etc_forecast_total_hours IS NOT NULL) AND (b.ac_h IS NOT NULL) AND ((b.ac_h + m.etc_forecast_total_hours) > (0)::numeric)) THEN round((b.bac_h / (b.ac_h + m.etc_forecast_total_hours)), 2)
            ELSE NULL::numeric
        END AS eff_hours_idx,
    archi_idx_signal(
        CASE
            WHEN ((COALESCE(b.bac_h, (0)::numeric) > (0)::numeric) AND (m.etc_forecast_total_hours IS NOT NULL) AND (b.ac_h IS NOT NULL) AND ((b.ac_h + m.etc_forecast_total_hours) > (0)::numeric)) THEN round((b.bac_h / (b.ac_h + m.etc_forecast_total_hours)), 2)
            ELSE NULL::numeric
        END) AS eff_signal,
        CASE
            WHEN (m.earned_value_contract > (0)::numeric) THEN round((m.acts_amount / m.earned_value_contract), 2)
            ELSE NULL::numeric
        END AS acts_to_ev,
        CASE
            WHEN (m.acts_amount > (0)::numeric) THEN round((m.money_received / m.acts_amount), 2)
            ELSE NULL::numeric
        END AS paid_to_acts,
    NULL::text AS acts_to_ev_signal,
    archi_flow_idx_signal(
        CASE
            WHEN (m.acts_amount > (0)::numeric) THEN round((m.money_received / m.acts_amount), 2)
            ELSE NULL::numeric
        END) AS paid_to_acts_signal,
        CASE
            WHEN ((COALESCE(b.bac_h, (0)::numeric) > (0)::numeric) AND (b.ac_h IS NOT NULL) AND (b.ac_h > (0)::numeric) AND (m.earned_value_contract IS NOT NULL) AND (COALESCE(m.contract_amount, (0)::numeric) > (0)::numeric)) THEN round((round((((100)::numeric * m.earned_value_contract) / m.contract_amount), 1) / NULLIF(round((((100)::numeric * b.ac_h) / b.bac_h), 1), (0)::numeric)), 2)
            ELSE NULL::numeric
        END AS exec_idx,
    archi_flow_idx_signal(
        CASE
            WHEN ((COALESCE(b.bac_h, (0)::numeric) > (0)::numeric) AND (b.ac_h IS NOT NULL) AND (b.ac_h > (0)::numeric) AND (m.earned_value_contract IS NOT NULL) AND (COALESCE(m.contract_amount, (0)::numeric) > (0)::numeric)) THEN round((round((((100)::numeric * m.earned_value_contract) / m.contract_amount), 1) / NULLIF(round((((100)::numeric * b.ac_h) / b.bac_h), 1), (0)::numeric)), 2)
            ELSE NULL::numeric
        END) AS exec_signal,
    a.acts_due,
    a.acts_done,
    a.acts_plan_idx,
    archi_flow_idx_signal(a.acts_plan_idx) AS acts_plan_signal,
        CASE
            WHEN ((COALESCE(b.bac_h, (0)::numeric) > (0)::numeric) AND (b.ac_h IS NOT NULL) AND (m.etc_forecast_total_hours IS NOT NULL)) THEN round((((100)::numeric * round((m.etc_forecast_total_hours - round((b.bac_h - b.ac_h), 1)), 1)) / b.bac_h), 1)
            ELSE NULL::numeric
        END AS etc_gap_pct_bac,
    ( SELECT jsonb_object_agg(s.key, archi_vac_signal((((s.value ->> 'etc_forecast_hours'::text))::numeric - (((s.value ->> 'etc_plan_hours'::text))::numeric - COALESCE(((s.value ->> 'actual_hours_live'::text))::numeric, (0)::numeric))), ((s.value ->> 'etc_plan_hours'::text))::numeric)) AS jsonb_object_agg
           FROM jsonb_each(m.stage_data) s(key, value)
          WHERE ((s.key = ANY (ARRAY['МБР'::text, 'ЕП'::text, 'П'::text, 'Р'::text])) AND ((s.value ->> 'etc_forecast_hours'::text) IS NOT NULL) AND (COALESCE(((s.value ->> 'etc_plan_hours'::text))::numeric, (0)::numeric) > (0)::numeric))) AS stage_etc_signal,
    m.company_id
   FROM ((project_metrics m
     CROSS JOIN LATERAL ( SELECT
                CASE
                    WHEN (COALESCE(m.contract_type, 'stages'::text) = 'stages'::text) THEN ( SELECT sum((e.value)::numeric) AS sum
                       FROM jsonb_each_text(m.etc_plan_by_stage) e(key, value)
                      WHERE (e.key = ANY (ARRAY['МБР'::text, 'ЕП'::text, 'П'::text, 'Р'::text])))
                    ELSE m.planned_hours
                END AS bac_h,
                CASE
                    WHEN (COALESCE(m.contract_type, 'stages'::text) = 'stages'::text) THEN ( SELECT COALESCE(sum(t."години"), (0)::numeric) AS "coalesce"
                       FROM time_log t
                      WHERE ((t.company_id = m.company_id) AND (t.project_id = m.project_id) AND (t."статус" = 'confirmed'::text) AND (t."стадія" = ANY (ARRAY['МБР'::text, 'ЕП'::text, 'П'::text, 'Р'::text]))))
                    ELSE m.actual_hours
                END AS ac_h) b)
     CROSS JOIN LATERAL archi_acts_plan(m.company_id, m.project_id, COALESCE(((m.data_updated_at AT TIME ZONE 'Europe/Kyiv'::text))::date, CURRENT_DATE)) a(acts_due, acts_done, acts_plan_idx));
CREATE OR REPLACE VIEW public.archi_plan_execution AS
WITH c AS (
         SELECT p.company_id,
            p.project_id,
            p.week_start,
            (count(*))::integer AS total,
            (count(*) FILTER (WHERE (p.status = 'done'::text)))::integer AS done,
            (count(*) FILTER (WHERE (p.status = 'not_done'::text)))::integer AS not_done,
            (count(*) FILTER (WHERE (p.status = 'no_answer'::text)))::integer AS no_answer,
            (count(*) FILTER (WHERE (p.status <> ALL (ARRAY['done'::text, 'not_done'::text, 'no_answer'::text]))))::integer AS pending,
            max(p.carry_count) AS max_carry
           FROM wr_plan_items p
          GROUP BY p.company_id, p.project_id, p.week_start
        ), t AS (
         SELECT COALESCE(( SELECT archi_thresholds.value
                   FROM archi_thresholds
                  WHERE (archi_thresholds.key = 'plan_exec_red'::text)), (50)::numeric) AS red,
            COALESCE(( SELECT archi_thresholds.value
                   FROM archi_thresholds
                  WHERE (archi_thresholds.key = 'plan_exec_yellow'::text)), (70)::numeric) AS yellow
        )
 SELECT c.project_id,
    c.week_start,
    c.total,
    c.done,
    c.not_done,
    c.no_answer,
    c.pending,
    c.max_carry,
        CASE
            WHEN ((c.pending = 0) AND (c.total > 0)) THEN round(((100.0 * (c.done)::numeric) / (c.total)::numeric))
            ELSE NULL::numeric
        END AS exec_pct,
        CASE
            WHEN ((c.pending = 0) AND (c.total > 0)) THEN
            CASE
                WHEN (round(((100.0 * (c.done)::numeric) / (c.total)::numeric)) < t.red) THEN 'red'::text
                WHEN (round(((100.0 * (c.done)::numeric) / (c.total)::numeric)) < t.yellow) THEN 'yellow'::text
                ELSE 'green'::text
            END
            ELSE NULL::text
        END AS signal,
    c.company_id
   FROM (c
     CROSS JOIN t);
-- Функції archi_snapshot_evm/metrics(p_company…) до зміни: сигнали викликались без p_company (старі однопараметрові версії); достатньо повторити CREATE OR REPLACE з sql/2026-11-03_w1_m4_functions_views.sql.
DROP FUNCTION public.archi_etc_gap_signal(uuid, numeric, numeric);
DROP FUNCTION public.archi_flow_idx_signal(uuid, numeric);
DROP FUNCTION public.archi_idx_signal(uuid, numeric);
DROP FUNCTION public.archi_ready_gap_signal(uuid, numeric);
DROP FUNCTION public.archi_vac_signal(uuid, numeric, numeric);
DROP FUNCTION public.archi_paid_idx_signal(uuid, numeric);
