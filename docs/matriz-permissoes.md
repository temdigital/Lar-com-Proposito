# Matriz inicial de permissões

## Papéis administrativos

- `superadmin`: função técnica global, controlada também por `profiles.eh_superadministrador`.
- `admin`: administração integral da própria organização.
- `instrutora`: gestão dos cursos aos quais está vinculada.
- `moderadora`: moderação dos espaços autorizados.
- `atendimento`: suporte operacional com acesso limitado.
- `membro`: consumo de recursos liberados por matrícula, assinatura ou concessão.

## Matriz

| Recurso | Superadmin | Admin | Instrutora | Moderadora | Atendimento | Membro |
|---|---|---|---|---|---|---|
| Organizações | Global | Própria | Não | Não | Não | Não |
| Usuárias | Global | Própria organização | Alunas autorizadas | Dados mínimos | Dados mínimos | Próprio perfil |
| Cursos | Global | Total na organização | Atribuídos | Leitura permitida | Leitura de suporte | Com acesso ativo |
| Aulas e materiais | Global | Total | Atribuídos | Não | Leitura de suporte | Com acesso ativo |
| Progresso | Global | Relatórios | Cursos atribuídos | Não | Consulta limitada | Próprio |
| Comunidade | Global | Total | Participação | Moderação atribuída | Consulta limitada | Espaços autorizados |
| Assinaturas | Global | Gestão | Não | Não | Consulta limitada | Própria |
| Pagamentos | Global | Gestão | Não | Não | Consulta limitada | Próprios |
| Conteúdo público | Global | Gestão | Conforme atribuição | Não | Não | Leitura |
| LGPD | Global | Gestão | Não | Não | Triagem | Próprias solicitações |
| Logs | Global | Operacionais | Próprias ações | Próprias ações | Não | Não |

## Regra de implementação

Papéis definem capacidade administrativa. Matrículas, assinaturas e `access_grants` definem consumo. As policies RLS devem validar organização, propriedade, papel e acesso ativo diretamente no banco.
