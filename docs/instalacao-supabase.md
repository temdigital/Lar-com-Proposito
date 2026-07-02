# Instalação e evolução do Supabase

## Fundação instalada

A fundação do projeto foi executada e validada pelos arquivos de `002_base.sql` até `013_verify_installation.sql`.

O ambiente consolidado possui autenticação, perfis, organização, papéis, permissões, cursos, comunidade, conteúdo, eventos, assinaturas, atendimento, armazenamento e auditoria com RLS ativa.

## Migrations posteriores

Execute sempre em ordem numérica:

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

As migrations até `042` foram executadas e validadas no ambiente. Os arquivos `040` e `042` retornaram todos os campos como `true`.

## Pessoas e acessos

Os arquivos `020` a `023` criam e protegem convites, papéis, atualização de membros e aceite autenticado. O arquivo `023` deve retornar todos os campos como `true`.

## Comunidade

Os arquivos `024` a `029` implementam espaços, feed seguro, reações, denúncias, moderação, suspensão e visibilidade administrativa. Os verificadores devem retornar todos os campos como `true`.

## Conteúdo

Os arquivos `030` e `031` implementam categorias, editor, rascunho, revisão, publicação, arquivamento, destaque e SEO. O arquivo `031` deve retornar todos os campos como `true`.

## Eventos

Os arquivos `032` e `033` implementam eventos e inscrições.

O arquivo `034` separa links e instruções privadas da tabela pública. O arquivo `035` cria o feed autenticado e o `036` verifica a proteção. Todos os campos do `036` devem retornar `true`.

## Atendimento e privacidade

O arquivo `037_support_center.sql` implementa:

- chamados com protocolo automático;
- respostas da membro e da equipe;
- notas internas invisíveis para a titular;
- situação, prioridade e responsável;
- fila das mensagens públicas;
- solicitações de privacidade com protocolo;
- análise e decisão auditáveis;
- notificações internas após resposta da equipe;
- bloqueio de escrita direta nas tabelas sensíveis;
- funções executáveis somente por pessoa autenticada.

O arquivo `038_verify_support_center.sql` deve retornar todos os campos como `true`, incluindo existência das funções, bloqueio anônimo, bloqueio de escrita direta e proteção das notas internas.

## Clube e assinaturas em homologação

O arquivo `039_club_subscriptions_homologation.sql` implementa, sem ativar cobrança real:

- tabela protegida de regras de acesso por plano;
- gestão de planos e benefícios por função SQL auditável;
- associação manual de assinaturas para testes;
- concessão e revogação de `access_grants` por assinatura;
- reconciliação de períodos expirados;
- bloqueio de escrita direta nas tabelas críticas do módulo.

O arquivo `040_verify_club_subscriptions_homologation.sql` validou a estrutura principal. O resultado inicial identificou que o papel `anon` ainda possuía privilégio efetivo de execução nas funções do módulo.

O arquivo `041_lock_club_function_privileges.sql` corrige esse ponto ao:

- revogar `EXECUTE` de `PUBLIC`, `anon` e `authenticated` nas cinco funções;
- devolver `EXECUTE` somente a `authenticated` nas quatro funções administrativas;
- manter `sync_subscription_access(uuid)` inacessível diretamente pelo frontend.

O arquivo `042_verify_club_function_privileges.sql` confirmou todos os dez controles como `true`.

Esta etapa não implementa checkout, provedor de pagamento, renovação automática, reembolso, chargeback ou webhook financeiro.

## Primeira administradora

A conta `cafedeeducadoras@gmail.com` foi promovida com os papéis `admin` e `membro`.

O procedimento auditável permanece em `supabase/manual/promote_first_admin.sql`.

## Regra de interrupção

Se qualquer migration retornar erro:

1. não execute o arquivo seguinte;
2. copie a mensagem completa;
3. registre o nome do arquivo;
4. envie o erro para análise antes de fazer correções manuais.

Não desative RLS, não remova constraints e não conceda acesso direto para contornar falhas.

## Testes operacionais

Após concluir as migrations:

1. testar cadastro, confirmação, login, logout e recuperação de senha;
2. testar a área da membro em smartphone e desktop;
3. validar que pessoas sem permissão não acessam `/admin/`;
4. testar convite, comunidade, conteúdo e eventos com uma conta secundária;
5. abrir um chamado como membro e responder pelo painel;
6. confirmar que uma nota interna não aparece para a titular;
7. registrar e concluir uma solicitação de privacidade;
8. criar um plano de homologação com benefícios;
9. associar uma assinatura manual a uma conta secundária;
10. confirmar a criação do acesso geral ao clube e dos recursos associados;
11. pausar ou expirar a assinatura e confirmar a revogação dos acessos;
12. revisar `subscription_events`, `audit_logs` e os resultados de `supabase/manual/verify_club_operational_homologation.sql`;
13. validar o fluxo em smartphone e desktop, sem erros críticos no console.
