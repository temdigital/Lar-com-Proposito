begin;

alter table public.support_tickets
  add column if not exists last_message_at timestamptz not null default now(),
  add column if not exists closed_by uuid references auth.users(id) on delete set null;

alter table public.contact_messages
  add column if not exists admin_note text;

create index if not exists support_tickets_org_last_message_idx
  on public.support_tickets(organization_id, status, last_message_at desc);

-- Mensagens internas nunca podem ser lidas pela titular do chamado.
drop policy if exists support_messages_select on public.support_messages;
create policy support_messages_select
on public.support_messages
for select to authenticated
using (
  exists (
    select 1
    from public.support_tickets t
    where t.id = support_messages.ticket_id
      and (
        public.has_permission(t.organization_id, 'support.manage')
        or (t.profile_id = auth.uid() and not support_messages.is_internal)
      )
  )
);

create or replace function public.create_support_ticket(
  p_subject text,
  p_category text,
  p_priority text,
  p_message text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_organization_id uuid;
  v_ticket_id uuid;
  v_protocol text;
  v_priority text := lower(trim(coalesce(p_priority, 'normal')));
  v_category text := lower(trim(coalesce(p_category, 'other')));
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

  if v_organization_id is null then
    raise exception 'Seu vínculo com a organização não está ativo.';
  end if;

  if char_length(trim(coalesce(p_subject, ''))) not between 4 and 180 then
    raise exception 'Informe um assunto entre 4 e 180 caracteres.';
  end if;

  if char_length(trim(coalesce(p_message, ''))) not between 10 and 4000 then
    raise exception 'A mensagem deve conter entre 10 e 4000 caracteres.';
  end if;

  if v_priority not in ('low','normal','high') then
    raise exception 'Prioridade inválida.';
  end if;

  if v_category not in ('technical','account','courses','community','billing','events','privacy','other') then
    raise exception 'Categoria inválida.';
  end if;

  v_protocol := 'LCP-' || to_char(clock_timestamp(), 'YYYYMMDD') || '-' || upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 8));

  insert into public.support_tickets(
    protocol, organization_id, profile_id, subject, category, priority,
    status, last_message_at
  ) values (
    v_protocol, v_organization_id, auth.uid(), trim(p_subject), v_category,
    v_priority, 'open', now()
  ) returning id into v_ticket_id;

  insert into public.support_messages(ticket_id, author_id, body, is_internal)
  values (v_ticket_id, auth.uid(), trim(p_message), false);

  insert into public.audit_logs(
    organization_id, actor_id, action, entity_type, entity_id, new_data
  ) values (
    v_organization_id, auth.uid(), 'support_ticket_created', 'support_ticket',
    v_ticket_id::text,
    jsonb_build_object('protocol', v_protocol, 'category', v_category, 'priority', v_priority)
  );

  return jsonb_build_object('ticket_id', v_ticket_id, 'protocol', v_protocol, 'status', 'open');
end;
$$;

