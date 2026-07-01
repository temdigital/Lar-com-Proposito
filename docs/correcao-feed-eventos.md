# Correção do feed de eventos da área da membro

## Causa do erro

O arquivo `035_member_events_feed.sql` dependia da tabela `public.event_private_details` e de campos de controle de acesso que ainda não existiam no banco.

## Sequência corrigida

Execute em ordem:

1. `supabase/migrations/034_event_private_access.sql`
2. `supabase/migrations/035_member_events_feed.sql`
3. `supabase/migrations/036_verify_member_events_feed.sql`

O arquivo `034`:

- cria os campos de acesso e inscrição usados pelo feed;
- cria a tabela protegida `event_private_details`;
- migra links de reunião já cadastrados;
- limpa os links da tabela pública de eventos;
- instala triggers para que novos links continuem sendo armazenados somente na tabela protegida;
- revoga a leitura direta da tabela protegida para `anon` e `authenticated`.

O arquivo `035` cria a função autenticada `get_member_events(boolean)`. O link da reunião e as instruções só são retornados para inscrições confirmadas ou com presença registrada.

O arquivo `036` deve retornar todos os campos como `true`.

## Regra de interrupção

Caso o arquivo `034` ou `035` apresente erro, não execute o arquivo seguinte. Copie a mensagem completa para análise.
