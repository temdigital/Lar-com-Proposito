import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
import { APP_CONFIG, hasSupabaseConfiguration } from './config.js';

let client = null;

export function getSupabaseClient() {
  if (!hasSupabaseConfiguration()) {
    throw new Error('SUPABASE_NOT_CONFIGURED');
  }

  if (!client) {
    client = createClient(APP_CONFIG.supabaseUrl, APP_CONFIG.supabaseAnonKey, {
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
