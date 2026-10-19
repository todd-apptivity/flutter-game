# Rogue Agent

A Flutter game built on the [Flame](https://docs.flame-engine.org/) engine.
The web build is a "coming soon" landing page with the game running behind it.

## Environment

The Flutter SDK is pinned per-project with [fvm](https://fvm.app), so nothing is
installed globally. The pinned version lives in `.fvmrc`; the SDK itself is
cached in `~/fvm/versions/` and symlinked at `.fvm/flutter_sdk`.

| | |
|---|---|
| Flutter | 3.47.7 (stable) |
| Dart | 3.13.5 |
| Flame | 1.38.2 |

First-time setup on a new machine:

```sh
brew tap leoafarias/fvm && brew install fvm
fvm install        # reads .fvmrc
fvm flutter pub get
```

## Commands

Always prefix with `fvm` so the pinned SDK is used.

```sh
fvm flutter run -d macos      # fastest iteration; r = hot reload, R = restart
fvm flutter run -d chrome     # web
fvm flutter test
fvm flutter analyze
fvm flutter run -d macos --profile   # real frame timings; debug mode is NOT representative
```

To change SDK version: `fvm use <version>` (e.g. `3.46.0`, `beta`).

## Layout

- `lib/main.dart` — entry point; builds the game and installs the dev API
- `lib/game.dart` — `MyGame` (extends `FlameGame`) and `Player`
- `lib/landing_page.dart` — the "coming soon" overlay drawn on top of the game
- `lib/game_api.dart` + `lib/src/` — the `window.rogueAgent` browser bridge
- `tool/drive.mjs` — headless Chromium smoke test of the built bundle
- `web/_headers` — Cloudflare Pages cache rules
- `assets/images/` — sprites (Flame resolves paths relative to this dir)
- `assets/audio/` — sfx and music

## Driving the web build from Chromium

Flame renders into a single `<canvas>`, so there is no DOM for a browser driver
to select. `lib/src/game_api_web.dart` publishes `window.rogueAgent` instead:

| Call | Does |
|---|---|
| `rogueAgent.ready()` | `true` once the game tree is mounted |
| `rogueAgent.state()` | `{ready, paused, width, height, player, target}` |
| `rogueAgent.tap(x, y)` | Same effect as tapping that point |
| `rogueAgent.setPaused(b)` | Stops/starts the `requestAnimationFrame` loop |
| `rogueAgent.step(dt)` | Advances one frame by an exact `dt` while paused |
| `rogueAgent.reset()` | Agent back to its spawn point, target cleared |

`setPaused(true)` + `step(dt)` is the deterministic path: no sleeping on wall
clock, identical positions every run.

```js
await page.waitForFunction(() => globalThis.rogueAgent?.ready?.() === true);
await page.evaluate(() => {
  rogueAgent.setPaused(true);
  rogueAgent.tap(800, 600);
  for (let i = 0; i < 10; i++) rogueAgent.step(1 / 60);
});
const { player } = await page.evaluate(() => rogueAgent.state());
```

On non-web targets `installGameApi` is a no-op (`lib/src/game_api_stub.dart`).

Headless Chromium needs software WebGL for CanvasKit — launch it with
`--enable-unsafe-swiftshader --use-gl=angle --use-angle=swiftshader`.

Run the bundled harness:

```sh
npm --prefix tool install                        # once
npx --prefix tool playwright install chromium    # once
fvm flutter build web --release
node tool/drive.mjs                              # serves build/web, drives it, screenshots
```

## Deploying (Cloudflare Pages)

`.github/workflows/deploy.yml` builds on every push to `main` and uploads
`build/web` with Wrangler. This is a **direct upload**, so it does not consume
the Pages build quota; on a public repo the Actions minutes are free too.

One-time setup:

1. Create the project (name must match `CF_PAGES_PROJECT` in the workflow):

   ```sh
   npx wrangler pages project create rogue-agent --production-branch main
   ```

2. Create an API token at **Cloudflare dashboard → My Profile → API Tokens**
   with the **Cloudflare Pages: Edit** permission.

3. Add two repo secrets under **Settings → Secrets and variables → Actions**:
   `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.

Pull requests get a preview deployment; `main` goes to production. The commit
SHA is passed through as `--dart-define=BUILD_REF` and rendered at the bottom of
the landing page, so you can confirm which build Cloudflare is serving.

### Web build notes

- Flutter 3.47 dropped `--web-renderer`; a plain `flutter build web --release`
  is CanvasKit-on-JS. Nothing here passes `--wasm`, so the page does **not** need
  `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` headers.
- `web/flutter_bootstrap.js` sets `canvasKitBaseUrl: "canvaskit/"` so CanvasKit
  loads from the deploy rather than `gstatic.com`.
- Flutter does not content-hash its web output (`main.dart.js`, `assets/*` and
  `canvaskit/*` keep stable URLs), so `web/_headers` uses ETag revalidation
  rather than `immutable`, and never caches the service-worker entry points. A
  long `max-age` there would pin visitors to a stale build.
- Known remaining third-party request: Flutter fetches its default Roboto face
  from `fonts.gstatic.com`. Bundle a font under `assets/` and set
  `ThemeData.fontFamily` to make the page fully self-contained.

## Platforms

macOS, iOS, Android, and web are scaffolded. macOS and web work now. iOS and
Android need extra tooling — see `fvm flutter doctor`:

- **iOS**: install the iOS simulator runtime (Xcode → Settings → Components) and
  CocoaPods (`brew install cocoapods`)
- **Android**: install Android Studio, then `fvm flutter doctor --android-licenses`
