# Continuidade do projeto Lar com Propósito

Atualizado em 1º de julho de 2026.

## Fonte de verdade

- Repositório: `temdigital/Lar-com-Proposito`
- Branch de produção: `main`
- Frontend: HTML, CSS e JavaScript modular
- Backend: Supabase
- Deploy: Vercel
- Prioridade: mobile-first

## Identidade visual permanente

Preservar a identidade já implantada: símbolo de dois arcos orgânicos com ponto terracota, nome em Parisienne, subtítulo vinho e paleta Altar Doméstico.

Cores principais:

- Creme Eucaristia `#F9F6F0`
- Dourado Sacro `#C9A84C`
- Terracota Tijolo `#B65C3D`
- Verde Esperança `#4A6B53`
- Vinho Profundo `#5E1F2D`

Não reinterpretar ou substituir a marca sem autorização expressa.

## Estado do banco

A fundação foi instalada até a migration `013`. As evoluções de `014` a `038` foram executadas e validadas, abrangendo:

- contato público;
- dashboard da membro;
- contexto autenticado;
- pessoas, papéis e convites;
- comunidade e moderação;
- conteúdo editorial;
- eventos e inscrições;
- atendimento e privacidade.

## Módulos implementados

- Site institucional e páginas legais
- Cadastro, login e recuperação de senha
- Área da membro
- Painel administrativo
- Cursos, módulos, aulas e progresso
- Pessoas, acessos e convites
- Comunidade, feed, reações e moderação
- Conteúdo, categorias, SEO e favoritos
- Eventos, inscrições e lista de espera
- Atendimento, mensagens públicas e solicitações de privacidade

## Decisões permanentes

1. Manter RLS ativa.
2. Não expor credenciais privadas no frontend ou repositório.
3. Não recriar a página pública `/seguranca`.
4. Não exibir a URL técnica como selo, aviso ou conteúdo promocional.
5. Manter URLs técnicas somente onde forem necessárias ao funcionamento.
6. Verificar impacto em banco, funções, policies e rotas antes de alterar.
7. Não considerar pagamentos liberados antes da homologação completa.

## Limpeza visual de julho de 2026

O build foi ajustado para retirar da interface pública:

- aviso de endereço nas telas de autenticação;
- selo do endereço no rodapé;
- frase sobre conexão HTTPS no rodapé;
- card institucional dedicado à URL técnica.

O conteúdo da página inicial passou a destacar formação, comunidade e atendimento.

## Próxima etapa recomendada

Prosseguir com Clube e Assinaturas em modo de homologação, sem ativar cobrança real:

- gestão administrativa de planos;
- benefícios por plano;
- associação manual de assinatura;
- concessão de acesso por assinatura;
- testes completos antes de escolher e integrar o provedor de pagamento.

## Regra para o próximo chat

Use o documento de transferência completo entregue ao responsável como contexto principal. Antes de implementar, confira o estado atual da branch `main`, as migrations existentes e o último deploy.
