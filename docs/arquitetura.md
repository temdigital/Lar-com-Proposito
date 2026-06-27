# Arquitetura — Lar com Propósito

## Objetivo

Plataforma digital de formação, comunidade e assinatura para mulheres, com foco em mesa posta, espiritualidade católica, feminilidade e edificação familiar.

## Arquitetura tecnológica

- Frontend: HTML5, CSS3 e JavaScript ES Modules.
- Repositório: GitHub.
- Deploy: Vercel.
- Autenticação: Supabase Auth.
- Banco: Supabase PostgreSQL.
- Arquivos: Supabase Storage.
- Operações privilegiadas: Supabase Edge Functions ou RPC protegida.

## Princípio multi-tenant

O sistema começará com uma organização operacional, mas todas as entidades privadas deverão aceitar `organization_id`. O isolamento entre organizações será aplicado por chaves estrangeiras, índices e Row Level Security.

## Domínios funcionais

1. Identidade e acesso.
2. Organizações, membros e permissões.
3. Cursos, módulos, aulas e progresso.
4. Comunidade e moderação.
5. Clube, planos, assinaturas e acessos.
6. Conteúdo público e eventos.
7. Notificações, suporte, LGPD e auditoria.

## Regras técnicas

- A chave `service_role` nunca pode chegar ao navegador.
- O frontend pode esconder menus, mas não substitui RLS.
- Uma pessoa possui um único registro central em `profiles`.
- Aluna e assinante são estados de acesso, não papéis administrativos.
- Vídeos do MVP serão cadastrados por URL/ID do YouTube.
- Pagamentos serão confirmados por webhook idempotente.
- Exclusões sensíveis serão lógicas e auditadas.
- Nenhuma migration de alteração será aplicada antes da auditoria do projeto Supabase existente.

## Ordem de implementação

1. Auditoria do Supabase.
2. Modelo base e autenticação.
3. Organizações, papéis e RLS.
4. Área pública.
5. Cursos e progresso.
6. Comunidade e moderação.
7. Clube e pagamentos.
8. Administração, relatórios, LGPD e homologação.
