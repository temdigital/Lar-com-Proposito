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

A migration revoga `INSERT`, `UPDATE` e `DELETE` diretos do papel `authenticated` nas tabelas críticas do módulo. As alterações devem passar pelas funções auditáveis. As policies de leitura existentes são preservadas.

### Rotas e módulos

- Administração: `/admin/#financeiro`
- Área da membro: `/app/clube.html`

Nenhuma rota `/seguranca` foi criada. Nenhuma URL técnica é apresentada como selo ou aviso.

## Ordem de instalação

1. Execute `supabase/migrations/039_club_subscriptions_homologation.sql`.
2. Confirme a mensagem de sucesso.
3. Execute `supabase/migrations/040_verify_club_subscriptions_homologation.sql`.
4. Confirme que todos os campos retornam `true`.

Interrompa se houver qualquer erro. Não desative RLS, não remova constraints e não conceda escrita direta para contornar falhas.

## Roteiro mínimo de homologação

1. Entre como administradora.
2. Abra **Clube** no painel administrativo.
3. Crie um plano em rascunho, com benefícios e pelo menos um recurso associado.
4. Ative o plano e confirme sua exibição em `/app/clube.html`.
5. Use uma conta secundária de membro ativa.
6. Associe uma assinatura manual com término futuro.
7. Confirme os registros ativos em `access_grants`.
8. Acesse o sistema com a conta secundária e valide a situação da assinatura.
9. Pause a assinatura e confirme a revogação dos acessos.
10. Reative com novo período e confirme a nova concessão.
11. Defina término curto, execute a reconciliação e confirme status `expired` e acessos revogados.
12. Revise os eventos em `subscription_events` e as ações em `audit_logs`.

## Fora do escopo

- checkout;
- cobrança real;
- provedor de pagamento;
- webhooks financeiros;
- renovação automática;
- reembolso e chargeback;
- conciliação financeira.
