-- W2.3 / M7: JSON вкладки «Кошторис» (Owner View). Лише читання; дані рахує SQL, інтерфейс лише відображає (п. 31, п. 51).
-- Маскування за роллю (п. 39): гроші бачать лише owner, pm і operator (оператор FDO, п. 22); решта отримує denied.
-- Застосовано трьома міграціями: w2_m7 (створення), w2_m7b (kind проєкту береться з koshtorys_totals), w2_m7c (роль operator); файл — підсумкова редакція.
-- Відкат: sql/2026-11-25_w2_m7_koshtorys_tab_data_rollback.sql
CREATE OR REPLACE FUNCTION public.koshtorys_tab_data(p_company uuid, p_project text, p_role text DEFAULT 'owner')
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $function$
DECLARE
  cur koshtorys_versions%ROWTYPE;
  pm project_metrics%ROWTYPE;
  t jsonb; stages jsonb; vers jsonb; chg jsonb; docs jsonb; adda jsonb; cmts jsonb;
BEGIN
  IF p_role IS NULL OR p_role NOT IN ('owner', 'pm', 'operator') THEN
    RETURN jsonb_build_object('ok', false, 'denied', true, 'reason', 'role', 'project_id', p_project);
  END IF;
  SELECT * INTO cur FROM koshtorys_versions
   WHERE company_id = p_company AND project_id = p_project AND status = 'approved'
   ORDER BY version_no DESC LIMIT 1;
  SELECT * INTO pm FROM project_metrics WHERE company_id = p_company AND project_id = p_project;
  IF NOT FOUND OR cur.id IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'project_id', p_project, 'has_version', false);
  END IF;
  t := koshtorys_totals(p_company, cur.id);

  -- Стадії: собівартість і години з рядків версії; ціна стадії — зі шапки файлу (file_totals.stage_money), якщо є
  SELECT coalesce(jsonb_agg(s ORDER BY s.ord), '[]'::jsonb) INTO stages FROM (
    SELECT x.stage,
           CASE x.stage WHEN 'МБР' THEN 1 WHEN 'ЕП' THEN 2 WHEN 'П' THEN 3 WHEN 'Р' THEN 4 ELSE 5 END AS ord,
           round(sum(x.cost_uah), 2) AS cost,
           coalesce(round(sum(x.cost_uah) FILTER (WHERE x.counterparty IS NULL), 2), 0) AS cost_team,
           coalesce(round(sum(x.cost_uah) FILTER (WHERE x.counterparty IS NOT NULL), 2), 0) AS cost_sub,
           coalesce(sum(x.hours), 0) AS hours,
           (cur.file_totals -> 'stage_money' -> x.stage ->> 'price')::numeric AS price,
           jsonb_agg(jsonb_build_object('section', x.section, 'who', coalesce(x.posada, x.counterparty),
                     'is_sub', x.counterparty IS NOT NULL, 'hours', x.hours, 'cost', x.cost_uah) ORDER BY x.sort_order, x.id) AS rows
      FROM koshtorys_rows x WHERE x.version_id = cur.id GROUP BY x.stage) s
   WHERE s.cost <> 0 OR s.hours <> 0;
  stages := (SELECT coalesce(jsonb_agg((e || jsonb_build_object(
              'profit', CASE WHEN (e ->> 'price') IS NULL THEN NULL ELSE round((e ->> 'price')::numeric - (e ->> 'cost')::numeric, 2) END,
              'rent_pct', CASE WHEN coalesce((e ->> 'price')::numeric, 0) > 0 THEN round(((e ->> 'price')::numeric - (e ->> 'cost')::numeric) / (e ->> 'price')::numeric * 100, 1) ELSE NULL END
            )) - 'ord'), '[]'::jsonb) FROM jsonb_array_elements(stages) e);

  -- Версії з різницею до попередньої
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'version_no', v.version_no, 'status', v.status, 'created_at', v.created_at, 'approved_at', v.approved_at,
           'approved_by', v.approved_by, 'file_url', v.file_url, 'file_sha256', v.file_sha256,
           'delta', CASE WHEN pv.id IS NULL THEN NULL ELSE koshtorys_diff(p_company, pv.id, v.id) -> 'delta' END
         ) ORDER BY v.version_no DESC), '[]'::jsonb) INTO vers
    FROM koshtorys_versions v
    LEFT JOIN LATERAL (SELECT w.id FROM koshtorys_versions w WHERE w.company_id = v.company_id AND w.project_id = v.project_id
                        AND w.version_no < v.version_no AND w.status IN ('approved', 'superseded') ORDER BY w.version_no DESC LIMIT 1) pv ON true
   WHERE v.company_id = p_company AND v.project_id = p_project AND v.status IN ('approved', 'superseded');

  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id, 'from_version_id', c.from_version_id, 'to_version_id', c.to_version_id, 'reason', c.reason, 'funding', c.funding,
           'delta_hours', c.delta_hours, 'delta_cost', c.delta_cost, 'delta_contract', c.delta_contract,
           'addendum_id', c.addendum_id, 'approved_at', c.approved_at) ORDER BY c.created_at DESC), '[]'::jsonb) INTO chg
    FROM koshtorys_changes c WHERE c.company_id = p_company AND c.project_id = p_project;

  SELECT coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'doc_type', d.doc_type, 'title', d.title, 'url', d.url,
           'signed_date', d.signed_date, 'status', d.status, 'addendum_id', d.addendum_id) ORDER BY d.created_at DESC), '[]'::jsonb) INTO docs
    FROM project_documents d WHERE d.company_id = p_company AND d.project_id = p_project;

  SELECT coalesce(jsonb_agg(jsonb_build_object('id', a.id, 'number', a.number, 'agreement_date', a.agreement_date,
           'description', a.description, 'status', a.status, 'file_url', a.file_url) ORDER BY a.agreement_date DESC NULLS LAST, a.id DESC), '[]'::jsonb) INTO adda
    FROM contract_addenda a WHERE a.company_id = p_company AND a.project_id = p_project;

  SELECT coalesce(jsonb_agg(jsonb_build_object('id', k.id, 'version_id', k.version_id, 'body', k.body, 'status', k.status,
           'decision_note', k.decision_note, 'created_at', k.created_at) ORDER BY k.created_at DESC), '[]'::jsonb) INTO cmts
    FROM koshtorys_comments k WHERE k.company_id = p_company AND k.project_id = p_project;

  RETURN jsonb_build_object(
    'ok', true, 'has_version', true, 'project_id', p_project, 'kind', t ->> 'kind', 'version_kind', cur.kind,
    'version', jsonb_build_object('version_no', cur.version_no, 'approved_at', cur.approved_at, 'file_status', cur.file_status,
                                  'file_spreadsheet_id', cur.file_spreadsheet_id, 'file_sheet', cur.file_sheet),
    'data_updated_at', pm.data_updated_at,
    'totals', jsonb_build_object(
      'contract', (t ->> 'contract')::numeric, 'cost', (t ->> 'bac')::numeric,
      'cost_team', (t ->> 'cost_internal')::numeric, 'cost_sub', (t ->> 'cost_sub')::numeric,
      'profit', (t ->> 'profit')::numeric, 'hours', (t ->> 'hours')::numeric,
      'rent_contract_pct', CASE WHEN (t ->> 'contract')::numeric > 0 THEN round((t ->> 'profit')::numeric / (t ->> 'contract')::numeric * 100, 1) END,
      'rent_cost_pct', CASE WHEN (t ->> 'bac')::numeric > 0 THEN round((t ->> 'profit')::numeric / (t ->> 'bac')::numeric * 100, 1) END),
    'visit', CASE WHEN t ->> 'kind' = 'visit' THEN jsonb_build_object('visits', cur.visits_count, 'price', cur.visit_price_uah,
                       'hours', cur.visit_hours, 'rate', cur.visit_rate_uah_hour) END,
    'stages', stages, 'versions', vers, 'changes', chg,
    'documents', jsonb_build_object('contract_url', pm.contract_file_url,
        'koshtorys_spreadsheet_id', pm.koshtorys_spreadsheet_id, 'koshtorys_sheet', pm.koshtorys_sheet, 'items', docs),
    'addenda', adda, 'comments', cmts);
END
$function$;
COMMENT ON FUNCTION public.koshtorys_tab_data(uuid, text, text) IS 'W2.3: JSON вкладки «Кошторис»; лише читання; гроші лише owner/pm (п. 39)';
