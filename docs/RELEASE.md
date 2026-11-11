# Release guide: Android and iOS

This guide covers going from this repository to signed store builds. None of the secrets mentioned here (keystores, passwords, certificates) belong in version control.

## 1. Before the first release

1. **Pick your permanent identifiers.** They cannot be changed after the first store upload.
   - Android: `android/gradle.properties` → `appId=com.yourcompany.mindtiles`
     (also update `namespace` in `android/app/build.gradle.kts` if you want the Kotlin package to match, and move `MainActivity.kt` to the matching folder).
   - iOS: `ios/Flutter/AppConfig.xcconfig` → `APP_BUNDLE_ID = com.yourcompany.mindtiles`
     (register the same App ID at developer.apple.com).
2. **Set the version** in `pubspec.yaml` (`version: 1.0.0+1`) and in `lib/app/app_config.dart`. `test/unit/systems_test.dart` fails if the two differ.
   - `1.0.0` is the user-visible version (versionName / CFBundleShortVersionString).
   - `+1` is the build number (versionCode / CFBundleVersion). It must increase with every upload.
3. **App name**: "Mind Tiles" is set in `AndroidManifest.xml` (`android:label`) and `Info.plist` (`CFBundleDisplayName`, `CFBundleName`).
4. **Icon and splash** are generated from `assets/images/`. To change them, edit `tool/generate_icons.py` or replace the PNGs, then run:
   ```bash
   dart run flutter_launcher_icons
   dart run flutter_native_splash:create
   ```

## 2. Android

### Minimum OS and permissions
- `minSdk` = Flutter default. `compileSdk` = 37 (required by flutter_local_notifications 23), `targetSdk` = 36, Android Gradle Plugin 9.1.1, Gradle 9.3.1.
- **Permissions** (all merged by the SDKs, verified with `aapt2`): `INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `VIBRATE`, `FOREGROUND_SERVICE` (Firebase/AdMob); `POST_NOTIFICATIONS` (requested at runtime only when the player enables Daily reminders); `c2dm.RECEIVE` (FCM); `AD_ID` and `ACCESS_ADSERVICES_*` (AdMob); and the install-referrer bind (Analytics). None of them is a dangerous permission requested at startup.

### Create an upload key (once)
```bash
keytool -genkey -v -keystore ~/keys/mindtiles-upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```
Create `android/key.properties` (this file is git-ignored):
```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=upload
storeFile=/Users/<you>/keys/mindtiles-upload.jks
```
`android/app/build.gradle.kts` uses this file automatically when it exists. Without it, release builds are **debug-signed**: you can run them locally, but Google Play rejects them.

Enroll in **Play App Signing** when you create the app in Play Console. Google then holds the app-signing key and you keep only the upload key.

### Build
```bash
flutter build appbundle --release        # → build/app/outputs/bundle/release/app-release.aab
flutter build apk --release --split-per-abi   # for side-loading/testing
```
R8 minification and resource shrinking are enabled (`android/app/proguard-rules.pro`).

### Play Console checklist
- App content: **Privacy policy URL** (adapt `docs/PRIVACY_POLICY_TEMPLATE.md` and host it). **Data safety** form: device or other IDs, app interactions, crash logs and diagnostics, shared with Google for advertising and analytics. **Ads** declaration: "Yes". **Target audience** (if you include children under 13, Families policy applies and AdMob must be configured for child-directed treatment), **Content rating** questionnaire (expected: Everyone / PEGI 3).
- Store listing: 512×512 icon (export `assets/images/app_icon.png` at 512), 1024×500 feature graphic, at least 2 phone screenshots (use `flutter drive ... screenshots_test.dart`), and optionally 7" and 10" tablet screenshots.
- Test with an **internal testing** track before production.

## 3. iOS

### Requirements
- macOS with Xcode 26.x, an Apple Developer Program membership and the App ID registered.
- Deployment target **iOS 15.0** (raised from 13.0 because Firebase requires it). All plugins are built through **Swift Package Manager**, so CocoaPods is not needed.
- `Info.plist` contains `GADApplicationIdentifier` (from `ADMOB_APP_ID`), `SKAdNetworkItems` (extend it to Google's full list), `UIBackgroundModes: remote-notification` and `ITSAppUsesNonExemptEncryption = false`.
- `Runner.entitlements` sets `aps-environment`. Enable **Push Notifications** for the App ID and upload an APNs key to Firebase (see FIREBASE.md).
- Crashlytics dSYM upload runs as a build phase and needs `flutterfire_cli` installed on the build machine.

### Signing
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Runner target → *Signing & Capabilities* → choose your Team. Keep "Automatically manage signing" on, or select your distribution profile.
3. The bundle identifier comes from `$(APP_BUNDLE_ID)` in `ios/Flutter/AppConfig.xcconfig`.

### Build and upload
```bash
flutter build ipa --release
# → build/ios/ipa/*.ipa; upload with Transporter or:
xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios -u <apple-id> -p <app-specific-password>
```
Or use Xcode → Product → Archive → Distribute App.

### App Store Connect checklist
- Privacy policy URL. **App Privacy**: identifiers, usage data and diagnostics (see PRIVACY_POLICY_TEMPLATE.md).
- Age rating questionnaire (expected 4+).
- Screenshots: 6.9" (1320×2868 or 1290×2796) and 6.5" iPhone sizes. Add 13" iPad screenshots if you ship for iPad (the app supports iPad).
- Use TestFlight before release.

## 4. Release verification checklist

- [ ] `flutter analyze` is clean
- [ ] `flutter test` passes
- [ ] `flutter test integration_test/app_test.dart -d <real Android phone>` passes
- [ ] `flutter test integration_test/app_test.dart -d <real iPhone>` passes
- [ ] Manual check on the device: sound, music, haptics, silent switch (iOS), backgrounding mid-game and then Continue, rotation, and a full game in each mode
- [ ] Version and build number bumped
- [ ] Signed with the real upload key or distribution certificate
- [ ] Privacy policy URL is live

## 5. What has and has not been verified in this repository

| Item | Status |
|---|---|
| `flutter build apk --release` / `appbundle` | ✅ built (debug-signed, because no upload key is present) |
| `flutter build ios --release --no-codesign` | ✅ built (unsigned) |
| Integration test on iOS Simulator (iPhone 15 Pro) | ✅ passed |
| Integration test on Android emulator (Pixel_10 AVD) | ✅ passed |
| Physical Android phone (Xiaomi 22041219I, Android 14): gameplay + Firebase + AdMob | ✅ passed |
| Physical iPhone | ❌ not done (no iPhone attached) |
| Release APK / iOS build with Firebase + AdMob | ✅ built (APK debug-signed, iOS unsigned) |
| Signed Play or App Store build | ❌ not done (no keys or certificates available) |
