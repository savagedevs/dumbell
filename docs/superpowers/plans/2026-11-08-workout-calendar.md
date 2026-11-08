# Workout Calendar Implementation Plan

**Goal:** Explain workout consistency plainly and add an interactive calendar to its existing Progress section.

**Design:** The card says that consistency means how often you train. A Monday-first monthly calendar highlights days containing saved workouts with completed sets. Separate counts distinguish workouts from training days, including multiple workouts on one day. Users browse months, return to Today, select a date and open that day's workouts. The existing eight-week comparison remains behind an expandable explanation, with explicitly labelled week dates and counts. Empty days are neutral, with no invented targets, missed-day penalties or streaks.

**Architecture:** Pure derived activity indexing over immutable history; scoped GetX calendar navigation/selection; Flutter calendar and weekly-chart widgets using the existing charcoal/lime design. No storage migration, dependencies or external calendar access.

**Review focus:** Local dates and daylight-saving boundaries; February/leap years and year changes; multiple workouts per day; unfinished/zero-completed-set archives; edit/delete reactivity and month selection; small screens, large text and accessible day labels.

- [x] Add activity indexing and GetX calendar controller. Tests pin completed-only eligibility, local-date grouping, day/week/month counts, leap/year navigation, midnight Today updates and source history immutability.
- [x] Add the monthly calendar card with month arrows, Today, trained/today/selected indicators, plain monthly summary, neutral empty-day message and date-specific links to workout details. Test month/day interactions, reactivity, navigation and 320px/2× text.
- [x] Move the weekly chart into a focused widget, explain that bars count saved workouts in Monday–Sunday weeks, and identify the partial current week. Replace the old consistency card in Progress without changing other charts.
- [x] Run analyzer and full tests, inspect renders, install in place after a private backup, verify on the emulator and update README with actual evidence.


## Verification

- Full Flutter suite: 176 tests passed. Analyzer: no issues. Formatting check: no changes required.
- Added coverage for workout/day distinctions, unfinished and empty archives, local dates and UTC storage, Monday–Sunday boundaries, leap years, year changes, midnight updates, reactive deletion, daily workout links, accessible date actions and 320px screens with doubled text.
- Built and installed on the Android emulator in place after a private database/photo/preferences backup. Visually inspected the calendar with the user's current five saved workouts on one training day. Verified previous-month navigation, Today restoring the current month/counts, and neutral empty-day selection. No records modified.
- Left Progress open on the current month. Screenshot: workout-consistency-calendar.png in the session visualization directory.
