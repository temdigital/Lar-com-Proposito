const body = document.body;
const header = document.querySelector('[data-header]');
const menuButton = document.querySelector('[data-menu-button]');
const menu = document.querySelector('[data-menu]');
const year = document.querySelector('[data-current-year]');
const cookieBanner = document.querySelector('[data-cookie-banner]');
const cookieAccept = document.querySelector('[data-cookie-accept]');
const cookieReject = document.querySelector('[data-cookie-reject]');

function closeMenu() {
  if (!menuButton || !menu) return;
  menuButton.setAttribute('aria-expanded', 'false');
  menu.classList.remove('is-open');
  body.classList.remove('menu-open');
}

function toggleMenu() {
  if (!menuButton || !menu) return;
  const isOpen = menuButton.getAttribute('aria-expanded') === 'true';
  menuButton.setAttribute('aria-expanded', String(!isOpen));
  menu.classList.toggle('is-open', !isOpen);
  body.classList.toggle('menu-open', !isOpen);
}

function updateHeader() {
  header?.classList.toggle('is-scrolled', window.scrollY > 12);
}

function saveCookiePreference(value) {
  localStorage.setItem('lar-com-proposito:cookie-consent', value);
  if (cookieBanner) cookieBanner.hidden = true;
}

menuButton?.addEventListener('click', toggleMenu);
menu?.querySelectorAll('a').forEach((link) => link.addEventListener('click', closeMenu));
window.addEventListener('scroll', updateHeader, { passive: true });
window.addEventListener('resize', () => {
  if (window.innerWidth > 900) closeMenu();
});

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') closeMenu();
});

if (year) year.textContent = String(new Date().getFullYear());
updateHeader();

const cookiePreference = localStorage.getItem('lar-com-proposito:cookie-consent');
if (cookieBanner && !cookiePreference) cookieBanner.hidden = false;
cookieAccept?.addEventListener('click', () => saveCookiePreference('accepted'));
cookieReject?.addEventListener('click', () => saveCookiePreference('necessary-only'));
