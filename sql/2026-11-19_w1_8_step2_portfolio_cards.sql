-- W1.8 крок 2 (дизайн docs/W1_8_DESIGN.md §3 п. 2): групи вкладок, hero-класи, лічильники й «потребують уваги» портфеля в SQL. ДОДАВАННЯ: n8n не змінюється, старий код працює як раніше.
-- Порт `Build MiniApp Data` (groupBy по cls.rent/profit/received/etc/cpi; hero-класи; counts; attention) поверх archi_project_signals (крок 1).
-- Договори АН (contract_type='visit') виключені — як `AN: Split Stage Rows`.
-- Форматування текстів і значень (₴, год, %) лишається в n8n; SQL повертає ідентифікатори проєктів і класи кольору.
-- НЕ входить (крок 2б, відкрито): сигнали таблиці портфеля pfc.fcSig, wp.sig, АН-блок (`AN: Attach Block`).
-- Свідомо перенесено як є (не змінено): hero «Виконано і не оплачено» і «Середній розрив до плану» мають 🟡 при > 0 — див. RELEASE_PLAN, знахідка Н-1 (рішення власника потрібне).
-- Пороги — archi_threshold_req (відсутній ключ → помилка). Відкат: sql/2026-11-19_w1_8_step2_portfolio_cards_rollback.sql

CREATE OR REPLACE FUNCTION public.archi_portfolio_cards(p_company uuid, p_asof date DEFAULT ((now() AT TIME ZONE 'Europe/Kyiv'))::date)
 RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public' AS $f$
DECLARE
  sig jsonb := public.archi_project_signals(p_company, p_asof);
  t_rent numeric := archi_threshold_req(p_company,'rent_drop_pp'); t_rent_red numeric := archi_threshold_req(p_company,'rent_drop_pp_red');
  t_pr_y numeric := archi_threshold_req(p_company,'profit_yellow_pct'); t_pr_r numeric := archi_threshold_req(p_company,'profit_red_pct');
  t_cpi_r numeric := archi_threshold_req(p_company,'cpi_red'); t_cpi_y numeric := archi_threshold_req(p_company,'cpi_yellow');
