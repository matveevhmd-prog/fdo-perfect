-- Відкат міграції p15_negative_red_20261029: значення порогів до 29.10.2026 (live SQL перед зміною)
UPDATE public.archi_thresholds AS t SET value = v.value
FROM (VALUES ('etc_yellow',0.05),('etc_red',0.10),('slip_red_days',14),('rent_drop_pp',5),('rent_drop_pp_red',10),('profit_yellow_pct',5),('profit_red_pct',10)) AS v(key, value)
WHERE t.key = v.key;
