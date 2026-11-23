-- W2 M1б (22.11.2026): поля файлу й нагляду у версії Кошториса; таблиці contract_addenda, project_documents, koshtorys_comments (CLAUDE.md п. 41).
-- Назви таблиць погоджено власником 22.11.2026 («Додаткові угоди», «Документи проєкту», «Коментарі власника до Кошториса»).
-- Усі таблиці з company_id і складеним FK на project_metrics (п. 20); RLS увімкнено без політик (п. 28, як M1).

-- 1. Версія Кошториса: файл, відбиток, хто завантажив, звідки, параметри нагляду.
ALTER TABLE public.koshtorys_versions
  ADD COLUMN IF NOT EXISTS file_url text,
  ADD COLUMN IF NOT EXISTS file_sha256 text,
  ADD COLUMN IF NOT EXISTS uploaded_by bigint,
  ADD COLUMN IF NOT EXISTS source_kind text CHECK (source_kind IN ('bot_upload','drive_api')),
  ADD COLUMN IF NOT EXISTS visits_count int CHECK (visits_count >= 0),
  ADD COLUMN IF NOT EXISTS visit_price_uah numeric(14,2) CHECK (visit_price_uah >= 0),
  ADD COLUMN IF NOT EXISTS visit_hours numeric(10,2) CHECK (visit_hours >= 0),
  ADD COLUMN IF NOT EXISTS visit_rate_uah_hour numeric(10,2) CHECK (visit_rate_uah_hour >= 0);

-- Незмінність: файл і відбиток затвердженої версії змінювати не можна (додано до наявної перевірки).
CREATE OR REPLACE FUNCTION public.koshtorys_versions_guard() RETURNS trigger LANGUAGE plpgsql AS $$
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
END $$;

-- 2. Додаткові угоди.
CREATE TABLE IF NOT EXISTS public.contract_addenda (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  company_id uuid NOT NULL,
  project_id text NOT NULL,
  number text NOT NULL,
  agreement_date date,
  description text NOT NULL,
  status text NOT NULL DEFAULT 'preparing' CHECK (status IN ('preparing','sent_for_signature','signed','rejected')),
  file_url text,
  created_by bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT contract_addenda_project_fk FOREIGN KEY (company_id, project_id)
    REFERENCES public.project_metrics (company_id, project_id),
  CONSTRAINT contract_addenda_uq UNIQUE (company_id, project_id, number),
  CONSTRAINT contract_addenda_key UNIQUE (id, company_id, project_id)
);

-- Зміна Кошториса може посилатись на додаткову угоду; з її статусу виводиться «Хто платить за зміну» (п. 41, правило — у функції пізніше).
ALTER TABLE public.koshtorys_changes ADD COLUMN IF NOT EXISTS addendum_id bigint;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'koshtorys_changes_addendum_fk') THEN
    ALTER TABLE public.koshtorys_changes ADD CONSTRAINT koshtorys_changes_addendum_fk
      FOREIGN KEY (addendum_id, company_id, project_id) REFERENCES public.contract_addenda (id, company_id, project_id);
  END IF;
END $$;

-- 3. Документи проєкту.
CREATE TABLE IF NOT EXISTS public.project_documents (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  company_id uuid NOT NULL,
  project_id text NOT NULL,
  doc_type text NOT NULL CHECK (doc_type IN ('commercial_offer','contract','addendum','act','tz','source_data')),
  title text NOT NULL,
  storage text NOT NULL CHECK (storage IN ('drive','vchasno','upload')),
  url text,
  file_sha256 text,
  signed_date date,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','signed','cancelled')),
  addendum_id bigint,
  created_by bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT project_documents_project_fk FOREIGN KEY (company_id, project_id)
    REFERENCES public.project_metrics (company_id, project_id),
  CONSTRAINT project_documents_addendum_fk FOREIGN KEY (addendum_id, company_id, project_id)
    REFERENCES public.contract_addenda (id, company_id, project_id),
  CONSTRAINT project_documents_link_chk CHECK (url IS NOT NULL OR storage = 'upload')
);
CREATE INDEX IF NOT EXISTS project_documents_project_idx ON public.project_documents (company_id, project_id);

-- 4. Коментарі власника до Кошториса.
CREATE TABLE IF NOT EXISTS public.koshtorys_comments (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  company_id uuid NOT NULL,
  project_id text NOT NULL,
  version_id bigint,
  body text NOT NULL,
  author_id bigint,
  status text NOT NULL DEFAULT 'new' CHECK (status IN ('new','discussed','permission_granted','rejected')),
  decision_note text,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT koshtorys_comments_project_fk FOREIGN KEY (company_id, project_id)
    REFERENCES public.project_metrics (company_id, project_id),
  CONSTRAINT koshtorys_comments_version_fk FOREIGN KEY (version_id, company_id, project_id)
    REFERENCES public.koshtorys_versions (id, company_id, project_id),
  CONSTRAINT koshtorys_comments_decided_chk CHECK (status IN ('new','discussed') OR decided_at IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS koshtorys_comments_project_idx ON public.koshtorys_comments (company_id, project_id);

ALTER TABLE public.contract_addenda ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.koshtorys_comments ENABLE ROW LEVEL SECURITY;
