# Test report

Every command below was run in this workspace on 2026-11-11 (macOS 26.6.2, Apple Silicon). The outcomes are the actual outputs. Nothing here is projected or assumed.

**Toolchain:** Flutter 3.44.7 (stable), Dart 3.12.2, Xcode 26.1.1, Android SDK 37 (build target 36). Flame 1.38.2, audioplayers 6.8.1, shared_preferences 2.5.6.

## Results

| # | Command | Result |
|---|---|---|
| 1 | `flutter pub get` | ✅ Got dependencies |
| 2 | `flutter analyze` | ✅ `No issues found!` |
| 3 | `flutter test` | ✅ `00:16 +137: All tests passed!` |
| 4 | `flutter test integration_test/app_test.dart -d <iPhone 15 Pro simulator>` | ✅ `Integration run on ios passed` · `+1: All tests passed!` |
| 5 | `flutter test integration_test/app_test.dart -d emulator-5554` (Pixel_10 AVD, arm64) | ✅ `Integration run on android passed` · `+1: All tests passed!` |
| 6 | `flutter drive … integration_test/screenshots_test.dart -d <iPhone 15 Pro simulator>` | ✅ `All tests passed.` 9 screenshots captured and reviewed by eye |
| 7 | `flutter build apk --release` | ✅ `app-release.apk (51.3MB)` (universal APK, debug-signed) |
| 8 | `flutter build appbundle --release` | ✅ `app-release.aab (50.6MB)` (debug-signed) |
| 9 | `flutter build apk --release --split-per-abi` | ✅ armeabi-v7a 16.4MB · arm64-v8a 19.0MB · x86_64 20.4MB |
| 10 | `flutter build ios --release --no-codesign` | ✅ `Runner.app (25.4MB)` (unsigned) |
| 11 | `aapt2 dump permissions app-arm64-v8a-release.apk` | ✅ No user-facing permissions and no `INTERNET`. Only AndroidX's internal `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. |
| 12 | `adb install` of the arm64 release APK, launched with `am start`, then tapped through the tutorial into Level 1 | ✅ The R8-minified release build ran with no `FATAL` or Flutter errors in logcat. Screens captured. |

**Not run:** physical iPhone or Android phone (none attached), signed store builds (no upload keystore or distribution certificate), and AdMob/Firebase (not integrated). The Android screenshot run (`flutter drive` on the headless emulator) hung in `convertFlutterSurfaceToImage` and was stopped. Android visuals were captured with `adb screencap` from the release APK instead (row 12).

## Test suites (137 automated tests)

| File | Tests | Covers |
|---|---|---|
| `test/unit/deck_and_board_test.dart` | 16 | Two copies of every symbol for 1–40 pairs, invalid pair counts, deck validation, seed determinism, shuffle spread, tier preference, adjacency limit, correct and incorrect matches, mismatch input lock, repeated taps, matched tiles locked, out-of-range taps, win detection, combo, hints, restore |
| `test/unit/game_session_test.dart` | 19 | Preview (face-up, input ignored, skip, off), mismatch flip-back, rapid taps during a mismatch, exactly-once completion and results events, pause freezes the clock and hides tiles, pause during preview, timed failure and win, limited-moves failure and a win on the last move, practice (no failure, unlimited hints), daily determinism and pinned seed, hint allowance and bonus hint, snapshot round trip and rejection, every mode × difficulty can be completed |
| `test/unit/scoring_progression_test.dart` | 10 | Documented formula (exact value), stars thresholds, time and moves bonuses, clamps for no negative scores and no overflow, minimum moves, hint penalty, 30-level progression, invalid levels, difficulty unlocks, config JSON |
| `test/unit/persistence_test.dart` | 21 | Defaults, save/restore round trip, corrupted JSON backed up, wrong field types, migrations, last-write-wins ordering, unlock rules, no duplicate recording, best score and new-best detection, practice not recorded, win/loss streaks, daily streak and gap reset, difficulty unlocks, snapshot lifecycle, stale daily snapshot, reset progress, every achievement condition |
| `test/unit/systems_test.dart` | 19 | Board fit on phone, tablet and small screens, tap→index with gap and outside rejection, every symbol renders, symbol catalogue, PRNG determinism with a pinned sequence, PhaseTimer, interstitial policy, disabled ads, audio sound/music/lifecycle gating, haptics enabled flag and error swallowing, version sync with pubspec, audio assets present |
| `test/widget/app_flow_test.dart` | 16 | Home actions, navigation to every screen, first-run tutorial, full Level 1 → results → Level 2, real taps on the Flame board, pause/resume, restart confirm and cancel, leave and Continue restoring the same board, app backgrounding (pause + snapshot + stays paused), timed failure and retry, locked difficulty, locked and unlocked levels, settings persisting across restart and affecting gameplay (preview Off, muted sound), reset with confirmation, rewarded hint only on verified reward (and not on dismiss), daily completion |
| `test/widget/responsive_layout_test.dart` | 36 | Seven sizes (320×568, 360×640, 390×844, 430×932, 844×390 landscape, 820×1180 tablet, 1366×1024 tablet landscape) × (all menu screens; Easy, Medium and Expert boards fit the width with tiles ≥ 40 pt, or ≥ 34 pt at 320 pt wide; pause overlay; win and loss results), plus an orientation change that keeps game state |
| `integration_test/app_test.dart` | 1 | On device: clean install, tutorial, preview skip, a deliberate mismatch then a full solve **through real screen taps and Flame hit testing**, results, persistence via real `SharedPreferences`, next level, music toggle through real audio |

## Defects found and fixed during testing

