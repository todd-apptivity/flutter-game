# flutter_game

A Flutter game built on the [Flame](https://docs.flame-engine.org/) engine.

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

- `lib/main.dart` — game entry; `MyGame` extends `FlameGame`
- `assets/images/` — sprites (Flame resolves paths relative to this dir)
- `assets/audio/` — sfx and music

## Platforms

macOS, iOS, Android, and web are scaffolded. macOS and web work now. iOS and
Android need extra tooling — see `fvm flutter doctor`:

- **iOS**: install the iOS simulator runtime (Xcode → Settings → Components) and
  CocoaPods (`brew install cocoapods`)
- **Android**: install Android Studio, then `fvm flutter doctor --android-licenses`
