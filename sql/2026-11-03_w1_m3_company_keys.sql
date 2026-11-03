-- ARCHI W1 (M3), 03.11.2026: нові складені унікальні індекси ПОРЯД зі старими ключами (розширення). Дизайн: docs/W1_DESIGN.md §5.
-- СТАТУС: підготовлено, НЕ застосовано (оновити після застосування).
-- Старі первинні ключі й UNIQUE лишаються до M6, щоб ON CONFLICT у n8n не зламались до оновлення вузлів (M5).
-- Відкат: sql/2026-11-03_w1_m3_company_keys_rollback.sql
CREATE UNIQUE INDEX project_metrics_company_project_uq        ON public.project_metrics (company_id, project_id);
CREATE UNIQUE INDEX wr_weekly_snapshots_company_project_week_uq ON public.wr_weekly_snapshots (company_id, project_id, week_start);
CREATE UNIQUE INDEX wr_plan_items_company_project_week_item_uq  ON public.wr_plan_items (company_id, project_id, week_start, item_number);
CREATE UNIQUE INDEX evm_packages_company_uq                    ON public.evm_packages (company_id, project_id, baseline_no, package_code);
CREATE UNIQUE INDEX rates_company_posada_uq                    ON public.rates (company_id, posada);
CREATE INDEX idx_time_log_company_project        ON public.time_log (company_id, project_id);
CREATE INDEX idx_money_log_company_project       ON public.money_log (company_id, project_id);
CREATE INDEX idx_payment_schedule_company_project ON public.payment_schedule (company_id, project_id);
CREATE INDEX idx_meeting_log_company_project     ON public.meeting_log (company_id, project_id);
CREATE INDEX idx_archi_wr_inbox_company_sess     ON public.archi_wr_inbox (company_id, session_id, project_id, id);
