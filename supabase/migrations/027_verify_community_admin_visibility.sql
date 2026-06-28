select
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'community_spaces' and policyname = 'community_spaces_read') = 1 as community_spaces_read_policy_ok,
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'community_posts' and policyname = 'community_posts_read') = 1 as community_posts_read_policy_ok,
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'community_comments' and policyname = 'community_comments_read') = 1 as community_comments_read_policy_ok;
