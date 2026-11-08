# Dumbbell — Play Store image pack

## Files

- `phone-screenshots/`: six 1080×1920 RGB PNG listing images in the intended order.
- `feature-graphic-1024x500.png`: 1024×500 RGB PNG feature graphic.
- `overview.png`: contact sheet for review, not a listing upload.
- `raw/`: real Flutter-rendered screen captures at 1080×2160, with isolated example records for Alex.
- `source/`: editable SVG layouts and the Instrument Sans fonts/OFL license.
- `asset-manifest.json`: dimensions and suggested alt text.

## Provenance

The Adobe connector is disabled by this workspace's administrator. These files were created locally with actual app widgets and SVG layouts; no Adobe editing or cloud upload occurred.

The preview uses in-memory example workouts, dates and body-weight entries. It never reads or writes the app's on-device records. The screenshot UI is the app's own Home, Workout, Exercises, exercise-details sheet, Exercise progress and Progress/calendar screens. Decorative phone framing and feature captions sit outside the app screenshots. Exercise illustrations remain inside their actual app views; they are not reused as separate promotional artwork.

## Upload

Use the six files in `phone-screenshots/` under Phone screenshots in Play Console. Use the separate 1024×500 image for Feature graphic. The overview and raw captures are review/source material. The images are static, opaque PNGs. Review the examples and captions against the final shipped app before submission.

Dimensions follow Google's preview-asset guidance: https://support.google.com/googleplay/android-developer/answer/9866151?hl=en-GB

## Rebuild

From `workout_app`, run `flutter test tool/store_assets/capture_test.dart --timeout 30s`, then run `node tool/store_assets/render.mjs`. Rendering dependencies are confined to `tool/store_assets`; `npm ci --prefix tool/store_assets --registry=https://registry.npmjs.org` restores them. The capture preview expects the existing local Flutter SDK fonts and the design tool expects the font files bundled under `store-assets/source/fonts` after first generation.
