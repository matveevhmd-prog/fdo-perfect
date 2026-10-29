-- ARCHI 29.10.2026 — «Приріст готовності проти витрат команди» (CLAUDE.md п. 11, FORMULAS P-10).
-- Логіка власника: ПМ каже, що минулого звіту готовність 25%, цього 40% → приріст 15 п.п.; команда за цей період витратила
-- N годин × ставка = витрати; вартість приросту = приріст × контракт; результат = вартість − витрати; індекс = вартість ÷ витрати.
-- Джерела: archi_snapshot_history (готовність ПМа по знімках, E-02), time_log × rates (як F-02, лише команда, status = confirmed), project_metrics.contract_amount.
-- Інтервал: (дата попереднього знімка + 6; дата цього знімка + 6]. Відкат: DROP VIEW public.archi_weekly_progress;
CREATE OR REPLACE VIEW public.archi_weekly_progress AS
WITH h AS (
  SELECT project_id, week_start, ready_pm_pct,
         LAG(week_start) OVER w AS prev_week,
         LAG(ready_pm_pct) OVER w AS prev_ready
  FROM public.archi_snapshot_history
  WINDOW w AS (PARTITION BY project_id ORDER BY week_start)
), i AS (
  SELECT h.project_id, h.week_start, h.prev_week, h.prev_ready, h.ready_pm_pct AS ready,
         m.contract_amount, m.real_rate_team_hour AS rate0
  FROM h JOIN public.project_metrics m ON m.project_id = h.project_id
  WHERE h.prev_week IS NOT NULL AND h.ready_pm_pct IS NOT NULL AND h.prev_ready IS NOT NULL
), c AS (
  SELECT i.*, hrs.hours, hrs.cost
  FROM i LEFT JOIN LATERAL (
    SELECT COALESCE(sum(t."години"), 0) AS hours,
           COALESCE(sum(t."години" * COALESCE(r.razom_grn_god, i.rate0)), 0) AS cost
    FROM public.time_log t LEFT JOIN public.rates r ON r.posada = t."виконавець"
    WHERE t.project_id = i.project_id AND t."статус" = 'confirmed'
      AND t."дата" > i.prev_week + 6 AND t."дата" <= i.week_start + 6
  ) hrs ON true
)
SELECT c.project_id, c.week_start, c.prev_week,
       round(c.prev_ready, 1) AS ready_prev_pct,
       round(c.ready, 1) AS ready_pct,
       round(c.ready - c.prev_ready, 1) AS d_ready_pp,
       round(c.hours, 1) AS hours,
       round(c.cost) AS cost_uah,
       c.contract_amount,
       round((c.ready - c.prev_ready) / 100 * c.contract_amount) AS value_uah,
       round((c.ready - c.prev_ready) / 100 * c.contract_amount - c.cost) AS result_uah,
       CASE WHEN c.cost > 0 THEN round(((c.ready - c.prev_ready) / 100 * c.contract_amount) / c.cost, 2) END AS idx,
       public.archi_flow_idx_signal(CASE WHEN c.cost > 0 THEN round(((c.ready - c.prev_ready) / 100 * c.contract_amount) / c.cost, 2) END) AS signal
FROM c;
