import { cp, copyFile, mkdir, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { extname, join } from 'node:path';

const root = process.cwd();
const output = join(root, 'dist');
const staticDirectories = ['app', 'admin', 'auth', 'public', 'src', '.well-known'];
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
      </div>
    </div>
  </footer>`;
}

function homeCareSection() {
  return `<section class="section trust-section" id="transparencia">
      <div class="container">
        <div class="trust-heading">
          <div>
            <p class="eyebrow">Cuidado em cada etapa</p>
            <h2>Uma plataforma organizada para servir à jornada completa.</h2>
          </div>
          <p>Formação, comunidade, conteúdos, eventos e atendimento são desenvolvidos de forma integrada para oferecer uma experiência acolhedora e funcional.</p>
        </div>
        <div class="trust-grid">
          <article class="trust-card">
            <span class="trust-icon" aria-hidden="true">✓</span>
            <h3>Formação organizada</h3>
            <p>Cursos, materiais e progresso reunidos em uma área pessoal simples de acompanhar.</p>
            <a href="/#jornada">Conhecer a jornada</a>
          </article>
          <article class="trust-card">
            <span class="trust-icon" aria-hidden="true">◌</span>
            <h3>Comunidade acompanhada</h3>
            <p>Espaços de troca com regras claras, moderação e cuidado com a convivência.</p>
            <a href="/#comunidade">Conhecer a comunidade</a>
          </article>
          <article class="trust-card">
            <span class="trust-icon" aria-hidden="true">?</span>
            <h3>Atendimento próximo</h3>
            <p>Dúvidas, suporte e solicitações de privacidade podem ser encaminhadas pelos canais do projeto.</p>
            <a href="/fale-conosco">Fale conosco</a>
          </article>
        </div>
      </div>
    </section>`;
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

  if (fileName === 'index.html') {
    html = html.replace(
      /<section class="section trust-section" id="transparencia">[\s\S]*?<\/section>/,
      homeCareSection()
    );
  }

  if (fileName === 'sobre.html') {
    html = html.replace(
      /<div class="notice"><strong>Transparência:<\/strong>[\s\S]*?<\/div>/,
      '<div class="notice"><strong>Compromisso:</strong> o desenvolvimento avança por etapas, com revisão de conteúdo, usabilidade, privacidade e funcionamento antes de cada liberação.</div>'
    );
  }

  html = html
    .replaceAll('/seguranca.html', '/#transparencia')
    .replaceAll('/seguranca', '/#transparencia')
    .replaceAll('Ver orientações de segurança', 'Conhecer o projeto');

  await writeFile(filePath, html, 'utf8');
}

const authScriptPath = join(output, 'src', 'js', 'auth-page.js');
let authScript = await readFile(authScriptPath, 'utf8');
authScript = authScript
  .replace(/function insertOfficialAddressNote\(\) \{[\s\S]*?\n\}/, '')
  .replace(/\ninsertOfficialAddressNote\(\);/, '');
await writeFile(authScriptPath, authScript, 'utf8');

const globalStylePath = join(output, 'src', 'styles', 'global.css');
let globalStyle = await readFile(globalStylePath, 'utf8');
globalStyle = globalStyle
  .replace(/\.official-address \{[\s\S]*?\n\}/, '')
  .replace(/\.official-address::before \{[\s\S]*?\n\}/, '');
await writeFile(globalStylePath, globalStyle, 'utf8');

const authStylePath = join(output, 'src', 'styles', 'auth.css');
let authStyle = await readFile(authStylePath, 'utf8');
authStyle = authStyle.replace(/\.auth-security-note\{[\s\S]*?\}(?=\.auth-form)/, '');
await writeFile(authStylePath, authStyle, 'utf8');

const forbiddenVisiblePhrases = [
  'Endereço oficial nesta fase',
  'Conexão protegida por HTTPS.',
  'class="official-address"',
  'insertOfficialAddressNote()'
];

for (const relativePath of [
  'index.html', 'sobre.html', 'fale-conosco.html', 'termos.html',
  'privacidade.html', 'cookies.html', 'src/js/auth-page.js'
]) {
  const content = await readFile(join(output, relativePath), 'utf8');
  for (const phrase of forbiddenVisiblePhrases) {
    if (content.includes(phrase)) {
      throw new Error(`Conteúdo visual obsoleto encontrado em ${relativePath}: ${phrase}`);
    }
  }
}

console.log('Build concluído com áreas pública, membro e administrativa.');
