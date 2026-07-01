# Módulo Atendimento

## Endereços

- Administração: `/admin/#atendimento`
- Área da membro: `/app/atendimento.html`
- Formulário público: `/fale-conosco`

## Escopo administrativo

A central reúne três filas:

1. chamados abertos por membros;
2. mensagens recebidas pelo formulário público;
3. solicitações de privacidade e proteção de dados.

A equipe autorizada pode pesquisar, filtrar, assumir registros, alterar situação e prioridade, responder chamados, criar notas internas e registrar decisões de privacidade.

## Área da membro

A pessoa autenticada pode:

- abrir chamado com protocolo automático;
- acompanhar situação e histórico;
- responder à equipe;
- registrar solicitação de acesso, correção, exclusão, anonimização, portabilidade ou revogação de consentimento;
- consultar decisão e andamento de solicitações próprias.

## Segurança

O arquivo `037_support_center.sql`:

- cria as funções protegidas de abertura, resposta e gestão;
- impede escrita direta nas tabelas sensíveis;
- oculta notas internas das titulares dos chamados;
- registra ações em `audit_logs`;
- cria notificações internas quando a equipe responde;
- restringe execução ao papel autenticado;
- exige `support.manage` ou `privacy.manage` nas operações administrativas.

Execute em ordem:

1. `supabase/migrations/037_support_center.sql`
2. `supabase/migrations/038_verify_support_center.sql`

O primeiro arquivo deve retornar `Success. No rows returned`.

O verificador deve retornar todos os campos como `true`.

## Teste recomendado

1. abrir um chamado com uma conta de membro;
2. responder pelo painel administrativo;
3. confirmar que a resposta aparece para a membro;
4. criar uma nota interna e confirmar que ela não aparece para a membro;
5. registrar uma solicitação de privacidade;
6. concluir a análise pelo painel e conferir a decisão na conta da titular.
