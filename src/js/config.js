export const APP_CONFIG = Object.freeze({
  supabaseUrl: 'https://kglmxbbqnsspthkfyanm.supabase.co',
  supabaseAnonKey: '',
  runtimeConfigUrl: '/api/public-config',
  siteUrl: 'https://lar-com-proposito.vercel.app',
  siteName: 'Lar com Propósito',
  emailConfirmationRequired: true
});

export function hasSupabaseConfiguration(config = APP_CONFIG) {
  return Boolean(config.supabaseUrl && config.supabaseAnonKey);
}
