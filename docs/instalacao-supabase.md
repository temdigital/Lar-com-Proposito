# Instalação inicial do Supabase

## Situação auditada

Na auditoria de 27/06/2026, o schema `public` estava vazio, o Auth não possuía usuários e nenhum bucket da aplicação estava criado.

## Ordem obrigatória

No SQL Editor do Supabase, execute cada arquivo por inteiro e aguarde a mensagem de sucesso antes de seguir:

1. `supabase/migrations/002_base.sql`
2. `supabase/migrations/003_auth_profiles.sql`
3. `supabase/migrations/004_roles_permissions.sql`
4. `supabase/migrations/005_courses.sql`
5. `supabase/migrations/006_commerce_subscriptions.sql`
6. `supabase/migrations/007_community.sql`
7. `supabase/migrations/008_content_support.sql`
8. `supabase/migrations/009_security_functions.sql`
9. `supabase/migrations/010_rls.sql`
10. `supabase/migrations/011_storage.sql`
11. `supabase/migrations/012_seed_core.sql`
12. `supabase/migrations/012b_seed_permissions.sql`
13. `supabase/migrations/012c_instructor_access.sql`
14. `supabase/migrations/012d_default_membership.sql`
15. `supabase/migrations/013_verify_installation.sql`

Os arquivos `001_audit.sql` e `001b_audit_consolidated.sql` são apenas de auditoria e não precisam ser executados novamente durante a instalação.

## Interrupção obrigatória em caso de erro

Se qualquer arquivo retornar erro:

1. não execute o arquivo seguinte;
2. copie a mensagem completa do erro;
3. registre qual arquivo estava sendo executado;
4. envie a mensagem para análise antes de tentar uma correção manual.

Não desative RLS e não remova constraints para contornar erros.

## Resultado esperado

O arquivo `013_verify_installation.sql` deve retornar `OK` para:

- tabelas públicas;
- policies RLS;
- organização principal;
- cinco papéis oficiais;
- trinta permissões;
- seis buckets;
- triggers de criação e atualização de usuários.

## Etapas posteriores

Depois da instalação:

1. configurar as URLs do Supabase Auth;
2. informar a chave pública do projeto no frontend;
3. criar a primeira conta;
4. promover essa conta para administradora por SQL controlado;
5. testar cadastro, confirmação de e-mail, login, logout e isolamento RLS.
