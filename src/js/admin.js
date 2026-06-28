import { getSupabaseClient } from './supabase.js';
import { createCoursesAdmin } from './admin-courses.js';
import { createPeopleAdmin } from './admin-people.js';

const supabase = getSupabaseClient();
const loadingElement = document.querySelector('[data-admin-loading]');
const deniedElement = document.querySelector('[data-admin-denied]');
const errorElement = document.querySelector('[data-admin-error]');
const errorMessageElement = document.querySelector('[data-admin-error-message]');
const contentElement = document.querySelector('[data-admin-content]');
const retryButton = document.querySelector('[data-admin-retry]');
const logoutButton = document.querySelector('[data-admin-logout]');
const navigationElements = document.querySelectorAll('[data-admin-navigation]');

const moduleDefinitions = [
  { id: 'cursos', title: 'Cursos e matrículas', description: 'Criar formações, organizar aulas e acompanhar alunas.', permissions: ['courses.read','courses.manage','courses.edit_assigned','enrollments.read','enrollments.manage'] },
  { id: 'pessoas', title: 'Pessoas e acessos', description: 'Consultar membros, convites, papéis e permissões.', permissions: ['users.read','users.manage','users.invite','roles.manage'] },
  { id: 'comunidade', title: 'Comunidade', description: 'Organizar espaços e realizar moderação.', permissions: ['community.manage','community.moderate'] },
  { id: 'conteudo', title: 'Conteúdo', description: 'Gerenciar publicações, categorias e materiais.', permissions: ['content.read','content.manage','media.read','media.manage'] },
  { id: 'eventos', title: 'Eventos', description: 'Criar encontros e acompanhar inscrições.', permissions: ['events.read','events.manage'] },
  { id: 'atendimento', title: 'Atendimento', description: 'Responder chamados, contatos e solicitações de privacidade.', permissions: ['support.manage','privacy.manage'] },
  { id: 'financeiro', title: 'Financeiro e assinaturas', description: 'Consultar pedidos, assinaturas e pagamentos.', permissions: ['billing.read','billing.manage','orders.read','orders.manage','finance.read','finance.manage'] },
  { id: 'configuracoes', title: 'Configurações', description: 'Administrar a organização, documentos e logs.', permissions: ['organization.manage','organization.settings','legal.manage','logs.read'] }
];

const moduleMap = new Map(moduleDefinitions.map((module) => [module.id, module]));
const adminPermissionSet = new Set(moduleDefinitions.flatMap((module) => module.permissions));
const state = { session: null, context: null, permissions: new Set(), counts: {}, courseAdmin: null, peopleAdmin: null };

