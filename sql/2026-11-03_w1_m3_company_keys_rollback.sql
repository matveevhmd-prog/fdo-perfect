-- Відкат M3
DROP INDEX IF EXISTS public.project_metrics_company_project_uq;
DROP INDEX IF EXISTS public.wr_weekly_snapshots_company_project_week_uq;
DROP INDEX IF EXISTS public.wr_plan_items_company_project_week_item_uq;
DROP INDEX IF EXISTS public.evm_packages_company_uq;
DROP INDEX IF EXISTS public.rates_company_posada_uq;
DROP INDEX IF EXISTS public.idx_time_log_company_project;
DROP INDEX IF EXISTS public.idx_money_log_company_project;
DROP INDEX IF EXISTS public.idx_payment_schedule_company_project;
DROP INDEX IF EXISTS public.idx_meeting_log_company_project;
DROP INDEX IF EXISTS public.idx_archi_wr_inbox_company_sess;
