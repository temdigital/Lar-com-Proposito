begin;

create or replace function public.handle_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_first_name text;
  v_member_id uuid;
  v_organization_id constant uuid := '11111111-1111-4111-8111-111111111111';
  v_member_status text;
begin
  v_first_name := nullif(trim(coalesce(new.raw_user_meta_data->>'nome', new.raw_user_meta_data->>'first_name', '')), '');
  v_member_status := case when new.email_confirmed_at is null then 'invited' else 'active' end;

  insert into public.profiles (
    id, first_name, last_name, email, whatsapp, status
  ) values (
    new.id,
    coalesce(v_first_name, split_part(coalesce(new.email, 'Usuária'), '@', 1), 'Usuária'),
    nullif(trim(coalesce(new.raw_user_meta_data->>'sobrenome', new.raw_user_meta_data->>'last_name', '')), ''),
    lower(coalesce(new.email, '')),
    nullif(trim(coalesce(new.raw_user_meta_data->>'whatsapp', '')), ''),
    case when new.email_confirmed_at is null then 'pending' else 'active' end
  )
  on conflict (id) do update
  set email = excluded.email,
      updated_at = now();

  insert into public.organization_members (
    organization_id, profile_id, status, joined_at
  ) values (
    v_organization_id,
    new.id,
    v_member_status,
    case when v_member_status = 'active' then now() else null end
  )
  on conflict (organization_id, profile_id) do update
  set status = excluded.status,
      joined_at = case
        when excluded.status = 'active' then coalesce(public.organization_members.joined_at, now())
        else public.organization_members.joined_at
      end,
      deleted_at = null,
      updated_at = now()
  returning id into v_member_id;

  insert into public.member_roles (
    organization_id, organization_member_id, role_id
  )
  select v_organization_id, v_member_id, r.id
  from public.roles r
  where r.code = 'membro'
  on conflict (organization_member_id, role_id) do update
  set revoked_at = null;

  return new;
end;
$$;

create or replace function public.handle_auth_user_updated()
returns trigger
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_is_banned boolean;
  v_is_confirmed boolean;
begin
  v_is_banned := new.banned_until is not null and new.banned_until > now();
  v_is_confirmed := new.email_confirmed_at is not null;

  update public.profiles
  set email = lower(coalesce(new.email, email)),
      status = case
        when v_is_banned then 'blocked'
        when v_is_confirmed then 'active'
        else 'pending'
      end,
      updated_at = now()
  where id = new.id;

  update public.organization_members
  set status = case
        when v_is_banned then 'suspended'
        when v_is_confirmed then 'active'
        else 'invited'
      end,
      joined_at = case
        when v_is_confirmed and joined_at is null then now()
        else joined_at
      end,
      updated_at = now()
  where profile_id = new.id
    and deleted_at is null;

  return new;
end;
$$;

revoke all on function public.handle_auth_user_created() from public;
revoke all on function public.handle_auth_user_updated() from public;

commit;
