begin;

create or replace function public.get_my_app_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_organization_id uuid;
  v_member_id uuid;
begin
  if v_user_id is null then
    raise exception 'Autenticação necessária.';
  end if;

  select om.organization_id, om.id
    into v_organization_id, v_member_id
  from public.organization_members om
  where om.profile_id = v_user_id
    and om.status = 'active'
    and om.deleted_at is null
  order by om.joined_at nulls last, om.created_at
  limit 1;

  return jsonb_build_object(
    'profile', coalesce((
      select jsonb_build_object(
        'id', p.id,
        'first_name', p.first_name,
        'last_name', p.last_name,
        'email', p.email,
        'whatsapp', p.whatsapp,
        'alternative_phone', p.alternative_phone,
        'birth_date', p.birth_date,
        'photo_url', p.photo_url,
        'biography', p.biography,
        'city', p.city,
        'postal_code', p.postal_code,
        'status', p.status,
        'is_superadmin', p.is_superadmin,
        'last_access_at', p.last_access_at,
        'created_at', p.created_at
      )
      from public.profiles p
      where p.id = v_user_id
    ), '{}'::jsonb),
    'organization', coalesce((
      select jsonb_build_object(
        'id', o.id,
        'name', o.name,
        'slug', o.slug,
        'status', o.status
      )
      from public.organizations o
      where o.id = v_organization_id
    ), '{}'::jsonb),
    'membership', coalesce((
      select jsonb_build_object(
        'id', om.id,
        'status', om.status,
        'job_title', om.job_title,
        'joined_at', om.joined_at
      )
      from public.organization_members om
      where om.id = v_member_id
    ), '{}'::jsonb),
    'roles', coalesce((
      select jsonb_agg(
        jsonb_build_object('code', r.code, 'name', r.name)
        order by r.name
      )
      from public.member_roles mr
      join public.roles r on r.id = mr.role_id
      where mr.organization_member_id = v_member_id
        and mr.revoked_at is null
    ), '[]'::jsonb),
    'permissions', coalesce((
      select jsonb_agg(distinct p.code order by p.code)
      from public.member_roles mr
      join public.role_permissions rp on rp.role_id = mr.role_id
      join public.permissions p on p.id = rp.permission_id
      where mr.organization_member_id = v_member_id
        and mr.revoked_at is null
    ), '[]'::jsonb),
    'counts', jsonb_build_object(
      'active_enrollments', (
        select count(*) from public.enrollments e
        where e.profile_id = v_user_id and e.status = 'active'
      ),
      'completed_enrollments', (
        select count(*) from public.enrollments e
        where e.profile_id = v_user_id and e.status = 'completed'
      ),
      'unread_notifications', (
        select count(*) from public.notifications n
        where n.profile_id = v_user_id and n.status <> 'read'
      ),
      'active_subscriptions', (
        select count(*) from public.subscriptions s
        where s.profile_id = v_user_id and s.status in ('trialing','active')
      ),
      'favorites', (
        select count(*) from public.favorites f
        where f.profile_id = v_user_id
      )
    )
  );
end;
$$;

revoke all on function public.get_my_app_context() from public;
grant execute on function public.get_my_app_context() to authenticated;

commit;
