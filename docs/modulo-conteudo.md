# Módulo Conteúdo

## Escopo implementado

O módulo editorial está disponível no painel administrativo em `/admin/#conteudo` e na área da membro em `/app/#conteudos`.

### Administração

- categorias com nome, endereço amigável e descrição;
- publicações em rascunho, revisão, publicadas ou arquivadas;
- editor formatado com títulos, listas, citações, links, negrito e itálico;
- resumo, capa, categoria, destaque e conteúdo exclusivo para membros;
- campos de título e descrição para mecanismos de busca;
- pré-visualização antes de salvar;
- envio de capa para o bucket público autorizado;
- pesquisa e filtros por situação e categoria;
- auditoria de criação, alteração, arquivamento e exclusão de categoria.

### Área da membro

- listagem somente de publicações permitidas pelas policies RLS;
- pesquisa por título, resumo e categoria;
- filtro por categoria;
- leitura completa em janela responsiva;
- favoritos vinculados à conta autenticada;
- tratamento seguro do HTML antes da exibição.

## Instalação no Supabase

Execute em ordem:

1. `supabase/migrations/030_content_management.sql`
2. `supabase/migrations/031_verify_content_management.sql`

O primeiro arquivo deve retornar `Success. No rows returned`.

O verificador deve retornar todos os campos como `true`, incluindo a existência das quatro funções, as permissões do papel autenticado, o bloqueio do papel anônimo e as novas colunas editoriais.

## Segurança

As operações de escrita usam funções `security definer`, validam a organização e exigem a permissão `content.manage`. As funções são explicitamente revogadas de `PUBLIC` e `anon`. A leitura continua subordinada às policies existentes de conteúdo público, conteúdo para membros e acesso administrativo.
