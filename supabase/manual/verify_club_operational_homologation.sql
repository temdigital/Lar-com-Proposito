-- Homologação operacional do módulo Clube e Assinaturas
-- Arquivo somente de leitura. Não altera dados.
-- Execute após criar o plano, associar uma assinatura manual e testar pausa/expiração.

-- 1. Planos, benefícios e recursos vinculados.
select
  p.id as plan_id,
  p.name as plan_name,
  p.slug,
  p.status as plan_status,
  p.billing_cycle,
  p.price,
  p.trial_days,
  count(distinct pf.id) as feature_count,
  count(distinct par.id) as access_rule_count
from public.plans p
left join public.plan_features pf on pf.plan_id = p.id
left join public.plan_access_rules par on par.plan_id = p.id
group by p.id, p.name, p.slug, p.status, p.billing_cycle, p.price, p.trial_days
order by p.created_at desc;

-- 2. Assinaturas manuais e titular.
select
  s.id as subscription_id,
  pr.email as member_email,
  concat_ws(' ', pr.first_name, pr.last_name) as member_name,
  p.name as plan_name,
  p.slug as plan_slug,
  s.provider,
  s.status,
  s.current_period_start,
  s.current_period_end,
  s.cancel_at_period_end,
  s.cancelled_at,
  s.created_at,
  s.updated_at
from public.subscriptions s
join public.profiles pr on pr.id = s.profile_id
join public.plans p on p.id = s.plan_id
where coalesce(s.provider, 'manual') = 'manual'
order by s.created_at desc;

-- 3. Acessos concedidos ou revogados por assinatura.
select
  ag.id as access_grant_id,
  pr.email as member_email,
  p.name as plan_name,
  s.id as subscription_id,
  s.status as subscription_status,
  ag.resource_type,
  ag.resource_id,
  ag.starts_at,
  ag.expires_at,
  ag.revoked_at,
  ag.revoked_reason,
  case
    when ag.revoked_at is not null then 'revoked'
    when ag.starts_at > now() then 'scheduled'
    when ag.expires_at is not null and ag.expires_at <= now() then 'expired'
    else 'active'
  end as effective_access_status
from public.access_grants ag
join public.subscriptions s
  on ag.source_type = 'subscription'
 and ag.source_id = s.id
join public.profiles pr on pr.id = s.profile_id
join public.plans p on p.id = s.plan_id
order by s.created_at desc, ag.resource_type, ag.created_at;

-- 4. Histórico de eventos das assinaturas manuais.
select
  se.id,
  se.subscription_id,
  pr.email as member_email,
  p.name as plan_name,
  se.event_type,
  se.payload,
  se.created_at
from public.subscription_events se
join public.subscriptions s on s.id = se.subscription_id
join public.profiles pr on pr.id = s.profile_id
join public.plans p on p.id = s.plan_id
where coalesce(s.provider, 'manual') = 'manual'
order by se.created_at desc;

-- 5. Auditoria específica do módulo.
select
  al.id,
  al.actor_id,
  al.action,
  al.entity_type,
  al.entity_id,
  al.old_data,
  al.new_data,
  al.result,
  al.created_at
from public.audit_logs al
where al.action in (
  'club_plan_created',
  'club_plan_updated',
  'manual_subscription_assigned',
  'manual_subscription_updated',
  'manual_subscriptions_reconciled'
)
order by al.created_at desc;
