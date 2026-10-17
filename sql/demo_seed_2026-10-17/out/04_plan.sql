update public.project_metrics set contract_amount=750000.0, cost_plan_team=348547.86, cost_plan_subcontract=200000, bac=548547.86, profit_plan=201452.14, profitability_plan_pct=26.9, planned_hours=592, planned_hours_by_stage=$j${"МБР":40,"ЕП":112,"П":180,"Р":260,"АН":0}$j$::jsonb, etc_plan_by_stage=$j${"МБР":40,"ЕП":112,"П":180,"Р":260}$j$::jsonb, real_rate_team_hour=588.76 where project_id=$q$DEMO-01$q$;
update public.project_metrics set contract_amount=405000, cost_plan_team=279190.26, cost_plan_subcontract=45000, bac=324190.26, profit_plan=80809.74, profitability_plan_pct=20.0, planned_hours=474, planned_hours_by_stage=$j${"МБР":32,"ЕП":90,"П":144,"Р":208,"АН":0}$j$::jsonb, etc_plan_by_stage=$j${"МБР":32,"ЕП":90,"П":144,"Р":208}$j$::jsonb, real_rate_team_hour=589.01 where project_id=$q$DEMO-02$q$;
update public.project_metrics set contract_amount=882000, cost_plan_team=652405.79, cost_plan_subcontract=98000, bac=750405.79, profit_plan=131594.21, profitability_plan_pct=14.9, planned_hours=1108, planned_hours_by_stage=$j${"МБР":75,"ЕП":210,"П":337,"Р":486,"АН":0}$j$::jsonb, etc_plan_by_stage=$j${"МБР":75,"ЕП":210,"П":337,"Р":486}$j$::jsonb, real_rate_team_hour=588.81 where project_id=$q$DEMO-03$q$;
update public.project_metrics set contract_amount=549000, cost_plan_team=377881.59, cost_plan_subcontract=61000, bac=438881.59, profit_plan=110118.41, profitability_plan_pct=20.1, planned_hours=642, planned_hours_by_stage=$j${"МБР":43,"ЕП":121,"П":195,"Р":283,"АН":0}$j$::jsonb, etc_plan_by_stage=$j${"МБР":43,"ЕП":121,"П":195,"Р":283}$j$::jsonb, real_rate_team_hour=588.6 where project_id=$q$DEMO-04$q$;
update public.project_metrics set contract_amount=1035000, cost_plan_team=765560.19, cost_plan_subcontract=115000, bac=880560.19, profit_plan=154439.81, profitability_plan_pct=14.9, planned_hours=1300, planned_hours_by_stage=$j${"МБР":88,"ЕП":246,"П":395,"Р":571,"АН":0}$j$::jsonb, etc_plan_by_stage=$j${"МБР":88,"ЕП":246,"П":395,"Р":571}$j$::jsonb, real_rate_team_hour=588.89 where project_id=$q$DEMO-05$q$;
update public.project_metrics set contract_amount=288000, cost_plan_team=198495.05, cost_plan_subcontract=32000, bac=230495.05, profit_plan=57504.95, profitability_plan_pct=20.0, planned_hours=337, planned_hours_by_stage=$j${"МБР":23,"ЕП":64,"П":102,"Р":148,"АН":0}$j$::jsonb, etc_plan_by_stage=$j${"МБР":23,"ЕП":64,"П":102,"Р":148}$j$::jsonb, real_rate_team_hour=589.01 where project_id=$q$DEMO-06$q$;
update public.project_metrics set contract_amount=702000, cost_plan_team=519277.18, cost_plan_subcontract=78000, bac=597277.18, profit_plan=104722.82, profitability_plan_pct=14.9, planned_hours=882, planned_hours_by_stage=$j${"МБР":60,"ЕП":167,"П":268,"Р":387,"АН":0}$j$::jsonb, etc_plan_by_stage=$j${"МБР":60,"ЕП":167,"П":268,"Р":387}$j$::jsonb, real_rate_team_hour=588.75 where project_id=$q$DEMO-07$q$;
update public.project_metrics set contract_amount=945000, cost_plan_team=652405.79, cost_plan_subcontract=105000, bac=757405.79, profit_plan=187594.21, profitability_plan_pct=19.9, planned_hours=1108, planned_hours_by_stage=$j${"МБР":75,"ЕП":210,"П":337,"Р":486,"АН":0}$j$::jsonb, etc_plan_by_stage=$j${"МБР":75,"ЕП":210,"П":337,"Р":486}$j$::jsonb, real_rate_team_hour=588.81 where project_id=$q$DEMO-08$q$;
update public.project_metrics set contract_amount=468000, cost_plan_team=323433.6, cost_plan_subcontract=52000, bac=375433.6, profit_plan=92566.4, profitability_plan_pct=19.8, planned_hours=549, planned_hours_by_stage=$j${"МБР":37,"ЕП":104,"П":167,"Р":241,"АН":0}$j$::jsonb, etc_plan_by_stage=$j${"МБР":37,"ЕП":104,"П":167,"Р":241}$j$::jsonb, real_rate_team_hour=589.13 where project_id=$q$DEMO-09$q$;
update public.project_metrics set contract_amount=801000, cost_plan_team=552155.52, cost_plan_subcontract=89000, bac=641155.52, profit_plan=159844.48, profitability_plan_pct=20.0, planned_hours=938, planned_hours_by_stage=$j${"МБР":63,"ЕП":177,"П":285,"Р":413,"АН":0}$j$::jsonb, etc_plan_by_stage=$j${"МБР":63,"ЕП":177,"П":285,"Р":413}$j$::jsonb, real_rate_team_hour=588.65 where project_id=$q$DEMO-10$q$;
update public.payment_schedule ps set "дата_план"=v.d::date, "сума_план"=v.sm, "ймовірність_план"=v.pr, "статус_план"=v.stt from (values
($q$DEMO-01$q$,$q$П$q$,'акт','2026-11-06',300000.0,9,$q$заплановано$q$),
($q$DEMO-01$q$,$q$П$q$,'документація','2026-10-30',NULL,8,NULL),
($q$DEMO-01$q$,$q$Р$q$,'акт','2026-12-18',400000.0,9,$q$заплановано$q$),
($q$DEMO-01$q$,$q$Р$q$,'документація','2026-12-04',NULL,8,NULL),
($q$DEMO-02$q$,$q$П$q$,'акт','2026-10-30',162000.0,6,$q$заплановано$q$),
($q$DEMO-02$q$,$q$П$q$,'документація','2026-10-16',NULL,5,NULL),
($q$DEMO-02$q$,$q$Р$q$,'акт','2026-12-11',216000.0,6,$q$заплановано$q$),
($q$DEMO-02$q$,$q$Р$q$,'документація','2026-11-27',NULL,5,NULL),
($q$DEMO-03$q$,$q$П$q$,'акт','2026-10-16',352800.0,3,$q$заплановано$q$),
($q$DEMO-03$q$,$q$П$q$,'документація','2026-10-02',NULL,3,NULL),
($q$DEMO-03$q$,$q$Р$q$,'акт','2026-11-27',470400.0,3,$q$заплановано$q$),
($q$DEMO-03$q$,$q$Р$q$,'документація','2026-11-13',NULL,3,NULL),
($q$DEMO-04$q$,$q$П$q$,'акт','2026-09-09',219600.0,9,$q$оплачено$q$),
($q$DEMO-04$q$,$q$П$q$,'документація','2026-09-02',NULL,10,NULL),
($q$DEMO-04$q$,$q$Р$q$,'акт','2026-10-30',292800.0,9,$q$заплановано$q$),
($q$DEMO-04$q$,$q$Р$q$,'документація','2026-10-16',NULL,10,NULL),
($q$DEMO-05$q$,$q$П$q$,'акт','2026-09-10',414000.0,2,$q$заплановано$q$),
($q$DEMO-05$q$,$q$П$q$,'документація','2026-09-03',NULL,2,NULL),
($q$DEMO-05$q$,$q$Р$q$,'акт','2026-12-04',552000.0,2,$q$заплановано$q$),
($q$DEMO-05$q$,$q$Р$q$,'документація','2026-11-20',NULL,2,NULL),
($q$DEMO-06$q$,$q$П$q$,'акт','2026-10-09',115200.0,5,$q$заплановано$q$),
($q$DEMO-06$q$,$q$П$q$,'документація','2026-09-25',NULL,5,NULL),
($q$DEMO-06$q$,$q$Р$q$,'акт','2026-11-20',153600.0,5,$q$заплановано$q$),
($q$DEMO-06$q$,$q$Р$q$,'документація','2026-11-06',NULL,5,NULL),
($q$DEMO-07$q$,$q$П$q$,'акт','2026-11-06',280800.0,4,$q$заплановано$q$),
($q$DEMO-07$q$,$q$П$q$,'документація','2026-10-23',NULL,4,NULL),
($q$DEMO-07$q$,$q$Р$q$,'акт','2026-12-25',374400.0,4,$q$заплановано$q$),
($q$DEMO-07$q$,$q$Р$q$,'документація','2026-12-11',NULL,4,NULL),
($q$DEMO-08$q$,$q$П$q$,'акт','2026-09-13',378000.0,10,$q$оплачено$q$),
($q$DEMO-08$q$,$q$П$q$,'документація','2026-09-06',NULL,10,NULL),
($q$DEMO-08$q$,$q$Р$q$,'акт','2026-10-09',504000.0,10,$q$оплачено$q$),
($q$DEMO-08$q$,$q$Р$q$,'документація','2026-09-19',NULL,10,NULL),
($q$DEMO-09$q$,$q$П$q$,'акт','2026-11-20',187200.0,7,$q$заплановано$q$),
($q$DEMO-09$q$,$q$П$q$,'документація','2026-11-06',NULL,7,NULL),
($q$DEMO-09$q$,$q$Р$q$,'акт','2026-12-25',249600.0,7,$q$заплановано$q$),
($q$DEMO-09$q$,$q$Р$q$,'документація','2026-12-11',NULL,7,NULL),
($q$DEMO-10$q$,$q$П$q$,'акт','2026-10-30',320400.0,5,$q$заплановано$q$),
($q$DEMO-10$q$,$q$П$q$,'документація','2026-10-16',NULL,8,NULL),
($q$DEMO-10$q$,$q$Р$q$,'акт','2026-12-18',427200.0,5,$q$заплановано$q$),
($q$DEMO-10$q$,$q$Р$q$,'документація','2026-12-04',NULL,8,NULL),
($q$22-24$q$,$q$Р$q$,'акт','2026-12-25',2084972.32,6,$q$заплановано$q$),
($q$22-24$q$,$q$Р$q$,'документація','2026-12-11',NULL,7,NULL),
($q$24-11$q$,$q$Р$q$,'акт','2026-12-04',697200.0,6,$q$заплановано$q$),
($q$24-11$q$,$q$Р$q$,'документація','2026-11-20',NULL,5,NULL),
($q$24-37$q$,$q$П$q$,'акт','2027-07-14',2875200.0,6,$q$заплановано$q$),
($q$24-37$q$,$q$П$q$,'документація','2027-06-30',NULL,6,NULL),
($q$24-37$q$,$q$Р$q$,'акт','2027-12-29',3009936.0,6,$q$заплановано$q$),
($q$24-37$q$,$q$Р$q$,'документація','2027-12-15',NULL,6,NULL),
($q$24-52$q$,$q$П$q$,'акт','2027-02-12',2040000.0,7,$q$заплановано$q$),
($q$24-52$q$,$q$П$q$,'документація','2027-01-29',NULL,7,NULL),
($q$24-52$q$,$q$Р$q$,'акт','2027-06-11',1904880.0,7,$q$заплановано$q$),
($q$24-52$q$,$q$Р$q$,'документація','2027-05-28',NULL,7,NULL)
) as v(pid, st, ev, d, sm, pr, stt) where ps.project_id=v.pid and ps."стадія"=v.st and ps."подія"=v.ev;
