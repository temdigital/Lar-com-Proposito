select
  to_regprocedure('public.is_community_suspended(uuid,uuid)') is not null as suspension_function_exists,
  to_regprocedure('public.get_community_space_feed(uuid,integer,integer)') is not null as feed_function_exists,
  has_function_privilege('authenticated', 'public.is_community_suspended(uuid,uuid)', 'EXECUTE') as authenticated_can_check_suspension,
  has_function_privilege('authenticated', 'public.get_community_space_feed(uuid,integer,integer)', 'EXECUTE') as authenticated_can_load_feed,
  not has_function_privilege('anon', 'public.is_community_suspended(uuid,uuid)', 'EXECUTE') as anonymous_cannot_check_suspension,
  not has_function_privilege('anon', 'public.get_community_space_feed(uuid,integer,integer)', 'EXECUTE') as anonymous_cannot_load_feed,
  (select count(*) from pg_policies where schemaname='public' and tablename='community_posts' and policyname='community_posts_insert') = 1 as post_insert_policy_ok,
  (select count(*) from pg_policies where schemaname='public' and tablename='community_comments' and policyname='community_comments_insert') = 1 as comment_insert_policy_ok;
