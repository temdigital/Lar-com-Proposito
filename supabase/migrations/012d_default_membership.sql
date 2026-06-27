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
begin
  v_first_name := nullif(trim(coalesce(new.raw_user_meta_data->>'nome', new.raw_user_meta_data->>'first_name', '')), '');

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
    'active',
    now()
  )
  on conflict (organization_id, profile_id) do update
  set status = 'active',
      joined_at = coalesce(public.organization_members.joined_at, excluded.joined_at),
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

revoke all on function public.handle_auth_user_created() from public;

commit;
