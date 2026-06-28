const body = document.body;
const header = document.querySelector('[data-header]');
const menuButton = document.querySelector('[data-menu-button]');
const menu = document.querySelector('[data-menu]');
const yearElements = document.querySelectorAll('[data-current-year]');
const cookieBanner = document.querySelector('[data-cookie-banner]');
const cookieAccept = document.querySelector('[data-cookie-accept]');
const cookieReject = document.querySelector('[data-cookie-reject]');
const desktopNavigation = window.matchMedia('(min-width: 1040px)');

function updateMenuButtonLabel(isOpen) {
  const label = menuButton?.querySelector('.sr-only');
  if (label) label.textContent = isOpen ? 'Fechar menu' : 'Abrir menu';
}

function closeMenu({ returnFocus = false } = {}) {
  if (!menuButton || !menu) return;
  menuButton.setAttribute('aria-expanded', 'false');
  menu.classList.remove('is-open');
  body.classList.remove('menu-open');
  updateMenuButtonLabel(false);

  if (!desktopNavigation.matches) {
    menu.setAttribute('aria-hidden', 'true');
  }

  if (returnFocus) menuButton.focus();
}

function openMenu() {
  if (!menuButton || !menu || desktopNavigation.matches) return;
  menuButton.setAttribute('aria-expanded', 'true');
  menu.classList.add('is-open');
  menu.setAttribute('aria-hidden', 'false');
  body.classList.add('menu-open');
  updateMenuButtonLabel(true);

  window.requestAnimationFrame(() => {
    menu.querySelector('a')?.focus();
  });
}

function toggleMenu() {
  const isOpen = menuButton?.getAttribute('aria-expanded') === 'true';
  if (isOpen) closeMenu();
  else openMenu();
}

function syncNavigationMode() {
  if (!menuButton || !menu) return;

  if (desktopNavigation.matches) {
    menuButton.setAttribute('aria-expanded', 'false');
    menu.classList.remove('is-open');
    menu.removeAttribute('aria-hidden');
    body.classList.remove('menu-open');
    updateMenuButtonLabel(false);
    return;
  }

  const isOpen = menuButton.getAttribute('aria-expanded') === 'true';
  menu.setAttribute('aria-hidden', String(!isOpen));
}

function updateHeader() {
  header?.classList.toggle('is-scrolled', window.scrollY > 12);
}

function saveCookiePreference(value) {
  localStorage.setItem('lar-com-proposito:cookie-consent', value);
  if (cookieBanner) cookieBanner.hidden = true;
}

menuButton?.addEventListener('click', toggleMenu);
menu?.querySelectorAll('a').forEach((link) => {
  link.addEventListener('click', () => closeMenu());
});

desktopNavigation.addEventListener('change', syncNavigationMode);
window.addEventListener('scroll', updateHeader, { passive: true });

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && menuButton?.getAttribute('aria-expanded') === 'true') {
    closeMenu({ returnFocus: true });
  }
});

document.addEventListener('click', (event) => {
  if (desktopNavigation.matches || menuButton?.getAttribute('aria-expanded') !== 'true') return;
  if (header?.contains(event.target)) return;
  closeMenu();
});

yearElements.forEach((element) => {
  element.textContent = String(new Date().getFullYear());
});

syncNavigationMode();
updateHeader();

const cookiePreference = localStorage.getItem('lar-com-proposito:cookie-consent');
if (cookieBanner && !cookiePreference) cookieBanner.hidden = false;
cookieAccept?.addEventListener('click', () => saveCookiePreference('accepted'));
cookieReject?.addEventListener('click', () => saveCookiePreference('necessary-only'));
