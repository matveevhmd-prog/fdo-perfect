-- W2 M6 (25.11.2026): імпорт Кошториса з файлу через чернетку версії (п. 41; SWOT K6sm, пріоритет 1).
-- Вузол K6sm читає файл, парсить рядки в JSON і викликає koshtorys_ingest_draft (перегляд) та koshtorys_commit_draft (затвердження).
-- Формул плану тут немає: підсумки рахують koshtorys_totals/preview (M4, M5a), план пише koshtorys_approve.

-- 1. Знімок файлу в версії: підсумки файлу, графік оплат (D-1), адреса листа, статус T2, попередження.
ALTER TABLE public.koshtorys_versions
  ADD COLUMN IF NOT EXISTS file_totals jsonb,
  ADD COLUMN IF NOT EXISTS file_schedule jsonb,
  ADD COLUMN IF NOT EXISTS file_spreadsheet_id text,
  ADD COLUMN IF NOT EXISTS file_sheet text,
  ADD COLUMN IF NOT EXISTS file_status text;

-- 2. Охорона: у затвердженої версії знімок файлу теж не змінюється.
CREATE OR REPLACE FUNCTION public.koshtorys_versions_guard() RETURNS trigger LANGUAGE plpgsql AS $g$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'draft' THEN RAISE EXCEPTION 'koshtorys_versions: версію зі статусом % видаляти не можна', OLD.status; END IF;
    RETURN OLD;
  END IF;
  IF OLD.status = 'draft' AND NEW.status IN ('draft','approved') THEN RETURN NEW; END IF;
  IF OLD.status = 'approved' AND NEW.status = 'superseded' AND
     (OLD.company_id, OLD.project_id, OLD.version_no, OLD.kind, OLD.contract_amount, OLD.source, OLD.approved_by, OLD.approved_at, OLD.file_url, OLD.file_sha256, OLD.file_totals, OLD.file_schedule)
     IS NOT DISTINCT FROM (NEW.company_id, NEW.project_id, NEW.version_no, NEW.kind, NEW.contract_amount, NEW.source, NEW.approved_by, NEW.approved_at, NEW.file_url, NEW.file_sha256, NEW.file_totals, NEW.file_schedule)
  THEN RETURN NEW; END IF;
  IF OLD.status = NEW.status AND OLD.status <> 'draft' AND
     (OLD.contract_amount, OLD.version_no, OLD.approved_at, OLD.file_url, OLD.file_sha256, OLD.file_totals, OLD.file_schedule)
     IS NOT DISTINCT FROM (NEW.contract_amount, NEW.version_no, NEW.approved_at, NEW.file_url, NEW.file_sha256, NEW.file_totals, NEW.file_schedule)
  THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'koshtorys_versions: недозволена зміна (% → %)', OLD.status, NEW.status;
END $g$;

