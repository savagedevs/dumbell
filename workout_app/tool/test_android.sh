#!/usr/bin/env bash
# Build and run instrumented tests without uninstalling the development app.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"
trust_store="$project_dir/.dart_tool/local-android/macos-truststore.p12"
if [[ "$(uname -s)" == "Darwin" && -f "$trust_store" ]]; then
  export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:+$JAVA_TOOL_OPTIONS }-Djavax.net.ssl.trustStore=\"$trust_store\" -Djavax.net.ssl.trustStoreType=PKCS12 -Djavax.net.ssl.trustStorePassword=changeit"
fi
if [[ -z "${JAVA_HOME:-}" && -d '/Applications/Android Studio.app/Contents/jbr/Contents/Home' ]]; then
  export JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home'
fi
(cd android && ./gradlew :app:assembleDebug :app:assembleDebugAndroidTest --console=plain)
android_sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb_tool="$android_sdk/platform-tools/adb"
device_id="${1:-emulator-5554}"
"$adb_tool" -s "$device_id" install -r build/app/outputs/apk/debug/app-debug.apk
"$adb_tool" -s "$device_id" install -r -t build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
report="$("$adb_tool" -s "$device_id" shell am instrument -w -r -e class com.savagecarol.dumbbell.LiveWorkoutInstrumentedTest com.savagecarol.dumbbell.debug.test/androidx.test.runner.AndroidJUnitRunner)"
printf '%s\n' "$report"
[[ "$report" == *'OK ('* && "$report" != *'FAILURES!!!'* ]]
