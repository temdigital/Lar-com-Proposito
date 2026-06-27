-- Lar com Propósito — auditoria somente leitura
-- Execute no SQL Editor do Supabase antes de qualquer migration estrutural.
-- Este arquivo não cria, altera ou exclui objetos.

-- 1. Identificação do ambiente
select
  current_database() as database_name,
  current_user as execution_user,
  version() as postgres_version,
  now() as audited_at;

-- 2. Extensões instaladas
select extname, extversion
from pg_extension
order by extname;

-- 3. Tabelas existentes e estimativa de registros
select
  n.nspname as schema_name,
  c.relname as table_name,
  c.reltuples::bigint as estimated_rows,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind in ('r','p')
  and n.nspname not in ('pg_catalog','information_schema')
order by n.nspname, c.relname;

-- 4. Colunas, tipos, nulabilidade e valores padrão
select
  table_schema,
  table_name,
  ordinal_position,
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema not in ('pg_catalog','information_schema')
order by table_schema, table_name, ordinal_position;

-- 5. Chaves primárias e constraints UNIQUE/CHECK
select
  n.nspname as schema_name,
  c.relname as table_name,
  con.conname as constraint_name,
  case con.contype
    when 'p' then 'PRIMARY KEY'
    when 'u' then 'UNIQUE'
    when 'c' then 'CHECK'
    when 'x' then 'EXCLUSION'
    else con.contype::text
  end as constraint_type,
  pg_get_constraintdef(con.oid, true) as definition
from pg_constraint con
join pg_class c on c.oid = con.conrelid
join pg_namespace n on n.oid = c.relnamespace
where con.contype in ('p','u','c','x')
  and n.nspname not in ('pg_catalog','information_schema')
order by n.nspname, c.relname, con.conname;

-- 6. Chaves estrangeiras
select
  src_ns.nspname as source_schema,
  src.relname as source_table,
  con.conname as constraint_name,
  pg_get_constraintdef(con.oid, true) as definition,
  tgt_ns.nspname as target_schema,
  tgt.relname as target_table
from pg_constraint con
join pg_class src on src.oid = con.conrelid
join pg_namespace src_ns on src_ns.oid = src.relnamespace
join pg_class tgt on tgt.oid = con.confrelid
join pg_namespace tgt_ns on tgt_ns.oid = tgt.relnamespace
where con.contype = 'f'
order by src_ns.nspname, src.relname, con.conname;

-- 7. Índices
select
  schemaname as schema_name,
  tablename as table_name,
  indexname as index_name,
  indexdef as definition
from pg_indexes
where schemaname not in ('pg_catalog','information_schema')
order by schemaname, tablename, indexname;

-- 8. Triggers de usuário
select
  event_object_schema as schema_name,
  event_object_table as table_name,
  trigger_name,
  action_timing,
  event_manipulation,
  action_statement
from information_schema.triggers
where event_object_schema not in ('pg_catalog','information_schema')
order by event_object_schema, event_object_table, trigger_name;

-- 9. Funções dos schemas da aplicação
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as return_type,
  p.prosecdef as security_definer,
  p.provolatile as volatility,
  p.proconfig as runtime_config
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname not in ('pg_catalog','information_schema')
order by n.nspname, p.proname;

-- 10. Policies RLS
select
  schemaname as schema_name,
  tablename as table_name,
  policyname as policy_name,
  permissive,
  roles,
  cmd,
  qual as using_expression,
  with_check
from pg_policies
order by schemaname, tablename, policyname;

-- 11. Tipos ENUM personalizados
select
  n.nspname as schema_name,
  t.typname as enum_name,
  string_agg(e.enumlabel, ', ' order by e.enumsortorder) as values
from pg_type t
join pg_namespace n on n.oid = t.typnamespace
join pg_enum e on e.enumtypid = t.oid
where n.nspname not in ('pg_catalog','information_schema')
group by n.nspname, t.typname
order by n.nspname, t.typname;

-- 12. Buckets do Supabase Storage
select id, name, public, file_size_limit, allowed_mime_types, created_at, updated_at
from storage.buckets
order by name;

-- 13. Resumo seguro do Auth, sem expor dados pessoais
select
  count(*) as auth_users,
  count(*) filter (where email_confirmed_at is not null) as confirmed_users,
  count(*) filter (where banned_until is not null and banned_until > now()) as currently_banned_users,
  min(created_at) as first_user_created_at,
  max(created_at) as last_user_created_at
from auth.users;

-- 14. Views e materialized views
select schemaname as schema_name, viewname as object_name, 'VIEW' as object_type
from pg_views
where schemaname not in ('pg_catalog','information_schema')
union all
select schemaname, matviewname, 'MATERIALIZED VIEW'
from pg_matviews
where schemaname not in ('pg_catalog','information_schema')
order by schema_name, object_name;
