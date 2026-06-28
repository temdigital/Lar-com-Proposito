# Lar com Propósito

Plataforma digital **Lar com Propósito | Mulheres que edificam com amor**.

## Stack

- HTML5, CSS3 e JavaScript modular;
- Supabase Auth, PostgreSQL e Storage;
- Vercel para deploy e funções públicas de configuração;
- GitHub para versionamento.

## Produção

Endereço oficial nesta fase:

`https://lar-com-proposito.vercel.app`

## Recursos implementados

- página institucional responsiva;
- navegação pública padronizada com prioridade mobile;
- logotipo tipográfico cursivo com conceito visual Altar Doméstico;
- cadastro, confirmação de e-mail, login e recuperação de senha;
- área inicial protegida da membro;
- páginas Sobre, Fale conosco, Termos, Privacidade e Cookies;
- formulário público de contato protegido por RLS;
- robots.txt, sitemap.xml, security.txt e página 404;
- banco multi-organização com cursos, comunidade, assinaturas, conteúdo, suporte e auditoria.

## Banco de dados

A fundação foi instalada até `013_verify_installation.sql`.

Migrations posteriores:

1. `014_contact_messages.sql`
2. `015_verify_contact.sql`

Consulte `docs/instalacao-supabase.md` antes de executar novos arquivos.

## Segurança

Nunca adicionar ao repositório:

- chave `service_role`;
- senha do banco;
- segredo JWT;
- credenciais privadas de pagamento;
- tokens OAuth privados.

A chave publishable do Supabase é pública e é fornecida ao frontend pela Vercel.
