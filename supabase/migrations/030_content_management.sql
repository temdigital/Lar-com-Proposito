begin;

alter table public.content_posts
  add column if not exists is_featured boolean not null default false,
  add column if not exists seo_title text,
  add column if not exists seo_description text,
  add column if not exists published_by uuid references auth.users(id) on delete set null;

create index if not exists content_posts_featured_idx
  on public.content_posts(organization_id, is_featured, published_at desc)
  where deleted_at is null and status = 'published';

create or replace function public.admin_save_content_category(
  p_category_id uuid,
  p_name text,
  p_slug text,
  p_description text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_organization_id uuid;
  v_category_id uuid;
  v_slug text := lower(trim(p_slug));
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select om.organization_id
    into v_organization_id
  from public.organization_members om
  where om.profile_id = auth.uid()
    and om.status = 'active'
    and om.deleted_at is null
  limit 1;

  if v_organization_id is null or not public.has_permission(v_organization_id, 'content.manage') then
    raise exception 'Você não possui permissão para gerenciar conteúdo.';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'Informe o nome da categoria.';
  end if;

  if v_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Endereço amigável inválido.';
  end if;

  if p_category_id is null then
    insert into public.content_categories (
      organization_id,
      name,
      slug,
      description
    ) values (
      v_organization_id,
      trim(p_name),
      v_slug,
      nullif(trim(coalesce(p_description, '')), '')
    )
    returning id into v_category_id;
  else
    update public.content_categories
    set name = trim(p_name),
        slug = v_slug,
        description = nullif(trim(coalesce(p_description, '')), '')
    where id = p_category_id
      and organization_id = v_organization_id
    returning id into v_category_id;

    if v_category_id is null then
      raise exception 'Categoria não encontrada.';
    end if;
  end if;

  insert into public.audit_logs (
    organization_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    new_data
  ) values (
    v_organization_id,
    auth.uid(),
    case when p_category_id is null then 'content_category_created' else 'content_category_updated' end,
    'content_category',
    v_category_id::text,
    jsonb_build_object('name', trim(p_name), 'slug', v_slug)
  );

  return jsonb_build_object('category_id', v_category_id, 'name', trim(p_name), 'slug', v_slug);
end;
$$;

create or replace function public.admin_delete_content_category(p_category_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_organization_id uuid;
  v_name text;
begin
  select cc.organization_id, cc.name
    into v_organization_id, v_name
  from public.content_categories cc
  where cc.id = p_category_id
  for update;

  if v_organization_id is null then
    raise exception 'Categoria não encontrada.';
  end if;

  if not public.has_permission(v_organization_id, 'content.manage') then
    raise exception 'Você não possui permissão para excluir categorias.';
  end if;

  update public.content_posts
  set category_id = null
  where category_id = p_category_id;

  delete from public.content_categories where id = p_category_id;

  insert into public.audit_logs (
    organization_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    old_data
  ) values (
    v_organization_id,
    auth.uid(),
    'content_category_deleted',
    'content_category',
    p_category_id::text,
    jsonb_build_object('name', v_name)
  );
end;
$$;

create or replace function public.admin_save_content_post(
  p_post_id uuid,
  p_category_id uuid,
  p_title text,
  p_slug text,
  p_excerpt text,
  p_body_html text,
  p_cover_path text,
  p_status text,
  p_is_members_only boolean,
  p_is_featured boolean,
  p_seo_title text,
  p_seo_description text,
  p_published_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_organization_id uuid;
  v_post_id uuid;
  v_slug text := lower(trim(p_slug));
  v_status text := lower(trim(p_status));
  v_published_at timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select om.organization_id
    into v_organization_id
  from public.organization_members om
  where om.profile_id = auth.uid()
    and om.status = 'active'
    and om.deleted_at is null
  limit 1;

  if v_organization_id is null or not public.has_permission(v_organization_id, 'content.manage') then
    raise exception 'Você não possui permissão para gerenciar conteúdo.';
  end if;

  if nullif(trim(p_title), '') is null then
    raise exception 'Informe o título da publicação.';
  end if;

  if length(trim(coalesce(p_body_html, ''))) < 10 then
    raise exception 'O conteúdo precisa ter pelo menos 10 caracteres.';
  end if;

  if v_slug !~ '^[a-z0-9]+(?:-[a-z0-9]+)*$' then
    raise exception 'Endereço amigável inválido.';
  end if;

  if v_status not in ('draft', 'review', 'published', 'archived') then
    raise exception 'Situação da publicação inválida.';
  end if;

  if p_category_id is not null and not exists (
    select 1
    from public.content_categories cc
    where cc.id = p_category_id
      and cc.organization_id = v_organization_id
  ) then
    raise exception 'Categoria inválida para esta organização.';
  end if;

  v_published_at := case
    when v_status = 'published' then coalesce(p_published_at, now())
    else null
  end;

  if p_post_id is null then
    insert into public.content_posts (
      organization_id,
      category_id,
      author_id,
      title,
      slug,
      excerpt,
      body_html,
      cover_path,
      status,
      is_members_only,
      is_featured,
      seo_title,
      seo_description,
      published_at,
      published_by
    ) values (
      v_organization_id,
      p_category_id,
      auth.uid(),
      trim(p_title),
      v_slug,
      nullif(trim(coalesce(p_excerpt, '')), ''),
      trim(p_body_html),
      nullif(trim(coalesce(p_cover_path, '')), ''),
      v_status,
      coalesce(p_is_members_only, false),
      coalesce(p_is_featured, false),
      nullif(trim(coalesce(p_seo_title, '')), ''),
      nullif(trim(coalesce(p_seo_description, '')), ''),
      v_published_at,
      case when v_status = 'published' then auth.uid() else null end
    )
    returning id into v_post_id;
  else
    update public.content_posts
    set category_id = p_category_id,
        title = trim(p_title),
        slug = v_slug,
        excerpt = nullif(trim(coalesce(p_excerpt, '')), ''),
        body_html = trim(p_body_html),
        cover_path = nullif(trim(coalesce(p_cover_path, '')), ''),
        status = v_status,
        is_members_only = coalesce(p_is_members_only, false),
        is_featured = coalesce(p_is_featured, false),
        seo_title = nullif(trim(coalesce(p_seo_title, '')), ''),
        seo_description = nullif(trim(coalesce(p_seo_description, '')), ''),
        published_at = v_published_at,
        published_by = case
          when v_status = 'published' then coalesce(published_by, auth.uid())
          else null
        end,
        deleted_at = null,
        updated_at = now()
    where id = p_post_id
      and organization_id = v_organization_id
    returning id into v_post_id;

    if v_post_id is null then
      raise exception 'Publicação não encontrada.';
    end if;
  end if;

  insert into public.audit_logs (
    organization_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    new_data
  ) values (
    v_organization_id,
    auth.uid(),
    case when p_post_id is null then 'content_post_created' else 'content_post_updated' end,
    'content_post',
    v_post_id::text,
    jsonb_build_object(
      'title', trim(p_title),
      'slug', v_slug,
      'status', v_status,
      'members_only', coalesce(p_is_members_only, false),
      'featured', coalesce(p_is_featured, false)
    )
  );

  return jsonb_build_object(
    'post_id', v_post_id,
    'title', trim(p_title),
    'slug', v_slug,
    'status', v_status,
    'published_at', v_published_at
  );
end;
$$;

create or replace function public.admin_archive_content_post(p_post_id uuid)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_organization_id uuid;
  v_title text;
begin
  select cp.organization_id, cp.title
    into v_organization_id, v_title
  from public.content_posts cp
  where cp.id = p_post_id
  for update;

  if v_organization_id is null then
    raise exception 'Publicação não encontrada.';
  end if;

  if not public.has_permission(v_organization_id, 'content.manage') then
    raise exception 'Você não possui permissão para arquivar conteúdo.';
  end if;

  update public.content_posts
  set status = 'archived',
      published_at = null,
      published_by = null,
      updated_at = now()
  where id = p_post_id;

  insert into public.audit_logs (
    organization_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    new_data
  ) values (
    v_organization_id,
    auth.uid(),
    'content_post_archived',
    'content_post',
    p_post_id::text,
    jsonb_build_object('title', v_title)
  );
end;
$$;

revoke all on function public.admin_save_content_category(uuid, text, text, text) from public;
revoke all on function public.admin_save_content_category(uuid, text, text, text) from anon;
revoke all on function public.admin_save_content_category(uuid, text, text, text) from authenticated;
grant execute on function public.admin_save_content_category(uuid, text, text, text) to authenticated;

revoke all on function public.admin_delete_content_category(uuid) from public;
revoke all on function public.admin_delete_content_category(uuid) from anon;
revoke all on function public.admin_delete_content_category(uuid) from authenticated;
grant execute on function public.admin_delete_content_category(uuid) to authenticated;

revoke all on function public.admin_save_content_post(uuid, uuid, text, text, text, text, text, text, boolean, boolean, text, text, timestamptz) from public;
revoke all on function public.admin_save_content_post(uuid, uuid, text, text, text, text, text, text, boolean, boolean, text, text, timestamptz) from anon;
revoke all on function public.admin_save_content_post(uuid, uuid, text, text, text, text, text, text, boolean, boolean, text, text, timestamptz) from authenticated;
grant execute on function public.admin_save_content_post(uuid, uuid, text, text, text, text, text, text, boolean, boolean, text, text, timestamptz) to authenticated;

revoke all on function public.admin_archive_content_post(uuid) from public;
revoke all on function public.admin_archive_content_post(uuid) from anon;
revoke all on function public.admin_archive_content_post(uuid) from authenticated;
grant execute on function public.admin_archive_content_post(uuid) to authenticated;

commit;
