import { getSupabaseClient } from './supabase.js';
import { createSupportAdmin } from './admin-support.js';

const supabase = getSupabaseClient();
let supportModule = null;

function escapeHtml(value = '') {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function markAvailable() {
  const button = document.querySelector('[data-admin-open="atendimento"]');
  if (!button) return false;
  button.textContent = 'Abrir módulo';
  const card = button.closest('.admin-module-card');
  const badge = card ? card.querySelector('.status-pill') : null;
  if (badge) badge.textContent = 'Disponível agora';
  return true;
}

async function mountSupportModule() {
  markAvailable();
  if (window.location.hash !== '#atendimento') return;

  const container = document.querySelector('[data-admin-section="atendimento"]');
  if (!container) return;

  try {
    const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
    if (sessionError || !sessionData.session) return;

    const { data: context, error: contextError } = await supabase.rpc('get_my_app_context');
    if (contextError || !context) return;

    const permissions = new Set(Array.isArray(context.permissions) ? context.permissions : []);
    const canAny = (codes) => Boolean(context.profile?.is_superadmin) || codes.some((code) => permissions.has(code));
    if (!canAny(['support.manage', 'privacy.manage'])) return;

    if (!supportModule) {
      supportModule = createSupportAdmin({
        supabase,
        context,
        session: sessionData.session,
        canAny,
        escapeHtml,
        onChanged: async () => {}
      });
    }

    await supportModule.mount(container);
  } catch (error) {
    console.error('Falha ao iniciar atendimento:', error);
  }
}

window.addEventListener('hashchange', () => window.setTimeout(mountSupportModule, 50));
window.addEventListener('load', () => {
  let attempts = 0;
  const timer = window.setInterval(() => {
    attempts += 1;
    if (markAvailable() || attempts > 20) window.clearInterval(timer);
  }, 150);
  window.setTimeout(mountSupportModule, 300);
}, { once: true });
