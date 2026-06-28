import { cp, copyFile, mkdir, readdir, rm } from 'node:fs/promises';
import { extname, join } from 'node:path';

const root = process.cwd();
const output = join(root, 'dist');
const staticDirectories = ['app', 'auth', 'public', 'src', '.well-known'];
const rootExtensions = new Set(['.html', '.xml', '.txt', '.webmanifest']);

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

console.log('Arquivos estáticos, legais, SEO e de segurança copiados para dist.');
