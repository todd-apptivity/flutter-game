/// Installs a `window.rogueAgent` bridge so a Chromium driver (Playwright,
/// Puppeteer, raw CDP) can inspect and drive the game without clicking on
/// canvas pixels. On non-web targets this is a no-op.
library;

export 'src/game_api_stub.dart'
    if (dart.library.js_interop) 'src/game_api_web.dart';
