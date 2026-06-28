import { getSupabaseClient } from './supabase.js';

const supabase = getSupabaseClient();
const params = new URLSearchParams(window.location.search);
const token = params.get('token') || '';

const loading = document.querySelector('[data-invite-loading]');
const invalid = document.querySelector('[data-invite-invalid]');
const invalidMessage = document.querySelector('[data-invite-invalid-message]');
const valid = document.querySelector('[data-invite-valid]');
const guest = document.querySelector('[data-invite-guest]');
const account = document.querySelector('[data-invite-account]');
const mismatch = document.querySelector('[data-invite-mismatch]');
const feedback = document.querySelector('[data-invite-feedback]');
const acceptButton = document.querySelector('[data-accept-invite]');
const logoutButtons = document.querySelectorAll('[data-invite-logout]');

let invitation = null;
let session = null;

function showOnly(element) {
  [loading, invalid, valid].forEach((item) => { if (item) item.hidden = item !== element; });
}

function showFeedback(message, type = 'error') {
  feedback.textContent = message;
  feedback.className = `invite-feedback is-visible is-${type}`;
}

function invalidReason(reason) {
  if (reason === 'accepted') return 'Este convite já foi aceito.';
  if (reason === 'revoked') return 'Este convite foi revogado pela equipe.';
  if (reason === 'expired') return 'Este convite expirou. Solicite um novo link à equipe.';
  return 'O link é inválido ou não foi encontrado.';
}

function fillInvitation(data) {
  document.querySelector('[data-invite-name]').textContent = `Olá, ${data.name}`;
  document.querySelector('[data-invite-organization]').textContent = data.organization_name || 'Lar com Propósito';
  document.querySelector('[data-invite-email]').textContent = data.email;
  document.querySelector('[data-invite-role]').textContent = data.role_name || data.role_code;
  document.querySelector('[data-invite-expiry]').textContent = new Intl.DateTimeFormat('pt-BR', { dateStyle: 'long', timeStyle: 'short' }).format(new Date(data.expires_at));

  const jobRow = document.querySelector('[data-invite-job-row]');
  if (data.job_title) {
    jobRow.hidden = false;
    document.querySelector('[data-invite-job]').textContent = data.job_title;
  }

  const messageRow = document.querySelector('[data-invite-message-row]');
  if (data.message) {
    messageRow.hidden = false;
    document.querySelector('[data-invite-message]').textContent = data.message;
  }
}

function configureAccess() {
  guest.hidden = true;
  account.hidden = true;
  mismatch.hidden = true;

  const next = `/aceite-convite?token=${encodeURIComponent(token)}`;
  if (!session) {
    guest.hidden = false;
    document.querySelector('[data-invite-signup]').href = `/cadastro?email=${encodeURIComponent(invitation.email)}&next=${encodeURIComponent(next)}`;
    document.querySelector('[data-invite-login]').href = `/login?email=${encodeURIComponent(invitation.email)}&next=${encodeURIComponent(next)}`;
    return;
  }

  const currentEmail = String(session.user.email || '').toLowerCase();
  document.querySelector('[data-current-email]').textContent = session.user.email || '';
  if (currentEmail !== String(invitation.email || '').toLowerCase()) {
    mismatch.hidden = false;
    return;
  }

  account.hidden = false;
}

async function acceptInvitation() {
  if (!token || !session) return;
  acceptButton.disabled = true;
  acceptButton.textContent = 'Aceitando…';
  showFeedback('Validando seu acesso…', 'success');
  try {
    const { error } = await supabase.rpc('accept_invitation', { p_token: token });
    if (error) throw error;
    showFeedback('Convite aceito. Redirecionando para sua área…', 'success');
    window.setTimeout(() => window.location.replace('/app/'), 800);
  } catch (error) {
    console.error(error);
    showFeedback(error.message || 'Não foi possível aceitar o convite.');
    acceptButton.disabled = false;
    acceptButton.textContent = 'Aceitar convite';
  }
}

async function logout() {
  await supabase.auth.signOut();
  window.location.reload();
}

async function initialize() {
  if (!token) {
    invalidMessage.textContent = 'O endereço não contém um token de convite.';
    showOnly(invalid);
    return;
  }

  try {
    const [{ data: preview, error: previewError }, { data: sessionData, error: sessionError }] = await Promise.all([
      supabase.rpc('get_invitation_preview', { p_token: token }),
      supabase.auth.getSession()
    ]);
    if (previewError) throw previewError;
    if (sessionError) throw sessionError;

    if (!preview?.valid) {
      invalidMessage.textContent = invalidReason(preview?.reason);
      showOnly(invalid);
      return;
    }

    invitation = preview;
    session = sessionData.session;
    fillInvitation(invitation);
    configureAccess();
    showOnly(valid);
  } catch (error) {
    console.error(error);
    invalidMessage.textContent = error?.message?.includes('get_invitation_preview')
      ? 'O módulo de convites ainda aguarda ativação no Supabase.'
      : 'Não foi possível validar o convite agora. Tente novamente em alguns instantes.';
    showOnly(invalid);
  }
}

acceptButton?.addEventListener('click', acceptInvitation);
logoutButtons.forEach((button) => button.addEventListener('click', logout));
initialize();
