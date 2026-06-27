export default function handler(request, response) {
  response.setHeader('Cache-Control', 'no-store, max-age=0');
  response.setHeader('Content-Type', 'application/json; charset=utf-8');
  response.status(200).json({
    supabaseUrl: process.env.SUPABASE_URL || 'https://kglmxbbqnsspthkfyanm.supabase.co',
    supabaseAnonKey: process.env.SUPABASE_PUBLISHABLE_KEY || ''
  });
}
