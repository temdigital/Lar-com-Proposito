select
  to_regprocedure('public.get_my_app_context()') is not null as context_function_exists,
  has_function_privilege('authenticated', 'public.get_my_app_context()', 'EXECUTE') as authenticated_can_execute,
  has_function_privilege('anon', 'public.get_my_app_context()', 'EXECUTE') as anonymous_can_execute,
  not has_function_privilege('anon', 'public.get_my_app_context()', 'EXECUTE') as anonymous_cannot_execute;
