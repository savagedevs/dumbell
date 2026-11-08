# Version 1 validation

## Required Name and live displays — 8 November 2026

Current verification: analyzer clean; **131 Flutter tests passed**, covering required nonblank Name and legacy-profile gating, compact Settings attribution/no update checks, current exercise focus, pending-edit flush, atomic Save & start new, permission failure, native method contract, cold-launch buffering and rapid focus-update ordering. Android builds successfully. **3 instrumented tests passed** on Android 17/API 37 for native notification/public chronometer data and cleanup, widget rendering at 250×140dp and 360×180dp with an hour-long timer, unfinished state, and restored/clock-rollback cache snapshots. Native widget renders are available in the chat visualization directory. Additional Android versions/OEM launchers and manual pin acceptance remain release-device checks.

Use `tool/test_android.sh` for instrumented checks. It builds both APKs, installs in place with `-r` and calls instrumentation directly; it does not uninstall the target app. The Gradle option to leave APKs installed is also set. The initial connected-test runner unexpectedly uninstalled the emulator app, resetting local app data. Two identical readable CSV exports remained in Downloads; a one-off recovery rebuilt one completed workout (three exercises/six sets) and one empty unfinished draft. Every exported CSV row was reproduced exactly by the recovered AppData, persisted through LocalWorkoutRepository, then verified byte-for-byte after restoring to the empty app database. CSV cannot recover original record IDs, sub-minute start timestamps, unexported changes, body-weight history, profile details or photo bytes. The temporary recovery harness is not part of the app source.

The native cache is display-only. No foreground service, sensor permission or exact alarm is used. Normal backgrounding preserves live displays; actual activity finish marks the widget unfinished and cancels the notification. Android force-stop/process termination can skip lifecycle callbacks; placed home widgets remain user-owned and may keep their last cached appearance until refreshed. Draft persistence does not depend on those callbacks. Lock-screen exercise details follow Android privacy settings; the public version has a generic message plus elapsed timer.

## RepDB Free verification — 8 November 2026

The active exercise library uses RepDB Free: 701 exercises, 516 paired-pose exercises and 185 single-pose exercises, with 1,217 bundled static WebP files. All files decoded successfully as single-frame 512×512 images. An independent review compared every generated record against the pinned source and every image byte-for-byte against the archive; representative artwork was also inspected visually. Names, instructions and images remain tied to their upstream IDs.

`flutter analyze --no-pub` reported no issues. The complete `flutter test --no-pub --machine` run passed **108 tests**, including old-ID history/draft editing and export, image selection, single poses, small screens and offline licensing. Phone-sized Flutter widget renders were inspected separately from the native build.

The Android debug APK built, installed and launched normally on emulator-5554. Its packaged assets contain all **1,217** RepDB images and the complete RepDB Free license, with zero old wger images or MP4 files. The resumed activity is `com.example.workout_app/.MainActivity`. This was a development installation retaining existing app data. Play Store release validation and native camera/gallery/CSV destination dialogs still require the checks described below.

Earlier stages below record historical validation and are superseded for exercise content by this RepDB integration.

The tests under `workout_app/test` exercise atomic persistence and reopening, schema protection, queued writes and failures, canonical unit conversion, optional update outcomes, complete workout navigation, editor autosaving, immediate completion after input, and mobile layouts. Run `flutter analyze` and `flutter test` from `workout_app` for the current results.

Independent review found weight-rounding and immediate-completion races, and a missing native install callback in the update plugin. The fixes preserve the exact committed weight during non-weight edits, advance the draft's canonical value before chained saves, and bound the optional-install wait. Regression tests cover each case.

A Home preview is rendered using Flutter's widget renderer, with system Arial substituted for Roboto in the capture environment. It represents the actual widgets and theme; it is not a device or browser screenshot.

Earlier feature-completion checks: `flutter analyze --no-pub` reported no issues; `flutter test --no-pub --machine` passed all **104 tests**. Formatting across all **80 Dart source/test files** reported no changes. Coverage includes schema1→2 migration, optional profile/skip/edit, automatic start-to-exercise selection, readable workout CSV, lossless backup import/export, global ID conflict rejection, photo picker/recovery/removal/deletion races, video lifecycle, media download validation/cancellation and reduced-motion/small-screen layouts. Independent review findings are resolved.

## Local build limitations

The initial Android build failed downloading Gradle with `SSLHandshakeException` / `PKIX path building failed`. This was resolved for local development by copying only macOS system roots and explicitly trusted system certificates into an ignored local Java trust store. No certificate checks were disabled and no system trust settings were changed. `workout_app/tool/run_android.sh` applies that store to the launched build process. The NDK, SDK platforms 35/36 and CMake were installed through the existing Android SDK licenses.

Android debug APK build and emulator installation now pass. The app was launched on `Medium_Phone_API_37.0` / `emulator-5554`, and its rendered Progress screen was verified via an emulator capture. The local DDS service failed, so the launcher uses `--no-dds` for a successful direct Dart VM connection and hot reload. The local trust store is under `.dart_tool/local-android` and is not included in source control; Flutter clean removes it along with other local caches.

Release web build was blocked by macOS rejecting the signatures of the Flutter SDK's dart2js/dart2wasm snapshot libraries. The development web server compiled and started, but its Dart Development Service connection then failed and the preview did not render. No browser runtime or web-storage smoke test is claimed.

Actual Google Play flexible-update testing requires an eligible Play installation and a later version on a test track. Local unit tests verify optional behavior, cancellation, unsupported platforms, failures and timeout recovery. Publication and signed release validation are still required.

## Earlier emulator verification

The updated APK was built and installed successfully and launched from its normal `lib/main.dart` entry point on Android17/API37 emulator-5554. The optional first-run profile rendered correctly. A separate temporary native media probe initialized and played both bundled assets using Android Media3: bench_press 640×352 (15.849 seconds), wger_659 1920×1080 (15.033 seconds). The app was then restarted normally; the probe is not part of the app source. Gallery/camera and SAF destination dialogs were not manually completed during automation; their file/picker contracts, cancellation, persistence and errors are covered with injectable service tests, and the native packages compile and register successfully.

Exercise coverage/licensing and remaining media limitations are recorded in exercise-sources.md. Public-source video coverage is 46 movements; two demos are included offline. Some external videos require H.265 support. CSV backups explicitly exclude profile and photo bytes.

## Image-only exercise revision

Video UI, player helpers, bundled MP4s and video_player dependencies were removed. Images display directly in browse/details, preferring bundled/cache then online source. The image filter and illustration-only details regression pass; full suite: **101 tests passed**, analyzer clean. Previous native video checks above describe the earlier implementation and are superseded by this image-only revision.
