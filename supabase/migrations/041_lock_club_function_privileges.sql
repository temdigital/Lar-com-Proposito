begin;

-- No Supabase, revogar de PUBLIC não substitui a revogação explícita do papel anon.
-- Mantemos apenas authenticated nas funções administrativas e nenhuma execução
-- direta na função interna de sincronização.
revoke execute on function public.sync_subscription_access(uuid) from public, anon, authenticated;
revoke execute on function public.save_club_plan(uuid,text,text,text,text,numeric,integer,text,jsonb,jsonb) from public, anon, authenticated;
revoke execute on function public.assign_manual_subscription(uuid,uuid,text,timestamptz,timestamptz,text) from public, anon, authenticated;
revoke execute on function public.manage_manual_subscription(uuid,text,timestamptz,boolean,text) from public, anon, authenticated;
revoke execute on function public.reconcile_manual_subscriptions() from public, anon, authenticated;

grant execute on function public.save_club_plan(uuid,text,text,text,text,numeric,integer,text,jsonb,jsonb) to authenticated;
grant execute on function public.assign_manual_subscription(uuid,uuid,text,timestamptz,timestamptz,text) to authenticated;
grant execute on function public.manage_manual_subscription(uuid,text,timestamptz,boolean,text) to authenticated;
grant execute on function public.reconcile_manual_subscriptions() to authenticated;

commit;
