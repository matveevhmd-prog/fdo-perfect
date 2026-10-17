update public.wr_plan_items set project_id = 'ARCH-' || project_id where project_id = $q$22-24$q$ and week_start between date '2026-09-07' and date '2026-10-19';
insert into public.wr_plan_items(project_id, week_start, item_number, item_text, status) values
($q$22-24$q$,'2026-09-07',1,$q$Довести готовність Р до 38%$q$,'done'),
($q$22-24$q$,'2026-09-14',1,$q$Довести готовність Р до 47%$q$,'done'),
($q$22-24$q$,'2026-09-21',1,$q$Довести готовність Р до 56%$q$,'done'),
($q$22-24$q$,'2026-09-28',1,$q$Довести готовність Р до 63%$q$,'done'),
($q$22-24$q$,'2026-10-05',1,$q$Довести готовність Р до 70%$q$,'done'),
($q$22-24$q$,'2026-10-05',2,$q$Передати розділи Р на внутрішню перевірку$q$,'done'),
($q$22-24$q$,'2026-10-12',1,$q$Довести готовність Р до 76%$q$,'done'),
($q$22-24$q$,'2026-10-12',2,$q$Передати розділи Р на внутрішню перевірку$q$,'done'),
($q$22-24$q$,'2026-10-19',1,$q$Довести готовність Р до 86%$q$,'pending'),
($q$22-24$q$,'2026-10-19',2,$q$Передати розділи Р на внутрішню перевірку$q$,'pending')
on conflict (project_id, week_start, item_number) do update set item_text=EXCLUDED.item_text, status=EXCLUDED.status;