-- 3. Перегляд: чернетка версії з рядків файлу.
-- p_payload: {kind:'stages'|'visit', spreadsheet_id, sheet, status, rate, totals:{hours,cost_internal,cost_sub,contract,hours_by_stage},
--   rows:[{stage,section,executor,hours,cost,sub,src_row}], schedule:[...], visit:{visits,price,hours,rate,cost,contract}, contract}
CREATE OR REPLACE FUNCTION public.koshtorys_ingest_draft(p_company uuid, p_project text, p_payload jsonb, p_uploaded_by bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SET search_path = public AS $f$
DECLARE ctype text; k text; sha text; vid bigint; vno int; vkind text; cur_id bigint; cur_sha text; reused boolean := false;
        pv jsonb; df jsonb; warns jsonb := '[]'::jsonb; n int; vis jsonb; furl text;
BEGIN
  SELECT coalesce(contract_type, 'stages') INTO ctype FROM project_metrics WHERE company_id = p_company AND project_id = p_project;
  IF NOT FOUND THEN RAISE EXCEPTION 'koshtorys_ingest: проєкт % компанії % не знайдено в project_metrics (створення проєкту з Кошториса — окремий вузол, п. 41 «відкрито»)', p_project, p_company; END IF;
  k := p_payload ->> 'kind';
  IF k IS DISTINCT FROM ctype THEN RAISE EXCEPTION 'koshtorys_ingest: файл типу %, а проєкт типу %', k, ctype; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_company::text || '/' || p_project, 0));
  sha := encode(sha256(convert_to(p_payload::text, 'UTF8')), 'hex');
  furl := CASE WHEN p_payload ->> 'spreadsheet_id' IS NOT NULL THEN 'https://docs.google.com/spreadsheets/d/' || (p_payload ->> 'spreadsheet_id') END;

  SELECT id, file_sha256 INTO cur_id, cur_sha FROM koshtorys_versions WHERE company_id = p_company AND project_id = p_project AND status = 'approved';
  IF cur_sha = sha THEN
    RETURN jsonb_build_object('same_as_current', true, 'project_id', p_project, 'version_id', cur_id, 'sha256', sha, 'ok', true,
                              'message', 'Файл збігається з чинною затвердженою версією, змін немає');
  END IF;

  SELECT id INTO vid FROM koshtorys_versions WHERE company_id = p_company AND project_id = p_project AND status = 'draft' AND file_sha256 = sha;
  IF FOUND THEN
    reused := true;
  ELSE
    DELETE FROM koshtorys_rows WHERE company_id = p_company AND project_id = p_project
       AND version_id IN (SELECT id FROM koshtorys_versions WHERE company_id = p_company AND project_id = p_project AND status = 'draft');
    DELETE FROM koshtorys_versions WHERE company_id = p_company AND project_id = p_project AND status = 'draft';
    SELECT coalesce(max(version_no), 0) + 1 INTO vno FROM koshtorys_versions WHERE company_id = p_company AND project_id = p_project;
    vkind := CASE WHEN vno = 1 THEN 'initial' ELSE 'change' END;
    vis := p_payload -> 'visit';
    IF k = 'visit' THEN
      INSERT INTO koshtorys_versions (company_id, project_id, version_no, status, kind, contract_amount, source, source_kind, note, file_url, file_sha256, uploaded_by, created_by,
                                      visits_count, visit_price_uah, visit_hours, visit_rate_uah_hour, file_totals, file_schedule, file_spreadsheet_id, file_sheet, file_status)
      VALUES (p_company, p_project, vno, 'draft', vkind, (vis ->> 'contract')::numeric, 'import_xlsx', 'drive_api', 'Імпорт листа нагляду', furl, sha, p_uploaded_by, p_uploaded_by,
              (vis ->> 'visits')::int, (vis ->> 'price')::numeric, (vis ->> 'hours')::numeric, (vis ->> 'rate')::numeric, p_payload -> 'totals', NULL,
              p_payload ->> 'spreadsheet_id', p_payload ->> 'sheet', p_payload ->> 'status')
      RETURNING id INTO vid;
      INSERT INTO koshtorys_rows (version_id, company_id, project_id, stage, section, kind, posada, hours, rate_uah_hour, cost_uah, sort_order)
      SELECT vid, p_company, p_project, 'АН', 'ГАП', 'internal', 'ГАП', (vis ->> 'visits')::numeric * (vis ->> 'hours')::numeric, (vis ->> 'rate')::numeric, (vis ->> 'cost')::numeric, 1;
    ELSE
      INSERT INTO koshtorys_versions (company_id, project_id, version_no, status, kind, contract_amount, source, source_kind, note, file_url, file_sha256, uploaded_by, created_by,
                                      file_totals, file_schedule, file_spreadsheet_id, file_sheet, file_status)
      VALUES (p_company, p_project, vno, 'draft', vkind, (p_payload ->> 'contract')::numeric, 'import_xlsx', 'drive_api', 'Імпорт листа проєкту', furl, sha, p_uploaded_by, p_uploaded_by,
              p_payload -> 'totals', p_payload -> 'schedule', p_payload ->> 'spreadsheet_id', p_payload ->> 'sheet', p_payload ->> 'status')
      RETURNING id INTO vid;
      -- Правило рядка (мануал §5, J2): години D → команда; гроші F → підрядник; обидва або жоден — помилка.
      IF EXISTS (SELECT 1 FROM jsonb_to_recordset(p_payload -> 'rows') AS x(hours numeric, sub numeric)
                  WHERE (x.hours IS NOT NULL AND coalesce(x.sub, 0) > 0) OR (x.hours IS NULL AND coalesce(x.sub, 0) <= 0)) THEN
        RAISE EXCEPTION 'koshtorys_ingest: рядок має водночас години й субпідряд або не має жодного (правило J2)';
      END IF;
      INSERT INTO koshtorys_rows (version_id, company_id, project_id, stage, section, kind, posada, counterparty, hours, rate_uah_hour, cost_uah, sort_order)
      SELECT vid, p_company, p_project, x.stage, x.section,
             CASE WHEN x.hours IS NOT NULL THEN 'internal' ELSE 'subcontract' END,
             CASE WHEN x.hours IS NOT NULL THEN rt.posada END,
             CASE WHEN x.hours IS NULL THEN x.executor END,
             x.hours,
             CASE WHEN x.hours IS NULL THEN NULL
                  WHEN rt.posada IS NOT NULL THEN rt.razom_grn_god
                  ELSE coalesce(round(x.cost / NULLIF(x.hours, 0), 2), (p_payload ->> 'rate')::numeric) END,
             CASE WHEN x.hours IS NULL THEN x.sub ELSE x.cost END,
             coalesce(x.src_row, row_number() OVER ()::int)
        FROM jsonb_to_recordset(p_payload -> 'rows') AS x(stage text, section text, executor text, hours numeric, cost numeric, sub numeric, src_row int)
        LEFT JOIN rates rt ON rt.company_id = p_company AND rt.posada = x.executor;
    END IF;
  END IF;

  pv := koshtorys_preview(p_company, vid, p_payload -> 'totals');
  df := CASE WHEN cur_id IS NOT NULL THEN koshtorys_diff(p_company, cur_id, vid) END;

  -- Попередження (не блокують): розділ поза довідником (рішення власника 25.11.2026); виконавець без ставки в довіднику — береться ставка проєкту (A5).
  warns := warns || coalesce((SELECT jsonb_agg(jsonb_build_object('code', 'W-SECTION', 'text', 'Розділ поза довідником: ' || s)) FROM (
    SELECT DISTINCT section AS s FROM koshtorys_rows r WHERE r.version_id = vid AND NOT EXISTS (
      SELECT 1 FROM koshtorys_sections ks WHERE ks.company_id = p_company AND ks.title = r.section)) q), '[]'::jsonb);
  warns := warns || coalesce((SELECT jsonb_agg(jsonb_build_object('code', 'W-RATE', 'text', 'Виконавця «' || e || '» немає в довіднику ставок, взято ставку проєкту')) FROM (
    SELECT DISTINCT x.executor AS e FROM jsonb_to_recordset(p_payload -> 'rows') AS x(executor text, hours numeric)
     WHERE x.hours IS NOT NULL AND NOT EXISTS (SELECT 1 FROM rates rt WHERE rt.company_id = p_company AND rt.posada = x.executor)) q), '[]'::jsonb);
  IF p_payload ->> 'status' IS DISTINCT FROM 'Затверджено' THEN
    warns := warns || jsonb_build_array(jsonb_build_object('code', 'W-T2', 'text', 'Статус у файлі: ' || coalesce(p_payload ->> 'status', 'не вказано') || ' (затвердження в ARCHI — дія власника)'));
  END IF;

  RETURN jsonb_build_object('same_as_current', false, 'project_id', p_project, 'version_id', vid, 'version_no', (SELECT version_no FROM koshtorys_versions WHERE id = vid),
    'reused', reused, 'sha256', sha, 'ok', (pv ->> 'ok')::boolean, 'checks', pv -> 'checks', 'totals', pv -> 'totals', 'diff', df, 'warnings', warns);
