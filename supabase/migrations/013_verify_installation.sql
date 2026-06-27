-- Verificação pós-instalação. Somente leitura.

with checks as (
  select 'public_tables'::text as check_name,
         (select count(*) from pg_tables where schemaname = 'public')::text as actual_value,
         '48 ou mais'::text as expected_value,
         (select count(*) from pg_tables where schemaname = 'public') >= 48 as passed
  union all
  select 'rls_policies',
         (select count(*) from pg_policies where schemaname = 'public')::text,
         '60 ou mais',
         (select count(*) from pg_policies where schemaname = 'public') >= 60
  union all
  select 'default_organization',
         (select count(*) from public.organizations where slug = 'lar-com-proposito')::text,
         '1',
         (select count(*) from public.organizations where slug = 'lar-com-proposito') = 1
  union all
  select 'system_roles',
         (select count(*) from public.roles where code in ('admin','instrutora','moderadora','atendimento','membro'))::text,
         '5',
         (select count(*) from public.roles where code in ('admin','instrutora','moderadora','atendimento','membro')) = 5
  union all
  select 'permissions',
         (select count(*) from public.permissions)::text,
         '30',
         (select count(*) from public.permissions) = 30
  union all
  select 'storage_buckets',
         (select count(*) from storage.buckets where id in ('brand-public','avatars','course-materials','community-media','documents-private','certificates'))::text,
         '6',
         (select count(*) from storage.buckets where id in ('brand-public','avatars','course-materials','community-media','documents-private','certificates')) = 6
  union all
  select 'auth_profile_trigger',
         (select count(*) from pg_trigger where tgname = 'on_auth_user_created' and not tgisinternal)::text,
         '1',
         (select count(*) from pg_trigger where tgname = 'on_auth_user_created' and not tgisinternal) = 1
  union all
  select 'auth_update_trigger',
         (select count(*) from pg_trigger where tgname = 'on_auth_user_updated' and not tgisinternal)::text,
         '1',
         (select count(*) from pg_trigger where tgname = 'on_auth_user_updated' and not tgisinternal) = 1
)
select check_name, actual_value, expected_value,
       case when passed then 'OK' else 'REVISAR' end as result
from checks
order by check_name;
