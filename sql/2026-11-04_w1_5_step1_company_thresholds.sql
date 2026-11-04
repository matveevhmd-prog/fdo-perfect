-- СТАТУС 04.11.2026: ЗАСТОСОВАНО (міграція w1_5_step1_company_thresholds). Перевірка live SQL: archi_rules(DEMO) = читання archi_thresholds (31 ключ, jsonb рівні), перевизначень 0.
-- ARCHI W1.5, крок 1 (04.11.2026). Рішення: CLAUDE.md п. 30 D4, п. 31; дизайн: docs/W1_DESIGN.md §9.
-- Додає перевизначення порогів по компанії. Нічого не змінює для наявних споживачів (archi_thresholds лишається значеннями за замовчуванням).
-- Відкат: sql/2026-11-04_w1_5_step1_company_thresholds_rollback.sql

CREATE TABLE public.company_thresholds (
  company_id uuid NOT NULL REFERENCES public.companies (company_id),
  key        text NOT NULL REFERENCES public.archi_thresholds (key),
  value      numeric NOT NULL,
  note       text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (company_id, key)
);
ALTER TABLE public.company_thresholds ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION public.archi_threshold(p_company uuid, p_key text) RETURNS numeric
LANGUAGE sql STABLE SET search_path = public AS $$
  SELECT COALESCE(
    (SELECT c.value FROM public.company_thresholds c WHERE c.company_id = p_company AND c.key = p_key),
    (SELECT t.value FROM public.archi_thresholds t WHERE t.key = p_key))
$$;

CREATE FUNCTION public.archi_rules(p_company uuid) RETURNS json
LANGUAGE sql STABLE SET search_path = public AS $$
  SELECT json_object_agg(t.key, COALESCE(c.value, t.value))
  FROM public.archi_thresholds t
  LEFT JOIN public.company_thresholds c ON c.company_id = p_company AND c.key = t.key
$$;
