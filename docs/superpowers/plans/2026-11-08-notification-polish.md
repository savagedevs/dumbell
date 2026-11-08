# Live workout notification polish

The notification should make an ongoing workout easy to read at a glance and return to. Use Android's decorated custom notification with a compact exercise/timer row and an expanded timer, exercise, workout name and set progress. A native Resume workout action opens the existing workout route. Use notification text appearances and system colors rather than a fixed card background.

Keep the saved start timestamp as the clock authority. Native chronometers tick without waking Flutter. Preserve permission handling, silent updates, private lock-screen redaction and draft recovery. Do not add workout completion or editing actions to the notification.

Implementation and validation:

- Add a failing instrumented assertion for custom compact/expanded layouts, one resume action, and lock-screen privacy.
- Build small RemoteViews layouts and bind clock/progress through a dedicated renderer.
- Test real inflated views, long names, empty sets, future clock rollback, and readable light/dark colors. Capture notification previews on the emulator.
- Back up current app records before installing in place. Run Flutter analysis/tests and the safe Android instrumented test helper. Restore the display cache after test fixtures.

Status: implemented and verified.

Evidence:

- The initial Android test failed on the missing compact custom layout before implementation.
- Flutter analysis: no issues. Full Flutter suite: 176 tests passed.
- Final safe in-place Android build/test run: 5 tests passed (`workout_app/.dart_tool/notification-android-final-tests.log`). Views were inflated and checked at 260/310dp, normal/1.3 text scale, and light/dark themes. Tests cover elapsed clock bases, zero sets, clock rollback, progress bounds, resume intents and lock-screen redaction.
- The test now waits for the replacement notification's saved start timestamp, avoiding a race with a pre-existing notification from the user's session.
- Reviewed the actual Android notification shade and body previews. A 2.5s capture delay avoids capturing SystemUI's opening animation. Restarting the emulator cleared its stale pre-icon-change notification header cache; the generated LiftLog mark is now visible.
- The workout database matched the private pre-install backup byte for byte, and the original native display cache was restored after all fixture tests. No synthetic workout records were written.

Preview: `/Users/kartisharma/.codex/visualizations/2026/11/08/01a1b88c-71d3-7b71-a386-134f32c4629b/live-workout-notification-compact-preview.png`. Expanded light/dark body previews are in the same directory.
