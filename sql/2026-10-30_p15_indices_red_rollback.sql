-- Відкат 2026-10-30_p15_indices_red.sql
UPDATE public.archi_thresholds SET value = 0.7  WHERE key = 'idx_red';
UPDATE public.archi_thresholds SET value = 0.9  WHERE key = 'idx_yellow';
UPDATE public.archi_thresholds SET value = 0.85 WHERE key = 'cpi_red';
UPDATE public.archi_thresholds SET value = 0.95 WHERE key = 'cpi_yellow';
UPDATE public.archi_thresholds SET value = 50   WHERE key = 'plan_exec_red';
UPDATE public.archi_thresholds SET value = 70   WHERE key = 'plan_exec_yellow';
UPDATE public.archi_thresholds SET value = 10   WHERE key = 'wr_ready_gap_pp';

CREATE OR REPLACE FUNCTION public.archi_idx_signal(p numeric)
 RETURNS text LANGUAGE sql STABLE AS $function$
SELECT CASE
  WHEN p IS NULL THEN NULL
  WHEN p < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_red'), 0.7) THEN 'red'
  WHEN p < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_yellow'), 0.9) THEN 'yellow'
  ELSE 'green' END
$function$;

CREATE OR REPLACE FUNCTION public.archi_flow_idx_signal(p numeric)
 RETURNS text LANGUAGE sql STABLE AS $function$
SELECT CASE
  WHEN p IS NULL THEN NULL
  WHEN p < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_red'), 0.7) THEN 'red'
  WHEN p < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_yellow'), 0.9) THEN 'yellow'
  ELSE 'green' END
$function$;

CREATE OR REPLACE FUNCTION public.archi_ready_gap_signal(p_pp numeric)
 RETURNS text LANGUAGE sql STABLE AS $function$
SELECT CASE
  WHEN p_pp IS NULL THEN NULL
  WHEN abs(p_pp) >= COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'wr_ready_gap_pp'), 10) THEN 'red'
  ELSE 'green' END
$function$;
