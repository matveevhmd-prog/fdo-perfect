-- Відкат WD.12 (ємність легенди): повертає значення, виміряні live SQL 26.11.2026 (16 800 / 14, V9 4Б 08.11.2026).
UPDATE public.company_thresholds
   SET value = 16800, note = 'DEMO: 84 000 × 0,2', updated_at = now()
 WHERE company_id = '00000000-0000-4000-8000-000000000001' AND key = 'plan_year_hours';
UPDATE public.company_thresholds
   SET value = 14, note = 'DEMO: 70 × 0,2 (масштаб демо, V9 4Б, 08.11.2026)', updated_at = now()
 WHERE company_id = '00000000-0000-4000-8000-000000000001' AND key = 'plan_year_projects';
