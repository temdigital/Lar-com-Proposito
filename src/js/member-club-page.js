import { getSupabaseClient } from './supabase.js';

const supabase = getSupabaseClient();
const loading = document.querySelector('[data-club-loading]');
const errorSection = document.querySelector('[data-club-error]');
const errorMessage = document.querySelector('[data-club-error-message]');
const content = document.querySelector('[data-club-content]');
const retry = document.querySelector('[data-club-retry]');

const moneyFormatter = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
const dateFormatter = new Intl.DateTimeFormat('pt-BR', { dateStyle: 'long' });

const cycleLabels = {
  monthly: 'referência mensal',
  yearly: 'referência anual',
  one_time: 'acesso único'
};

const subscriptionLabels = {
  trialing: 'Período de experiência',
  active: 'Assinatura ativa',
  paused: 'Assinatura pausada',
  cancelled: 'Assinatura cancelada',
  expired: 'Assinatura expirada',
  pending: 'Assinatura pendente',
  past_due: 'Situação pendente de revisão'
};

function escapeHtml(value = '') {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function formatDate(value) {
  if (!value) return 'sem data definida';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? 'sem data definida' : dateFormatter.format(date);
}

function showOnly(element) {
  [loading, errorSection, content].forEach((item) => {
    if (item) item.hidden = item !== element;
  });
}

function empty(title, message) {
  return `<div class="member-club-empty"><strong>${escapeHtml(title)}</strong><p>${escapeHtml(message)}</p></div>`;
}

function renderCurrent(subscriptions) {
  const container = document.querySelector('[data-current-subscription]');
  const now = Date.now();
  const current = subscriptions.find((item) =>
    ['trialing', 'active'].includes(item.status)
    && (!item.current_period_end || new Date(item.current_period_end).getTime() > now)
  ) || subscriptions[0];

  if (!current) {
    container.innerHTML = empty(
      'Nenhuma assinatura associada',
      'O clube está em homologação. Uma associação de teste ou futura liberação aparecerá aqui quando estiver disponível para sua conta.'
    );
    return;
  }

  const planName = current.plan?.name || 'Clube Lar com Propósito';
  const isValid = ['trialing', 'active'].includes(current.status)
    && (!current.current_period_end || new Date(current.current_period_end).getTime() > now);

  container.innerHTML = `<article class="member-club-card${isValid ? ' is-current' : ''}">
    <span class="member-club-badge${isValid ? ' is-active' : ''}">${escapeHtml(subscriptionLabels[current.status] || current.status)}</span>
    <div><h3>${escapeHtml(planName)}</h3><p>${isValid ? 'Seu acesso está liberado conforme os benefícios associados ao plano.' : 'Este registro não concede acesso ativo neste momento.'}</p></div>
    <p class="member-club-meta">Período: ${formatDate(current.current_period_start)} até ${formatDate(current.current_period_end)}${current.cancel_at_period_end ? ' · cancelamento programado para o fim do período' : ''}</p>
  </article>`;
}

function renderPlans(plans) {
  const container = document.querySelector('[data-plan-list]');
  if (!plans.length) {
    container.innerHTML = empty(
      'Planos em preparação',
      'Os planos informativos ainda não foram publicados. Nenhuma cobrança está disponível nesta etapa.'
    );
    return;
  }

  container.innerHTML = plans.map((plan) => {
    const features = [...(plan.plan_features || [])].sort((a, b) => Number(a.position) - Number(b.position));
    return `<article class="member-club-card">
      <span class="member-club-badge">Plano informativo</span>
      <div><h3>${escapeHtml(plan.name)}</h3><p>${escapeHtml(plan.description || 'Uma proposta de formação, comunidade e acompanhamento preparada para a jornada do lar.')}</p></div>
      <div class="member-club-card-price"><strong>${moneyFormatter.format(Number(plan.price || 0))}</strong><span>${escapeHtml(cycleLabels[plan.billing_cycle] || plan.billing_cycle || '')}</span></div>
      <ul class="member-club-features">${features.length
        ? features.map((feature) => `<li>${escapeHtml(feature.label)}</li>`).join('')
        : '<li>Benefícios detalhados serão publicados antes da liberação comercial.</li>'}</ul>
      ${plan.trial_days ? `<p class="member-club-meta">Referência de experiência: ${Number(plan.trial_days)} dia(s).</p>` : ''}
    </article>`;
  }).join('');
}

async function load() {
  showOnly(loading);
  try {
    const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
    if (sessionError) throw sessionError;
    if (!sessionData.session) {
      window.location.replace('/login');
      return;
    }

    const userId = sessionData.session.user.id;
    const [{ data: plans, error: plansError }, { data: subscriptions, error: subscriptionsError }] = await Promise.all([
      supabase
        .from('plans')
        .select('id,name,slug,description,billing_cycle,price,currency,trial_days,status,plan_features(id,label,position,value)')
        .eq('status', 'active')
        .order('price', { ascending: true }),
      supabase
        .from('subscriptions')
        .select('id,status,current_period_start,current_period_end,cancel_at_period_end,created_at,plan:plans(id,name,slug)')
        .eq('profile_id', userId)
        .order('created_at', { ascending: false })
    ]);

    if (plansError) throw plansError;
    if (subscriptionsError) throw subscriptionsError;

    renderCurrent(subscriptions || []);
    renderPlans(plans || []);
    showOnly(content);
  } catch (error) {
    console.error('Falha ao carregar informações do clube:', error);
    if (errorMessage) errorMessage.textContent = 'Não foi possível consultar os planos e sua assinatura. Tente novamente em instantes.';
    showOnly(errorSection);
  }
}

retry?.addEventListener('click', load);
load();
