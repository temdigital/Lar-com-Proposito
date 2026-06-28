-- PROMOÇÃO MANUAL DA PRIMEIRA ADMINISTRADORA
-- 1. Crie a conta pelo site e confirme o e-mail.
-- 2. Substitua ADMIN_EMAIL_AQUI pelo e-mail exato da conta.
-- 3. Execute este arquivo inteiro no SQL Editor do Supabase.

begin;

do $$
declare
  v_email text := lower(trim('ADMIN_EMAIL_AQUI'));
  v_user_id uuid;
  v_member_id uuid;
  v_roles_found integer;
  v_organization_id constant uuid := '11111111-1111-4111-8111-111111111111';
begin
  if v_email = 'admin_email_aqui' or position('@' in v_email) < 2 then
    raise exception 'Substitua ADMIN_EMAIL_AQUI por um e-mail válido antes de executar.';
  end if;

  select u.id
    into v_user_id
  from auth.users u
  where lower(u.email) = v_email;

  if v_user_id is null then
    raise exception 'Nenhuma conta foi encontrada para o e-mail informado.';
  end if;

  if not exists (
    select 1
    from auth.users u
    where u.id = v_user_id
      and u.email_confirmed_at is not null
  ) then
    raise exception 'A conta existe, mas o e-mail ainda não foi confirmado.';
  end if;

  select count(*)
    into v_roles_found
  from public.roles r
  where r.code in ('admin', 'membro');

  if v_roles_found <> 2 then
    raise exception 'Os papéis admin e membro precisam existir antes da promoção.';
  end if;

  update public.profiles
  set status = 'active',
      updated_at = now()
  where id = v_user_id;

  insert into public.organization_members (
    organization_id,
    profile_id,
    job_title,
    status,
    joined_at
  ) values (
    v_organization_id,
    v_user_id,
    'Administradora',
    'active',
    now()
  )
  on conflict (organization_id, profile_id) do update
  set job_title = excluded.job_title,
      status = 'active',
      joined_at = coalesce(public.organization_members.joined_at, now()),
      deleted_at = null,
      updated_at = now()
  returning id into v_member_id;

  insert into public.member_roles (
    organization_id,
    organization_member_id,
    role_id,
    assigned_by
  )
  select
    v_organization_id,
    v_member_id,
    r.id,
    v_user_id
  from public.roles r
  where r.code in ('admin', 'membro')
  on conflict (organization_member_id, role_id) do update
  set revoked_at = null,
      assigned_by = excluded.assigned_by,
      assigned_at = now();

  insert into public.audit_logs (
    organization_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    new_data
  ) values (
    v_organization_id,
    v_user_id,
    'first_admin_promoted',
    'organization_member',
    v_member_id::text,
    jsonb_build_object(
      'email', v_email,
      'roles', jsonb_build_array('admin', 'membro')
    )
  );
end $$;

commit;

-- Conferência final: deve retornar exatamente os papéis admin e membro.
select
  p.email,
  p.status as profile_status,
  om.status as member_status,
  om.job_title,
  r.code as role_code,
  r.name as role_name
from public.profiles p
join public.organization_members om on om.profile_id = p.id
join public.member_roles mr on mr.organization_member_id = om.id and mr.revoked_at is null
join public.roles r on r.id = mr.role_id
where lower(p.email) = lower(trim('ADMIN_EMAIL_AQUI'))
  and r.code in ('admin', 'membro')
order by r.code;
