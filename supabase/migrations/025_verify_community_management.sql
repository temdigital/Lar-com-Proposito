select
  to_regprocedure('public.admin_moderate_community(text,uuid,text,text,uuid,timestamptz)') is not null as moderation_function_exists,
  to_regprocedure('public.community_toggle_reaction(text,uuid,text)') is not null as reaction_function_exists,
  has_function_privilege('authenticated', 'public.admin_moderate_community(text,uuid,text,text,uuid,timestamptz)', 'EXECUTE') as authenticated_can_moderate,
  has_function_privilege('authenticated', 'public.community_toggle_reaction(text,uuid,text)', 'EXECUTE') as authenticated_can_react,
  not has_function_privilege('anon', 'public.admin_moderate_community(text,uuid,text,text,uuid,timestamptz)', 'EXECUTE') as anonymous_cannot_moderate,
  not has_function_privilege('anon', 'public.community_toggle_reaction(text,uuid,text)', 'EXECUTE') as anonymous_cannot_react;
