# Asset and dependency licenses

## Original assets (created for this project)

| Asset | Source | License |
|---|---|---|
| `assets/audio/*.wav` (flip, button, match, mismatch, hint, victory, fail, star) and `music_loop.m4a` (AAC, converted with macOS `afconvert`) | Synthesized from scratch by `tool/generate_audio.py` (sine/triangle tones with envelopes). No samples were used. | CC0 1.0. Owned by the project; free to use, modify and distribute. |
| `assets/images/app_icon*.png`, `splash_logo*.png` and the generated launcher icons | Drawn programmatically by `tool/generate_icons.py` | Project-owned |
| All 40 tile symbols | Vector paths in `lib/game/board/symbol_renderer.dart` | Project-owned (code) |
| UI art (backgrounds, buttons, confetti, particles) | Drawn in code with Flutter and Flame canvases | Project-owned (code) |

## Third-party assets

| Asset | Author | License | File |
|---|---|---|---|
| Lilita One font | Juan Montoreano | SIL Open Font License 1.1 | `assets/fonts/LilitaOne-Regular.ttf`, license text in `assets/fonts/OFL-LilitaOne.txt` |
| Roboto font (Regular/Bold/Black static instances made from the variable font with fontTools) | The Roboto Project Authors | SIL Open Font License 1.1 | `assets/fonts/Roboto-*.ttf`, license text in `assets/fonts/OFL-Roboto.txt` |
| Material Icons (tree-shaken) | Google | Apache 2.0 | Bundled by Flutter |

## Runtime dependencies

| Package | License |
|---|---|
| Flutter SDK | BSD-3-Clause |
| flame | MIT |
| audioplayers (and its platform packages) | MIT |
| shared_preferences (and its platform packages) | BSD-3-Clause |
| google_mobile_ads (Google Mobile Ads SDK) | Apache 2.0 (SDK under Google terms) |
| firebase_core / analytics / crashlytics / performance / messaging | BSD-3-Clause (SDKs under Google terms) |
| flutter_local_notifications | BSD-3-Clause |

Dev-only: flutter_launcher_icons (MIT), flutter_native_splash (MIT), flutter_lints (BSD-3-Clause).

The full license list for everything bundled in the app is available in-game under **Privacy & About → Open-source licenses** (Flutter's `showLicensePage`).
