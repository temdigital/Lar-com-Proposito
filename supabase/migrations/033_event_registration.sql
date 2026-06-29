begin;

create or replace function public.register_for_event(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,auth,pg_temp
as $$
declare
  e public.events%rowtype;
  rid uuid;
  old_status text;
  used_count integer;
  new_status text;
begin
  if auth.uid() is null then raise exception 'Autenticação obrigatória.'; end if;
  select * into e from public.events where id=p_event_id for update;
  if e.id is null or e.deleted_at is not null or e.status<>'published' then raise exception 'Evento indisponível.'; end if;
  if e.starts_at<=now() then raise exception 'Inscrições encerradas.'; end if;
  if e.is_members_only and not public.is_organization_member(e.organization_id) then raise exception 'Evento exclusivo para membros.'; end if;
  if e.registration_opens_at is not null and now()<e.registration_opens_at then raise exception 'Inscrições ainda não abertas.'; end if;
  if e.registration_deadline is not null and now()>e.registration_deadline then raise exception 'Prazo encerrado.'; end if;

  select id,status into rid,old_status
  from public.event_registrations
  where event_id=p_event_id and profile_id=auth.uid()
  for update;

  if rid is not null and old_status<>'cancelled' then
    return jsonb_build_object('registration_id',rid,'status',old_status,'already_registered',true);
  end if;

  select count(*)::integer into used_count
  from public.event_registrations
  where event_id=p_event_id and status in('pending','confirmed','attended');

  if e.capacity is null or used_count<e.capacity then
    new_status:=case when e.price>0 then 'pending' else 'confirmed' end;
  elsif e.waitlist_enabled then
    new_status:='waitlist';
  else
    raise exception 'Não há vagas disponíveis.';
  end if;

  if rid is null then
    insert into public.event_registrations(event_id,profile_id,status)
    values(p_event_id,auth.uid(),new_status)
    returning id into rid;
  else
    update public.event_registrations
    set status=new_status,registered_at=now(),checked_in_at=null,order_id=null
    where id=rid;
  end if;

  return jsonb_build_object('registration_id',rid,'status',new_status,'already_registered',false);
end;
$$;

drop policy if exists event_registrations_insert on public.event_registrations;

revoke all on function public.register_for_event(uuid) from public,anon,authenticated;
grant execute on function public.register_for_event(uuid) to authenticated;

commit;
