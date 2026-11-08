# Dumbbell 1.0.0 (1) — release verification

Verified 8 November 2026. Signed release candidate ready for direct APK testing/sharing; Play production publication is still gated by the steps below.

## Built artifacts

- Package: `com.savagecarol.dumbbell`; name: Dumbbell; support: svgcarol@gmail.com.
- Universal signed release APK and signed Play App Bundle: `workout_app/releases/1.0.0+1/`.
- Release certificate SHA-256: `5979748fbee3cd61b99fdcda8ffd362f61a1ce2c5f0ba6ad0dbdaf9ce6b0f885`.
- Optimized/non-debuggable build. Android API 24 minimum, API 36 target. Universal APK contains ARM32, ARM64 and x86-64 runtimes.
- Actual merged APK permissions: optional POST_NOTIFICATIONS and AndroidX's app-private signature receiver permission. No INTERNET, location, broad storage, health, foreground-service or exact-alarm permissions.
- APK signature verified by apksigner; signed AAB verified by jarsigner; both certificates match. APK zip alignment and all packaged ARM64/x86-64 ELF LOAD alignments pass the 16 KB checks.
- All 1,217 exercise illustrations and the bundled RepDB license are present. The app has offline privacy information and open-source notices. Public privacy HTML is generated in `docs/store/privacy-policy.html`.
- Full artifact sizes, certificate and SHA-256 file checksums are in `verification.json` and `SHA256SUMS.txt` beside the files.

## Checks performed

- `flutter analyze`: no issues.
- `flutter test`: 186 passing tests, including offline policy loading/contact, Settings policy navigation and the existing workout/data/photo/sharing/motion regressions.
- Signed release APK: installed and cold-started successfully on emulator-5554 (Android 17/API 37). This is a startup check, not a complete manual release UI acceptance run.
- `./tool/test_android.sh emulator-5554`: 5 native Android tests pass in the separate debug application, exercising widgets, notification content/chronometer/rendering, permission behavior and cached draft state. No old development installation was removed.
- `:app:lintRelease`: successful, 0 errors and 20 warnings. Warnings cover synchronous SharedPreferences persistence (deliberate for durable display snapshots), modern widget attributes with legacy fallbacks, pluralization suggestions, generated launcher-icon/resource/API-level suggestions, small widget label sizes, KTX suggestions and a newer available Gradle version. These are not hidden by a lint baseline; inspect `workout_app/build/app/reports/lint-results-release.html` for details. Small-label readability still needs physical-device review.
- Android SDK command-line tools were missing, causing Flutter's final bundle inspection to fail although Gradle had produced the bundle. Installed Google's official Mac ARM tools after verifying Google's published SHA-256; reran Flutter's bundle command successfully. No SDK checks were bypassed.

## Publication gates remaining

1. Securely back up the private signing keystore and `android/key.properties`. Configure Play App Signing with the existing app-signing identity if Play updates must replace these shared APKs without uninstalling.
2. Host the generated privacy policy at a public HTTPS URL and supply it in Play Console. No site has been published by this work.
3. Complete developer/account verification, store assets, app access/content rating/target audience, health and Data safety declarations in Play Console. Draft listing and factual answers: `docs/store/play-store-preparation.md`.
4. Test real devices and a Play test track before production: camera/gallery, external file destinations and sharing targets, notification denial/grant and lock screen, multiple OEM launchers, large text, offline use, restart/resume and app-update data preservation. Minimum Android/API 24 has not been exercised on a device in this session.
5. Meet any account-specific closed-testing/production-access requirements. Direct APK sharing does not complete a Play Console closed test.

The app code and signed binaries are prepared for release testing. This report does not claim Google Play approval, a completed physical-device matrix, or public privacy hosting.
