-- Відкат 2026-11-01_evm_classic_f1b_functions.sql
DROP VIEW IF EXISTS public.evm_classic_today;
DROP FUNCTION IF EXISTS public.evm_classic_at(text, date);
DROP FUNCTION IF EXISTS public.evm_classic_indices(numeric, numeric, numeric, numeric);
