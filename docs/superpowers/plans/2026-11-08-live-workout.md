# Live Workout and Settings Implementation Plan

> **For agentic workers:** Implement the independent UI, workout-state and Android display tasks in parallel, then integrate and verify them.

**Goal:** Require Name, simplify Settings, and add consistent live workout displays with safe draft recovery.
**Architecture:** Existing GetX/Sembast state remains authoritative. A small Dart service publishes cached snapshots through a MethodChannel to Android widgets and notifications. Native host chronometers update the timer independently of Flutter rendering.
**Tech stack:** Flutter/GetX/Sembast; Android Kotlin/AppWidgetProvider/RemoteViews/Notification.
**Spec:** `docs/superpowers/specs/2026-11-08-live-workout-design.md`

## Global constraints
- Required nonblank Name; preserve old records and gate unnamed legacy users.
- Keep only legally required provider credit, in Settings/source details.
- Play Store handles app updates; no manual in-app check/install UI.
- Both live displays show the same saved session and exercise; no duplicate workout on tap.
- No per-second app background ticker or unnecessary foreground/sensor service.
- Save & start new is atomic and retains incomplete sets; failed writes retain the old draft.

## Review focus
- Notification taps during boot/name entry wait until routing is ready.
- Old platform updates must never overwrite a newer completed/cleared state.
- A malformed or denied native feature never blocks workout persistence.
- Historical editing must not change the active exercise display.
- App close/kill cannot be relied upon to persist a workout: drafts are already durable.

## Tasks
- [x] Require Name in profile form, durable save guard and route/boot guard; regression tests for whitespace and legacy unnamed profiles.
- [x] Remove manual update code/dependencies and prominent library branding; retain compact Settings credit and license.
- [x] Add active exercise selection and atomic save-and-start-new flow with input flush and failure tests.
- [x] Add native Kotlin display cache, provider, layout and chronometers; permission and click handling via `liftlog/live_workout`.
- [x] Add Dart snapshot/platform/service and Settings controls; test coalescing, denial, completion, lifecycle and buffered routing.
- [x] Run analyzer, full Flutter suite, Android compile and appropriate emulator checks; document actual device checks and limits.

The user has approved this scope. This folder has no Git repository; no worktree/commit is created.
