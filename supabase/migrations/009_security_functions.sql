begin;

create or replace function public.try_uuid(value text)
returns uuid
language plpgsql
immutable
strict
set search_path = public, pg_temp
as $$
begin
  return value::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;

create or replace function public.is_superadmin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce((
    select p.is_superadmin
    from public.profiles p
    where p.id = auth.uid()
      and p.status = 'active'
      and p.deleted_at is null
  ), false);
$$;

create or replace function public.is_organization_member(target_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_superadmin() or exists (
    select 1
    from public.organization_members om
    where om.organization_id = target_organization_id
      and om.profile_id = auth.uid()
      and om.status = 'active'
      and om.deleted_at is null
  );
$$;

create or replace function public.has_role(target_organization_id uuid, target_role_code text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_superadmin() or exists (
    select 1
    from public.organization_members om
    join public.member_roles mr
      on mr.organization_member_id = om.id
     and mr.organization_id = om.organization_id
     and mr.revoked_at is null
    join public.roles r on r.id = mr.role_id
    where om.organization_id = target_organization_id
      and om.profile_id = auth.uid()
      and om.status = 'active'
      and om.deleted_at is null
      and r.code = target_role_code
  );
$$;

create or replace function public.has_permission(target_organization_id uuid, target_permission_code text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_superadmin() or exists (
    select 1
    from public.organization_members om
    join public.member_roles mr
      on mr.organization_member_id = om.id
     and mr.organization_id = om.organization_id
     and mr.revoked_at is null
    join public.role_permissions rp on rp.role_id = mr.role_id
    join public.permissions p on p.id = rp.permission_id
    where om.organization_id = target_organization_id
      and om.profile_id = auth.uid()
      and om.status = 'active'
      and om.deleted_at is null
      and p.code = target_permission_code
  );
$$;

create or replace function public.has_active_enrollment(target_course_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_superadmin() or exists (
    select 1
    from public.enrollments e
    where e.course_id = target_course_id
      and e.profile_id = auth.uid()
      and e.status in ('active','completed')
      and coalesce(e.starts_at, now()) <= now()
      and (e.expires_at is null or e.expires_at > now())
  );
$$;

create or replace function public.has_active_access(target_resource_type text, target_resource_id uuid default null)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.is_superadmin() or exists (
    select 1
    from public.access_grants ag
    where ag.profile_id = auth.uid()
      and ag.resource_type = target_resource_type
      and (target_resource_id is null or ag.resource_id = target_resource_id)
      and ag.starts_at <= now()
      and (ag.expires_at is null or ag.expires_at > now())
      and ag.revoked_at is null
  );
$$;

create or replace function public.can_access_community_space(target_space_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.community_spaces cs
    where cs.id = target_space_id
      and cs.status = 'active'
      and (
        cs.access_type = 'public'
        or public.is_superadmin()
        or public.has_permission(cs.organization_id, 'community.manage')
        or (
          auth.uid() is not null and (
            (cs.access_type = 'members' and public.is_organization_member(cs.organization_id))
            or (cs.access_type = 'course' and cs.course_id is not null and public.has_active_enrollment(cs.course_id))
            or (cs.access_type = 'plan' and cs.plan_id is not null and exists (
              select 1 from public.subscriptions s
              where s.profile_id = auth.uid()
                and s.plan_id = cs.plan_id
                and s.status in ('trialing','active')
                and (s.current_period_end is null or s.current_period_end > now())
            ))
            or exists (
              select 1 from public.community_space_members csm
              where csm.space_id = cs.id
                and csm.profile_id = auth.uid()
                and csm.status = 'active'
            )
          )
        )
      )
  );
$$;

revoke all on function public.try_uuid(text) from public;
revoke all on function public.is_superadmin() from public;
revoke all on function public.is_organization_member(uuid) from public;
revoke all on function public.has_role(uuid, text) from public;
revoke all on function public.has_permission(uuid, text) from public;
revoke all on function public.has_active_enrollment(uuid) from public;
revoke all on function public.has_active_access(text, uuid) from public;
revoke all on function public.can_access_community_space(uuid) from public;

grant execute on function public.try_uuid(text) to anon, authenticated;
grant execute on function public.is_superadmin() to authenticated;
grant execute on function public.is_organization_member(uuid) to authenticated;
grant execute on function public.has_role(uuid, text) to authenticated;
grant execute on function public.has_permission(uuid, text) to authenticated;
grant execute on function public.has_active_enrollment(uuid) to authenticated;
grant execute on function public.has_active_access(text, uuid) to authenticated;
grant execute on function public.can_access_community_space(uuid) to anon, authenticated;

commit;
