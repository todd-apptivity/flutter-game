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

// Keeps a test run alive: the end-of-run freeze is correct behaviour, but it
// stalls checks that are about something else. The run-end check below turns
// this off and lets the player die for real.
async function keepAlive() {
  await page.evaluate(() => rogueAgent.setIntegrity(100));
  await clearDraft();
}

// A draft freezes the whole simulation until a card is taken, which is correct
// behaviour and will silently stall any later check that expects time to pass.
async function clearDraft() {
  for (let i = 0; i < 6; i++) {
    const { drafting } = await page.evaluate(() => rogueAgent.state());
    if (!drafting) return;
    await page.keyboard.press('1');
    await settle(250);
  }
}

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

// Agents must appear from outside the arena and close on the control plane.
{
  await page.mouse.move(640, 360, { steps: 6 });
  await settle(3000);
  const state = await page.evaluate(() => rogueAgent.state());
  if (state.agents.length === 0) {
    problems.push('no agents spawned after 3s');
  } else {
    const dist = (a) => Math.hypot(a.x - state.player.x, a.y - state.player.y);
    const before = state.agents.map(dist);
    await settle(1500);
    const after = await page.evaluate(() => rogueAgent.state());
    // Agents die to the defenses now, so counting them down is meaningless;
    // what matters is that some agent has walked well inside the arena.
    const closest = Math.min(...after.agents.map(dist));
    if (!(closest < Math.min(...before)) && closest > 380) {
      problems.push(`agents are not closing on the control plane (${closest.toFixed(0)}px)`);
    } else {
      console.log(
        `✓ ${after.agents.length} agents in play, nearest ${closest.toFixed(0)}px out`,
      );
    }
  }
}

// Once agents are close, the defenses must fire on their own.
{
  // Packets are fast and sparse, so sample inside the page rather than
  // round-tripping: a poll every 250ms walks straight past them.
  const fired = await page.evaluate(
    () =>
      new Promise((resolve) => {
        let seen = 0;
        const id = setInterval(() => {
          seen = Math.max(seen, rogueAgent.state().projectiles.length);
          if (seen > 0) {
            clearInterval(id);
            resolve(seen);
          }
        }, 16);
        setTimeout(() => {
          clearInterval(id);
          resolve(seen);
        }, 8000);
      }),
  );
  if (fired === 0) {
    problems.push('the weapon never fired at an agent in range');
  } else {
    console.log(`✓ defenses fire automatically (${fired} packets in flight)`);
  }
}

// Kills must register, and sitting still must cost integrity.
{
  let state = await page.evaluate(() => rogueAgent.state());
  for (let i = 0; i < 24 && state.kills === 0; i++) {
    await settle(500);
    state = await page.evaluate(() => rogueAgent.state());
  }
  if (state.kills === 0) {
    problems.push('no agents were destroyed');
  } else {
    console.log(`✓ kills register (${state.kills} terminated at ${state.elapsed.toFixed(1)}s)`);
  }

  // Stand still in the swarm and bleed: the spawn rate out-paces one cannon.
  const before = state.integrity;
  let after = state;
  for (let i = 0; i < 12 && after.integrity >= before; i++) {
    await settle(2500);
    after = await page.evaluate(() => rogueAgent.state());
  }
  if (after.integrity >= before) {
    problems.push(`integrity did not drop (${before} -> ${after.integrity})`);
  } else {
    console.log(
      `✓ contact drains integrity (${before.toFixed(1)} -> ${after.integrity.toFixed(1)})`,
    );
  }
}

// Kills must drop tokens, and collecting them must raise the tier.
{
  const state = await page.evaluate(() => rogueAgent.state());
  if (state.tokensCollected === 0 && state.tokens.length === 0) {
    problems.push('no tokens dropped or collected');
  } else {
    console.log(
      `✓ tokens drop and bank (${state.tokensCollected} absorbed, ` +
        `${state.tokens.length} on the floor, tier ${state.level}, xp ${state.xp})`,
    );
  }
  if (state.tokensCollected > 0 && state.level === 1 && state.xp === 0) {
    problems.push('collected tokens did not bank any xp');
  }
}

// Every sprite must have loaded: the art is in the repo now, so a 404 under
// assets/images means a path or manifest problem, not a pending asset.
{
  const missing = await page.evaluate(async () => {
    const files = [
      'player_core.png',
      'floor_tile.png',
      'agent_scraper.png',
      'proj_packet.png',
      'pickup_token.png',
    ];
    const bad = [];
    for (const f of files) {
      const r = await fetch(`assets/assets/images/${f}`);
      if (!r.ok) bad.push(`${f} (${r.status})`);
    }
    return bad;
  });
  if (missing.length) {
    problems.push(`art not served: ${missing.join(', ')}`);
  } else {
    console.log('✓ all stage-6 sprites are served');
  }
}

