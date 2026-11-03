-- СТАТУС 03.11.2026: частини A і B ЗАСТОСОВАНО (міграції w1_m6a_composite_keys, w1_m6b_drop_company_default).
-- ARCHI W1 M6 (contract), 03.11.2026. Рішення: CLAUDE.md п. 27, 29, 30; дизайн: docs/W1_DESIGN.md §5.
-- Частина A: ключі (project_id більше не унікальний сам по собі, ключ = (company_id, project_id))
-- Частина B: прибрати DEFAULT company_id (запис без company_id тепер падає)
-- Не зроблено свідомо: композитні FK time_log/money_log/payment_schedule/meeting_log/wr_plan_items → project_metrics
--   (у даних є рядки з project_id поза project_metrics; D2 — сироти wr_plan_items — чекає підтвердження в SQL Editor).
-- Відкат: sql/2026-11-03_w1_m6_contract_rollback.sql

-- ===== Частина A =====
ALTER TABLE public.evm_packages DROP CONSTRAINT evm_packages_project_id_fkey;
ALTER TABLE public.evm_packages DROP CONSTRAINT evm_packages_uq;
ALTER TABLE public.project_metrics DROP CONSTRAINT project_metrics_pkey;
ALTER TABLE public.project_metrics ADD CONSTRAINT project_metrics_pkey PRIMARY KEY USING INDEX project_metrics_company_project_uq;
ALTER TABLE public.evm_packages ADD CONSTRAINT evm_packages_uq UNIQUE USING INDEX evm_packages_company_uq;
ALTER TABLE public.evm_packages ADD CONSTRAINT evm_packages_project_fkey FOREIGN KEY (company_id, project_id) REFERENCES public.project_metrics (company_id, project_id);
ALTER TABLE public.wr_weekly_snapshots DROP CONSTRAINT wr_weekly_snapshots_project_id_week_start_key;
ALTER TABLE public.wr_weekly_snapshots ADD CONSTRAINT wr_weekly_snapshots_company_project_week_key UNIQUE USING INDEX wr_weekly_snapshots_company_project_week_uq;
ALTER TABLE public.wr_plan_items DROP CONSTRAINT wr_plan_items_project_id_week_start_item_number_key;
ALTER TABLE public.wr_plan_items ADD CONSTRAINT wr_plan_items_company_project_week_item_key UNIQUE USING INDEX wr_plan_items_company_project_week_item_uq;
ALTER TABLE public.rates DROP CONSTRAINT rates_pkey;
ALTER TABLE public.rates ADD CONSTRAINT rates_pkey PRIMARY KEY USING INDEX rates_company_posada_uq;

-- ===== Частина B =====
ALTER TABLE public.project_metrics     ALTER COLUMN company_id DROP DEFAULT;
ALTER TABLE public.time_log            ALTER COLUMN company_id DROP DEFAULT;
ALTER TABLE public.money_log           ALTER COLUMN company_id DROP DEFAULT;
ALTER TABLE public.payment_schedule    ALTER COLUMN company_id DROP DEFAULT;
ALTER TABLE public.meeting_log         ALTER COLUMN company_id DROP DEFAULT;
ALTER TABLE public.kp_log              ALTER COLUMN company_id DROP DEFAULT;
ALTER TABLE public.rates               ALTER COLUMN company_id DROP DEFAULT;
ALTER TABLE public.wr_weekly_snapshots ALTER COLUMN company_id DROP DEFAULT;
ALTER TABLE public.wr_plan_items       ALTER COLUMN company_id DROP DEFAULT;
ALTER TABLE public.archi_wr_inbox      ALTER COLUMN company_id DROP DEFAULT;
ALTER TABLE public.evm_packages        ALTER COLUMN company_id DROP DEFAULT;
ALTER TABLE public.evm_package_done    ALTER COLUMN company_id DROP DEFAULT;
