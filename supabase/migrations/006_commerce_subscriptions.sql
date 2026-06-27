begin;

create table public.plans (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  slug text not null,
  description text,
  billing_cycle text not null check (billing_cycle in ('monthly','yearly','one_time')),
  price numeric(12,2) not null check (price >= 0),
  currency char(3) not null default 'BRL',
  status text not null default 'draft' check (status in ('draft','active','inactive','archived')),
  trial_days integer not null default 0 check (trial_days >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, slug)
);

create trigger plans_set_updated_at
before update on public.plans
for each row execute function public.set_updated_at();

create table public.plan_features (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete cascade,
  feature_code text not null,
  label text not null,
  value jsonb not null default 'true'::jsonb,
  position integer not null default 1,
  unique (plan_id, feature_code)
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  plan_id uuid not null references public.plans(id) on delete restrict,
  provider text,
  provider_customer_id text,
  provider_subscription_id text,
  status text not null default 'pending' check (status in ('pending','trialing','active','past_due','paused','cancelled','expired')),
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index subscriptions_provider_unique
  on public.subscriptions(provider, provider_subscription_id)
  where provider_subscription_id is not null;
create index subscriptions_profile_status_idx on public.subscriptions(profile_id, status);
create index subscriptions_org_status_idx on public.subscriptions(organization_id, status);

create trigger subscriptions_set_updated_at
before update on public.subscriptions
for each row execute function public.set_updated_at();

create table public.subscription_events (
  id bigint generated always as identity primary key,
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  event_type text not null,
  provider_event_id text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create unique index subscription_events_provider_unique
  on public.subscription_events(provider_event_id)
  where provider_event_id is not null;

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  order_number text not null,
  status text not null default 'draft' check (status in ('draft','pending','awaiting_payment','paid','partially_refunded','refunded','cancelled','failed')),
  currency char(3) not null default 'BRL',
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  discount numeric(12,2) not null default 0 check (discount >= 0),
  fees numeric(12,2) not null default 0 check (fees >= 0),
  total numeric(12,2) not null default 0 check (total >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  paid_at timestamptz,
  cancelled_at timestamptz,
  unique (organization_id, order_number)
);

create index orders_profile_created_idx on public.orders(profile_id, created_at desc);
create index orders_org_status_idx on public.orders(organization_id, status);

create trigger orders_set_updated_at
before update on public.orders
for each row execute function public.set_updated_at();

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  item_type text not null check (item_type in ('course','plan','event','digital_product')),
  item_id uuid not null,
  description text not null,
  quantity integer not null default 1 check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  discount numeric(12,2) not null default 0 check (discount >= 0),
  total numeric(12,2) not null check (total >= 0)
);

create table public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  provider text not null,
  provider_transaction_id text,
  transaction_type text not null check (transaction_type in ('charge','refund','chargeback','adjustment')),
  status text not null default 'pending' check (status in ('pending','authorized','paid','failed','cancelled','refunded','partially_refunded','chargeback')),
  gross_amount numeric(12,2) not null check (gross_amount >= 0),
  discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0),
  fee_amount numeric(12,2) not null default 0 check (fee_amount >= 0),
  net_amount numeric(12,2) not null check (net_amount >= 0),
  currency char(3) not null default 'BRL',
  payment_method text,
  competence_date date,
  due_at timestamptz,
  paid_at timestamptz,
  refunded_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index payment_transactions_provider_unique
  on public.payment_transactions(provider, provider_transaction_id)
  where provider_transaction_id is not null;
create index payment_transactions_org_created_idx on public.payment_transactions(organization_id, created_at desc);

create trigger payment_transactions_set_updated_at
before update on public.payment_transactions
for each row execute function public.set_updated_at();

create table public.payment_webhooks (
  id bigint generated always as identity primary key,
  provider text not null,
  provider_event_id text not null,
  event_type text not null,
  signature_valid boolean,
  payload jsonb not null,
  processing_status text not null default 'pending' check (processing_status in ('pending','processed','ignored','failed')),
  processing_error text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (provider, provider_event_id)
);

create table public.access_grants (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  resource_type text not null check (resource_type in ('course','community_space','content','event','club')),
  resource_id uuid,
  source_type text not null check (source_type in ('enrollment','subscription','order','invite','manual','promotion')),
  source_id uuid,
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  revoked_reason text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index access_grants_profile_resource_idx on public.access_grants(profile_id, resource_type, resource_id);
create index access_grants_org_active_idx on public.access_grants(organization_id, revoked_at, expires_at);

commit;
