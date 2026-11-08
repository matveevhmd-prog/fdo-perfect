DELETE FROM public.company_thresholds
WHERE company_id = '00000000-0000-4000-8000-000000000001'
  AND key IN ('plan_year_projects','plan_year_hours','plan_year_profit','plan_year_contract');
