import { getSupabaseClient } from './supabase.js';
import { createEventsAdmin } from './admin-events.js';
const supabase=getSupabaseClient();let mod=null;
function esc(v=''){return String(v).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&#039;')}
async function mount(){if(location.hash!=='#eventos')return;const c=document.querySelector('[data-admin-section="eventos"]');if(!c)return;try{const{data:s,error:se}=await supabase.auth.getSession();if(se||!s.session)return;const{data:ctx,error:ce}=await supabase.rpc('get_my_app_context');if(ce||!ctx)return;const perms=new Set(Array.isArray(ctx.permissions)?ctx.permissions:[]);const canAny=(codes)=>Boolean(ctx.profile?.is_superadmin)||codes.some(x=>perms.has(x));if(!canAny(['events.read','events.manage']))return;if(!mod)mod=createEventsAdmin({supabase,context:ctx,session:s.session,canAny,escapeHtml:esc,onChanged:async()=>{}});await mod.mount(c)}catch(e){console.error('Falha ao iniciar eventos:',e)}}
addEventListener('hashchange',()=>setTimeout(mount,50));addEventListener('load',()=>setTimeout(mount,250),{once:true});
