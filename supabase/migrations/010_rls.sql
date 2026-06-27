begin;

-- Habilita RLS em todas as tabelas da aplicação.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'organizations','organization_settings','profiles','organization_members','invitations',
    'terms_versions','terms_acceptances','privacy_requests','audit_logs','roles','permissions',
    'role_permissions','member_roles','courses','course_instructors','course_modules','lessons',
    'lesson_materials','enrollments','lesson_progress','certificates','plans','plan_features',
    'subscriptions','subscription_events','orders','order_items','payment_transactions',
    'payment_webhooks','access_grants','community_spaces','community_space_members',
    'community_posts','community_comments','community_reactions','community_reports',
    'moderation_actions','community_suspensions','content_categories','content_posts','events',
    'event_registrations','media_assets','notifications','support_tickets','support_messages','favorites'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
  end loop;
end $$;

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant select on public.terms_versions, public.courses, public.course_modules, public.lessons,
  public.plans, public.plan_features, public.community_spaces, public.community_posts,
  public.community_comments, public.content_categories, public.content_posts, public.events
  to anon;

-- Organizações e perfis
create policy organizations_select on public.organizations
for select to authenticated
using (public.is_organization_member(id));

create policy organizations_update on public.organizations
for update to authenticated
using (public.has_permission(id, 'organization.manage'))
with check (public.has_permission(id, 'organization.manage'));

create policy organization_settings_select on public.organization_settings
for select to authenticated
using (public.is_organization_member(organization_id));

create policy organization_settings_manage on public.organization_settings
for all to authenticated
using (public.has_permission(organization_id, 'organization.settings'))
with check (public.has_permission(organization_id, 'organization.settings'));

create policy profiles_select on public.profiles
for select to authenticated
using (
  id = auth.uid()
  or public.is_superadmin()
  or exists (
    select 1 from public.organization_members target_member
    where target_member.profile_id = profiles.id
      and public.has_permission(target_member.organization_id, 'users.read')
  )
);

create policy profiles_update_self on public.profiles
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid() and is_superadmin = public.is_superadmin());

create policy profiles_manage on public.profiles
for update to authenticated
using (
  public.is_superadmin()
  or exists (
    select 1 from public.organization_members target_member
    where target_member.profile_id = profiles.id
      and public.has_permission(target_member.organization_id, 'users.manage')
  )
)
with check (true);

create policy organization_members_select on public.organization_members
for select to authenticated
using (profile_id = auth.uid() or public.has_permission(organization_id, 'users.read'));

create policy organization_members_manage on public.organization_members
for all to authenticated
using (public.has_permission(organization_id, 'users.manage'))
with check (public.has_permission(organization_id, 'users.manage'));

create policy invitations_manage on public.invitations
for all to authenticated
using (public.has_permission(organization_id, 'users.invite'))
with check (public.has_permission(organization_id, 'users.invite'));

-- Documentos jurídicos e LGPD
create policy terms_versions_public_read on public.terms_versions
for select to anon, authenticated
using (status = 'published');

create policy terms_versions_manage on public.terms_versions
for all to authenticated
using (organization_id is null and public.is_superadmin() or public.has_permission(organization_id, 'legal.manage'))
with check (organization_id is null and public.is_superadmin() or public.has_permission(organization_id, 'legal.manage'));

create policy terms_acceptances_self on public.terms_acceptances
for select to authenticated using (profile_id = auth.uid());

create policy terms_acceptances_insert_self on public.terms_acceptances
for insert to authenticated with check (profile_id = auth.uid());

create policy privacy_requests_select on public.privacy_requests
for select to authenticated
using (profile_id = auth.uid() or public.has_permission(organization_id, 'privacy.manage'));

create policy privacy_requests_insert on public.privacy_requests
for insert to authenticated
with check (profile_id = auth.uid());

create policy privacy_requests_manage on public.privacy_requests
for update to authenticated
using (public.has_permission(organization_id, 'privacy.manage'))
with check (public.has_permission(organization_id, 'privacy.manage'));

