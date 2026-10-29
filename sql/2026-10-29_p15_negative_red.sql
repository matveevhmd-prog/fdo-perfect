-- CLAUDE.md п. 15 (власник, 29.10.2026, «варіант 1»): будь-яка від'ємна розбіжність з планом — 🔴, жовтого для перевитрат немає.
-- Розбіжність = план − (факт + прогноз). Пороги «гірше за план» = 0; порівняння строгі (SQL archi_vac_signal / archi_etc_gap_signal — «>»,
-- n8n Build MiniApp Data / AN: Attach Block — «>» по округленому до 0,1 значенню), тож «рівно за планом» лишається 🟢.
-- Не змінюються: індекси (idx_*, cpi_*), неоплата (unpaid_*), ймовірність документації (doc_prob_*), дні блокера, виконання плану тижня.
UPDATE public.archi_thresholds SET value = 0
WHERE key IN ('etc_yellow','etc_red','slip_red_days','rent_drop_pp','rent_drop_pp_red','profit_yellow_pct','profit_red_pct');
