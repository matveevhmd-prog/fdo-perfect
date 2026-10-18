-- ARCHI 18.10.2026: контур «план → виконання» (рішення власника: варіант А, пороги 70/50).
-- 1) Перенос без втрат: звідки пункт і скільки разів перенесено. 2) Показник виконання плану (PX-01) — вʼю archi_plan_execution.
-- Відкат: DROP VIEW public.archi_plan_execution; ALTER TABLE public.wr_plan_items DROP COLUMN origin_week, DROP COLUMN carry_count;
--         DELETE FROM public.archi_thresholds WHERE key IN ('plan_exec_red','plan_exec_yellow');
ALTER TABLE public.wr_plan_items ADD COLUMN IF NOT EXISTS origin_week date;
ALTER TABLE public.wr_plan_items ADD COLUMN IF NOT EXISTS carry_count integer NOT NULL DEFAULT 0;
-- Бекфіл: історію переносів до 18.10.2026 не відновлюємо (невідома) — origin_week = тиждень самого рядка, carry_count = 0.
UPDATE public.wr_plan_items SET origin_week = week_start WHERE origin_week IS NULL;

INSERT INTO public.archi_thresholds (key, value, note) VALUES
 ('plan_exec_red', 50, 'виконання плану тижня нижче цього % — червоний (власник 18.10.2026)'),
 ('plan_exec_yellow', 70, 'виконання плану тижня нижче цього % — жовтий (власник 18.10.2026)')
ON CONFLICT (key) DO NOTHING;

-- PX-01: виконання плану тижня week_start = done / усі пункти; exec_pct = NULL, поки є непідтверджені (pending).
CREATE OR REPLACE VIEW public.archi_plan_execution AS
WITH c AS (
  SELECT p.project_id, p.week_start,
         count(*)::int AS total,
         count(*) FILTER (WHERE p.status = 'done')::int AS done,
         count(*) FILTER (WHERE p.status = 'not_done')::int AS not_done,
         count(*) FILTER (WHERE p.status = 'no_answer')::int AS no_answer,
         count(*) FILTER (WHERE p.status NOT IN ('done','not_done','no_answer'))::int AS pending,
         max(p.carry_count)::int AS max_carry
  FROM public.wr_plan_items p GROUP BY p.project_id, p.week_start
), t AS (
  SELECT coalesce((SELECT value FROM public.archi_thresholds WHERE key = 'plan_exec_red'), 50)    AS red,
         coalesce((SELECT value FROM public.archi_thresholds WHERE key = 'plan_exec_yellow'), 70) AS yellow
)
SELECT c.*,
       CASE WHEN c.pending = 0 AND c.total > 0 THEN round(100.0 * c.done / c.total) END AS exec_pct,
       CASE WHEN c.pending = 0 AND c.total > 0 THEN
              CASE WHEN round(100.0 * c.done / c.total) < t.red THEN 'red'
                   WHEN round(100.0 * c.done / c.total) < t.yellow THEN 'yellow' ELSE 'green' END END AS signal
FROM c CROSS JOIN t;
COMMENT ON VIEW public.archi_plan_execution IS 'PX-01: виконання плану тижня (week_start = тиждень, на який складено план; статуси підтверджує ПМ у звіті цього ж тижня)';
