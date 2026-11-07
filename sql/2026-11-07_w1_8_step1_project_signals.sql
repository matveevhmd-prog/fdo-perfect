-- W1.8 крок 1 (дизайн docs/W1_8_DESIGN.md): кольори й сигнали рівня проєкту в SQL. ДОДАВАННЯ: старий код n8n не змінюється і не вимикається.
-- Порт логіки `Build MiniApp Data` (cls.rent/profit/etc/received/acts/cpi/cpiH, сигнали, стадійні терміни, блокер) з двома свідомими змінами 2А (рішення власника 06.11.2026):
--   1) сигнал «готовність ПМа ≠ годинам» — 'red' (було 'yellow');  2) «оптимістичний прогноз ПМа» — 'green', без надбавки cls.etc (було 'yellow');
--   status/reds/yellows: yellows = лише сигнали 'yellow'.
-- Пороги — archi_threshold(company, key); відсутній ключ → помилка (3А, без запасних значень).
-- Відкат: sql/2026-11-07_w1_8_step1_project_signals_rollback.sql

CREATE OR REPLACE FUNCTION public.archi_threshold_req(p_company uuid, p_key text)
 RETURNS numeric LANGUAGE plpgsql STABLE SET search_path TO 'public' AS $f$
DECLARE v numeric;
BEGIN
  v := public.archi_threshold(p_company, p_key);
  IF v IS NULL THEN RAISE EXCEPTION 'Поріг відсутній у archi_thresholds: %', p_key; END IF;
  RETURN v;
END $f$;

CREATE OR REPLACE FUNCTION public.archi_project_signals(p_company uuid, p_asof date DEFAULT ((now() AT TIME ZONE 'Europe/Kyiv'))::date)
 RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public' AS $f$
DECLARE
  r record; res jsonb := '[]'::jsonb;
  stages text[] := ARRAY['МБР','ЕП','П','Р'];
  s text; d jsonb;
  t_rent numeric := archi_threshold_req(p_company,'rent_drop_pp'); t_rent_red numeric := archi_threshold_req(p_company,'rent_drop_pp_red');
  t_pr_y numeric := archi_threshold_req(p_company,'profit_yellow_pct'); t_pr_r numeric := archi_threshold_req(p_company,'profit_red_pct');
  t_cpi_r numeric := archi_threshold_req(p_company,'cpi_red'); t_cpi_y numeric := archi_threshold_req(p_company,'cpi_yellow');
  t_slip numeric := archi_threshold_req(p_company,'slip_red_days');
  t_un_y numeric := archi_threshold_req(p_company,'unpaid_yellow'); t_un_r numeric := archi_threshold_req(p_company,'unpaid_red');
  t_doc_r numeric := archi_threshold_req(p_company,'doc_prob_red'); t_doc_y numeric := archi_threshold_req(p_company,'doc_prob_yellow');
  t_block numeric := archi_threshold_req(p_company,'block_red_days');
  t_opt_drop numeric := archi_threshold_req(p_company,'opt_etc_drop'); t_opt_ready numeric := archi_threshold_req(p_company,'opt_ready_max');
  noFc boolean; rentF numeric; rentP numeric; profitP numeric; profitF numeric; Q numeric; S_ numeric; P_ numeric; ctr numeric;
  cpi numeric; cpiH numeric; etcF numeric; hoursDone numeric; drop_pp numeric; dev numeric; unpaid numeric;
  cls jsonb; sigs jsonb; stcls jsonb; doccls text; opt jsonb; slips jsonb; ep numeric; ef numeric; rr numeric;
  slip int; col text; reds int; yellows int; status text; bl jsonb; bdays int; bcls text; gp jsonb; gapk text[]; docp numeric;
  rdv numeric; has_rd boolean; txt text;
