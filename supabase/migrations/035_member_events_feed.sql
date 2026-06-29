begin;

create or replace function public.get_member_events(p_include_past boolean default false)
returns jsonb
language sql
stable
security definer
set search_path=public,auth,pg_temp
as $$
select coalesce(jsonb_agg(item order by featured desc,starts_at),'[]'::jsonb)
from(
  select e.is_featured featured,e.starts_at,
  jsonb_build_object(
    'id',e.id,
    'title',e.title,
    'slug',e.slug,
    'description',e.description,
    'event_type',e.event_type,
    'location_name',e.location_name,
    'location_address',e.location_address,
    'starts_at',e.starts_at,
    'ends_at',e.ends_at,
    'capacity',e.capacity,
    'price',e.price,
    'cover_path',e.cover_path,
    'is_members_only',e.is_members_only,
    'registration_required',e.registration_required,
    'registration_opens_at',e.registration_opens_at,
    'registration_deadline',e.registration_deadline,
    'waitlist_enabled',e.waitlist_enabled,
    'is_featured',e.is_featured,
    'registered_count',(select count(*)::integer from public.event_registrations x where x.event_id=e.id and x.status in('pending','confirmed','attended')),
    'my_registration',case when er.id is null then null else jsonb_build_object('id',er.id,'status',er.status,'registered_at',er.registered_at,'checked_in_at',er.checked_in_at) end,
    'meeting_url',case when er.status in('confirmed','attended') then d.meeting_url end,
    'instructions',case when er.status in('confirmed','attended') then d.instructions end
  ) item
  from public.events e
  left join public.event_registrations er on er.event_id=e.id and er.profile_id=auth.uid()
  left join public.event_private_details d on d.event_id=e.id
  where e.deleted_at is null
    and e.status='published'
    and (p_include_past or e.ends_at>=now())
    and (not e.is_members_only or public.is_organization_member(e.organization_id))
) rows;
$$;

revoke all on function public.get_member_events(boolean) from public,anon,authenticated;
grant execute on function public.get_member_events(boolean) to authenticated;

commit;
