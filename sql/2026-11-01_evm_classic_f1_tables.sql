-- 2026-11-01 EVM (класичний), Ф1: таблиці базового плану і факту виконання пакетів.
-- Дизайн: docs/EVM_CLASSIC_DESIGN.md §4. Лише нові об'єкти, наявні таблиці не змінюються.
-- RLS увімкнено без політик (як archi_wr_inbox): звичайний ключ не читає, сервісний читає.
CREATE TABLE IF NOT EXISTS public.evm_packages (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  project_id text NOT NULL REFERENCES public.project_metrics(project_id),
  baseline_no int NOT NULL DEFAULT 1 CHECK (baseline_no >= 1),
  stage text NOT NULL CHECK (stage IN ('МБР','ЕП','П','Р')),
  package_code text NOT NULL,
  title text NOT NULL,
  budget_uah numeric(14,2) NOT NULL CHECK (budget_uah > 0),
  budget_src text,
  rule text NOT NULL DEFAULT '0/100' CHECK (rule IN ('0/100')),
  planned_start date,
  planned_finish date NOT NULL,
  source text NOT NULL CHECK (source IN ('koshtorys','demo')),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by text,
  CONSTRAINT evm_packages_uq UNIQUE (project_id, baseline_no, package_code),
  CONSTRAINT evm_packages_start_le_finish CHECK (planned_start IS NULL OR planned_start <= planned_finish)
);
CREATE TABLE IF NOT EXISTS public.evm_package_done (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  package_id bigint NOT NULL REFERENCES public.evm_packages(id) ON DELETE RESTRICT,
  event text NOT NULL CHECK (event IN ('started','done','cancelled')),
  event_date date NOT NULL,
  confirmed_by text,
  evidence text,
  source text NOT NULL CHECK (source IN ('bot','koshtorys','demo')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS evm_package_done_pkg_idx ON public.evm_package_done(package_id);
ALTER TABLE public.evm_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.evm_package_done ENABLE ROW LEVEL SECURITY;
