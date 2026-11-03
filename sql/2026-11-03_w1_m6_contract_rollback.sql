-- Відкат M6 (виконувати в зворотному порядку: спершу B, потім A).
-- B: повернути DEFAULT = DEMO
ALTER TABLE public.project_metrics     ALTER COLUMN company_id SET DEFAULT '00000000-0000-4000-8000-000000000001';
ALTER TABLE public.time_log            ALTER COLUMN company_id SET DEFAULT '00000000-0000-4000-8000-000000000001';
ALTER TABLE public.money_log           ALTER COLUMN company_id SET DEFAULT '00000000-0000-4000-8000-000000000001';
ALTER TABLE public.payment_schedule    ALTER COLUMN company_id SET DEFAULT '00000000-0000-4000-8000-000000000001';
ALTER TABLE public.meeting_log         ALTER COLUMN company_id SET DEFAULT '00000000-0000-4000-8000-000000000001';
ALTER TABLE public.kp_log              ALTER COLUMN company_id SET DEFAULT '00000000-0000-4000-8000-000000000001';
ALTER TABLE public.rates               ALTER COLUMN company_id SET DEFAULT '00000000-0000-4000-8000-000000000001';
ALTER TABLE public.wr_weekly_snapshots ALTER COLUMN company_id SET DEFAULT '00000000-0000-4000-8000-000000000001';
ALTER TABLE public.wr_plan_items       ALTER COLUMN company_id SET DEFAULT '00000000-0000-4000-8000-000000000001';
ALTER TABLE public.archi_wr_inbox      ALTER COLUMN company_id SET DEFAULT '00000000-0000-4000-8000-000000000001';
ALTER TABLE public.evm_packages        ALTER COLUMN company_id SET DEFAULT '00000000-0000-4000-8000-000000000001';
ALTER TABLE public.evm_package_done    ALTER COLUMN company_id SET DEFAULT '00000000-0000-4000-8000-000000000001';
-- A: старі ключі (можливо лише поки немає двох проєктів з однаковим кодом у різних компаніях)
ALTER TABLE public.rates DROP CONSTRAINT rates_pkey;
CREATE UNIQUE INDEX rates_company_posada_uq ON public.rates (company_id, posada);
ALTER TABLE public.rates ADD CONSTRAINT rates_pkey PRIMARY KEY (posada);
ALTER TABLE public.wr_plan_items DROP CONSTRAINT wr_plan_items_company_project_week_item_key;
CREATE UNIQUE INDEX wr_plan_items_company_project_week_item_uq ON public.wr_plan_items (company_id, project_id, week_start, item_number);
ALTER TABLE public.wr_plan_items ADD CONSTRAINT wr_plan_items_project_id_week_start_item_number_key UNIQUE (project_id, week_start, item_number);
ALTER TABLE public.wr_weekly_snapshots DROP CONSTRAINT wr_weekly_snapshots_company_project_week_key;
CREATE UNIQUE INDEX wr_weekly_snapshots_company_project_week_uq ON public.wr_weekly_snapshots (company_id, project_id, week_start);
ALTER TABLE public.wr_weekly_snapshots ADD CONSTRAINT wr_weekly_snapshots_project_id_week_start_key UNIQUE (project_id, week_start);
ALTER TABLE public.evm_packages DROP CONSTRAINT evm_packages_project_fkey;
ALTER TABLE public.evm_packages DROP CONSTRAINT evm_packages_uq;
CREATE UNIQUE INDEX evm_packages_company_uq ON public.evm_packages (company_id, project_id, baseline_no, package_code);
ALTER TABLE public.evm_packages ADD CONSTRAINT evm_packages_uq UNIQUE (project_id, baseline_no, package_code);
ALTER TABLE public.project_metrics DROP CONSTRAINT project_metrics_pkey;
CREATE UNIQUE INDEX project_metrics_company_project_uq ON public.project_metrics (company_id, project_id);
ALTER TABLE public.project_metrics ADD CONSTRAINT project_metrics_pkey PRIMARY KEY (project_id);
ALTER TABLE public.evm_packages ADD CONSTRAINT evm_packages_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.project_metrics (project_id);
