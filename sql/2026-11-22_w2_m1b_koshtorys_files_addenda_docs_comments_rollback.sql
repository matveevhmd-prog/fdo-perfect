-- Відкат M1б: повертає попередню перевірку незмінності, видаляє нові таблиці й поля (дані в них при відкаті втрачаються).
BEGIN;
ALTER TABLE public.koshtorys_changes DROP CONSTRAINT IF EXISTS koshtorys_changes_addendum_fk;
ALTER TABLE public.koshtorys_changes DROP COLUMN IF EXISTS addendum_id;
DROP TABLE IF EXISTS public.koshtorys_comments;
DROP TABLE IF EXISTS public.project_documents;
DROP TABLE IF EXISTS public.contract_addenda;
CREATE OR REPLACE FUNCTION public.koshtorys_versions_guard() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'draft' THEN RAISE EXCEPTION 'koshtorys_versions: версію зі статусом % видаляти не можна', OLD.status; END IF;
    RETURN OLD;
  END IF;
  IF OLD.status = 'draft' AND NEW.status IN ('draft','approved') THEN RETURN NEW; END IF;
  IF OLD.status = 'approved' AND NEW.status = 'superseded' AND
     (OLD.company_id, OLD.project_id, OLD.version_no, OLD.kind, OLD.contract_amount, OLD.source, OLD.approved_by, OLD.approved_at)
     IS NOT DISTINCT FROM (NEW.company_id, NEW.project_id, NEW.version_no, NEW.kind, NEW.contract_amount, NEW.source, NEW.approved_by, NEW.approved_at)
  THEN RETURN NEW; END IF;
  IF OLD.status = NEW.status AND OLD.status <> 'draft' AND
     (OLD.contract_amount, OLD.version_no, OLD.approved_at) IS NOT DISTINCT FROM (NEW.contract_amount, NEW.version_no, NEW.approved_at)
  THEN RETURN NEW; END IF;
  RAISE EXCEPTION 'koshtorys_versions: недозволена зміна (% → %)', OLD.status, NEW.status;
END $$;
ALTER TABLE public.koshtorys_versions
  DROP COLUMN IF EXISTS file_url, DROP COLUMN IF EXISTS file_sha256, DROP COLUMN IF EXISTS uploaded_by,
  DROP COLUMN IF EXISTS source_kind, DROP COLUMN IF EXISTS visits_count, DROP COLUMN IF EXISTS visit_price_uah,
  DROP COLUMN IF EXISTS visit_hours, DROP COLUMN IF EXISTS visit_rate_uah_hour;
COMMIT;
