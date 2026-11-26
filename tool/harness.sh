#!/usr/bin/env bash
# Run the app's real URL → recipe pipeline on a simulator or device, with no UI.
#
#   tool/harness.sh <url> [device-id]
#
# With no device id it uses the first booted iOS simulator. The report is
# printed and saved to harness_runs/<video-id>/<timestamp>.json. Put a Python
# CLI run (its Markdown output) at integration_test/references/<video-id>.md
# to compare ingredients against it.
set -euo pipefail

url="${1:?usage: tool/harness.sh <url> [device-id]}"
device="${2:-}"

if [[ -z "$device" ]]; then
  device="$(xcrun simctl list devices booted | grep -Eo '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -1 || true)"
  if [[ -z "$device" ]]; then
    echo "No booted iOS simulator. Boot one, or pass a device id (see 'flutter devices')." >&2
    exit 1
  fi
fi

target=integration_test/pipeline_harness_test.dart
driver=test_driver/integration_test.dart
cd "$(dirname "$0")/.."

# Simulators run debug builds.
if xcrun simctl list devices | grep -q "$device"; then
  exec flutter drive \
    --driver="$driver" --target="$target" -d "$device" \
    --dart-define=VIDEO_URL="$url"
fi

# On a physical iPhone, use a profile build. A debug build there needs Xcode
# to attach a debugger (iOS 17+), which Flutter starts through macOS
# Automation and can hang on a white screen. Profile is also closer to the
# shipped app (AOT-compiled). flutter drive --profile builds the app but then
# can't find it, so build with flutter build ios first and hand flutter drive
# the binary. Keep the phone unlocked: a locked phone fails the launch, and
# locking it mid-run slows transcription badly.
flutter build ios --profile --target="$target" --dart-define=VIDEO_URL="$url"
app=build/ios/iphoneos/Runner.app  # where flutter build ios puts it
if [[ ! -d "$app" ]]; then
  echo "Built, but $app is missing." >&2
  exit 1
fi
exec flutter drive --profile --use-application-binary="$app" \
  --driver="$driver" --target="$target" -d "$device" \
  --dart-define=VIDEO_URL="$url"
