import { getSupabaseClient } from './supabase.js';

const form = document.querySelector('[data-auth-form]');
const message = document.querySelector('[data-form-message]');

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

async function handleLogin(data) {
  const supabase = getSupabaseClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: String(data.get('email')).trim(),
    password: String(data.get('password'))
  });
  if (error) throw error;
  window.location.href = '/app/';
}

async function handleSignup(data) {
  const password = String(data.get('password'));
  const passwordConfirmation = String(data.get('password_confirmation'));

  if (password.length < 8) throw new Error('A senha deve ter pelo menos 8 caracteres.');
  if (password !== passwordConfirmation) throw new Error('As senhas não coincidem.');
  if (!data.get('terms')) throw new Error('É necessário aceitar os Termos de Uso e a Política de Privacidade.');

  const supabase = getSupabaseClient();
  const { error } = await supabase.auth.signUp({
    email: String(data.get('email')).trim(),
    password,
    options: {
      emailRedirectTo: `${window.location.origin}/login.html`,
      data: {
        nome: String(data.get('name')).trim(),
        whatsapp: String(data.get('whatsapp')).trim()
      }
    }
  });
  if (error) throw error;
  form.reset();
  showMessage('Conta criada. Confirme o endereço enviado ao seu e-mail antes de entrar.', 'success');
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
  } catch (error) {
    const text = error?.message === 'SUPABASE_NOT_CONFIGURED'
      ? 'A integração do Supabase ainda aguarda a chave pública do projeto. Nenhum dado foi enviado.'
      : error?.message || 'Não foi possível concluir. Revise os dados e tente novamente.';
    showMessage(text, 'error');
  } finally {
    setSubmitting(false);
  }
});
