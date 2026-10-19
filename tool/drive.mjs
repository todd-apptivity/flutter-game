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
const page = await browser.newPage({ viewport: { width: 900, height: 700 } });

const problems = [];
page.on('pageerror', (e) => problems.push(`pageerror: ${e.message}`));
page.on('console', (m) => m.type() === 'error' && problems.push(`console: ${m.text()}`));
page.on('requestfailed', (r) =>
  problems.push(`requestfailed: ${r.url()} ${r.failure()?.errorText}`),
);

await page.goto(base, { waitUntil: 'load' });
await page.waitForFunction(() => globalThis.rogueAgent?.ready?.() === true, null, {
  timeout: 60_000,
});
console.log('✓ booted; window.rogueAgent.ready() === true');

// Deterministic run: pause the rAF loop, then advance exact frames.
await page.evaluate(() => {
  rogueAgent.setPaused(true);
  rogueAgent.reset();
  rogueAgent.tap(800, 600);
});
const before = await page.evaluate(() => rogueAgent.state());
await page.evaluate(() => {
  for (let i = 0; i < 10; i++) rogueAgent.step(1 / 60);
});
const after = await page.evaluate(() => rogueAgent.state());

const moved = Math.hypot(after.player.x - before.player.x, after.player.y - before.player.y);
const expected = 300 * (10 / 60); // Player.speed * elapsed
if (Math.abs(moved - expected) > 0.5) {
  problems.push(`step() moved ${moved.toFixed(2)}px, expected ${expected.toFixed(2)}px`);
} else {
  console.log(`✓ step() is deterministic (${moved.toFixed(2)}px over 10 frames)`);
}

// The landing copy must not swallow pointer events meant for the canvas.
await page.evaluate(() => {
  rogueAgent.setPaused(false);
  rogueAgent.reset();
});
await page.mouse.click(700, 200);
await page
  .waitForFunction(() => rogueAgent.state().target !== null, null, { timeout: 5000 })
  .then(() => console.log('✓ canvas taps reach the game'))
  .catch(() => problems.push('a canvas tap did not reach the game'));

await page.evaluate(() => rogueAgent.reset());
const shot = path.join(BUILD, 'landing.png');
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
