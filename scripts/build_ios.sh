#!/usr/bin/env bash
set -e

# ==============================================================================
# APEX // OS — Real-Time iOS App Compiler & Simulator Launcher
# ==============================================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

COLOR_CYAN="\033[0;36m"
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_RED="\033[0;31m"
COLOR_BOLD="\033[1m"
COLOR_RESET="\033[0m"

echo -e "${COLOR_CYAN}${COLOR_BOLD}======================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}   🍏 APEX // OS — Native iOS App & HealthKit Real-Time Compiler     ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}======================================================================${COLOR_RESET}"

SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)
APP_BUNDLE="APEX_iOS.app"

# Step 1: Clean & Prep
echo -e "\n${COLOR_YELLOW}[1/5] Initializing iOS App Structure...${COLOR_RESET}"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE"

# Step 2: Compile Swift Sources for iOS Target
echo -e "\n${COLOR_YELLOW}[2/5] Compiling Swift & SwiftUI Sources (HealthKit.framework)...${COLOR_RESET}"
xcrun swiftc \
    -sdk "$SDK_PATH" \
    -target arm64-apple-ios17.0-simulator \
    -framework SwiftUI \
    -framework HealthKit \
    -framework AVFoundation \
    -framework Combine \
    -parse-as-library \
    -O \
    ios_app/HealthKitManager.swift \
    ios_app/ActivityRingsView.swift \
    ios_app/CameraWorkoutView.swift \
    ios_app/ContentView.swift \
    ios_app/APEXApp.swift \
    -o "$APP_BUNDLE/APEX_iOS"

echo -e "${COLOR_GREEN}  ✓ Mach-O iOS binary compiled: $APP_BUNDLE/APEX_iOS${COLOR_RESET}"

# Step 3: Bundle Metadata & Entitlements
echo -e "\n${COLOR_YELLOW}[3/5] Bundling Info.plist & Signing with HealthKit Entitlements...${COLOR_RESET}"
cp "ios_app/Info.plist" "$APP_BUNDLE/Info.plist"

codesign --force --sign - --entitlements ios_app/APEX_iOS.entitlements "$APP_BUNDLE"
codesign -v "$APP_BUNDLE"
echo -e "${COLOR_GREEN}  ✓ $APP_BUNDLE packaged and codesigned successfully!${COLOR_RESET}"

# Step 4: Create Standalone Distribution Archive
echo -e "\n${COLOR_YELLOW}[4/5] Packaging APEX-OS-iOS.zip...${COLOR_RESET}"
ZIP_NAME="APEX-OS-iOS.zip"
rm -f "$ZIP_NAME"
zip -q -r -y "$ZIP_NAME" "$APP_BUNDLE"
ZIP_SIZE=$(ls -lh "$ZIP_NAME" | awk '{print $5}')
echo -e "${COLOR_GREEN}  ✓ iOS distribution archive created: $ZIP_NAME ($ZIP_SIZE)${COLOR_RESET}"

# Step 5: Boot Simulator & Install (if Simulator available)
echo -e "\n${COLOR_YELLOW}[5/5] Checking iOS Simulator Device...${COLOR_RESET}"
SIM_ID=$(xcrun simctl list devices available | grep -E "iPhone 18 Pro|iPhone 17 Pro" | head -n 1 | grep -o -E "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}")

if [ -n "$SIM_ID" ]; then
    echo -e "  Target Simulator: $SIM_ID"
    xcrun simctl boot "$SIM_ID" 2>/dev/null || true
    echo -e "  Installing $APP_BUNDLE to Simulator..."
    xcrun simctl install "$SIM_ID" "$APP_BUNDLE"
    echo -e "${COLOR_GREEN}  ✓ Successfully installed to iOS Simulator!${COLOR_RESET}"
    echo -e "  Launching APEX OS on iOS Simulator..."
    xcrun simctl launch "$SIM_ID" club.apex.lifemaxx.ios 2>/dev/null || true
    open -a Simulator 2>/dev/null || true
else
    echo -e "  (Simulator boot skipped: no offline simulator ID found)"
fi

echo -e "\n${COLOR_GREEN}${COLOR_BOLD}======================================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}${COLOR_BOLD}   🎉 iOS APP BUILD COMPLETE!                                        ${COLOR_RESET}"
echo -e "${COLOR_GREEN}${COLOR_BOLD}======================================================================${COLOR_RESET}"
echo -e "• iOS App Bundle : ${COLOR_BOLD}$PROJECT_DIR/$APP_BUNDLE${COLOR_RESET}"
echo -e "• Standalone Zip : ${COLOR_BOLD}$PROJECT_DIR/$ZIP_NAME${COLOR_RESET}"
echo -e "• Real-Time Sync : Automatic broadcast to Mac App at http://127.0.0.1:5174/api/healthkit-sync\n"
