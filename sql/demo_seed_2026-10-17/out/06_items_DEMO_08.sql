update public.wr_plan_items set project_id = 'ARCH-' || project_id where project_id = $q$DEMO-08$q$ and week_start between date '2026-09-07' and date '2026-10-19';
insert into public.wr_plan_items(project_id, week_start, item_number, item_text, status) values
($q$DEMO-08$q$,'2026-09-07',1,$q$Довести готовність Р до 95%$q$,'done'),
($q$DEMO-08$q$,'2026-09-07',2,$q$Передати розділи Р на внутрішню перевірку$q$,'done'),
($q$DEMO-08$q$,'2026-09-07',3,$q$Видати документацію Р до 19.09.2026$q$,'done'),
($q$DEMO-08$q$,'2026-09-14',1,$q$Довести готовність Р до 100%$q$,'done'),
($q$DEMO-08$q$,'2026-09-14',2,$q$Передати розділи Р на внутрішню перевірку$q$,'done'),
($q$DEMO-08$q$,'2026-09-14',3,$q$Видати документацію Р до 19.09.2026$q$,'done'),
($q$DEMO-08$q$,'2026-09-21',1,$q$Підготувати акт по стадії Р до підписання$q$,'done'),
($q$DEMO-08$q$,'2026-09-28',1,$q$Підготувати підсумок для власника$q$,'done'),
($q$DEMO-08$q$,'2026-09-28',2,$q$Закрити проєкт у системі$q$,'done'),
($q$DEMO-08$q$,'2026-09-28',3,$q$Передати архів документації замовнику$q$,'done')
on conflict (project_id, week_start, item_number) do update set item_text=EXCLUDED.item_text, status=EXCLUDED.status;
