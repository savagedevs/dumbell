# Android release preparation

User requested a shareable APK and preparation for a later Play Store launch.

## Deliverables

- Signed, optimized universal APK for direct installation, plus signed AAB for Play Console testing.
- User-selected Android identity `com.savagecarol.dumbbell` and display name Dumbbell. Keep the existing development installation intact.
- Private signing key and ignored signing properties. Release builds must fail rather than silently use a debug certificate when signing credentials are missing.
- Explicit offline release permissions, disabled Android cloud/device backups to match local-only storage, retained optional notifications and system photo/file pickers.
- In-app privacy information and open-source notices; public privacy-policy draft and Play listing/declaration preparation. Public support contact: svgcarol@gmail.com. Public policy hosting remains a later publication step.
- Reproducible release script, artifact hashes, signature/manifest/16 KB alignment checks, Flutter tests/analyzer and native regression checks.

## Tasks

- [x] Audit current release settings and current official Play/Flutter requirements.
- [x] Configure Android identity, real signing, local-data backup exclusions and minimum permissions.
- [x] Add privacy access in Settings and prepare store handoff files.
- [x] Build and validate APK/AAB, preserve signing material privately, copy only shareable binaries to `releases/`.
- [x] Record exact verification and remaining Play Console/physical-device gates.

## Review focus

Do not overwrite or uninstall the existing development application. Never expose keystore passwords in logs or distribute keys with APKs. Verify actual merged release permissions and certificate rather than source configuration alone. Keep catalogue artwork and third-party attribution accurate. Direct APK and Play signing identities must be planned together so later updates can retain user data.

Evidence: 186 Flutter tests and 5 native tests passed, analyzer clean, Android release lint 0 errors/20 warnings, signed release cold launch successful. APK/AAB certificates match and actual APK passes 16 KB zip/native alignment verification. See docs/release-readiness.md for scope and publication gates.
