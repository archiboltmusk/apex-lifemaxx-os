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
echo -e "${COLOR_CYAN}${COLOR_BOLD}   🍏 APEX — Native iOS App, Vision & HealthKit Compiler             ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}======================================================================${COLOR_RESET}"

APP_BUNDLE="APEX_iOS.app"

# Step 1: Clean & Generate AppIcon + LaunchBackground Asset Catalog
echo -e "\n${COLOR_YELLOW}[1/6] Generating AppIcon & Asset Catalog...${COLOR_RESET}"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE"

if [ ! -f "ios_app/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" ]; then
    swift ios_app/generate_ios_icon.swift
fi

xcrun actool ios_app/Assets.xcassets \
    --compile "$APP_BUNDLE" \
    --platform iphonesimulator \
    --minimum-deployment-target 17.0 \
    --app-icon AppIcon \
    --output-partial-info-plist /tmp/apex_ios_assets_info.plist > /dev/null

echo -e "${COLOR_GREEN}  ✓ Compiled Assets.car & AppIcon cleanly${COLOR_RESET}"

# Step 2: Prepare Simulator HealthKit Entitlements Section
echo -e "\n${COLOR_YELLOW}[2/6] Configuring Simulator HealthKit Entitlements...${COLOR_RESET}"
SIM_ENTITLEMENTS="/tmp/apex_ios_sim_entitlements.plist"
cat << 'EOF' > "$SIM_ENTITLEMENTS"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>application-identifier</key>
    <string>APEXOS0001.club.apex.lifemaxx.ios</string>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.background-delivery</key>
    <true/>
</dict>
</plist>
EOF

# Step 3: Compile Swift & SwiftUI Sources for iOS Simulator
echo -e "\n${COLOR_YELLOW}[3/6] Compiling Native SwiftUI, Vision & HealthKit Binary...${COLOR_RESET}"
xcrun --sdk iphonesimulator swiftc \
    -target arm64-apple-ios17.0-simulator \
    -framework SwiftUI \
    -framework HealthKit \
    -framework AVFoundation \
    -framework Vision \
    -framework PhotosUI \
    -framework Combine \
    -framework CoreImage \
    -parse-as-library \
    -O \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __entitlements -Xlinker "$SIM_ENTITLEMENTS" \
    ios_app/DesignSystem.swift \
    ios_app/HealthKitManager.swift \
    ios_app/ActivityRingsView.swift \
    ios_app/FaceScanView.swift \
    ios_app/CameraWorkoutView.swift \
    ios_app/LongevityView.swift \
    ios_app/SummaryView.swift \
    ios_app/ContentView.swift \
    ios_app/APEXApp.swift \
    -o "$APP_BUNDLE/APEX_iOS"

echo -e "${COLOR_GREEN}  ✓ Mach-O iOS binary compiled: $APP_BUNDLE/APEX_iOS${COLOR_RESET}"

# Step 4: Merge Info.plist with Compiled Asset Icon Keys & Codesign
echo -e "\n${COLOR_YELLOW}[4/6] Bundling Info.plist & Signing App Bundle...${COLOR_RESET}"
cp "ios_app/Info.plist" "$APP_BUNDLE/Info.plist"
python3 -c "
import plistlib
with open('$APP_BUNDLE/Info.plist', 'rb') as f:
    main_plist = plistlib.load(f)
with open('/tmp/apex_ios_assets_info.plist', 'rb') as f:
    asset_plist = plistlib.load(f)
for k, v in asset_plist.items():
    main_plist[k] = v
with open('$APP_BUNDLE/Info.plist', 'wb') as f:
    plistlib.dump(main_plist, f)
"

codesign --force --sign - "$APP_BUNDLE"
codesign -v "$APP_BUNDLE"
echo -e "${COLOR_GREEN}  ✓ $APP_BUNDLE packaged & signed cleanly!${COLOR_RESET}"

# Step 5: Create Standalone Distribution Archive
echo -e "\n${COLOR_YELLOW}[5/6] Packaging APEX-OS-iOS.zip...${COLOR_RESET}"
ZIP_NAME="APEX-OS-iOS.zip"
rm -f "$ZIP_NAME"
zip -q -r -y "$ZIP_NAME" "$APP_BUNDLE"
ZIP_SIZE=$(ls -lh "$ZIP_NAME" | awk '{print $5}')
echo -e "${COLOR_GREEN}  ✓ iOS distribution archive created: $ZIP_NAME ($ZIP_SIZE)${COLOR_RESET}"

# Step 6: Install & Launch on iOS Simulator
echo -e "\n${COLOR_YELLOW}[6/6] Checking Booted iOS Simulator...${COLOR_RESET}"
BOOTED_ID=$(xcrun simctl list devices booted | grep -o -E "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}" | head -n 1)

if [ -z "$BOOTED_ID" ]; then
    BOOTED_ID=$(xcrun simctl list devices available | grep -E "iPhone 18 Pro|iPhone 17 Pro|iPhone 16 Pro" | head -n 1 | grep -o -E "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}")
    if [ -n "$BOOTED_ID" ]; then
        xcrun simctl boot "$BOOTED_ID" 2>/dev/null || true
    fi
fi

if [ -n "$BOOTED_ID" ]; then
    echo -e "  Target Simulator: $BOOTED_ID"
    xcrun simctl uninstall "$BOOTED_ID" club.apex.lifemaxx.ios 2>/dev/null || true
    xcrun simctl install "$BOOTED_ID" "$APP_BUNDLE"
    xcrun simctl launch "$BOOTED_ID" club.apex.lifemaxx.ios
    open -a Simulator 2>/dev/null || true
    echo -e "${COLOR_GREEN}  ✓ Successfully installed & launched on iOS Simulator!${COLOR_RESET}"
else
    echo -e "  (Simulator launch skipped: no offline iPhone simulator found)"
fi

echo -e "\n${COLOR_GREEN}${COLOR_BOLD}======================================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}${COLOR_BOLD}   🎉 iOS APP BUILD & LAUNCH COMPLETE!                               ${COLOR_RESET}"
echo -e "${COLOR_GREEN}${COLOR_BOLD}======================================================================${COLOR_RESET}"
echo -e "• iOS App Bundle : ${COLOR_BOLD}$PROJECT_DIR/$APP_BUNDLE${COLOR_RESET}"
echo -e "• Standalone Zip : ${COLOR_BOLD}$PROJECT_DIR/$ZIP_NAME${COLOR_RESET}\n"
