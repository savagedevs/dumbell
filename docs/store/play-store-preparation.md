# Dumbbell — Play Store preparation

Updated 8 November 2026. The listing and declarations below were submitted with the version 1 production release; Google review is pending.

## Listing

- Name: Dumbbell
- Category: Health & Fitness
- Contact/support/privacy email: svgcarol@gmail.com
- Website: https://designingsystems.dev/app/dumbbell
- Privacy policy: https://designingsystems.dev/app/dumbbell/privacy
- Package: com.savagecarol.dumbbell
- Short description: Log workouts, track your progress and keep your training records offline.

### Full description

Dumbbell is a free, offline workout journal. Start a workout, choose exercises, and record your sets, repetitions and weights in kilograms or pounds. Your previous completed sets help you prepare the next session, while every new set stays unchecked until you complete it.

Track how your training changes with exercise charts, body-weight history and a calendar of training days. Browse 701 exercises with bundled illustrations and instructions, review and edit saved workouts, and resume unfinished sessions.

Add an optional workout photo and preview a square or story summary before sharing through your phone's share sheet. Export readable workout CSV files, or save and import a Backup CSV to restore workout records. Photos and profile details are not included in CSV backups.

An optional home-screen widget and workout notification show elapsed time and the current exercise. No account, advertising or subscription is required. Training records, profile details and attached photos stay in private storage on your device. Export backups regularly: uninstalling or losing the device can remove local records.

Exercise illustrations are provided by RepDB and are AI-generated. Exercise information is for general fitness. Dumbbell is not a medical device and does not diagnose, treat, cure, or prevent any medical condition.

## Declaration preparation

- App access: all core functionality is accessible without an account or login. The first-run name is a local profile, not an online account. No reviewer credentials are required.
- Ads: no advertising SDK or ads are included.
- Health apps: declare fitness/workout tracking as applicable to the actual form. This is general exercise logging, not medical diagnosis or treatment. No Health Connect, sensor or medical-device integration is present.
- Data safety: the current app has no developer server, telemetry, advertising, analytics or automatic crash-upload integration, and the Android release has no internet permission. Profile, workout, body-weight and selected photo data are processed locally. Google does not define on-device-only access as collection when it is not transmitted off-device. Exports and sharing occur only through explicit user actions; review the form's user-initiated transfer exception against the exact distribution. Do not copy these answers to a later build if SDKs/data flows change. [Official definitions](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en-en)
- Account deletion: no online accounts can be created. Users can remove individual records/photos in-app or clear app storage/uninstall to delete all private data. Previously exported/shared copies remain at their destinations.
- Permissions: optional notifications only, plus the AndroidX internal signature-protected receiver permission. Files/photos/camera use system selection/capture flows. The artifact verifier rejects unexpected permissions.
- Privacy: the public policy is hosted at https://designingsystems.dev/app/dumbbell/privacy. In-app full text is bundled offline and includes svgcarol@gmail.com. Update the effective date if data practices change.
- Content rating and target audience: questionnaire completed. Owner selected ages 13 and older; this audience declaration is included in the review submission.
- Advertising ID: no use declared, consistent with the audited dependencies and merged release permissions.

## Assets and submission gates

- Launcher icon: `workout_app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (device asset); use the generated 512px marketing icon under `workout_app/assets/branding/` for the store after inspecting it.
- Six phone screenshots and the 1024×500 feature graphic from `store-assets/` are attached. Screenshots 03 and 04 are labeled for their AI-generated exercise illustrations.
- Public policy URL: https://designingsystems.dev/app/dumbbell/privacy (verified publicly accessible).
- App registration and Play App Signing are configured. Console accepted the production submission without a closed-testing access gate.
- Physical-device installation was not independently verified by this publishing workflow.
- The account-level "Declare your trader status" banner remains visible; this workflow did not choose a legal trader status on the owner's behalf.

Version 1.0.0 (1) remains available on the internal testing track for karthiksharma1411@gmail.com. The same bundle was promoted to production as "1.0.0 (1) - First release". All 178 availability entries were selected (177 named countries/regions plus rest of world). The production release, listing, privacy policy and declarations were submitted together. Console shows "Changes in review" with quick checks still running. Managed publishing is off, so approved changes are configured to publish automatically. Public availability is not yet verified.
