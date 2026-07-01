begin;

-- Campos de acesso e inscrição utilizados pelo feed da área da membro.
alter table public.events
  add column if not exists is_members_only boolean not null default false,
  add column if not exists registration_required boolean not null default true,
  add column if not exists registration_opens_at timestamptz,
  add column if not exists waitlist_enabled boolean not null default true;

-- Dados privados do evento não devem permanecer na tabela pública de eventos,
-- pois as linhas publicadas podem ser consultadas por visitantes.
create table if not exists public.event_private_details (
  event_id uuid primary key references public.events(id) on delete cascade,
  meeting_url text,
  instructions text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.event_private_details enable row level security;

-- Migra links já cadastrados antes de limpar a coluna pública.
insert into public.event_private_details (event_id, meeting_url)
select e.id, e.meeting_url
from public.events e
where nullif(trim(coalesce(e.meeting_url, '')), '') is not null
on conflict (event_id) do update
set meeting_url = excluded.meeting_url,
    updated_at = now();

update public.events
set meeting_url = null
where meeting_url is not null;

create or replace function public.capture_event_private_details_on_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if nullif(trim(coalesce(new.meeting_url, '')), '') is not null then
    insert into public.event_private_details (event_id, meeting_url)
    values (new.id, trim(new.meeting_url))
    on conflict (event_id) do update
    set meeting_url = excluded.meeting_url,
        updated_at = now();

    update public.events
    set meeting_url = null
    where id = new.id;
  end if;

  return new;
end;
$$;

create or replace function public.capture_event_private_details_on_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Evita que a limpeza executada pelo trigger de inserção apague o valor recém-migrado.
  if pg_trigger_depth() > 1 then
    return new;
  end if;

  if new.meeting_url is distinct from old.meeting_url then
    insert into public.event_private_details (event_id, meeting_url)
    values (new.id, nullif(trim(coalesce(new.meeting_url, '')), ''))
    on conflict (event_id) do update
    set meeting_url = excluded.meeting_url,
        updated_at = now();

    new.meeting_url := null;
  end if;

  return new;
end;
$$;

drop trigger if exists events_capture_private_details_insert on public.events;
create trigger events_capture_private_details_insert
after insert on public.events
for each row execute function public.capture_event_private_details_on_insert();

drop trigger if exists events_capture_private_details_update on public.events;
create trigger events_capture_private_details_update
before update of meeting_url on public.events
for each row execute function public.capture_event_private_details_on_update();

revoke all on table public.event_private_details from public;
revoke all on table public.event_private_details from anon;
revoke all on table public.event_private_details from authenticated;

revoke all on function public.capture_event_private_details_on_insert() from public;
revoke all on function public.capture_event_private_details_on_insert() from anon;
revoke all on function public.capture_event_private_details_on_insert() from authenticated;

revoke all on function public.capture_event_private_details_on_update() from public;
revoke all on function public.capture_event_private_details_on_update() from anon;
revoke all on function public.capture_event_private_details_on_update() from authenticated;

commit;
