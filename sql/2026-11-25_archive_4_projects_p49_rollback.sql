-- Відкат п. 49: повернути проєкти 22-24, 24-11, 24-37, 24-52 з компанії ARCHIVE в DEMO.
ALTER TABLE public.project_metrics DISABLE TRIGGER USER;
ALTER TABLE public.money_log DISABLE TRIGGER USER;
ALTER TABLE public.payment_schedule DISABLE TRIGGER USER;
ALTER TABLE public.time_log DISABLE TRIGGER USER;
ALTER TABLE public.wr_weekly_snapshots DISABLE TRIGGER USER;
-- project_metrics і evm_packages — одним оператором: складений ключ (company_id, project_id) перевіряється наприкінці оператора
WITH pm AS (UPDATE public.project_metrics SET company_id='00000000-0000-4000-8000-000000000001' WHERE company_id='00000000-0000-4000-8000-0000000000a1' AND project_id IN ('22-24','24-11','24-37','24-52') RETURNING 1),
     ep AS (UPDATE public.evm_packages SET company_id='00000000-0000-4000-8000-000000000001' WHERE company_id='00000000-0000-4000-8000-0000000000a1' AND project_id IN ('22-24','24-11','24-37','24-52') RETURNING 1)
SELECT (SELECT count(*) FROM pm) AS project_metrics, (SELECT count(*) FROM ep) AS evm_packages;
UPDATE public.time_log SET company_id='00000000-0000-4000-8000-000000000001' WHERE company_id='00000000-0000-4000-8000-0000000000a1' AND project_id IN ('22-24','24-11','24-37','24-52');
UPDATE public.wr_plan_items SET company_id='00000000-0000-4000-8000-000000000001' WHERE company_id='00000000-0000-4000-8000-0000000000a1' AND project_id IN ('22-24','24-11','24-37','24-52');
UPDATE public.wr_weekly_snapshots SET company_id='00000000-0000-4000-8000-000000000001' WHERE company_id='00000000-0000-4000-8000-0000000000a1' AND project_id IN ('22-24','24-11','24-37','24-52');
UPDATE public.payment_schedule SET company_id='00000000-0000-4000-8000-000000000001' WHERE company_id='00000000-0000-4000-8000-0000000000a1' AND project_id IN ('22-24','24-11','24-37','24-52');
UPDATE public.money_log SET company_id='00000000-0000-4000-8000-000000000001' WHERE company_id='00000000-0000-4000-8000-0000000000a1' AND project_id IN ('22-24','24-11','24-37','24-52');
UPDATE public.meeting_log SET company_id='00000000-0000-4000-8000-000000000001' WHERE company_id='00000000-0000-4000-8000-0000000000a1' AND project_id IN ('22-24','24-11','24-37','24-52');
ALTER TABLE public.project_metrics ENABLE TRIGGER USER;
ALTER TABLE public.money_log ENABLE TRIGGER USER;
ALTER TABLE public.payment_schedule ENABLE TRIGGER USER;
ALTER TABLE public.time_log ENABLE TRIGGER USER;
ALTER TABLE public.wr_weekly_snapshots ENABLE TRIGGER USER;
-- Компанію ARCHIVE видаляти лише порожню:
DELETE FROM public.companies c WHERE c.company_id='00000000-0000-4000-8000-0000000000a1' AND NOT EXISTS (SELECT 1 FROM public.project_metrics p WHERE p.company_id=c.company_id);
