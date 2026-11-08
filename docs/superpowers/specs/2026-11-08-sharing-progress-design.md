# Workout progress, social sharing and visual live widget

The user requested a less text-heavy live Android widget, social-media workout sharing, exercise progress charts and last-session weights when choosing/logging exercises. These finish features already in plan.md while retaining the charcoal/lime visual system and GetX routing/state.

## Exercise performance

Derive metrics from completed sets in saved sessions only. For each movement, aggregate one point per workout: highest completed-set weight (canonical kg), completed-set volume (kg × reps), total reps and completed set list. Charts use actual session dates and labelled units; one-point/no-data states remain truthful. Let users switch Top weight / Volume / Reps and inspect each point's dated session/sets. Adding a movement copies the latest strictly earlier saved session's completed sets into fresh, unchecked fields. Never compare a workout against itself or later sessions. Multiple entries of the same exercise in one saved session aggregate once. Edits/deletions/unit changes update derived views without schema changes.

Exercise-library rows expose an explicit graph shortcut. Details follow the user's requested order: Add to workout, illustration and instructions, then interactive progress at the bottom. The Full graph action opens date ranges and recorded workout details. Empty history explains how to create the first point. Graph access never adds an exercise or starts a workout.

The workout logger has no separate Last time / Progress panel. Initial weights and reps come from the previous completed workout, with Same as last hints on matching field values and Your entry on changed values. This comparison is derived without persisting duplicate source metadata. Existing drafts are never reseeded on open, rebuild or unit change; histories remain immutable. Source values stay in canonical kg, and copied sets do not count toward progress until checked complete. With no previous result, retain the existing 0 kg / 8 reps starter set.

Preserve identity by source IDs. Explicitly map the original 18 exercise IDs to verified current RepDB equivalents. CSV-recovered IDs may match a small exact known-name alias table or exact current catalogue names; do not fuzzy-match arbitrary custom IDs or variants. Unknown movements retain distinct IDs and their saved names. This allows recovered Barbell Squat, Seated Cable Row and Push-Up to participate in their correct progress histories.

## Social sharing

A Share workout action on saved workout details flushes pending changes before opening a preview. Offer Story (1080×1920) and Square (1080×1080), with a bold workout summary, date/duration, completed sets, volume and exercise highlights. Optional existing workout photo is included only when selected. Default excludes profile/name and private photo. Generate a PNG locally, then open the platform share sheet on explicit Share; no direct posting or account connection. A cancel/error leaves workouts/photos intact. Do not export RepDB artwork: the image uses original app graphics and optionally the user's own photo.

## Native widget

Keep the real Android Chronometer, tap-to-resume and idle/unfinished behavior. Introduce a completion ring and current exercise illustration for larger widget sizes, with an adaptive compact layout. Prioritize current exercise and elapsed time over a generic workout title. Ring progress follows completed/total sets, without a background animation loop. Source images remain static licensed in-app assets; unknown exercises use a neutral icon, never unrelated art. Match charcoal #10110F/#1C1E1A, lime #D5FF3F, text #F5F5EF and muted #A8ACA0. Re-render on durable state/focus/resize changes, not every second. No new foreground service or sensor permissions.

## Validation and storage

Back up emulator data before device tests. Use only tool/test_android.sh or install-in-place builds; never a test task that uninstalls the app. Verify metric identity/boundaries/units, last-time hints and navigation, share preview/export/cancel/error, small screens/large text and reduced motion. Decode actual share PNGs, inspect real UI/native widget renders and native tap/timer state. Preserve current schema, photos, drafts and IDs. No Git repository is present.
