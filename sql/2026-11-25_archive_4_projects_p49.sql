-- п. 49 (власник, 25.11.2026): проєкти 22-24, 24-11, 24-37, 24-52 прибрати з системи. НЕ ЗАСТОСОВАНО — лише після «так» власника.
-- Спосіб: перенесення в компанію ARCHIVE (kind='demo': CHECK дозволяє лише 'demo' і 'client'; дані демонстраційні, п. 18). Видалення рядків немає; відкат — sql/2026-11-25_archive_4_projects_p49_rollback.sql.
-- Тригери перерахунку (archi_recalc_*) на час переносу вимкнено, щоб не змінити значення; вони вмикаються тим самим скриптом (транзакція).
-- Запасний вибір компанії в core бере найстарішу за created_at (DEMO), архів-компанія новіша — на вибір не впливає.
-- Репетиція в транзакції зі скасуванням, live SQL 25.11.2026: перенесено 58 time_log, 40 wr_plan_items, 25 wr_weekly_snapshots, 16 payment_schedule, 12 money_log, 2 meeting_log, 4 project_metrics, 20 evm_packages; у DEMO по цих проєктах 0; хеші рядків project_metrics (4 проєкти без company_id; решта проєктів) збігаються до і після.
-- Після: портфель 14 → 10 проєктів; no_report 10, acts_overdue 10, blocked 1, etc_red 5, rent_below 5, no_forecast 0, pm_escalations 5, client_unpaid 3, sub_blocked 1, acts_soon 1.
INSERT INTO public.companies (company_id, code, name, kind) VALUES ('00000000-0000-4000-8000-0000000000a1','ARCHIVE','ARCHIVE (виведені проєкти, п. 49)','demo') ON CONFLICT (company_id) DO NOTHING;
ALTER TABLE public.project_metrics DISABLE TRIGGER USER;
ALTER TABLE public.money_log DISABLE TRIGGER USER;
ALTER TABLE public.payment_schedule DISABLE TRIGGER USER;
ALTER TABLE public.time_log DISABLE TRIGGER USER;
ALTER TABLE public.wr_weekly_snapshots DISABLE TRIGGER USER;
-- project_metrics і evm_packages — одним оператором: складений ключ (company_id, project_id) перевіряється наприкінці оператора
WITH pm AS (UPDATE public.project_metrics SET company_id='00000000-0000-4000-8000-0000000000a1' WHERE company_id='00000000-0000-4000-8000-000000000001' AND project_id IN ('22-24','24-11','24-37','24-52') RETURNING 1),
     ep AS (UPDATE public.evm_packages SET company_id='00000000-0000-4000-8000-0000000000a1' WHERE company_id='00000000-0000-4000-8000-000000000001' AND project_id IN ('22-24','24-11','24-37','24-52') RETURNING 1)
SELECT (SELECT count(*) FROM pm) AS project_metrics, (SELECT count(*) FROM ep) AS evm_packages;
UPDATE public.time_log SET company_id='00000000-0000-4000-8000-0000000000a1' WHERE company_id='00000000-0000-4000-8000-000000000001' AND project_id IN ('22-24','24-11','24-37','24-52');
UPDATE public.wr_plan_items SET company_id='00000000-0000-4000-8000-0000000000a1' WHERE company_id='00000000-0000-4000-8000-000000000001' AND project_id IN ('22-24','24-11','24-37','24-52');
UPDATE public.wr_weekly_snapshots SET company_id='00000000-0000-4000-8000-0000000000a1' WHERE company_id='00000000-0000-4000-8000-000000000001' AND project_id IN ('22-24','24-11','24-37','24-52');
UPDATE public.payment_schedule SET company_id='00000000-0000-4000-8000-0000000000a1' WHERE company_id='00000000-0000-4000-8000-000000000001' AND project_id IN ('22-24','24-11','24-37','24-52');
UPDATE public.money_log SET company_id='00000000-0000-4000-8000-0000000000a1' WHERE company_id='00000000-0000-4000-8000-000000000001' AND project_id IN ('22-24','24-11','24-37','24-52');
UPDATE public.meeting_log SET company_id='00000000-0000-4000-8000-0000000000a1' WHERE company_id='00000000-0000-4000-8000-000000000001' AND project_id IN ('22-24','24-11','24-37','24-52');
ALTER TABLE public.project_metrics ENABLE TRIGGER USER;
ALTER TABLE public.money_log ENABLE TRIGGER USER;
ALTER TABLE public.payment_schedule ENABLE TRIGGER USER;
ALTER TABLE public.time_log ENABLE TRIGGER USER;
ALTER TABLE public.wr_weekly_snapshots ENABLE TRIGGER USER;
