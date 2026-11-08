# Sharing, Progress and Widget Implementation Plan

> **For agentic workers:** Implement the independent performance-data, sharing and native-widget tasks in parallel; root integrates progress UI/history hints and verifies the whole app.

**Goal:** Complete social sharing and per-exercise progression, and make the live widget more visual.
**Architecture:** Immutable derived performance data over saved snapshots; GetX-observed UI and native display cache; local share PNG renderer and platform chooser. No database migration.
**Tech stack:** Flutter/GetX/Sembast, share_plus, native Android RemoteViews/Canvas/Chronometer.
**Spec:** `docs/superpowers/specs/2026-11-08-sharing-progress-design.md`

## Global constraints
- Completed saved sets only for progress; previous sessions strictly earlier and excluding the selected workout.
- Explicit exercise aliases only; never merge arbitrary similarly named movements.
- Story/square share preview, photo opt-in, no automatic posting and no exported RepDB art.
- Native widget stays accurate across resize/tap/unfinished states; Android renders its clock.
- Preserve current data/schema; back up device and install in place for tests.

## Review focus
- Multiple same-exercise entries, unordered history and unit changes must not distort metrics.
- Bodyweight/one-point/no-data charts must stay readable and avoid invented progress.
- Pending history edits must flush before sharing or prior-session navigation.
- Share cancellation/deleted photos/long titles must leave records safe and PNG legible.
- Compact widget, unknown exercise images and long timers must remain readable and truthful.

## Tasks
- [x] Performance-data layer: exerciseKey/definition lookup, verified legacy aliases, session aggregation/previous-session queries and boundary tests.
- [x] Sharing: local PNG rendering, preview and explicit share sheet with optional user photo, failure/cancel tests; root wires detail action after input flush.
- [x] Native widget: visual progress ring/image/adaptive layout, native payload support and widget-host tests; root extends Dart snapshot with source asset.
- [x] Root: progress browser/chart/detail page and previous-session hints in exercise selection/logging; GetX routes and reactive edits/units.
- [x] Validate analyzer/full Flutter suite, safe native tests, rendered previews and emulator app refresh. Update docs and checks with actual evidence.

## Verification

- Final `flutter analyze --no-pub`: no issues found.
- Full Flutter suite: 158 tests passed. Covers failed/successful pending-edit flush before sharing, PNG dimensions, photo opt-in, cancellation/errors, exercise aggregation, previous-session boundaries, chart selection/ranges, GetX controller disposal and existing app regressions.
- Android: 5 instrumented tests passed through `tool/test_android.sh emulator-5554`, preserving the app install and user data. Covers actual widget hosts, compact/expanded layouts, per-instance resize, image/fallback, timer, ring bounds and unfinished/idle states.
- Visually inspected real-font Story/Square PNGs, a multi-session chart fixture and native widget-host screenshots. Fixtures were rendered outside the device database.
- Updated emulator app verified with existing records: History → Share workout → preview → Android image chooser → cancel; Progress → Barbell Back Squat → single-workout chart. No destination selected or post sent. Existing history, draft and attached photo retained.
- README now documents sharing, individual exercise charts, previous-set hints and adaptive live widget behavior.

## Exercise-page discoverability correction

The exercise details originally exposed a small Progress link without displaying the graph. Added a graph shortcut to catalogue rows and an inline graph near the top of details, sharing the existing performance controller and chart renderer. Inline metric/point state is scoped to its sheet. Empty exercises explain that saved completed sets are required.

Regression reproduced before the fix: the exercise details contained no `ExerciseTrendChart`. After the fix, the full Flutter suite passed all 161 tests and the analyzer reported no issues. On the emulator, verified the inline graph using existing records, Volume = 160 kg × reps, Full graph navigation and Back retaining inline selection. Installed in place after a fresh database/photo/preferences backup; no workout or exercise added during verification.

## User-directed exercise order and field defaults

- Details now show Add to workout first, then illustration, description, form cues and tips, with progress at the bottom. Removed the redundant Last time / Progress panel from details and the workout editor.
- Adding a movement copies the completed sets from the latest strictly earlier saved workout, using verified exercise identities. New set IDs and unchecked completion flags preserve the source history and require explicit confirmation of today's sets. No previous history retains the 0 kg / 8 reps starter.
- Weight/reps fields show Same as last when their displayed values match the corresponding previous set, and Your entry when changed. Existing drafts are not reseeded; canonical precision and unit conversion remain intact without schema or backup format changes.
- Verification: full Flutter suite 167 tests passed; analyzer clean. Regression tests cover layout order, copied values and fresh identities, incomplete/future exclusions, persistence failure/retry, resume edits, kg/lb precision, large text and the absence of the old panel.
- Android app rebuilt and installed in place after a fresh private backup. On the emulator, confirmed Add to workout and illustration at the top, progress reachable below the instructions/tips, and no Last time panel. Left details open at the top. No workout or exercise added during device verification.
