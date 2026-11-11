# Mind Tiles

A symbol memory-matching puzzle game for Android and iOS, built with **Flutter** and the **Flame** game engine.
The board is modelled on a physical board of rounded yellow tiles with black geometric symbols
(stars, circles, hearts, hexagons, X marks, dice dots and more), all drawn as vector paths.

There is no account or login, and core gameplay works fully offline. It ships with **Google AdMob** ads and **Firebase** Analytics, Crashlytics, Performance and Cloud Messaging (push).

---

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Project structure](#project-structure)
- [Game rules, modes and scoring](#game-rules-modes-and-scoring)
- [Testing](#testing)
- [Building for release](#building-for-release)
- [Configuration](#configuration)
- [Further documentation](#further-documentation)
- [Known limitations](#known-limitations)

## Features

- **Core memory matching**: shuffled pairs, a memorize preview you can skip or turn off, flip animation, ✓/✗ badges for matches and mismatches, input locked while a mismatch resolves, and win detection.
- **5 modes**: Classic (30-level campaign), Timed Challenge, Limited Moves, Daily Challenge (deterministic date seed with a streak) and Practice (unlimited hints, not recorded).
- **4 difficulties**: Easy 4×4, Medium 6×6, Hard 8×8 and Expert 8×10. Harder levels add more pairs, shorter previews and more similar-looking symbols.
- **40 custom vector symbols** in 3 difficulty tiers. No emoji or font glyphs on tiles.
- **Progression**: level unlocks, 1–3 stars, best score, time and moves per level, win/loss stats, streaks and 13 achievements with explicit conditions.
- **Hints**: a limited number per game. Each hint costs score.
- **Persistence**: one versioned JSON save with a migration pipeline. Corrupted saves are backed up and replaced with defaults. An in-progress game can be resumed with **Continue**.
- **Settings**: sound, music, haptics, reduce motion, preview length (Off/Short/Normal/Long), 3 tile themes (Sunny Yellow, Midnight, High Contrast) and reset progress (with confirmation). All settings are saved and take effect immediately.
- **Audio and haptics**: original synthesized sound effects and music loop. Game audio mixes with the player's own music and respects the iOS silent switch. Haptics use Flutter's built-in API.
- **Accessibility**: screen-reader labels on every control and on every board tile, live announcements of matches, feedback that never relies on color alone, text scaling up to 130%, and reduced motion (follows the OS setting as well).
- **Responsive layout**: works on small phones, large phones, notched devices, tablets and in landscape. Large boards scroll vertically instead of shrinking tiles below 40 pt (see [limitations](#known-limitations)).
- **Ads (AdMob)**: banner on Home and Results, an interstitial at natural breaks (frequency-capped), and a rewarded ad for an extra hint (granted only on the verified callback). UMP consent comes first, ad content is G-rated, and test IDs are the default. See [docs/MONETIZATION.md](docs/MONETIZATION.md).
- **Firebase**: Analytics (custom events plus automatic screen views, including the Realtime dashboard and DebugView), Crashlytics, Performance (automatic traces plus `app_bootstrap` and `level_play` custom traces), and Cloud Messaging with opt-in Daily reminders, topic subscription and a deep link to the Daily Challenge. Players can switch analytics, crash reports and performance off in Settings. See [docs/FIREBASE.md](docs/FIREBASE.md).

## YouTube Playables (web) build

The same game also builds as a YouTube Playable (an HTML5 game inside YouTube), using its own entry point `lib/main_playables.dart`:

```bash
flutter build web -t lib/main_playables.dart --release --no-web-resources-cdn -o "$PWD/build/playables"
python3 tool/package_playables.py      # → build/mind_tiles_playables.zip
```

It uses the Playables SDK instead of Firebase and AdMob: cloud save, YouTube mute and pause, and YouTube ads. Every MUST size limit passes, and it makes zero external requests under YouTube's CSP. See [docs/PLAYABLES.md](docs/PLAYABLES.md).

## Requirements

| Tool | Version used and verified |
|---|---|
| Flutter | 3.44.7 (stable) |
| Dart | 3.12.2 |
| Flame | 1.38.2 |
| audioplayers | 6.8.1 |
| shared_preferences | 2.5.6 |
| Xcode | 26.1.1 (iOS **15.0+** deployment target, required by Firebase) |
| Android | compileSdk 37, targetSdk 36, AGP 9.1.1, Gradle 9.3.1. minSdk comes from the Flutter default. |
| google_mobile_ads | 9.2.0 |
| FlutterFire | firebase_core 4.15 · analytics 12.6 · crashlytics 5.4 · performance 0.11.7 · messaging 16.7 (Firebase iOS SDK 12.19.3) |

**CocoaPods is not required.** Every plugin is built with Swift Package Manager.

## Getting started

```bash
flutter pub get
flutter run            # pick a connected device or simulator
```

To regenerate the generated assets (optional, because the outputs are committed):

```bash
python3 tool/generate_audio.py                 # synthesizes assets/audio/*.wav
python3 tool/generate_icons.py                 # draws icon + splash PNGs (needs Pillow)
dart run flutter_launcher_icons                # writes platform launcher icons
dart run flutter_native_splash:create          # writes native splash screens
```

## Project structure

```
lib/
  main.dart                     app bootstrap: storage, services, error hooks
  app/                          app widget, theme, navigation, service scope, config
  game/                         ── pure game logic + Flame rendering ──
    game_config.dart            LevelConfig, Difficulty, BoardSpec
    game_state.dart             GameSession: the single source of truth for a game
    symbol_match_game.dart      FlameGame: board, taps → tile index, particles
    board/                      symbols, deck generation, matching rules, layout,
                                vector symbol renderer, tile component, palettes
    modes/                      classic, timed, limited moves, daily, practice rules
    systems/                    scoring, level progression, timers, seeded RNG,
                                audio manager, haptics manager
  features/                     Flutter screens (home, gameplay, results, levels,
                                modes, daily, settings, statistics, achievements,
                                onboarding, about)
  data/                         key-value storage, versioned save repository,
                                PlayerDataController (progress/stats/achievements)
  models/                       settings, save data, achievements, game result
  services/                     ads (AdMob), firebase (analytics, crashlytics,
                                performance), notifications (FCM), interfaces
  firebase_options.dart         generated by flutterfire configure
  widgets/                      buttons, panels, background, symbols, stars, confetti
test/                           unit + widget tests (137)
integration_test/               on-device end-to-end test + screenshot capture
tool/                           asset generators (audio, icons)
docs/                           release, monetization, analytics, licenses, reports
```

**How the pieces fit:**
- `BoardController` holds the matching rules. It is plain Dart with no Flutter, timers or rendering.
- `GameSession` adds mode rules, preview, pause, hints and the result. It advances only through `tick(dt)`, so it is deterministic and easy to test. It never uses `Timer` or `Future.delayed`.
- `SymbolMatchGame` (Flame) reads the session every frame to draw tiles and drives `tick` from the game loop. When Flame pauses (for example when the app is backgrounded), the clock stops.
- Flutter screens render the HUD and dialogs from the session (`ListenableBuilder`) and react to session events for sound, haptics, saving and navigation.
- `AppServices` is created once in `main` and handed down through an `InheritedWidget`. There are no global singletons.

## Game rules, modes and scoring

- **Move**: revealing the second tile of an attempt. A perfect game uses exactly `pairs` moves.
- **Accuracy** = `pairs ÷ moves`. 100% means no wasted flips.
- **Stars**: 3★ if moves ≤ ⌈pairs × 1.5⌉, 2★ if moves ≤ ⌈pairs × 2.25⌉, otherwise 1★.

| Mode | Board | Limit | Hints | Score × | Recorded |
|---|---|---|---|---|---|
| Classic | 30 levels, 4×4 → 8×10 | none | 2 | 1.0 | yes |
| Timed | by difficulty | Easy 48 s · Medium 90 s · Hard 144 s · Expert 168 s | 1 | 1.2 | yes |
| Limited Moves | by difficulty | Easy 20 · Medium 40 · Hard 64 · Expert 76 | 1 | 1.2 | yes |
| Daily | 6×6, seed = `yyyymmdd` | 3 min | 1 | 1.5 | yes, plus streak |
| Practice | any difficulty | none | unlimited | 0.5 | no |

Timed and Limited Moves difficulties unlock after Classic levels 6 (Medium), 15 (Hard) and 24 (Expert).

**Score formula** (implemented in `lib/game/systems/scoring_system.dart`):

```
D            = difficulty multiplier (Easy 1.0, Medium 1.5, Hard 2.0, Expert 2.5)
base         = pairs × 100 × D
efficiency   = base × accuracy
timeBonus    = timed modes: secondsRemaining × 10 × D
               otherwise:   max(0, pairs × 4 s − elapsed) × 5 × D
movesBonus   = movesRemaining × 20 × D          (Limited Moves only)
comboBonus   = longest run of consecutive matches × 15
hintPenalty  = hintsUsed × 50 × D
score        = clamp((base + efficiency + timeBonus + movesBonus + comboBonus − hintPenalty) × modeMultiplier, 0, 9 999 999)
```

A lost game scores 0.

## Testing

```bash
flutter analyze                                   # static analysis
flutter test                                      # 157 unit + widget tests
flutter test integration_test/app_test.dart -d <device-id>   # on device/simulator
flutter test integration_test/services_test.dart -d <device-id>  # live Firebase + AdMob
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart -d <device-id>  # screenshots → build/screenshots
```

What each suite covers:
- **Unit tests**: deck generation, the two-copies invariant, shuffle spread, matching rules, repeated and invalid taps, move counting, win detection, timed and move-limit failures, hints, preview, pause, snapshots, scoring formula, stars, overflow and negative clamps, level progression and unlocks, achievements, the save round trip, corrupted and malformed saves, migrations, write ordering, daily determinism (pinned PRNG sequence), board layout and tap-to-index conversion, symbol rendering, the ad policy and audio/haptics gating.
- **Widget tests**: home navigation, the tutorial, a full level through to results and the next level, real taps on the Flame board, pause/resume, the restart confirmation, leave and Continue, backgrounding the app, timed failure and retry, locked content, settings persistence and their effect on gameplay, reset progress, rewarded-hint verification and the Daily Challenge. Seven screen sizes, including landscape and tablet, are checked for overflow, and the game state survives an orientation change.
- **Integration test**: a clean install on a real device. It covers the tutorial, a mismatch and then a full level played by real screen taps through Flame hit testing, persistence through platform storage, and starting the next level.

The commands that were run and their actual output are recorded in [docs/TEST_REPORT.md](docs/TEST_REPORT.md).

## Building for release

```bash
flutter build appbundle --release     # Play Store upload (build/app/outputs/bundle/release/)
flutter build apk --release --split-per-abi
flutter build ipa --release           # App Store (requires signing set up in Xcode)
```

Read [docs/RELEASE.md](docs/RELEASE.md) before you publish. It covers signing keys, store listings, privacy forms and versioning.
**Without `android/key.properties`, Android release builds fall back to debug signing. Do not upload those to Play.**

## Configuration

| What | Where |
|---|---|
| Android application ID | `android/gradle.properties` → `appId=` |
| iOS bundle identifier | `ios/Flutter/AppConfig.xcconfig` → `APP_BUNDLE_ID` |
| App display name | `android/app/src/main/AndroidManifest.xml` (`android:label`), `ios/Runner/Info.plist` (`CFBundleDisplayName`) |
| Version | `pubspec.yaml` `version:` and `lib/app/app_config.dart` (a test checks they match) |
| Ads on/off | `lib/main.dart` → `kAdsEnabled` |
| Ad frequency | `lib/services/ads/ad_service.dart` → `AdsConfig` |
| AdMob App IDs | `android/gradle.properties` (`admobAppId`), `ios/Flutter/AppConfig.xcconfig` (`ADMOB_APP_ID`) |
| AdMob unit IDs | `--dart-define=ADMOB_*` (see MONETIZATION.md) |
| Firebase project | `lib/firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist` (project `mind-tiles-9t1li`) |

## Further documentation

- [docs/RELEASE.md](docs/RELEASE.md): Android and iOS builds, signing, store submission, versioning and store assets
- [docs/MONETIZATION.md](docs/MONETIZATION.md): AdMob placements, real IDs, consent and store declarations
- [docs/PLAYABLES.md](docs/PLAYABLES.md): YouTube Playables web build (build, package, CSP test, e2e, submission)
- [docs/FIREBASE.md](docs/FIREBASE.md): Analytics, Realtime/DebugView, Crashlytics, Performance, push, and the console steps you must do
- [docs/PRIVACY_POLICY_TEMPLATE.md](docs/PRIVACY_POLICY_TEMPLATE.md): starting point for the store privacy policy
- [docs/ASSET_LICENSES.md](docs/ASSET_LICENSES.md): fonts, audio, art and packages
- [docs/IMPLEMENTATION_CHECKLIST.md](docs/IMPLEMENTATION_CHECKLIST.md): each requirement and where it is implemented and tested
- [docs/TEST_REPORT.md](docs/TEST_REPORT.md): commands run and their real results

## Known limitations

- **Google Analytics is not yet linked to the Firebase project.** You need to do this once in the console (Project settings → Integrations); it cannot be done from the CLI. Until then, Analytics/Realtime show no data. See [docs/FIREBASE.md](docs/FIREBASE.md).
- **iOS push needs an APNs key** uploaded to Firebase from your Apple Developer account. Android push is ready.
- **AdMob uses test IDs.** Add real App and unit IDs before release.
- **FlutterFire is pinned to the Firebase iOS SDK 12 generation** because the newest generation needs Xcode 26.2+ and this Mac has 26.1.1.
- **Signed store builds not produced.** No upload keystore or Apple distribution certificate was available.
- **Physical-device coverage:** gameplay, Firebase and ads were verified on one Android phone (Xiaomi, Android 14). iOS was verified on the Simulator only.
- **8-column boards on 320 pt-wide phones** get tiles of about 36 pt, below the 40 pt target.
- **Board tiles can be read and selected by screen readers**, but there is no keyboard or switch-access focus traversal on the Flame board.
- **The Daily Challenge uses the device's local date** and is not validated by a server.
