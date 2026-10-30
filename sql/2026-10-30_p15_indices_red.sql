-- п. 15 (власник, 29–30.10.2026): «будь-яке гірше за план — 🔴», поширено на індекси (план = 1,00),
-- виконання плану тижня (план = 100%) і узгодженість прогнозу (знак «за прогнозом − ПМа», мінус = 🔴).
-- Жовтого для відхилень від плану немає. Порівняння — з округленим значенням (як на екрані): «1,00» ніколи не 🔴.
-- Відкат: sql/2026-10-30_p15_indices_red_rollback.sql
UPDATE public.archi_thresholds SET value = 1   WHERE key IN ('idx_red','idx_yellow','cpi_red','cpi_yellow');
UPDATE public.archi_thresholds SET value = 100 WHERE key IN ('plan_exec_red','plan_exec_yellow');
UPDATE public.archi_thresholds SET value = 0   WHERE key = 'wr_ready_gap_pp';

CREATE OR REPLACE FUNCTION public.archi_idx_signal(p numeric)
 RETURNS text LANGUAGE sql STABLE AS $function$
SELECT CASE
  WHEN p IS NULL THEN NULL
  WHEN round(p, 2) < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_red'), 1) THEN 'red'
  WHEN round(p, 2) < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_yellow'), 1) THEN 'yellow'
  ELSE 'green' END
$function$;

CREATE OR REPLACE FUNCTION public.archi_flow_idx_signal(p numeric)
 RETURNS text LANGUAGE sql STABLE AS $function$
SELECT CASE
  WHEN p IS NULL THEN NULL
  WHEN round(p, 2) < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_red'), 1) THEN 'red'
  WHEN round(p, 2) < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_yellow'), 1) THEN 'yellow'
  ELSE 'green' END
$function$;

-- p_pp = Готовність ПМа − Готовність за прогнозом (збережене значення, знак не змінюється).
-- На екрані показується зі знаком «за прогнозом − ПМа» (= −p_pp). Додатне p_pp = прогноз відстає = 🔴.
CREATE OR REPLACE FUNCTION public.archi_ready_gap_signal(p_pp numeric)
 RETURNS text LANGUAGE sql STABLE AS $function$
SELECT CASE
  WHEN p_pp IS NULL THEN NULL
  WHEN round(p_pp, 1) > COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'wr_ready_gap_pp'), 0) THEN 'red'
  ELSE 'green' END
$function$;
