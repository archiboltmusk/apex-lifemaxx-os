#!/bin/bash
set -euo pipefail

# Physical iOS Device (.ipa) + Embedded WidgetKit (.appex) + watchOS (.app) Builder
# Compiles genuine arm64 iPhoneOS & watchOS binaries using Xcode's iphoneos/watchos SDKs
# without requiring xcodegen, producing APEX-OS.ipa ready for Xcode, devicectl, Sideloadly, or AltStore.

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

SIGN_TEAM="${1:-}"
STAGING_DIR="$PROJECT_DIR/.ipa_build"
PAYLOAD_DIR="$STAGING_DIR/Payload"
APP_BUNDLE="$PAYLOAD_DIR/APEX_iOS.app"
WIDGET_APPEX="$APP_BUNDLE/PlugIns/APEXWidgets.appex"
WATCH_BUNDLE="$APP_BUNDLE/Watch/APEXWatch.app"
IPA_NAME="APEX-OS.ipa"
IPA_PATH="$PROJECT_DIR/$IPA_NAME"

COLOR_CYAN="\033[1;36m"
COLOR_GREEN="\033[1;32m"
COLOR_YELLOW="\033[1;33m"
COLOR_RESET="\033[0m"

echo -e "${COLOR_CYAN}======================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}   📱 APEX — Physical iPhone ARM64 Device Build (.ipa)                ${COLOR_RESET}"
echo -e "${COLOR_CYAN}======================================================================${COLOR_RESET}"

rm -rf "$STAGING_DIR" "$IPA_PATH"
mkdir -p "$APP_BUNDLE" "$WIDGET_APPEX" "$WATCH_BUNDLE" "$STAGING_DIR/watch_bin"

# 1. Compile iPhoneOS Asset Catalog & AppIcon
echo -e "\n${COLOR_YELLOW}[1/5] Compiling iPhoneOS Asset Catalog (Assets.car)...${COLOR_RESET}"
xcrun actool "$PROJECT_DIR/ios_app/Assets.xcassets" \
    --compile "$APP_BUNDLE" \
    --platform iphoneos \
    --minimum-deployment-target 17.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$STAGING_DIR/AssetInfo.plist" > /dev/null
echo -e "${COLOR_GREEN}  ✓ iPhoneOS Assets.car compiled${COLOR_RESET}"

# 2. Collect all iOS main target Swift files (excluding build helper scripts)
SWIFT_SOURCES=()
while IFS= read -r src; do
    SWIFT_SOURCES+=("$src")
done < <(find ios_app -maxdepth 1 -name '*.swift' ! -name 'generate_ios_icon.swift' | sort)
SWIFT_SOURCES+=("ios_app/Widgets/ApexWidgetIntents.swift")

# 3. Compile Physical ARM64 Main iOS Executable (iphoneos SDK)
echo -e "\n${COLOR_YELLOW}[2/5] Compiling ARM64 iPhoneOS Binary (APEX_iOS)...${COLOR_RESET}"
xcrun --sdk iphoneos swiftc \
    -O \
    -target arm64-apple-ios17.0 \
    -parse-as-library \
    -framework SwiftUI \
    -framework UIKit \
    -framework HealthKit \
    -framework AVFoundation \
    -framework Vision \
    -framework VisionKit \
    -framework ARKit \
    -framework PhotosUI \
    -framework Combine \
    -framework CoreImage \
    -framework Charts \
    -framework Network \
    -framework WidgetKit \
    -framework ActivityKit \
    -framework AppIntents \
    -framework CoreBluetooth \
    -framework CoreMotion \
    -framework CoreHaptics \
    -framework Accelerate \
    -framework RealityKit \
    -framework SoundAnalysis \
    -framework WorkoutKit \
    -framework WatchConnectivity \
    -framework UserNotifications \
    -framework PDFKit \
    -framework StoreKit \
    -Xlinker -weak_framework -Xlinker FoundationModels \
    "${SWIFT_SOURCES[@]}" \
    -o "$APP_BUNDLE/APEX_iOS"
echo -e "${COLOR_GREEN}  ✓ Physical ARM64 APEX_iOS binary built cleanly${COLOR_RESET}"

# 4. Compile WidgetKit & Live Activity Extension (iphoneos SDK)
echo -e "\n${COLOR_YELLOW}[3/5] Compiling iPhoneOS WidgetKit Extension (APEXWidgets.appex)...${COLOR_RESET}"
xcrun --sdk iphoneos swiftc \
    -O \
    -target arm64-apple-ios17.0 \
    -application-extension \
    -parse-as-library \
    -framework WidgetKit \
    -framework SwiftUI \
    -framework ActivityKit \
    -framework AppIntents \
    ios_app/ApexSharedTypes.swift \
    ios_app/Widgets/ApexWidgetIntents.swift \
    ios_app/Widgets/ApexWidgets.swift \
    -o "$WIDGET_APPEX/APEXWidgets"
echo -e "${COLOR_GREEN}  ✓ Physical ARM64 APEXWidgets.appex built cleanly${COLOR_RESET}"

# 5. Compile Universal Physical Apple Watch Companion (watchos SDK: arm64 + arm64_32)
echo -e "\n${COLOR_YELLOW}[4/5] Compiling watchOS Companion Binary (APEXWatch.app)...${COLOR_RESET}"
xcrun --sdk watchos swiftc \
    -O \
    -target arm64-apple-watchos10.0 \
    -parse-as-library \
    -framework SwiftUI \
    -framework Combine \
    -framework HealthKit \
    -framework WatchConnectivity \
    -framework WatchKit \
    ios_app/ApexSharedTypes.swift \
    ios_app/Watch/APEXWatchApp.swift \
    -o "$STAGING_DIR/watch_bin/APEXWatch_arm64"

