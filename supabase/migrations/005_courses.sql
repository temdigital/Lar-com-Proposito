begin;

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  title text not null,
  slug text not null,
  subtitle text,
  description text,
  cover_path text,
  status text not null default 'draft' check (status in ('draft','review','published','archived')),
  access_type text not null default 'paid' check (access_type in ('free','paid','subscription','invite')),
  price numeric(12,2) not null default 0 check (price >= 0),
  certificate_enabled boolean not null default false,
  published_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create unique index courses_org_slug_unique
  on public.courses(organization_id, lower(slug))
  where deleted_at is null;
create index courses_org_status_idx on public.courses(organization_id, status);

create trigger courses_set_updated_at
before update on public.courses
for each row execute function public.set_updated_at();

create table public.course_instructors (
  course_id uuid not null references public.courses(id) on delete cascade,
  organization_member_id uuid not null references public.organization_members(id) on delete cascade,
  is_lead boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (course_id, organization_member_id)
);

create table public.course_modules (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  title text not null,
  description text,
  position integer not null check (position > 0),
  release_type text not null default 'immediate' check (release_type in ('immediate','days_after_enrollment','fixed_date')),
  release_after_days integer check (release_after_days is null or release_after_days >= 0),
  release_at timestamptz,
  status text not null default 'draft' check (status in ('draft','published','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_id, position)
);

create trigger course_modules_set_updated_at
before update on public.course_modules
for each row execute function public.set_updated_at();

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  course_module_id uuid not null references public.course_modules(id) on delete cascade,
  title text not null,
  slug text not null,
  description text,
  content_html text,
  lesson_type text not null default 'video' check (lesson_type in ('video','text','download','live')),
  video_provider text check (video_provider in ('youtube','none')),
  youtube_video_id text,
  duration_seconds integer check (duration_seconds is null or duration_seconds >= 0),
  position integer not null check (position > 0),
  is_preview boolean not null default false,
  status text not null default 'draft' check (status in ('draft','published','archived')),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_module_id, position),
  unique (course_module_id, slug)
);

create trigger lessons_set_updated_at
before update on public.lessons
for each row execute function public.set_updated_at();

create table public.lesson_materials (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  title text not null,
  bucket text not null,
  storage_path text not null,
  mime_type text,
  size_bytes bigint check (size_bytes is null or size_bytes >= 0),
  position integer not null default 1 check (position > 0),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (lesson_id, storage_path)
);

create table public.enrollments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  source_type text not null default 'manual' check (source_type in ('manual','order','subscription','invite','promotion')),
  source_id uuid,
  status text not null default 'active' check (status in ('pending','active','completed','cancelled','expired')),
  enrolled_at timestamptz not null default now(),
  starts_at timestamptz,
  expires_at timestamptz,
  completed_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (course_id, profile_id)
);

create index enrollments_profile_status_idx on public.enrollments(profile_id, status);
create index enrollments_org_course_idx on public.enrollments(organization_id, course_id);

create trigger enrollments_set_updated_at
before update on public.enrollments
for each row execute function public.set_updated_at();

create table public.lesson_progress (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.enrollments(id) on delete cascade,
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  progress_percent numeric(5,2) not null default 0 check (progress_percent between 0 and 100),
  watched_seconds integer not null default 0 check (watched_seconds >= 0),
  started_at timestamptz,
  completed_at timestamptz,
  last_access_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (enrollment_id, lesson_id)
);

create trigger lesson_progress_set_updated_at
before update on public.lesson_progress
for each row execute function public.set_updated_at();

create table public.certificates (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null unique references public.enrollments(id) on delete cascade,
  verification_code text not null unique,
  issued_at timestamptz not null default now(),
  storage_path text,
  revoked_at timestamptz,
  revocation_reason text
);

commit;
