-- Lar com Propósito — auditoria consolidada e somente leitura
-- Retorna uma única tabela exportável no SQL Editor do Supabase.
-- Não cria, altera ou exclui objetos.

with audit as (
  -- 01. Ambiente
  select
    10 as section_order,
    'ambiente'::text as category,
    current_database()::text as object_name,
    jsonb_build_object(
      'database_name', current_database(),
      'execution_user', current_user,
      'postgres_version', version(),
      'audited_at', now()
    ) as details

  union all

  -- 02. Extensões
  select
    20,
    'extensao',
    e.extname,
    jsonb_build_object(
      'name', e.extname,
      'version', e.extversion,
      'schema', n.nspname
    )
  from pg_extension e
  join pg_namespace n on n.oid = e.extnamespace

  union all

  -- 03. Tabelas da aplicação no schema public
  select
    30,
    'tabela_publica',
    c.relname,
    jsonb_build_object(
      'schema', n.nspname,
      'table', c.relname,
      'estimated_rows', c.reltuples::bigint,
      'rls_enabled', c.relrowsecurity,
      'rls_forced', c.relforcerowsecurity,
      'kind', case c.relkind when 'r' then 'table' when 'p' then 'partitioned_table' else c.relkind::text end
    )
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where c.relkind in ('r','p')
    and n.nspname = 'public'

  union all

  -- 04. Colunas das tabelas públicas
  select
    40,
    'coluna_publica',
    format('%I.%I', cols.table_name, cols.column_name),
    jsonb_build_object(
      'schema', cols.table_schema,
      'table', cols.table_name,
      'position', cols.ordinal_position,
      'column', cols.column_name,
      'data_type', cols.data_type,
      'udt_name', cols.udt_name,
      'nullable', cols.is_nullable,
      'default', cols.column_default
    )
  from information_schema.columns cols
  where cols.table_schema = 'public'

  union all

  -- 05. Constraints públicas
  select
    50,
    'constraint_publica',
    format('%I.%I', c.relname, con.conname),
    jsonb_build_object(
      'schema', n.nspname,
      'table', c.relname,
      'constraint_name', con.conname,
      'constraint_type', case con.contype
        when 'p' then 'PRIMARY KEY'
        when 'u' then 'UNIQUE'
        when 'c' then 'CHECK'
        when 'f' then 'FOREIGN KEY'
        when 'x' then 'EXCLUSION'
        else con.contype::text
      end,
      'definition', pg_get_constraintdef(con.oid, true)
    )
  from pg_constraint con
  join pg_class c on c.oid = con.conrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'

  union all

  -- 06. Índices públicos
  select
    60,
    'indice_publico',
    format('%I.%I', idx.tablename, idx.indexname),
    jsonb_build_object(
      'schema', idx.schemaname,
      'table', idx.tablename,
      'index_name', idx.indexname,
      'definition', idx.indexdef
    )
  from pg_indexes idx
  where idx.schemaname = 'public'

  union all

  -- 07. Triggers públicos
  select
    70,
    'trigger_publico',
    format('%I.%I', t.event_object_table, t.trigger_name),
    jsonb_build_object(
      'schema', t.event_object_schema,
      'table', t.event_object_table,
      'trigger_name', t.trigger_name,
      'timing', t.action_timing,
      'event', t.event_manipulation,
      'statement', t.action_statement
    )
  from information_schema.triggers t
  where t.event_object_schema = 'public'

  union all

  -- 08. Funções públicas
  select
    80,
    'funcao_publica',
    format('%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid)),
    jsonb_build_object(
      'schema', n.nspname,
      'function_name', p.proname,
      'arguments', pg_get_function_identity_arguments(p.oid),
      'return_type', pg_get_function_result(p.oid),
      'security_definer', p.prosecdef,
      'volatility', p.provolatile,
      'runtime_config', p.proconfig
    )
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'

  union all

  -- 09. Policies RLS públicas
  select
    90,
    'policy_publica',
    format('%I.%I', pol.tablename, pol.policyname),
    jsonb_build_object(
      'schema', pol.schemaname,
      'table', pol.tablename,
      'policy_name', pol.policyname,
      'permissive', pol.permissive,
      'roles', pol.roles,
      'command', pol.cmd,
      'using_expression', pol.qual,
      'with_check', pol.with_check
    )
  from pg_policies pol
  where pol.schemaname = 'public'

  union all

  -- 10. ENUMs públicos
  select
    100,
    'enum_publico',
    t.typname,
    jsonb_build_object(
      'schema', n.nspname,
      'enum_name', t.typname,
      'values', jsonb_agg(e.enumlabel order by e.enumsortorder)
    )
  from pg_type t
  join pg_namespace n on n.oid = t.typnamespace
  join pg_enum e on e.enumtypid = t.oid
  where n.nspname = 'public'
  group by n.nspname, t.typname

  union all

  -- 11. Views públicas
  select
    110,
    'view_publica',
    v.viewname,
    jsonb_build_object(
      'schema', v.schemaname,
      'view_name', v.viewname,
      'definition', v.definition
    )
  from pg_views v
  where v.schemaname = 'public'

  union all

  -- 12. Materialized views públicas
  select
    120,
    'materialized_view_publica',
    mv.matviewname,
    jsonb_build_object(
      'schema', mv.schemaname,
      'view_name', mv.matviewname,
      'populated', mv.ispopulated,
      'definition', mv.definition
    )
  from pg_matviews mv
  where mv.schemaname = 'public'

  union all

  -- 13. Buckets do Storage
  select
    130,
    'storage_bucket',
    b.name,
    jsonb_build_object(
      'id', b.id,
      'name', b.name,
      'public', b.public,
      'file_size_limit', b.file_size_limit,
      'allowed_mime_types', b.allowed_mime_types,
      'created_at', b.created_at,
      'updated_at', b.updated_at
    )
  from storage.buckets b

  union all

  -- 14. Resumo seguro do Auth
  select
    140,
    'auth_resumo',
    'auth.users',
    jsonb_build_object(
      'auth_users', count(*),
      'confirmed_users', count(*) filter (where email_confirmed_at is not null),
      'currently_banned_users', count(*) filter (where banned_until is not null and banned_until > now()),
      'first_user_created_at', min(created_at),
      'last_user_created_at', max(created_at)
    )
  from auth.users

  union all

  -- 15. Contagem dos principais schemas gerenciados pelo Supabase
  select
    150,
    'schema_resumo',
    n.nspname,
    jsonb_build_object(
      'schema', n.nspname,
      'tables', count(*) filter (where c.relkind in ('r','p')),
      'views', count(*) filter (where c.relkind in ('v','m')),
      'sequences', count(*) filter (where c.relkind = 'S')
    )
  from pg_namespace n
  left join pg_class c on c.relnamespace = n.oid
  where n.nspname in ('public','auth','storage','realtime','vault','extensions','supabase_functions')
  group by n.nspname
)
select
  category,
  object_name,
  details
from audit
order by section_order, category, object_name;
