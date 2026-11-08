# Exercise sources and licenses

LiftLog bundles the complete RepDB Free catalogue: **701 exercises and 1,217 unique flat WebP illustrations**. Exercise search, descriptions, instructions, tips and images work offline. Poses are still images selected manually: **Start** and **Peak** when the source supplies a pair, or **Position** for a single pose.

Settings keeps the required linked credit [Exercise data by RepDB (repdb.co)](https://repdb.co) in a compact Sources & licenses card with **Read license**. The movement library focuses on browsing and search. Each exercise's Sources & license section retains its attribution, artwork provenance and upstream record at `https://exercise-dataset.com/exercise/<sourceId>/`.

## Source identity and provenance

The importer uses upstream exercise IDs to bind English names, muscle groups, equipment, descriptions, all instructions, tips and illustration paths. It does not match exercises by similar names or substitute artwork from a related movement. Source image aliases are retained; multiple records can reference the same image, so the number of pose references can exceed the number of unique bundled files.

App catalogue IDs are namespaced as `repdb_<sourceId>`. The source ID remains available separately for provenance and source links. Each upstream record appears once, with common lifts first and the rest sorted by name.

The pinned source URLs, SHA-256 input hashes, import provenance and coverage are recorded in `workout_app/assets/exercises/repdb/manifest.json`. Generated definitions live in `workout_app/lib/data/exercise_catalog.g.dart`. Only the flat images referenced by the free catalogue are bundled under `workout_app/assets/exercises/repdb/flat/`.

## License and artwork

The exact RepDB Free license is bundled at `workout_app/assets/exercises/licenses/REPDB-FREE-LICENSE.md`. **Read license** in Settings or exercise source details opens that complete local text without a network request. If the file cannot be loaded, the app reports that it is unavailable and displays the source URL.

RepDB identifies the illustrations as **AI-generated artwork commissioned by RepDB**. That provenance appears in exercise source details. The app preserves the supplied flat WebP files and uses contain sizing. It includes no premium evaluation assets.

The catalogue has no video playback or exercise-image download features. All illustrations ship with the app, with no remote image fallback or automatic pose animation.

## Existing workout records

The catalogue replacement does not migrate or rewrite saved workouts or drafts. Those records retain their own exercise IDs, names, sets and units. Historical entries, including original and `wger_` IDs, remain readable, editable and exportable even though those IDs are outside the active catalogue. New selections use RepDB IDs.

## Reproduction and verification

The import tooling is `workout_app/tool/import_repdb_catalog.py`. It validates the pinned source, unique IDs, nonempty instructions, source-bound image paths, static WebP signatures and complete local asset coverage before generating the catalogue and manifest. Reproduce the import using source inputs matching the hashes recorded in the manifest; run the tool with `--help` for its input arguments.

From `workout_app/`, validate the integration with:

```sh
flutter analyze --no-pub
flutter test --no-pub
```

Catalogue tests check the full exercise count, unique source IDs, all referenced assets and representative source mappings. UI tests cover offline images, paired and single poses, credit links and the exact local license. Persistence and CSV tests cover historical exercise IDs. Representative squat, bench, deadlift, row and cable artwork is also reviewed visually against the corresponding source record.
