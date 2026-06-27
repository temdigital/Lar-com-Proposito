import { cp, copyFile, mkdir, readdir, rm } from 'node:fs/promises';
import { join } from 'node:path';

const root = process.cwd();
const output = join(root, 'dist');
const staticDirectories = ['app', 'auth', 'public', 'src'];

await rm(output, { recursive: true, force: true });
await mkdir(output, { recursive: true });

for (const entry of await readdir(root, { withFileTypes: true })) {
  if (entry.isFile() && entry.name.endsWith('.html')) {
    await copyFile(join(root, entry.name), join(output, entry.name));
  }
}

for (const directory of staticDirectories) {
  await cp(join(root, directory), join(output, directory), { recursive: true });
}

console.log('Arquivos estáticos copiados para dist.');
