begin;

create or replace function public.admin_moderate_community(
  p_target_type text,
  p_target_id uuid,
  p_action_type text,
  p_reason text,
  p_report_id uuid default null,
  p_expires_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_organization_id uuid;
  v_profile_id uuid;
  v_report_status text;
  v_target_type text := lower(trim(p_target_type));
  v_action_type text := lower(trim(p_action_type));
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  if v_target_type not in ('post', 'comment', 'profile') then
    raise exception 'Tipo de alvo inválido.';
  end if;

  if v_action_type not in ('warn', 'hide', 'remove', 'restore', 'mute', 'suspend', 'ban', 'dismiss') then
    raise exception 'Ação de moderação inválida.';
  end if;

  if nullif(trim(p_reason), '') is null then
    raise exception 'Informe o motivo da ação.';
  end if;

  if p_report_id is not null then
    select cr.organization_id, cr.status
      into v_organization_id, v_report_status
    from public.community_reports cr
    where cr.id = p_report_id
    for update;

    if v_organization_id is null then
      raise exception 'Denúncia não encontrada.';
    end if;
  elsif v_target_type = 'post' then
    select cp.organization_id
      into v_organization_id
    from public.community_posts cp
    where cp.id = p_target_id;
  elsif v_target_type = 'comment' then
    select cp.organization_id
      into v_organization_id
    from public.community_comments cc
    join public.community_posts cp on cp.id = cc.post_id
    where cc.id = p_target_id;
  else
    select om.organization_id
      into v_organization_id
    from public.organization_members om
    where om.profile_id = p_target_id
      and om.deleted_at is null
    limit 1;
  end if;

  if v_organization_id is null then
    raise exception 'Não foi possível determinar a organização do alvo.';
  end if;

  if not public.has_permission(v_organization_id, 'community.moderate') then
    raise exception 'Você não possui permissão para moderar a comunidade.';
  end if;

  if v_target_type = 'post' then
    if v_action_type = 'hide' then
      update public.community_posts
      set status = 'hidden', updated_at = now()
      where id = p_target_id and organization_id = v_organization_id;
    elsif v_action_type = 'remove' then
      update public.community_posts
      set status = 'removed', deleted_at = coalesce(deleted_at, now()), updated_at = now()
      where id = p_target_id and organization_id = v_organization_id;
    elsif v_action_type = 'restore' then
      update public.community_posts
      set status = 'published', deleted_at = null, updated_at = now()
      where id = p_target_id and organization_id = v_organization_id;
    elsif v_action_type not in ('warn', 'dismiss') then
      raise exception 'Ação incompatível com publicação.';
    end if;
  elsif v_target_type = 'comment' then
    if v_action_type = 'hide' then
      update public.community_comments cc
      set status = 'hidden', updated_at = now()
      from public.community_posts cp
      where cc.id = p_target_id
        and cp.id = cc.post_id
        and cp.organization_id = v_organization_id;
    elsif v_action_type = 'remove' then
      update public.community_comments cc
      set status = 'removed', deleted_at = coalesce(cc.deleted_at, now()), updated_at = now()
      from public.community_posts cp
      where cc.id = p_target_id
        and cp.id = cc.post_id
        and cp.organization_id = v_organization_id;
    elsif v_action_type = 'restore' then
      update public.community_comments cc
      set status = 'published', deleted_at = null, updated_at = now()
      from public.community_posts cp
      where cc.id = p_target_id
        and cp.id = cc.post_id
        and cp.organization_id = v_organization_id;
    elsif v_action_type not in ('warn', 'dismiss') then
      raise exception 'Ação incompatível com comentário.';
    end if;
  else
    v_profile_id := p_target_id;

    if v_profile_id = auth.uid() and v_action_type in ('mute', 'suspend', 'ban') then
      raise exception 'Você não pode aplicar suspensão ao próprio perfil.';
    end if;

    if v_action_type in ('mute', 'suspend', 'ban') then
      insert into public.community_suspensions (
        organization_id,
        profile_id,
        reason,
        starts_at,
        ends_at,
        created_by
      ) values (
        v_organization_id,
        v_profile_id,
        trim(p_reason),
        now(),
        case
          when v_action_type = 'ban' then null
          when p_expires_at is not null and p_expires_at > now() then p_expires_at
          when v_action_type = 'mute' then now() + interval '24 hours'
          else now() + interval '7 days'
        end,
        auth.uid()
      );
    elsif v_action_type = 'restore' then
      update public.community_suspensions
      set revoked_at = now()
      where organization_id = v_organization_id
        and profile_id = v_profile_id
        and revoked_at is null
        and (ends_at is null or ends_at > now());
    elsif v_action_type not in ('warn', 'dismiss') then
      raise exception 'Ação incompatível com perfil.';
    end if;
  end if;

  insert into public.moderation_actions (
    organization_id,
    moderator_id,
    report_id,
    target_type,
    target_id,
    action_type,
    reason,
    expires_at
  ) values (
    v_organization_id,
    auth.uid(),
    p_report_id,
    v_target_type,
    p_target_id,
    v_action_type,
    trim(p_reason),
    p_expires_at
  );

  if p_report_id is not null then
    update public.community_reports
    set status = case when v_action_type = 'dismiss' then 'dismissed' else 'resolved' end,
        assigned_to = auth.uid(),
        resolution = trim(p_reason),
        resolved_at = now()
    where id = p_report_id;
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
    'community_moderation_action',
    v_target_type,
    p_target_id::text,
    jsonb_build_object(
      'action_type', v_action_type,
      'reason', trim(p_reason),
      'report_id', p_report_id,
      'expires_at', p_expires_at
    )
  );

  return jsonb_build_object(
    'success', true,
    'target_type', v_target_type,
    'target_id', p_target_id,
    'action_type', v_action_type,
    'report_id', p_report_id
  );
