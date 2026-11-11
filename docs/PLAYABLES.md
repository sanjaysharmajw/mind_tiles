# YouTube Playables build

Mind Tiles has a separate **web build for YouTube Playables**. It shares all game code with the mobile app. It uses its own entry point, `lib/main_playables.dart`, which leaves out Firebase, AdMob and notifications and uses the YouTube Playables SDK (`ytgame`) instead.

> **Access:** Playables publishing is in *early access*. Submit the interest form linked from https://developers.google.com/youtube/gaming/playables first. The Developer Portal is invite-only (Private Preview), and you need a YouTube channel onboarded to Playables.

## Build → package → test

```bash
# 1. Build (JS + CanvasKit, everything bundled locally — no CDN)
flutter build web -t lib/main_playables.dart --release --no-web-resources-cdn \
  -o "$PWD/build/playables"

# 2. Prune unused files, check every Playables limit, write the upload ZIP
python3 tool/package_playables.py          # → build/mind_tiles_playables.zip

# 3. Serve locally with YouTube's Content-Security-Policy
python3 tool/serve_playables_csp.py 8790   # http://localhost:8790/

# 4. End-to-end emulation (fake ytgame SDK, real mouse clicks, CSP, reload)
pip3 install websocket-client              # once
python3 tool/playables_e2e.py --shots build/playables_shots
```

Then upload `build/mind_tiles_playables.zip` in the Playables Developer Portal (entry point: `index.html`). Use the portal's **Test** step: open the preview link on desktop web, mobile web, YouTube Android and YouTube iOS, and run the **Playables Test Suite** (https://developers.google.com/youtube/gaming/playables/test_suite).

## Current bundle (measured)

| Metric | Value | Limit |
|---|---|---|
| Files | 30 | MUST ≤ 8000 ✅ |
| Total size | 17.1 MiB | MUST < 250 MiB ✅ |
| Upload ZIP | 6.3 MiB | n/a |
| Initial bundle, Chrome/Edge (gzip, until `gameReady`) | 3.10 MiB | MUST < 30 MiB, SHOULD < 15 MiB ✅ |
| Initial bundle, Safari/Firefox | 3.78 MiB | ✅ |
| Largest file | `canvaskit/canvaskit.wasm` 6.9 MiB (2.8 MiB gzip) | MUST < 30 MiB ✅ · SHOULD < 512 KiB ⚠️ |
| File names / relative paths | all valid | MUST ✅ |
| Cloud save size | ≈ 2 KB | MUST < 3 MiB, SHOULD < 500 KiB ✅ |

**Files over the 512 KiB *SHOULD*:** `canvaskit.wasm` (Flutter's rendering engine), `main.dart.js` (2.4 MiB, 711 KiB gzip) and `assets/NOTICES` (open-source licenses, loaded only when the license page opens). Flutter cannot split these further. This is a SHOULD, not a MUST, so it is allowed with a valid reason, but reviewers may ask about it.

## Requirement → implementation

| Requirement | How Mind Tiles meets it |
|---|---|
| Integration 1: load SDK before game code | `<script src="https://www.youtube.com/game_api/v1">` is the first script in `web/index.html` |
| 2a: `firstFrameReady` during a loading screen | Called from `web/index.html` while the HTML "MIND TILES · Loading…" screen is visible |
| 2b/2c: `gameReady` only when interactive | `main_playables.dart` waits for the first rendered frame of Home, removes the HTML loader, then calls `gameReady` |
| 4a–4c: cloud save, `loadData` before `saveData`, no other storage | `PlayablesStore` loads first. Saves after every progress change and on `onPause`. If the first load fails, it never overwrites existing cloud data. No localStorage, cookies or IndexedDB are used. |
| 4d: old saves keep working | `SaveRepository` is versioned with migrations and tolerant parsing |
| 5: respect YouTube mute | `isAudioEnabled` sets the initial state and `onAudioEnabledChange` gates all audio (`AudioManager.setPlatformAudioEnabled`). In-game sound and music toggles are granular and cannot override YouTube mute. There is no single global mute button. |
| 6: pause/resume only via SDK | `onPause` pauses the session, stops the Flame engine, stops all tickers (`TickerMode`) and music, and saves. `onResume` restarts the engine, and the player resumes from the pause menu. OS lifecycle and page-visibility handlers are disabled in this flavor. |
| Design 1: responsive, no orientation lock | The layout adapts to every aspect ratio (tested from 320 × 568 to 1366 × 1024 and in landscape). Large boards scroll. |
| Design 2: touch and mouse | All interactions use Flutter or Flame pointer events. The e2e test plays a full level with mouse clicks. |
| Design 5: end of content | The results screen after level 30 and the Home screen say that all levels are complete and point to Daily, Timed and Limited Moves |
| Design 6: no share prompts, external links, extra agreements or exit button | None in this flavor. The pause button reads "MAIN MENU" (in-game navigation, not exit). The Notifications and Privacy settings section is hidden. |
| Monetization: YouTube ads only | `PlayablesAdService`: rewarded hint via `requestRewardedAd` (opt-in tap and never blocks progress), interstitial via `requestInterstitialAd` only when leaving Results (frequency-capped). No AdMob. |
| Privacy 3: no external calls | No Firebase or AdMob. CanvasKit and fonts are bundled (`--no-web-resources-cdn` plus bundled Roboto). The UI theme is forced to bundled fonts so the engine never downloads fallback fonts. Verified: 0 external requests and 0 CSP violations under the Playables CSP. |
| Privacy 4.2: no personal data | The game never asks for names, ages or logins |
| Privacy 5: no obfuscation | Standard dart2js minification only |
| Privacy 8: single page app | Flutter web is an SPA |
| i18n: English, no navigator.language | English UI. The game code does not read the locale. |
| Trust & Safety: original, 13+ | Original art, code and sounds. General audience. |

## Open questions to ask the Playables team

1. **WebAssembly:** Flutter's renderer (CanvasKit) is a `.wasm` file. The Privacy section says YouTube *may decline* games using WASM that it cannot evaluate. Flutter is listed as a supported engine with an "Experimental" sample, so ask your Partner Manager or the Discord to confirm before investing further.
2. **Engine internals:** the Flutter web engine itself listens to page-visibility events (for its own lifecycle) and reads `navigator.languages` (for its locale). Our game code ignores both and uses only the SDK, but an automated scan might flag them.
3. **Esc key:** Flutter dialogs close on Esc. Confirm the engine does not call `preventDefault()` on Esc in a way the Test Suite flags (Design 2g).
4. **Haptics:** web has no haptics, so the in-game Haptics toggle has no effect on desktop (allowed: "MAY use haptics").

## Listing assets you will need (Developer Portal)

- Thumbnails in the portal's aspect ratios, with **no logos or branding** in the images. Use gameplay art such as the tile board.
- Title, description, genre (Puzzle), and publisher or developer info.
- An **IARC age rating** (questionnaire in the portal).
- Optional: Accessible Games Initiative tags (e.g. high-contrast theme, reduced motion, no time pressure in Classic).

## Files

- `lib/main_playables.dart`: entry point
- `lib/playables/`: SDK bridge (`js_playables_platform.dart`, dart:js_interop), cloud save store, YouTube ads, crash logging to `ytgame.health`
- `web/index.html`, `web/flutter_bootstrap.js`: SDK tag, loading screen, no service worker
- `tool/package_playables.py`, `tool/serve_playables_csp.py`, `tool/playables_e2e.py`: packaging, CSP server, e2e emulation
- `test/unit/playables_test.dart` and the Playables tests in `test/widget/app_flow_test.dart`
