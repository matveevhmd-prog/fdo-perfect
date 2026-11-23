-- Відкат M3: вимикає тригери незмінності лише в межах транзакції, видаляє версії 1 демо й їх рядки, вмикає тригери.
BEGIN;
ALTER TABLE public.koshtorys_rows DISABLE TRIGGER koshtorys_rows_guard_trg;
ALTER TABLE public.koshtorys_versions DISABLE TRIGGER koshtorys_versions_guard_trg;
DELETE FROM public.koshtorys_rows WHERE company_id = '00000000-0000-4000-8000-000000000001'::uuid AND version_id IN (SELECT id FROM public.koshtorys_versions WHERE company_id = '00000000-0000-4000-8000-000000000001'::uuid AND version_no = 1 AND source = 'demo');
DELETE FROM public.koshtorys_versions WHERE company_id = '00000000-0000-4000-8000-000000000001'::uuid AND version_no = 1 AND source = 'demo';
ALTER TABLE public.koshtorys_rows ENABLE TRIGGER koshtorys_rows_guard_trg;
ALTER TABLE public.koshtorys_versions ENABLE TRIGGER koshtorys_versions_guard_trg;
COMMIT;
