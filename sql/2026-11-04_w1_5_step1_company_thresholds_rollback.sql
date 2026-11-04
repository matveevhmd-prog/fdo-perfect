-- Відкат W1.5 крок 1 (виконувати в Supabase SQL Editor: сесійні міграції скасовують DROP).
DROP FUNCTION public.archi_rules(uuid);
DROP FUNCTION public.archi_threshold(uuid, text);
DROP TABLE public.company_thresholds;
