import { getSupabaseClient } from './supabase.js';
import { createClubAdmin } from './admin-club.js';

const supabase = getSupabaseClient();
let clubModule = null;

function escapeHtml(value = '') {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function markAvailable() {
  const cards = [...document.querySelectorAll('.admin-module-card')];
  const card = cards.find((item) => {
    const text = item.querySelector('h3')?.textContent || '';
    return text.includes('Financeiro e assinaturas') || text.includes('Clube e assinaturas');
  });
  if (!card) return false;

  const title = card.querySelector('h3');
  const description = card.querySelector('p');
  const badge = card.querySelector('.status-pill');
  if (title) title.textContent = 'Clube e assinaturas';
  if (description) description.textContent = 'Gerenciar planos, benefícios, associações manuais e acessos de homologação.';
  if (badge && !card.classList.contains('is-disabled')) badge.textContent = 'Disponível agora';

  if (!card.classList.contains('is-disabled') && !card.querySelector('[data-admin-open="financeiro"]')) {
    const button = document.createElement('button');
    button.className = 'button button-secondary';
    button.type = 'button';
    button.dataset.adminOpen = 'financeiro';
    button.textContent = 'Abrir módulo';
    button.addEventListener('click', () => {
      window.location.hash = 'financeiro';
    });
    card.append(button);
  }
  return true;
}

async function mountClubModule() {
  markAvailable();
  if (window.location.hash !== '#financeiro') return;

  const container = document.querySelector('[data-admin-section="financeiro"]');
  if (!container) return;

  try {
    const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
    if (sessionError || !sessionData.session) return;

    const { data: context, error: contextError } = await supabase.rpc('get_my_app_context');
    if (contextError || !context) return;

    const permissions = new Set(Array.isArray(context.permissions) ? context.permissions : []);
    const canAny = (codes) => Boolean(context.profile?.is_superadmin) || codes.some((code) => permissions.has(code));
    if (!canAny(['billing.read', 'billing.manage'])) return;

    if (!clubModule) {
      clubModule = createClubAdmin({
        supabase,
        context,
        canAny,
        escapeHtml,
        onChanged: async () => {}
      });
    }

    await clubModule.mount(container);
  } catch (error) {
    console.error('Falha ao iniciar Clube e assinaturas:', error);
    container.innerHTML = '<div class="admin-empty-module"><p class="admin-eyebrow">Clube e assinaturas</p><h1>Módulo indisponível</h1><p>Confirme a execução das migrations de homologação e tente novamente.</p></div>';
  }
}

window.addEventListener('hashchange', () => window.setTimeout(mountClubModule, 50));
window.addEventListener('load', () => {
  let attempts = 0;
  const timer = window.setInterval(() => {
    attempts += 1;
    if (markAvailable() || attempts > 20) window.clearInterval(timer);
  }, 150);
  window.setTimeout(mountClubModule, 300);
}, { once: true });
