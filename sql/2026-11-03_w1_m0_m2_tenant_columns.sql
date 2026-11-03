-- СТАТУС 03.11.2026: підготовлено, НЕ застосовано (apply_migration чекав підтвердження користувача; перевірено live SQL: company_id 0 колонок). Оновити статус після застосування.
-- ARCHI W1 (M0–M2), 03.11.2026. Рішення власника: CLAUDE.md п. 29, 30; дизайн: docs/W1_DESIGN.md.
-- M0: резервні копії таблиць Archi (з RLS, як раніше)
-- M1: companies, user_access (RLS увімкнено, політик немає), компанія DEMO, оператор
-- M2: company_id у таблицях Archi (NOT NULL DEFAULT DEMO — старі вузли n8n продовжують писати; DEFAULT прибирається в M6)
-- Відкат: sql/2026-11-03_w1_m0_m2_tenant_columns_rollback.sql

-- ===== M0 =====
CREATE TABLE public._bak_20261103_project_metrics AS TABLE public.project_metrics;
CREATE TABLE public._bak_20261103_time_log AS TABLE public.time_log;
CREATE TABLE public._bak_20261103_money_log AS TABLE public.money_log;
CREATE TABLE public._bak_20261103_payment_schedule AS TABLE public.payment_schedule;
CREATE TABLE public._bak_20261103_meeting_log AS TABLE public.meeting_log;
CREATE TABLE public._bak_20261103_kp_log AS TABLE public.kp_log;
CREATE TABLE public._bak_20261103_rates AS TABLE public.rates;
CREATE TABLE public._bak_20261103_wr_weekly_snapshots AS TABLE public.wr_weekly_snapshots;
CREATE TABLE public._bak_20261103_wr_plan_items AS TABLE public.wr_plan_items;
CREATE TABLE public._bak_20261103_archi_bot_mode_state AS TABLE public.archi_bot_mode_state;
CREATE TABLE public._bak_20261103_archi_wr_inbox AS TABLE public.archi_wr_inbox;
CREATE TABLE public._bak_20261103_evm_packages AS TABLE public.evm_packages;
CREATE TABLE public._bak_20261103_evm_package_done AS TABLE public.evm_package_done;
CREATE TABLE public._bak_20261103_archi_thresholds AS TABLE public.archi_thresholds;

ALTER TABLE public._bak_20261103_project_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_20261103_time_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_20261103_money_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_20261103_payment_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_20261103_meeting_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_20261103_kp_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_20261103_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_20261103_wr_weekly_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_20261103_wr_plan_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_20261103_archi_bot_mode_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_20261103_archi_wr_inbox ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_20261103_evm_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_20261103_evm_package_done ENABLE ROW LEVEL SECURITY;
ALTER TABLE public._bak_20261103_archi_thresholds ENABLE ROW LEVEL SECURITY;

-- ===== M1 =====
CREATE TABLE public.companies (
  company_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code       text NOT NULL UNIQUE,
  name       text NOT NULL,
  kind       text NOT NULL CHECK (kind IN ('demo', 'client')),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.user_access (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  telegram_user_id bigint NOT NULL,
  company_id       uuid REFERENCES public.companies (company_id),
  role             text NOT NULL CHECK (role IN ('owner', 'pm', 'gap', 'executor', 'operator')),
  created_at       timestamptz NOT NULL DEFAULT now(),
  created_by       text,
  CONSTRAINT user_access_operator_global CHECK ((role = 'operator') = (company_id IS NULL))
);
CREATE UNIQUE INDEX user_access_uq ON public.user_access (telegram_user_id, COALESCE(company_id, '00000000-0000-0000-0000-000000000000'::uuid));
ALTER TABLE public.user_access ENABLE ROW LEVEL SECURITY;

-- Усі наявні дані — демо (CLAUDE.md п. 18, правило сесії 9): одна компанія DEMO з фіксованим id
INSERT INTO public.companies (company_id, code, name, kind)
VALUES ('00000000-0000-4000-8000-000000000001', 'DEMO', 'DEMO (демо-дані)', 'demo');
-- Оператор FDO (власник) бачить усіх клієнтів (CLAUDE.md п. 22)
INSERT INTO public.user_access (telegram_user_id, company_id, role, created_by)
VALUES (304884647, NULL, 'operator', 'migration 2026-11-03');

-- ===== M2 =====
ALTER TABLE public.project_metrics     ADD COLUMN company_id uuid NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001' REFERENCES public.companies (company_id);
ALTER TABLE public.time_log            ADD COLUMN company_id uuid NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001' REFERENCES public.companies (company_id);
ALTER TABLE public.money_log           ADD COLUMN company_id uuid NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001' REFERENCES public.companies (company_id);
ALTER TABLE public.payment_schedule    ADD COLUMN company_id uuid NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001' REFERENCES public.companies (company_id);
ALTER TABLE public.meeting_log         ADD COLUMN company_id uuid NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001' REFERENCES public.companies (company_id);
ALTER TABLE public.kp_log              ADD COLUMN company_id uuid NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001' REFERENCES public.companies (company_id);
ALTER TABLE public.rates               ADD COLUMN company_id uuid NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001' REFERENCES public.companies (company_id);
ALTER TABLE public.wr_weekly_snapshots ADD COLUMN company_id uuid NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001' REFERENCES public.companies (company_id);
ALTER TABLE public.wr_plan_items       ADD COLUMN company_id uuid NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001' REFERENCES public.companies (company_id);
ALTER TABLE public.archi_wr_inbox      ADD COLUMN company_id uuid NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001' REFERENCES public.companies (company_id);
ALTER TABLE public.evm_packages        ADD COLUMN company_id uuid NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001' REFERENCES public.companies (company_id);
ALTER TABLE public.evm_package_done    ADD COLUMN company_id uuid NOT NULL DEFAULT '00000000-0000-4000-8000-000000000001' REFERENCES public.companies (company_id);
-- активна компанія чату (для оператора — обрана); NULL = ще не обрана
ALTER TABLE public.archi_bot_mode_state ADD COLUMN company_id uuid REFERENCES public.companies (company_id);
-- archi_thresholds: company_id додається в W1.5 (пороги на клієнта)

-- ===== D2 (CLAUDE.md п. 30): сироти wr_plan_items (project_id не в project_metrics) → wr_plan_items_legacy =====
CREATE TABLE public.wr_plan_items_legacy AS
  SELECT * FROM public.wr_plan_items w
   WHERE NOT EXISTS (SELECT 1 FROM public.project_metrics m WHERE m.project_id = w.project_id);
ALTER TABLE public.wr_plan_items_legacy ENABLE ROW LEVEL SECURITY;
DELETE FROM public.wr_plan_items w
 WHERE NOT EXISTS (SELECT 1 FROM public.project_metrics m WHERE m.project_id = w.project_id);
