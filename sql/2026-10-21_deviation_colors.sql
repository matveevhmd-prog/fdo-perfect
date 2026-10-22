-- УВАГА 22.10.2026: функції archi_etc_gap_signal / archi_ready_gap_signal / archi_idx_signal тут ЗАСТАРІЛІ (симетричний колір скасовано) — чинні в sql/2026-10-22_color_direction.sql.
-- ARCHI 21.10.2026: колір відхилень від плану (RELEASE_PLAN §81) — єдине обчислення в SQL.
-- Застосовано міграцією deviation_colors_20261021. Дані не змінюються. Без DROP (середовище скасовує такі міграції).
-- Вʼю archi_snapshot_history і archi_report_today у цій міграції = версії з sql/2026-10-21_evm_readiness_chain.sql
-- + дві колонки в кінці: acts_to_ev_signal = archi_flow_idx_signal(acts_to_ev), paid_to_acts_signal = archi_flow_idx_signal(paid_to_acts)
-- (текст вʼю не дублюється тут, щоб не розходитись із evm_readiness_chain; повні тексти — у живій БД: pg_get_viewdef).

INSERT INTO public.archi_thresholds (key, value, note) VALUES
  ('idx_yellow', 0.9, 'Акти ÷ освоєне, Оплата ÷ акти: жовтий нижче (власник 21.10.2026)'),
  ('idx_red', 0.7, 'Акти ÷ освоєне, Оплата ÷ акти: червоний нижче (власник 21.10.2026)'),
  ('wr_ready_gap_pp', 10, 'Weekly Render/чат ПМа: розбіжність готовності, п.п., червоний (власник 21.10.2026)')
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.archi_etc_gap_signal(p_fact numeric, p_forecast numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT CASE
  WHEN p_fact IS NULL OR p_forecast IS NULL THEN NULL
  WHEN p_fact <= 0 THEN CASE WHEN p_forecast > 0 THEN 'red' ELSE 'green' END
  WHEN abs(p_forecast - p_fact) > p_fact * COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'etc_red'), 0.10) THEN 'red'
  WHEN abs(p_forecast - p_fact) > p_fact * COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'etc_yellow'), 0.05) THEN 'yellow'
  ELSE 'green' END
$$;

CREATE OR REPLACE FUNCTION public.archi_ready_gap_signal(p_pp numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT CASE
  WHEN p_pp IS NULL THEN NULL
  WHEN abs(p_pp) >= COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'wr_ready_gap_pp'), 10) THEN 'red'
  ELSE 'green' END
$$;

CREATE OR REPLACE FUNCTION public.archi_flow_idx_signal(p numeric) RETURNS text
LANGUAGE sql STABLE AS $$
SELECT CASE
  WHEN p IS NULL THEN NULL
  WHEN p < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_red'), 0.7) THEN 'red'
  WHEN p < COALESCE((SELECT value FROM public.archi_thresholds WHERE key = 'idx_yellow'), 0.9) THEN 'yellow'
  ELSE 'green' END
$$;
