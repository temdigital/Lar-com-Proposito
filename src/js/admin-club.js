const PLAN_STATUS = {
  draft: 'Rascunho',
  active: 'Ativo',
  inactive: 'Inativo',
  archived: 'Arquivado'
};

const SUBSCRIPTION_STATUS = {
  pending: 'Pendente',
  trialing: 'Experiência',
  active: 'Ativa',
  past_due: 'Em atraso',
  paused: 'Pausada',
  cancelled: 'Cancelada',
  expired: 'Expirada'
};

const BILLING_CYCLE = {
  monthly: 'Mensal',
  yearly: 'Anual',
  one_time: 'Acesso único'
};

const RESOURCE_TYPES = {
  course: 'Curso',
  community_space: 'Espaço da comunidade',
  content: 'Conteúdo',
  event: 'Evento'
};

const dateFormatter = new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short' });
const moneyFormatter = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });

function fullName(profile = {}) {
  return [profile.first_name, profile.last_name].filter(Boolean).join(' ').trim() || profile.email || 'Membro';
}

function formatDate(value) {
  if (!value) return 'Sem data';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? 'Sem data' : dateFormatter.format(date);
}

function localDateTime(value) {
  const date = value ? new Date(value) : new Date();
  if (Number.isNaN(date.getTime())) return '';
  const offset = date.getTimezoneOffset();
  return new Date(date.getTime() - offset * 60000).toISOString().slice(0, 16);
}

function isoDateTime(value) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function statusClass(status) {
  if (['active', 'trialing'].includes(status)) return ' is-success';
  if (['inactive', 'paused', 'pending'].includes(status)) return ' is-warning';
  if (['cancelled', 'expired', 'archived', 'past_due'].includes(status)) return ' is-danger';
  return '';
}

function rpcMessage(error, fallback) {
  return error?.message?.replace(/^.*?exception:\s*/i, '') || fallback;
}