xcrun --sdk watchos swiftc \
    -O \
    -target arm64_32-apple-watchos10.0 \
    -parse-as-library \
    -framework SwiftUI \
    -framework Combine \
    -framework HealthKit \
    -framework WatchConnectivity \
    -framework WatchKit \
    ios_app/ApexSharedTypes.swift \
    ios_app/Watch/APEXWatchApp.swift \
    -o "$STAGING_DIR/watch_bin/APEXWatch_arm64_32"

lipo -create \
    "$STAGING_DIR/watch_bin/APEXWatch_arm64" \
    "$STAGING_DIR/watch_bin/APEXWatch_arm64_32" \
    -output "$WATCH_BUNDLE/APEXWatch"
echo -e "${COLOR_GREEN}  ✓ Universal Physical watchOS APEXWatch.app (arm64 + arm64_32) built cleanly${COLOR_RESET}"

# 6. Patch Device Info.plist files for iPhoneOS & WatchOS hardware installation
echo -e "\n${COLOR_YELLOW}[5/5] Patching Device Plists, Signing & Packaging $IPA_NAME...${COLOR_RESET}"
python3 - <<PYEOF
import plistlib

def load(path):
    with open(path, 'rb') as f:
        return plistlib.load(f)

def save(path, data):
    with open(path, 'wb') as f:
        plistlib.dump(data, f)

# Main App Info.plist
app_plist = load('ios_app/Info.plist')
asset_plist = load('$STAGING_DIR/AssetInfo.plist')
app_plist.update(asset_plist)
app_plist['CFBundleSupportedPlatforms'] = ['iPhoneOS']
app_plist['DTPlatformName'] = 'iphoneos'
app_plist['DTSDKName'] = 'iphoneos'
app_plist['MinimumOSVersion'] = '17.0'
app_plist['UIDeviceFamily'] = [1, 2]
save('$APP_BUNDLE/Info.plist', app_plist)

# Widget Extension Info.plist
wid_plist = load('ios_app/Widgets/Info.plist')
wid_plist['CFBundleSupportedPlatforms'] = ['iPhoneOS']
wid_plist['DTPlatformName'] = 'iphoneos'
wid_plist['DTSDKName'] = 'iphoneos'
wid_plist['MinimumOSVersion'] = '17.0'
wid_plist['UIDeviceFamily'] = [1, 2]
save('$WIDGET_APPEX/Info.plist', wid_plist)

# Watch Companion Info.plist
watch_plist = load('ios_app/Watch/Info.plist')
watch_plist['CFBundleSupportedPlatforms'] = ['WatchOS']
watch_plist['DTPlatformName'] = 'watchos'
watch_plist['DTSDKName'] = 'watchos'
watch_plist['MinimumOSVersion'] = '10.0'
watch_plist['UIDeviceFamily'] = [4]
save('$WATCH_BUNDLE/Info.plist', watch_plist)
PYEOF

# Resolve Signing Identity (if Keychain contains Apple Development / Distribution cert)
SIGN_IDENTITY="-"
if [ -n "$SIGN_TEAM" ]; then
    MATCHED_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "$SIGN_TEAM" | head -n 1 | awk -F'"' '{print $2}' || true)
    if [ -n "$MATCHED_ID" ]; then
        SIGN_IDENTITY="$MATCHED_ID"
    fi
else
    FIRST_VALID=$(security find-identity -v -p codesigning 2>/dev/null | grep -E "Apple Development|iPhone Developer|Apple Distribution|iPhone Distribution" | head -n 1 | awk -F'"' '{print $2}' || true)
    if [ -n "$FIRST_VALID" ]; then
        SIGN_IDENTITY="$FIRST_VALID"
    fi
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
    echo -e "  Signing Mode : Ad-hoc (0 Apple signing certs in Keychain; ready for Sideloadly/AltStore/SideStore re-sign)"
    codesign --force --sign - --entitlements ios_app/Watch/APEXWatch.entitlements "$WATCH_BUNDLE"
    codesign --force --sign - --entitlements ios_app/Widgets/APEXWidgets.entitlements "$WIDGET_APPEX"
    codesign --force --sign - --entitlements ios_app/APEX_iOS.entitlements "$APP_BUNDLE"
else
    echo -e "  Signing Mode : Identity '$SIGN_IDENTITY'"
    codesign --force --sign "$SIGN_IDENTITY" --entitlements ios_app/Watch/APEXWatch.entitlements "$WATCH_BUNDLE"
    codesign --force --sign "$SIGN_IDENTITY" --entitlements ios_app/Widgets/APEXWidgets.entitlements "$WIDGET_APPEX"
    codesign --force --sign "$SIGN_IDENTITY" --entitlements ios_app/APEX_iOS.entitlements "$APP_BUNDLE"
fi

# Package standard Apple .ipa archive (top-level Payload/APEX_iOS.app)
(cd "$STAGING_DIR" && zip -q -r -y "$IPA_PATH" Payload)
rm -rf "$STAGING_DIR"

IPA_SIZE=$(ls -lh "$IPA_PATH" | awk '{print $5}')
echo -e "${COLOR_GREEN}  ✓ Physical iPhone IPA packaged cleanly: $IPA_NAME ($IPA_SIZE)${COLOR_RESET}"
