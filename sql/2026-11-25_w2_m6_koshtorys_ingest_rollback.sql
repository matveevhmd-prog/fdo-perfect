-- Відкат W2 M6 (25.11.2026). Виконувати лише якщо немає версій із file_totals / file_schedule, які треба зберегти.
DROP FUNCTION IF EXISTS public.koshtorys_commit_draft(uuid, text, bigint);
DROP FUNCTION IF EXISTS public.koshtorys_ingest_draft(uuid, text, jsonb, bigint);
CREATE OR REPLACE FUNCTION public.koshtorys_versions_guard() RETURNS trigger LANGUAGE plpgsql AS $g$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'draft' THEN RAISE EXCEPTION 'koshtorys_versions: версію зі статусом % видаляти не можна', OLD.status; END IF;
    RETURN OLD;
  END IF;
  IF OLD.status = 'draft' AND NEW.status IN ('draft','approved') THEN RETURN NEW; END IF;
  IF OLD.status = 'approved' AND NEW.status = 'superseded' AND
     (OLD.company_id, OLD.project_id, OLD.version_no, OLD.kind, OLD.contract_amount, OLD.source, OLD.approved_by, OLD.approved_at, OLD.file_url, OLD.file_sha256)
     IS NOT DISTINCT FROM (NEW.company_id, NEW.project_id, NEW.version_no, NEW.kind, NEW.contract_amount, NEW.source, NEW.approved_by, NEW.approved_at, NEW.file_url, NEW.file_sha256)
  THEN RETURN NEW; END IF;
  IF OLD.status = NEW.status AND OLD.status <> 'draft' AND
     (OLD.contract_amount, OLD.version_no, OLD.approved_at, OLD.file_url, OLD.file_sha256) IS NOT DISTINCT FROM (NEW.contract_amount, NEW.version_no, NEW.approved_at, NEW.file_url, NEW.file_sha256)
  THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'koshtorys_versions: недозволена зміна (% → %)', OLD.status, NEW.status;
END $g$;
ALTER TABLE public.koshtorys_versions DROP COLUMN IF EXISTS file_totals, DROP COLUMN IF EXISTS file_schedule,
  DROP COLUMN IF EXISTS file_spreadsheet_id, DROP COLUMN IF EXISTS file_sheet, DROP COLUMN IF EXISTS file_status;