create policy audit_logs_read on public.audit_logs
for select to authenticated
using (public.is_superadmin() or public.has_permission(organization_id, 'logs.read'));

-- Papéis e permissões
create policy roles_read on public.roles for select to authenticated using (true);
create policy permissions_read on public.permissions for select to authenticated using (true);
create policy role_permissions_read on public.role_permissions for select to authenticated using (true);

create policy roles_manage on public.roles
for all to authenticated
using (public.is_superadmin()) with check (public.is_superadmin());

create policy permissions_manage on public.permissions
for all to authenticated
using (public.is_superadmin()) with check (public.is_superadmin());

create policy role_permissions_manage on public.role_permissions
for all to authenticated
using (public.is_superadmin()) with check (public.is_superadmin());

create policy member_roles_select on public.member_roles
for select to authenticated
using (
  public.has_permission(organization_id, 'users.read')
  or exists (
    select 1 from public.organization_members om
    where om.id = member_roles.organization_member_id and om.profile_id = auth.uid()
  )
);

create policy member_roles_manage on public.member_roles
for all to authenticated
using (public.has_permission(organization_id, 'roles.manage'))
with check (public.has_permission(organization_id, 'roles.manage'));

-- Cursos
create policy courses_public_read on public.courses
for select to anon, authenticated
using (
  deleted_at is null and (
    status = 'published'
    or public.has_permission(organization_id, 'courses.read')
    or exists (
      select 1 from public.course_instructors ci
      join public.organization_members om on om.id = ci.organization_member_id
      where ci.course_id = courses.id and om.profile_id = auth.uid() and om.status = 'active'
    )
  )
);

create policy courses_manage on public.courses
for all to authenticated
using (public.has_permission(organization_id, 'courses.manage'))
with check (public.has_permission(organization_id, 'courses.manage'));

create policy course_instructors_read on public.course_instructors
for select to authenticated
using (
  exists (select 1 from public.courses c where c.id = course_id and public.has_permission(c.organization_id, 'courses.read'))
  or exists (select 1 from public.organization_members om where om.id = organization_member_id and om.profile_id = auth.uid())
);

create policy course_instructors_manage on public.course_instructors
for all to authenticated
using (exists (select 1 from public.courses c where c.id = course_id and public.has_permission(c.organization_id, 'courses.manage')))
with check (exists (select 1 from public.courses c where c.id = course_id and public.has_permission(c.organization_id, 'courses.manage')));

create policy course_modules_read on public.course_modules
for select to anon, authenticated
using (exists (
  select 1 from public.courses c
  where c.id = course_id and (
    (c.status = 'published' and course_modules.status = 'published')
    or public.has_permission(c.organization_id, 'courses.read')
  )
));

create policy course_modules_manage on public.course_modules
for all to authenticated
using (exists (select 1 from public.courses c where c.id = course_id and public.has_permission(c.organization_id, 'courses.manage')))
with check (exists (select 1 from public.courses c where c.id = course_id and public.has_permission(c.organization_id, 'courses.manage')));

create policy lessons_read on public.lessons
for select to anon, authenticated
using (exists (
  select 1 from public.course_modules cm
  join public.courses c on c.id = cm.course_id
  where cm.id = lessons.course_module_id and (
    (lessons.status = 'published' and c.status = 'published' and lessons.is_preview)
    or public.has_active_enrollment(c.id)
    or public.has_permission(c.organization_id, 'courses.read')
  )
));

create policy lessons_manage on public.lessons
for all to authenticated
using (exists (
  select 1 from public.course_modules cm join public.courses c on c.id = cm.course_id
  where cm.id = lessons.course_module_id and public.has_permission(c.organization_id, 'courses.manage')
))
with check (exists (
  select 1 from public.course_modules cm join public.courses c on c.id = cm.course_id
  where cm.id = lessons.course_module_id and public.has_permission(c.organization_id, 'courses.manage')
));

