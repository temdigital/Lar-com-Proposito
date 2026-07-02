select
  has_function_privilege('authenticated','public.save_club_plan(uuid,text,text,text,text,numeric,integer,text,jsonb,jsonb)','EXECUTE') as authenticated_can_save_plan,
  has_function_privilege('authenticated','public.assign_manual_subscription(uuid,uuid,text,timestamptz,timestamptz,text)','EXECUTE') as authenticated_can_assign_subscription,
  has_function_privilege('authenticated','public.manage_manual_subscription(uuid,text,timestamptz,boolean,text)','EXECUTE') as authenticated_can_manage_subscription,
  has_function_privilege('authenticated','public.reconcile_manual_subscriptions()','EXECUTE') as authenticated_can_reconcile,
  not has_function_privilege('authenticated','public.sync_subscription_access(uuid)','EXECUTE') as authenticated_cannot_sync_access_directly,
  not has_function_privilege('anon','public.sync_subscription_access(uuid)','EXECUTE') as anonymous_cannot_sync_access,
  not has_function_privilege('anon','public.save_club_plan(uuid,text,text,text,text,numeric,integer,text,jsonb,jsonb)','EXECUTE') as anonymous_cannot_save_plan,
  not has_function_privilege('anon','public.assign_manual_subscription(uuid,uuid,text,timestamptz,timestamptz,text)','EXECUTE') as anonymous_cannot_assign_subscription,
  not has_function_privilege('anon','public.manage_manual_subscription(uuid,text,timestamptz,boolean,text)','EXECUTE') as anonymous_cannot_manage_subscription,
  not has_function_privilege('anon','public.reconcile_manual_subscriptions()','EXECUTE') as anonymous_cannot_reconcile;
