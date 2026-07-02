begin;

create table if not exists public.plan_access_rules (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete cascade,
  resource_type text not null check (resource_type in ('course','community_space','content','event')),
  resource_id uuid not null,
  label text not null,
  position integer not null default 1 check (position > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (plan_id, resource_type, resource_id)
);

create index if not exists plan_access_rules_plan_position_idx
  on public.plan_access_rules(plan_id, position, created_at);

drop trigger if exists plan_access_rules_set_updated_at on public.plan_access_rules;
create trigger plan_access_rules_set_updated_at
before update on public.plan_access_rules
for each row execute function public.set_updated_at();

alter table public.plan_access_rules enable row level security;

grant select on public.plan_access_rules to authenticated;

drop policy if exists plan_access_rules_read on public.plan_access_rules;
create policy plan_access_rules_read
on public.plan_access_rules
for select to authenticated
using (
  exists (
    select 1
    from public.plans p
    where p.id = plan_access_rules.plan_id
      and (
        public.has_permission(p.organization_id, 'billing.read')
        or public.has_permission(p.organization_id, 'billing.manage')
      )
  )
);

create or replace function public.sync_subscription_access(
  p_subscription_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_subscription public.subscriptions%rowtype;
  v_rule public.plan_access_rules%rowtype;
  v_is_active boolean;
  v_starts_at timestamptz;
  v_granted integer := 0;
  v_revoked integer := 0;
begin
  select *
    into v_subscription
  from public.subscriptions
  where id = p_subscription_id
  for update;

  if v_subscription.id is null then
    raise exception 'Assinatura não encontrada.';
  end if;

  v_starts_at := coalesce(v_subscription.current_period_start, v_subscription.created_at, now());
  v_is_active := v_subscription.status in ('trialing','active')
    and v_starts_at <= now()
    and (v_subscription.current_period_end is null or v_subscription.current_period_end > now());

  if not v_is_active then
    update public.access_grants
    set revoked_at = coalesce(revoked_at, now()),
        revoked_reason = coalesce(revoked_reason, 'Assinatura inativa, cancelada ou expirada.')
    where source_type = 'subscription'
      and source_id = v_subscription.id
      and revoked_at is null;

    get diagnostics v_revoked = row_count;

    return jsonb_build_object(
      'subscription_id', v_subscription.id,
      'active', false,
      'granted', 0,
      'revoked', v_revoked
    );
  end if;

  update public.access_grants
  set starts_at = v_starts_at,
      expires_at = v_subscription.current_period_end,
      revoked_reason = null
  where source_type = 'subscription'
    and source_id = v_subscription.id
    and resource_type = 'club'
    and resource_id = v_subscription.plan_id
    and revoked_at is null;

  if not found then
    insert into public.access_grants(
      organization_id, profile_id, resource_type, resource_id,
      source_type, source_id, starts_at, expires_at, created_by
    ) values (
      v_subscription.organization_id, v_subscription.profile_id, 'club', v_subscription.plan_id,
      'subscription', v_subscription.id, v_starts_at, v_subscription.current_period_end, auth.uid()
    );
    v_granted := v_granted + 1;
  end if;

  for v_rule in
    select *
    from public.plan_access_rules
    where plan_id = v_subscription.plan_id
    order by position, created_at
  loop
    update public.access_grants
    set starts_at = v_starts_at,
        expires_at = v_subscription.current_period_end,
        revoked_reason = null
    where source_type = 'subscription'
      and source_id = v_subscription.id
      and resource_type = v_rule.resource_type
      and resource_id = v_rule.resource_id
      and revoked_at is null;

    if not found then
      insert into public.access_grants(
        organization_id, profile_id, resource_type, resource_id,
        source_type, source_id, starts_at, expires_at, created_by
      ) values (
        v_subscription.organization_id, v_subscription.profile_id,
        v_rule.resource_type, v_rule.resource_id,
        'subscription', v_subscription.id, v_starts_at,
        v_subscription.current_period_end, auth.uid()
      );
      v_granted := v_granted + 1;
    end if;
  end loop;

  update public.access_grants ag
  set revoked_at = now(),
      revoked_reason = 'Benefício removido do plano.'
  where ag.source_type = 'subscription'
    and ag.source_id = v_subscription.id
    and ag.revoked_at is null
    and not (
      ag.resource_type = 'club'
      and ag.resource_id = v_subscription.plan_id
    )
    and not exists (
      select 1
      from public.plan_access_rules par
      where par.plan_id = v_subscription.plan_id
        and par.resource_type = ag.resource_type
        and par.resource_id = ag.resource_id
    );

  get diagnostics v_revoked = row_count;

  return jsonb_build_object(
    'subscription_id', v_subscription.id,
    'active', true,
    'granted', v_granted,
    'revoked', v_revoked
  );
end;
$$;

create or replace function public.save_club_plan(
  p_plan_id uuid,
  p_name text,
  p_slug text,
  p_description text,
  p_billing_cycle text,
  p_price numeric,
  p_trial_days integer,
  p_status text,
  p_features jsonb default '[]'::jsonb,
  p_access_rules jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_organization_id uuid;
  v_plan public.plans%rowtype;
  v_plan_id uuid;
  v_item jsonb;
  v_position bigint;
  v_feature_code text;
  v_feature_label text;
  v_resource_type text;
  v_resource_id uuid;
  v_resource_label text;
  v_resource_valid boolean;
  v_subscription_id uuid;
  v_old_plan jsonb;
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select om.organization_id
    into v_organization_id
  from public.organization_members om
  where om.profile_id = auth.uid()
    and om.status = 'active'
    and om.deleted_at is null
    and public.has_permission(om.organization_id, 'billing.manage')
    and public.has_permission(om.organization_id, 'access.manage')
  order by om.created_at
  limit 1;

  if v_organization_id is null then
    raise exception 'Você não possui permissão para administrar planos e acessos.';
  end if;

  if char_length(trim(coalesce(p_name, ''))) not between 3 and 120 then
    raise exception 'Informe um nome entre 3 e 120 caracteres.';
  end if;

  if trim(coalesce(p_slug, '')) !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'O identificador deve usar letras minúsculas, números e hífens.';
  end if;

  if lower(trim(coalesce(p_billing_cycle, ''))) not in ('monthly','yearly','one_time') then
    raise exception 'Ciclo de cobrança inválido.';
  end if;

  if coalesce(p_price, -1) < 0 then
    raise exception 'O valor do plano não pode ser negativo.';
  end if;

  if coalesce(p_trial_days, -1) < 0 or p_trial_days > 365 then
    raise exception 'O período de experiência deve ficar entre 0 e 365 dias.';
  end if;

  if lower(trim(coalesce(p_status, ''))) not in ('draft','active','inactive','archived') then
    raise exception 'Situação do plano inválida.';
  end if;

  if p_plan_id is null then
    insert into public.plans(
      organization_id, name, slug, description, billing_cycle,
      price, currency, status, trial_days
    ) values (
      v_organization_id, trim(p_name), trim(p_slug), nullif(trim(coalesce(p_description, '')), ''),
      lower(trim(p_billing_cycle)), p_price, 'BRL', lower(trim(p_status)), p_trial_days
    ) returning * into v_plan;
  else
    select * into v_plan
    from public.plans
    where id = p_plan_id
    for update;

    if v_plan.id is null or v_plan.organization_id <> v_organization_id then
      raise exception 'Plano não encontrado nesta organização.';
    end if;

    v_old_plan := to_jsonb(v_plan);

    update public.plans
    set name = trim(p_name),
        slug = trim(p_slug),
        description = nullif(trim(coalesce(p_description, '')), ''),
        billing_cycle = lower(trim(p_billing_cycle)),
        price = p_price,
        status = lower(trim(p_status)),
        trial_days = p_trial_days
    where id = p_plan_id
    returning * into v_plan;
  end if;

  v_plan_id := v_plan.id;

  delete from public.plan_features where plan_id = v_plan_id;

  for v_item, v_position in
    select value, ordinality
    from jsonb_array_elements(coalesce(p_features, '[]'::jsonb)) with ordinality
  loop
    v_feature_label := trim(coalesce(v_item->>'label', ''));
    if v_feature_label = '' then
      continue;
    end if;

    v_feature_code := lower(trim(coalesce(v_item->>'feature_code', '')));
    if v_feature_code = '' then
      v_feature_code := 'beneficio-' || v_position::text;
    end if;
    v_feature_code := regexp_replace(v_feature_code, '[^a-z0-9_-]+', '-', 'g');

    insert into public.plan_features(plan_id, feature_code, label, value, position)
    values (
      v_plan_id,
      v_feature_code,
      v_feature_label,
      coalesce(v_item->'value', 'true'::jsonb),
      coalesce(nullif(v_item->>'position', '')::integer, v_position::integer)
    );
  end loop;

  delete from public.plan_access_rules where plan_id = v_plan_id;

  for v_item, v_position in
    select value, ordinality
    from jsonb_array_elements(coalesce(p_access_rules, '[]'::jsonb)) with ordinality
  loop
    v_resource_type := lower(trim(coalesce(v_item->>'resource_type', '')));
    v_resource_id := public.try_uuid(v_item->>'resource_id');
    v_resource_label := trim(coalesce(v_item->>'label', ''));

    if v_resource_type not in ('course','community_space','content','event') or v_resource_id is null then
      raise exception 'Regra de acesso inválida na posição %.', v_position;
    end if;

    v_resource_valid := case v_resource_type
      when 'course' then exists (
        select 1 from public.courses c
        where c.id = v_resource_id and c.organization_id = v_organization_id and c.deleted_at is null
      )
      when 'community_space' then exists (
        select 1 from public.community_spaces cs
        where cs.id = v_resource_id and cs.organization_id = v_organization_id
      )
      when 'content' then exists (
        select 1 from public.content_posts cp
        where cp.id = v_resource_id and cp.organization_id = v_organization_id and cp.deleted_at is null
      )
      when 'event' then exists (
        select 1 from public.events e
        where e.id = v_resource_id and e.organization_id = v_organization_id and e.deleted_at is null
      )
      else false
    end;

    if not v_resource_valid then
      raise exception 'O recurso informado não pertence à organização.';
    end if;

    if v_resource_label = '' then
      v_resource_label := initcap(replace(v_resource_type, '_', ' '));
    end if;

    insert into public.plan_access_rules(plan_id, resource_type, resource_id, label, position)
    values (
      v_plan_id, v_resource_type, v_resource_id, v_resource_label,
      coalesce(nullif(v_item->>'position', '')::integer, v_position::integer)
    );
  end loop;

  for v_subscription_id in
    select s.id
    from public.subscriptions s
    where s.plan_id = v_plan_id
      and s.status in ('trialing','active')
  loop
    perform public.sync_subscription_access(v_subscription_id);
  end loop;

  insert into public.audit_logs(
    organization_id, actor_id, action, entity_type, entity_id, old_data, new_data
  ) values (
    v_organization_id,
    auth.uid(),
    case when p_plan_id is null then 'club_plan_created' else 'club_plan_updated' end,
    'plan',
    v_plan_id::text,
    v_old_plan,
    jsonb_build_object(
      'name', trim(p_name),
      'slug', trim(p_slug),
      'status', lower(trim(p_status)),
      'billing_cycle', lower(trim(p_billing_cycle)),
      'price', p_price,
      'features', jsonb_array_length(coalesce(p_features, '[]'::jsonb)),
      'access_rules', jsonb_array_length(coalesce(p_access_rules, '[]'::jsonb))
    )
  );

  return jsonb_build_object(
    'plan_id', v_plan_id,
    'status', v_plan.status,
    'features', jsonb_array_length(coalesce(p_features, '[]'::jsonb)),
    'access_rules', jsonb_array_length(coalesce(p_access_rules, '[]'::jsonb))
  );
end;
$$;

create or replace function public.assign_manual_subscription(
  p_profile_id uuid,
  p_plan_id uuid,
  p_status text,
  p_current_period_start timestamptz,
  p_current_period_end timestamptz,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_plan public.plans%rowtype;
  v_subscription public.subscriptions%rowtype;
  v_status text := lower(trim(coalesce(p_status, 'active')));
  v_start timestamptz := coalesce(p_current_period_start, now());
  v_access jsonb;
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select * into v_plan
  from public.plans
  where id = p_plan_id;

  if v_plan.id is null then
    raise exception 'Plano não encontrado.';
  end if;

  if not public.has_permission(v_plan.organization_id, 'billing.manage')
     or not public.has_permission(v_plan.organization_id, 'access.manage') then
    raise exception 'Você não possui permissão para associar assinaturas e acessos.';
  end if;

  if v_status not in ('trialing','active') then
    raise exception 'A associação inicial deve estar em experiência ou ativa.';
  end if;

  if p_current_period_end is null or p_current_period_end <= v_start then
    raise exception 'Informe uma data final posterior ao início.';
  end if;

  if not exists (
    select 1
    from public.organization_members om
    where om.organization_id = v_plan.organization_id
      and om.profile_id = p_profile_id
      and om.status = 'active'
      and om.deleted_at is null
  ) then
    raise exception 'A pessoa não possui vínculo ativo com esta organização.';
  end if;

  select * into v_subscription
  from public.subscriptions s
  where s.organization_id = v_plan.organization_id
    and s.profile_id = p_profile_id
    and s.plan_id = p_plan_id
    and coalesce(s.provider, 'manual') = 'manual'
    and s.status in ('pending','trialing','active','paused')
  order by s.created_at desc
  limit 1
  for update;

  if v_subscription.id is null then
    insert into public.subscriptions(
      organization_id, profile_id, plan_id, provider, status,
      current_period_start, current_period_end, cancel_at_period_end
    ) values (
      v_plan.organization_id, p_profile_id, p_plan_id, 'manual', v_status,
      v_start, p_current_period_end, false
    ) returning * into v_subscription;
  else
    update public.subscriptions
    set provider = 'manual',
        status = v_status,
        current_period_start = v_start,
        current_period_end = p_current_period_end,
        cancel_at_period_end = false,
        cancelled_at = null
    where id = v_subscription.id
    returning * into v_subscription;
  end if;

  insert into public.subscription_events(subscription_id, event_type, payload)
  values (
    v_subscription.id,
    'manual_assigned',
    jsonb_build_object(
      'status', v_status,
      'period_start', v_start,
      'period_end', p_current_period_end,
      'note', nullif(trim(coalesce(p_note, '')), ''),
      'actor_id', auth.uid()
    )
  );

  v_access := public.sync_subscription_access(v_subscription.id);

  insert into public.audit_logs(
    organization_id, actor_id, action, entity_type, entity_id, new_data
  ) values (
    v_plan.organization_id, auth.uid(), 'manual_subscription_assigned',
    'subscription', v_subscription.id::text,
    jsonb_build_object(
      'profile_id', p_profile_id,
      'plan_id', p_plan_id,
      'status', v_status,
      'period_start', v_start,
      'period_end', p_current_period_end,
      'note', nullif(trim(coalesce(p_note, '')), ''),
      'access', v_access
    )
  );

  return jsonb_build_object(
    'subscription_id', v_subscription.id,
    'status', v_subscription.status,
    'access', v_access
  );
end;
$$;

create or replace function public.manage_manual_subscription(
  p_subscription_id uuid,
  p_status text,
  p_current_period_end timestamptz,
  p_cancel_at_period_end boolean default false,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_subscription public.subscriptions%rowtype;
  v_status text := lower(trim(coalesce(p_status, '')));
  v_access jsonb;
  v_old_subscription jsonb;
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select * into v_subscription
  from public.subscriptions
  where id = p_subscription_id
  for update;

  if v_subscription.id is null then
    raise exception 'Assinatura não encontrada.';
  end if;

  if coalesce(v_subscription.provider, 'manual') <> 'manual' then
    raise exception 'Somente assinaturas manuais podem ser alteradas nesta etapa.';
  end if;

  if not public.has_permission(v_subscription.organization_id, 'billing.manage')
     or not public.has_permission(v_subscription.organization_id, 'access.manage') then
    raise exception 'Você não possui permissão para gerenciar esta assinatura.';
  end if;

  if v_status not in ('trialing','active','paused','cancelled','expired') then
    raise exception 'Situação da assinatura inválida.';
  end if;

  if v_status in ('trialing','active')
     and (p_current_period_end is null or p_current_period_end <= now()) then
    raise exception 'Assinaturas ativas precisam de uma data final futura.';
  end if;

  v_old_subscription := to_jsonb(v_subscription);

  update public.subscriptions
  set provider = 'manual',
      status = v_status,
      current_period_end = p_current_period_end,
      cancel_at_period_end = coalesce(p_cancel_at_period_end, false),
      cancelled_at = case
        when v_status = 'cancelled' then coalesce(cancelled_at, now())
        when v_status in ('trialing','active','paused') then null
        else cancelled_at
      end
  where id = p_subscription_id
  returning * into v_subscription;

  insert into public.subscription_events(subscription_id, event_type, payload)
  values (
    v_subscription.id,
    'manual_status_changed',
    jsonb_build_object(
      'status', v_status,
      'period_end', p_current_period_end,
      'cancel_at_period_end', coalesce(p_cancel_at_period_end, false),
      'note', nullif(trim(coalesce(p_note, '')), ''),
      'actor_id', auth.uid()
    )
  );

  v_access := public.sync_subscription_access(v_subscription.id);

  insert into public.audit_logs(
    organization_id, actor_id, action, entity_type, entity_id, old_data, new_data
  ) values (
    v_subscription.organization_id,
    auth.uid(),
    'manual_subscription_updated',
    'subscription',
    v_subscription.id::text,
    v_old_subscription,
    jsonb_build_object(
      'status', v_status,
      'period_end', p_current_period_end,
      'cancel_at_period_end', coalesce(p_cancel_at_period_end, false),
      'note', nullif(trim(coalesce(p_note, '')), ''),
      'access', v_access
    )
  );

  return jsonb_build_object(
    'subscription_id', v_subscription.id,
    'status', v_subscription.status,
    'access', v_access
  );
end;
$$;

create or replace function public.reconcile_manual_subscriptions()
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_organization_id uuid;
  v_subscription_id uuid;
  v_expired integer := 0;
  v_synced integer := 0;
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select om.organization_id
    into v_organization_id
  from public.organization_members om
  where om.profile_id = auth.uid()
    and om.status = 'active'
    and om.deleted_at is null
    and public.has_permission(om.organization_id, 'billing.manage')
    and public.has_permission(om.organization_id, 'access.manage')
  order by om.created_at
  limit 1;

  if v_organization_id is null then
    raise exception 'Você não possui permissão para reconciliar assinaturas.';
  end if;

  for v_subscription_id in
    select s.id
    from public.subscriptions s
    where s.organization_id = v_organization_id
      and coalesce(s.provider, 'manual') = 'manual'
      and s.status in ('trialing','active','paused')
      and s.current_period_end is not null
      and s.current_period_end <= now()
    for update
  loop
    update public.subscriptions
    set status = 'expired',
        cancel_at_period_end = false
    where id = v_subscription_id;

    insert into public.subscription_events(subscription_id, event_type, payload)
    values (
      v_subscription_id,
      'manual_expired',
      jsonb_build_object('expired_at', now(), 'actor_id', auth.uid())
    );

    perform public.sync_subscription_access(v_subscription_id);
    v_expired := v_expired + 1;
  end loop;

  for v_subscription_id in
    select s.id
    from public.subscriptions s
    where s.organization_id = v_organization_id
      and coalesce(s.provider, 'manual') = 'manual'
      and s.status in ('trialing','active')
      and (s.current_period_end is null or s.current_period_end > now())
  loop
    perform public.sync_subscription_access(v_subscription_id);
    v_synced := v_synced + 1;
  end loop;

  insert into public.audit_logs(
    organization_id, actor_id, action, entity_type, entity_id, new_data
  ) values (
    v_organization_id, auth.uid(), 'manual_subscriptions_reconciled',
    'subscription_batch', v_organization_id::text,
    jsonb_build_object('expired', v_expired, 'synced', v_synced)
  );

  return jsonb_build_object('expired', v_expired, 'synced', v_synced);
end;
$$;

revoke all on function public.sync_subscription_access(uuid) from public;
revoke all on function public.save_club_plan(uuid,text,text,text,text,numeric,integer,text,jsonb,jsonb) from public;
revoke all on function public.assign_manual_subscription(uuid,uuid,text,timestamptz,timestamptz,text) from public;
revoke all on function public.manage_manual_subscription(uuid,text,timestamptz,boolean,text) from public;
revoke all on function public.reconcile_manual_subscriptions() from public;

grant execute on function public.save_club_plan(uuid,text,text,text,text,numeric,integer,text,jsonb,jsonb) to authenticated;
grant execute on function public.assign_manual_subscription(uuid,uuid,text,timestamptz,timestamptz,text) to authenticated;
grant execute on function public.manage_manual_subscription(uuid,text,timestamptz,boolean,text) to authenticated;
grant execute on function public.reconcile_manual_subscriptions() to authenticated;

revoke insert, update, delete on public.plans from authenticated;
revoke insert, update, delete on public.plan_features from authenticated;
revoke insert, update, delete on public.plan_access_rules from authenticated;
revoke insert, update, delete on public.subscriptions from authenticated;
revoke insert, update, delete on public.subscription_events from authenticated;
revoke insert, update, delete on public.access_grants from authenticated;

commit;