create policy lesson_materials_read on public.lesson_materials
for select to authenticated
using (exists (
  select 1 from public.lessons l
  join public.course_modules cm on cm.id = l.course_module_id
  join public.courses c on c.id = cm.course_id
  where l.id = lesson_materials.lesson_id
    and (public.has_active_enrollment(c.id) or public.has_permission(c.organization_id, 'courses.read'))
));

create policy lesson_materials_manage on public.lesson_materials
for all to authenticated
using (exists (
  select 1 from public.lessons l join public.course_modules cm on cm.id = l.course_module_id
  join public.courses c on c.id = cm.course_id
  where l.id = lesson_materials.lesson_id and public.has_permission(c.organization_id, 'courses.manage')
))
with check (exists (
  select 1 from public.lessons l join public.course_modules cm on cm.id = l.course_module_id
  join public.courses c on c.id = cm.course_id
  where l.id = lesson_materials.lesson_id and public.has_permission(c.organization_id, 'courses.manage')
));

create policy enrollments_select on public.enrollments
for select to authenticated
using (profile_id = auth.uid() or public.has_permission(organization_id, 'enrollments.manage'));

create policy enrollments_manage on public.enrollments
for all to authenticated
using (public.has_permission(organization_id, 'enrollments.manage'))
with check (public.has_permission(organization_id, 'enrollments.manage'));

create policy lesson_progress_select on public.lesson_progress
for select to authenticated
using (exists (
  select 1 from public.enrollments e
  where e.id = lesson_progress.enrollment_id
    and (e.profile_id = auth.uid() or public.has_permission(e.organization_id, 'enrollments.read'))
));

create policy lesson_progress_write on public.lesson_progress
for insert to authenticated
with check (exists (select 1 from public.enrollments e where e.id = enrollment_id and e.profile_id = auth.uid()));

create policy lesson_progress_update on public.lesson_progress
for update to authenticated
using (exists (select 1 from public.enrollments e where e.id = enrollment_id and e.profile_id = auth.uid()))
with check (exists (select 1 from public.enrollments e where e.id = enrollment_id and e.profile_id = auth.uid()));

create policy certificates_select on public.certificates
for select to authenticated
using (exists (
  select 1 from public.enrollments e
  where e.id = certificates.enrollment_id
    and (e.profile_id = auth.uid() or public.has_permission(e.organization_id, 'enrollments.read'))
));

-- Planos, pedidos e pagamentos
create policy plans_public_read on public.plans
for select to anon, authenticated
using (status = 'active' or public.has_permission(organization_id, 'billing.manage'));

create policy plans_manage on public.plans
for all to authenticated
using (public.has_permission(organization_id, 'billing.manage'))
with check (public.has_permission(organization_id, 'billing.manage'));

create policy plan_features_read on public.plan_features
for select to anon, authenticated
using (exists (select 1 from public.plans p where p.id = plan_id and (p.status = 'active' or public.has_permission(p.organization_id, 'billing.manage'))));

create policy plan_features_manage on public.plan_features
for all to authenticated
using (exists (select 1 from public.plans p where p.id = plan_id and public.has_permission(p.organization_id, 'billing.manage')))
with check (exists (select 1 from public.plans p where p.id = plan_id and public.has_permission(p.organization_id, 'billing.manage')));

create policy subscriptions_select on public.subscriptions
for select to authenticated
using (profile_id = auth.uid() or public.has_permission(organization_id, 'billing.read'));

create policy subscriptions_manage on public.subscriptions
for all to authenticated
using (public.has_permission(organization_id, 'billing.manage'))
with check (public.has_permission(organization_id, 'billing.manage'));

create policy subscription_events_read on public.subscription_events
for select to authenticated
using (exists (
  select 1 from public.subscriptions s
  where s.id = subscription_id and (s.profile_id = auth.uid() or public.has_permission(s.organization_id, 'billing.read'))
));

create policy orders_select on public.orders
for select to authenticated
using (profile_id = auth.uid() or public.has_permission(organization_id, 'orders.read'));

