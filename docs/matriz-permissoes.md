# Matriz inicial de permissões

## Papéis administrativos

- `superadmin`: função técnica global, controlada pela flag interna `profiles.is_superadmin`; não é um papel atribuível pelo painel comum.
- `admin`: administração integral da própria organização.
- `instrutora`: gestão dos cursos aos quais está vinculada.
- `moderadora`: moderação dos espaços e consulta das pessoas necessárias à atividade.
- `atendimento`: suporte operacional com acesso de leitura aos módulos necessários.
- `membro`: consumo de recursos liberados por matrícula, assinatura, convite ou concessão.

Uma pessoa pode acumular mais de um papel. O papel `membro` é preservado em todo vínculo ativo; os demais papéis acrescentam capacidades administrativas.

## Matriz

| Recurso | Superadmin | Admin | Instrutora | Moderadora | Atendimento | Membro |
|---|---|---|---|---|---|---|
| Organizações | Global | Própria | Não | Não | Não | Não |
| Pessoas e vínculos | Global | Gestão total | Não | Consulta | Consulta | Próprio perfil |
| Convites | Global | Criar e revogar | Não | Não | Não | Não |
| Papéis | Global | Atribuir papéis oficiais | Não | Não | Não | Não |
| Cursos | Global | Total na organização | Atribuídos | Não | Leitura | Com acesso ativo |
| Aulas e materiais | Global | Total | Atribuídos | Não | Leitura | Com acesso ativo |
| Matrículas e progresso | Global | Gestão e relatórios | Consulta dos cursos atribuídos | Não | Consulta | Próprio |
| Comunidade | Global | Total | Participação | Gestão e moderação | Não | Espaços autorizados |
| Assinaturas | Global | Gestão | Não | Não | Consulta | Própria |
| Pedidos e pagamentos | Global | Gestão | Não | Não | Consulta | Próprios |
| Conteúdo | Global | Gestão | Não | Não | Não | Conteúdo liberado |
| Eventos | Global | Gestão | Não | Não | Consulta | Eventos liberados |
| Atendimento | Global | Gestão | Não | Não | Gestão | Próprios chamados |
| LGPD | Global | Gestão | Não | Não | Não | Próprias solicitações |
| Logs | Global | Operacionais | Não | Não | Não | Não |

## Regras do módulo Pessoas e acessos

- uma administradora não pode suspender nem remover o próprio vínculo;
- uma administradora não pode retirar de si mesma o papel `admin`;
- a organização deve manter ao menos uma administradora ativa;
- remoções revogam os papéis, mas preservam histórico e auditoria;
- convites são associados ao e-mail exato e possuem validade de 1 a 30 dias;
- o token do convite é retornado somente na criação e armazenado no banco apenas como hash;
- o aceite exige sessão autenticada com o mesmo e-mail do convite;
- criação, revogação, aceite e alterações de acesso geram registros em `audit_logs`.

## Regra de implementação

Papéis definem capacidade administrativa. Matrículas, assinaturas e `access_grants` definem consumo. As policies RLS e as funções protegidas validam organização, propriedade, papel e acesso ativo diretamente no banco.
