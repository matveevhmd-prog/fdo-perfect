update public.wr_plan_items set project_id = 'ARCH-' || project_id where project_id = $q$DEMO-04$q$ and week_start between date '2026-09-07' and date '2026-10-19';
insert into public.wr_plan_items(project_id, week_start, item_number, item_text, status) values
($q$DEMO-04$q$,'2026-09-07',1,$q$Довести готовність Р до 30%$q$,'done'),
($q$DEMO-04$q$,'2026-09-07',2,$q$Підготувати акт по стадії П до підписання$q$,'done'),
($q$DEMO-04$q$,'2026-09-14',1,$q$Довести готовність Р до 45%$q$,'done'),
($q$DEMO-04$q$,'2026-09-21',1,$q$Довести готовність Р до 60%$q$,'done'),
($q$DEMO-04$q$,'2026-09-28',1,$q$Довести готовність Р до 75%$q$,'done'),
($q$DEMO-04$q$,'2026-09-28',2,$q$Передати розділи Р на внутрішню перевірку$q$,'done'),
($q$DEMO-04$q$,'2026-09-28',3,$q$Видати документацію Р до 21.10.2026$q$,'done'),
($q$DEMO-04$q$,'2026-10-05',1,$q$Довести готовність Р до 85%$q$,'done'),
($q$DEMO-04$q$,'2026-10-05',2,$q$Передати розділи Р на внутрішню перевірку$q$,'done'),
($q$DEMO-04$q$,'2026-10-05',3,$q$Видати документацію Р до 18.10.2026$q$,'done'),
($q$DEMO-04$q$,'2026-10-12',1,$q$Довести готовність Р до 92%$q$,'done'),
($q$DEMO-04$q$,'2026-10-12',2,$q$Передати розділи Р на внутрішню перевірку$q$,'done'),
($q$DEMO-04$q$,'2026-10-12',3,$q$Видати документацію Р до 16.10.2026$q$,'done'),
($q$DEMO-04$q$,'2026-10-19',1,$q$Довести готовність Р до 100%$q$,'pending'),
($q$DEMO-04$q$,'2026-10-19',2,$q$Передати розділи Р на внутрішню перевірку$q$,'pending'),
($q$DEMO-04$q$,'2026-10-19',3,$q$Видати документацію Р до 14.10.2026$q$,'pending')
on conflict (project_id, week_start, item_number) do update set item_text=EXCLUDED.item_text, status=EXCLUDED.status;
