# Subtle Feedback Implementation Plan

> Implement directly in the current workspace; user authorized these three effects.

**Goal:** Add restrained feedback to welcome, set completion, and successful workout finish.

**Architecture:** Flutter animation widgets own their controllers and dispose them. The workout controller tracks the greeting claim only in memory. A typed detail-route argument distinguishes a fresh finish from history navigation.

**Tech Stack:** Flutter, GetX, existing app colors; no additional dependencies.

**Spec:** `docs/superpowers/specs/2026-11-08-subtle-feedback-design.md`

## Constraints and review focus

Failed saves must never celebrate. Opening history and initially completed sets must not replay effects. Reduced motion must stop active effects as well as prevent new ones. Rebuilds and timer ticks must preserve animation state and text fields. New route arguments must retain compatibility with existing string IDs.

## Tasks

- [x] Add focused animation tests covering one-shot behavior, set transitions, and reduced motion; run to establish missing feature failures.
- [x] Add `WelcomeFade`, `SetCompletionFeedback`, `SetProgress`, and `CompletionSparkle` in `lib/core/feedback_motion.dart`; integrate into Home, WorkoutEditor, and successful finish routing.
- [x] Verify routing only celebrates successful saves, existing form behavior, and the full Flutter suite; run analyzer and self-review.

No Git repository exists in this workspace, so changes remain available directly without commits.

Validation: 183 Flutter tests passed; analyzer clean; Android debug APK built successfully. Self-review caught summary-header disposal on scrolling; a regression test reproduced the replay, and retaining its one-shot state fixed it. Reduced-motion progress switches immediately to a static indicator, including when the preference changes during an animation.

Follow-up visibility fix: a failing navigation test showed the welcome fade was already 97% visible during page entry. Entry feedback now waits until the page is onstage and the route transition completes. Greeting duration is 650 ms; checkbox pulse is 300 ms at 1.10 scale; six sparkles remain local and last one second with clearer marks. Validation: 184 Flutter tests passed; analyzer clean; updated Android debug APK built.
