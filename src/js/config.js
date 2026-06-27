export const APP_CONFIG = Object.freeze({
  supabaseUrl: 'https://kglmxbbqnsspthkfyanm.supabase.co',
  supabaseAnonKey: '',
  siteName: 'Lar com Propósito',
  emailConfirmationRequired: true
});

export function hasSupabaseConfiguration() {
  return Boolean(APP_CONFIG.supabaseUrl && APP_CONFIG.supabaseAnonKey);
}