BEGIN
  RETURN (
  WITH s AS (
    SELECT e->>'project_id' AS project_id, e->>'status' AS status, (e->>'reds')::int AS reds, (e->>'yellows')::int AS yellows, e->'cls' AS cls,
           EXISTS (SELECT 1 FROM jsonb_array_elements(e->'signals') x WHERE (x->>'b')::boolean IS TRUE) AS blocked
    FROM jsonb_array_elements(sig) e
  ), m AS (
    SELECT m.project_id, m.profitability_plan_pct AS rp, m.profitability_forecast_pct AS rf, m.profit_plan AS pp, m.profit_forecast AS pf,
           m.actual_cost AS q, m.money_received AS p, m.etc_forecast_total_hours AS etcf, m.cpi_classic_evm AS cpi, m.hours_remaining AS hrem, m.stage_data
    FROM public.project_metrics m WHERE m.company_id = p_company AND COALESCE(m.contract_type,'') <> 'visit'
  ), st AS (
    SELECT m.project_id, bool_or((d.value->>'etc_plan_hours') IS NOT NULL) AS has_stg,
           SUM(CASE WHEN (d.value->>'etc_plan_hours') IS NOT NULL THEN (d.value->>'etc_plan_hours')::numeric - COALESCE((d.value->>'actual_hours_live')::numeric,0) END) AS etc_fact_all
    FROM m LEFT JOIN LATERAL jsonb_each(CASE WHEN jsonb_typeof(m.stage_data::jsonb)='object' THEN m.stage_data::jsonb ELSE '{}'::jsonb END) d ON d.key IN ('МБР','ЕП','П','Р')
    GROUP BY m.project_id
  ), r AS (
    SELECT m.project_id, s.status, s.reds, s.yellows, s.cls, s.blocked, (m.rf IS NULL) AS no_fc, m.rp, m.rf, m.pp, m.pf, m.q, m.p, m.etcf, m.cpi,
           CASE WHEN COALESCE(st.has_stg,false) THEN round(st.etc_fact_all,1) ELSE m.hrem END AS etc_plan
    FROM m JOIN s USING (project_id) LEFT JOIN st USING (project_id)
  ), h AS (
    SELECT COALESCE(avg(rf/100) FILTER (WHERE NOT no_fc),0) AS avg_rf, COALESCE(avg(COALESCE(rp,0)/100) FILTER (WHERE NOT no_fc),0) AS avg_rp,
           COALESCE(sum(COALESCE(pp,0)) FILTER (WHERE NOT no_fc),0) AS tot_pp, COALESCE(sum(COALESCE(pf,0)) FILTER (WHERE NOT no_fc),0) AS tot_pf,
           COALESCE(sum(GREATEST(COALESCE(q,0) - COALESCE(p,0), 0)),0) AS gap_sum,
           COALESCE(avg(COALESCE(etcf,0) - COALESCE(etc_plan,0)) FILTER (WHERE NOT no_fc),0) AS etc_avg,
           COALESCE(avg(cpi),0) AS cpi_avg, count(*) FILTER (WHERE no_fc) AS n_nofc
    FROM r
  ), gc AS (
    SELECT v.k, r.project_id,
           CASE WHEN v.k = 'evm' AND r.cpi IS NULL THEN NULL
                ELSE COALESCE(r.cls->>(CASE v.k WHEN 'volume' THEN 'received' WHEN 'evm' THEN 'cpi' ELSE v.k END), '') END AS c
    FROM r CROSS JOIN (VALUES ('rent'),('profit'),('volume'),('etc'),('evm')) v(k)
  ), g AS (
    SELECT k, jsonb_build_object(
             'critical',  COALESCE(jsonb_agg(project_id ORDER BY project_id) FILTER (WHERE c = 'red'), '[]'::jsonb),
             'attention', COALESCE(jsonb_agg(project_id ORDER BY project_id) FILTER (WHERE c = 'yellow'), '[]'::jsonb),
             'normal',    COALESCE(jsonb_agg(project_id ORDER BY project_id) FILTER (WHERE c IS NOT NULL AND c NOT IN ('red','yellow')), '[]'::jsonb)) AS j
    FROM gc GROUP BY k
  )
  SELECT jsonb_build_object(
    'counts', (SELECT jsonb_build_object('red', count(*) FILTER (WHERE status='red'), 'yellow', count(*) FILTER (WHERE status='yellow'), 'green', count(*) FILTER (WHERE status='green'), 'blocked', count(*) FILTER (WHERE blocked)) FROM r),
    'attention', COALESCE((SELECT jsonb_agg(jsonb_build_object('id',project_id,'status',status,'blocked',blocked,'reds',reds,'yellows',yellows) ORDER BY blocked DESC, reds DESC, yellows DESC, project_id) FROM r WHERE status <> 'green'), '[]'::jsonb),
    'groups', (SELECT jsonb_object_agg(k, j) FROM g),
    'hero', jsonb_build_object(
      'rent',   CASE WHEN h.avg_rf < 0 OR (h.avg_rp - h.avg_rf) * 100 > t_rent_red THEN 'red' WHEN (h.avg_rp - h.avg_rf) * 100 > t_rent THEN 'yellow' ELSE 'green' END,
      'profit', CASE WHEN h.tot_pf < 0 THEN 'red'
                     WHEN h.tot_pp <> 0 AND (h.tot_pp - h.tot_pf) / h.tot_pp * 100 > t_pr_r THEN 'red'
                     WHEN h.tot_pp <> 0 AND (h.tot_pp - h.tot_pf) / h.tot_pp * 100 > t_pr_y THEN 'yellow' ELSE 'green' END,
      'volume', CASE WHEN h.gap_sum > 0 THEN 'yellow' ELSE 'green' END,
      'etc',    CASE WHEN h.etc_avg > 0 THEN 'yellow' ELSE 'green' END,
      'evm',    CASE WHEN round(h.cpi_avg,2) < t_cpi_r THEN 'red' WHEN round(h.cpi_avg,2) < t_cpi_y THEN 'yellow' ELSE 'green' END),
    'hero_values', jsonb_build_object('rent_plan_avg_pct', round(h.avg_rp*100), 'rent_forecast_avg_pct', round(h.avg_rf*100), 'profit_plan', h.tot_pp, 'profit_forecast', h.tot_pf,
                   'volume_gap', h.gap_sum, 'etc_gap_avg', round(h.etc_avg,1), 'cpi_avg', round(h.cpi_avg,2), 'no_forecast', h.n_nofc))
  FROM h);
END $f$;
