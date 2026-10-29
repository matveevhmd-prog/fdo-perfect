-- Вʼю archi_weekly_progress (CLAUDE.md п. 11, FORMULAS P-10). Єдине SQL-джерело «приріст готовності проти витрат команди».
-- Бюджет приросту = max(Δготовність,0) × контракт; за гроші замовника = min(витрати, бюджет); за гроші власника = max(витрати − бюджет, 0).
-- Перевитрата рахується ПО КОЖНОМУ проєкту й тижню окремо (брутто): економія одного проєкту не гасить перевитрату іншого.
-- Відкат: DROP VIEW public.archi_weekly_progress;
CREATE OR REPLACE VIEW public.archi_weekly_progress AS
 WITH h AS (
         SELECT archi_snapshot_history.project_id,
            archi_snapshot_history.week_start,
            archi_snapshot_history.ready_pm_pct,
            lag(archi_snapshot_history.week_start) OVER w AS prev_week,
            lag(archi_snapshot_history.ready_pm_pct) OVER w AS prev_ready
           FROM archi_snapshot_history
          WINDOW w AS (PARTITION BY archi_snapshot_history.project_id ORDER BY archi_snapshot_history.week_start)
        ), i AS (
         SELECT h.project_id, h.week_start, h.prev_week, h.prev_ready, h.ready_pm_pct AS ready, m.contract_amount, m.real_rate_team_hour AS rate0
           FROM h JOIN project_metrics m ON m.project_id = h.project_id
          WHERE h.prev_week IS NOT NULL AND h.ready_pm_pct IS NOT NULL AND h.prev_ready IS NOT NULL
        ), c AS (
         SELECT i.*, hrs.hours, hrs.cost
           FROM i
             LEFT JOIN LATERAL ( SELECT COALESCE(sum(t."години"), 0::numeric) AS hours,
                    COALESCE(sum(t."години" * COALESCE(r.razom_grn_god, i.rate0)), 0::numeric) AS cost
                   FROM time_log t LEFT JOIN rates r ON r.posada = t."виконавець"
                  WHERE t.project_id = i.project_id AND t."статус" = 'confirmed'::text AND t."дата" > (i.prev_week + 6) AND t."дата" <= (i.week_start + 6)) hrs ON true
        )
 SELECT project_id, week_start, prev_week,
    round(prev_ready, 1) AS ready_prev_pct, round(ready, 1) AS ready_pct, round(ready - prev_ready, 1) AS d_ready_pp,
    round(hours, 1) AS hours, round(cost) AS cost_uah, contract_amount,
    round((ready - prev_ready) / 100::numeric * contract_amount) AS value_uah,
    round((ready - prev_ready) / 100::numeric * contract_amount - cost) AS result_uah,
    CASE WHEN cost > 0::numeric THEN round((ready - prev_ready) / 100::numeric * contract_amount / cost, 2) ELSE NULL::numeric END AS idx,
    archi_flow_idx_signal(CASE WHEN cost > 0::numeric THEN round((ready - prev_ready) / 100::numeric * contract_amount / cost, 2) ELSE NULL::numeric END) AS signal,
    round(GREATEST(ready - prev_ready, 0::numeric) / 100::numeric * contract_amount) AS budget_uah,
    round(LEAST(cost, GREATEST(ready - prev_ready, 0::numeric) / 100::numeric * contract_amount)) AS customer_money_uah,
    round(GREATEST(cost - GREATEST(ready - prev_ready, 0::numeric) / 100::numeric * contract_amount, 0::numeric)) AS owner_money_uah
   FROM c;
