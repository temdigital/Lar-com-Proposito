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

## Recursos implementados

- página institucional responsiva;
- navegação pública padronizada com prioridade mobile;
- logotipo tipográfico cursivo com conceito visual Altar Doméstico;
- cadastro, confirmação de e-mail, login e recuperação de senha;
- dashboard mobile-first da membro com cursos, comunidade, conteúdos, eventos, assinatura e perfil;
- painel administrativo protegido por papéis e permissões;
- indicadores administrativos condicionados ao acesso autorizado;
- gestão de cursos com criação, edição, filtros, preços, formas de acesso, certificados e arquivamento;
- gestão do conteúdo programático com módulos, liberação gradual, videoaulas, textos, prévias e arquivamento;
- gestão de pessoas com consulta, filtros, situação do vínculo, função e papéis organizacionais;
- convites com token criptográfico armazenado somente como hash, revogação e aceite autenticado;
- proteção contra autossuspensão, autorremoção do papel administrativo e remoção da última administradora;
- gestão administrativa da comunidade com espaços, acesso por membro, curso, plano ou convite;
- fila de denúncias com ocultação, remoção, restauração, advertência, suspensão, banimento e descarte;
- feed da membro com publicações, comentários, reações e denúncias;
- bloqueio de novas publicações e comentários durante suspensão ativa;
- páginas Sobre, Fale conosco, Termos, Privacidade e Cookies;
- formulário público de contato protegido por RLS;
- robots.txt, sitemap.xml, security.txt e página 404;
- banco multi-organização com cursos, comunidade, assinaturas, conteúdo, suporte e auditoria.

## Banco de dados

A fundação foi instalada até `013_verify_installation.sql`.

Migrations posteriores:

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

A primeira administradora foi promovida com os papéis `admin` e `membro`. O procedimento auditável permanece documentado em `supabase/manual/promote_first_admin.sql`.

Consulte `docs/instalacao-supabase.md` antes de executar novos arquivos.

## Segurança

Nunca adicionar ao repositório:

- chave `service_role`;
- senha do banco;
- segredo JWT;
- credenciais privadas de pagamento;
- tokens OAuth privados.

A chave publishable do Supabase é pública e é fornecida ao frontend pela Vercel.
