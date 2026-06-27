begin;

create table public.content_categories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  slug text not null,
  description text,
  created_at timestamptz not null default now(),
  unique (organization_id, slug)
);

create table public.content_posts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  category_id uuid references public.content_categories(id) on delete set null,
  author_id uuid references public.profiles(id) on delete set null,
  title text not null,
  slug text not null,
  excerpt text,
  body_html text not null,
  cover_path text,
  status text not null default 'draft' check (status in ('draft','review','published','archived')),
  is_members_only boolean not null default false,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create unique index content_posts_org_slug_unique
  on public.content_posts(organization_id, lower(slug))
  where deleted_at is null;
create index content_posts_org_status_idx on public.content_posts(organization_id, status, published_at desc);

create trigger content_posts_set_updated_at
before update on public.content_posts
for each row execute function public.set_updated_at();

create table public.events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  title text not null,
  slug text not null,
  description text,
  event_type text not null check (event_type in ('online','in_person','hybrid')),
  location_name text,
  location_address text,
  meeting_url text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  capacity integer check (capacity is null or capacity > 0),
  price numeric(12,2) not null default 0 check (price >= 0),
  status text not null default 'draft' check (status in ('draft','published','cancelled','completed','archived')),
  cover_path text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (ends_at > starts_at)
);

create unique index events_org_slug_unique
  on public.events(organization_id, lower(slug))
  where deleted_at is null;
create index events_org_start_idx on public.events(organization_id, starts_at);

create trigger events_set_updated_at
before update on public.events
for each row execute function public.set_updated_at();

create table public.event_registrations (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','confirmed','waitlist','cancelled','attended','no_show')),
  order_id uuid references public.orders(id) on delete set null,
  registered_at timestamptz not null default now(),
  checked_in_at timestamptz,
  unique (event_id, profile_id)
);

create table public.media_assets (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  owner_id uuid references public.profiles(id) on delete set null,
  bucket text not null,
  storage_path text not null,
  public_url text,
  file_name text not null,
  mime_type text,
  size_bytes bigint check (size_bytes is null or size_bytes >= 0),
  visibility text not null default 'private' check (visibility in ('public','members','private')),
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (bucket, storage_path)
);

create index media_assets_org_idx on public.media_assets(organization_id, created_at desc);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  channel text not null default 'internal' check (channel in ('internal','email','whatsapp')),
  type text not null,
  title text not null,
  body text not null,
  action_url text,
  status text not null default 'pending' check (status in ('pending','sent','delivered','error','read')),
  sent_at timestamptz,
  delivered_at timestamptz,
  read_at timestamptz,
  error_message text,
  created_at timestamptz not null default now()
);

create index notifications_profile_status_idx on public.notifications(profile_id, status, created_at desc);

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  protocol text not null unique,
  organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  subject text not null,
  category text,
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  status text not null default 'open' check (status in ('open','in_progress','waiting_user','resolved','closed')),
  assigned_to uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index support_tickets_org_status_idx on public.support_tickets(organization_id, status, created_at desc);
create index support_tickets_profile_idx on public.support_tickets(profile_id, created_at desc);

create trigger support_tickets_set_updated_at
before update on public.support_tickets
for each row execute function public.set_updated_at();

create table public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  is_internal boolean not null default false,
  created_at timestamptz not null default now()
);

create index support_messages_ticket_idx on public.support_messages(ticket_id, created_at);

create table public.favorites (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('course','content','event','community_post')),
  target_id uuid not null,
  created_at timestamptz not null default now(),
  unique (profile_id, target_type, target_id)
);

commit;
