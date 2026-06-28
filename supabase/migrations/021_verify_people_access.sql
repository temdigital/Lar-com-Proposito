select
  to_regprocedure('public.admin_update_member(uuid,text,text,text,text,text,text[])') is not null as update_member_function,
  to_regprocedure('public.admin_create_invitation(text,text,text,text,text,text,integer)') is not null as create_invitation_function,
  to_regprocedure('public.admin_revoke_invitation(uuid)') is not null as revoke_invitation_function,
  to_regprocedure('public.get_invitation_preview(text)') is not null as invitation_preview_function,
  to_regprocedure('public.accept_invitation(text)') is not null as accept_invitation_function,
  has_function_privilege('authenticated', 'public.admin_update_member(uuid,text,text,text,text,text,text[])', 'EXECUTE') as authenticated_can_update_member,
  has_function_privilege('authenticated', 'public.admin_create_invitation(text,text,text,text,text,text,integer)', 'EXECUTE') as authenticated_can_create_invitation,
  not has_function_privilege('anon', 'public.admin_update_member(uuid,text,text,text,text,text,text[])', 'EXECUTE') as anonymous_cannot_update_member,
  not has_function_privilege('anon', 'public.admin_create_invitation(text,text,text,text,text,text,integer)', 'EXECUTE') as anonymous_cannot_create_invitation,
  has_function_privilege('anon', 'public.get_invitation_preview(text)', 'EXECUTE') as anonymous_can_preview_invitation,
  has_function_privilege('authenticated', 'public.accept_invitation(text)', 'EXECUTE') as authenticated_can_accept_invitation;
