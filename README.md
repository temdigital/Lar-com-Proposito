# Lar com Propósito

Plataforma digital **Lar com Propósito | Mulheres que edificam com amor**.

## Stack

- HTML5, CSS3 e JavaScript modular;
- Supabase Auth, PostgreSQL e Storage;
- Vercel para deploy e funções públicas de configuração;
- GitHub para versionamento.

## Produção

Endereço oficial nesta fase:

`https://lar-com-proposito.vercel.app`

## Identidade visual oficial

A identidade consolidada do projeto usa:

- símbolo de dois arcos orgânicos com ponto terracota;
- assinatura “Lar com Propósito” em Parisienne;
- subtítulo “Mulheres que edificam com amor” em Inter;
- títulos editoriais em Georgia;
- paleta Altar Doméstico: Creme Eucaristia, Dourado Sacro, Terracota Tijolo, Verde Esperança e Vinho Profundo.

A identidade aplicada ao site deve ser preservada sem reinterpretação.

## Recursos implementados

- página institucional responsiva;
- navegação pública padronizada com prioridade mobile;
- cadastro, confirmação de e-mail, login e recuperação de senha;
- dashboard mobile-first da membro;
- painel administrativo protegido por papéis e permissões;
- gestão de cursos, módulos, aulas, matrículas e certificados;
- gestão de pessoas, convites, papéis e permissões;
- proteção da última administradora e bloqueio de alterações críticas indevidas;
- gestão administrativa da comunidade;
- denúncias, moderação, suspensões, reações e feed seguro;
- gestão editorial com categorias, rascunho, revisão, publicação, arquivamento e SEO;
- leitura de conteúdos e favoritos na área da membro;
- gestão de eventos, inscrições, capacidade, lista de espera e detalhes privados;
- feed protegido de eventos para membros;
- central administrativa de atendimento;
- chamados com protocolo, histórico, notas internas e notificações;
- mensagens do formulário público organizadas em fila;
- solicitações de privacidade com protocolo, análise e decisão;
- área da membro para abertura e acompanhamento de chamados e pedidos LGPD;
- clube e assinaturas em modo de homologação, sem cobrança real;
- gestão de planos, benefícios, associações manuais e acessos por assinatura;
- visualização informativa de planos na área da membro;
- páginas Sobre, Fale conosco, Termos, Privacidade e Cookies;
- formulário público de contato protegido por RLS;
- robots.txt, sitemap.xml, security.txt e página 404;
- banco multi-organização com auditoria.

## Banco de dados

A fundação foi instalada até `013_verify_installation.sql`.

Migrations posteriores, em ordem:

1. `014_contact_messages.sql`
2. `015_verify_contact.sql`
3. `016_member_dashboard.sql`
4. `017_verify_member_dashboard.sql`
5. `018_lock_member_context.sql`
6. `019_verify_member_context_lock.sql`
7. `020_people_access.sql`
8. `021_verify_people_access.sql`
9. `022_lock_people_access.sql`
10. `023_verify_people_access_lock.sql`
11. `024_community_management.sql`
12. `025_verify_community_management.sql`
13. `026_community_admin_visibility.sql`
14. `027_verify_community_admin_visibility.sql`
15. `028_community_member_feed.sql`
16. `029_verify_community_member_feed.sql`
17. `030_content_management.sql`
18. `031_verify_content_management.sql`
19. `032_events_management.sql`
20. `033_verify_events_management.sql`
21. `034_event_private_access.sql`
22. `035_member_events_feed.sql`
23. `036_verify_member_events_feed.sql`
24. `037_support_center.sql`
25. `038_verify_support_center.sql`
26. `039_club_subscriptions_homologation.sql`
27. `040_verify_club_subscriptions_homologation.sql`
28. `041_lock_club_function_privileges.sql`
29. `042_verify_club_function_privileges.sql`

As migrations até `042` estão confirmadas no ambiente. Os verificadores `040` e `042` retornaram todos os campos como `true`. A próxima etapa é a homologação operacional do Clube e Assinaturas com conta secundária, sem cobrança real.

A primeira administradora foi promovida com os papéis `admin` e `membro`. O procedimento auditável permanece documentado em `supabase/manual/promote_first_admin.sql`.

Consulte `docs/instalacao-supabase.md`, `docs/modulo-clube-assinaturas.md` e `supabase/manual/verify_club_operational_homologation.sql` antes de avançar para pagamentos.

## Segurança

Nunca adicionar ao repositório:

- chave `service_role`;
- senha do banco;
- segredo JWT;
- credenciais privadas de pagamento;
- tokens OAuth privados.

A chave publishable do Supabase é pública e é fornecida ao frontend pela Vercel.
