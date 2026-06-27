import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
import { APP_CONFIG, hasSupabaseConfiguration } from './config.js';

let client = null;
let runtimeConfig = APP_CONFIG;

try {
  if (APP_CONFIG.runtimeConfigUrl) {
    const response = await fetch(APP_CONFIG.runtimeConfigUrl, {
      headers: { Accept: 'application/json' },
      cache: 'no-store',
      credentials: 'same-origin'
    });

    if (response.ok) {
      const remoteConfig = await response.json();
      runtimeConfig = Object.freeze({ ...APP_CONFIG, ...remoteConfig });
    }
  }
} catch (error) {
  console.warn('Não foi possível carregar a configuração pública em runtime.', error);
}

export function getSupabaseClient() {
  if (!hasSupabaseConfiguration(runtimeConfig)) {
    throw new Error('SUPABASE_NOT_CONFIGURED');
  }

  if (!client) {
    client = createClient(runtimeConfig.supabaseUrl, runtimeConfig.supabaseAnonKey, {
      auth: {
        flowType: 'pkce',
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true
      }
    });
  }

  return client;
}