// The level-up draft must open, freeze the arena, and apply what you pick.
{
  // Play until a tier is earned rather than forcing it, so this exercises the
  // real path: kills -> tokens -> xp -> draft.
  let state = await page.evaluate(() => rogueAgent.state());
  for (let i = 0; i < 40 && !state.drafting; i++) {
    await page.mouse.move(
      440 + ((i * 97) % 400),
      260 + ((i * 53) % 200),
      { steps: 6 },
    );
    await settle(700);
    // A run that ends here would freeze the game and starve this check.
    if ((await page.evaluate(() => rogueAgent.state())).over) {
      await page.evaluate(() => rogueAgent.setIntegrity(100));
    }
    state = await page.evaluate(() => rogueAgent.state());
  }

  if (!state.drafting) {
    problems.push('never reached a level-up draft');
  } else {
    console.log(`✓ draft opened at tier ${state.level} with [${state.offered}]`);

    const frozen = await page.evaluate(
      () =>
        new Promise((resolve) => {
          const a = rogueAgent.state();
          setTimeout(() => {
            const b = rogueAgent.state();
            resolve({
              elapsedDelta: b.elapsed - a.elapsed,
              moved: a.agents.length === b.agents.length
                ? a.agents.reduce(
                    (m, ag, i) =>
                      Math.max(m, Math.hypot(ag.x - b.agents[i].x, ag.y - b.agents[i].y)),
                    0,
                  )
                : -1,
            });
          }, 1200);
        }),
    );
    if (frozen.elapsedDelta > 0.01 || frozen.moved > 0.01) {
      problems.push(
        `arena kept running during the draft (clock +${frozen.elapsedDelta}, agents moved ${frozen.moved})`,
      );
    } else {
      console.log('✓ the arena is frozen while the cards are up');
    }

    await page.screenshot({ path: path.join(BUILD, 'draft.png') });

    const picked = state.offered[1];
    await page.keyboard.press('2');
    await settle(600);
    const after = await page.evaluate(() => rogueAgent.state());
    if (after.drafting) {
      problems.push('pressing 2 did not take a card');
    } else if ((after.upgradesTaken[picked] ?? 0) < 1) {
      problems.push(`picked ${picked} but it was not recorded as installed`);
    } else {
      console.log(`✓ keyboard pick installed ${picked}, run resumed`);
    }
  }
}

// Later waves must introduce the other agent types and the ranged attack.
{
  await page.evaluate(() => rogueAgent.setClock(95));
  await settle(1200);
  const banner = await page.evaluate(() => rogueAgent.state());
  if (!banner.waveBanner) {
    problems.push('crossing into a later wave raised no banner');
  } else {
    console.log(`✓ wave banner: "${banner.waveBanner}"`);
  }
  await page.screenshot({ path: path.join(BUILD, 'waves.png') });

  // Keep moving so the run survives long enough to see the mix.
  const seen = new Set();
  let injections = 0;
  for (let i = 0; i < 24; i++) {
    await page.mouse.move(
      420 + ((i * 131) % 440),
      240 + ((i * 71) % 240),
      { steps: 5 },
    );
    await page.evaluate(() => rogueAgent.setClock(150));
    await settle(600);
    await keepAlive();
    const s = await page.evaluate(() => rogueAgent.state());
    s.agents.forEach((a) => seen.add(a.id));
    injections = Math.max(injections, s.injections.length);
  }

  const expected = ['scraper', 'swarmlet', 'crawler', 'injector'];
  const missing = expected.filter((id) => !seen.has(id));
  if (missing.length) {
    problems.push(`agent types never seen in late waves: ${missing.join(', ')}`);
  } else {
    console.log(`✓ all four agent types spawn (${[...seen].join(', ')})`);
  }
  if (injections === 0) {
    problems.push('Prompt Injectors never fired a payload');
  } else {
    console.log(`✓ injectors fire payloads (${injections} in flight at peak)`);
  }
}