END $f$;

-- 4. Затвердження чернетки: графік оплат і план — одна транзакція (спершу графік: перерахунок бере nearest_* з нього).
CREATE OR REPLACE FUNCTION public.koshtorys_commit_draft(p_company uuid, p_project text, p_approved_by bigint DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SET search_path = public AS $f$
DECLARE v koshtorys_versions%ROWTYPE; ins int := 0; res jsonb;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended(p_company::text || '/' || p_project, 0));
  SELECT * INTO v FROM koshtorys_versions WHERE company_id = p_company AND project_id = p_project AND status = 'draft' ORDER BY version_no DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'no_draft', 'project_id', p_project, 'message', 'Немає чернетки для затвердження: зробіть перегляд («кошторис ' || p_project || '»)');
  END IF;
  IF v.file_schedule IS NOT NULL THEN
    DELETE FROM payment_schedule WHERE company_id = p_company AND project_id = p_project;
    INSERT INTO payment_schedule (company_id, project_id, "стадія", "подія", "дата_план", "сума_план", "ймовірність_план", "статус_план")
    SELECT p_company, p_project, x."стадія", x."подія", x."дата_план"::date, x."сума_план", x."ймовірність_план", x."статус_план"
      FROM jsonb_to_recordset(v.file_schedule) AS x("стадія" text, "подія" text, "дата_план" text, "сума_план" numeric, "ймовірність_план" int, "статус_план" text);
    GET DIAGNOSTICS ins = ROW_COUNT;
  END IF;
  UPDATE project_metrics SET koshtorys_spreadsheet_id = v.file_spreadsheet_id, koshtorys_sheet = v.file_sheet, baseline_at = now(), baseline_by = p_approved_by
   WHERE company_id = p_company AND project_id = p_project;
  res := koshtorys_approve(p_company, v.id, p_approved_by, v.file_totals);
  RETURN res || jsonb_build_object('schedule_rows', ins);
END $f$;

REVOKE ALL ON FUNCTION public.koshtorys_ingest_draft(uuid, text, jsonb, bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.koshtorys_commit_draft(uuid, text, bigint) FROM PUBLIC, anon, authenticated;