create policy orders_manage on public.orders
for all to authenticated
using (public.has_permission(organization_id, 'orders.manage'))
with check (public.has_permission(organization_id, 'orders.manage'));

create policy order_items_select on public.order_items
for select to authenticated
using (exists (
  select 1 from public.orders o
  where o.id = order_id and (o.profile_id = auth.uid() or public.has_permission(o.organization_id, 'orders.read'))
));

create policy order_items_manage on public.order_items
for all to authenticated
using (exists (select 1 from public.orders o where o.id = order_id and public.has_permission(o.organization_id, 'orders.manage')))
with check (exists (select 1 from public.orders o where o.id = order_id and public.has_permission(o.organization_id, 'orders.manage')));

create policy payment_transactions_select on public.payment_transactions
for select to authenticated
using (profile_id = auth.uid() or public.has_permission(organization_id, 'finance.read'));

create policy payment_transactions_manage on public.payment_transactions
for all to authenticated
using (public.has_permission(organization_id, 'finance.manage'))
with check (public.has_permission(organization_id, 'finance.manage'));

create policy payment_webhooks_superadmin on public.payment_webhooks
for select to authenticated using (public.is_superadmin());

create policy access_grants_select on public.access_grants
for select to authenticated
using (profile_id = auth.uid() or public.has_permission(organization_id, 'access.manage'));

create policy access_grants_manage on public.access_grants
for all to authenticated
using (public.has_permission(organization_id, 'access.manage'))
with check (public.has_permission(organization_id, 'access.manage'));

-- Comunidade
create policy community_spaces_read on public.community_spaces
for select to anon, authenticated
using (public.can_access_community_space(id));

create policy community_spaces_manage on public.community_spaces
for all to authenticated
using (public.has_permission(organization_id, 'community.manage'))
with check (public.has_permission(organization_id, 'community.manage'));

create policy community_space_members_select on public.community_space_members
for select to authenticated
using (profile_id = auth.uid() or exists (
  select 1 from public.community_spaces cs where cs.id = space_id and public.has_permission(cs.organization_id, 'community.manage')
));

create policy community_space_members_manage on public.community_space_members
for all to authenticated
using (exists (select 1 from public.community_spaces cs where cs.id = space_id and public.has_permission(cs.organization_id, 'community.manage')))
with check (exists (select 1 from public.community_spaces cs where cs.id = space_id and public.has_permission(cs.organization_id, 'community.manage')));

create policy community_posts_read on public.community_posts
for select to anon, authenticated
using (deleted_at is null and status = 'published' and public.can_access_community_space(space_id));

create policy community_posts_insert on public.community_posts
for insert to authenticated
with check (author_id = auth.uid() and public.can_access_community_space(space_id));

create policy community_posts_update on public.community_posts
for update to authenticated
using (author_id = auth.uid() or public.has_permission(organization_id, 'community.moderate'))
with check (author_id = auth.uid() or public.has_permission(organization_id, 'community.moderate'));

create policy community_comments_read on public.community_comments
for select to anon, authenticated
using (status = 'published' and deleted_at is null and exists (
  select 1 from public.community_posts p where p.id = post_id and public.can_access_community_space(p.space_id)
));

create policy community_comments_insert on public.community_comments
for insert to authenticated
with check (author_id = auth.uid() and exists (
  select 1 from public.community_posts p where p.id = post_id and public.can_access_community_space(p.space_id)
));

create policy community_comments_update on public.community_comments
for update to authenticated
using (author_id = auth.uid() or exists (
  select 1 from public.community_posts p where p.id = post_id and public.has_permission(p.organization_id, 'community.moderate')
));

create policy community_reactions_self on public.community_reactions
for all to authenticated
using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy community_reports_select on public.community_reports
for select to authenticated
using (reporter_id = auth.uid() or public.has_permission(organization_id, 'community.moderate'));

create policy community_reports_insert on public.community_reports
for insert to authenticated with check (reporter_id = auth.uid());

create policy community_reports_manage on public.community_reports
for update to authenticated
using (public.has_permission(organization_id, 'community.moderate'))
with check (public.has_permission(organization_id, 'community.moderate'));

