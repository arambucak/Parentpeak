import { access, readFile } from 'node:fs/promises';

const requiredFiles = [
  'index.html',
  'style.css',
  'script.js',
  'robots.txt',
  'sitemap.xml',
  'assets/app-icon.png',
  'assets/app-home.png',
];

await Promise.all(requiredFiles.map((file) => access(new URL(file, import.meta.url))));

const html = await readFile(new URL('index.html', import.meta.url), 'utf8');
const requiredSnippets = [
  '<html lang="de">',
  '<link rel="canonical" href="https://parentpeak.com/">',
  'assets/app-home.png',
  'id="features"',
  'id="philosophie"',
  'id="sicherheit"',
  'href="https://parentpeak.de"',
];

for (const snippet of requiredSnippets) {
  if (!html.includes(snippet)) {
    throw new Error(`Missing required website marker: ${snippet}`);
  }
}

if (/UG \(haftungsbeschränkt\)|komplett kostenlos|DSGVO-konform|Open Source Transparenz|14 Tage|Keine Kreditkarte/i.test(html)) {
  throw new Error('Found an outdated or unsupported public claim.');
}

console.log('Parentpeak website checks passed.');