export function createClubAdmin({ supabase, context, canAny, escapeHtml, onChanged }) {
  const organizationId = context.organization?.id || context.membership?.organization_id;
  const state = {
    container: null,
    tab: 'plans',
    plans: [],
    subscriptions: [],
    grants: [],
    members: [],
    resources: {
      course: [],
      community_space: [],
      content: [],
      event: []
    },
    editingPlan: null,
    editingSubscription: null,
    draftRules: [],
    mounted: false
  };

  const canRead = () => canAny(['billing.read', 'billing.manage']);
  const canManageBilling = () => canAny(['billing.manage']);
  const canManageAccess = () => canAny(['access.manage']);
  const canWrite = () => canManageBilling() && canManageAccess();

  function shell() {
    return `<div class="club-admin">
      <header class="club-header">
        <div>
          <p class="admin-eyebrow">Homologação sem cobrança real</p>
          <h1>Clube e assinaturas</h1>
          <p>Cadastre planos, organize benefícios e associe assinaturas manuais para validar acessos antes da integração de pagamentos.</p>
        </div>
        <div class="club-header-actions">
          ${canWrite() ? '<button class="button button-secondary" type="button" data-club-reconcile>Reconciliar expirações</button><button class="button" type="button" data-club-new-plan>Novo plano</button>' : ''}
        </div>
      </header>

      <div class="club-notice" role="note">
        <strong>Escopo controlado:</strong> esta etapa não permite contratação, renovação automática, reembolso ou processamento financeiro.
      </div>

      <section class="club-metrics" aria-label="Resumo do clube">
        <article><strong data-club-count="plans">—</strong><span>Planos cadastrados</span></article>
        <article><strong data-club-count="activePlans">—</strong><span>Planos informativos ativos</span></article>
        <article><strong data-club-count="activeSubscriptions">—</strong><span>Assinaturas válidas</span></article>
        <article><strong data-club-count="activeGrants">—</strong><span>Acessos concedidos</span></article>
      </section>

      <nav class="club-tabs" aria-label="Áreas do clube">
        <button class="club-tab is-active" type="button" data-club-tab="plans">Planos</button>
        <button class="club-tab" type="button" data-club-tab="subscriptions">Assinaturas</button>
        <button class="club-tab" type="button" data-club-tab="access">Acessos</button>
      </nav>

      <section class="club-panel" data-club-panel="plans">
        <div class="club-panel-header">
          <div><h2>Planos e benefícios</h2><p>Somente planos ativos aparecem na visualização informativa da área da membro.</p></div>
        </div>
        <div class="club-list" data-club-plans></div>
      </section>

      <section class="club-panel" data-club-panel="subscriptions" hidden>
        <div class="club-panel-header">
          <div><h2>Assinaturas manuais</h2><p>Use dados de teste e períodos curtos para validar concessão, expiração e revogação.</p></div>
          ${canWrite() ? '<button class="button" type="button" data-club-new-subscription>Associar assinatura</button>' : ''}
        </div>
        <div class="club-toolbar">
          <div class="field"><label for="club-subscription-search">Pesquisar</label><input id="club-subscription-search" type="search" placeholder="Nome, e-mail ou plano" data-club-subscription-search></div>
          <div class="field"><label for="club-subscription-status">Situação</label><select id="club-subscription-status" data-club-subscription-status><option value="all">Todas</option>${Object.entries(SUBSCRIPTION_STATUS).map(([value, label]) => `<option value="${value}">${label}</option>`).join('')}</select></div>
        </div>
        <div class="club-list" data-club-subscriptions></div>
      </section>

      <section class="club-panel" data-club-panel="access" hidden>
        <div class="club-panel-header">
          <div><h2>Acessos por assinatura</h2><p>Registros ativos e revogados gerados pelas regras dos planos.</p></div>
        </div>
        <div class="club-list" data-club-grants></div>
      </section>

      <dialog class="club-dialog" data-club-plan-dialog>
        <form data-club-plan-form>
          <div class="club-dialog-header"><div><h2 data-club-plan-title>Novo plano</h2><p>Defina a apresentação, os benefícios e os recursos liberados.</p></div><button class="dialog-close" type="button" data-club-close>×</button></div>
          <div class="club-dialog-body">
            <div class="club-form-grid">
              <div class="field"><label for="club-plan-name">Nome</label><input id="club-plan-name" name="name" maxlength="120" required></div>
              <div class="field"><label for="club-plan-slug">Identificador</label><input id="club-plan-slug" name="slug" pattern="[a-z0-9]+(?:-[a-z0-9]+)*" maxlength="120" required><small>Ex.: clube-essencial</small></div>
              <div class="field"><label for="club-plan-cycle">Ciclo informativo</label><select id="club-plan-cycle" name="billing_cycle"><option value="monthly">Mensal</option><option value="yearly">Anual</option><option value="one_time">Acesso único</option></select></div>
              <div class="field"><label for="club-plan-price">Valor informativo</label><input id="club-plan-price" name="price" type="number" min="0" step="0.01" value="0" required></div>
              <div class="field"><label for="club-plan-trial">Dias de experiência</label><input id="club-plan-trial" name="trial_days" type="number" min="0" max="365" value="0" required></div>
              <div class="field"><label for="club-plan-status">Situação</label><select id="club-plan-status" name="status"><option value="draft">Rascunho</option><option value="active">Ativo</option><option value="inactive">Inativo</option><option value="archived">Arquivado</option></select></div>
              <div class="field is-full"><label for="club-plan-description">Descrição</label><textarea id="club-plan-description" name="description" maxlength="1200"></textarea></div>
              <div class="field is-full"><label for="club-plan-features">Benefícios — um por linha</label><textarea id="club-plan-features" name="features" rows="6" maxlength="4000" placeholder="Encontros mensais\nConteúdos exclusivos\nComunidade acompanhada"></textarea></div>
            </div>

            <section class="club-rule-editor">
              <div><h3>Recursos liberados</h3><p>Além do acesso geral ao clube, associe cursos, espaços, conteúdos ou eventos específicos.</p></div>
              <div class="club-rule-controls">
                <div class="field"><label for="club-rule-type">Tipo</label><select id="club-rule-type" data-club-rule-type>${Object.entries(RESOURCE_TYPES).map(([value, label]) => `<option value="${value}">${label}</option>`).join('')}</select></div>
                <div class="field"><label for="club-rule-resource">Recurso</label><select id="club-rule-resource" data-club-rule-resource></select></div>
                <button class="button button-secondary" type="button" data-club-add-rule>Adicionar</button>
              </div>
              <div class="club-rule-list" data-club-rule-list></div>
            </section>

            <p class="club-feedback" role="status" aria-live="polite" data-club-plan-feedback></p>
            <div class="club-dialog-actions"><button class="button" type="submit">Salvar plano</button><button class="button button-secondary" type="button" data-club-close>Cancelar</button></div>
          </div>
        </form>
      </dialog>

      <dialog class="club-dialog" data-club-subscription-dialog>
        <form data-club-subscription-form>
          <div class="club-dialog-header"><div><h2>Associar assinatura manual</h2><p>Nenhuma cobrança será criada.</p></div><button class="dialog-close" type="button" data-club-close>×</button></div>
          <div class="club-dialog-body">
            <div class="club-form-grid">
              <div class="field is-full"><label for="club-subscription-member">Membro</label><select id="club-subscription-member" name="profile_id" required></select></div>
              <div class="field is-full"><label for="club-subscription-plan">Plano</label><select id="club-subscription-plan" name="plan_id" required></select></div>
              <div class="field"><label for="club-subscription-initial-status">Situação inicial</label><select id="club-subscription-initial-status" name="status"><option value="active">Ativa</option><option value="trialing">Experiência</option></select></div>
              <div class="field"><label for="club-subscription-start">Início</label><input id="club-subscription-start" name="current_period_start" type="datetime-local" required></div>
              <div class="field"><label for="club-subscription-end">Fim</label><input id="club-subscription-end" name="current_period_end" type="datetime-local" required></div>
              <div class="field is-full"><label for="club-subscription-note">Observação de homologação</label><textarea id="club-subscription-note" name="note" maxlength="1000"></textarea></div>
            </div>
            <p class="club-feedback" role="status" aria-live="polite" data-club-subscription-feedback></p>
            <div class="club-dialog-actions"><button class="button" type="submit">Associar e conceder acessos</button><button class="button button-secondary" type="button" data-club-close>Cancelar</button></div>
          </div>
        </form>
      </dialog>

      <dialog class="club-dialog" data-club-manage-dialog>
        <form data-club-manage-form>
          <div class="club-dialog-header"><div><h2 data-club-manage-title>Gerenciar assinatura</h2><p data-club-manage-subtitle></p></div><button class="dialog-close" type="button" data-club-close>×</button></div>
          <div class="club-dialog-body">
            <div class="club-form-grid">
              <div class="field"><label for="club-manage-status">Situação</label><select id="club-manage-status" name="status"><option value="trialing">Experiência</option><option value="active">Ativa</option><option value="paused">Pausada</option><option value="cancelled">Cancelada</option><option value="expired">Expirada</option></select></div>
              <div class="field"><label for="club-manage-end">Fim do período</label><input id="club-manage-end" name="current_period_end" type="datetime-local"></div>
              <label class="club-check is-full"><input name="cancel_at_period_end" type="checkbox"><span>Programar cancelamento para o fim do período</span></label>
              <div class="field is-full"><label for="club-manage-note">Motivo ou observação</label><textarea id="club-manage-note" name="note" maxlength="1000"></textarea></div>
            </div>
            <p class="club-feedback" role="status" aria-live="polite" data-club-manage-feedback></p>
            <div class="club-dialog-actions"><button class="button" type="submit">Salvar e sincronizar acessos</button><button class="button button-secondary" type="button" data-club-close>Cancelar</button></div>
          </div>
        </form>
      </dialog>
    </div>`;
  }

  function setFeedback(selector, message, type = 'error') {
    const element = state.container.querySelector(selector);
    if (!element) return;
    element.textContent = message;
    element.className = `club-feedback is-visible is-${type}`;
  }

  function clearFeedback(selector) {
    const element = state.container.querySelector(selector);
    if (!element) return;
    element.textContent = '';
    element.className = 'club-feedback';
  }

  function empty(title, text) {
    return `<div class="club-empty"><strong>${escapeHtml(title)}</strong><p>${escapeHtml(text)}</p></div>`;
  }

  async function safeSelect(query, label) {
    try {
      const { data, error } = await query;
      if (error) throw error;
      return data || [];
    } catch (error) {
      console.warn(`Consulta indisponível (${label}):`, error);
      return [];
    }
  }

  async function loadData() {
    if (!organizationId || !canRead()) return;

    const [plans, subscriptions, grants, members, courses, spaces, content, events] = await Promise.all([
      safeSelect(
        supabase.from('plans')
          .select('id,organization_id,name,slug,description,billing_cycle,price,currency,status,trial_days,created_at,updated_at,plan_features(id,feature_code,label,value,position),plan_access_rules(id,resource_type,resource_id,label,position)')
          .eq('organization_id', organizationId)
          .order('created_at', { ascending: false }),
        'planos'
      ),
      safeSelect(
        supabase.from('subscriptions')
          .select('id,organization_id,profile_id,plan_id,provider,status,current_period_start,current_period_end,cancel_at_period_end,cancelled_at,created_at,profile:profiles(id,first_name,last_name,email),plan:plans(id,name,slug)')
          .eq('organization_id', organizationId)
          .order('created_at', { ascending: false }),
        'assinaturas'
      ),
      canManageAccess() ? safeSelect(
        supabase.from('access_grants')
          .select('id,profile_id,resource_type,resource_id,source_type,source_id,starts_at,expires_at,revoked_at,revoked_reason,created_at,profile:profiles(id,first_name,last_name,email)')
          .eq('organization_id', organizationId)
          .eq('source_type', 'subscription')
          .order('created_at', { ascending: false })
          .limit(300),
        'acessos'
      ) : Promise.resolve([]),
      safeSelect(
        supabase.from('organization_members')
          .select('profile_id,status,profile:profiles(id,first_name,last_name,email,status)')
          .eq('organization_id', organizationId)
          .eq('status', 'active')
          .is('deleted_at', null),
        'membros'
      ),
      safeSelect(supabase.from('courses').select('id,title').eq('organization_id', organizationId).is('deleted_at', null).order('title'), 'cursos'),
      safeSelect(supabase.from('community_spaces').select('id,name').eq('organization_id', organizationId).order('name'), 'espaços'),
      safeSelect(supabase.from('content_posts').select('id,title').eq('organization_id', organizationId).is('deleted_at', null).order('title'), 'conteúdos'),
      safeSelect(supabase.from('events').select('id,title').eq('organization_id', organizationId).is('deleted_at', null).order('title'), 'eventos')
    ]);

    state.plans = plans;
    state.subscriptions = subscriptions;
    state.grants = grants;
    state.members = members
      .map((item) => item.profile)
      .filter((profile) => profile?.id && profile.status !== 'deleted')
      .sort((a, b) => fullName(a).localeCompare(fullName(b), 'pt-BR'));
    state.resources = {
      course: courses.map((item) => ({ id: item.id, label: item.title })),
      community_space: spaces.map((item) => ({ id: item.id, label: item.name })),
      content: content.map((item) => ({ id: item.id, label: item.title })),
      event: events.map((item) => ({ id: item.id, label: item.title }))
    };
  }

  function renderMetrics() {
    const now = Date.now();
    const values = {
      plans: state.plans.length,
      activePlans: state.plans.filter((plan) => plan.status === 'active').length,
      activeSubscriptions: state.subscriptions.filter((subscription) =>
        ['trialing', 'active'].includes(subscription.status)
        && (!subscription.current_period_end || new Date(subscription.current_period_end).getTime() > now)
      ).length,
      activeGrants: state.grants.filter((grant) => !grant.revoked_at && (!grant.expires_at || new Date(grant.expires_at).getTime() > now)).length
    };

    Object.entries(values).forEach(([key, value]) => {
      const element = state.container.querySelector(`[data-club-count="${key}"]`);
      if (element) element.textContent = String(value);
    });
  }

  function renderPlans() {
    const list = state.container.querySelector('[data-club-plans]');
    if (!state.plans.length) {
      list.innerHTML = empty('Nenhum plano cadastrado', 'Crie o primeiro plano de homologação para organizar benefícios e acessos.');
      return;
    }

    list.innerHTML = state.plans.map((plan) => {
      const features = [...(plan.plan_features || [])].sort((a, b) => a.position - b.position);
      const rules = [...(plan.plan_access_rules || [])].sort((a, b) => a.position - b.position);
      return `<article class="club-card">
        <div class="club-card-main">
          <div class="club-badges"><span class="club-badge${statusClass(plan.status)}">${PLAN_STATUS[plan.status] || plan.status}</span><span class="club-badge">${BILLING_CYCLE[plan.billing_cycle] || plan.billing_cycle}</span></div>
          <h3>${escapeHtml(plan.name)}</h3>
          <p>${escapeHtml(plan.description || 'Plano sem descrição informativa.')}</p>
          <div class="club-card-price"><strong>${moneyFormatter.format(Number(plan.price || 0))}</strong><span>${plan.trial_days ? `${plan.trial_days} dia(s) de experiência` : 'Sem experiência automática'}</span></div>
          <ul class="club-feature-list">${features.length ? features.map((feature) => `<li>${escapeHtml(feature.label)}</li>`).join('') : '<li>Nenhum benefício descritivo cadastrado.</li>'}</ul>
          <p class="club-card-meta">${rules.length} recurso(s) específico(s) · identificador ${escapeHtml(plan.slug)}</p>
        </div>
        ${canWrite() ? `<div class="club-card-actions"><button class="button button-secondary" type="button" data-club-edit-plan="${plan.id}">Editar plano</button></div>` : ''}
      </article>`;
    }).join('');

    list.querySelectorAll('[data-club-edit-plan]').forEach((button) => {
      button.addEventListener('click', () => openPlan(button.dataset.clubEditPlan));
    });
  }

  function filteredSubscriptions() {
    const query = (state.container.querySelector('[data-club-subscription-search]')?.value || '').trim().toLowerCase();
    const status = state.container.querySelector('[data-club-subscription-status]')?.value || 'all';
    return state.subscriptions.filter((subscription) => {
      const haystack = [
        fullName(subscription.profile),
        subscription.profile?.email,
        subscription.plan?.name,
        subscription.plan?.slug
      ].filter(Boolean).join(' ').toLowerCase();
      return (status === 'all' || subscription.status === status) && (!query || haystack.includes(query));
    });
  }

  function renderSubscriptions() {
    const list = state.container.querySelector('[data-club-subscriptions]');
    const rows = filteredSubscriptions();
    if (!rows.length) {
      list.innerHTML = empty('Nenhuma assinatura encontrada', 'Associe uma assinatura manual ou altere os filtros.');
      return;
    }

    list.innerHTML = rows.map((subscription) => `<article class="club-card is-row">
      <div class="club-card-main">
        <div class="club-badges"><span class="club-badge${statusClass(subscription.status)}">${SUBSCRIPTION_STATUS[subscription.status] || subscription.status}</span><span class="club-badge">${subscription.provider === 'manual' || !subscription.provider ? 'Manual' : escapeHtml(subscription.provider)}</span></div>
        <h3>${escapeHtml(fullName(subscription.profile))}</h3>
        <p>${escapeHtml(subscription.profile?.email || 'E-mail não disponível')} · ${escapeHtml(subscription.plan?.name || 'Plano não identificado')}</p>
        <p class="club-card-meta">Período: ${formatDate(subscription.current_period_start)} a ${formatDate(subscription.current_period_end)}${subscription.cancel_at_period_end ? ' · cancelamento programado' : ''}</p>
      </div>
      ${canWrite() ? `<div class="club-card-actions"><button class="button button-secondary" type="button" data-club-manage-subscription="${subscription.id}">Gerenciar</button></div>` : ''}
    </article>`).join('');

    list.querySelectorAll('[data-club-manage-subscription]').forEach((button) => {
      button.addEventListener('click', () => openManageSubscription(button.dataset.clubManageSubscription));
    });
  }

  function renderGrants() {
    const list = state.container.querySelector('[data-club-grants]');
    if (!canManageAccess()) {
      list.innerHTML = empty('Consulta não autorizada', 'Seu papel não possui a permissão access.manage.');
      return;
    }
    if (!state.grants.length) {
      list.innerHTML = empty('Nenhum acesso por assinatura', 'Os acessos surgirão após a primeira associação manual.');
      return;
    }

    list.innerHTML = state.grants.map((grant) => {
      const active = !grant.revoked_at && (!grant.expires_at || new Date(grant.expires_at).getTime() > Date.now());
      return `<article class="club-card is-row">
        <div class="club-card-main">
          <div class="club-badges"><span class="club-badge${active ? ' is-success' : ' is-danger'}">${active ? 'Válido' : 'Revogado ou expirado'}</span><span class="club-badge">${RESOURCE_TYPES[grant.resource_type] || (grant.resource_type === 'club' ? 'Clube' : grant.resource_type)}</span></div>
          <h3>${escapeHtml(fullName(grant.profile))}</h3>
          <p>Recurso ${escapeHtml(grant.resource_id || 'geral')} · origem por assinatura</p>
          <p class="club-card-meta">Início ${formatDate(grant.starts_at)} · fim ${formatDate(grant.expires_at)}${grant.revoked_reason ? ` · ${escapeHtml(grant.revoked_reason)}` : ''}</p>
        </div>
      </article>`;
    }).join('');
  }

  function renderAll() {
    renderMetrics();
    renderPlans();
    renderSubscriptions();
    renderGrants();
  }

  function switchTab(tab) {
    state.tab = tab;
    state.container.querySelectorAll('[data-club-tab]').forEach((button) => {
      button.classList.toggle('is-active', button.dataset.clubTab === tab);
    });
    state.container.querySelectorAll('[data-club-panel]').forEach((panel) => {
      panel.hidden = panel.dataset.clubPanel !== tab;
    });
  }

  function resourceLabel(type, id) {
    return state.resources[type]?.find((item) => item.id === id)?.label || id;
  }

  function updateResourceOptions() {
    const type = state.container.querySelector('[data-club-rule-type]').value;
    const select = state.container.querySelector('[data-club-rule-resource]');
    const options = state.resources[type] || [];
    select.innerHTML = options.length
      ? options.map((item) => `<option value="${item.id}">${escapeHtml(item.label)}</option>`).join('')
      : '<option value="">Nenhum recurso disponível</option>';
  }

  function renderDraftRules() {
    const list = state.container.querySelector('[data-club-rule-list]');
    list.innerHTML = state.draftRules.length
      ? state.draftRules.map((rule, index) => `<div class="club-rule-item"><span><strong>${RESOURCE_TYPES[rule.resource_type]}</strong> · ${escapeHtml(rule.label || resourceLabel(rule.resource_type, rule.resource_id))}</span><button type="button" aria-label="Remover regra" data-club-remove-rule="${index}">×</button></div>`).join('')
      : '<p>Nenhum recurso específico. O acesso geral ao clube será concedido automaticamente.</p>';
    list.querySelectorAll('[data-club-remove-rule]').forEach((button) => {
      button.addEventListener('click', () => {
        state.draftRules.splice(Number(button.dataset.clubRemoveRule), 1);
        renderDraftRules();
      });
    });
  }

  function addDraftRule() {
    const type = state.container.querySelector('[data-club-rule-type]').value;
    const resourceId = state.container.querySelector('[data-club-rule-resource]').value;
    if (!resourceId) return;
    if (state.draftRules.some((rule) => rule.resource_type === type && rule.resource_id === resourceId)) return;
    state.draftRules.push({
      resource_type: type,
      resource_id: resourceId,
      label: resourceLabel(type, resourceId),
      position: state.draftRules.length + 1
    });
    renderDraftRules();
  }

  function openPlan(id = null) {
    const plan = id ? state.plans.find((item) => item.id === id) : null;
    state.editingPlan = plan || null;
    state.draftRules = (plan?.plan_access_rules || []).map((rule) => ({
      resource_type: rule.resource_type,
      resource_id: rule.resource_id,
      label: rule.label,
      position: rule.position
    }));

    const form = state.container.querySelector('[data-club-plan-form]');
    form.reset();
    form.elements.name.value = plan?.name || '';
    form.elements.slug.value = plan?.slug || '';
    form.elements.description.value = plan?.description || '';
    form.elements.billing_cycle.value = plan?.billing_cycle || 'monthly';
    form.elements.price.value = Number(plan?.price || 0);
    form.elements.trial_days.value = Number(plan?.trial_days || 0);
    form.elements.status.value = plan?.status || 'draft';
    form.elements.features.value = [...(plan?.plan_features || [])]
      .sort((a, b) => a.position - b.position)
      .map((feature) => feature.label)
      .join('\n');
    state.container.querySelector('[data-club-plan-title]').textContent = plan ? 'Editar plano' : 'Novo plano';
    clearFeedback('[data-club-plan-feedback]');
    updateResourceOptions();
    renderDraftRules();
    state.container.querySelector('[data-club-plan-dialog]').showModal();
  }

  function openNewSubscription() {
    const form = state.container.querySelector('[data-club-subscription-form]');
    form.reset();
    const memberSelect = form.elements.profile_id;
    const planSelect = form.elements.plan_id;
    memberSelect.innerHTML = state.members.length
      ? state.members.map((profile) => `<option value="${profile.id}">${escapeHtml(fullName(profile))} — ${escapeHtml(profile.email || '')}</option>`).join('')
      : '<option value="">Nenhum membro ativo</option>';
    const availablePlans = state.plans.filter((plan) => !['archived'].includes(plan.status));
    planSelect.innerHTML = availablePlans.length
      ? availablePlans.map((plan) => `<option value="${plan.id}">${escapeHtml(plan.name)} — ${PLAN_STATUS[plan.status]}</option>`).join('')
      : '<option value="">Nenhum plano disponível</option>';
    const start = new Date();
    const end = new Date(start.getTime() + 30 * 24 * 60 * 60 * 1000);
    form.elements.current_period_start.value = localDateTime(start);
    form.elements.current_period_end.value = localDateTime(end);
    clearFeedback('[data-club-subscription-feedback]');
    state.container.querySelector('[data-club-subscription-dialog]').showModal();
  }

  function openManageSubscription(id) {
    const subscription = state.subscriptions.find((item) => item.id === id);
    if (!subscription) return;
    state.editingSubscription = subscription;
    const form = state.container.querySelector('[data-club-manage-form]');
    form.reset();
    form.elements.status.value = ['trialing', 'active', 'paused', 'cancelled', 'expired'].includes(subscription.status) ? subscription.status : 'active';
    form.elements.current_period_end.value = localDateTime(subscription.current_period_end);
    form.elements.cancel_at_period_end.checked = Boolean(subscription.cancel_at_period_end);
    state.container.querySelector('[data-club-manage-title]').textContent = fullName(subscription.profile);
    state.container.querySelector('[data-club-manage-subtitle]').textContent = subscription.plan?.name || 'Plano';
    clearFeedback('[data-club-manage-feedback]');
    state.container.querySelector('[data-club-manage-dialog]').showModal();
  }

  async function refresh() {
    await loadData();
    renderAll();
    await onChanged?.();
  }

  async function submitPlan(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const submit = form.querySelector('[type="submit"]');
    submit.disabled = true;
    clearFeedback('[data-club-plan-feedback]');
    try {
      const features = form.elements.features.value
        .split('\n')
        .map((label) => label.trim())
        .filter(Boolean)
        .map((label, index) => ({ feature_code: `beneficio-${index + 1}`, label, value: true, position: index + 1 }));
      const rules = state.draftRules.map((rule, index) => ({ ...rule, position: index + 1 }));
      const { error } = await supabase.rpc('save_club_plan', {
        p_plan_id: state.editingPlan?.id || null,
        p_name: form.elements.name.value.trim(),
        p_slug: form.elements.slug.value.trim(),
        p_description: form.elements.description.value.trim() || null,
        p_billing_cycle: form.elements.billing_cycle.value,
        p_price: Number(form.elements.price.value || 0),
        p_trial_days: Number(form.elements.trial_days.value || 0),
        p_status: form.elements.status.value,
        p_features: features,
        p_access_rules: rules
      });
      if (error) throw error;
      setFeedback('[data-club-plan-feedback]', 'Plano salvo e acessos sincronizados.', 'success');
      await refresh();
      window.setTimeout(() => state.container.querySelector('[data-club-plan-dialog]').close(), 450);
    } catch (error) {
      setFeedback('[data-club-plan-feedback]', rpcMessage(error, 'Não foi possível salvar o plano.'));
    } finally {
      submit.disabled = false;
    }
  }

  async function submitSubscription(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const submit = form.querySelector('[type="submit"]');
    submit.disabled = true;
    clearFeedback('[data-club-subscription-feedback]');
    try {
      const { error } = await supabase.rpc('assign_manual_subscription', {
        p_profile_id: form.elements.profile_id.value,
        p_plan_id: form.elements.plan_id.value,
        p_status: form.elements.status.value,
        p_current_period_start: isoDateTime(form.elements.current_period_start.value),
        p_current_period_end: isoDateTime(form.elements.current_period_end.value),
        p_note: form.elements.note.value.trim() || null
      });
      if (error) throw error;
      setFeedback('[data-club-subscription-feedback]', 'Assinatura associada e acessos concedidos.', 'success');
      await refresh();
      switchTab('subscriptions');
      window.setTimeout(() => state.container.querySelector('[data-club-subscription-dialog]').close(), 450);
    } catch (error) {
      setFeedback('[data-club-subscription-feedback]', rpcMessage(error, 'Não foi possível associar a assinatura.'));
    } finally {
      submit.disabled = false;
    }
  }

  async function submitManage(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const submit = form.querySelector('[type="submit"]');
    submit.disabled = true;
    clearFeedback('[data-club-manage-feedback]');
    try {
      const { error } = await supabase.rpc('manage_manual_subscription', {
        p_subscription_id: state.editingSubscription.id,
        p_status: form.elements.status.value,
        p_current_period_end: isoDateTime(form.elements.current_period_end.value),
        p_cancel_at_period_end: form.elements.cancel_at_period_end.checked,
        p_note: form.elements.note.value.trim() || null
      });
      if (error) throw error;
      setFeedback('[data-club-manage-feedback]', 'Assinatura e acessos atualizados.', 'success');
      await refresh();
      window.setTimeout(() => state.container.querySelector('[data-club-manage-dialog]').close(), 450);
    } catch (error) {
      setFeedback('[data-club-manage-feedback]', rpcMessage(error, 'Não foi possível atualizar a assinatura.'));
    } finally {
      submit.disabled = false;
    }
  }

  async function reconcile() {
    const button = state.container.querySelector('[data-club-reconcile]');
    button.disabled = true;
    try {
      const { data, error } = await supabase.rpc('reconcile_manual_subscriptions');
      if (error) throw error;
      await refresh();
      window.alert(`Reconciliação concluída: ${data?.expired || 0} expirada(s) e ${data?.synced || 0} sincronizada(s).`);
    } catch (error) {
      window.alert(rpcMessage(error, 'Não foi possível reconciliar as assinaturas.'));
    } finally {
      button.disabled = false;
    }
  }

  function bind() {
    state.container.querySelectorAll('[data-club-tab]').forEach((button) => {
      button.addEventListener('click', () => switchTab(button.dataset.clubTab));
    });
    state.container.querySelector('[data-club-new-plan]')?.addEventListener('click', () => openPlan());
    state.container.querySelector('[data-club-new-subscription]')?.addEventListener('click', openNewSubscription);
    state.container.querySelector('[data-club-reconcile]')?.addEventListener('click', reconcile);
    state.container.querySelector('[data-club-rule-type]')?.addEventListener('change', updateResourceOptions);
    state.container.querySelector('[data-club-add-rule]')?.addEventListener('click', addDraftRule);
    state.container.querySelector('[data-club-plan-form]')?.addEventListener('submit', submitPlan);
    state.container.querySelector('[data-club-subscription-form]')?.addEventListener('submit', submitSubscription);
    state.container.querySelector('[data-club-manage-form]')?.addEventListener('submit', submitManage);
    state.container.querySelector('[data-club-subscription-search]')?.addEventListener('input', renderSubscriptions);
    state.container.querySelector('[data-club-subscription-status]')?.addEventListener('change', renderSubscriptions);
    state.container.querySelectorAll('[data-club-close]').forEach((button) => {
      button.addEventListener('click', () => button.closest('dialog')?.close());
    });
  }

  return {
    async mount(container) {
      state.container = container;
      if (!state.mounted) {
        container.innerHTML = shell();
        bind();
        state.mounted = true;
      }
      await refresh();
    }
  };
}
