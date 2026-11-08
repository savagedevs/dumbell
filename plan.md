# Workout App Plan

## Product vision

Build a free, offline-first workout tracking app that people can use without creating an account. Workout and personal data stays on the device by default, and users can export a backup whenever they want.

## Agreed requirements

- Free to use; no login or account required.
- Log workouts by adding exercises and sets, including reps and weight. Support kg and lb.
- Start a timer when a workout begins and record its total duration when it ends. If someone leaves during a workout, let them resume or discard it.
- View workout history and progress charts, including exercise performance, workout consistency, and body weight.
- Height tracking is out of scope.
- Edit and delete workouts, exercises, sets, and body-weight entries.
- Provide an exercise library. Each exercise has an animated demonstration and concise instructions or form cues.
- Optionally add a photo after a workout and create a shareable workout summary image for Instagram or other apps. Photos remain on the device unless the user chooses to share them.
- Export workout and progress records as easy-to-understand CSV files.
- Import data back into the app, starting with the app's own exported CSV format. Consider broader Excel compatibility later.
- Keep data locally on the device by default. Make clear that losing or uninstalling the device app may lose data, so users should export backups regularly.

## Suggested screens

1. **Home** — Start or resume a workout, show recent activity and a simple progress summary.
2. **Workout** — Show elapsed time; add exercises and sets; save or finish the session.
3. **Exercise library** — Search and browse exercises, view animated demonstrations and cues, and add exercises to a workout.
4. **Progress** — Show charts for exercise performance, workout consistency, and body weight.
5. **History** — Browse, edit, and delete past workouts.
6. **Workout summary** — Review duration and recorded exercises, optionally add a photo, and share a summary image.
7. **Settings & data** — Set units, export CSV, import a backup, and manage local data.

## Build sequence

1. Review the provided reference screenshots and agree on the visual direction.
2. Confirm the first-release feature list and settle exercise types and import/export behavior.
3. Sketch the main screens and workout flow.
4. Choose the local database and chart, animation, image-sharing, and file-handling approaches.
5. Implement the core flow: start and time a workout, log sets, save locally, and view history.
6. Add editing and deletion, progress charts, and body-weight tracking.
7. Add exercise demonstrations, post-workout photos, and shareable summaries.
8. Add CSV export and import, then check usability and data recovery on the target devices.

## Decisions still to settle

- Should exercises support reps only, or also time, distance, and other exercise types?
- Should body weight be a one-time value or a measurement history? (The current plan assumes a history so progress can be charted.)
- Which devices should be targeted first: Android, iPhone, or both?
- Should workout photos be stored only on-device, or should users also be able to choose an existing photo from their gallery?
