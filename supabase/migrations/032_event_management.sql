begin;

alter table public.events
  add column if not exists is_members_only boolean not null default false,
  add column if not exists registration_required boolean not null default true,
  add column if not exists registration_opens_at timestamptz,
  add column if not exists registration_deadline timestamptz,
  add column if not exists waitlist_enabled boolean not null default true,
  add column if not exists is_featured boolean not null default false,
  add column if not exists published_at timestamptz;

create index if not exists events_published_featured_idx
on public.events(organization_id,is_featured,starts_at)
where deleted_at is null and status='published';

create table if not exists public.event_private_details(
  event_id uuid primary key references public.events(id) on delete cascade,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  meeting_url text,
  instructions text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.event_private_details enable row level security;

drop trigger if exists event_private_details_set_updated_at on public.event_private_details;
create trigger event_private_details_set_updated_at before update on public.event_private_details
for each row execute function public.set_updated_at();

insert into public.event_private_details(event_id,organization_id,meeting_url)
select id,organization_id,meeting_url from public.events
where nullif(trim(meeting_url),'') is not null
on conflict(event_id) do update set meeting_url=coalesce(public.event_private_details.meeting_url,excluded.meeting_url);
update public.events set meeting_url=null where meeting_url is not null;

create or replace function public.admin_save_event(
  p_event_id uuid,p_title text,p_slug text,p_description text,p_event_type text,
  p_location_name text,p_location_address text,p_meeting_url text,p_instructions text,
  p_starts_at timestamptz,p_ends_at timestamptz,p_capacity integer,p_price numeric,
  p_status text,p_cover_path text,p_is_members_only boolean,p_registration_required boolean,
  p_registration_opens_at timestamptz,p_registration_deadline timestamptz,
  p_waitlist_enabled boolean,p_is_featured boolean
) returns jsonb
language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare
  v_org uuid;v_id uuid;v_slug text:=lower(trim(p_slug));
  v_type text:=lower(trim(p_event_type));v_status text:=lower(trim(p_status));
begin
  if auth.uid() is null then raise exception 'Autenticação obrigatória.';end if;
  select organization_id into v_org from public.organization_members
  where profile_id=auth.uid() and status='active' and deleted_at is null limit 1;
  if v_org is null or not public.has_permission(v_org,'events.manage') then
    raise exception 'Você não possui permissão para gerenciar eventos.';
  end if;
  if nullif(trim(p_title),'') is null then raise exception 'Informe o título.';end if;
  if v_slug!~'^[a-z0-9]+(?:-[a-z0-9]+)*$' then raise exception 'Endereço amigável inválido.';end if;
  if v_type not in('online','in_person','hybrid') then raise exception 'Formato inválido.';end if;
  if v_status not in('draft','published','cancelled','completed','archived') then raise exception 'Situação inválida.';end if;
  if p_starts_at is null or p_ends_at is null or p_ends_at<=p_starts_at then raise exception 'Período inválido.';end if;
  if p_capacity is not null and p_capacity<=0 then raise exception 'Capacidade inválida.';end if;
  if coalesce(p_price,0)<0 then raise exception 'Valor inválido.';end if;
  if p_registration_opens_at is not null and p_registration_opens_at>=p_starts_at then raise exception 'Abertura inválida.';end if;
  if p_registration_deadline is not null and p_registration_deadline>p_starts_at then raise exception 'Encerramento inválido.';end if;
  if p_registration_opens_at is not null and p_registration_deadline is not null and p_registration_deadline<=p_registration_opens_at then raise exception 'Janela de inscrição inválida.';end if;
  if v_type in('in_person','hybrid') and nullif(trim(coalesce(p_location_name,'')),'') is null then raise exception 'Informe o local.';end if;
  if nullif(trim(coalesce(p_meeting_url,'')),'') is not null and trim(p_meeting_url)!~*'^https?://' then raise exception 'Link inválido.';end if;

  if p_event_id is null then
    insert into public.events(organization_id,title,slug,description,event_type,location_name,location_address,meeting_url,starts_at,ends_at,capacity,price,status,cover_path,created_by,is_members_only,registration_required,registration_opens_at,registration_deadline,waitlist_enabled,is_featured,published_at)
    values(v_org,trim(p_title),v_slug,nullif(trim(coalesce(p_description,'')),''),v_type,nullif(trim(coalesce(p_location_name,'')),''),nullif(trim(coalesce(p_location_address,'')),''),null,p_starts_at,p_ends_at,p_capacity,coalesce(p_price,0),v_status,nullif(trim(coalesce(p_cover_path,'')),''),auth.uid(),coalesce(p_is_members_only,false),coalesce(p_registration_required,true),p_registration_opens_at,p_registration_deadline,coalesce(p_waitlist_enabled,true),coalesce(p_is_featured,false),case when v_status='published' then now() end)
    returning id into v_id;
  else
    update public.events set title=trim(p_title),slug=v_slug,description=nullif(trim(coalesce(p_description,'')),''),event_type=v_type,location_name=nullif(trim(coalesce(p_location_name,'')),''),location_address=nullif(trim(coalesce(p_location_address,'')),''),meeting_url=null,starts_at=p_starts_at,ends_at=p_ends_at,capacity=p_capacity,price=coalesce(p_price,0),status=v_status,cover_path=nullif(trim(coalesce(p_cover_path,'')),''),is_members_only=coalesce(p_is_members_only,false),registration_required=coalesce(p_registration_required,true),registration_opens_at=p_registration_opens_at,registration_deadline=p_registration_deadline,waitlist_enabled=coalesce(p_waitlist_enabled,true),is_featured=coalesce(p_is_featured,false),published_at=case when v_status='published' then coalesce(published_at,now()) end,deleted_at=null,updated_at=now()
    where id=p_event_id and organization_id=v_org returning id into v_id;
    if v_id is null then raise exception 'Evento não encontrado.';end if;
  end if;

  insert into public.event_private_details(event_id,organization_id,meeting_url,instructions)
  values(v_id,v_org,nullif(trim(coalesce(p_meeting_url,'')),''),nullif(trim(coalesce(p_instructions,'')),''))
  on conflict(event_id) do update set organization_id=excluded.organization_id,meeting_url=excluded.meeting_url,instructions=excluded.instructions,updated_at=now();

  insert into public.audit_logs(organization_id,actor_id,action,entity_type,entity_id,new_data)
  values(v_org,auth.uid(),case when p_event_id is null then 'event_created' else 'event_updated' end,'event',v_id::text,jsonb_build_object('title',trim(p_title),'status',v_status,'starts_at',p_starts_at));
  return jsonb_build_object('event_id',v_id,'status',v_status);
end;$$;

create or replace function public.admin_archive_event(p_event_id uuid) returns void
language plpgsql security definer set search_path=public,auth,pg_temp as $$
declare v_org uuid;v_title text;
begin
  select organization_id,title into v_org,v_title from public.events where id=p_event_id for update;
  if v_org is null then raise exception 'Evento não encontrado.';end if;
  if not public.has_permission(v_org,'events.manage') then raise exception 'Permissão negada.';end if;
  update public.events set status='archived',published_at=null,updated_at=now() where id=p_event_id;
  insert into public.audit_logs(organization_id,actor_id,action,entity_type,entity_id,new_data)
  values(v_org,auth.uid(),'event_archived','event',p_event_id::text,jsonb_build_object('title',v_title));
end;$$;

drop policy if exists event_private_details_read on public.event_private_details;
create policy event_private_details_read on public.event_private_details for select to authenticated
using(public.has_permission(organization_id,'events.read'));
drop policy if exists event_private_details_manage on public.event_private_details;
create policy event_private_details_manage on public.event_private_details for all to authenticated
using(public.has_permission(organization_id,'events.manage'))
with check(public.has_permission(organization_id,'events.manage'));

drop policy if exists events_read on public.events;
create policy events_read on public.events for select to anon,authenticated using(
  (deleted_at is null and status='published' and (not is_members_only or public.is_organization_member(organization_id)))
  or public.has_permission(organization_id,'events.read')
);

revoke all on function public.admin_save_event(uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,integer,numeric,text,text,boolean,boolean,timestamptz,timestamptz,boolean,boolean) from public,anon,authenticated;
grant execute on function public.admin_save_event(uuid,text,text,text,text,text,text,text,text,timestamptz,timestamptz,integer,numeric,text,text,boolean,boolean,timestamptz,timestamptz,boolean,boolean) to authenticated;
revoke all on function public.admin_archive_event(uuid) from public,anon,authenticated;
grant execute on function public.admin_archive_event(uuid) to authenticated;

commit;
