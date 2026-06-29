# Módulo Eventos

## Escopo implementado

O módulo de eventos está disponível no painel administrativo em `/admin/#eventos`.

Também foi criada uma página dedicada para membros em `/app/eventos.html`.

### Administração

- criação e edição de eventos;
- eventos online, presenciais ou híbridos;
- rascunho, publicação, cancelamento, conclusão e arquivamento;
- data e hora de início e fim;
- capacidade, preço e modo de inscrição;
- inscrição livre, por aprovação, paga ou fechada;
- prazo de inscrição;
- local, endereço físico e link de reunião;
- capa, destaque, título e descrição para busca;
- pesquisa e filtros por situação e tipo;
- contadores de publicados, rascunhos, próximos eventos e inscrições;
- auditoria de criação, alteração e arquivamento.

### Área da membro

- listagem de eventos publicados;
- filtro por tipo;
- pesquisa por título, descrição e local;
- visualização de detalhes;
- inscrição autenticada;
- lista de espera automática quando a capacidade estiver esgotada;
- status da inscrição exibido no card.

## Instalação no Supabase

Execute em ordem:

1. `supabase/migrations/032_events_management.sql`
2. `supabase/migrations/033_verify_events_management.sql`

O primeiro arquivo deve retornar `Success. No rows returned`.

O verificador deve retornar todos os campos como `true`.

## Segurança

As funções administrativas exigem a permissão `events.manage`. A inscrição exige autenticação e só aceita eventos publicados, com prazo e modo de inscrição válidos. As funções são explicitamente bloqueadas para o papel anônimo.
