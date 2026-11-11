# Implementation checklist

✅ = implemented and covered by automated tests or on-device runs · ⚠️ = implemented with a documented limitation · ❌ = not done (reason given)

## Gameplay (§4)
| Requirement | Status | Where |
|---|---|---|
| Shuffled deck, exactly 2 of each symbol, validated | ✅ | `game/board/deck_generator.dart` |
| Preview, which can be skipped or disabled in settings | ✅ | `GameSession`, `PreviewBanner`, Settings → Memorize preview |
| Reveal 1 then 2 tiles, match stays up, mismatch flips back | ✅ | `board_controller.dart`, `game_state.dart` |
| Input locked during a mismatch; repeated or matched taps ignored | ✅ | `SelectionResult.ignored*` |
| Win detection, celebration, results, continue/replay/home | ✅ | `GameSession._finish`, `SymbolMatchGame` burst, `ResultsScreen` |
| Easy 4×4 / Medium 6×6 / Hard 8×8 / Expert 8×10 | ✅ | `BoardSpec` |
| 30-level progression: more pairs, less preview, harder symbols | ✅ | `level_progression.dart` |
| Move and time limits as difficulty rises | ✅ | Timed and Limited Moves budgets tighten per difficulty (`timed_mode.dart`, `limited_moves_mode.dart`) |
| Tutorial for first-time players | ✅ | `features/onboarding/tutorial_screen.dart` |
| Classic, Timed, Limited Moves, Daily (date seed), Practice | ✅ | `game/modes/*` |

## UI and UX (§5)
| Requirement | Status | Notes |
|---|---|---|
| Home: logo, Play, Continue, Levels, Modes, Daily, Settings, Stats, Achievements, sound and music toggles, About/Privacy | ✅ | |
| Gameplay HUD: level, difficulty, moves, timer, pairs progress, pause, restart, hint | ✅ | Sound, music and haptics toggles are in the pause menu |
| Pause, resume, restart confirm, exit confirm, win and loss screens | ✅ | |
| Results: animated stars, score, moves, time, accuracy (formula shown), combo, best comparison, next/replay/home | ✅ | |
| Custom vector symbols (40) | ✅ | `symbol_renderer.dart` |
| Flip, match pulse and particles, mismatch shake, transitions, button press, score count-up, star pop, confetti, floating background | ✅ | All disabled or simplified by Reduce motion |

## Architecture and Flame (§6)
| Requirement | Status |
|---|---|
| Flame renders the board and handles taps; Flutter handles menus | ✅ |
| Tap position → tile index; gaps and outside points rejected | ✅ `BoardLayout.indexAt` (unit tested, and verified with real taps on device) |
| Resize and orientation relayout without reset | ✅ |
| Lifecycle: pause and snapshot on background, Flame engine paused | ✅ |
| No orphaned timers (tick-driven timers), listeners removed on dispose | ✅ |
| Logic separated from rendering | ✅ `BoardController`/`GameSession` have no rendering dependencies |

## Responsive (§7)
| Requirement | Status |
|---|---|
| Safe areas, dynamic geometry, no overflow at 7 sizes including landscape and tablet | ✅ |
| Large boards scroll vertically, tiles ≥ 40 pt | ⚠️ ~36 pt on 320 pt wide phones with 8 columns |

## Progression, persistence and settings (§8, §9, §11)
| Requirement | Status |
|---|---|
| Deterministic, documented scoring with clamps | ✅ |
| Unlocks, stars, best score/time/moves, games, pairs, win/loss, streaks, daily streak | ✅ |
| 13 achievements with explicit conditions and progress | ✅ |
| Local persistence, versioned with migrations, corruption recovery | ✅ |
| Resume an in-progress game (Continue) | ✅ |
| Settings for sound, music, haptics, reduce motion, preview, theme, reset (confirmed), privacy, version, all persisted and applied | ✅ |

## Audio, haptics and accessibility (§10)
| Requirement | Status |
|---|---|
| Tap, match, mismatch, button, victory, fail, hint and star sounds, music loop | ✅ Original, CC0 |
| Independent sound, music and haptics toggles | ✅ |
| Fails gracefully without audio or haptics | ✅ All guarded |
| Screen-reader labels (controls and every tile), live announcements, non-color feedback (✓/✗ badges), text scaling, reduced motion | ✅ |

## Monetization and analytics (§12, §13)
| Requirement | Status |
|---|---|
| Ad abstraction, central switch, policy that never shows ads during play, reward only on verified callback | ✅ Tested with fake ad services |
| AdMob SDK: banner, interstitial, rewarded, UMP consent, G rating, test IDs | ✅ Verified on a physical Android phone and the iOS Simulator. Real IDs are still to be supplied. |
| Analytics and crash abstraction, events, no personal data | ✅ |
| Firebase Analytics (+ screen views, Realtime/DebugView), Crashlytics, Performance, Cloud Messaging | ✅ Project `mind-tiles-9t1li`, verified on a physical Android phone. ⚠️ Analytics must be linked in the console, and iOS push needs an APNs key. |
| User control of data collection and notifications | ✅ Settings toggles. Notifications are opt-in. |

## Platform and release (§16, §17)
| Requirement | Status |
|---|---|
| Configurable app ID and bundle ID, app name, launcher icon, splash | ✅ |
| Minimal permissions | ✅ Only SDK-required ones (verified with aapt2) |
| Release signing setup with git-ignored key.properties | ✅ Configured |
| Android release APK and AAB build | ✅ (debug-signed: no upload key available) |
| iOS release build | ✅ `--no-codesign` |
| Simulator and emulator end-to-end tests | ✅ iOS Simulator + Android emulator |
| Physical device tests | ✅ Android (Xiaomi, Android 14) · ❌ iPhone not attached |
| Signed store builds | ❌ No keys or certificates |
| README, release, privacy, licenses, test report | ✅ |