// The Rate Limiter must spin up, follow the player, and kill things.
let ringRadius = 0;
{
  await keepAlive();
  const owned = await page.evaluate(() => rogueAgent.state().weapons);
  if (!owned.includes('rate_limiter')) {
    await page.evaluate(() => rogueAgent.equip('rate_limiter'));
  }
  await settle(400);

  const spun = await page.evaluate(() => rogueAgent.state());
  if (spun.orbitNodes.length === 0) {
    problems.push('Rate Limiter equipped but no orbit nodes appeared');
  } else {
    // The ring's radius scales with range upgrades, so measure it rather than
    // hardcoding it; what matters is that every node shares one radius.
    const radii = spun.orbitNodes.map((n) =>
      Math.hypot(n.x - spun.player.x, n.y - spun.player.y),
    );
    ringRadius = radii[0];
    const offRing = radii.filter((r) => Math.abs(r - ringRadius) > 2);
    if (offRing.length || ringRadius < 50) {
      problems.push(`orbit nodes are off the ring: ${radii.map((r) => r.toFixed(0))}`);
    } else {
      console.log(
        `✓ Rate Limiter spun up ${spun.orbitNodes.length} nodes on a ${ringRadius.toFixed(0)}px ring`,
      );
    }
  }

  // Drive through the swarm; the ring should rack up kills by contact.
  const killsBefore = spun.kills;
  const clockBefore = spun.elapsed;
  for (let i = 0; i < 10; i++) {
    await page.mouse.move(
      420 + ((i * 113) % 440),
      250 + ((i * 67) % 220),
      { steps: 5 },
    );
    await settle(500);
    await keepAlive();
  }
  const after = await page.evaluate(() => rogueAgent.state());
  const stillOnRing = after.orbitNodes.every(
    (n) =>
      Math.abs(Math.hypot(n.x - after.player.x, n.y - after.player.y) - ringRadius) <
      2,
  );
  if (!stillOnRing) {
    problems.push('orbit nodes stopped tracking the player');
  } else if (after.kills <= killsBefore) {
    problems.push(
      `no kills after deploying the Rate Limiter ` +
        `(kills ${killsBefore} -> ${after.kills}, agents ${after.agents.length}, ` +
        `weapons ${after.weapons}, wave "${after.wave}", ` +
        `game clock advanced ${(after.elapsed - clockBefore).toFixed(2)}s)`,
    );
  } else {
    console.log(
      `✓ the ring tracks the player and kills (${after.kills - killsBefore} more agents)`,
    );
  }
  await page.screenshot({ path: path.join(BUILD, 'orbit.png') });
}

// A run must actually end, and redeploying must give a clean board.
{
  // Stand still in the late-game swarm until integrity runs out.
  await page.mouse.move(640, 360, { steps: 4 });
  let state = await page.evaluate(() => rogueAgent.state());
  for (let i = 0; i < 40 && !state.over; i++) {
    await settle(700);
    await clearDraft();
    state = await page.evaluate(() => rogueAgent.state());
  }

  if (!state.over) {
    problems.push(`the run never ended (integrity ${state.integrity})`);
  } else {
    console.log(
      `✓ run ended at ${state.elapsed.toFixed(0)}s with ${state.kills} kills, tier ${state.level}`,
    );
    await settle(1200);
    await page.screenshot({ path: path.join(BUILD, 'gameover.png') });

    // Frozen until the player acts.
    const a = await page.evaluate(() => rogueAgent.state());
    await settle(900);
    const b = await page.evaluate(() => rogueAgent.state());
    if (b.elapsed !== a.elapsed || b.agents.length !== a.agents.length) {
      problems.push('the arena kept running after the run ended');
    } else {
      console.log('✓ the arena is frozen on the end screen');
    }

    await page.keyboard.press('r');
    await settle(800);
    const fresh = await page.evaluate(() => rogueAgent.state());
    const clean =
      !fresh.over &&
      fresh.kills === 0 &&
      fresh.level === 1 &&
      fresh.integrity === 100 &&
      fresh.agents.length === 0 &&
      fresh.tokens.length === 0 &&
      fresh.orbitNodes.length === 0 &&
      fresh.weapons.length === 1;
    if (!clean) {
      problems.push(
        `redeploy left state behind: ${JSON.stringify({
          over: fresh.over,
          kills: fresh.kills,
          level: fresh.level,
          integrity: fresh.integrity,
          agents: fresh.agents.length,
          weapons: fresh.weapons,
        })}`,
      );
    } else {
      console.log('✓ R redeploys into a clean run');
    }

    // And the fresh run actually runs.
    await settle(2500);
    const running = await page.evaluate(() => rogueAgent.state());
    if (running.elapsed < 1 || running.agents.length === 0) {
      problems.push('the redeployed run is not spawning');
    } else {
      console.log(
        `✓ the new run is live (${running.elapsed.toFixed(1)}s, ${running.agents.length} agents)`,
      );
    }
  }
}

await settle(500);
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
