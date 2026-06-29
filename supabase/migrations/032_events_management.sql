begin;

alter table public.events
  add column if not exists is_featured boolean not null default false,
  add column if not exists registration_mode text not null default 'free' check (registration_mode in ('free','approval','paid','closed')),
  add column if not exists registration_deadline timestamptz,
  add column if not exists seo_title text,
  add column if not exists seo_description text;

create index if not exists events_featured_idx
  on public.events(organization_id, is_featured, starts_at)
  where deleted_at is null and status = 'published';

create or replace function public.admin_save_event(
  p_event_id uuid,
  p_title text,
  p_slug text,
  p_description text,
  p_event_type text,
  p_location_name text,
  p_location_address text,
  p_meeting_url text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_capacity integer,
  p_price numeric,
  p_status text,
  p_cover_path text,
  p_is_featured boolean,
  p_registration_mode text,
  p_registration_deadline timestamptz,
  p_seo_title text,
  p_seo_description text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_organization_id uuid;
  v_event_id uuid;
  v_slug text := lower(trim(p_slug));
  v_event_type text := lower(trim(p_event_type));
  v_status text := lower(trim(p_status));
  v_registration_mode text := lower(trim(coalesce(p_registration_mode, 'free')));
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select om.organization_id into v_organization_id
  from public.organization_members om
  where om.profile_id = auth.uid()
    and om.status = 'active'
    and om.deleted_at is null
  limit 1;

  if v_organization_id is null or not public.has_permission(v_organization_id, 'events.manage') then
    raise exception 'Você não possui permissão para gerenciar eventos.';
  end if;

  if nullif(trim(p_title), '') is null then
    raise exception 'Informe o título do evento.';
  end if;

  if v_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Endereço amigável inválido.';
  end if;

  if v_event_type not in ('online','in_person','hybrid') then
    raise exception 'Tipo de evento inválido.';
  end if;

  if v_status not in ('draft','published','cancelled','completed','archived') then
    raise exception 'Situação do evento inválida.';
  end if;

  if v_registration_mode not in ('free','approval','paid','closed') then
    raise exception 'Modo de inscrição inválido.';
  end if;

  if p_starts_at is null or p_ends_at is null or p_ends_at <= p_starts_at then
    raise exception 'Informe datas válidas para início e fim.';
  end if;

  if p_capacity is not null and p_capacity <= 0 then
    raise exception 'A capacidade precisa ser maior que zero.';
  end if;

  if coalesce(p_price, 0) < 0 then
    raise exception 'O preço não pode ser negativo.';
  end if;

  if p_event_id is null then
    insert into public.events (
      organization_id,title,slug,description,event_type,location_name,location_address,
      meeting_url,starts_at,ends_at,capacity,price,status,cover_path,created_by,
      is_featured,registration_mode,registration_deadline,seo_title,seo_description
    ) values (
      v_organization_id,trim(p_title),v_slug,nullif(trim(coalesce(p_description,'')),''),v_event_type,
      nullif(trim(coalesce(p_location_name,'')),''),nullif(trim(coalesce(p_location_address,'')),''),
      nullif(trim(coalesce(p_meeting_url,'')),''),p_starts_at,p_ends_at,p_capacity,coalesce(p_price,0),
      v_status,nullif(trim(coalesce(p_cover_path,'')),''),auth.uid(),coalesce(p_is_featured,false),
      v_registration_mode,p_registration_deadline,nullif(trim(coalesce(p_seo_title,'')),''),
      nullif(trim(coalesce(p_seo_description,'')),'')
    ) returning id into v_event_id;
  else
    update public.events
    set title=trim(p_title), slug=v_slug, description=nullif(trim(coalesce(p_description,'')),''),
        event_type=v_event_type, location_name=nullif(trim(coalesce(p_location_name,'')),''),
        location_address=nullif(trim(coalesce(p_location_address,'')),''),
        meeting_url=nullif(trim(coalesce(p_meeting_url,'')),''), starts_at=p_starts_at,
        ends_at=p_ends_at, capacity=p_capacity, price=coalesce(p_price,0), status=v_status,
        cover_path=nullif(trim(coalesce(p_cover_path,'')),''), is_featured=coalesce(p_is_featured,false),
        registration_mode=v_registration_mode, registration_deadline=p_registration_deadline,
        seo_title=nullif(trim(coalesce(p_seo_title,'')),''),
        seo_description=nullif(trim(coalesce(p_seo_description,'')),''), deleted_at=null, updated_at=now()
    where id=p_event_id and organization_id=v_organization_id
    returning id into v_event_id;

    if v_event_id is null then
      raise exception 'Evento não encontrado.';
    end if;
  end if;

  insert into public.audit_logs(organization_id,actor_id,action,entity_type,entity_id,new_data)
  values (
    v_organization_id, auth.uid(), case when p_event_id is null then 'event_created' else 'event_updated' end,
    'event', v_event_id::text,
    jsonb_build_object('title',trim(p_title),'slug',v_slug,'status',v_status,'starts_at',p_starts_at)
  );

  return jsonb_build_object('event_id',v_event_id,'title',trim(p_title),'slug',v_slug,'status',v_status);
end;
$$;

create or replace function public.admin_archive_event(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_organization_id uuid;
  v_title text;
begin
  select organization_id,title into v_organization_id,v_title
  from public.events where id=p_event_id for update;

  if v_organization_id is null then
    raise exception 'Evento não encontrado.';
  end if;

  if not public.has_permission(v_organization_id, 'events.manage') then
    raise exception 'Você não possui permissão para arquivar eventos.';
  end if;

  update public.events set status='archived', updated_at=now() where id=p_event_id;

  insert into public.audit_logs(organization_id,actor_id,action,entity_type,entity_id,new_data)
  values (v_organization_id,auth.uid(),'event_archived','event',p_event_id::text,jsonb_build_object('title',v_title));
end;
$$;

create or replace function public.register_for_event(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_event public.events%rowtype;
  v_count integer;
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'Entre na sua conta para se inscrever.';
  end if;

  select * into v_event from public.events where id=p_event_id and deleted_at is null;

  if v_event.id is null or v_event.status <> 'published' then
    raise exception 'Evento indisponível.';
  end if;

  if v_event.registration_mode = 'closed' then
    raise exception 'Inscrições encerradas.';
  end if;

  if v_event.registration_deadline is not null and v_event.registration_deadline < now() then
    raise exception 'Prazo de inscrição encerrado.';
  end if;

  select count(*) into v_count
  from public.event_registrations er
  where er.event_id=p_event_id and er.status in ('pending','confirmed','attended');

  if v_event.capacity is not null and v_count >= v_event.capacity then
    v_status := 'waitlist';
  elsif v_event.registration_mode = 'approval' then
    v_status := 'pending';
  else
    v_status := 'confirmed';
  end if;

  insert into public.event_registrations(event_id,profile_id,status)
  values (p_event_id,auth.uid(),v_status)
  on conflict(event_id,profile_id) do update
  set status = case when event_registrations.status = 'cancelled' then excluded.status else event_registrations.status end,
      registered_at = case when event_registrations.status = 'cancelled' then now() else event_registrations.registered_at end
  returning status into v_status;

  return jsonb_build_object('event_id',p_event_id,'status',v_status);
end;
$$;

revoke all on function public.admin_save_event(uuid,text,text,text,text,text,text,text,timestamptz,timestamptz,integer,numeric,text,text,boolean,text,timestamptz,text,text) from public;
revoke all on function public.admin_save_event(uuid,text,text,text,text,text,text,text,timestamptz,timestamptz,integer,numeric,text,text,boolean,text,timestamptz,text,text) from anon;
revoke all on function public.admin_save_event(uuid,text,text,text,text,text,text,text,timestamptz,timestamptz,integer,numeric,text,text,boolean,text,timestamptz,text,text) from authenticated;
grant execute on function public.admin_save_event(uuid,text,text,text,text,text,text,text,timestamptz,timestamptz,integer,numeric,text,text,boolean,text,timestamptz,text,text) to authenticated;

revoke all on function public.admin_archive_event(uuid) from public;
revoke all on function public.admin_archive_event(uuid) from anon;
revoke all on function public.admin_archive_event(uuid) from authenticated;
grant execute on function public.admin_archive_event(uuid) to authenticated;

revoke all on function public.register_for_event(uuid) from public;
revoke all on function public.register_for_event(uuid) from anon;
revoke all on function public.register_for_event(uuid) from authenticated;
grant execute on function public.register_for_event(uuid) to authenticated;

commit;
