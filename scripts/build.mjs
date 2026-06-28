import { cp, copyFile, mkdir, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { extname, join } from 'node:path';

const root = process.cwd();
const output = join(root, 'dist');
const staticDirectories = ['app', 'auth', 'public', 'src', '.well-known'];
const rootExtensions = new Set(['.html', '.xml', '.txt', '.webmanifest']);
const publicPages = new Map([
  ['index.html', 'home'],
  ['sobre.html', 'about'],
  ['fale-conosco.html', 'contact'],
  ['termos.html', 'terms'],
  ['privacidade.html', 'privacy'],
  ['cookies.html', 'cookies']
]);

function currentAttribute(current, item) {
  return current === item ? ' aria-current="page"' : '';
}

function publicMenu(current) {
  return `<nav class="main-nav" id="menu-principal" aria-label="Navegação principal" data-menu>
        <a href="/"${currentAttribute(current, 'home')}>Início</a>
        <a href="/#proposito">Propósito</a>
        <a href="/#jornada">Jornada</a>
        <a href="/#comunidade">Comunidade</a>
        <a href="/sobre"${currentAttribute(current, 'about')}>Sobre</a>
        <a href="/fale-conosco"${currentAttribute(current, 'contact')}>Contato</a>
        <a class="button button-small button-secondary" href="/login">Entrar</a>
        <a class="button button-small" href="/cadastro">Criar conta</a>
      </nav>`;
}

function publicFooter() {
  return `<footer class="site-footer">
    <div class="container">
      <div class="footer-grid">
        <div class="footer-brand-block">
          <strong class="footer-wordmark">Lar com Propósito</strong>
          <p>Mulheres que edificam com amor, presença, serviço e beleza no cotidiano.</p>
          <span class="official-address">lar-com-proposito.vercel.app</span>
        </div>
        <div>
          <strong class="footer-heading">Projeto</strong>
          <nav class="footer-links" aria-label="Links do projeto">
            <a href="/">Início</a>
            <a href="/sobre">Sobre</a>
            <a href="/#jornada">Jornada</a>
            <a href="/#comunidade">Comunidade</a>
            <a href="/fale-conosco">Contato</a>
          </nav>
        </div>
        <div>
          <strong class="footer-heading">Informações</strong>
          <nav class="footer-links" aria-label="Links legais">
            <a href="/termos">Termos de Uso</a>
            <a href="/privacidade">Privacidade</a>
            <a href="/cookies">Cookies</a>
          </nav>
        </div>
      </div>
      <div class="footer-bottom">
        <p>© <span data-current-year></span> Lar com Propósito.</p>
        <p>Conexão protegida por HTTPS.</p>
      </div>
    </div>
  </footer>`;
}

await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });

for (const entry of await readdir(root, { withFileTypes: true })) {
  if (entry.isFile() && rootExtensions.has(extname(entry.name))) {
    await copyFile(join(root, entry.name), join(output, entry.name));
  }
}

for (const directory of staticDirectories) {
  await cp(join(root, directory), join(output, directory), { recursive: true });
}

for (const [fileName, current] of publicPages) {
  const filePath = join(output, fileName);
  let html = await readFile(filePath, 'utf8');

  if (!html.includes('/src/styles/public-navigation.css')) {
    html = html.replace(
      '<link rel="stylesheet" href="/src/styles/global.css">',
      '<link rel="stylesheet" href="/src/styles/global.css">\n  <link rel="stylesheet" href="/src/styles/public-navigation.css">'
    );
  }

  html = html.replace(
    /<nav class="main-nav" id="menu-principal"[\s\S]*?<\/nav>/,
    publicMenu(current)
  );
  html = html.replace(
    /<footer class="site-footer">[\s\S]*?<\/footer>/,
    publicFooter()
  );
  html = html
    .replaceAll('/seguranca.html', '/#transparencia')
    .replaceAll('/seguranca', '/#transparencia')
    .replaceAll('Ver orientações de segurança', 'Conhecer o projeto');

  await writeFile(filePath, html, 'utf8');
}

console.log('Build concluído com navegação pública padronizada e prioridade mobile.');
