select
  to_regprocedure('public.admin_save_event(uuid,text,text,text,text,text,text,text,timestamptz,timestamptz,integer,numeric,text,text,boolean,text,timestamptz,text,text)') is not null as save_event_function_exists,
  to_regprocedure('public.admin_archive_event(uuid)') is not null as archive_event_function_exists,
  to_regprocedure('public.register_for_event(uuid)') is not null as register_event_function_exists,
  has_function_privilege('authenticated','public.admin_save_event(uuid,text,text,text,text,text,text,text,timestamptz,timestamptz,integer,numeric,text,text,boolean,text,timestamptz,text,text)','EXECUTE') as authenticated_can_save_event,
  has_function_privilege('authenticated','public.admin_archive_event(uuid)','EXECUTE') as authenticated_can_archive_event,
  has_function_privilege('authenticated','public.register_for_event(uuid)','EXECUTE') as authenticated_can_register_event,
  not has_function_privilege('anon','public.admin_save_event(uuid,text,text,text,text,text,text,text,timestamptz,timestamptz,integer,numeric,text,text,boolean,text,timestamptz,text,text)','EXECUTE') as anonymous_cannot_save_event,
  not has_function_privilege('anon','public.admin_archive_event(uuid)','EXECUTE') as anonymous_cannot_archive_event,
  not has_function_privilege('anon','public.register_for_event(uuid)','EXECUTE') as anonymous_cannot_register_event,
  exists (select 1 from information_schema.columns where table_schema='public' and table_name='events' and column_name='is_featured') as featured_column_exists,
  exists (select 1 from information_schema.columns where table_schema='public' and table_name='events' and column_name='registration_mode') as registration_mode_column_exists,
  exists (select 1 from information_schema.columns where table_schema='public' and table_name='events' and column_name='seo_title') as seo_title_column_exists;
