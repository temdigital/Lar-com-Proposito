select
  to_regprocedure('public.admin_save_content_category(uuid,text,text,text)') is not null as save_category_function_exists,
  to_regprocedure('public.admin_delete_content_category(uuid)') is not null as delete_category_function_exists,
  to_regprocedure('public.admin_save_content_post(uuid,uuid,text,text,text,text,text,text,boolean,boolean,text,text,timestamptz)') is not null as save_post_function_exists,
  to_regprocedure('public.admin_archive_content_post(uuid)') is not null as archive_post_function_exists,
  has_function_privilege('authenticated', 'public.admin_save_content_category(uuid,text,text,text)', 'EXECUTE') as authenticated_can_save_category,
  has_function_privilege('authenticated', 'public.admin_delete_content_category(uuid)', 'EXECUTE') as authenticated_can_delete_category,
  has_function_privilege('authenticated', 'public.admin_save_content_post(uuid,uuid,text,text,text,text,text,text,boolean,boolean,text,text,timestamptz)', 'EXECUTE') as authenticated_can_save_post,
  has_function_privilege('authenticated', 'public.admin_archive_content_post(uuid)', 'EXECUTE') as authenticated_can_archive_post,
  not has_function_privilege('anon', 'public.admin_save_content_category(uuid,text,text,text)', 'EXECUTE') as anonymous_cannot_save_category,
  not has_function_privilege('anon', 'public.admin_delete_content_category(uuid)', 'EXECUTE') as anonymous_cannot_delete_category,
  not has_function_privilege('anon', 'public.admin_save_content_post(uuid,uuid,text,text,text,text,text,text,boolean,boolean,text,text,timestamptz)', 'EXECUTE') as anonymous_cannot_save_post,
  not has_function_privilege('anon', 'public.admin_archive_content_post(uuid)', 'EXECUTE') as anonymous_cannot_archive_post,
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='content_posts' and column_name='is_featured'
  ) as featured_column_exists,
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='content_posts' and column_name='seo_title'
  ) as seo_title_column_exists,
  exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='content_posts' and column_name='seo_description'
  ) as seo_description_column_exists;