BEGIN
  FOR r IN
    SELECT m.project_id, m.contract_amount, m.profitability_plan_pct, m.profitability_forecast_pct, m.profit_plan, m.profit_forecast,
           m.acts_amount, m.actual_cost, m.stage_data, m.money_received, m.etc_forecast_total_hours, m.cpi_classic_evm,
           s.week_start AS wr_week, s."готовність_pct" AS wr_readiness, s."залишок_прогноз_по_стадіях" AS wr_etc, s."дедлайн_прогноз_по_стадіях" AS wr_deadlines,
           s."ймовірність_документації" AS wr_doc_prob, s.help_needed AS wr_help, s."блокер" AS wr_blocker,
           regexp_replace(s."розбіжність_готовності"::text, '"note": ?"\s*ПМ\s+підтвердив[:,.]?\s*', '"note": "', 'i')::jsonb AS wr_gap,
           pe.signal AS pe_signal, pe.exec_pct AS pe_pct, pe.done AS pe_done, pe.total AS pe_total,
           v.etc_gap_signal, v.etc_gap_hours, v.etc_gap_pct_bac,
           (SELECT jsonb_object_agg(p."стадія", p."дата_план") FROM public.payment_schedule p WHERE p.company_id = m.company_id AND p.project_id = m.project_id AND p."подія" = 'документація') AS doc_deadlines_plan
    FROM public.project_metrics m
    LEFT JOIN LATERAL (SELECT * FROM public.wr_weekly_snapshots w WHERE w.company_id = m.company_id AND w.project_id = m.project_id ORDER BY w.week_start DESC LIMIT 1) s ON true
    LEFT JOIN public.archi_plan_execution pe ON pe.company_id = m.company_id AND pe.project_id = m.project_id AND pe.week_start = s.week_start
    LEFT JOIN public.archi_report_today v ON v.company_id = m.company_id AND v.project_id = m.project_id
    WHERE m.company_id = p_company ORDER BY m.project_id
  LOOP
    cls := '{}'::jsonb; sigs := '[]'::jsonb; stcls := '{}'::jsonb; doccls := NULL;
    rentF := r.profitability_forecast_pct; noFc := (rentF IS NULL); rentP := r.profitability_plan_pct;
    profitP := r.profit_plan; profitF := r.profit_forecast; Q := r.actual_cost; S_ := r.acts_amount; P_ := r.money_received;
    ctr := COALESCE(r.contract_amount, 0); cpi := r.cpi_classic_evm; etcF := r.etc_forecast_total_hours;
    hoursDone := 0;
    FOREACH s IN ARRAY stages LOOP IF r.stage_data ? s THEN hoursDone := hoursDone + COALESCE((r.stage_data->s->>'actual_hours_live')::numeric, 0); END IF; END LOOP;
    cpiH := CASE WHEN etcF IS NOT NULL AND Q IS NOT NULL AND Q > 0 AND ctr > 0 AND (hoursDone + etcF) > 0 THEN (ctr * hoursDone / (hoursDone + etcF)) / Q END;

    -- рентабельність
    drop_pp := CASE WHEN rentP IS NOT NULL AND NOT noFc THEN floor((rentP - rentF) * 10 + 0.5) / 10 END;
    IF noFc THEN cls := cls || '{"rent":"red"}';
    ELSIF rentF < 0 OR (drop_pp IS NOT NULL AND drop_pp > t_rent_red) THEN
      cls := cls || '{"rent":"red"}'; sigs := sigs || jsonb_build_array(jsonb_build_object('c','red','code','rent','args',jsonb_build_object('loss',rentF<0,'plan',rentP,'forecast',rentF,'drop_pp',drop_pp)));
    ELSIF drop_pp IS NOT NULL AND drop_pp > t_rent THEN
      cls := cls || '{"rent":"yellow"}'; sigs := sigs || jsonb_build_array(jsonb_build_object('c','yellow','code','rent','args',jsonb_build_object('loss',false,'plan',rentP,'forecast',rentF,'drop_pp',drop_pp)));
    ELSE cls := cls || '{"rent":"green"}'; END IF;
    -- прибуток
    dev := CASE WHEN profitF IS NOT NULL AND profitP IS NOT NULL AND profitP <> 0 THEN floor((profitP - profitF) / profitP * 1000 + 0.5) / 10 END;
    col := CASE WHEN noFc THEN 'red' WHEN profitF IS NOT NULL AND profitF < 0 THEN 'red' WHEN dev IS NOT NULL AND dev > t_pr_r THEN 'red' WHEN dev IS NOT NULL AND dev > t_pr_y THEN 'yellow' ELSE 'green' END;
    cls := cls || jsonb_build_object('profit', col);
    -- ETC (колір рахує archi_vac_signal у v.etc_gap_signal)
    IF noFc THEN cls := cls || '{"etc":"red"}';
    ELSIF r.etc_gap_signal IS NOT NULL AND r.etc_gap_signal <> '' THEN
      cls := cls || jsonb_build_object('etc', r.etc_gap_signal);
      IF r.etc_gap_signal IN ('red','yellow') THEN sigs := sigs || jsonb_build_array(jsonb_build_object('c',r.etc_gap_signal,'code','etc_gap','args',jsonb_build_object('etc_forecast',etcF,'gap_hours',r.etc_gap_hours,'gap_pct_bac',r.etc_gap_pct_bac))); END IF;
    END IF;
    -- роботи / акти / гроші
    IF Q IS NOT NULL AND P_ IS NOT NULL AND ctr > 0 THEN
      unpaid := Q - P_;
      IF unpaid > ctr * t_un_r THEN cls := cls || '{"received":"red"}'; sigs := sigs || jsonb_build_array(jsonb_build_object('c','red','code','unpaid','args',jsonb_build_object('amount',unpaid,'pct',floor(unpaid / ctr * 100 + 0.5))));
      ELSIF unpaid > ctr * t_un_y THEN cls := cls || '{"received":"yellow"}'; sigs := sigs || jsonb_build_array(jsonb_build_object('c','yellow','code','unpaid','args',jsonb_build_object('amount',unpaid,'pct',floor(unpaid / ctr * 100 + 0.5))));
      ELSE cls := cls || '{"received":"green"}'; END IF;
    END IF;
    IF Q IS NOT NULL AND S_ IS NOT NULL AND ctr > 0 AND Q - S_ > ctr * t_un_y THEN cls := cls || '{"acts":"yellow"}'; END IF;
    -- ефективність виконання (гроші) і за годинами
    IF cpi IS NOT NULL THEN
      IF floor(cpi * 100 + 0.5) / 100 < t_cpi_r THEN cls := cls || '{"cpi":"red"}'; sigs := sigs || jsonb_build_array(jsonb_build_object('c','red','code','cpi','args',jsonb_build_object('value',cpi)));
      ELSIF floor(cpi * 100 + 0.5) / 100 < t_cpi_y THEN cls := cls || '{"cpi":"yellow"}';
      ELSE cls := cls || '{"cpi":"green"}'; END IF;
    END IF;
    IF cpiH IS NOT NULL THEN
      col := CASE WHEN floor(cpiH * 100 + 0.5) / 100 < t_cpi_r THEN 'red' WHEN floor(cpiH * 100 + 0.5) / 100 < t_cpi_y THEN 'yellow' ELSE 'green' END;
      cls := cls || jsonb_build_object('cpiH', col);
    END IF;
    -- оптимістичний прогноз ПМа (2А: без кольору відхилення, 'green')
    opt := '[]'::jsonb;
    FOREACH s IN ARRAY stages LOOP
      d := r.stage_data->s;
      IF d IS NOT NULL THEN
        ep := (d->>'etc_plan_hours')::numeric; ef := (d->>'etc_forecast_hours')::numeric; rr := (d->>'readiness_forecast')::numeric;
        IF ep IS NOT NULL AND ep > 0 AND ef IS NOT NULL AND rr IS NOT NULL AND rr < t_opt_ready AND ef < ep * (1 - t_opt_drop) THEN
          opt := opt || jsonb_build_array(jsonb_build_object('stage',s,'drop',floor((1 - ef / ep) * 100 + 0.5),'ready',rr));
        END IF;
      END IF;
    END LOOP;
    IF NOT noFc AND jsonb_array_length(opt) > 0 THEN sigs := sigs || jsonb_build_array(jsonb_build_object('c','green','code','optimistic','args',jsonb_build_object('stages',opt))); END IF;

    -- тижневий звіт ПМа
    IF r.wr_week IS NOT NULL THEN
      slips := '[]'::jsonb;
      FOREACH s IN ARRAY stages LOOP
        slip := NULL; col := '';
        IF COALESCE(r.doc_deadlines_plan->>s, '') <> '' AND COALESCE(r.wr_deadlines->>s, '') <> '' THEN
          slip := (left(r.wr_deadlines->>s, 10)::date - left(r.doc_deadlines_plan->>s, 10)::date);
        END IF;
        has_rd := r.wr_readiness ? s; rdv := CASE WHEN has_rd THEN (r.wr_readiness->>s)::numeric END;
        IF slip IS NOT NULL AND (NOT has_rd OR rdv < 100) THEN
          col := CASE WHEN slip > t_slip THEN 'red' WHEN slip > 0 THEN 'yellow' ELSE 'green' END;
          IF col IN ('red','yellow') THEN slips := slips || jsonb_build_array(jsonb_build_object('stage',s,'days',slip,'c',col)); END IF;
        END IF;
        stcls := stcls || jsonb_build_object(s, col);
      END LOOP;
      IF jsonb_array_length(slips) > 0 THEN
        sigs := sigs || jsonb_build_array(jsonb_build_object('c', CASE WHEN EXISTS (SELECT 1 FROM jsonb_array_elements(slips) x WHERE x->>'c'='red') THEN 'red' ELSE 'yellow' END, 'code','slips','args',jsonb_build_object('slips',slips)));
      END IF;
      docp := r.wr_doc_prob;
      doccls := CASE WHEN docp IS NULL THEN '' WHEN docp <= t_doc_r THEN 'red' WHEN docp <= t_doc_y THEN 'yellow' ELSE 'green' END;
      IF doccls = 'red' THEN sigs := sigs || jsonb_build_array(jsonb_build_object('c','red','code','doc_prob','args',jsonb_build_object('prob',docp))); END IF;
      txt := lower(regexp_replace(btrim(COALESCE(r.wr_help,'')), '[.\s]', '', 'g'));
      IF txt NOT IN ('', 'немає', 'непотрібна', 'непотрібно', '(беззауважень)', '(непотрібно)') THEN sigs := sigs || jsonb_build_array(jsonb_build_object('c','yellow','code','help')); END IF;
      IF r.pe_signal IN ('red','yellow') THEN sigs := sigs || jsonb_build_array(jsonb_build_object('c',r.pe_signal,'code','plan_exec','args',jsonb_build_object('pct',r.pe_pct,'done',r.pe_done,'total',r.pe_total))); END IF;
      gp := COALESCE(r.wr_gap, '{}'::jsonb);
      IF jsonb_typeof(gp) = 'object' AND gp <> '{}'::jsonb THEN sigs := sigs || jsonb_build_array(jsonb_build_object('c','red','code','readiness_gap','args',jsonb_build_object('gap',gp))); END IF;
      bl := r.wr_blocker;
      IF bl IS NOT NULL AND jsonb_typeof(bl->'types') = 'array' AND jsonb_array_length(bl->'types') > 0 THEN
        bdays := CASE WHEN COALESCE(bl->>'since','') <> '' THEN (p_asof - left(bl->>'since',10)::date) END;
        bcls := CASE WHEN bdays IS NOT NULL AND bdays >= t_block THEN 'red' ELSE 'yellow' END;
        sigs := sigs || jsonb_build_array(jsonb_build_object('c',bcls,'b',true,'code','blocker','args',jsonb_build_object('days',bdays,'since',bl->>'since','types',bl->'types')));
      END IF;
    ELSE
      IF NOT noFc THEN sigs := sigs || jsonb_build_array(jsonb_build_object('c','yellow','code','no_weekly_report')); END IF;
    END IF;
    IF noFc THEN sigs := sigs || jsonb_build_array(jsonb_build_object('c','red','code','no_forecast')); END IF;

    -- порядок як у n8n: блокер, потім червоні, потім решта (стабільно)
    SELECT COALESCE(jsonb_agg(x.e ORDER BY (CASE WHEN x.e->>'b' = 'true' THEN 0 ELSE 2 END) + (CASE WHEN x.e->>'c' = 'red' THEN 0 ELSE 1 END), x.ord), '[]'::jsonb)
      INTO sigs FROM jsonb_array_elements(sigs) WITH ORDINALITY AS x(e, ord);
    reds := (SELECT count(*) FROM jsonb_array_elements(sigs) x WHERE x->>'c' = 'red');
    yellows := (SELECT count(*) FROM jsonb_array_elements(sigs) x WHERE x->>'c' = 'yellow');
    status := CASE WHEN reds > 0 THEN 'red' WHEN yellows > 0 THEN 'yellow' ELSE 'green' END;
    res := res || jsonb_build_array(jsonb_build_object('project_id', r.project_id, 'status', status, 'reds', reds, 'yellows', yellows, 'cls', cls, 'signals', sigs, 'stage_cls', stcls, 'doc_cls', doccls));
  END LOOP;
  RETURN res;
END $f$;
