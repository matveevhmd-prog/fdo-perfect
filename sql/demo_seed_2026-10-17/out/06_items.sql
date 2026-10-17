insert into public.wr_plan_items(project_id, week_start, item_number, item_text, status)
select s.project_id, (s.week_start + 7), t.n::int, t.line,
 case when s.week_start = date '2026-10-12' then 'pending'
      when t.n = 1 and (s.project_id, s.week_start::text) in (values ($q$DEMO-02$q$,'2026-09-28'),($q$DEMO-02$q$,'2026-10-05'),($q$DEMO-03$q$,'2026-09-07'),($q$DEMO-03$q$,'2026-09-14'),($q$DEMO-03$q$,'2026-09-21'),($q$DEMO-03$q$,'2026-09-28'),($q$DEMO-03$q$,'2026-10-05'),($q$DEMO-05$q$,'2026-09-14'),($q$DEMO-05$q$,'2026-09-21'),($q$DEMO-05$q$,'2026-09-28'),($q$DEMO-05$q$,'2026-10-05'),($q$DEMO-06$q$,'2026-09-28'),($q$DEMO-06$q$,'2026-10-05'),($q$DEMO-07$q$,'2026-09-07'),($q$DEMO-07$q$,'2026-09-14'),($q$DEMO-07$q$,'2026-09-21'),($q$DEMO-07$q$,'2026-09-28'),($q$DEMO-07$q$,'2026-10-05'),($q$DEMO-10$q$,'2026-09-28'),($q$DEMO-10$q$,'2026-10-05'),($q$24-11$q$,'2026-09-28'),($q$24-11$q$,'2026-10-05')) then 'not_done' else 'done' end
from public.wr_weekly_snapshots s cross join lateral unnest(string_to_array(s.plans_next_week, E'\n')) with ordinality as t(line, n)
where s.session_id = '304884647' and s.plans_next_week is not null and s.week_start between date '2026-08-31' and date '2026-10-12'
on conflict (project_id, week_start, item_number) do update set item_text = EXCLUDED.item_text, status = EXCLUDED.status;
