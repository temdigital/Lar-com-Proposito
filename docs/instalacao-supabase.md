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

O arquivo `014_contact_messages.sql` cria o canal público de contato com inserção anônima controlada e leitura restrita à equipe com a permissão `support.manage`.

O arquivo `015_verify_contact.sql` é somente leitura e deve confirmar:

- `table_exists = true`;
- `policy_count = 3`;
- `anon_can_insert = true`;
- `authenticated_can_select = true`;
- `authenticated_can_update = true`.

O arquivo `016_member_dashboard.sql` cria a função segura `get_my_app_context()`. Ela fornece somente os dados da pessoa autenticada, seu vínculo, papéis, permissões e contadores necessários para a área da membro e o painel administrativo.

O arquivo `017_verify_member_dashboard.sql` verifica a função inicial. Caso `anonymous_cannot_execute` retorne `false`, execute obrigatoriamente os arquivos `018` e `019`.

O arquivo `018_lock_member_context.sql` remove explicitamente a permissão de execução dos papéis `PUBLIC` e `anon` e mantém a execução somente para `authenticated`.

O arquivo `019_verify_member_context_lock.sql` deve retornar:

- `context_function_exists = true`;
- `authenticated_can_execute = true`;
- `anonymous_can_execute = false`;
- `anonymous_cannot_execute = true`.

O arquivo `020_people_access.sql` cria as operações protegidas do módulo Pessoas e acessos:

- atualização de membro, vínculo e papéis;
- proteção contra autossuspensão e remoção da última administradora;
- criação e revogação de convites;
- token armazenado somente como hash;
- visualização segura do convite;
- aceite autenticado com conferência do e-mail;
- registro das operações em `audit_logs`.

O arquivo `021_verify_people_access.sql` faz a primeira conferência. Caso `anonymous_cannot_update_member` ou `anonymous_cannot_create_invitation` retorne `false`, execute obrigatoriamente os arquivos `022` e `023`.

O arquivo `022_lock_people_access.sql` revoga explicitamente de `PUBLIC` e `anon` a execução das funções administrativas e concede novamente apenas ao papel `authenticated`. A função pública de prévia do convite permanece acessível ao visitante, pois ela somente valida o token e retorna dados limitados do convite.

O arquivo `023_verify_people_access_lock.sql` deve retornar todos os campos como `true`, inclusive:

- `authenticated_can_update_member`;
- `authenticated_can_create_invitation`;
- `authenticated_can_revoke_invitation`;
- `authenticated_can_accept_invitation`;
- `anonymous_cannot_update_member`;
- `anonymous_cannot_create_invitation`;
- `anonymous_cannot_revoke_invitation`;
- `anonymous_cannot_accept_invitation`;
- `anonymous_can_preview_invitation`.

## Primeira administradora

A primeira administradora foi promovida com sucesso para a conta `cafedeeducadoras@gmail.com`, com os papéis `admin` e `membro`.

O procedimento auditável permanece disponível em `supabase/manual/promote_first_admin.sql` para recuperação controlada ou instalação em outro ambiente. O script é idempotente, mantém o vínculo organizacional ativo, atribui os dois papéis e registra a promoção em `audit_logs`.

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
9. testar suspensão, reativação e troca de papéis com uma conta secundária;
10. revisar periodicamente logs, RLS e dependências.
