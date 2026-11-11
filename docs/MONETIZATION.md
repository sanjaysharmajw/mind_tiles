# Monetization: Google AdMob

**Status:** integrated (`google_mobile_ads` 9.2.0). The app is currently configured with **Google's public TEST IDs**. Test ads were verified loading on a physical Android phone (banner, rewarded and interstitial) and on the iOS Simulator (rewarded and interstitial).
**Do not publish with test IDs.** Switch to your real IDs as described below.

Implementation: `lib/services/ads/admob_ad_service.dart` (game code only talks to the `AdService` interface).
Master switch: `kAdsEnabled` in `lib/main.dart`. Set it to `false` for an ad-free build, which uses `DisabledAdService`.

## Placements and rules

| Format | Where | Rules (enforced in code) |
|---|---|---|
| Banner (anchored adaptive) | Bottom of **Home** and **Results** | Never on the gameplay screen. Collapses to nothing until an ad loads or if one fails. |
| Interstitial | When leaving **Results** (Next / Replay / Home) | `InterstitialPolicy`: not before 3 finished games, then every 3rd game, at least 180 s apart. Never during play. |
| Rewarded | **Hint** button after the free hints are used (badge shows "AD") | Offered only when an ad is loaded. The game is paused while it shows. The hint is granted only from the SDK's `onUserEarnedReward` callback; closing early grants nothing. |

Other safeguards:
- **Consent first:** the Google UMP consent form runs before any ad request. If ads can't be requested (no consent, or an error), the game continues ad-free.
- **Family-friendly content:** `maxAdContentRating = G`.
- **Load failures** retry with exponential back-off (2 s up to 64 s). There are no request loops and no blocking.
- **Ad privacy choices:** Settings shows this button when the UMP SDK reports that privacy options are required (for example in the EEA/UK).

## Switching to real IDs (before release)

1. AdMob console → **Apps** → *Add app* (once for Android, once for iOS). Each app gets an **App ID** (`ca-app-pub-XXXX~YYYY`).
2. For each app, create 3 **ad units**: Banner, Interstitial and Rewarded (`ca-app-pub-XXXX/ZZZZ`).
3. App IDs:
   - Android: `android/gradle.properties` → `admobAppId=ca-app-pub-XXXX~YYYY`
   - iOS: `ios/Flutter/AppConfig.xcconfig` → `ADMOB_APP_ID = ca-app-pub-XXXX~YYYY`
4. Ad unit IDs are passed at build time, so they never sit in source as test or real mixes:
   ```bash
   flutter build appbundle --release \
     --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXX/1111 \
     --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-XXXX/2222 \
     --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-XXXX/3333

   flutter build ipa --release \
     --dart-define=ADMOB_BANNER_IOS=ca-app-pub-XXXX/4444 \
     --dart-define=ADMOB_INTERSTITIAL_IOS=ca-app-pub-XXXX/5555 \
     --dart-define=ADMOB_REWARDED_IOS=ca-app-pub-XXXX/6666
   ```
   Without these flags, the build falls back to test units. A unit test asserts this.
5. **Never click your own live ads.** To test real units on your phone, add your device as a test device in AdMob → Settings → Test devices. The logcat line `setTestDeviceIds(... "82C0…")` shows the hashed ID.
6. iOS: replace the single `SKAdNetworkItems` entry in `ios/Runner/Info.plist` with **Google's full current list** (AdMob docs → iOS → "Update your Info.plist"). Only Google's own identifier is included now.
7. Add `app-ads.txt` to your developer website.

## Consent and privacy setup (AdMob console)

- **Privacy & messaging** → create a **GDPR** message (EEA/UK/CH) and, if you serve US users, a **US states** message. Publish both. The app already shows them through UMP when required.
- iOS **App Tracking Transparency** is not requested. Ads are served without IDFA, which is allowed. If you want personalized ads on iOS, add an IDFA explainer message in UMP (it handles ATT) and add `NSUserTrackingUsageDescription` to Info.plist.
- **Children:** the game is family-friendly but not designed for children. If you target under-13s in Play Families or the App Store Kids category, set `tagForChildDirectedTreatment` in `RequestConfiguration` and use certified networks only.

## Store declarations

- Play Console → App content → **Ads: Yes**. **Data safety:** declare the advertising ID and approximate device information collected by the AdMob SDK.
  The SDK merges the permissions `INTERNET`, `ACCESS_NETWORK_STATE`, `AD_ID` and `ACCESS_ADSERVICES_*`.
- App Store Connect → **App Privacy:** declare Device ID / Product interaction / Advertising data used for third-party advertising.

## Verified behaviour

| Check | Result |
|---|---|
| UMP consent flow runs and allows ads (India: GDPR not applicable) | ✅ physical Android phone |
| Test banner renders on Home | ✅ physical Android phone (screenshot) |
| Rewarded and interstitial test ads load | ✅ physical Android phone and iOS Simulator (`integration_test/services_test.dart`) |
| Reward granted only on verified callback; dismiss grants nothing | ✅ widget tests with fake ad service |
| Showing full-screen ads on device and watching to completion | ⚠️ not automated (needs a human to close the ad). Check manually. |
