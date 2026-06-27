begin;

insert into public.permissions (code, name, module, description)
values
  ('organization.manage', 'Administrar organização', 'organization', 'Alterar dados institucionais.'),
  ('organization.settings', 'Configurar organização', 'organization', 'Alterar configurações permitidas.'),
  ('users.read', 'Consultar usuárias', 'users', 'Consultar perfis vinculados.'),
  ('users.manage', 'Administrar usuárias', 'users', 'Atualizar vínculos e estados.'),
  ('users.invite', 'Convidar equipe', 'users', 'Criar e revogar convites.'),
  ('roles.manage', 'Administrar papéis', 'users', 'Associar papéis organizacionais.'),
  ('courses.read', 'Consultar cursos', 'courses', 'Consultar cursos, módulos e aulas.'),
  ('courses.manage', 'Administrar todos os cursos', 'courses', 'Administrar todos os cursos da organização.'),
  ('courses.edit_assigned', 'Editar cursos atribuídos', 'courses', 'Editar apenas cursos atribuídos à instrutora.'),
  ('enrollments.read', 'Consultar matrículas', 'courses', 'Consultar matrículas e progresso.'),
  ('enrollments.manage', 'Administrar matrículas', 'courses', 'Criar, alterar e cancelar matrículas.'),
  ('community.manage', 'Administrar comunidade', 'community', 'Criar e configurar espaços.'),
  ('community.moderate', 'Moderar comunidade', 'community', 'Analisar denúncias e aplicar medidas.'),
  ('billing.read', 'Consultar assinaturas', 'billing', 'Consultar planos e assinaturas.'),
  ('billing.manage', 'Administrar assinaturas', 'billing', 'Criar planos e administrar assinaturas.'),
  ('orders.read', 'Consultar pedidos', 'commerce', 'Consultar pedidos e itens.'),
  ('orders.manage', 'Administrar pedidos', 'commerce', 'Atualizar pedidos e seus estados.'),
  ('finance.read', 'Consultar pagamentos', 'finance', 'Consultar transações financeiras.'),
  ('finance.manage', 'Administrar pagamentos', 'finance', 'Registrar ajustes e reconciliações.'),
  ('access.manage', 'Administrar acessos', 'access', 'Conceder e revogar acessos.'),
  ('content.read', 'Consultar conteúdo interno', 'content', 'Consultar rascunhos e conteúdos internos.'),
  ('content.manage', 'Administrar conteúdo', 'content', 'Criar, editar e publicar conteúdo.'),
  ('events.read', 'Consultar eventos', 'events', 'Consultar eventos e inscrições.'),
  ('events.manage', 'Administrar eventos', 'events', 'Criar eventos e administrar inscrições.'),
  ('media.read', 'Consultar mídias', 'media', 'Consultar biblioteca de arquivos.'),
  ('media.manage', 'Administrar mídias', 'media', 'Enviar, substituir e excluir arquivos.'),
  ('support.manage', 'Administrar suporte', 'support', 'Responder e atualizar chamados.'),
  ('privacy.manage', 'Administrar solicitações LGPD', 'privacy', 'Analisar solicitações de privacidade.'),
  ('legal.manage', 'Administrar documentos jurídicos', 'legal', 'Publicar termos e políticas.'),
  ('logs.read', 'Consultar logs', 'security', 'Consultar logs operacionais.')
on conflict (code) do update
set name = excluded.name,
    module = excluded.module,
    description = excluded.description;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r cross join public.permissions p
where r.code = 'admin'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in ('courses.read','courses.edit_assigned','enrollments.read','media.read')
where r.code = 'instrutora'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in ('users.read','community.manage','community.moderate','media.read')
where r.code = 'moderadora'
on conflict do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.code in (
  'users.read','courses.read','enrollments.read','billing.read','orders.read',
  'finance.read','events.read','support.manage','media.read'
)
where r.code = 'atendimento'
on conflict do nothing;

commit;
