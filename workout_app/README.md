# Dumbbell · Version 1

A free workout log with no account. The interface follows `../visuals.md`: charcoal surfaces, lime actions, bold headings and readable set entry.

## Run

From this folder:

```sh
flutter pub get
flutter run
```

Use `flutter devices` to list targets. To use the configured Android emulator:

```sh
flutter emulators --launch Medium_Phone_API_37.0
./tool/run_android.sh
```

Skip the launch command when the emulator is already running. The helper defaults to `emulator-5554`; pass a different device ID as its first argument if needed. On this Mac, it uses an ignored local Java trust store mirroring certificates macOS already trusts, fixing the Gradle download certificate error without changing system settings. Other machines without that local file use their normal Java configuration.

The helper also uses `--no-dds` because this Mac's Flutter DDS service fails to start. Flutter connects directly to the Dart VM; hot reload remains available. The equivalent Flutter command is `flutter run --no-dds -d emulator-5554` with the local Java trust settings applied. Android and iOS are the main targets.

## Implemented

- First-run name, training goal, experience, units and optional starting weight, stored locally. A name is required; the profile can be edited in Settings.
- Original lime barbell launcher icon, including Android adaptive/round/themed layers and matching platform icon catalogues. The widget and notification use the same mark.
- Home starts the timer and immediately opens the exercise selector. Resume opens the existing logger.
- Automatic local draft saves, set editing, history, finish/discard and restart recovery. Save & start new archives all current sets, including unfinished sets, and starts the next draft atomically.
- Android home-screen widget and workout notification show elapsed time and the current exercise. The widget uses a timer-first layout with the app mark, LIVE/DRAFT/READY status, one thin set-progress bar and a discreet Resume/Open action. Each instance adapts independently when resized. Existing widgets refresh in place after an app update. Tap either live display to resume the existing workout. Current exercise follows active logging; historical edits do not change it. Add the widget and enable notifications from Settings → Live workout.
- An offline catalogue of 701 exercises and 1,217 unique flat WebP illustrations, with search and muscle filters. Every exercise includes its upstream instructions; source IDs bind the text and images.
- Exercise details show manually selected, labelled still poses above the description, instructions and tips: Start/Peak when supplied, or Position for a single pose. Settings has a compact Sources & licenses card with the required linked credit and the complete license available offline. Exercise source details retain provenance and source links. See `../docs/exercise-sources.md`.
- Private camera/gallery photos on saved workouts, replace/remove, failed-save safety and lost-picker recovery.
- Saved workouts have a Share workout action. Preview an original 1080 × 1920 Story or 1080 × 1080 Square PNG, optionally include your saved workout photo, then choose a destination in the phone's share sheet. Sharing uses completed-set stats and does not add your profile, change records or post automatically.
- History's download button and Settings offer a readable workout CSV: Workout #, Workout, Date, Start time, Duration, Exercise, Set, Weight, Unit, Reps, Completed. Weights use the selected display unit.
- Separate versioned Backup CSV and import with full validation and merge confirmation. Existing IDs/preferences/drafts are preserved; conflicting record IDs reject the import atomically. Photos and profile are explicitly excluded from CSV backup.
- Per-exercise Top weight, Volume and Reps charts with dated workout selection and 4-week, 12-week and All time ranges. Progress uses completed sets in finished workouts, with exact legacy movement aliases. Edits, deletions and kg/lb settings update these views.
- Exercise details put Add to workout first, then the illustration and form cues, with progress at the bottom. The exercise list also has a graph shortcut for each movement. Full graph opens date ranges and workout history; unlogged movements explain how to record their first point.
- Adding an exercise prefills fresh, unchecked sets from its previous completed workout, excluding future and unfinished sessions. Matching field values are labelled Same as last; changed values are labelled Your entry. Existing drafts and historical records retain their values. Weights remain exact in canonical kg when displayed in either kg or lb.
- Workout consistency explains how often you train, with a Monday-first monthly calendar, highlighted training days, separate workout/day counts, month browsing and Today. Select a date to open its saved workouts. Only saved sessions with completed sets mark activity. An expandable eight-week chart explains its Monday–Sunday counts and the partial current week.
- Body-weight charts, weight history and kg/lb settings.
- Short entry/transitions respecting reduced-motion preferences, with immediate access to controls.
- Updates are distributed through Google Play and follow the user's Play Store update settings.

## Android live displays

Android renders the widget and notification chronometers, so elapsed time does not need per-second background app work. The original saved start timestamp is retained across app restarts. The widget uses the app’s charcoal/lime palette and a minimum resize width of 250dp. The notification has a compact exercise/timer row; expanding it reveals a larger timer, workout name, set-progress bar and a native Resume workout action. Notification text follows the system light/dark theme. Details on a locked phone follow Android privacy settings; the public version shows a generic workout message and timer. Permission denial leaves logging and the home-screen widget usable.

Home-screen widgets stay placed until the user removes them. A normal app finish marks the display as unfinished and removes the notification; ordinary backgrounding keeps it live. Force-stop removes Android notifications, and system termination may skip lifecycle callbacks, so a widget can retain its cached appearance until refreshed. Draft recovery never depends on those callbacks: records are saved independently. The next app launch republishes authoritative data. The native cache contains display details only and is not a workout backup.

## Structure

- `lib/app`: bootstrap, named GetX routes, shell, workout state and serialized mutations.
- `lib/core`: visual tokens, shared components and unit/date formatting.
- `lib/data`: immutable records, schema migration, generated exercise catalogue and transactional Sembast persistence.
- `lib/features`: Home, workout, library, history, progress and settings screens.
- `test`: domain/persistence, controller and UI regression tests.

Data writes complete before the reactive snapshot is published. Save failures retain the previous state and report an error. Draft timing uses the original start timestamp, so leaving the app does not reset the elapsed time. Native storage uses the app support directory; web uses IndexedDB. Clearing/uninstalling the app can remove records.

## Check

```sh
flutter analyze
flutter test
./tool/test_android.sh emulator-5554
```

The suite covers required-name onboarding, complete workout navigation, migration and restart persistence, failure recovery, concurrent writes, exact unit precision, readable CSV and backup roundtrips, photo recovery, offline exercise images and pose selection, catalogue coverage and source mappings, required credit and license reading, historical workout IDs, exercise identity/aggregation and previous-session boundaries, chart ranges and selection, sharing image dimensions/privacy/error handling, pending edits before sharing, GetX route disposal, large text and small screens. Android tests host compact and expanded widgets, exercise artwork/fallback, resize and independent instances, timers and unfinished/idle states.

## Releasing updates

See `../docs/releasing.md`. Version `1.0.0+1` is the first release; increment the build number for each Play upload. Release identity is com.savagecarol.dumbbell; signed builds use private local release signing. Run ./tool/build_release.sh to create validated APK/AAB artifacts. Debug builds install separately as Dumbbell Dev. Public policy hosting and Play Console/testing gates are documented before publication.

## App icon source

Edit `assets/branding/liftlog-icon.svg`, then regenerate the platform catalogues:

```sh
python3 -m pip install -r tool/requirements-icons.txt
python3 tool/generate_app_icons.py
python3 tool/generate_app_icons.py --check
```

The generator also emits Android adaptive/monochrome layers, the widget mark, the notification silhouette and a 512px Play Store PNG. iOS catalogue images are opaque RGB. These tools are only needed when changing the icon; normal app builds use the generated files.

## Sources & licenses

[Exercise data by RepDB (repdb.co)](https://repdb.co). The bundled exercise data and illustrations use the RepDB Free license, available in Settings and `assets/exercises/licenses/REPDB-FREE-LICENSE.md`.
