begin;

create or replace function public.is_community_suspended(
  p_organization_id uuid,
  p_space_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.community_suspensions cs
    where cs.organization_id = p_organization_id
      and cs.profile_id = auth.uid()
      and cs.revoked_at is null
      and cs.starts_at <= now()
      and (cs.ends_at is null or cs.ends_at > now())
      and (cs.space_id is null or p_space_id is null or cs.space_id = p_space_id)
  );
$$;

create or replace function public.get_community_space_feed(
  p_space_id uuid,
  p_limit integer default 30,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_space public.community_spaces%rowtype;
  v_limit integer := greatest(1, least(coalesce(p_limit, 30), 50));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_posts jsonb;
begin
  select * into v_space
  from public.community_spaces
  where id = p_space_id;

  if v_space.id is null or not public.can_access_community_space(v_space.id) then
    raise exception 'Espaço indisponível para sua conta.';
  end if;

  select coalesce(jsonb_agg(post_item order by pinned desc, created_at desc), '[]'::jsonb)
    into v_posts
  from (
    select
      p.is_pinned as pinned,
      p.created_at,
      jsonb_build_object(
        'id', p.id,
        'space_id', p.space_id,
        'title', p.title,
        'body', p.body,
        'is_pinned', p.is_pinned,
        'published_at', p.published_at,
        'edited_at', p.edited_at,
        'created_at', p.created_at,
        'author', jsonb_build_object(
          'id', author.id,
          'first_name', author.first_name,
          'last_name', author.last_name,
          'photo_url', author.photo_url
        ),
        'reactions', coalesce((
          select jsonb_object_agg(reaction_type, reaction_count)
          from (
            select cr.reaction_type, count(*)::integer as reaction_count
            from public.community_reactions cr
            where cr.target_type = 'post' and cr.target_id = p.id
            group by cr.reaction_type
          ) reaction_counts
        ), '{}'::jsonb),
        'my_reactions', coalesce((
          select jsonb_agg(cr.reaction_type)
          from public.community_reactions cr
          where cr.target_type = 'post'
            and cr.target_id = p.id
            and cr.profile_id = auth.uid()
        ), '[]'::jsonb),
        'comments', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', c.id,
              'post_id', c.post_id,
              'parent_comment_id', c.parent_comment_id,
              'body', c.body,
              'created_at', c.created_at,
              'author', jsonb_build_object(
                'id', comment_author.id,
                'first_name', comment_author.first_name,
                'last_name', comment_author.last_name,
                'photo_url', comment_author.photo_url
              )
            ) order by c.created_at
          )
          from public.community_comments c
          join public.profiles comment_author on comment_author.id = c.author_id
          where c.post_id = p.id
            and c.status = 'published'
            and c.deleted_at is null
        ), '[]'::jsonb)
      ) as post_item
    from public.community_posts p
    join public.profiles author on author.id = p.author_id
    where p.space_id = v_space.id
      and p.status = 'published'
      and p.deleted_at is null
    order by p.is_pinned desc, p.created_at desc
    limit v_limit offset v_offset
  ) feed_rows;

  return jsonb_build_object(
    'space', jsonb_build_object(
      'id', v_space.id,
      'name', v_space.name,
      'slug', v_space.slug,
      'description', v_space.description,
      'access_type', v_space.access_type
    ),
    'suspended', public.is_community_suspended(v_space.organization_id, v_space.id),
    'posts', v_posts
  );
end;
$$;

-- Bloqueia novas publicações e comentários durante suspensão ativa.
drop policy if exists community_posts_insert on public.community_posts;
create policy community_posts_insert on public.community_posts
for insert to authenticated
with check (
  author_id = auth.uid()
  and public.can_access_community_space(space_id)
  and not public.is_community_suspended(organization_id, space_id)
);

drop policy if exists community_comments_insert on public.community_comments;
create policy community_comments_insert on public.community_comments
for insert to authenticated
with check (
  author_id = auth.uid()
  and exists (
    select 1
    from public.community_posts p
    where p.id = post_id
      and public.can_access_community_space(p.space_id)
      and not public.is_community_suspended(p.organization_id, p.space_id)
  )
);

revoke all on function public.is_community_suspended(uuid, uuid) from public;
revoke all on function public.is_community_suspended(uuid, uuid) from anon;
revoke all on function public.is_community_suspended(uuid, uuid) from authenticated;
grant execute on function public.is_community_suspended(uuid, uuid) to authenticated;

revoke all on function public.get_community_space_feed(uuid, integer, integer) from public;
revoke all on function public.get_community_space_feed(uuid, integer, integer) from anon;
revoke all on function public.get_community_space_feed(uuid, integer, integer) from authenticated;
grant execute on function public.get_community_space_feed(uuid, integer, integer) to authenticated;

commit;
