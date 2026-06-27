begin;

create policy courses_update_assigned_instructor on public.courses
for update to authenticated
using (
  public.has_permission(organization_id, 'courses.edit_assigned')
  and exists (
    select 1
    from public.course_instructors ci
    join public.organization_members om on om.id = ci.organization_member_id
    where ci.course_id = courses.id
      and om.profile_id = auth.uid()
      and om.status = 'active'
      and om.deleted_at is null
  )
)
with check (
  public.has_permission(organization_id, 'courses.edit_assigned')
  and exists (
    select 1
    from public.course_instructors ci
    join public.organization_members om on om.id = ci.organization_member_id
    where ci.course_id = courses.id
      and om.profile_id = auth.uid()
      and om.status = 'active'
      and om.deleted_at is null
  )
);

create policy course_modules_manage_assigned_instructor on public.course_modules
for all to authenticated
using (exists (
  select 1
  from public.courses c
  join public.course_instructors ci on ci.course_id = c.id
  join public.organization_members om on om.id = ci.organization_member_id
  where c.id = course_modules.course_id
    and om.profile_id = auth.uid()
    and om.status = 'active'
    and public.has_permission(c.organization_id, 'courses.edit_assigned')
))
with check (exists (
  select 1
  from public.courses c
  join public.course_instructors ci on ci.course_id = c.id
  join public.organization_members om on om.id = ci.organization_member_id
  where c.id = course_modules.course_id
    and om.profile_id = auth.uid()
    and om.status = 'active'
    and public.has_permission(c.organization_id, 'courses.edit_assigned')
));

create policy lessons_manage_assigned_instructor on public.lessons
for all to authenticated
using (exists (
  select 1
  from public.course_modules cm
  join public.courses c on c.id = cm.course_id
  join public.course_instructors ci on ci.course_id = c.id
  join public.organization_members om on om.id = ci.organization_member_id
  where cm.id = lessons.course_module_id
    and om.profile_id = auth.uid()
    and om.status = 'active'
    and public.has_permission(c.organization_id, 'courses.edit_assigned')
))
with check (exists (
  select 1
  from public.course_modules cm
  join public.courses c on c.id = cm.course_id
  join public.course_instructors ci on ci.course_id = c.id
  join public.organization_members om on om.id = ci.organization_member_id
  where cm.id = lessons.course_module_id
    and om.profile_id = auth.uid()
    and om.status = 'active'
    and public.has_permission(c.organization_id, 'courses.edit_assigned')
));

create policy lesson_materials_manage_assigned_instructor on public.lesson_materials
for all to authenticated
using (exists (
  select 1
  from public.lessons l
  join public.course_modules cm on cm.id = l.course_module_id
  join public.courses c on c.id = cm.course_id
  join public.course_instructors ci on ci.course_id = c.id
  join public.organization_members om on om.id = ci.organization_member_id
  where l.id = lesson_materials.lesson_id
    and om.profile_id = auth.uid()
    and om.status = 'active'
    and public.has_permission(c.organization_id, 'courses.edit_assigned')
))
with check (exists (
  select 1
  from public.lessons l
  join public.course_modules cm on cm.id = l.course_module_id
  join public.courses c on c.id = cm.course_id
  join public.course_instructors ci on ci.course_id = c.id
  join public.organization_members om on om.id = ci.organization_member_id
  where l.id = lesson_materials.lesson_id
    and om.profile_id = auth.uid()
    and om.status = 'active'
    and public.has_permission(c.organization_id, 'courses.edit_assigned')
));

create or replace function public.protect_course_publication_status()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.status is distinct from new.status
     and not public.has_permission(old.organization_id, 'courses.manage') then
    raise exception 'Somente administradoras autorizadas podem alterar o estado de publicação do curso.';
  end if;
  return new;
end;
$$;

create trigger courses_protect_publication_status
before update of status on public.courses
for each row execute function public.protect_course_publication_status();

revoke all on function public.protect_course_publication_status() from public;

commit;