| Found by | Defect | Fix |
|---|---|---|
| Widget test | `ChunkyButton` built a Stack with only positioned children, so layout crashed when it had no width constraint (preview "GO" button) | The face is now the sizing child |
| Responsive tests | Overflow at 320 pt or large text: home link row, logo tiles, preview banner, pause toggles, stat cards, titles | `Wrap`, `Flexible` and `FittedBox` scaling where needed |
| Unit test | 8-column boards gave 34–39 pt tiles on 360 pt phones | Tighter gap (0.08) and padding (6). Tiles are now ≥ 40 pt on 360 pt wide screens |
| Unit test | The session clamped `tick` to 0.25 s, mixing the frame-stall guard into the game model | The clamp moved to the Flame loop (`maxFrameStep = 0.1 s`) |
| Android integration | `FlameAudio.play` created a new player for every sound, and each ran a per-frame position updater until playback completed. 30 players were left alive on the emulator. | Replaced with a reusable 3-voice player bank per sound, position tracking disabled, and `flame_audio` dropped |
| Widget test | Achievements badge showed "0" | The badge is hidden when the count is zero |


---

## Update: AdMob and Firebase integration (2026-11-11)

| # | Command | Result |
|---|---|---|
| 13 | `firebase projects:create mind-tiles-9t1li` + `flutterfire configure` | ✅ Android and iOS apps registered, configs generated |
| 14 | `flutter analyze` | ✅ `No issues found!` |
| 15 | `flutter test` | ✅ `+146: All tests passed!` (137 earlier + 9 new: Firebase event/param mapping, test-ID default, settings persistence, consent toggling all three SDKs, notification opt-in granted/denied, `level_play` trace, notification-denied UI) |
| 16 | `flutter build apk --release` | ✅ `app-release.apk (56.1MB)` after moving to compileSdk 37 / AGP 9.1.1 / Gradle 9.3.1 (required by flutter_local_notifications 23) |
| 17 | `flutter build ios --release --no-codesign` | ✅ `Runner.app (29.3MB)` after pinning FlutterFire to Firebase iOS SDK 12.19.3 (13.x requires Xcode 26.2+) and raising the iOS target to 15.0 |
| 18 | `flutter run` on **physical Xiaomi 22041219I (Android 14)** | ✅ log `game_started` sent to Firebase. UMP consent ran. AdMob initialised. **Test banner visible** (screenshot). |
| 19 | `flutter test integration_test/services_test.dart -d <phone>` | ✅ `+2: All tests passed!` Firebase project ID correct; analytics, Crashlytics (non-fatal) and performance trace sent; FCM permission, topics and **token** obtained; rewarded and interstitial test ads **loaded** |
| 20 | `flutter test integration_test/app_test.dart -d <phone>` | ✅ `Integration run on android passed` (full level by real taps on a physical device) |
| 21 | `flutter test integration_test/app_test.dart -d <iPhone 15 Pro sim>` | ✅ passed with the Firebase SDKs linked |
| 22 | `services_test.dart --plain-name AdMob -d <iPhone 15 Pro sim>` | ✅ rewarded and interstitial test ads loaded on iOS |
| 23 | `services_test.dart` (Firebase part) on the iOS Simulator | ⚠️ stopped at the iOS notification permission dialog, which the test cannot tap (this confirms the opt-in prompt appears). An iOS FCM token also needs the APNs key (not uploaded yet). |
| 24 | `aapt2 dump permissions` on the release APK | ✅ only SDK-merged permissions (listed in RELEASE.md) |

**Console steps not done (they need your accounts):** link Google Analytics to the Firebase project, upload the APNs key, add real AdMob IDs and verify data in each Firebase dashboard. Events and the non-fatal error sent by test 19 should appear in Crashlytics or DebugView after Analytics is linked.


---

## Update: YouTube Playables web build (2026-11-11)

| # | Command | Result |
|---|---|---|
| 25 | `flutter build web -t lib/main_playables.dart --release --no-web-resources-cdn` | ✅ built |
| 26 | `python3 tool/package_playables.py` | ✅ **All MUST checks passed**: 30 files, 17.1 MiB total, initial bundle 3.10 MiB (Chrome) / 3.78 MiB (Safari) gzip. SHOULD warnings: canvaskit.wasm, main.dart.js and NOTICES are over 512 KiB. |
| 27 | Headless Chrome with the exact Playables CSP (`tool/serve_playables_csp.py`) | ✅ after fixes: 0 CSP violations and only same-origin requests. The first run found a **blocked Noto font fallback download** (Apple-platform default font), fixed by forcing bundled Roboto in the Playables theme. |
| 28 | `python3 tool/playables_e2e.py` (fake ytgame SDK and real mouse input) | ✅ **22/22 passed**: firstFrameReady first, loadData before gameReady, loader removed, onPause/onResume handled, mouse-played Level 1 completed, saveData after loadData (well-formed, ≈ 2 KB), rewarded ad on explicit tap, 0 CSP violations, 0 external requests, 0 JS exceptions, progress restored from cloud save on reload |
| 29 | `flutter analyze` / `flutter test` | ✅ No issues / **157 passed** (11 new Playables tests) |
| 30 | `flutter build apk --release` / `flutter build ios --release --no-codesign` | ✅ mobile builds unaffected (55.7 MB / 29.1 MB) |
| 31 | `integration_test/app_test.dart` on the Android emulator | ✅ passed (music now AAC .m4a) |
| 32 | Same test on the physical Xiaomi phone | ⚠️ not run: `INSTALL_FAILED_USER_RESTRICTED` (MIUI needs on-screen approval for USB installs) |

Not testable here: the real YouTube environment (Developer Portal preview link, YouTube Android/iOS apps, official Test Suite). That needs Playables access.
