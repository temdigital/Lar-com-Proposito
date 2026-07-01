select
  to_regprocedure('public.get_member_events(boolean)') is not null as member_events_function_exists,
  has_function_privilege('authenticated', 'public.get_member_events(boolean)', 'EXECUTE') as authenticated_can_load_member_events,
  not has_function_privilege('anon', 'public.get_member_events(boolean)', 'EXECUTE') as anonymous_cannot_load_member_events,
  exists (select 1 from information_schema.columns where table_schema='public' and table_name='events' and column_name='meeting_url') as meeting_url_column_exists,
  exists (select 1 from information_schema.columns where table_schema='public' and table_name='events' and column_name='registration_mode') as registration_mode_column_exists,
  exists (select 1 from information_schema.columns where table_schema='public' and table_name='events' and column_name='registration_deadline') as registration_deadline_column_exists;
