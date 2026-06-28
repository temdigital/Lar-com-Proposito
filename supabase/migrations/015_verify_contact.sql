select
  to_regclass('public.contact_messages') is not null as table_exists,
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'contact_messages') as policy_count,
  has_table_privilege('anon', 'public.contact_messages', 'INSERT') as anon_can_insert,
  has_table_privilege('authenticated', 'public.contact_messages', 'SELECT') as authenticated_can_select,
  has_table_privilege('authenticated', 'public.contact_messages', 'UPDATE') as authenticated_can_update;
