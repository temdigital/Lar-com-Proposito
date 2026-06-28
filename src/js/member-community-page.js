import { getSupabaseClient } from './supabase.js';
import { createMemberCommunity } from './member-community.js';

const supabase = getSupabaseClient();

function escapeHtml(value = '') {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

async function waitForMemberArea() {
  for (let attempt = 0; attempt < 80; attempt += 1) {
    const content = document.querySelector('[data-app-content]');
    const container = document.querySelector('[data-community-list]');
    if (content && !content.hidden && container) return container;
    await new Promise((resolve) => window.setTimeout(resolve, 100));
  }
  return null;
}

async function initializeCommunity() {
  try {
    const container = await waitForMemberArea();
    if (!container) return;

    const { data: sessionData, error: sessionError } = await supabase.auth.getSession();
    if (sessionError || !sessionData.session) return;

    const { data: context, error: contextError } = await supabase.rpc('get_my_app_context');
    if (contextError || !context) return;

    const { data: spaces, error: spacesError } = await supabase
      .from('community_spaces')
      .select('id,organization_id,name,slug,description,access_type,course_id,plan_id,status,created_at')
      .eq('status', 'active')
      .order('created_at', { ascending: false });
    if (spacesError) throw spacesError;

    const community = createMemberCommunity({
      supabase,
      context,
      session: sessionData.session,
      escapeHtml
    });
    community.mount(container, spaces || []);
  } catch (error) {
    console.warn('Comunidade ainda indisponível:', error);
  }
}

window.addEventListener('load', initializeCommunity, { once: true });