create or replace function public.add_support_message(
  p_ticket_id uuid,
  p_body text,
  p_is_internal boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_ticket public.support_tickets%rowtype;
  v_is_staff boolean;
  v_internal boolean;
  v_message_id uuid;
  v_next_status text;
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select * into v_ticket
  from public.support_tickets
  where id = p_ticket_id
  for update;

  if v_ticket.id is null then
    raise exception 'Chamado não encontrado.';
  end if;

  v_is_staff := public.has_permission(v_ticket.organization_id, 'support.manage');

  if not v_is_staff and v_ticket.profile_id <> auth.uid() then
    raise exception 'Você não possui acesso a este chamado.';
  end if;

  if not v_is_staff and v_ticket.status = 'closed' then
    raise exception 'Este chamado está encerrado.';
  end if;

  if char_length(trim(coalesce(p_body, ''))) not between 2 and 4000 then
    raise exception 'A mensagem deve conter entre 2 e 4000 caracteres.';
  end if;

  v_internal := v_is_staff and coalesce(p_is_internal, false);

  insert into public.support_messages(ticket_id, author_id, body, is_internal)
  values (p_ticket_id, auth.uid(), trim(p_body), v_internal)
  returning id into v_message_id;

  v_next_status := case
    when v_internal then v_ticket.status
    when v_is_staff then 'waiting_user'
    else 'in_progress'
  end;

  update public.support_tickets
  set status = v_next_status,
      last_message_at = now(),
      resolved_at = case when v_next_status in ('resolved','closed') then resolved_at else null end,
      closed_by = case when v_next_status = 'closed' then closed_by else null end
  where id = p_ticket_id;

  if v_is_staff and not v_internal and v_ticket.profile_id <> auth.uid() then
    insert into public.notifications(
      organization_id, profile_id, channel, type, title, body, action_url, status
    ) values (
      v_ticket.organization_id,
      v_ticket.profile_id,
      'internal',
      'support_reply',
      'Nova resposta no atendimento',
      'Seu chamado ' || v_ticket.protocol || ' recebeu uma nova resposta.',
      '/app/atendimento.html?ticket=' || p_ticket_id::text,
      'pending'
    );
  end if;

  insert into public.audit_logs(
    organization_id, actor_id, action, entity_type, entity_id, new_data
  ) values (
    v_ticket.organization_id, auth.uid(), 'support_message_added', 'support_ticket',
    p_ticket_id::text,
    jsonb_build_object('message_id', v_message_id, 'internal', v_internal, 'status', v_next_status)
  );

  return jsonb_build_object('message_id', v_message_id, 'status', v_next_status, 'internal', v_internal);
end;
$$;

create or replace function public.manage_support_ticket(
  p_ticket_id uuid,
  p_status text,
  p_priority text,
  p_assigned_to uuid,
  p_internal_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_ticket public.support_tickets%rowtype;
  v_status text := lower(trim(p_status));
  v_priority text := lower(trim(p_priority));
begin
  select * into v_ticket
  from public.support_tickets
  where id = p_ticket_id
  for update;

  if v_ticket.id is null then
    raise exception 'Chamado não encontrado.';
  end if;

  if not public.has_permission(v_ticket.organization_id, 'support.manage') then
    raise exception 'Você não possui permissão para gerenciar atendimentos.';
  end if;

  if v_status not in ('open','in_progress','waiting_user','resolved','closed') then
    raise exception 'Situação inválida.';
  end if;

  if v_priority not in ('low','normal','high','urgent') then
    raise exception 'Prioridade inválida.';
  end if;

  update public.support_tickets
  set status = v_status,
      priority = v_priority,
      assigned_to = p_assigned_to,
      resolved_at = case when v_status in ('resolved','closed') then coalesce(resolved_at, now()) else null end,
      closed_by = case when v_status = 'closed' then auth.uid() else null end
  where id = p_ticket_id;

  if nullif(trim(coalesce(p_internal_note, '')), '') is not null then
    insert into public.support_messages(ticket_id, author_id, body, is_internal)
    values (p_ticket_id, auth.uid(), trim(p_internal_note), true);

    update public.support_tickets
    set last_message_at = now()
    where id = p_ticket_id;
  end if;

  insert into public.audit_logs(
    organization_id, actor_id, action, entity_type, entity_id, old_data, new_data
  ) values (
    v_ticket.organization_id, auth.uid(), 'support_ticket_updated', 'support_ticket', p_ticket_id::text,
    jsonb_build_object('status', v_ticket.status, 'priority', v_ticket.priority, 'assigned_to', v_ticket.assigned_to),
    jsonb_build_object('status', v_status, 'priority', v_priority, 'assigned_to', p_assigned_to)
  );

  return jsonb_build_object('ticket_id', p_ticket_id, 'status', v_status, 'priority', v_priority);
end;
$$;

create or replace function public.manage_contact_message(
  p_message_id uuid,
  p_status text,
  p_assigned_to uuid,
  p_admin_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_message public.contact_messages%rowtype;
  v_status text := lower(trim(p_status));
begin
  select * into v_message
  from public.contact_messages
  where id = p_message_id
  for update;

  if v_message.id is null then
    raise exception 'Mensagem não encontrada.';
  end if;

  if not public.has_permission(v_message.organization_id, 'support.manage') then
    raise exception 'Você não possui permissão para gerenciar contatos.';
  end if;

  if v_status not in ('new','in_review','answered','closed','spam') then
    raise exception 'Situação inválida.';
  end if;

  update public.contact_messages
  set status = v_status,
      assigned_to = p_assigned_to,
      admin_note = nullif(trim(coalesce(p_admin_note, '')), ''),
      answered_at = case when v_status in ('answered','closed') then coalesce(answered_at, now()) else null end
  where id = p_message_id;

  insert into public.audit_logs(
    organization_id, actor_id, action, entity_type, entity_id, old_data, new_data
  ) values (
    v_message.organization_id, auth.uid(), 'contact_message_updated', 'contact_message', p_message_id::text,
    jsonb_build_object('status', v_message.status, 'assigned_to', v_message.assigned_to),
    jsonb_build_object('status', v_status, 'assigned_to', p_assigned_to)
  );

  return jsonb_build_object('message_id', p_message_id, 'status', v_status);
end;
$$;

create or replace function public.create_privacy_request(
  p_request_type text,
  p_description text,
  p_whatsapp text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions, pg_temp
as $$
declare
  v_profile public.profiles%rowtype;
  v_organization_id uuid;
  v_request_id uuid;
  v_protocol text;
  v_type text := lower(trim(p_request_type));
begin
  if auth.uid() is null then
    raise exception 'Autenticação obrigatória.';
  end if;

  select * into v_profile
  from public.profiles
  where id = auth.uid();

  select om.organization_id into v_organization_id
  from public.organization_members om
  where om.profile_id = auth.uid()
    and om.status = 'active'
    and om.deleted_at is null
  limit 1;

  if v_profile.id is null or v_organization_id is null then
    raise exception 'Perfil ou vínculo ativo não encontrado.';
  end if;

  if v_type not in ('access','correction','deletion','anonymization','portability','consent_revocation') then
    raise exception 'Tipo de solicitação inválido.';
  end if;

  if char_length(trim(coalesce(p_description, ''))) not between 10 and 3000 then
    raise exception 'A descrição deve conter entre 10 e 3000 caracteres.';
  end if;

  v_protocol := 'LGPD-' || to_char(clock_timestamp(), 'YYYYMMDD') || '-' || upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 8));

  insert into public.privacy_requests(
    protocol, organization_id, profile_id, name, email, whatsapp,
    request_type, description, status
  ) values (
    v_protocol,
    v_organization_id,
    auth.uid(),
    trim(concat_ws(' ', v_profile.first_name, v_profile.last_name)),
    v_profile.email,
    coalesce(nullif(trim(coalesce(p_whatsapp, '')), ''), v_profile.whatsapp),
    v_type,
    trim(p_description),
    'open'
  ) returning id into v_request_id;

  insert into public.audit_logs(
    organization_id, actor_id, action, entity_type, entity_id, new_data
  ) values (
    v_organization_id, auth.uid(), 'privacy_request_created', 'privacy_request', v_request_id::text,
    jsonb_build_object('protocol', v_protocol, 'request_type', v_type)
  );

  return jsonb_build_object('request_id', v_request_id, 'protocol', v_protocol, 'status', 'open');
end;
$$;

create or replace function public.manage_privacy_request(
  p_request_id uuid,
  p_status text,
  p_decision text,
  p_assigned_to uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_request public.privacy_requests%rowtype;
  v_status text := lower(trim(p_status));
begin
  select * into v_request
  from public.privacy_requests
  where id = p_request_id
  for update;

  if v_request.id is null then
    raise exception 'Solicitação não encontrada.';
  end if;

  if not public.has_permission(v_request.organization_id, 'privacy.manage') then
    raise exception 'Você não possui permissão para gerenciar solicitações de privacidade.';
  end if;

  if v_status not in ('open','under_review','approved','rejected','completed','cancelled') then
    raise exception 'Situação inválida.';
  end if;

  if v_status in ('approved','rejected','completed') and nullif(trim(coalesce(p_decision, '')), '') is null then
    raise exception 'Registre a decisão antes de concluir a análise.';
  end if;

  update public.privacy_requests
  set status = v_status,
      assigned_to = p_assigned_to,
      decision = nullif(trim(coalesce(p_decision, '')), ''),
      resolved_at = case when v_status in ('rejected','completed','cancelled') then coalesce(resolved_at, now()) else null end
  where id = p_request_id;

  insert into public.audit_logs(
    organization_id, actor_id, action, entity_type, entity_id, old_data, new_data
  ) values (
    v_request.organization_id, auth.uid(), 'privacy_request_updated', 'privacy_request', p_request_id::text,
    jsonb_build_object('status', v_request.status, 'assigned_to', v_request.assigned_to),
    jsonb_build_object('status', v_status, 'assigned_to', p_assigned_to, 'decision', nullif(trim(coalesce(p_decision, '')), ''))
  );

  return jsonb_build_object('request_id', p_request_id, 'status', v_status);
end;
$$;

-- Escritas passam exclusivamente pelas funções protegidas.
revoke insert, update on public.support_tickets from authenticated;
revoke insert on public.support_messages from authenticated;
revoke insert, update on public.privacy_requests from authenticated;
revoke update on public.contact_messages from authenticated;

revoke all on function public.create_support_ticket(text,text,text,text) from public, anon, authenticated;
grant execute on function public.create_support_ticket(text,text,text,text) to authenticated;

revoke all on function public.add_support_message(uuid,text,boolean) from public, anon, authenticated;
grant execute on function public.add_support_message(uuid,text,boolean) to authenticated;

revoke all on function public.manage_support_ticket(uuid,text,text,uuid,text) from public, anon, authenticated;
grant execute on function public.manage_support_ticket(uuid,text,text,uuid,text) to authenticated;

revoke all on function public.manage_contact_message(uuid,text,uuid,text) from public, anon, authenticated;
grant execute on function public.manage_contact_message(uuid,text,uuid,text) to authenticated;

revoke all on function public.create_privacy_request(text,text,text) from public, anon, authenticated;
grant execute on function public.create_privacy_request(text,text,text) to authenticated;

revoke all on function public.manage_privacy_request(uuid,text,text,uuid) from public, anon, authenticated;
grant execute on function public.manage_privacy_request(uuid,text,text,uuid) to authenticated;

commit;
