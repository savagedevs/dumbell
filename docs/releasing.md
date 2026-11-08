# Dumbbell Android releases

App name: **Dumbbell**. Application ID: **com.savagecarol.dumbbell**. Support/privacy contact: **svgcarol@gmail.com**. Initial release: **1.0.0 (1)**. The package identity becomes fixed once published on Google Play.

## Build and share

From `workout_app`, run `./tool/build_release.sh`. It runs the analyzer and Flutter tests, creates an optimized signed universal APK and signed Android App Bundle, then verifies the actual files and copies them into `releases/<version>+<build>/` with SHA-256 checksums and `verification.json`.

Share `Dumbbell-1.0.0-1.apk` for direct Android installation. The AAB is for Play Console uploads and cannot be installed by opening it on a phone. The APK supports Android 7.0/API 24 and newer, including ARM32, ARM64 and x86-64. Its release target is API 36. The release excludes internet access; external source links open in the user's browser. Notifications are optional.

For the next release, increase the integer after `+` in `pubspec.yaml`, for example `1.0.1+2`, and rebuild. Keep the application ID and signing identity stable. Generated reports record the actual version and signing certificate.

## Private signing identity

The local signing identity is `.signing/liftlog-release.jks`, alias `liftlog-release`; its passwords and relative path are in `android/key.properties`. These private files are ignored and restricted to the owner. Their historical filenames and certificate label do not affect the app's public Dumbbell name or package identity. Back up both files together in secure storage before distributing updates. Never send them with an APK or commit them. The release script never copies them to `releases/`.

`python3 tool/create_release_key.py` is for first-time setup only. It refuses to overwrite existing signing material. Do not replace a key after distributing a signed APK; restore the original. Gradle rejects release builds with missing signing material instead of falling back to development signing.

### Plan Play App Signing before publishing

To let Google Play updates replace the APKs shared from this folder without uninstalling, enroll the **existing app signing key** through Play Console's secure PEPK workflow. Then register a separate upload key if desired. If you instead let Google create a different app signing key, the locally signed APK cannot be replaced directly by a Play build with a different certificate. Testers would need to export a Backup CSV, uninstall, install the Play build and restore; photos/profile are excluded from CSV. [Google's signing options](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en-GB&rd=1)

## Development installation and existing records

Debug builds now use `com.savagecarol.dumbbell.debug` and show **Dumbbell Dev**. The older `com.example.workout_app` development installation is left intact. Neither the production APK nor the new debug app overwrites its private records. To move workouts, export a Backup CSV from the old app and import it into Dumbbell. Photos/profile must be handled separately. An ordinary update of the same package signed with the same identity retains local data.

Data schema 2 and the original CSV protocol identifiers/database filenames are intentionally unchanged, preserving previously exported backups. All database writes remain transactional. Unknown future schemas reject loading/writing rather than replacing records. Android automatic cloud backup and device transfer are explicitly disabled; manual CSV backup remains the recovery mechanism.

## Before Play Store publication

1. Host `docs/store/privacy-policy.html` at a stable, publicly accessible HTTPS URL and add that URL to `config/release.json` and Play Console. The complete policy is also available offline in Settings. Public hosting is not performed by the build script. [Privacy-policy requirements](https://support.google.com/googleplay/android-developer/answer/10144311)
2. Use the signed AAB for an internal test release; finish Play App Signing, account/developer verification, app access, content rating, target audience, Data safety, ads and Health apps declarations. Draft factual answers and listing text are in `docs/store/play-store-preparation.md`. [Health declarations](https://support.google.com/googleplay/android-developer/answer/14738291)
3. Review the generated icon and supply real phone screenshots plus a 1024×500 feature graphic. Do not use exercise illustrations outside the in-app use allowed by their license without checking permission.
4. Test the signed release on physical phones, including the oldest supported Android versions and common OEM launchers: first-run name, full workout/save/resume, airplane mode, photo camera/gallery/cancel, CSV export/import destinations, notification denial/grant, widget sizes/tap, sharing/cancel, large text, process death and restart. The current automated/emulator checks do not replace this device testing.
5. Test an upgrade through a Play test track with a higher version code and ensure local records survive. A locally signed update check does not prove Play re-signing/track delivery.
6. If this is a personal Play developer account created after 13 November 2023, the production-access gate currently requires at least 12 continuously opted-in closed testers for 14 days, followed by an application for production access. Direct APK sharing does not satisfy this Play testing requirement. [Official testing requirement](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en-GB)

Current submission requirements were checked on 8 November 2026. New phone apps/updates must target API 36 or newer. [Target SDK policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-en). Native APK zip and ELF LOAD alignment are checked for 16 KB compatibility by the release verifier. [Android guidance](https://developer.android.com/guide/practices/page-sizes)

This preparation does not publish the app or certify Play approval. Account declarations, public privacy hosting and release-device/Play-track testing remain publication gates.
