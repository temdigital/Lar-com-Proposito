begin;

create or replace function public.admin_update_member(
  p_member_id uuid,
  p_first_name text,
  p_last_name text default null,
  p_whatsapp text default null,
  p_job_title text default null,
  p_status text default 'active',
  p_role_codes text[] default array['membro']::text[]
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_organization_id uuid;
  v_profile_id uuid;
  v_current_is_admin boolean;
  v_requested_is_admin boolean;
  v_other_active_admins integer;
  v_role_codes text[];
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select om.organization_id, om.profile_id
    into v_organization_id, v_profile_id
  from public.organization_members om
  where om.id = p_member_id
  for update;

  if v_profile_id is null then
    raise exception 'Vínculo não encontrado.';
  end if;

  if not public.has_permission(v_organization_id, 'users.manage')
     or not public.has_permission(v_organization_id, 'roles.manage') then
    raise exception 'Você não possui permissão para administrar pessoas e papéis.';
  end if;

  if p_status not in ('active', 'suspended', 'removed') then
    raise exception 'Situação de vínculo inválida.';
  end if;

  if v_profile_id = auth.uid() and p_status <> 'active' then
    raise exception 'Você não pode suspender ou remover o próprio acesso.';
  end if;

  select coalesce(array_agg(distinct lower(trim(code))) filter (where trim(code) <> ''), array[]::text[])
    into v_role_codes
  from unnest(coalesce(p_role_codes, array[]::text[])) as code;

  if p_status <> 'removed' and not ('membro' = any(v_role_codes)) then
    v_role_codes := array_append(v_role_codes, 'membro');
  end if;

  if exists (
    select 1
    from unnest(v_role_codes) requested(code)
    left join public.roles r on r.code = requested.code
    where r.id is null
  ) then
    raise exception 'Um ou mais papéis informados não existem.';
  end if;

  select exists (
    select 1
    from public.member_roles mr
    join public.roles r on r.id = mr.role_id
    where mr.organization_member_id = p_member_id
      and mr.revoked_at is null
      and r.code = 'admin'
  ) into v_current_is_admin;

  v_requested_is_admin := 'admin' = any(v_role_codes) and p_status <> 'removed';

  if v_profile_id = auth.uid() and v_current_is_admin and not v_requested_is_admin then
    raise exception 'Você não pode remover o próprio papel de administradora.';
  end if;

  if v_current_is_admin and not v_requested_is_admin then
    select count(*)
      into v_other_active_admins
    from public.organization_members om
    join public.member_roles mr
      on mr.organization_member_id = om.id
     and mr.organization_id = om.organization_id
     and mr.revoked_at is null
    join public.roles r on r.id = mr.role_id and r.code = 'admin'
    where om.organization_id = v_organization_id
      and om.id <> p_member_id
      and om.status = 'active'
      and om.deleted_at is null;

    if v_other_active_admins = 0 then
      raise exception 'A organização precisa manter ao menos uma administradora ativa.';
    end if;
  end if;

  update public.profiles
  set first_name = coalesce(nullif(trim(p_first_name), ''), first_name),
      last_name = nullif(trim(coalesce(p_last_name, '')), ''),
      whatsapp = nullif(trim(coalesce(p_whatsapp, '')), ''),
      updated_at = now()
  where id = v_profile_id;

  update public.organization_members
  set job_title = nullif(trim(coalesce(p_job_title, '')), ''),
      status = p_status,
      joined_at = case when p_status = 'active' then coalesce(joined_at, now()) else joined_at end,
      deleted_at = case when p_status = 'removed' then now() else null end,
      updated_at = now()
  where id = p_member_id;

  if p_status = 'removed' then
    update public.member_roles
    set revoked_at = coalesce(revoked_at, now())
    where organization_member_id = p_member_id
      and revoked_at is null;
  else
    insert into public.member_roles (
      organization_id,
      organization_member_id,
      role_id,
      assigned_by
    )
    select
      v_organization_id,
      p_member_id,
      r.id,
      auth.uid()
    from public.roles r
    where r.code = any(v_role_codes)
    on conflict (organization_member_id, role_id) do update
    set revoked_at = null,
        assigned_by = excluded.assigned_by,
        assigned_at = now();

    update public.member_roles mr
    set revoked_at = now()
    where mr.organization_member_id = p_member_id
      and mr.revoked_at is null
      and not exists (
        select 1
        from public.roles r
        where r.id = mr.role_id
          and r.code = any(v_role_codes)
      );
  end if;

  insert into public.audit_logs (
    organization_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    new_data
  ) values (
    v_organization_id,
    auth.uid(),
    'organization_member_updated',
    'organization_member',
    p_member_id::text,
    jsonb_build_object(
      'status', p_status,
      'roles', to_jsonb(v_role_codes),
      'job_title', nullif(trim(coalesce(p_job_title, '')), '')
    )
  );

  return jsonb_build_object(
    'member_id', p_member_id,
    'profile_id', v_profile_id,
    'status', p_status,
    'roles', to_jsonb(v_role_codes)
  );
end;
$$;

create or replace function public.admin_create_invitation(
  p_name text,
  p_email text,
  p_whatsapp text default null,
  p_role_code text default 'membro',
  p_job_title text default null,
  p_message text default null,
  p_expires_days integer default 7
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_organization_id uuid;
  v_invitation_id uuid;
  v_token text;
  v_token_hash text;
  v_expires_at timestamptz;
  v_email text := lower(trim(p_email));
  v_role_code text := lower(trim(p_role_code));
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select om.organization_id
    into v_organization_id
  from public.organization_members om
  where om.profile_id = auth.uid()
    and om.status = 'active'
    and om.deleted_at is null
  limit 1;

  if v_organization_id is null or not public.has_permission(v_organization_id, 'users.invite') then
    raise exception 'Você não possui permissão para criar convites.';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'Informe o nome da pessoa convidada.';
  end if;

  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$' then
    raise exception 'Informe um e-mail válido.';
  end if;

  if not exists (select 1 from public.roles where code = v_role_code) then
    raise exception 'Papel de acesso inválido.';
  end if;

  if v_role_code = 'admin' and not public.has_permission(v_organization_id, 'roles.manage') then
    raise exception 'Você não possui permissão para convidar administradoras.';
  end if;

  update public.invitations
  set status = 'revoked',
      updated_at = now()
  where organization_id = v_organization_id
    and lower(email) = v_email
    and status = 'pending';

  v_token := encode(extensions.gen_random_bytes(24), 'hex');
  v_token_hash := encode(extensions.digest(v_token, 'sha256'), 'hex');
  v_expires_at := now() + make_interval(days => greatest(1, least(coalesce(p_expires_days, 7), 30)));

  insert into public.invitations (
    organization_id,
    name,
    email,
    whatsapp,
    role_code,
    job_title,
    message,
    token_hash,
    status,
    expires_at,
    created_by
  ) values (
    v_organization_id,
    trim(p_name),
    v_email,
    nullif(trim(coalesce(p_whatsapp, '')), ''),
    v_role_code,
    nullif(trim(coalesce(p_job_title, '')), ''),
    nullif(trim(coalesce(p_message, '')), ''),
    v_token_hash,
    'pending',
    v_expires_at,
    auth.uid()
  )
  returning id into v_invitation_id;

  insert into public.audit_logs (
    organization_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    new_data
  ) values (
    v_organization_id,
    auth.uid(),
    'invitation_created',
    'invitation',
    v_invitation_id::text,
    jsonb_build_object('email', v_email, 'role_code', v_role_code, 'expires_at', v_expires_at)
  );

  return jsonb_build_object(
    'invitation_id', v_invitation_id,
    'token', v_token,
    'email', v_email,
    'role_code', v_role_code,
    'expires_at', v_expires_at
  );
end;
$$;

create or replace function public.admin_revoke_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_organization_id uuid;
begin
  select i.organization_id
    into v_organization_id
  from public.invitations i
  where i.id = p_invitation_id
  for update;

  if v_organization_id is null then
    raise exception 'Convite não encontrado.';
  end if;

  if not public.has_permission(v_organization_id, 'users.invite') then
    raise exception 'Você não possui permissão para revogar convites.';
  end if;

  update public.invitations
  set status = 'revoked',
      updated_at = now()
  where id = p_invitation_id
    and status = 'pending';

  insert into public.audit_logs (
    organization_id,
    actor_id,
    action,
    entity_type,
    entity_id
  ) values (
    v_organization_id,
    auth.uid(),
    'invitation_revoked',
    'invitation',
    p_invitation_id::text
  );
end;
$$;

create or replace function public.get_invitation_preview(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_invitation public.invitations%rowtype;
  v_organization_name text;
  v_role_name text;
begin
  select i.*
    into v_invitation
  from public.invitations i
  where i.token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex')
  limit 1;

  if v_invitation.id is null then
    return jsonb_build_object('valid', false, 'reason', 'not_found');
  end if;

  if v_invitation.status <> 'pending' then
    return jsonb_build_object('valid', false, 'reason', v_invitation.status);
  end if;

  if v_invitation.expires_at <= now() then
    return jsonb_build_object('valid', false, 'reason', 'expired');
  end if;

  select o.name into v_organization_name
  from public.organizations o
  where o.id = v_invitation.organization_id;

  select r.name into v_role_name
  from public.roles r
  where r.code = v_invitation.role_code;

  return jsonb_build_object(
    'valid', true,
    'invitation_id', v_invitation.id,
    'name', v_invitation.name,
    'email', v_invitation.email,
    'whatsapp', v_invitation.whatsapp,
    'role_code', v_invitation.role_code,
    'role_name', v_role_name,
    'job_title', v_invitation.job_title,
    'message', v_invitation.message,
    'organization_name', v_organization_name,
    'expires_at', v_invitation.expires_at
  );
end;
$$;

create or replace function public.accept_invitation(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_invitation public.invitations%rowtype;
  v_user_email text;
  v_member_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Entre na sua conta para aceitar o convite.';
  end if;

  select i.*
    into v_invitation
  from public.invitations i
  where i.token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex')
  for update;

  if v_invitation.id is null then
    raise exception 'Convite não encontrado.';
  end if;

  if v_invitation.status <> 'pending' then
    raise exception 'Este convite não está mais disponível.';
  end if;

  if v_invitation.expires_at <= now() then
    update public.invitations set status = 'expired', updated_at = now() where id = v_invitation.id;
    raise exception 'Este convite expirou.';
  end if;

  select lower(u.email)
    into v_user_email
  from auth.users u
  where u.id = auth.uid();

  if v_user_email is distinct from lower(v_invitation.email) then
    raise exception 'Entre com a conta correspondente ao e-mail do convite.';
  end if;

  update public.profiles
  set status = 'active',
      updated_at = now()
  where id = auth.uid();

  insert into public.organization_members (
    organization_id,
    profile_id,
    job_title,
    status,
    joined_at
  ) values (
    v_invitation.organization_id,
    auth.uid(),
    v_invitation.job_title,
    'active',
    now()
  )
  on conflict (organization_id, profile_id) do update
  set job_title = coalesce(excluded.job_title, public.organization_members.job_title),
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
    v_invitation.organization_id,
    v_member_id,
    r.id,
    v_invitation.created_by
  from public.roles r
  where r.code in ('membro', v_invitation.role_code)
  on conflict (organization_member_id, role_id) do update
  set revoked_at = null,
      assigned_by = excluded.assigned_by,
      assigned_at = now();

  update public.invitations
  set status = 'accepted',
      accepted_at = now(),
      accepted_by = auth.uid(),
      updated_at = now()
  where id = v_invitation.id;

  insert into public.audit_logs (
    organization_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    new_data
  ) values (
    v_invitation.organization_id,
    auth.uid(),
    'invitation_accepted',
    'invitation',
    v_invitation.id::text,
    jsonb_build_object('member_id', v_member_id, 'role_code', v_invitation.role_code)
  );

  return jsonb_build_object(
    'accepted', true,
    'member_id', v_member_id,
    'role_code', v_invitation.role_code
  );
end;
$$;

revoke all on function public.admin_update_member(uuid, text, text, text, text, text, text[]) from public;
revoke all on function public.admin_create_invitation(text, text, text, text, text, text, integer) from public;
revoke all on function public.admin_revoke_invitation(uuid) from public;
revoke all on function public.get_invitation_preview(text) from public;
revoke all on function public.accept_invitation(text) from public;

grant execute on function public.admin_update_member(uuid, text, text, text, text, text, text[]) to authenticated;
grant execute on function public.admin_create_invitation(text, text, text, text, text, text, integer) to authenticated;
grant execute on function public.admin_revoke_invitation(uuid) to authenticated;
grant execute on function public.get_invitation_preview(text) to anon, authenticated;
grant execute on function public.accept_invitation(text) to authenticated;

commit;
