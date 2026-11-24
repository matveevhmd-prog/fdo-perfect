-- Відкат M5a: спершу видалити версії з рядками без посади (M5c, відкат M5c), потім повернути правило рядків; функції — повернути з sql/2026-11-22_w2_m4_koshtorys_functions.sql.
BEGIN;
ALTER TABLE public.koshtorys_rows DROP CONSTRAINT IF EXISTS koshtorys_rows_kind_chk;
ALTER TABLE public.koshtorys_rows ADD CONSTRAINT koshtorys_rows_kind_chk CHECK (
  (kind = 'internal' AND posada IS NOT NULL AND hours IS NOT NULL AND hours >= 0)
  OR (kind = 'subcontract' AND counterparty IS NOT NULL AND hours IS NULL));
COMMIT;
-- Далі виконати sql/2026-11-22_w2_m4_koshtorys_functions.sql (CREATE OR REPLACE повертає попередні тіла функцій).
