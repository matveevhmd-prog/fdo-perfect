-- П2e: факти для ШІ-аналітика картки чату (відхилення прибутку, концентрація втрат, блоковані контракти).
-- Формули в SQL (CLAUDE.md п. 31); n8n лише передає. Чернетка до застосування: застосовувати лише за «так» власника (apply_migration).
-- Відкат: drop function public.archi_card_facts(uuid);
create or replace function public.archi_card_facts(p_company uuid)
returns jsonb
language sql
stable
as $$
with last_snap as (
  select distinct on (project_id) project_id, "блокер" as b
  from public.wr_weekly_snapshots
  where company_id = p_company
  order by project_id, week_start desc
),
base as (
  select m.project_id,
         m.contract_amount,
         case when m.etc_forecast_total_hours is not null then round(m.profit_forecast - m.profit_plan) end as profit_gap,
         (ls.b is not null and coalesce(jsonb_array_length(ls.b->'types'), 0) > 0) as blocked,
         case when ls.b is not null then ls.b->'types' else '[]'::jsonb end as btypes
  from public.project_metrics m
  left join last_snap ls on ls.project_id = m.project_id
  where m.company_id = p_company and m.contract_type is distinct from 'visit'
),
tot as (
  select coalesce(sum(-profit_gap) filter (where profit_gap < 0), 0) as neg_total,
         coalesce(sum(profit_gap) filter (where profit_gap > 0), 0) as pos_total,
         coalesce(sum(profit_gap), 0) as net_gap
  from base
),
proj as (
  select b.project_id,
         jsonb_build_object('profit_gap', b.profit_gap,
                            'gap_share_pct', case when b.profit_gap < 0 and t.neg_total > 0 then round(-b.profit_gap / t.neg_total * 100) end) as f
  from base b, tot t
),
loss as (
  select jsonb_agg(jsonb_build_object('id', project_id, 'gap', profit_gap, 'share_pct', round(-profit_gap / (select neg_total from tot) * 100)) order by profit_gap) as top_loss
  from (select project_id, profit_gap from base where profit_gap < 0 order by profit_gap limit 3) x
),
gain as (
  select jsonb_build_object('id', project_id, 'gap', profit_gap) as top_gain
  from base where profit_gap > 0 order by profit_gap desc limit 1
),
blk as (
  select count(*) filter (where blocked) as cnt,
         coalesce(sum(contract_amount) filter (where blocked), 0) as contract_sum,
         count(*) filter (where blocked and btypes ? 'люди') as r_people,
         count(*) filter (where blocked and btypes ? 'гроші') as r_money,
         count(*) filter (where blocked and btypes ? 'замовник') as r_customer
  from base
)
select jsonb_build_object(
  'projects', (select jsonb_object_agg(project_id, f) from proj),
  'portfolio', jsonb_build_object(
    'neg_total', (select neg_total from tot),
    'pos_total', (select pos_total from tot),
    'net_gap', (select net_gap from tot),
    'top_loss', (select top_loss from loss),
    'top_gain', (select top_gain from gain),
    'blocked', (select jsonb_build_object('count', cnt, 'contract_sum', contract_sum,
                 'reasons', jsonb_build_object('люди', r_people, 'гроші', r_money, 'замовник', r_customer)) from blk)
  )
);
$$;
