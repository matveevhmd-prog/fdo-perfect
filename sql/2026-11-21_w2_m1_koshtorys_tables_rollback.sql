-- Відкат W2 / M1: видаляє лише об'єкти, створені sql/2026-11-21_w2_m1_koshtorys_tables.sql.
DROP TABLE IF EXISTS public.koshtorys_changes;
DROP TABLE IF EXISTS public.koshtorys_rows;
DROP TABLE IF EXISTS public.koshtorys_versions;
DROP TABLE IF EXISTS public.koshtorys_sections;
DROP FUNCTION IF EXISTS public.koshtorys_rows_guard();
DROP FUNCTION IF EXISTS public.koshtorys_versions_guard();
