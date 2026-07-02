# Módulo Clube e Assinaturas — homologação

## Objetivo

Validar a gestão de planos, benefícios, assinaturas e acessos sem iniciar cobrança real. O módulo foi desenhado para testar o ciclo funcional antes da escolha de um provedor de pagamento.

## Impacto revisado antes da implementação

### Tabelas existentes consultadas

- `organizations` e `organization_members` para contexto e isolamento;
- `profiles` para associação da membro;
- `plans` e `plan_features` para apresentação dos planos;
- `subscriptions` e `subscription_events` para histórico da assinatura;
- `access_grants` para liberação e revogação;
- `audit_logs` para rastreabilidade;
- `courses`, `community_spaces`, `content_posts` e `events` para recursos vinculados.

### Nova tabela

`plan_access_rules` relaciona cada plano a cursos, espaços da comunidade, conteúdos ou eventos. A tabela possui RLS e leitura administrativa condicionada a permissões.

### Funções protegidas

- `save_club_plan(...)`
- `assign_manual_subscription(...)`
- `manage_manual_subscription(...)`
- `reconcile_manual_subscriptions()`

A função interna `sync_subscription_access(uuid)` não é executável por `anon` ou pelo frontend autenticado. Ela é chamada pelas funções administrativas, que validam organização e permissões.

### Escrita direta bloqueada

As migrations revogam `INSERT`, `UPDATE` e `DELETE` diretos do papel `authenticated` nas tabelas críticas do módulo. As alterações devem passar pelas funções auditáveis. As policies de leitura existentes são preservadas.

### Rotas e módulos

- Administração: `/admin/#financeiro`
- Área da membro: `/app/clube.html`

Nenhuma rota `/seguranca` foi criada. Nenhuma URL técnica é apresentada como selo ou aviso.

## Ordem de instalação e validação

1. Execute `supabase/migrations/039_club_subscriptions_homologation.sql`.
2. Execute `supabase/migrations/040_verify_club_subscriptions_homologation.sql`.
3. Execute `supabase/migrations/041_lock_club_function_privileges.sql`.
4. Execute `supabase/migrations/042_verify_club_function_privileges.sql`.
5. Confirme que os verificadores `040` e `042` retornam todos os campos como `true`.

As migrations até `042` foram executadas e validadas no ambiente em 2 de julho de 2026.

Interrompa se houver qualquer erro. Não desative RLS, não remova constraints e não conceda escrita direta para contornar falhas.

## Roteiro mínimo de homologação operacional

1. Entre como administradora.
2. Abra **Clube** no painel administrativo.
3. Crie um plano em rascunho com nome, descrição, ciclo, valor de homologação e benefícios.
4. Vincule pelo menos um recurso real da organização: curso, conteúdo, espaço da comunidade ou evento.
5. Ative o plano e confirme sua exibição em `/app/clube.html`.
6. Use uma conta secundária de membro com vínculo ativo na organização.
7. Associe uma assinatura manual com início atual e término futuro.
8. Confirme os registros ativos em `access_grants`: um acesso geral `club` e os recursos vinculados.
9. Acesse o sistema com a conta secundária e valide a situação da assinatura e o acesso aos recursos.
10. Pause a assinatura e confirme a revogação dos acessos.
11. Reative com novo período e confirme a nova concessão.
12. Defina término curto, aguarde o vencimento, execute a reconciliação e confirme status `expired` e acessos revogados.
13. Teste também o cancelamento manual e confirme a revogação imediata.
14. Revise os eventos em `subscription_events` e as ações em `audit_logs`.
15. Execute `supabase/manual/verify_club_operational_homologation.sql` e guarde os resultados como evidência.
16. Repita a validação em smartphone e desktop e confirme ausência de erros críticos no console.

## Critérios de aprovação

A homologação funcional somente será considerada aprovada quando:

- o plano ativo aparecer corretamente para a membro;
- a assinatura manual gerar acesso geral ao clube;
- cada recurso vinculado gerar um `access_grant` ativo;
- uma membro sem assinatura não receber os acessos;
- pausa, cancelamento e expiração revogarem os acessos;
- reativação com período futuro restaurar os acessos;
- `subscription_events` registrar cada mudança;
- `audit_logs` registrar criação, associação, alteração e reconciliação;
- o painel administrativo respeitar `billing.manage` e `access.manage`;
- o fluxo funcionar em smartphone e desktop;
- não houver erro crítico no console nem exposição de controles administrativos.

## Fora do escopo

- checkout;
- cobrança real;
- provedor de pagamento;
- webhooks financeiros;
- renovação automática;
- reembolso e chargeback;
- conciliação financeira.
