#!/bin/bash

# Take iOS App Screenshots
# This script runs integration tests to capture screenshots of all app screens
#
# Usage: ./scripts/take_ios_screenshots.sh [device]
#
# Examples:
#   ./scripts/take_ios_screenshots.sh                    # Use default iPhone 15 Pro
#   ./scripts/take_ios_screenshots.sh "iPhone 15"        # Use iPhone 15
#   ./scripts/take_ios_screenshots.sh "iPhone SE"        # Use iPhone SE

set -e

# Configuration
DEFAULT_DEVICE="iPhone 15 Pro"
DEVICE="${1:-$DEFAULT_DEVICE}"
SCREENSHOTS_DIR="screenshots"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Recipe Ripper - iOS Screenshot Capture${NC}"
echo "========================================"
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script must be run on macOS${NC}"
    echo "iOS simulators are only available on macOS"
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Error: Flutter is not installed or not in PATH${NC}"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcrun &> /dev/null; then
    echo -e "${RED}Error: Xcode command line tools are not installed${NC}"
    echo "Run: xcode-select --install"
    exit 1
fi

# Find the simulator
echo -e "${YELLOW}Looking for simulator: ${DEVICE}${NC}"
SIMULATOR_ID=$(xcrun simctl list devices available | grep "$DEVICE" | head -1 | grep -oE '[A-F0-9-]{36}')

if [ -z "$SIMULATOR_ID" ]; then
    echo -e "${RED}Error: Could not find simulator '${DEVICE}'${NC}"
    echo ""
    echo "Available simulators:"
    xcrun simctl list devices available | grep -E "iPhone|iPad" | head -20
    exit 1
fi

echo -e "${GREEN}Found simulator: ${SIMULATOR_ID}${NC}"
echo ""

# Boot the simulator if needed
SIMULATOR_STATE=$(xcrun simctl list devices | grep "$SIMULATOR_ID" | grep -oE '\(Booted\)' || true)
if [ -z "$SIMULATOR_STATE" ]; then
    echo -e "${YELLOW}Booting simulator...${NC}"
    xcrun simctl boot "$SIMULATOR_ID"
    sleep 5
fi

# Open Simulator app
open -a Simulator

# Wait for simulator to be ready
echo -e "${YELLOW}Waiting for simulator to be ready...${NC}"
sleep 3

# Create screenshots directory
mkdir -p "$SCREENSHOTS_DIR"

# Get Flutter dependencies
echo -e "${YELLOW}Getting Flutter dependencies...${NC}"
flutter pub get

# Run the integration test
echo ""
echo -e "${GREEN}Running screenshot tests...${NC}"
echo "This will capture screenshots of all app screens"
echo ""

flutter test integration_test/screenshot_test.dart -d "$SIMULATOR_ID" --no-pub

# Check results
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}Screenshots captured successfully!${NC}"
    echo ""
    echo "Screenshots saved to: $SCREENSHOTS_DIR/"
    echo ""
    ls -la "$SCREENSHOTS_DIR"/*.png 2>/dev/null || echo "No screenshots found in directory"
else
    echo ""
    echo -e "${RED}Screenshot capture failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Done!${NC}"
