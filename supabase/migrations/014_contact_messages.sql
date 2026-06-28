begin;

create table public.contact_messages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null default '11111111-1111-4111-8111-111111111111'
    references public.organizations(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  name text not null check (char_length(trim(name)) between 2 and 120),
  email text not null check (char_length(trim(email)) between 5 and 254 and position('@' in email) > 1),
  topic text not null check (topic in ('general','support','privacy','partnership','security')),
  subject text not null check (char_length(trim(subject)) between 4 and 180),
  message text not null check (char_length(trim(message)) between 20 and 3000),
  source_page text,
  user_agent text,
  status text not null default 'new' check (status in ('new','in_review','answered','closed','spam')),
  assigned_to uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  answered_at timestamptz
);

create index contact_messages_org_status_created_idx
  on public.contact_messages(organization_id, status, created_at desc);
create index contact_messages_email_created_idx
  on public.contact_messages(lower(email), created_at desc);

create trigger contact_messages_set_updated_at
before update on public.contact_messages
for each row execute function public.set_updated_at();

alter table public.contact_messages enable row level security;

grant insert on public.contact_messages to anon, authenticated;
grant select, update on public.contact_messages to authenticated;

create policy contact_messages_public_insert
on public.contact_messages
for insert to anon, authenticated
with check (
  organization_id = '11111111-1111-4111-8111-111111111111'
  and status = 'new'
  and assigned_to is null
  and answered_at is null
  and (profile_id is null or profile_id = auth.uid())
);

create policy contact_messages_staff_read
on public.contact_messages
for select to authenticated
using (public.has_permission(organization_id, 'support.manage'));

create policy contact_messages_staff_update
on public.contact_messages
for update to authenticated
using (public.has_permission(organization_id, 'support.manage'))
with check (public.has_permission(organization_id, 'support.manage'));

commit;
