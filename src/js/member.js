import { getSupabaseClient } from './supabase.js';

const supabase = getSupabaseClient();
const loadingElement = document.querySelector('[data-app-loading]');
const contentElement = document.querySelector('[data-app-content]');
const errorElement = document.querySelector('[data-app-error]');
const errorMessageElement = document.querySelector('[data-app-error-message]');
const retryButton = document.querySelector('[data-retry]');
const logoutButtons = document.querySelectorAll('[data-logout]');
const profileForm = document.querySelector('[data-profile-form]');
const profileFeedback = document.querySelector('[data-profile-feedback]');
const profileSubmit = document.querySelector('[data-profile-submit]');

const validSections = new Set(['inicio', 'cursos', 'comunidade', 'conteudos', 'perfil']);
const adminPermissionCodes = new Set([
  'organization.manage', 'organization.settings', 'users.read', 'users.manage',
  'courses.manage', 'courses.edit_assigned', 'enrollments.read', 'enrollments.manage',
  'community.manage', 'community.moderate', 'billing.read', 'billing.manage',
  'orders.read', 'orders.manage', 'finance.read', 'finance.manage',
  'content.read', 'content.manage', 'events.read', 'events.manage',
  'support.manage', 'privacy.manage', 'legal.manage', 'logs.read'
]);

const state = {
  session: null,
  context: null,
  enrollments: [],
  spaces: [],
  posts: [],
  events: [],
  subscriptions: [],
  notifications: []
};

const dateFormatter = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: 'short', year: 'numeric' });
const dateTimeFormatter = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });

function escapeHtml(value = '') {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function formatDate(value, withTime = false) {
  if (!value) return 'Data a definir';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Data a definir';
  return (withTime ? dateTimeFormatter : dateFormatter).format(date);
}

function initials(profile = {}) {
  const parts = [profile.first_name, profile.last_name].filter(Boolean);
  const result = parts.map((part) => String(part).trim().charAt(0)).join('').slice(0, 2);
  return result.toUpperCase() || 'LP';
}

function fullName(profile = {}) {
  return [profile.first_name, profile.last_name].filter(Boolean).join(' ').trim() || 'Membro Lar com Propósito';
}

function emptyState(title, message) {
  return `<div class="empty-state"><strong>${escapeHtml(title)}</strong><p>${escapeHtml(message)}</p></div>`;
}

function showError(message) {
  loadingElement.hidden = true;
  contentElement.hidden = true;
  errorElement.hidden = false;
  if (errorMessageElement) errorMessageElement.textContent = message;
}

function showContent() {
  loadingElement.hidden = true;
  errorElement.hidden = true;
  contentElement.hidden = false;
}

function showSection(sectionName, updateUrl = true) {
  const section = validSections.has(sectionName) ? sectionName : 'inicio';

  document.querySelectorAll('[data-section]').forEach((element) => {
    element.hidden = element.dataset.section !== section;
  });

  document.querySelectorAll('[data-nav-target]').forEach((button) => {
    const isActive = button.dataset.navTarget === section;
    button.classList.toggle('is-active', isActive);
    if (button.classList.contains('app-nav-button')) {
      button.setAttribute('aria-current', isActive ? 'page' : 'false');
    }
  });

  if (updateUrl) history.replaceState(null, '', `#${section}`);
  document.querySelector(`[data-section="${section}"]`)?.querySelector('h1')?.focus?.({ preventScroll: true });
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

async function getContext(user) {
  const { data, error } = await supabase.rpc('get_my_app_context');
  if (!error && data) return data;

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('id,first_name,last_name,email,whatsapp,alternative_phone,birth_date,photo_url,biography,city,postal_code,status,is_superadmin,last_access_at,created_at')
    .eq('id', user.id)
    .single();
  if (profileError) throw profileError;

  const { data: membership } = await supabase
    .from('organization_members')
    .select('id,organization_id,status,job_title,joined_at,organization:organizations(id,name,slug,status)')
    .eq('profile_id', user.id)
    .eq('status', 'active')
    .maybeSingle();

  return {
    profile,
    organization: membership?.organization || {},
    membership: membership ? {
      id: membership.id,
      status: membership.status,
      job_title: membership.job_title,
      joined_at: membership.joined_at
    } : {},
    roles: [{ code: 'membro', name: 'Membro' }],
    permissions: [],
    counts: {
      active_enrollments: 0,
      completed_enrollments: 0,
      unread_notifications: 0,
      active_subscriptions: 0,
      favorites: 0
    }
  };
}

async function safeQuery(queryPromise) {
  try {
    const { data, error } = await queryPromise;
    if (error) throw error;
    return data || [];
  } catch (error) {
    console.warn('Módulo ainda indisponível:', error);
    return [];
  }
}

async function loadMemberData(user) {
  const now = new Date().toISOString();
  const [enrollments, spaces, posts, events, subscriptions, notifications] = await Promise.all([
    safeQuery(
      supabase.from('enrollments')
        .select('id,status,enrolled_at,completed_at,course:courses(id,title,slug,subtitle,description,cover_path,certificate_enabled,status),lesson_progress(progress_percent,completed_at)')
        .eq('profile_id', user.id)
        .order('enrolled_at', { ascending: false })
    ),
    safeQuery(
      supabase.from('community_spaces')
        .select('id,name,slug,description,access_type,status,created_at')
        .eq('status', 'active')
        .order('created_at', { ascending: false })
    ),
    safeQuery(
      supabase.from('content_posts')
        .select('id,title,slug,excerpt,published_at,is_members_only,created_at')
        .eq('status', 'published')
        .order('published_at', { ascending: false })
        .limit(12)
    ),
    safeQuery(
      supabase.from('events')
        .select('id,title,slug,description,event_type,location_name,starts_at,ends_at,price,status')
        .eq('status', 'published')
        .gte('starts_at', now)
        .order('starts_at', { ascending: true })
        .limit(6)
    ),
    safeQuery(
      supabase.from('subscriptions')
        .select('id,status,current_period_end,cancel_at_period_end,created_at,plan:plans(name,slug,billing_cycle,price,currency)')
        .eq('profile_id', user.id)
        .order('created_at', { ascending: false })
        .limit(3)
    ),
    safeQuery(
      supabase.from('notifications')
        .select('id,title,body,action_url,status,created_at')
        .eq('profile_id', user.id)
        .order('created_at', { ascending: false })
        .limit(8)
    )
  ]);

  Object.assign(state, { enrollments, spaces, posts, events, subscriptions, notifications });
}

function enrollmentProgress(enrollment) {
  const progressItems = Array.isArray(enrollment.lesson_progress) ? enrollment.lesson_progress : [];
  if (!progressItems.length) return enrollment.status === 'completed' ? 100 : 0;
  const sum = progressItems.reduce((total, item) => total + Number(item.progress_percent || 0), 0);
  return Math.max(0, Math.min(100, Math.round(sum / progressItems.length)));
}

function renderCourseCard(enrollment) {
  const course = enrollment.course || {};
  const progress = enrollmentProgress(enrollment);
  const statusLabel = enrollment.status === 'completed' ? 'Concluído' : enrollment.status === 'active' ? 'Em andamento' : 'Matrícula registrada';

  return `<article class="learning-card">
    <span class="status-pill${enrollment.status === 'completed' ? '' : ' is-muted'}">${statusLabel}</span>
    <div>
      <h3>${escapeHtml(course.title || 'Curso em preparação')}</h3>
      <p>${escapeHtml(course.subtitle || course.description || 'Os detalhes desta formação serão publicados em breve.')}</p>
    </div>
    <div>
      <div class="card-meta"><span>${progress}% concluído</span><span>Matrícula em ${formatDate(enrollment.enrolled_at)}</span></div>
      <div class="progress-track" aria-label="${progress}% concluído"><span style="width:${progress}%"></span></div>
    </div>
    <div class="card-actions">
      <span class="button button-secondary" aria-disabled="true">${progress > 0 ? 'Continuar em breve' : 'Aguardar liberação'}</span>
    </div>
  </article>`;
}

function renderCourses() {
  const active = state.enrollments.filter((item) => item.status === 'active');
  const overviewContainer = document.querySelector('[data-overview-courses]');
  const listContainer = document.querySelector('[data-course-list]');

  overviewContainer.innerHTML = active.length
    ? active.slice(0, 2).map(renderCourseCard).join('')
    : emptyState('Nenhum curso em andamento', 'Quando uma formação for liberada para sua conta, ela aparecerá aqui.');

  listContainer.innerHTML = state.enrollments.length
    ? state.enrollments.map(renderCourseCard).join('')
    : emptyState('Sua jornada de formação começará em breve', 'Você ainda não possui matrículas ativas. Novos cursos serão apresentados pela página pública e pela comunidade.');
}

function renderEvents() {
  const container = document.querySelector('[data-upcoming-events]');
  container.innerHTML = state.events.length
    ? state.events.slice(0, 3).map((event) => `<article class="list-card">
        <span class="status-pill">${event.event_type === 'online' ? 'Online' : event.event_type === 'hybrid' ? 'Híbrido' : 'Presencial'}</span>
        <div><h3>${escapeHtml(event.title)}</h3><p>${escapeHtml(event.description || 'Mais informações serão publicadas em breve.')}</p></div>
        <div class="card-meta"><span>${formatDate(event.starts_at, true)}</span>${event.location_name ? `<span>${escapeHtml(event.location_name)}</span>` : ''}</div>
      </article>`).join('')
    : emptyState('Nenhum encontro agendado', 'Os próximos encontros, retiros e eventos aparecerão aqui.');
}

function renderSubscription() {
  const container = document.querySelector('[data-subscription-summary]');
  const subscription = state.subscriptions.find((item) => ['active', 'trialing'].includes(item.status));

  if (!subscription) {
    container.innerHTML = emptyState('Clube ainda não ativo', 'A assinatura será disponibilizada após a homologação dos planos e pagamentos.');
    return;
  }

  container.innerHTML = `<article class="list-card">
    <span class="status-pill">${subscription.status === 'trialing' ? 'Período de experiência' : 'Assinatura ativa'}</span>
    <div><h3>${escapeHtml(subscription.plan?.name || 'Clube Lar com Propósito')}</h3><p>${subscription.cancel_at_period_end ? 'Cancelamento programado para o fim do período.' : 'Seu acesso está ativo.'}</p></div>
    <div class="card-meta"><span>Próxima renovação: ${formatDate(subscription.current_period_end)}</span></div>
  </article>`;
}

function renderCommunity() {
  const container = document.querySelector('[data-community-list]');
  container.innerHTML = state.spaces.length
    ? state.spaces.map((space) => `<article class="list-card">
        <span class="status-pill">${space.access_type === 'public' ? 'Espaço público' : 'Acesso liberado'}</span>
        <div><h3>${escapeHtml(space.name)}</h3><p>${escapeHtml(space.description || 'Espaço de troca, formação e acolhimento entre as participantes.')}</p></div>
        <div class="card-actions"><span class="button button-secondary" aria-disabled="true">Conversas em breve</span></div>
      </article>`).join('')
    : emptyState('Comunidade em preparação', 'Os espaços de convivência serão liberados de acordo com cursos, convites e planos.');
}

function renderContent() {
  const container = document.querySelector('[data-content-list]');
  container.innerHTML = state.posts.length
    ? state.posts.map((post) => `<article class="content-card">
        <span class="status-pill${post.is_members_only ? '' : ' is-muted'}">${post.is_members_only ? 'Exclusivo para membros' : 'Conteúdo aberto'}</span>
        <div><h3>${escapeHtml(post.title)}</h3><p>${escapeHtml(post.excerpt || 'Conteúdo preparado para inspirar o cotidiano do lar.')}</p></div>
        <div class="card-meta"><span>${formatDate(post.published_at || post.created_at)}</span></div>
      </article>`).join('')
    : emptyState('Conteúdos em produção', 'As primeiras reflexões, orientações e materiais serão publicados nesta área.');
}

function renderProfile() {
  const profile = state.context.profile || {};
  const roles = Array.isArray(state.context.roles) ? state.context.roles : [];
  const roleNames = roles.map((role) => role.name).filter(Boolean).join(' · ') || 'Membro';
  const name = fullName(profile);
  const initialText = initials(profile);

  document.querySelectorAll('[data-user-name]').forEach((element) => { element.textContent = name; });
  document.querySelectorAll('[data-user-initials],[data-profile-initials]').forEach((element) => { element.textContent = initialText; });
  document.querySelector('[data-welcome-name]').textContent = profile.first_name || 'mulher que edifica';
  document.querySelector('[data-profile-name]').textContent = name;
  document.querySelector('[data-profile-email]').textContent = profile.email || state.session.user.email || '';
  document.querySelector('[data-profile-role]').textContent = roleNames;
  document.querySelector('[data-profile-since]').textContent = `Membro desde ${formatDate(state.context.membership?.joined_at || profile.created_at)}`;

  profileForm.elements.first_name.value = profile.first_name || '';
  profileForm.elements.last_name.value = profile.last_name || '';
  profileForm.elements.email.value = profile.email || state.session.user.email || '';
  profileForm.elements.whatsapp.value = profile.whatsapp || '';
  profileForm.elements.city.value = profile.city || '';
  profileForm.elements.postal_code.value = profile.postal_code || '';
  profileForm.elements.biography.value = profile.biography || '';
}

function renderMetricsAndAccess() {
  const counts = state.context.counts || {};
  const activeCount = state.enrollments.filter((item) => item.status === 'active').length || Number(counts.active_enrollments || 0);
  const completedCount = state.enrollments.filter((item) => item.status === 'completed').length || Number(counts.completed_enrollments || 0);
  const unreadCount = state.notifications.filter((item) => item.status !== 'read').length || Number(counts.unread_notifications || 0);

  document.querySelector('[data-count-active-courses]').textContent = String(activeCount);
  document.querySelector('[data-count-completed-courses]').textContent = String(completedCount);
  document.querySelector('[data-count-favorites]').textContent = String(counts.favorites || 0);
  document.querySelector('[data-count-notifications]').textContent = String(unreadCount);

  const badge = document.querySelector('[data-notification-count]');
  if (unreadCount > 0) {
    badge.textContent = unreadCount > 99 ? '99+' : String(unreadCount);
    badge.hidden = false;
  } else {
    badge.hidden = true;
  }

  const permissions = new Set(Array.isArray(state.context.permissions) ? state.context.permissions : []);
  const hasAdminAccess = Boolean(state.context.profile?.is_superadmin) || [...permissions].some((code) => adminPermissionCodes.has(code));
  document.querySelectorAll('[data-admin-link]').forEach((link) => { link.hidden = !hasAdminAccess; });
  document.querySelector('[data-admin-callout]')?.classList.toggle('is-visible', hasAdminAccess);
}

function renderAll() {
  renderProfile();
  renderMetricsAndAccess();
  renderCourses();
  renderEvents();
  renderSubscription();
  renderCommunity();
  renderContent();
}

function showProfileFeedback(message, type) {
  profileFeedback.textContent = message;
  profileFeedback.className = `form-feedback is-visible is-${type}`;
}

async function saveProfile(event) {
  event.preventDefault();
  const formData = new FormData(profileForm);
  const firstName = String(formData.get('first_name') || '').trim();

  if (firstName.length < 2) {
    showProfileFeedback('Informe um nome com pelo menos 2 caracteres.', 'error');
    return;
  }

  profileSubmit.disabled = true;
  profileSubmit.textContent = 'Salvando…';
  profileFeedback.className = 'form-feedback';

  const updates = {
    first_name: firstName,
    last_name: String(formData.get('last_name') || '').trim() || null,
    whatsapp: String(formData.get('whatsapp') || '').trim() || null,
    city: String(formData.get('city') || '').trim() || null,
    postal_code: String(formData.get('postal_code') || '').trim() || null,
    biography: String(formData.get('biography') || '').trim() || null
  };

  try {
    const { data, error } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', state.session.user.id)
      .select('id,first_name,last_name,email,whatsapp,alternative_phone,birth_date,photo_url,biography,city,postal_code,status,is_superadmin,last_access_at,created_at')
      .single();
    if (error) throw error;

    state.context.profile = data;
    renderProfile();
    showProfileFeedback('Perfil atualizado com sucesso.', 'success');
  } catch (error) {
    console.error(error);
    showProfileFeedback('Não foi possível salvar suas alterações. Tente novamente.', 'error');
  } finally {
    profileSubmit.disabled = false;
    profileSubmit.textContent = 'Salvar alterações';
  }
}

async function initialize() {
  loadingElement.hidden = false;
  errorElement.hidden = true;
  contentElement.hidden = true;

  try {
    const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
    if (sessionError) throw sessionError;
    if (!sessionData.session) {
      window.location.replace('/login');
      return;
    }

    state.session = sessionData.session;
    await supabase.rpc('register_last_access');
    state.context = await getContext(sessionData.session.user);
    await loadMemberData(sessionData.session.user);
    renderAll();
    showContent();

    const requestedSection = window.location.hash.replace('#', '');
    showSection(validSections.has(requestedSection) ? requestedSection : 'inicio', false);
  } catch (error) {
    console.error(error);
    showError(error?.message === 'SUPABASE_NOT_CONFIGURED'
      ? 'A conexão com o Supabase ainda não foi configurada.'
      : 'Não foi possível validar sua sessão ou carregar seus dados.');
  }
}

document.querySelectorAll('[data-nav-target]').forEach((button) => {
  button.addEventListener('click', () => showSection(button.dataset.navTarget));
});

logoutButtons.forEach((button) => {
  button.addEventListener('click', async () => {
    button.disabled = true;
    try {
      await supabase.auth.signOut();
    } finally {
      window.location.replace('/');
    }
  });
});

profileForm?.addEventListener('submit', saveProfile);
retryButton?.addEventListener('click', initialize);
window.addEventListener('hashchange', () => {
  const requested = window.location.hash.replace('#', '');
  if (validSections.has(requested)) showSection(requested, false);
});

initialize();