create policy moderation_actions_read on public.moderation_actions
for select to authenticated
using (public.has_permission(organization_id, 'community.moderate'));

create policy moderation_actions_insert on public.moderation_actions
for insert to authenticated
with check (moderator_id = auth.uid() and public.has_permission(organization_id, 'community.moderate'));

create policy community_suspensions_read on public.community_suspensions
for select to authenticated
using (profile_id = auth.uid() or public.has_permission(organization_id, 'community.moderate'));

create policy community_suspensions_manage on public.community_suspensions
for all to authenticated
using (public.has_permission(organization_id, 'community.moderate'))
with check (public.has_permission(organization_id, 'community.moderate'));

-- Conteúdo, eventos, mídia e suporte
create policy content_categories_read on public.content_categories
for select to anon, authenticated using (true);

create policy content_categories_manage on public.content_categories
for all to authenticated
using (public.has_permission(organization_id, 'content.manage'))
with check (public.has_permission(organization_id, 'content.manage'));

create policy content_posts_read on public.content_posts
for select to anon, authenticated
using (
  deleted_at is null and status = 'published' and (
    not is_members_only or public.is_organization_member(organization_id)
  )
  or public.has_permission(organization_id, 'content.read')
);

create policy content_posts_manage on public.content_posts
for all to authenticated
using (public.has_permission(organization_id, 'content.manage'))
with check (public.has_permission(organization_id, 'content.manage'));

create policy events_read on public.events
for select to anon, authenticated
using (deleted_at is null and status = 'published' or public.has_permission(organization_id, 'events.read'));

create policy events_manage on public.events
for all to authenticated
using (public.has_permission(organization_id, 'events.manage'))
with check (public.has_permission(organization_id, 'events.manage'));

create policy event_registrations_select on public.event_registrations
for select to authenticated
using (profile_id = auth.uid() or exists (
  select 1 from public.events e where e.id = event_id and public.has_permission(e.organization_id, 'events.manage')
));

create policy event_registrations_insert on public.event_registrations
for insert to authenticated with check (profile_id = auth.uid());

create policy event_registrations_manage on public.event_registrations
for update to authenticated
using (profile_id = auth.uid() or exists (
  select 1 from public.events e where e.id = event_id and public.has_permission(e.organization_id, 'events.manage')
));

create policy media_assets_read on public.media_assets
for select to authenticated
using (owner_id = auth.uid() or visibility = 'public' or public.has_permission(organization_id, 'media.read'));

create policy media_assets_manage on public.media_assets
for all to authenticated
using (owner_id = auth.uid() or public.has_permission(organization_id, 'media.manage'))
with check (owner_id = auth.uid() or public.has_permission(organization_id, 'media.manage'));

create policy notifications_self on public.notifications
for select to authenticated using (profile_id = auth.uid());

create policy notifications_update_self on public.notifications
for update to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy support_tickets_select on public.support_tickets
for select to authenticated
using (profile_id = auth.uid() or public.has_permission(organization_id, 'support.manage'));

create policy support_tickets_insert on public.support_tickets
for insert to authenticated with check (profile_id = auth.uid());

create policy support_tickets_update on public.support_tickets
for update to authenticated
using (profile_id = auth.uid() or public.has_permission(organization_id, 'support.manage'));

create policy support_messages_select on public.support_messages
for select to authenticated
using (exists (
  select 1 from public.support_tickets t
  where t.id = ticket_id and (t.profile_id = auth.uid() or public.has_permission(t.organization_id, 'support.manage'))
));

create policy support_messages_insert on public.support_messages
for insert to authenticated
with check (author_id = auth.uid() and exists (
  select 1 from public.support_tickets t
  where t.id = ticket_id and (t.profile_id = auth.uid() or public.has_permission(t.organization_id, 'support.manage'))
));

create policy favorites_self on public.favorites
for all to authenticated
using (profile_id = auth.uid()) with check (profile_id = auth.uid());

commit;
