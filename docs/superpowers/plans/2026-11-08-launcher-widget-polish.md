# Launcher Icon and Live Widget Polish

**Goal:** Add a recognisable LiftLog launcher icon and replace the crowded widget hierarchy with a timer-first design.

**Design:** A bold lime barbell on charcoal provides an editable vector identity, with adaptive Android layers, a monochrome themed layer and correctly sized platform icon catalogues. The widget repeats the mark, uses concise live/draft/ready state labels, gives elapsed time and the current exercise most of the space, and shows set completion once as a thin progress strip. Remove the illustration/ring competition and the oversized Resume button. Preserve a clear, quiet resume/open action and deliberate idle/unfinished layouts. Fit compact 250×140dp and expanded 360×180dp instances independently.

**Ownership:** Root owns icon SVG/generator, launcher assets, manifest, docs and verification. The widget agent owns native widget provider, layouts/resources, retired widget artwork cleanup and host tests. Only root runs Flutter/Gradle/adb to avoid shared build races.

**Constraints:** No workout schema or timing changes. Keep real Chronometer, private display cache and tap-to-resume behavior; do not fake a stopped timer for unfinished work. Preserve user records with a private device backup and install in place. Do not run connectedDebugAndroidTest, which uninstalls this development app.

- [x] Create vector icon and deterministic generation for Android adaptive/round/monochrome icons, iOS and existing desktop/web catalogues; verify sizes, opacity and reproducibility.
- [x] Implement responsive widget redesign, installation refresh and host tests covering clocks, progress, actions, long content and inactive states.
- [x] Run analyzer/Flutter suite and safe native tests. Inspect rendered widget/icon screenshots and packaged assets on the emulator.
- [x] Update documentation and leave the app available on the emulator without changing workout records.


## Verification

- Icon generator verified all 49 outputs against the SVG source. Checked platform catalogue dimensions and opaque RGB, Android adaptive/themed layers and round icon registration. Verified the custom icon visibly in the Android launcher.
- Full Flutter suite: 176 tests passed. Analyzer: no issues found.
- Safe in-place Android build and instrumented checks: 4 native tests passed, covering real widget hosts, independent resize, live/unfinished/idle states, progress limits, actual root/action PendingIntents, long time/name bounds and package-update refresh. Repeated after matching the notification resource to the generated mark; all 4 passed again.
- Inspected actual compact/expanded/idle native renders and the Android pin-widget preview. The optional attempt to place the widget was interrupted by Android UI automation returning no root; no placement is claimed. The app's existing Add home-screen widget control remains available.
- Installed without uninstalling after a fresh private database/photo/preferences backup. No workout records changed. Final app reopened on the emulator.
