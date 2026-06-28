import { getSupabaseClient } from './supabase.js';
import { createContentAdmin } from './admin-content.js';

const supabase = getSupabaseClient();
let contentModule = null;

function escapeHtml(value = '') {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

async function mountContentModule() {
  if (window.location.hash !== '#conteudo') return;
  const container = document.querySelector('[data-admin-section="conteudo"]');
  if (!container) return;

  try {
    const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
    if (sessionError || !sessionData.session) return;

    const { data: context, error: contextError } = await supabase.rpc('get_my_app_context');
    if (contextError || !context) return;

    const permissions = new Set(Array.isArray(context.permissions) ? context.permissions : []);
    const canAny = (codes) => Boolean(context.profile?.is_superadmin) || codes.some((code) => permissions.has(code));
    if (!canAny(['content.read','content.manage','media.read','media.manage'])) return;

    if (!contentModule) {
      contentModule = createContentAdmin({
        supabase,
        context,
        session: sessionData.session,
        canAny,
        escapeHtml,
        onChanged: async () => {}
      });
    }

    await contentModule.mount(container);
  } catch (error) {
    console.error('Falha ao iniciar conteúdo:', error);
  }
}

window.addEventListener('hashchange', () => window.setTimeout(mountContentModule, 50));
window.addEventListener('load', () => window.setTimeout(mountContentModule, 250), { once: true });
