import { getSupabaseClient } from './supabase.js';

const form = document.querySelector('[data-contact-form]');
const statusElement = document.querySelector('[data-contact-status]');
const submitButton = form?.querySelector('button[type="submit"]');

function showStatus(message, type = 'info') {
  if (!statusElement) return;
  statusElement.textContent = message;
  statusElement.className = `form-status is-visible is-${type}`;
}

function setSubmitting(isSubmitting) {
  if (!submitButton) return;
  submitButton.disabled = isSubmitting;
  submitButton.textContent = isSubmitting ? 'Enviando…' : submitButton.dataset.defaultLabel;
}

function validate(data) {
  const name = String(data.get('name') || '').trim();
  const email = String(data.get('email') || '').trim();
  const subject = String(data.get('subject') || '').trim();
  const message = String(data.get('message') || '').trim();

  if (name.length < 2) throw new Error('Informe seu nome.');
  if (!email.includes('@')) throw new Error('Informe um e-mail válido.');
  if (subject.length < 4) throw new Error('Informe um assunto com pelo menos 4 caracteres.');
  if (message.length < 20) throw new Error('Escreva uma mensagem com pelo menos 20 caracteres.');
  if (message.length > 3000) throw new Error('A mensagem deve ter no máximo 3000 caracteres.');
}

form?.addEventListener('submit', async (event) => {
  event.preventDefault();
  const data = new FormData(form);

  if (String(data.get('website') || '').trim()) {
    form.reset();
    showStatus('Mensagem recebida. Obrigada pelo contato.', 'success');
    return;
  }

  const lastSubmission = Number(localStorage.getItem('lar-com-proposito:last-contact') || 0);
  if (Date.now() - lastSubmission < 60000) {
    showStatus('Aguarde um minuto antes de enviar outra mensagem.', 'error');
    return;
  }

  setSubmitting(true);
  showStatus('Enviando sua mensagem…');

  try {
    validate(data);
    const supabase = getSupabaseClient();
    const { data: sessionData } = await supabase.auth.getSession();
    const { error } = await supabase.from('contact_messages').insert({
      profile_id: sessionData.session?.user?.id || null,
      name: String(data.get('name')).trim(),
      email: String(data.get('email')).trim().toLowerCase(),
      topic: String(data.get('topic')),
      subject: String(data.get('subject')).trim(),
      message: String(data.get('message')).trim(),
      source_page: window.location.pathname,
      user_agent: navigator.userAgent.slice(0, 500)
    });

    if (error) throw error;

    localStorage.setItem('lar-com-proposito:last-contact', String(Date.now()));
    form.reset();
    showStatus('Mensagem enviada com sucesso. Ela será analisada pelo canal de atendimento.', 'success');
  } catch (error) {
    const message = error?.message === 'SUPABASE_NOT_CONFIGURED'
      ? 'O canal de contato ainda está sendo conectado. Tente novamente mais tarde.'
      : error?.message || 'Não foi possível enviar a mensagem. Tente novamente.';
    showStatus(message, 'error');
  } finally {
    setSubmitting(false);
  }
});
