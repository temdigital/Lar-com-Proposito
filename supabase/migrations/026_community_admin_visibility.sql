begin;

-- Administradoras e moderadoras precisam visualizar também registros não publicados
-- para configurar espaços e tratar denúncias. Visitantes continuam vendo apenas o
-- conteúdo permitido por can_access_community_space e pelo status publicado.

drop policy if exists community_spaces_read on public.community_spaces;
create policy community_spaces_read on public.community_spaces
for select to anon, authenticated
using (
  public.can_access_community_space(id)
  or public.has_permission(organization_id, 'community.manage')
  or public.has_permission(organization_id, 'community.moderate')
);

drop policy if exists community_posts_read on public.community_posts;
create policy community_posts_read on public.community_posts
for select to anon, authenticated
using (
  (
    deleted_at is null
    and status = 'published'
    and public.can_access_community_space(space_id)
  )
  or public.has_permission(organization_id, 'community.manage')
  or public.has_permission(organization_id, 'community.moderate')
);

drop policy if exists community_comments_read on public.community_comments;
create policy community_comments_read on public.community_comments
for select to anon, authenticated
using (
  (
    status = 'published'
    and deleted_at is null
    and exists (
      select 1
      from public.community_posts p
      where p.id = post_id
        and public.can_access_community_space(p.space_id)
    )
  )
  or exists (
    select 1
    from public.community_posts p
    where p.id = post_id
      and (
        public.has_permission(p.organization_id, 'community.manage')
        or public.has_permission(p.organization_id, 'community.moderate')
      )
  )
);

commit;
