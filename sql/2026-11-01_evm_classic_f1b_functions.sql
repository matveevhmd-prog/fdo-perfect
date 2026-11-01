-- 2026-11-01 EVM (класичний), Ф1b: функції і в'ю за EVM_CLASSIC_DESIGN.md §3 (K-01…K-12).
-- Лише нові об'єкти. Archi-таблиці читаються (time_log, money_log, rates, project_metrics), не змінюються.
-- Статусна дата (D7): неділя поточного тижня за Europe/Kyiv. [Припущення: «кінець звітного тижня» = неділя поточного тижня.]
-- AC (K-04): години × rates.razom_grn_god (запасний варіант project_metrics.real_rate_team_hour — як F-02) + оплати субпідряднику (О-3: за оплатою, рішення відкрите).
-- security_invoker: в'ю підпорядковане RLS таблиць evm_*.

CREATE OR REPLACE FUNCTION public.evm_classic_indices(p_bac numeric, p_pv numeric, p_ev numeric, p_ac numeric)
RETURNS TABLE (cv numeric, sv numeric, cpi numeric, spi numeric, eac numeric, etc numeric, vac numeric, tcpi numeric)
LANGUAGE sql IMMUTABLE SET search_path = public AS $$
  WITH b AS (SELECT p_ev / NULLIF(p_ac, 0) AS cpi_v, p_ev / NULLIF(p_pv, 0) AS spi_v),
       e AS (SELECT cpi_v, spi_v, p_bac / NULLIF(cpi_v, 0) AS eac_v FROM b)
  SELECT p_ev - p_ac, p_ev - p_pv, cpi_v, spi_v, eac_v, eac_v - p_ac, p_bac - eac_v,
         CASE WHEN p_bac - p_ac > 0 THEN (p_bac - p_ev) / (p_bac - p_ac) END
  FROM e;
$$;

CREATE OR REPLACE FUNCTION public.evm_classic_at(p_project text, p_t date)
RETURNS TABLE (project_id text, as_of date, has_baseline boolean, baseline_no int, packages int,
  bac numeric, pv numeric, ev numeric, ac numeric, cv numeric, sv numeric, cpi numeric, spi numeric,
  eac numeric, etc numeric, vac numeric, tcpi numeric)
LANGUAGE sql STABLE SET search_path = public AS $$
WITH pr AS (
  SELECT m.project_id, m.real_rate_team_hour FROM public.project_metrics m
  WHERE COALESCE(m.contract_type, 'stages') = 'stages' AND (p_project IS NULL OR m.project_id = p_project)),
cur AS (
  SELECT p.project_id, max(p.baseline_no) AS bn FROM public.evm_packages p
  JOIN pr ON pr.project_id = p.project_id GROUP BY p.project_id),
pk AS (
  SELECT p.* FROM public.evm_packages p JOIN cur c ON c.project_id = p.project_id AND c.bn = p.baseline_no),
last_ev AS (
  SELECT DISTINCT ON (d.package_id) d.package_id, d.event
  FROM public.evm_package_done d JOIN pk ON pk.id = d.package_id
  WHERE d.event IN ('done', 'cancelled') AND d.event_date <= p_t
  ORDER BY d.package_id, d.event_date DESC, d.id DESC),
agg AS (
  SELECT pk.project_id, count(*)::int AS n, sum(pk.budget_uah) AS bac_v,
         sum(pk.budget_uah) FILTER (WHERE pk.planned_finish <= p_t) AS pv_v,
         sum(pk.budget_uah) FILTER (WHERE le.event = 'done') AS ev_v
  FROM pk LEFT JOIN last_ev le ON le.package_id = pk.id GROUP BY pk.project_id),
hrs AS (
  SELECT t.project_id, sum(t."години" * COALESCE(r.razom_grn_god, pr.real_rate_team_hour)) AS c
  FROM public.time_log t JOIN pr ON pr.project_id = t.project_id
  LEFT JOIN public.rates r ON r.posada = t."виконавець"
  WHERE t."статус" = 'confirmed' AND t."стадія" IN ('МБР', 'ЕП', 'П', 'Р') AND t."дата" <= p_t
  GROUP BY t.project_id),
sub AS (
  SELECT mo.project_id, sum(mo."сума") AS c FROM public.money_log mo JOIN pr ON pr.project_id = mo.project_id
  WHERE mo."статус" = 'confirmed' AND mo."тип" = 'оплата_субпідряднику' AND mo."дата" <= p_t
  GROUP BY mo.project_id),
base AS (
  SELECT pr.project_id, (a.project_id IS NOT NULL) AS hb, c.bn, a.n, a.bac_v,
         COALESCE(a.pv_v, 0) AS pv_v, COALESCE(a.ev_v, 0) AS ev_v,
         COALESCE(h.c, 0) + COALESCE(s.c, 0) AS ac_v
  FROM pr
  LEFT JOIN agg a ON a.project_id = pr.project_id
  LEFT JOIN cur c ON c.project_id = pr.project_id
  LEFT JOIN hrs h ON h.project_id = pr.project_id
  LEFT JOIN sub s ON s.project_id = pr.project_id)
SELECT b.project_id, p_t, b.hb, b.bn, b.n,
       b.bac_v,
       CASE WHEN b.hb THEN b.pv_v END, CASE WHEN b.hb THEN b.ev_v END, CASE WHEN b.hb THEN b.ac_v END,
       i.cv, i.sv, i.cpi, i.spi, i.eac, i.etc, i.vac, i.tcpi
FROM base b
LEFT JOIN LATERAL public.evm_classic_indices(b.bac_v, b.pv_v, b.ev_v, b.ac_v) i ON b.hb
ORDER BY b.project_id;
$$;

CREATE OR REPLACE VIEW public.evm_classic_today WITH (security_invoker = true) AS
SELECT * FROM public.evm_classic_at(NULL, (date_trunc('week', timezone('Europe/Kyiv', now()))::date + 6));
