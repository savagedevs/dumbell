#!/usr/bin/env bash
# Build signed distribution artifacts. Signing files are never copied.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
[[ -f android/key.properties ]] || { echo 'Restore release signing files or run python3 tool/create_release_key.py first.' >&2; exit 1; }
trust_store="$project_dir/.dart_tool/local-android/macos-truststore.p12"
if [[ "$(uname -s)" == Darwin && -f "$trust_store" ]]; then
  export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Djavax.net.ssl.trustStore=\"$trust_store\" -Djavax.net.ssl.trustStoreType=PKCS12 -Djavax.net.ssl.trustStorePassword=changeit"
fi
flutter analyze
flutter test
flutter build apk --release --dart-define-from-file=config/release.json
flutter build appbundle --release --dart-define-from-file=config/release.json
python3 tool/package_release.py
