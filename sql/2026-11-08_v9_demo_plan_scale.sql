-- V9 (рішення власника 4Б, 08.11.2026): план року компанії DEMO приведено до масштабу демо (14 проєктів).
-- Перевизначення лише для компанії DEMO (company_thresholds); значення за замовчуванням в archi_thresholds НЕ змінюються.
-- Коефіцієнт 14/70 = 0,2 від значень за замовчуванням — [Припущення], погоджується власником.
INSERT INTO public.company_thresholds (company_id, key, value, note) VALUES
 ('00000000-0000-4000-8000-000000000001','plan_year_projects',14,'DEMO: 70 × 0,2 (масштаб демо, V9 4Б, 08.11.2026)'),
 ('00000000-0000-4000-8000-000000000001','plan_year_hours',16800,'DEMO: 84 000 × 0,2'),
 ('00000000-0000-4000-8000-000000000001','plan_year_profit',1890000,'DEMO: 9 450 000 × 0,2'),
 ('00000000-0000-4000-8000-000000000001','plan_year_contract',9450000,'DEMO: 47 250 000 × 0,2')
ON CONFLICT (company_id, key) DO UPDATE SET value = EXCLUDED.value, note = EXCLUDED.note, updated_at = now();
