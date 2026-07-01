begin;

-- Feed de eventos da área da membro.
-- Compatível com a estrutura criada em 008_content_support.sql e ampliada em
-- 032_events_management.sql. Dados sensíveis, como o link da reunião, só são
-- retornados para inscrições confirmadas ou com presença registrada.
create or replace function public.get_member_events(p_include_past boolean default false)
returns jsonb
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select coalesce(jsonb_agg(item order by featured desc, starts_at), '[]'::jsonb)
  from (
    select
      coalesce(e.is_featured, false) as featured,
      e.starts_at,
      jsonb_build_object(
        'id', e.id,
        'title', e.title,
        'slug', e.slug,
        'description', e.description,
        'event_type', e.event_type,
        'location_name', e.location_name,
        'location_address', e.location_address,
        'starts_at', e.starts_at,
        'ends_at', e.ends_at,
        'capacity', e.capacity,
        'price', e.price,
        'cover_path', e.cover_path,
        'is_members_only', false,
        'registration_required', e.registration_mode <> 'closed',
        'registration_mode', e.registration_mode,
        'registration_opens_at', null,
        'registration_deadline', e.registration_deadline,
        'waitlist_enabled', e.capacity is not null,
        'is_featured', coalesce(e.is_featured, false),
        'registered_count', (
          select count(*)::integer
          from public.event_registrations x
          where x.event_id = e.id
            and x.status in ('pending', 'confirmed', 'attended')
        ),
        'my_registration', case
          when er.id is null then null
          else jsonb_build_object(
            'id', er.id,
            'status', er.status,
            'registered_at', er.registered_at,
            'checked_in_at', er.checked_in_at
          )
        end,
        'meeting_url', case
          when er.status in ('confirmed', 'attended') then e.meeting_url
          else null
        end,
        'instructions', null
      ) as item
    from public.events e
    left join public.event_registrations er
      on er.event_id = e.id
     and er.profile_id = auth.uid()
    where auth.uid() is not null
      and e.deleted_at is null
      and e.status = 'published'
      and (p_include_past or e.ends_at >= now())
  ) rows;
$$;

revoke all on function public.get_member_events(boolean) from public;
revoke all on function public.get_member_events(boolean) from anon;
revoke all on function public.get_member_events(boolean) from authenticated;
grant execute on function public.get_member_events(boolean) to authenticated;

commit;
