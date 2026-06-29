select
  to_regprocedure('public.register_for_event(uuid)') is not null as register_function_exists,
  to_regprocedure('public.cancel_event_registration(uuid)') is not null as cancel_function_exists,
  to_regprocedure('public.admin_update_event_registration(uuid,text)') is not null as update_registration_function_exists,
  to_regprocedure('public.get_member_events(boolean)') is not null as member_feed_function_exists,
  has_function_privilege('authenticated','public.register_for_event(uuid)','EXECUTE') as authenticated_can_register,
  has_function_privilege('authenticated','public.cancel_event_registration(uuid)','EXECUTE') as authenticated_can_cancel,
  not has_function_privilege('anon','public.register_for_event(uuid)','EXECUTE') as anonymous_cannot_register,
  not has_function_privilege('anon','public.cancel_event_registration(uuid)','EXECUTE') as anonymous_cannot_cancel,
  to_regclass('public.event_private_details') is not null as private_details_table_exists,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='events' and column_name='is_members_only') as members_only_column_exists,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='events' and column_name='waitlist_enabled') as waitlist_column_exists,
  (select count(*) from pg_policies where schemaname='public' and tablename='event_registrations' and policyname='event_registrations_insert')=0 as direct_insert_blocked;
