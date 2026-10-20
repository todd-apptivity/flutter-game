// Boots build/web in headless Chromium and drives the game through the
// window.rogueAgent bridge. Used as a smoke test for the deployable bundle.
//
//   npm --prefix tool install            # once
//   npx --prefix tool playwright install chromium   # once
//   fvm flutter build web --release
//   node tool/drive.mjs
//
// Exits non-zero on any page error, failed request, or behaviour mismatch.

import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const BUILD = path.resolve(fileURLToPath(import.meta.url), '../../build');
const ROOT = path.join(BUILD, 'web');
const TYPES = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.otf': 'font/otf',
  '.ttf': 'font/ttf',
};

if (!fs.existsSync(path.join(ROOT, 'index.html'))) {
  console.error(`No build at ${ROOT}. Run: fvm flutter build web --release`);
  process.exit(1);
}

const server = http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p === '/') p = '/index.html';
  const file = path.join(ROOT, p);
  if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404).end('not found');
    return;
  }
  res.writeHead(200, {
    'Content-Type': TYPES[path.extname(file)] ?? 'application/octet-stream',
  });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, r));
const base = `http://localhost:${server.address().port}`;

// SwiftShader: CanvasKit needs WebGL, which headless Chromium only provides in
// software, and recent builds refuse it without the explicit opt-in flag.
const browser = await chromium.launch({
  args: ['--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

const problems = [];
page.on('pageerror', (e) => problems.push(`pageerror: ${e.message}`));
// Pixel art lands file-by-file during the build, and the game is designed to
// draw placeholders for whatever is absent — so a 404 under assets/images is
// expected, and its matching console line is noise. Anything else is a bug.
const expectedMiss = (url) => url.includes('/assets/assets/images/');
page.on('console', (m) => {
  if (m.type() !== 'error') return;
  if (m.text().includes('Failed to load resource')) return;
  problems.push(`console: ${m.text()}`);
});
page.on('response', (r) => {
  if (r.status() >= 400 && !expectedMiss(r.url())) {
    problems.push(`http ${r.status()}: ${r.url()}`);
  }
});
page.on('requestfailed', (r) =>
  problems.push(`requestfailed: ${r.url()} ${r.failure()?.errorText}`),
);

await page.goto(base, { waitUntil: 'load' });
await page.waitForFunction(() => globalThis.rogueAgent?.ready?.() === true, null, {
  timeout: 60_000,
});
console.log('✓ booted; window.rogueAgent.ready() === true');

const pos = async () => (await page.evaluate(() => rogueAgent.state())).player;
const settle = (ms = 600) => page.waitForTimeout(ms);

// Real key events must reach the game and move the core right.
{
  const before = await pos();
  await page.keyboard.down('d');
  await settle();
  await page.keyboard.up('d');
  const after = await pos();
  if (after.x - before.x < 20) {
    problems.push(`holding D moved the core ${(after.x - before.x).toFixed(1)}px right`);
  } else {
    console.log(`✓ keyboard moves the core (${(after.x - before.x).toFixed(1)}px right)`);
  }
}

// With no keys held, the core chases the mouse.
{
  const before = await pos();
  await page.mouse.move(640, 80, { steps: 8 });
  await settle();
  const after = await pos();
  if (before.y - after.y < 20) {
    problems.push(`the core did not chase the pointer (dy ${(after.y - before.y).toFixed(1)})`);
  } else {
    console.log(`✓ pointer steering works (${(before.y - after.y).toFixed(1)}px up)`);
  }
}

// Keys outrank the mouse while held.
{
  await page.mouse.move(100, 360, { steps: 4 });
  await settle(300);
  const before = await pos();
  await page.keyboard.down('ArrowRight');
  await settle();
  await page.keyboard.up('ArrowRight');
  const after = await pos();
  if (after.x <= before.x) {
    problems.push('keyboard did not override pointer steering');
  } else {
    console.log('✓ keyboard overrides the pointer while held');
  }
}

// The core must stay inside the arena.
{
  await page.mouse.move(1279, 719, { steps: 8 });
  await settle(2500);
  const p = await pos();
  if (p.x > 1280 - 24 || p.y > 720 - 24) {
    problems.push(`the core left the arena at (${p.x.toFixed(1)}, ${p.y.toFixed(1)})`);
  } else {
    console.log(`✓ clamped inside the arena (${p.x.toFixed(1)}, ${p.y.toFixed(1)})`);
  }
}

await page.mouse.move(640, 360, { steps: 6 });
await settle(1200);
const shot = path.join(BUILD, 'stage.png');
await page.screenshot({ path: shot });
console.log(`✓ screenshot written to ${shot}`);

await browser.close();
server.close();

if (problems.length) {
  console.error('\nFAILED:');
  problems.forEach((p) => console.error('  ' + p));
  process.exit(1);
}
console.log('\nAll checks passed.');
