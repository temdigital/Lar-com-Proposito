begin;

insert into public.organizations (id, name, slug, legal_name, status)
values (
  '11111111-1111-4111-8111-111111111111',
  'Lar com Propósito',
  'lar-com-proposito',
  'Lar com Propósito | Mulheres que edificam com amor',
  'active'
)
on conflict (id) do update
set name = excluded.name,
    slug = excluded.slug,
    legal_name = excluded.legal_name,
    status = excluded.status,
    updated_at = now();

insert into public.organization_settings (
  organization_id, brand_name, timezone, locale, settings
)
values (
  '11111111-1111-4111-8111-111111111111',
  'Lar com Propósito',
  'America/Sao_Paulo',
  'pt-BR',
  jsonb_build_object(
    'tagline', 'Mulheres que edificam com amor',
    'theme', 'altar-domestico',
    'email_confirmation_required', true
  )
)
on conflict (organization_id) do update
set brand_name = excluded.brand_name,
    timezone = excluded.timezone,
    locale = excluded.locale,
    settings = excluded.settings,
    updated_at = now();

insert into public.roles (code, name, description, is_system)
values
  ('admin', 'Administradora', 'Administração integral da organização.', true),
  ('instrutora', 'Instrutora', 'Gestão dos cursos atribuídos e acompanhamento das alunas.', true),
  ('moderadora', 'Moderadora', 'Moderação dos espaços e análise de denúncias.', true),
  ('atendimento', 'Atendimento', 'Suporte operacional com acesso limitado.', true),
  ('membro', 'Membro', 'Acesso aos recursos liberados por matrícula, assinatura ou convite.', true)
on conflict (code) do update
set name = excluded.name,
    description = excluded.description,
    is_system = excluded.is_system,
    updated_at = now();

commit;