function escapeHtml(value = '') {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function initials(profile = {}) {
  return [profile.first_name, profile.last_name]
    .filter(Boolean)
    .map((value) => String(value).trim().charAt(0))
    .join('')
    .slice(0, 2)
    .toUpperCase() || 'LP';
}

function fullName(profile = {}) {
  return [profile.first_name, profile.last_name].filter(Boolean).join(' ').trim() || 'Equipe Lar com Propósito';
}

function canAny(permissionCodes) {
  return Boolean(state.context?.profile?.is_superadmin) || permissionCodes.some((code) => state.permissions.has(code));
}

function setNavigationVisible(visible) {
  navigationElements.forEach((element) => { element.hidden = !visible; });
}

function showOnly(element) {
  [loadingElement, deniedElement, errorElement, contentElement].forEach((item) => {
    if (item) item.hidden = item !== element;
  });
}

async function fallbackContext(user) {
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('id,first_name,last_name,email,status,is_superadmin,created_at')
    .eq('id', user.id)
    .single();
  if (profileError) throw profileError;

  const { data: membership } = await supabase
    .from('organization_members')
    .select('id,organization_id,status,job_title,joined_at,organization:organizations(id,name,slug,status)')
    .eq('profile_id', user.id)
    .eq('status', 'active')
    .maybeSingle();

  let roles = [];
  let permissions = [];

  if (membership?.id) {
    const { data: links } = await supabase
      .from('member_roles')
      .select('role:roles(code,name,role_permissions(permission:permissions(code)))')
      .eq('organization_member_id', membership.id)
      .is('revoked_at', null);

    roles = (links || []).map((link) => ({ code: link.role?.code, name: link.role?.name })).filter((role) => role.code);
    permissions = [...new Set((links || []).flatMap((link) =>
      (link.role?.role_permissions || []).map((item) => item.permission?.code).filter(Boolean)
    ))];
  }

  return {
    profile,
    organization: membership?.organization || {},
    membership: membership ? { id: membership.id, organization_id: membership.organization_id, status: membership.status, job_title: membership.job_title, joined_at: membership.joined_at } : {},
    roles,
    permissions,
    counts: {}
  };
}

async function getContext(user) {
  const { data, error } = await supabase.rpc('get_my_app_context');
  if (!error && data) return data;
  return fallbackContext(user);
}

async function exactCount(table, permissionCodes, filters = []) {
  if (!canAny(permissionCodes)) return null;

  try {
    let query = supabase.from(table).select('*', { count: 'exact', head: true });
    filters.forEach(([method, column, value]) => { query = query[method](column, value); });
    const { count, error } = await query;
    if (error) throw error;
    return count ?? 0;
  } catch (error) {
    console.warn(`Contagem indisponível para ${table}:`, error);
    return null;
  }
}

async function loadCounts() {
  const [members, courses, enrollments, content, events, supportTickets, contactMessages] = await Promise.all([
    exactCount('organization_members', ['users.read','users.manage']),
    exactCount('courses', ['courses.read','courses.manage','courses.edit_assigned'], [['is','deleted_at',null]]),
    exactCount('enrollments', ['enrollments.read','enrollments.manage']),
    exactCount('content_posts', ['content.read','content.manage'], [['is','deleted_at',null]]),
    exactCount('events', ['events.read','events.manage'], [['is','deleted_at',null]]),
    exactCount('support_tickets', ['support.manage']),
    exactCount('contact_messages', ['support.manage'])
  ]);

  state.counts = {
    members,
    courses,
    enrollments,
    content,
    events,
    support: supportTickets === null && contactMessages === null ? null : (supportTickets || 0) + (contactMessages || 0)
  };
}

function renderIdentity() {
  const profile = state.context.profile || {};
  const roles = Array.isArray(state.context.roles) ? state.context.roles : [];
  document.querySelector('[data-admin-name]').textContent = fullName(profile);
  document.querySelector('[data-admin-initials]').textContent = initials(profile);
  document.querySelector('[data-admin-roles]').textContent = roles.map((role) => role.name).filter(Boolean).join(' · ') || 'Acesso administrativo';
}

function renderCounts() {
  Object.entries(state.counts).forEach(([key, value]) => {
    const element = document.querySelector(`[data-admin-count="${key}"]`);
    if (element) element.textContent = value === null ? '—' : String(value);
  });
}

async function refreshCounts() {
  await loadCounts();
  renderCounts();
}

function syncNavigationAccess() {
  document.querySelectorAll('[data-admin-module]').forEach((button) => {
    const definition = moduleMap.get(button.dataset.adminModule);
    button.hidden = !definition || !canAny(definition.permissions);
  });
}

function renderModules() {
  const container = document.querySelector('[data-admin-modules]');
  container.innerHTML = moduleDefinitions.map((module) => {
    const allowed = canAny(module.permissions);
    const active = ['cursos', 'pessoas'].includes(module.id);
    return `<article class="admin-module-card${allowed ? '' : ' is-disabled'}">
      <span class="status-pill">${allowed ? (active ? 'Disponível agora' : 'Acesso liberado') : 'Sem permissão'}</span>
      <div><h3>${escapeHtml(module.title)}</h3><p>${escapeHtml(module.description)}</p></div>
      ${allowed && ['cursos','pessoas','comunidade','conteudo','eventos','atendimento'].includes(module.id)
        ? `<button class="button button-secondary" type="button" data-admin-open="${module.id}">${active ? 'Abrir módulo' : 'Ver próxima etapa'}</button>`
        : ''}
    </article>`;
  }).join('');

  container.querySelectorAll('[data-admin-open]').forEach((button) => {
    button.addEventListener('click', () => showSection(button.dataset.adminOpen));
  });
}

function renderPermissions() {
  const container = document.querySelector('[data-admin-permissions]');
  const permissions = [...state.permissions].sort();
  if (state.context.profile?.is_superadmin) permissions.unshift('superadmin');
  container.innerHTML = permissions.length
    ? permissions.map((code) => `<span class="permission-chip">${escapeHtml(code)}</span>`).join('')
    : '<p>Nenhuma permissão administrativa foi atribuída.</p>';
}

function placeholderContent(section) {
  const definitions = {
    comunidade: ['Comunidade', 'Este módulo reunirá espaços, publicações, denúncias e ações de moderação.'],
    conteudo: ['Conteúdo', 'Este módulo reunirá categorias, publicações, mídia e conteúdos exclusivos.'],
    eventos: ['Eventos', 'Este módulo reunirá encontros, inscrições, capacidade e presença.'],
    atendimento: ['Atendimento', 'Este módulo reunirá chamados, mensagens do formulário e solicitações de privacidade.']
  };
  const [title, description] = definitions[section] || ['Módulo', 'Funcionalidade em desenvolvimento.'];
  return `<div class="admin-empty-module"><p class="admin-eyebrow">Próxima etapa</p><h1>${title}</h1><p>${description}</p><button class="button button-secondary" type="button" data-admin-back>Voltar à visão geral</button></div>`;
}

function prepareSection(section, element) {
  if (section === 'cursos') {
    state.courseAdmin?.mount(element);
    return;
  }
  if (section === 'pessoas') {
    state.peopleAdmin?.mount(element);
    return;
  }
  if (section !== 'visao-geral' && !element.innerHTML.trim()) {
    element.innerHTML = placeholderContent(section);
    element.querySelector('[data-admin-back]')?.addEventListener('click', () => showSection('visao-geral'));
  }
}

function showSection(sectionName) {
  let section = sectionName || 'visao-geral';
  if (section !== 'visao-geral') {
    const definition = moduleMap.get(section);
    if (!definition || !canAny(definition.permissions)) section = 'visao-geral';
  }

  document.querySelectorAll('[data-admin-section]').forEach((element) => {
    element.hidden = element.dataset.adminSection !== section;
    if (!element.hidden) prepareSection(section, element);
  });

  document.querySelectorAll('[data-admin-nav]').forEach((button) => {
    const active = button.dataset.adminNav === section;
    button.classList.toggle('is-active', active);
    button.setAttribute('aria-current', active ? 'page' : 'false');
  });

  history.replaceState(null, '', `#${section}`);
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function hasAdministrativeAccess() {
  return Boolean(state.context.profile?.is_superadmin) || [...state.permissions].some((code) => adminPermissionSet.has(code));
}

async function initialize() {
  setNavigationVisible(false);
  showOnly(loadingElement);

  try {
    const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
    if (sessionError) throw sessionError;
    if (!sessionData.session) {
      window.location.replace('/login');
      return;
    }

    state.session = sessionData.session;
    state.context = await getContext(sessionData.session.user);
    state.permissions = new Set(Array.isArray(state.context.permissions) ? state.context.permissions : []);

    if (!hasAdministrativeAccess()) {
      showOnly(deniedElement);
      return;
    }

    state.courseAdmin = createCoursesAdmin({
      supabase,
      context: state.context,
      session: state.session,
      canAny,
      escapeHtml,
      onChanged: refreshCounts
    });

    state.peopleAdmin = createPeopleAdmin({
      supabase,
      context: state.context,
      session: state.session,
      canAny,
      escapeHtml,
      onChanged: refreshCounts
    });

    await loadCounts();
    renderIdentity();
    renderCounts();
    renderModules();
    renderPermissions();
    syncNavigationAccess();
    setNavigationVisible(true);
    showOnly(contentElement);

    const requested = window.location.hash.replace('#','');
    showSection(requested || 'visao-geral');
  } catch (error) {
    console.error(error);
    setNavigationVisible(false);
    if (errorMessageElement) errorMessageElement.textContent = 'Não foi possível validar suas permissões ou consultar os dados da organização.';
    showOnly(errorElement);
  }
}

document.querySelectorAll('[data-admin-nav]').forEach((button) => {
  button.addEventListener('click', () => showSection(button.dataset.adminNav));
});

logoutButton?.addEventListener('click', async () => {
  logoutButton.disabled = true;
  try {
    await supabase.auth.signOut();
  } finally {
    window.location.replace('/');
  }
});

retryButton?.addEventListener('click', initialize);
window.addEventListener('hashchange', () => {
  const requested = window.location.hash.replace('#','');
  if (requested) showSection(requested);
});

initialize();
