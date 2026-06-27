begin;

create extension if not exists pgcrypto with schema extensions;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null,
  legal_name text,
  status text not null default 'active' check (status in ('active','suspended','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create unique index organizations_slug_unique
  on public.organizations (lower(slug))
  where deleted_at is null;

create trigger organizations_set_updated_at
before update on public.organizations
for each row execute function public.set_updated_at();

create table public.organization_settings (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  brand_name text not null,
  timezone text not null default 'America/Sao_Paulo',
  locale text not null default 'pt-BR',
  support_email text,
  whatsapp text,
  logo_path text,
  primary_domain text,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger organization_settings_set_updated_at
before update on public.organization_settings
for each row execute function public.set_updated_at();

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null default 'Usuária',
  last_name text,
  email text not null,
  whatsapp text,
  alternative_phone text,
  birth_date date,
  document text,
  photo_url text,
  photo_path text,
  biography text,
  city text,
  address text,
  postal_code text,
  public_slug text,
  status text not null default 'active' check (status in ('pending','active','suspended','blocked','deleted')),
  is_superadmin boolean not null default false,
  terms_accepted_at timestamptz,
  privacy_accepted_at timestamptz,
  last_access_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create unique index profiles_email_unique
  on public.profiles (lower(email))
  where deleted_at is null;

create unique index profiles_public_slug_unique
  on public.profiles (lower(public_slug))
  where public_slug is not null and deleted_at is null;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create table public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  job_title text,
  status text not null default 'active' check (status in ('invited','active','suspended','removed')),
  joined_at timestamptz,
  invited_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (organization_id, profile_id),
  unique (id, organization_id)
);

create index organization_members_profile_idx on public.organization_members(profile_id);
create index organization_members_org_status_idx on public.organization_members(organization_id, status);

create trigger organization_members_set_updated_at
before update on public.organization_members
for each row execute function public.set_updated_at();

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  email text not null,
  whatsapp text,
  role_code text not null,
  job_title text,
  message text,
  token_hash text not null unique,
  status text not null default 'pending' check (status in ('pending','accepted','expired','revoked')),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  accepted_by uuid references auth.users(id) on delete set null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index invitations_org_email_idx on public.invitations(organization_id, lower(email));
create index invitations_status_expires_idx on public.invitations(status, expires_at);

create trigger invitations_set_updated_at
before update on public.invitations
for each row execute function public.set_updated_at();

create table public.terms_versions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  document_type text not null check (document_type in ('terms','privacy','cookies','community_rules')),
  version text not null,
  title text not null,
  content text not null,
  status text not null default 'draft' check (status in ('draft','published','archived')),
  published_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, document_type, version)
);

create trigger terms_versions_set_updated_at
before update on public.terms_versions
for each row execute function public.set_updated_at();

create table public.terms_acceptances (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  terms_version_id uuid not null references public.terms_versions(id) on delete restrict,
  accepted_at timestamptz not null default now(),
  ip_address inet,
  user_agent text,
  unique (profile_id, terms_version_id)
);

create table public.privacy_requests (
  id uuid primary key default gen_random_uuid(),
  protocol text not null unique,
  organization_id uuid references public.organizations(id) on delete set null,
  profile_id uuid references public.profiles(id) on delete set null,
  name text not null,
  email text not null,
  whatsapp text,
  request_type text not null check (request_type in ('access','correction','deletion','anonymization','portability','consent_revocation')),
  description text,
  status text not null default 'open' check (status in ('open','under_review','approved','rejected','completed','cancelled')),
  assigned_to uuid references auth.users(id) on delete set null,
  decision text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index privacy_requests_org_status_idx on public.privacy_requests(organization_id, status);

create trigger privacy_requests_set_updated_at
before update on public.privacy_requests
for each row execute function public.set_updated_at();

create table public.audit_logs (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id) on delete set null,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  old_data jsonb,
  new_data jsonb,
  ip_address inet,
  user_agent text,
  result text not null default 'success' check (result in ('success','failure','denied')),
  created_at timestamptz not null default now()
);

create index audit_logs_org_created_idx on public.audit_logs(organization_id, created_at desc);
create index audit_logs_actor_created_idx on public.audit_logs(actor_id, created_at desc);
create index audit_logs_entity_idx on public.audit_logs(entity_type, entity_id);

commit;
