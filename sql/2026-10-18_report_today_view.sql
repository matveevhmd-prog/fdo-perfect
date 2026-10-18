-- ARCHI 18.10.2026: єдине місце обчислення показників «Сьогодні» звіту (пп. 1,2,3,9 форми, WEEKLY_REPORT_FORM §2).
-- Раніше №2 (план) і №3 (F-22) рахував n8n-вузол Build Weekly Render Data (друге місце обчислення поза SQL, борг TECH_SPEC §2.1).
-- Тепер їх читають і Weekly Render, і чат ПМа (WR: Render Report) — звідси.
-- Відкат: DROP VIEW public.archi_report_today;
create or replace view public.archi_report_today as
select
  m.project_id,
  m.data_updated_at,
  m.profitability_plan_pct                                                  as rent_plan_pct,        -- F-15 план
  m.profitability_forecast_pct                                              as rent_forecast_pct,    -- F-15 прогноз (NULL, якщо ПМ не дав ETC по стадії)
  m.planned_hours,
  m.actual_hours,
  (select sum(e.value::numeric) from jsonb_each_text(m.etc_plan_by_stage) e
    where e.key in ('МБР','ЕП','П','Р'))                                    as etc_plan_hours,       -- F-23 ETC_план (Σ 4 стадій)
  case when m.planned_hours is not null and m.actual_hours is not null
       then round((m.planned_hours - m.actual_hours)::numeric, 1) end       as etc_fact_hours,       -- F-23 ETC_факт (без обмеження знизу)
  m.etc_forecast_total_hours                                                as etc_forecast_hours,   -- F-06
  case when coalesce(m.planned_hours,0) > 0 and m.actual_hours is not null and m.etc_forecast_total_hours is not null
       then round(((m.actual_hours + m.etc_forecast_total_hours) / m.planned_hours * 1000)::numeric) / 10
       end                                                                  as eac_hours_pct,        -- F-22 (не готовність; >100% = перевищення)
  m.cpi_classic_evm                                                         as cpi,                  -- F-10
  m.nearest_act_date                                                        as act_date,             -- F-18
  m.nearest_act_probability                                                 as act_prob,
  m.nearest_doc_deadline                                                    as doc_date,             -- F-19
  m.doc_issuance_probability                                                as doc_prob              -- F-20
from public.project_metrics m;
comment on view public.archi_report_today is 'Показники колонки «Сьогодні» звіту (пп. 1,2,3,9 + 7,8): єдине обчислення; читають Weekly Render і чат ПМа';
