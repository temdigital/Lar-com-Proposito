const MEMBER_STATUS = {
  active: 'Ativa',
  invited: 'Aguardando confirmação',
  suspended: 'Suspensa',
  removed: 'Removida'
};

const INVITATION_STATUS = {
  pending: 'Pendente',
  accepted: 'Aceito',
  revoked: 'Revogado',
  expired: 'Expirado'
};

function fullName(profile = {}) {
  return [profile.first_name, profile.last_name].filter(Boolean).join(' ').trim() || 'Membro sem nome';
}

function initials(profile = {}) {
  return [profile.first_name, profile.last_name]
    .filter(Boolean)
    .map((part) => String(part).trim().charAt(0))
    .join('')
    .slice(0, 2)
    .toUpperCase() || 'LP';
}

function normalizePhone(value = '') {
  return String(value).replace(/\D/g, '');
}

function formatDate(value, withTime = false) {
  if (!value) return 'Não registrado';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Não registrado';
  return new Intl.DateTimeFormat('pt-BR', withTime
    ? { dateStyle: 'short', timeStyle: 'short' }
    : { dateStyle: 'short' }).format(date);
}

export function createPeopleAdmin({ supabase, context, session, canAny, escapeHtml, onChanged }) {
  const state = {
    container: null,
    members: [],
    roles: [],
    invitations: [],
    activeTab: 'members',
    selectedMember: null,
    mounted: false
  };

  const organizationId = context.organization?.id || context.membership?.organization_id;
  const canRead = () => canAny(['users.read', 'users.manage']);
  const canManageUsers = () => canAny(['users.manage']);
  const canManageRoles = () => canAny(['roles.manage']);
  const canInvite = () => canAny(['users.invite']);

  function displayInvitationStatus(invitation) {
    if (invitation.status === 'pending' && new Date(invitation.expires_at) <= new Date()) return 'expired';
    return invitation.status;
  }

  function shell() {
    return `<div class="people-admin">
      <header class="people-admin-header">
        <div><p class="admin-eyebrow">Gestão de acesso</p><h1>Pessoas e acessos</h1><p>Consulte membros, atribua funções à equipe e acompanhe convites com rastreabilidade.</p></div>
        <div class="people-header-actions">${canInvite() ? '<button class="button" type="button" data-invite-new>Convidar pessoa</button>' : ''}</div>
      </header>

      <nav class="people-tabs" aria-label="Áreas de pessoas e acessos">
        <button class="people-tab is-active" type="button" data-people-tab="members">Pessoas</button>
        <button class="people-tab" type="button" data-people-tab="invitations">Convites</button>
      </nav>

      <section class="people-metrics" aria-label="Indicadores de pessoas">
        <article><strong data-people-count="active">—</strong><span>Membros ativos</span></article>
        <article><strong data-people-count="team">—</strong><span>Pessoas da equipe</span></article>
        <article><strong data-people-count="pending">—</strong><span>Convites pendentes</span></article>
        <article><strong data-people-count="suspended">—</strong><span>Acessos suspensos</span></article>
      </section>

      <section data-people-view="members">
        <div class="people-toolbar">
          <div class="field"><label for="people-search">Pesquisar</label><input id="people-search" type="search" placeholder="Nome, e-mail, WhatsApp ou função" data-people-search></div>
          <div class="field"><label for="people-status">Situação</label><select id="people-status" data-people-status><option value="all">Todas</option><option value="active">Ativas</option><option value="invited">Aguardando confirmação</option><option value="suspended">Suspensas</option><option value="removed">Removidas</option></select></div>
        </div>
        <section class="people-panel">
          <div class="people-panel-header"><div><h2>Membros e equipe</h2><p><span data-people-total>0</span> vínculo(s) encontrado(s).</p></div></div>
          <div class="people-list" data-people-list><div class="people-empty"><strong>Carregando pessoas…</strong><p>Aguarde alguns segundos.</p></div></div>
        </section>
      </section>

      <section data-people-view="invitations" hidden>
        <div class="people-toolbar">
          <div class="field"><label for="invite-search">Pesquisar convites</label><input id="invite-search" type="search" placeholder="Nome ou e-mail" data-invite-search></div>
          <div class="field"><label for="invite-status">Situação</label><select id="invite-status" data-invite-status><option value="all">Todas</option><option value="pending">Pendentes</option><option value="accepted">Aceitos</option><option value="expired">Expirados</option><option value="revoked">Revogados</option></select></div>
        </div>
        <section class="people-panel">
          <div class="people-panel-header"><div><h2>Convites</h2><p>O link completo é mostrado somente no momento da criação.</p></div>${canInvite() ? '<button class="button button-small" type="button" data-invite-new>Novo convite</button>' : ''}</div>
          <div class="invitation-list" data-invitation-list></div>
        </section>
      </section>

      <dialog class="people-dialog" data-member-dialog>
        <form method="dialog" data-member-form>
          <div class="people-dialog-header"><div><h2 data-member-dialog-title>Editar acesso</h2><p data-member-dialog-email></p></div><button class="dialog-close" type="button" data-dialog-close aria-label="Fechar">×</button></div>
          <div class="people-dialog-body">
            <input type="hidden" name="member_id">
            <div class="people-dialog-grid">
              <div class="field"><label for="member-first-name">Nome</label><input id="member-first-name" name="first_name" type="text" minlength="2" maxlength="120" required></div>
              <div class="field"><label for="member-last-name">Sobrenome</label><input id="member-last-name" name="last_name" type="text" maxlength="120"></div>
              <div class="field"><label for="member-whatsapp">WhatsApp</label><input id="member-whatsapp" name="whatsapp" type="tel" inputmode="tel" maxlength="30"></div>
              <div class="field"><label for="member-job-title">Função na equipe</label><input id="member-job-title" name="job_title" type="text" maxlength="120" placeholder="Ex.: Coordenação de formação"></div>
              <div class="field is-full"><label for="member-status">Situação do vínculo</label><select id="member-status" name="status"><option value="active">Ativa</option><option value="suspended">Suspensa</option><option value="removed">Removida</option></select></div>
            </div>
            <div><p class="admin-eyebrow">Papéis organizacionais</p><div class="role-selector" data-role-selector></div></div>
            <div class="permission-preview"><strong>Permissões resultantes</strong><div class="permission-preview-list" data-permission-preview></div></div>
            <p class="people-feedback" data-member-feedback role="status" aria-live="polite"></p>
            <div class="people-dialog-actions"><button class="button" type="submit" data-member-save>Salvar acesso</button><button class="button button-secondary" type="button" data-dialog-close>Cancelar</button></div>
          </div>
        </form>
      </dialog>

      <dialog class="invite-dialog" data-invite-dialog>
        <form method="dialog" data-invite-form>
          <div class="people-dialog-header"><div><h2>Convidar pessoa</h2><p>O convite vincula a conta confirmada ao papel escolhido.</p></div><button class="dialog-close" type="button" data-dialog-close aria-label="Fechar">×</button></div>
          <div class="people-dialog-body">
            <div class="people-dialog-grid">
              <div class="field"><label for="invite-name">Nome</label><input id="invite-name" name="name" type="text" minlength="2" maxlength="180" required></div>
              <div class="field"><label for="invite-email">E-mail</label><input id="invite-email" name="email" type="email" maxlength="254" required></div>
              <div class="field"><label for="invite-whatsapp">WhatsApp</label><input id="invite-whatsapp" name="whatsapp" type="tel" inputmode="tel" maxlength="30"></div>
              <div class="field"><label for="invite-role">Papel inicial</label><select id="invite-role" name="role_code" data-invite-role></select></div>
              <div class="field"><label for="invite-job-title">Função na equipe</label><input id="invite-job-title" name="job_title" type="text" maxlength="120"></div>
              <div class="field"><label for="invite-expiry">Validade em dias</label><input id="invite-expiry" name="expires_days" type="number" min="1" max="30" step="1" value="7"></div>
              <div class="field is-full"><label for="invite-message">Mensagem opcional</label><textarea id="invite-message" name="message" maxlength="1000" placeholder="Uma mensagem de acolhimento ou orientação para o primeiro acesso."></textarea></div>
            </div>
            <p class="people-feedback" data-invite-feedback role="status" aria-live="polite"></p>
            <div class="invite-result" data-invite-result>
              <strong>Convite criado com sucesso</strong>
              <div class="invite-link-row"><input type="text" readonly data-invite-link><button class="button button-secondary" type="button" data-copy-invite>Copiar link</button></div>
              <div class="people-dialog-actions"><a class="button" href="#" target="_blank" rel="noopener" data-whatsapp-invite>Enviar pelo WhatsApp</a><button class="button button-secondary" type="button" data-dialog-close>Concluir</button></div>
              <p class="invite-warning">Por segurança, o token não fica armazenado em texto aberto. Copie ou envie este link agora.</p>
            </div>
            <div class="people-dialog-actions" data-invite-actions><button class="button" type="submit" data-invite-save>Criar convite</button><button class="button button-secondary" type="button" data-dialog-close>Cancelar</button></div>
          </div>
        </form>
      </dialog>
    </div>`;
  }

  function roleCodes(member) {
    return member.roles.filter((role) => !role.revoked_at).map((role) => role.code);
  }

  function renderMetrics() {
    const active = state.members.filter((member) => member.status === 'active' && !member.deleted_at).length;
    const team = state.members.filter((member) => roleCodes(member).some((code) => code !== 'membro') && member.status === 'active').length;
    const pending = state.invitations.filter((invitation) => displayInvitationStatus(invitation) === 'pending').length;
    const suspended = state.members.filter((member) => member.status === 'suspended').length;
    const values = { active, team, pending, suspended };
    Object.entries(values).forEach(([key, value]) => {
      const element = state.container.querySelector(`[data-people-count="${key}"]`);
      if (element) element.textContent = String(value);
    });
  }

  function filteredMembers() {
    const search = state.container.querySelector('[data-people-search]')?.value.trim().toLowerCase() || '';
    const status = state.container.querySelector('[data-people-status]')?.value || 'all';
    return state.members.filter((member) => {
      const text = [fullName(member.profile), member.profile.email, member.profile.whatsapp, member.job_title, ...roleCodes(member)].filter(Boolean).join(' ').toLowerCase();
      return (status === 'all' || member.status === status) && (!search || text.includes(search));
    });
  }

  function renderMembers() {
    const list = state.container.querySelector('[data-people-list]');
    const members = filteredMembers();
    state.container.querySelector('[data-people-total]').textContent = String(members.length);

    if (!members.length) {
      list.innerHTML = '<div class="people-empty"><strong>Nenhuma pessoa encontrada</strong><p>Altere os filtros ou envie um novo convite.</p></div>';
      return;
    }

    list.innerHTML = members.map((member) => {
      const roles = roleCodes(member);
      return `<article class="person-card">
        <div class="person-main"><span class="person-avatar">${escapeHtml(initials(member.profile))}</span><div class="person-copy"><strong>${escapeHtml(fullName(member.profile))}</strong><span>${escapeHtml(member.profile.email || '')}</span><span>${escapeHtml(member.job_title || member.profile.whatsapp || 'Sem função informada')}</span></div></div>
        <div><div class="person-meta"><span class="member-status is-${member.status}">${MEMBER_STATUS[member.status] || member.status}</span>${roles.map((code) => `<span class="role-pill">${escapeHtml(state.roles.find((role) => role.code === code)?.name || code)}</span>`).join('')}</div></div>
        <div class="person-actions">${canManageUsers() && canManageRoles() ? `<button class="button button-secondary" type="button" data-member-edit="${member.id}">Gerenciar</button>` : ''}</div>
      </article>`;
    }).join('');

    list.querySelectorAll('[data-member-edit]').forEach((button) => button.addEventListener('click', () => openMember(button.dataset.memberEdit)));
  }

  function filteredInvitations() {
    const search = state.container.querySelector('[data-invite-search]')?.value.trim().toLowerCase() || '';
    const status = state.container.querySelector('[data-invite-status]')?.value || 'all';
    return state.invitations.filter((invitation) => {
      const actualStatus = displayInvitationStatus(invitation);
      const text = [invitation.name, invitation.email, invitation.role_code, invitation.job_title].filter(Boolean).join(' ').toLowerCase();
      return (status === 'all' || actualStatus === status) && (!search || text.includes(search));
    });
  }

  function renderInvitations() {
    const list = state.container.querySelector('[data-invitation-list]');
    const invitations = filteredInvitations();
    if (!invitations.length) {
      list.innerHTML = '<div class="people-empty"><strong>Nenhum convite encontrado</strong><p>Os convites enviados aparecerão aqui.</p></div>';
      return;
    }

    list.innerHTML = invitations.map((invitation) => {
      const status = displayInvitationStatus(invitation);
      const role = state.roles.find((item) => item.code === invitation.role_code);
      return `<article class="invitation-card">
        <div class="invitation-copy"><strong>${escapeHtml(invitation.name)}</strong><span>${escapeHtml(invitation.email)}</span><span>${escapeHtml(invitation.job_title || role?.name || invitation.role_code)}</span></div>
        <div class="invitation-meta"><span class="invitation-status is-${status}">${INVITATION_STATUS[status] || status}</span><span class="role-pill">Expira em ${formatDate(invitation.expires_at)}</span></div>
        <div class="invitation-actions">${canInvite() && status === 'pending' ? `<button class="button button-secondary" type="button" data-invite-revoke="${invitation.id}">Revogar</button>` : ''}</div>
      </article>`;
    }).join('');

    list.querySelectorAll('[data-invite-revoke]').forEach((button) => button.addEventListener('click', () => revokeInvitation(button.dataset.inviteRevoke)));
  }

  function renderRoles(member = null) {
    const selector = state.container.querySelector('[data-role-selector]');
    const assigned = new Set(member ? roleCodes(member) : ['membro']);
    selector.innerHTML = state.roles.map((role) => {
      const fixed = role.code === 'membro';
      return `<label class="role-option"><input type="checkbox" name="role_codes" value="${escapeHtml(role.code)}"${assigned.has(role.code) || fixed ? ' checked' : ''}${fixed ? ' disabled' : ''}><span><strong>${escapeHtml(role.name)}</strong><small>${escapeHtml(role.description || 'Papel organizacional.')}</small></span></label>`;
    }).join('');
    selector.querySelectorAll('input').forEach((input) => input.addEventListener('change', renderPermissionPreview));
    renderPermissionPreview();
  }

  function renderPermissionPreview() {
    const selected = [...state.container.querySelectorAll('[data-role-selector] input:checked')].map((input) => input.value);
    if (!selected.includes('membro')) selected.push('membro');
    const permissions = [...new Set(state.roles
      .filter((role) => selected.includes(role.code))
      .flatMap((role) => role.permissions.map((permission) => permission.code)))].sort();
    const container = state.container.querySelector('[data-permission-preview]');
    container.innerHTML = permissions.length
      ? permissions.map((code) => `<span>${escapeHtml(code)}</span>`).join('')
      : '<span>Acesso básico de membro</span>';
  }

  function openMember(memberId) {
    const member = state.members.find((item) => item.id === memberId);
    if (!member) return;
    state.selectedMember = member;
    const dialog = state.container.querySelector('[data-member-dialog]');
    const form = state.container.querySelector('[data-member-form]');
    form.reset();
    form.elements.member_id.value = member.id;
    form.elements.first_name.value = member.profile.first_name || '';
    form.elements.last_name.value = member.profile.last_name || '';
    form.elements.whatsapp.value = member.profile.whatsapp || '';
    form.elements.job_title.value = member.job_title || '';
    form.elements.status.value = member.status === 'invited' ? 'active' : member.status;
    const isSelf = member.profile_id === session.user.id;
    form.elements.status.disabled = isSelf;
    state.container.querySelector('[data-member-dialog-title]').textContent = fullName(member.profile);
    state.container.querySelector('[data-member-dialog-email]').textContent = member.profile.email || '';
    state.container.querySelector('[data-member-feedback]').className = 'people-feedback';
    renderRoles(member);
    dialog.showModal();
    form.elements.first_name.focus();
  }

  async function saveMember(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    const member = state.selectedMember;
    if (!member) return;
    const roleCodesSelected = [...form.querySelectorAll('input[name="role_codes"]:checked')].map((input) => input.value);
    if (!roleCodesSelected.includes('membro')) roleCodesSelected.push('membro');
    const firstName = String(data.get('first_name') || '').trim();
    if (firstName.length < 2) {
      showDialogFeedback('[data-member-feedback]', 'Informe um nome com pelo menos 2 caracteres.');
      return;
    }
    const button = form.querySelector('[data-member-save]');
    button.disabled = true;
    button.textContent = 'Salvando…';
    try {
      const { error } = await supabase.rpc('admin_update_member', {
        p_member_id: member.id,
        p_first_name: firstName,
        p_last_name: String(data.get('last_name') || '').trim() || null,
        p_whatsapp: String(data.get('whatsapp') || '').trim() || null,
        p_job_title: String(data.get('job_title') || '').trim() || null,
        p_status: form.elements.status.disabled ? 'active' : String(data.get('status') || 'active'),
        p_role_codes: roleCodesSelected
      });
      if (error) throw error;
      state.container.querySelector('[data-member-dialog]').close();
      await loadAll();
      await onChanged?.();
    } catch (error) {
      console.error(error);
      showDialogFeedback('[data-member-feedback]', error.message || 'Não foi possível atualizar o acesso.');
    } finally {
      button.disabled = false;
      button.textContent = 'Salvar acesso';
    }
  }

  function showDialogFeedback(selector, message, type = 'error') {
    const element = state.container.querySelector(selector);
    element.textContent = message;
    element.className = `people-feedback is-visible is-${type}`;
  }

  function openInvite() {
    const dialog = state.container.querySelector('[data-invite-dialog]');
    const form = state.container.querySelector('[data-invite-form]');
    form.reset();
    form.elements.expires_days.value = '7';
    state.container.querySelector('[data-invite-feedback]').className = 'people-feedback';
    state.container.querySelector('[data-invite-result]').className = 'invite-result';
    state.container.querySelector('[data-invite-actions]').hidden = false;
    dialog.showModal();
    form.elements.name.focus();
  }

  async function createInvitation(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const data = new FormData(form);
    const button = form.querySelector('[data-invite-save]');
    button.disabled = true;
    button.textContent = 'Criando…';
    try {
      const { data: result, error } = await supabase.rpc('admin_create_invitation', {
        p_name: String(data.get('name') || '').trim(),
        p_email: String(data.get('email') || '').trim().toLowerCase(),
        p_whatsapp: String(data.get('whatsapp') || '').trim() || null,
        p_role_code: String(data.get('role_code') || 'membro'),
        p_job_title: String(data.get('job_title') || '').trim() || null,
        p_message: String(data.get('message') || '').trim() || null,
        p_expires_days: Number(data.get('expires_days') || 7)
      });
      if (error) throw error;
      const link = `${window.location.origin}/aceite-convite?token=${encodeURIComponent(result.token)}`;
      const linkInput = state.container.querySelector('[data-invite-link]');
      linkInput.value = link;
      const phone = normalizePhone(data.get('whatsapp'));
      const text = `Olá, ${String(data.get('name') || '').trim()}! Você recebeu um convite para o Lar com Propósito. Acesse: ${link}`;
      const whatsapp = state.container.querySelector('[data-whatsapp-invite]');
      whatsapp.href = phone ? `https://wa.me/${phone}?text=${encodeURIComponent(text)}` : `https://wa.me/?text=${encodeURIComponent(text)}`;
      state.container.querySelector('[data-invite-result]').className = 'invite-result is-visible';
      state.container.querySelector('[data-invite-actions]').hidden = true;
      await loadInvitations();
      renderMetrics();
      renderInvitations();
    } catch (error) {
      console.error(error);
      showDialogFeedback('[data-invite-feedback]', error.message || 'Não foi possível criar o convite.');
    } finally {
      button.disabled = false;
      button.textContent = 'Criar convite';
    }
  }

  async function copyInvitation() {
    const input = state.container.querySelector('[data-invite-link]');
    try {
      await navigator.clipboard.writeText(input.value);
      state.container.querySelector('[data-copy-invite]').textContent = 'Link copiado';
    } catch {
      input.select();
      document.execCommand('copy');
    }
  }

  async function revokeInvitation(id) {
    const invitation = state.invitations.find((item) => item.id === id);
    if (!invitation || !window.confirm(`Revogar o convite enviado para ${invitation.email}?`)) return;
    const { error } = await supabase.rpc('admin_revoke_invitation', { p_invitation_id: id });
    if (error) {
      window.alert(error.message || 'Não foi possível revogar o convite.');
      return;
    }
    await loadInvitations();
    renderMetrics();
    renderInvitations();
  }

  async function loadRoles() {
    const { data, error } = await supabase
      .from('roles')
      .select('id,code,name,description,is_system,role_permissions(permission:permissions(code,name,module,description))')
      .order('name');
    if (error) throw error;
    state.roles = (data || []).map((role) => ({
      ...role,
      permissions: (role.role_permissions || []).map((item) => item.permission).filter(Boolean)
    }));
    const inviteRole = state.container.querySelector('[data-invite-role]');
    inviteRole.innerHTML = state.roles.map((role) => `<option value="${escapeHtml(role.code)}">${escapeHtml(role.name)}</option>`).join('');
    inviteRole.value = 'membro';
  }

  async function loadMembers() {
    const { data: memberships, error: membershipError } = await supabase
      .from('organization_members')
      .select('id,organization_id,profile_id,job_title,status,joined_at,created_at,updated_at,deleted_at')
      .eq('organization_id', organizationId)
      .order('created_at', { ascending: false });
    if (membershipError) throw membershipError;

    const profileIds = (memberships || []).map((member) => member.profile_id);
    const memberIds = (memberships || []).map((member) => member.id);
    const [profileResponse, roleResponse] = await Promise.all([
      profileIds.length
        ? supabase.from('profiles').select('id,first_name,last_name,email,whatsapp,status,last_access_at,created_at').in('id', profileIds)
        : Promise.resolve({ data: [], error: null }),
      memberIds.length
        ? supabase.from('member_roles').select('id,organization_member_id,role_id,revoked_at').in('organization_member_id', memberIds)
        : Promise.resolve({ data: [], error: null })
    ]);
    if (profileResponse.error) throw profileResponse.error;
    if (roleResponse.error) throw roleResponse.error;

    state.members = (memberships || []).map((member) => ({
      ...member,
      profile: (profileResponse.data || []).find((profile) => profile.id === member.profile_id) || {},
      roles: (roleResponse.data || [])
        .filter((link) => link.organization_member_id === member.id)
        .map((link) => {
          const role = state.roles.find((item) => item.id === link.role_id) || {};
          return { ...role, revoked_at: link.revoked_at };
        })
    }));
  }

  async function loadInvitations() {
    if (!canInvite() && !canRead()) {
      state.invitations = [];
      return;
    }
    const { data, error } = await supabase
      .from('invitations')
      .select('id,organization_id,name,email,whatsapp,role_code,job_title,message,status,expires_at,accepted_at,created_at,updated_at')
      .eq('organization_id', organizationId)
      .order('created_at', { ascending: false });
    if (error) throw error;
    state.invitations = data || [];
  }

  async function loadAll() {
    await loadRoles();
    await Promise.all([loadMembers(), loadInvitations()]);
    renderMetrics();
    renderMembers();
    renderInvitations();
  }

  function switchTab(tab) {
    state.activeTab = tab === 'invitations' ? 'invitations' : 'members';
    state.container.querySelectorAll('[data-people-tab]').forEach((button) => button.classList.toggle('is-active', button.dataset.peopleTab === state.activeTab));
    state.container.querySelectorAll('[data-people-view]').forEach((view) => { view.hidden = view.dataset.peopleView !== state.activeTab; });
  }

  function bind() {
    state.container.querySelectorAll('[data-people-tab]').forEach((button) => button.addEventListener('click', () => switchTab(button.dataset.peopleTab)));
    state.container.querySelector('[data-people-search]').addEventListener('input', renderMembers);
    state.container.querySelector('[data-people-status]').addEventListener('change', renderMembers);
    state.container.querySelector('[data-invite-search]').addEventListener('input', renderInvitations);
    state.container.querySelector('[data-invite-status]').addEventListener('change', renderInvitations);
    state.container.querySelectorAll('[data-invite-new]').forEach((button) => button.addEventListener('click', openInvite));
    state.container.querySelectorAll('[data-dialog-close]').forEach((button) => button.addEventListener('click', () => button.closest('dialog')?.close()));
    state.container.querySelector('[data-member-form]').addEventListener('submit', saveMember);
    state.container.querySelector('[data-invite-form]').addEventListener('submit', createInvitation);
    state.container.querySelector('[data-copy-invite]').addEventListener('click', copyInvitation);
  }

  async function mount(container) {
    state.container = container;
    if (!state.mounted) {
      container.innerHTML = shell();
      bind();
      state.mounted = true;
    }
    try {
      await loadAll();
    } catch (error) {
      console.error(error);
      container.querySelector('[data-people-list]').innerHTML = '<div class="people-empty"><strong>Módulo aguardando ativação</strong><p>Execute as migrations 020 e 021 no Supabase e recarregue esta página.</p></div>';
      container.querySelector('[data-invitation-list]').innerHTML = '<div class="people-empty"><strong>Convites indisponíveis</strong><p>Não foi possível consultar os registros neste momento.</p></div>';
    }
  }

  return { mount, reload: () => loadAll() };
}
