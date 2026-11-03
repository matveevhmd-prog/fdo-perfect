-- Відкат sql/2026-11-03_w1_m0_m2_tenant_columns.sql (виконувати в зворотному порядку).
-- Увага: виконувати до M3–M6; після них спершу відкотити їх відповідні файли.

-- D2: повернути сироти з wr_plan_items_legacy (id збережені)
INSERT INTO public.wr_plan_items (id, project_id, week_start, item_number, item_text, status, created_at, origin_week, carry_count)
SELECT id, project_id, week_start, item_number, item_text, status, created_at, origin_week, carry_count FROM public.wr_plan_items_legacy;
DROP TABLE public.wr_plan_items_legacy;

-- M2
ALTER TABLE public.archi_bot_mode_state DROP COLUMN company_id;
ALTER TABLE public.evm_package_done    DROP COLUMN company_id;
ALTER TABLE public.evm_packages        DROP COLUMN company_id;
ALTER TABLE public.archi_wr_inbox      DROP COLUMN company_id;
ALTER TABLE public.wr_plan_items       DROP COLUMN company_id;
ALTER TABLE public.wr_weekly_snapshots DROP COLUMN company_id;
ALTER TABLE public.rates               DROP COLUMN company_id;
ALTER TABLE public.kp_log              DROP COLUMN company_id;
ALTER TABLE public.meeting_log         DROP COLUMN company_id;
ALTER TABLE public.payment_schedule    DROP COLUMN company_id;
ALTER TABLE public.money_log           DROP COLUMN company_id;
ALTER TABLE public.time_log            DROP COLUMN company_id;
ALTER TABLE public.project_metrics     DROP COLUMN company_id;

-- M1
DROP TABLE public.user_access;
DROP TABLE public.companies;

-- M0 (копії можна лишити; видалити за потреби)
-- DROP TABLE public._bak_20261103_project_metrics, public._bak_20261103_time_log, public._bak_20261103_money_log,
--   public._bak_20261103_payment_schedule, public._bak_20261103_meeting_log, public._bak_20261103_kp_log,
--   public._bak_20261103_rates, public._bak_20261103_wr_weekly_snapshots, public._bak_20261103_wr_plan_items,
--   public._bak_20261103_archi_bot_mode_state, public._bak_20261103_archi_wr_inbox, public._bak_20261103_evm_packages,
--   public._bak_20261103_evm_package_done, public._bak_20261103_archi_thresholds;
