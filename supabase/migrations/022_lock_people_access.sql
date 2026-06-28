begin;

-- Endurecimento explícito das funções administrativas do módulo Pessoas e acessos.
-- O PostgreSQL concede EXECUTE a PUBLIC por padrão em novas funções. Esta migration
-- remove tanto a concessão pública quanto qualquer concessão direta ao papel anon.

revoke all on function public.admin_update_member(uuid, text, text, text, text, text, text[]) from public;
revoke all on function public.admin_update_member(uuid, text, text, text, text, text, text[]) from anon;
revoke all on function public.admin_update_member(uuid, text, text, text, text, text, text[]) from authenticated;
grant execute on function public.admin_update_member(uuid, text, text, text, text, text, text[]) to authenticated;

revoke all on function public.admin_create_invitation(text, text, text, text, text, text, integer) from public;
revoke all on function public.admin_create_invitation(text, text, text, text, text, text, integer) from anon;
revoke all on function public.admin_create_invitation(text, text, text, text, text, text, integer) from authenticated;
grant execute on function public.admin_create_invitation(text, text, text, text, text, text, integer) to authenticated;

revoke all on function public.admin_revoke_invitation(uuid) from public;
revoke all on function public.admin_revoke_invitation(uuid) from anon;
revoke all on function public.admin_revoke_invitation(uuid) from authenticated;
grant execute on function public.admin_revoke_invitation(uuid) to authenticated;

-- A prévia do convite precisa permanecer acessível sem sessão para validar o link.
revoke all on function public.get_invitation_preview(text) from public;
revoke all on function public.get_invitation_preview(text) from anon;
revoke all on function public.get_invitation_preview(text) from authenticated;
grant execute on function public.get_invitation_preview(text) to anon, authenticated;

revoke all on function public.accept_invitation(text) from public;
revoke all on function public.accept_invitation(text) from anon;
revoke all on function public.accept_invitation(text) from authenticated;
grant execute on function public.accept_invitation(text) to authenticated;

commit;
