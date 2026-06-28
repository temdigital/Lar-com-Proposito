import { getSupabaseClient } from './supabase.js';

const form = document.querySelector('[data-auth-form]');
const message = document.querySelector('[data-form-message]');
const callbackStatus = document.querySelector('[data-callback-status]');
const callbackLogin = document.querySelector('[data-callback-login]');

function insertOfficialAddressNote() {
  const card = document.querySelector('.auth-card');
  if (!card || card.querySelector('.auth-security-note')) return;

  const note = document.createElement('aside');
  note.className = 'auth-security-note';
  note.innerHTML = '<strong>Endereço oficial nesta fase</strong><span>lar-com-proposito.vercel.app</span><a href="/seguranca.html">Como reconhecer um acesso seguro</a>';
  card.insertBefore(note, card.firstChild);
}

function showMessage(text, type = 'info') {
  if (!message) return;
  message.textContent = text;
  message.className = `form-message is-visible is-${type}`;
}

function setSubmitting(isSubmitting) {
  const button = form?.querySelector('button[type="submit"]');
  if (!button) return;
  button.disabled = isSubmitting;
  button.textContent = isSubmitting ? 'Aguarde…' : button.dataset.defaultLabel;
}

function friendlyAuthError(error) {
  if (error?.message === 'SUPABASE_NOT_CONFIGURED') {
    return 'A integração do Supabase ainda aguarda a chave pública do projeto. Nenhum dado foi enviado.';
  }

  const messageText = String(error?.message || '').toLowerCase();
  if (messageText.includes('invalid login credentials')) return 'E-mail ou senha incorretos.';
  if (messageText.includes('email not confirmed')) return 'Confirme seu e-mail antes de entrar.';
  if (messageText.includes('user already registered')) return 'Já existe uma conta com este e-mail.';
  if (messageText.includes('rate limit')) return 'Muitas tentativas em pouco tempo. Aguarde alguns minutos.';
  if (messageText.includes('same password')) return 'A nova senha deve ser diferente da senha atual.';
  return error?.message || 'Não foi possível concluir. Revise os dados e tente novamente.';
}

async function handleLogin(data) {
  const supabase = getSupabaseClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: String(data.get('email')).trim(),
    password: String(data.get('password'))
  });
  if (error) throw error;
  await supabase.rpc('register_last_access');
  window.location.replace('/app/');
}

async function handleSignup(data) {
  const password = String(data.get('password'));
  const passwordConfirmation = String(data.get('password_confirmation'));

  if (password.length < 8) throw new Error('A senha deve ter pelo menos 8 caracteres.');
  if (password !== passwordConfirmation) throw new Error('As senhas não coincidem.');
  if (!data.get('terms')) throw new Error('É necessário aceitar os Termos de Uso e a Política de Privacidade.');

  const supabase = getSupabaseClient();
  const { data: signupData, error } = await supabase.auth.signUp({
    email: String(data.get('email')).trim(),
    password,
    options: {
      emailRedirectTo: `${window.location.origin}/auth/callback.html`,
      data: {
        nome: String(data.get('name')).trim(),
        whatsapp: String(data.get('whatsapp')).trim()
      }
    }
  });
  if (error) throw error;

  form.reset();
  if (signupData.session) {
    showMessage('Conta criada e sessão iniciada. Redirecionando…', 'success');
    window.location.replace('/app/');
    return;
  }

  showMessage('Conta criada. Confirme o endereço enviado ao seu e-mail antes de entrar.', 'success');
}

async function handleRecovery(data) {
  const supabase = getSupabaseClient();
  const { error } = await supabase.auth.resetPasswordForEmail(
    String(data.get('email')).trim(),
    { redirectTo: `${window.location.origin}/redefinir-senha.html` }
  );
  if (error) throw error;
  form.reset();
  showMessage('Se o e-mail estiver cadastrado, enviaremos as instruções para redefinir a senha.', 'success');
}

async function handlePasswordReset(data) {
  const password = String(data.get('password'));
  const passwordConfirmation = String(data.get('password_confirmation'));

  if (password.length < 8) throw new Error('A senha deve ter pelo menos 8 caracteres.');
  if (password !== passwordConfirmation) throw new Error('As senhas não coincidem.');

  const supabase = getSupabaseClient();
  const { data: sessionData } = await supabase.auth.getSession();
  if (!sessionData.session) throw new Error('O link de redefinição expirou ou não é válido. Solicite um novo link.');

  const { error } = await supabase.auth.updateUser({ password });
  if (error) throw error;
  form.reset();
  showMessage('Senha atualizada com sucesso. Redirecionando para sua área…', 'success');
  window.location.replace('/app/');
}

async function initializeAuthPage() {
  try {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase.auth.getSession();
    if (error) throw error;

    if (callbackStatus) {
      if (!data.session) {
        callbackStatus.textContent = 'O link expirou ou já foi utilizado. Solicite um novo acesso.';
        if (callbackLogin) callbackLogin.hidden = false;
        return;
      }

      await supabase.rpc('register_last_access');
      callbackStatus.textContent = 'E-mail confirmado. Redirecionando para sua área…';
      window.location.replace('/app/');
      return;
    }

    if (data.session && form?.dataset.authForm === 'login') {
      window.location.replace('/app/');
    }

    if (!data.session && form?.dataset.authForm === 'reset') {
      showMessage('O link de redefinição expirou ou não é válido. Solicite um novo link.', 'error');
      const button = form.querySelector('button[type="submit"]');
      if (button) button.disabled = true;
    }
  } catch (error) {
    if (callbackStatus) {
      callbackStatus.textContent = error?.message === 'SUPABASE_NOT_CONFIGURED'
        ? 'A integração do Supabase ainda não foi configurada no site.'
        : 'Não foi possível validar o link. Volte ao login e tente novamente.';
      if (callbackLogin) callbackLogin.hidden = false;
      return;
    }

    if (error?.message !== 'SUPABASE_NOT_CONFIGURED') console.error(error);
  }
}

form?.addEventListener('submit', async (event) => {
  event.preventDefault();
  setSubmitting(true);
  showMessage('Processando sua solicitação…');

  try {
    const data = new FormData(form);
    const action = form.dataset.authForm;
    if (action === 'login') await handleLogin(data);
    if (action === 'signup') await handleSignup(data);
    if (action === 'recover') await handleRecovery(data);
    if (action === 'reset') await handlePasswordReset(data);
  } catch (error) {
    showMessage(friendlyAuthError(error), 'error');
  } finally {
    setSubmitting(false);
  }
});

insertOfficialAddressNote();
initializeAuthPage();
