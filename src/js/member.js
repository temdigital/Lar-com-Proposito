import { getSupabaseClient } from './supabase.js';

const status = document.querySelector('[data-member-status]');
const logoutButton = document.querySelector('[data-logout]');

function setStatus(text) {
  if (status) status.textContent = text;
}

async function init() {
  try {
    const supabase = getSupabaseClient();
    const { data, error } = await supabase.auth.getSession();
    if (error) throw error;

    if (!data.session) {
      window.location.replace('/login.html');
      return;
    }

    const name = data.session.user.user_metadata?.nome;
    setStatus(name ? `Olá, ${name}. Sua sessão está ativa. Os módulos da plataforma serão liberados por etapas.` : 'Sua sessão está ativa. Os módulos da plataforma serão liberados por etapas.');
    if (logoutButton) logoutButton.hidden = false;
  } catch (error) {
    if (error?.message === 'SUPABASE_NOT_CONFIGURED') {
      setStatus('A integração do Supabase ainda aguarda a chave pública do projeto. Nenhuma sessão foi iniciada.');
      return;
    }
    setStatus('Não foi possível validar sua sessão. Volte à página de login e tente novamente.');
  }
}

logoutButton?.addEventListener('click', async () => {
  try {
    const supabase = getSupabaseClient();
    await supabase.auth.signOut();
  } finally {
    window.location.replace('/');
  }
});

init();
