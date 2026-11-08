# V1 requested feature completion

**Goal:** Add local photos, useful downloads, an expanded media exercise library, optional first-run profile and motion, and constrain new workout creation to Home.
**Architecture:** Retain GetX application controller/routes and transactional repository. Migrate schema1 to schema2 for profile/onboarding/photo metadata without losing existing records. Catalogue is a bundled snapshot; media may be explicitly cached for offline use. Native photo/file pickers preserve privacy and scoped storage.
**Spec and task contracts:** ../../next-features-contracts.md

- [x] Root: backward-compatible models, transactional controller APIs, profile route/bootstrap, shared motion, dependencies and native configuration.
- [x] Exercise agent: source/license review, expanded stable-ID catalogue, browse images, attributed actual video player and individual offline downloads.
- [x] Profile agent: optional onboarding and editing, local personalisation and Home entry motion.
- [x] Photos/export agent: durable local photo picker/display/recovery and CSV save/import with validation/confirmation.
- [x] Root: make every non-Home entry route return to Home to create a session; Settings integration and native emulator relaunch.
- [x] Validate: schema migration, photo failure/recovery, CSV roundtrip/invalid input, onboarding/skip, Home-only starts, library media/download lifecycle, reduced motion and small screens. Analyze, targeted tests, native debug build and independent review.

Media coverage must be accurate. Do not represent still images as videos or claim every external record has a demonstration. Keep source/license attribution and document source coverage limitations. CSV export and offline demonstration downloads are both being implemented while the optional download clarification is pending.

## Final validation

`flutter analyze --no-pub`: no issues. `flutter test --no-pub --machine`: 104 tests passed. Formatting checked all 80 Dart source/test files with no changes. Independent review findings on startup photo recovery, global import ID conflicts and attachment cleanup are resolved and regression tested. Native Android debug build/install succeeded; normal lib/main.dart is running on emulator-5554. Real video_player initialization/play succeeded for both bundled clips: bench_press (640×352, 15.849s) and wger_659 (1920×1080, 15.033s). Native picker dialogs remain for interactive user verification.
