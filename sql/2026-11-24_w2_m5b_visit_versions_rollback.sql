-- Відкат M5b: тимчасово вимикає захист затверджених версій і рядків; видаляє версії нагляду DEMO.
BEGIN;
ALTER TABLE public.koshtorys_rows DISABLE TRIGGER koshtorys_rows_guard_trg;
ALTER TABLE public.koshtorys_versions DISABLE TRIGGER koshtorys_versions_guard_trg;
DELETE FROM public.koshtorys_rows WHERE version_id IN (SELECT id FROM public.koshtorys_versions WHERE company_id = '00000000-0000-4000-8000-000000000001'::uuid AND version_no = 1 AND visits_count IS NOT NULL);
DELETE FROM public.koshtorys_versions WHERE company_id = '00000000-0000-4000-8000-000000000001'::uuid AND version_no = 1 AND visits_count IS NOT NULL;
ALTER TABLE public.koshtorys_rows ENABLE TRIGGER koshtorys_rows_guard_trg;
ALTER TABLE public.koshtorys_versions ENABLE TRIGGER koshtorys_versions_guard_trg;
COMMIT;
