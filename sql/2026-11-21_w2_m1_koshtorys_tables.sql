-- 2026-11-21 W2.1 / M1: таблиці Кошториса (версії, рядки, журнал змін, довідник розділів).
-- Дизайн: docs/W2_DESIGN.md §4, рішення власника: CLAUDE.md п. 40. СТАТУС: підготовлено, НЕ застосовано.
-- Лише нові об'єкти; наявні таблиці не змінюються. Відкат: sql/2026-11-21_w2_m1_koshtorys_tables_rollback.sql.
-- RLS: увімкнено без політик (як evm_packages, archi_wr_inbox): публічний ключ не читає, n8n (роль postgres) працює.
-- Причина: таблиці містять ставки й вартість (п. 39).

CREATE TABLE IF NOT EXISTS public.koshtorys_sections (
  company_id uuid NOT NULL REFERENCES public.companies(company_id),
  title text NOT NULL,
  sort_order int,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (company_id, title)
);

CREATE TABLE IF NOT EXISTS public.koshtorys_versions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  company_id uuid NOT NULL,
  project_id text NOT NULL,
  version_no int NOT NULL CHECK (version_no >= 1),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','approved','superseded')),
  kind text NOT NULL DEFAULT 'initial' CHECK (kind IN ('initial','change')),
  contract_amount numeric(14,2) NOT NULL CHECK (contract_amount >= 0),
  source text NOT NULL CHECK (source IN ('import_xlsx','manual','demo','demo_derived')),
  note text,
  created_by bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  approved_by bigint,
  approved_at timestamptz,
  CONSTRAINT koshtorys_versions_project_fk FOREIGN KEY (company_id, project_id)
    REFERENCES public.project_metrics (company_id, project_id),
  CONSTRAINT koshtorys_versions_uq UNIQUE (company_id, project_id, version_no),
  CONSTRAINT koshtorys_versions_key UNIQUE (id, company_id, project_id),
  CONSTRAINT koshtorys_versions_approved_chk CHECK (status = 'draft' OR approved_at IS NOT NULL)
);
CREATE UNIQUE INDEX IF NOT EXISTS koshtorys_versions_one_approved
  ON public.koshtorys_versions (company_id, project_id) WHERE status = 'approved';
CREATE UNIQUE INDEX IF NOT EXISTS koshtorys_versions_one_draft
  ON public.koshtorys_versions (company_id, project_id) WHERE status = 'draft';

CREATE TABLE IF NOT EXISTS public.koshtorys_rows (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  version_id bigint NOT NULL,
  company_id uuid NOT NULL,
  project_id text NOT NULL,
  stage text NOT NULL CHECK (stage IN ('МБР','ЕП','П','Р','АН')),
  section text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('internal','subcontract')),
  posada text,
  counterparty text,
  hours numeric(10,2),
  rate_uah_hour numeric(10,2),
  cost_uah numeric(14,2) NOT NULL CHECK (cost_uah >= 0),
  sort_order int,
  CONSTRAINT koshtorys_rows_version_fk FOREIGN KEY (version_id, company_id, project_id)
    REFERENCES public.koshtorys_versions (id, company_id, project_id) ON DELETE RESTRICT,
  CONSTRAINT koshtorys_rows_posada_fk FOREIGN KEY (company_id, posada)
    REFERENCES public.rates (company_id, posada),
  CONSTRAINT koshtorys_rows_kind_chk CHECK (
    (kind = 'internal' AND posada IS NOT NULL AND hours IS NOT NULL AND hours >= 0)
    OR (kind = 'subcontract' AND counterparty IS NOT NULL AND hours IS NULL))
);
CREATE INDEX IF NOT EXISTS koshtorys_rows_version_idx ON public.koshtorys_rows (version_id);

CREATE TABLE IF NOT EXISTS public.koshtorys_changes (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  company_id uuid NOT NULL,
  project_id text NOT NULL,
  from_version_id bigint,
  to_version_id bigint NOT NULL,
  reason text NOT NULL CHECK (reason IN ('customer_request','inputs_incomplete','executor_error','bureau_initiative','other')),
  funding text NOT NULL DEFAULT 'undetermined' CHECK (funding IN ('customer','bureau','undetermined')),
  with_money boolean,
  tz_evidence text,
  delta_hours numeric(10,2),
  delta_cost numeric(14,2),
  delta_contract numeric(14,2),
  approved_by bigint,
  approved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT koshtorys_changes_to_fk FOREIGN KEY (to_version_id, company_id, project_id)
    REFERENCES public.koshtorys_versions (id, company_id, project_id),
  CONSTRAINT koshtorys_changes_from_fk FOREIGN KEY (from_version_id, company_id, project_id)
    REFERENCES public.koshtorys_versions (id, company_id, project_id)
);

-- Незмінність: рядки затвердженої версії не змінюються; версія переходить лише draft→approved→superseded.
CREATE OR REPLACE FUNCTION public.koshtorys_rows_guard() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_status text; v_id bigint;
BEGIN
  v_id := CASE WHEN TG_OP = 'INSERT' THEN NEW.version_id ELSE OLD.version_id END;
  SELECT status INTO v_status FROM public.koshtorys_versions WHERE id = v_id;
  IF v_status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'koshtorys_rows: версія % має статус %, рядки змінювати не можна', v_id, v_status;
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;
CREATE TRIGGER koshtorys_rows_guard_trg BEFORE INSERT OR UPDATE OR DELETE ON public.koshtorys_rows
  FOR EACH ROW EXECUTE FUNCTION public.koshtorys_rows_guard();

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
CREATE TRIGGER koshtorys_versions_guard_trg BEFORE UPDATE OR DELETE ON public.koshtorys_versions
  FOR EACH ROW EXECUTE FUNCTION public.koshtorys_versions_guard();

ALTER TABLE public.koshtorys_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.koshtorys_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.koshtorys_rows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.koshtorys_changes ENABLE ROW LEVEL SECURITY;
