-- ARCHI 22.10.2026 (RELEASE_PLAN §83): напрям кольору. Рішення власника: 🟢 = краще за план або за планом, 🟡/🔴 = гірше за план.
-- Застосовано міграцією deviation_colors3_direction_20261022. Лише функції, вʼю не змінювались. Дані не змінюються.

CREATE OR REPLACE FUNCTION public.archi_etc_gap_signal(p_fact numeric, p_forecast numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT CASE
  WHEN p_fact IS NULL OR p_forecast IS NULL THEN NULL
  WHEN p_fact <= 0 THEN CASE WHEN p_forecast > 0 THEN 'red' ELSE 'green' END
  WHEN p_forecast <= p_fact THEN 'green'
  WHEN p_forecast - p_fact > p_fact * COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'etc_red'), 0.10) THEN 'red'
  WHEN p_forecast - p_fact > p_fact * COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'etc_yellow'), 0.05) THEN 'yellow'
  ELSE 'green' END
$$;

CREATE OR REPLACE FUNCTION public.archi_ready_gap_signal(p_pp numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT CASE
  WHEN p_pp IS NULL THEN NULL
  WHEN p_pp >= COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'wr_ready_gap_pp'), 10) THEN 'red'
  ELSE 'green' END
$$;

CREATE OR REPLACE FUNCTION public.archi_idx_signal(p numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT CASE
  WHEN p IS NULL THEN NULL
  WHEN p < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_red'), 0.7) THEN 'red'
  WHEN p < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_yellow'), 0.9) THEN 'yellow'
  ELSE 'green' END
$$;

CREATE OR REPLACE FUNCTION public.archi_paid_idx_signal(p numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT public.archi_flow_idx_signal(p)
$$;
