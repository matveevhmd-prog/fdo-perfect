-- Відкат M4: видаляє чотири функції (дані не змінюються; плани, записані затвердженням, лишаються в project_metrics).
DROP FUNCTION IF EXISTS public.koshtorys_diff(uuid, bigint, bigint);
DROP FUNCTION IF EXISTS public.koshtorys_approve(uuid, bigint, bigint, jsonb);
DROP FUNCTION IF EXISTS public.koshtorys_preview(uuid, bigint, jsonb);
DROP FUNCTION IF EXISTS public.koshtorys_totals(uuid, bigint);
