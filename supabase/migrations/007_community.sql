begin;

create table public.community_spaces (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  slug text not null,
  description text,
  access_type text not null default 'members' check (access_type in ('public','members','course','plan','invite')),
  course_id uuid references public.courses(id) on delete set null,
  plan_id uuid references public.plans(id) on delete set null,
  status text not null default 'active' check (status in ('draft','active','archived')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, slug)
);

create trigger community_spaces_set_updated_at
before update on public.community_spaces
for each row execute function public.set_updated_at();

create table public.community_space_members (
  space_id uuid not null references public.community_spaces(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'active' check (status in ('active','muted','removed')),
  joined_at timestamptz not null default now(),
  primary key (space_id, profile_id)
);

create table public.community_posts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  space_id uuid not null references public.community_spaces(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  title text,
  body text not null,
  status text not null default 'published' check (status in ('draft','published','hidden','removed')),
  is_pinned boolean not null default false,
  published_at timestamptz not null default now(),
  edited_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index community_posts_space_created_idx on public.community_posts(space_id, created_at desc);
create index community_posts_author_idx on public.community_posts(author_id);

create trigger community_posts_set_updated_at
before update on public.community_posts
for each row execute function public.set_updated_at();

create table public.community_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  parent_comment_id uuid references public.community_comments(id) on delete cascade,
  body text not null,
  status text not null default 'published' check (status in ('published','hidden','removed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index community_comments_post_created_idx on public.community_comments(post_id, created_at);

create trigger community_comments_set_updated_at
before update on public.community_comments
for each row execute function public.set_updated_at();

create table public.community_reactions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('post','comment')),
  target_id uuid not null,
  reaction_type text not null default 'like' check (reaction_type in ('like','love','support','gratitude')),
  created_at timestamptz not null default now(),
  unique (profile_id, target_type, target_id, reaction_type)
);

create index community_reactions_target_idx on public.community_reactions(target_type, target_id);

create table public.community_reports (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('post','comment','profile')),
  target_id uuid not null,
  reason text not null,
  description text,
  status text not null default 'open' check (status in ('open','under_review','resolved','dismissed')),
  assigned_to uuid references auth.users(id) on delete set null,
  resolution text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index community_reports_org_status_idx on public.community_reports(organization_id, status);

create table public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  moderator_id uuid not null references auth.users(id) on delete restrict,
  report_id uuid references public.community_reports(id) on delete set null,
  target_type text not null,
  target_id uuid not null,
  action_type text not null check (action_type in ('warn','hide','remove','restore','mute','suspend','ban','dismiss')),
  reason text not null,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.community_suspensions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  space_id uuid references public.community_spaces(id) on delete cascade,
  reason text not null,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  revoked_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create index community_suspensions_profile_idx on public.community_suspensions(profile_id, starts_at, ends_at);

commit;
