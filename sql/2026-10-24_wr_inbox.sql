-- ARCHI 24.10.2026 (RELEASE_PLAN §93): варіант А — повідомлення ПМа в тижневому звіті накопичуються в черзі
-- і обробляються лише по «📤 Відправити» / «✅ Фінал». Міграція wr_inbox_20261024.
CREATE TABLE IF NOT EXISTS public.archi_wr_inbox (
  id BIGSERIAL PRIMARY KEY,
  session_id TEXT NOT NULL,
  project_id TEXT NOT NULL,
  source_type TEXT NOT NULL DEFAULT 'text',
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS archi_wr_inbox_sess_proj ON public.archi_wr_inbox (session_id, project_id, id);
-- RLS увімкнено при створенні (як payment_schedule): n8n пише ролью postgres (власник таблиці), анонімний/API-доступ закрито.
ALTER TABLE public.archi_wr_inbox ENABLE ROW LEVEL SECURITY;
