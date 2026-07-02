select
  to_regclass('public.plan_access_rules') is not null as plan_access_rules_table_exists,
  coalesce((select relrowsecurity from pg_class where oid = 'public.plan_access_rules'::regclass), false) as plan_access_rules_rls_enabled,
  exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'plan_access_rules' and policyname = 'plan_access_rules_read'
  ) as plan_access_rules_read_policy_exists,
  to_regprocedure('public.sync_subscription_access(uuid)') is not null as sync_access_function_exists,
  to_regprocedure('public.save_club_plan(uuid,text,text,text,text,numeric,integer,text,jsonb,jsonb)') is not null as save_plan_function_exists,
  to_regprocedure('public.assign_manual_subscription(uuid,uuid,text,timestamptz,timestamptz,text)') is not null as assign_subscription_function_exists,
  to_regprocedure('public.manage_manual_subscription(uuid,text,timestamptz,boolean,text)') is not null as manage_subscription_function_exists,
  to_regprocedure('public.reconcile_manual_subscriptions()') is not null as reconcile_function_exists,
  has_function_privilege('authenticated','public.save_club_plan(uuid,text,text,text,text,numeric,integer,text,jsonb,jsonb)','EXECUTE') as authenticated_can_save_plan,
  has_function_privilege('authenticated','public.assign_manual_subscription(uuid,uuid,text,timestamptz,timestamptz,text)','EXECUTE') as authenticated_can_assign_subscription,
  has_function_privilege('authenticated','public.manage_manual_subscription(uuid,text,timestamptz,boolean,text)','EXECUTE') as authenticated_can_manage_subscription,
  has_function_privilege('authenticated','public.reconcile_manual_subscriptions()','EXECUTE') as authenticated_can_reconcile,
  not has_function_privilege('anon','public.sync_subscription_access(uuid)','EXECUTE') as anonymous_cannot_sync_access,
  not has_function_privilege('anon','public.save_club_plan(uuid,text,text,text,text,numeric,integer,text,jsonb,jsonb)','EXECUTE') as anonymous_cannot_save_plan,
  not has_function_privilege('anon','public.assign_manual_subscription(uuid,uuid,text,timestamptz,timestamptz,text)','EXECUTE') as anonymous_cannot_assign_subscription,
  not has_function_privilege('anon','public.manage_manual_subscription(uuid,text,timestamptz,boolean,text)','EXECUTE') as anonymous_cannot_manage_subscription,
  not has_function_privilege('anon','public.reconcile_manual_subscriptions()','EXECUTE') as anonymous_cannot_reconcile,
  not has_table_privilege('authenticated','public.plans','INSERT') as direct_plan_insert_blocked,
  not has_table_privilege('authenticated','public.plan_features','INSERT') as direct_feature_insert_blocked,
  not has_table_privilege('authenticated','public.plan_access_rules','INSERT') as direct_access_rule_insert_blocked,
  not has_table_privilege('authenticated','public.subscriptions','INSERT') as direct_subscription_insert_blocked,
  not has_table_privilege('authenticated','public.subscriptions','UPDATE') as direct_subscription_update_blocked,
  not has_table_privilege('authenticated','public.subscription_events','INSERT') as direct_subscription_event_insert_blocked,
  not has_table_privilege('authenticated','public.access_grants','INSERT') as direct_access_grant_insert_blocked,
  not has_table_privilege('authenticated','public.access_grants','UPDATE') as direct_access_grant_update_blocked;
