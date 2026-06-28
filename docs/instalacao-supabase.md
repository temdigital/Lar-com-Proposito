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

O arquivo `014_contact_messages.sql` cria o canal público de contato com inserção anônima controlada e leitura restrita à equipe com a permissão `support.manage`.

O arquivo `015_verify_contact.sql` é somente leitura e deve confirmar:

- `table_exists = true`;
- `policy_count = 3`;
- `anon_can_insert = true`;
- `staff_privileges_available = true`.

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
6. revisar periodicamente logs, RLS e dependências.
