begin;

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  is_system boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger roles_set_updated_at
before update on public.roles
for each row execute function public.set_updated_at();

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  module text not null,
  description text,
  created_at timestamptz not null default now()
);

create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role_id, permission_id)
);

create table public.member_roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  organization_member_id uuid not null,
  role_id uuid not null references public.roles(id) on delete restrict,
  assigned_by uuid references auth.users(id) on delete set null,
  assigned_at timestamptz not null default now(),
  revoked_at timestamptz,
  constraint member_roles_member_org_fk
    foreign key (organization_member_id, organization_id)
    references public.organization_members(id, organization_id)
    on delete cascade,
  unique (organization_member_id, role_id)
);

create index member_roles_org_idx on public.member_roles(organization_id);
create index member_roles_role_idx on public.member_roles(role_id);

commit;
