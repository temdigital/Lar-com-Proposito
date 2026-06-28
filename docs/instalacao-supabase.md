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

## Primeira administradora

A promoção da primeira administradora não é uma migration automática. Depois de criar a conta e confirmar o e-mail:

1. abra `supabase/manual/promote_first_admin.sql`;
2. substitua todas as ocorrências de `ADMIN_EMAIL_AQUI` pelo e-mail exato da conta;
3. execute o arquivo inteiro no SQL Editor;
4. confira se o resultado mostra exatamente os papéis `admin` e `membro`.

O script é idempotente, mantém o vínculo organizacional ativo, atribui os dois papéis e registra a promoção em `audit_logs`. A execução é interrompida se a conta não existir ou ainda não estiver confirmada.

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
8. revisar periodicamente logs, RLS e dependências.
