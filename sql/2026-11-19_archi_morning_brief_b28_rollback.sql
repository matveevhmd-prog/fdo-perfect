-- Відкат B-28 для рушія брифінгу
DROP FUNCTION public.archi_morning_brief(uuid, date);
ALTER FUNCTION public.archi_morning_brief_pre_b28(uuid, date) RENAME TO archi_morning_brief;