end;
$$;

create or replace function public.community_toggle_reaction(
  p_target_type text,
  p_target_id uuid,
  p_reaction_type text default 'like'
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_target_type text := lower(trim(p_target_type));
  v_reaction_type text := lower(trim(p_reaction_type));
  v_existing_id uuid;
  v_space_id uuid;
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'Entre na sua conta para reagir.';
  end if;

  if v_target_type not in ('post', 'comment') then
    raise exception 'Tipo de alvo inválido.';
  end if;

  if v_reaction_type not in ('like', 'love', 'support', 'gratitude') then
    raise exception 'Reação inválida.';
  end if;

  if v_target_type = 'post' then
    select cp.space_id into v_space_id
    from public.community_posts cp
    where cp.id = p_target_id and cp.status = 'published' and cp.deleted_at is null;
  else
    select cp.space_id into v_space_id
    from public.community_comments cc
    join public.community_posts cp on cp.id = cc.post_id
    where cc.id = p_target_id
      and cc.status = 'published'
      and cc.deleted_at is null
      and cp.status = 'published'
      and cp.deleted_at is null;
  end if;

  if v_space_id is null or not public.can_access_community_space(v_space_id) then
    raise exception 'Conteúdo indisponível para sua conta.';
  end if;

  select cr.id into v_existing_id
  from public.community_reactions cr
  where cr.profile_id = auth.uid()
    and cr.target_type = v_target_type
    and cr.target_id = p_target_id
    and cr.reaction_type = v_reaction_type;

  if v_existing_id is null then
    insert into public.community_reactions (profile_id, target_type, target_id, reaction_type)
    values (auth.uid(), v_target_type, p_target_id, v_reaction_type);
  else
    delete from public.community_reactions where id = v_existing_id;
  end if;

  select count(*) into v_count
  from public.community_reactions cr
  where cr.target_type = v_target_type
    and cr.target_id = p_target_id
    and cr.reaction_type = v_reaction_type;

  return jsonb_build_object(
    'active', v_existing_id is null,
    'count', v_count,
    'reaction_type', v_reaction_type
  );
end;
$$;

revoke all on function public.admin_moderate_community(text, uuid, text, text, uuid, timestamptz) from public;
revoke all on function public.admin_moderate_community(text, uuid, text, text, uuid, timestamptz) from anon;
revoke all on function public.admin_moderate_community(text, uuid, text, text, uuid, timestamptz) from authenticated;
grant execute on function public.admin_moderate_community(text, uuid, text, text, uuid, timestamptz) to authenticated;

revoke all on function public.community_toggle_reaction(text, uuid, text) from public;
revoke all on function public.community_toggle_reaction(text, uuid, text) from anon;
revoke all on function public.community_toggle_reaction(text, uuid, text) from authenticated;
grant execute on function public.community_toggle_reaction(text, uuid, text) to authenticated;

commit;
