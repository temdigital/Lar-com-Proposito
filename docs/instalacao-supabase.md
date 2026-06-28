# Instalação inicial do Supabase

## Situação auditada

Na auditoria de 27/06/2026, o schema `public` estava vazio, o Auth não possuía usuários e nenhum bucket da aplicação estava criado.

## Fundação já instalada

Os arquivos de `002_base.sql` até `013_verify_installation.sql` foram executados e validados com sucesso. O ambiente retornou:

- 47 tabelas públicas;
- 99 policies RLS;
- 6 buckets;
- 30 permissões;
- 5 papéis oficiais;
- 2 triggers do Auth;
- organização principal criada.

## Migrations posteriores

Depois da fundação, execute novos arquivos em ordem numérica:

1. `supabase/migrations/014_contact_messages.sql`
2. `supabase/migrations/015_verify_contact.sql`
3. `supabase/migrations/016_member_dashboard.sql`
4. `supabase/migrations/017_verify_member_dashboard.sql`
5. `supabase/migrations/018_lock_member_context.sql`
6. `supabase/migrations/019_verify_member_context_lock.sql`
7. `supabase/migrations/020_people_access.sql`
8. `supabase/migrations/021_verify_people_access.sql`
9. `supabase/migrations/022_lock_people_access.sql`
10. `supabase/migrations/023_verify_people_access_lock.sql`
11. `supabase/migrations/024_community_management.sql`
12. `supabase/migrations/025_verify_community_management.sql`
13. `supabase/migrations/026_community_admin_visibility.sql`
14. `supabase/migrations/027_verify_community_admin_visibility.sql`
15. `supabase/migrations/028_community_member_feed.sql`
16. `supabase/migrations/029_verify_community_member_feed.sql`

O arquivo `014_contact_messages.sql` cria o canal público de contato com inserção anônima controlada e leitura restrita à equipe com a permissão `support.manage`.

O arquivo `015_verify_contact.sql` é somente leitura e deve confirmar `table_exists`, `anon_can_insert`, `authenticated_can_select` e `authenticated_can_update` como `true`.

O arquivo `016_member_dashboard.sql` cria a função segura `get_my_app_context()`. Ela fornece somente os dados da pessoa autenticada, seu vínculo, papéis, permissões e contadores necessários para a área da membro e o painel administrativo.

O arquivo `017_verify_member_dashboard.sql` verifica a função inicial. Caso `anonymous_cannot_execute` retorne `false`, execute obrigatoriamente os arquivos `018` e `019`.

O arquivo `018_lock_member_context.sql` remove explicitamente a permissão de execução dos papéis `PUBLIC` e `anon` e mantém a execução somente para `authenticated`.

O arquivo `019_verify_member_context_lock.sql` deve retornar todos os campos como `true`, incluindo `anonymous_cannot_execute`.

O arquivo `020_people_access.sql` cria atualização de membros e papéis, convites, aceite autenticado, proteção da última administradora e auditoria.

O arquivo `021_verify_people_access.sql` faz a primeira conferência. Caso permissões anônimas indevidas sejam encontradas, execute os arquivos `022` e `023`.

O arquivo `022_lock_people_access.sql` revoga de `PUBLIC` e `anon` as funções administrativas e concede novamente somente ao papel `authenticated`.

O arquivo `023_verify_people_access_lock.sql` foi validado com todos os 14 campos retornando `true` em 28/06/2026.

## Comunidade

O arquivo `024_community_management.sql` cria:

- moderação auditável de publicação, comentário ou perfil;
- ocultação, remoção e restauração de conteúdo;
- advertência, silêncio temporário, suspensão e banimento;
- resolução ou descarte de denúncia;
- reação segura com alternância de estado;
- bloqueio explícito de execução anônima das funções protegidas.

O arquivo `025_verify_community_management.sql` deve retornar todos os campos como `true`.

O arquivo `026_community_admin_visibility.sql` ajusta as policies de leitura para que administradoras e moderadoras possam visualizar rascunhos, conteúdo oculto e conteúdo denunciado, sem ampliar o acesso público.

O arquivo `027_verify_community_admin_visibility.sql` deve retornar:

- `community_spaces_read_policy_ok = true`;
- `community_posts_read_policy_ok = true`;
- `community_comments_read_policy_ok = true`.

O arquivo `028_community_member_feed.sql` cria o feed seguro da comunidade com dados públicos limitados das autoras, comentários, contagens de reações e reações da pessoa conectada. Também impede novas publicações e comentários durante suspensão comunitária ativa.

O arquivo `029_verify_community_member_feed.sql` deve retornar todos os campos como `true`, incluindo bloqueio anônimo das funções e presença das policies de inserção.

## Primeira administradora

A primeira administradora foi promovida com sucesso para a conta `cafedeeducadoras@gmail.com`, com os papéis `admin` e `membro`.

O procedimento auditável permanece disponível em `supabase/manual/promote_first_admin.sql` para recuperação controlada ou instalação em outro ambiente.

## Interrupção obrigatória em caso de erro

Se qualquer arquivo retornar erro:

1. não execute o arquivo seguinte;
2. copie a mensagem completa do erro;
3. registre qual arquivo estava sendo executado;
4. envie a mensagem para análise antes de tentar uma correção manual.

Não desative RLS e não remova constraints para contornar erros.

## Configurações operacionais

Depois das migrations:

1. manter as URLs do Supabase Auth alinhadas ao domínio de produção;
2. manter somente a chave pública no frontend;
3. nunca expor `service_role`, segredo JWT ou senha do banco;
4. testar cadastro, confirmação de e-mail, login, logout e recuperação;
5. testar o formulário público de contato;
6. testar a área da membro em smartphone e desktop;
7. validar que pessoas sem permissão não entram em `/admin/`;
8. criar um convite de teste e concluir o fluxo em `/aceite-convite`;
9. criar um espaço de comunidade e publicar uma conversa de teste;
10. testar denúncia, moderação, suspensão e restauração com uma conta secundária;
11. revisar periodicamente logs, RLS e dependências.
