#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

# This optional, ignored local file mirrors certificates already trusted by
# macOS. It keeps this Mac's Java certificate workaround scoped to this launch.
trust_store="$project_dir/.dart_tool/local-android/macos-truststore.p12"
if [[ "$(uname -s)" == "Darwin" && -f "$trust_store" ]]; then
  export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Djavax.net.ssl.trustStore=\"$trust_store\" -Djavax.net.ssl.trustStoreType=PKCS12 -Djavax.net.ssl.trustStorePassword=changeit"
fi

exec flutter run --no-dds -d "${1:-emulator-5554}" "${@:2}"
