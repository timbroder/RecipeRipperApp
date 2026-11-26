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

cd "$(dirname "$0")/.."
exec flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/pipeline_harness_test.dart \
  -d "$device" \
  --dart-define=VIDEO_URL="$url"
