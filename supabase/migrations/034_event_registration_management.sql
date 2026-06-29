begin;

create or replace function public.cancel_event_registration(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,auth,pg_temp
as $$
declare
  e public.events%rowtype;
  rid uuid;
  old_status text;
  next_id uuid;
  next_profile uuid;
begin
  if auth.uid() is null then raise exception 'Autenticação obrigatória.'; end if;
  select * into e from public.events where id=p_event_id for update;
  select id,status into rid,old_status
  from public.event_registrations
  where event_id=p_event_id and profile_id=auth.uid()
  for update;

  if rid is null or old_status='cancelled' then raise exception 'Inscrição ativa não encontrada.'; end if;
  if old_status in('attended','no_show') then raise exception 'Esta inscrição não pode mais ser cancelada.'; end if;

  update public.event_registrations set status='cancelled',checked_in_at=null where id=rid;

  if old_status in('pending','confirmed') then
    select id,profile_id into next_id,next_profile
    from public.event_registrations
    where event_id=p_event_id and status='waitlist'
    order by registered_at
    limit 1
    for update skip locked;

    if next_id is not null then
      update public.event_registrations
      set status=case when e.price>0 then 'pending' else 'confirmed' end
      where id=next_id;
      insert into public.notifications(organization_id,profile_id,channel,type,title,body,action_url,status)
      values(e.organization_id,next_profile,'internal','event_waitlist_promoted','Uma vaga foi liberada','Sua inscrição avançou na fila.','/app/#eventos','sent');
    end if;
  end if;

  return jsonb_build_object('registration_id',rid,'status','cancelled');
end;
$$;

create or replace function public.admin_update_event_registration(p_registration_id uuid,p_status text)
returns jsonb
language plpgsql
security definer
set search_path=public,auth,pg_temp
as $$
declare
  org_id uuid;
  profile_id_value uuid;
  event_id_value uuid;
  event_title text;
  new_status text:=lower(trim(p_status));
begin
  if new_status not in('pending','confirmed','waitlist','cancelled','attended','no_show') then raise exception 'Situação inválida.'; end if;

  select e.organization_id,er.profile_id,er.event_id,e.title
  into org_id,profile_id_value,event_id_value,event_title
  from public.event_registrations er
  join public.events e on e.id=er.event_id
  where er.id=p_registration_id
  for update of er;

  if org_id is null then raise exception 'Inscrição não encontrada.'; end if;
  if not public.has_permission(org_id,'events.manage') then raise exception 'Permissão negada.'; end if;

  update public.event_registrations
  set status=new_status,
      checked_in_at=case when new_status='attended' then now() else null end
  where id=p_registration_id;

  insert into public.audit_logs(organization_id,actor_id,action,entity_type,entity_id,new_data)
  values(org_id,auth.uid(),'event_registration_updated','event_registration',p_registration_id::text,
    jsonb_build_object('event_id',event_id_value,'profile_id',profile_id_value,'status',new_status));

  insert into public.notifications(organization_id,profile_id,channel,type,title,body,action_url,status)
  values(org_id,profile_id_value,'internal','event_registration_status','Inscrição atualizada','A situação da sua inscrição foi atualizada.','/app/#eventos','sent');

  return jsonb_build_object('registration_id',p_registration_id,'status',new_status);
end;
$$;

drop policy if exists event_registrations_manage on public.event_registrations;
create policy event_registrations_manage on public.event_registrations
for update to authenticated
using(exists(select 1 from public.events e where e.id=event_id and public.has_permission(e.organization_id,'events.manage')))
with check(exists(select 1 from public.events e where e.id=event_id and public.has_permission(e.organization_id,'events.manage')));

revoke all on function public.cancel_event_registration(uuid) from public,anon,authenticated;
grant execute on function public.cancel_event_registration(uuid) to authenticated;
revoke all on function public.admin_update_event_registration(uuid,text) from public,anon,authenticated;
grant execute on function public.admin_update_event_registration(uuid,text) to authenticated;

commit;
