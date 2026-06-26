#!/usr/bin/env bash
# Pull the on-device telemetry log from a connected device and run the analyzer.
#
# The app must be a debuggable build (debug or profile — NOT release) for
# `adb run-as` to access the app-private `databases/` dir. The live-test build
# is `flutter build apk --profile` for exactly this reason (AOT perf + debuggable).
#
# Usage:
#   tool/pull_telemetry.sh                 # auto-detect first Android device
#   tool/pull_telemetry.sh <serial>        # explicit device serial
#   tool/pull_telemetry.sh <serial> /tmp/out.log   # custom output path
set -euo pipefail

PKG="com.zmeul.retrometer"
DEV_LOG="databases/retrometer_telemetry.log"

SERIAL="${1:-}"
OUT="${2:-/tmp/retrometer_telemetry.log}"

ADB=(adb)
if [[ -n "$SERIAL" ]]; then
  ADB+=( -s "$SERIAL" )
elif [[ "$(adb devices | grep -c 'device$')" -gt 1 ]]; then
  echo "Multiple devices connected; specify a serial: tool/pull_telemetry.sh <serial>" >&2
  adb devices -l >&2
  exit 1
fi

echo "Pulling $DEV_LOG from $PKG ..."
if ! "${ADB[@]}" shell run-as "$PKG" cat "$DEV_LOG" > "$OUT" 2>/dev/null; then
  echo "run-as pull failed (is this a release/non-debuggable build?)." >&2
  exit 1
fi

if [[ ! -s "$OUT" ]]; then
  echo "Log is empty or missing — no telemetry events recorded yet." >&2
  exit 0
fi

echo "Pulled $(wc -l < "$OUT") records → $OUT"
echo "---"
dart run tool/analyze_telemetry_log.dart "$OUT"