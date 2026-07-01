select
  to_regprocedure('public.get_member_events(boolean)') is not null as member_events_function_exists,
  has_function_privilege('authenticated', 'public.get_member_events(boolean)', 'EXECUTE') as authenticated_can_load_member_events,
  not has_function_privilege('anon', 'public.get_member_events(boolean)', 'EXECUTE') as anonymous_cannot_load_member_events,
  to_regclass('public.event_private_details') is not null as private_details_table_exists,
  exists (select 1 from information_schema.columns where table_schema='public' and table_name='events' and column_name='is_members_only') as members_only_column_exists,
  exists (select 1 from information_schema.columns where table_schema='public' and table_name='events' and column_name='registration_required') as registration_required_column_exists,
  exists (select 1 from information_schema.columns where table_schema='public' and table_name='events' and column_name='registration_opens_at') as registration_opens_column_exists,
  exists (select 1 from information_schema.columns where table_schema='public' and table_name='events' and column_name='waitlist_enabled') as waitlist_column_exists,
  not has_table_privilege('anon', 'public.event_private_details', 'SELECT') as anonymous_cannot_read_private_details,
  not has_table_privilege('authenticated', 'public.event_private_details', 'SELECT') as authenticated_cannot_read_private_details_directly,
  not exists (select 1 from public.events where meeting_url is not null) as public_meeting_urls_cleared;
