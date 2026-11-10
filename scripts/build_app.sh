#!/usr/bin/env bash
set -e

# ==============================================================================
# APEX // OS — macOS Native App & DMG Production Compiler
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
echo -e "${COLOR_CYAN}${COLOR_BOLD}   🚀 APEX // OS — Native macOS App & DMG Compilation Engine          ${COLOR_RESET}"
echo -e "${COLOR_CYAN}${COLOR_BOLD}======================================================================${COLOR_RESET}"

BUILD_DMG=true
for arg in "$@"; do
    if [ "$arg" == "--no-dmg" ]; then
        BUILD_DMG=false
    fi
done

# Step 1: Check Required Toolchain
echo -e "\n${COLOR_YELLOW}[1/6] Verifying Compilation Toolchain...${COLOR_RESET}"
for tool in node npm swiftc iconutil codesign hdiutil; do
    if ! command -v $tool &> /dev/null; then
        echo -e "${COLOR_RED}Error: Required tool '$tool' not found in PATH.${COLOR_RESET}"
        exit 1
    fi
    echo -e "  ✓ $tool detected: $(which $tool)"
done

# Step 2: Build Vite Production Assets
echo -e "\n${COLOR_YELLOW}[2/6] Building Production React & Tailwind Bundle...${COLOR_RESET}"
npm run build
if [ ! -f "dist/index.html" ]; then
    echo -e "${COLOR_RED}Error: dist/index.html was not generated!${COLOR_RESET}"
    exit 1
fi
echo -e "${COLOR_GREEN}  ✓ Production bundle built successfully in dist/${COLOR_RESET}"

# Step 3: Ensure AppIcon.icns Exists
echo -e "\n${COLOR_YELLOW}[3/6] Generating macOS App Icon...${COLOR_RESET}"
if [ ! -f "mac_app/AppIcon.icns" ]; then
    swift mac_app/generate_icon.swift
    iconutil -c icns mac_app/AppIcon.iconset -o mac_app/AppIcon.icns
fi
echo -e "${COLOR_GREEN}  ✓ macOS icon generated: mac_app/AppIcon.icns${COLOR_RESET}"

# Step 4: Compile Native Swift Mach-O Binary
echo -e "\n${COLOR_YELLOW}[4/6] Compiling Native Apple Silicon Executable (Swift 5.10+)...${COLOR_RESET}"
swiftc -O \
    -target arm64-apple-macos12.0 \
    -framework Cocoa \
    -framework WebKit \
    mac_app/main.swift \
    -o "mac_app/APEX OS"
echo -e "${COLOR_GREEN}  ✓ Mach-O binary compiled: mac_app/APEX OS${COLOR_RESET}"

# Step 5: Assemble & Sign APEX OS.app Bundle
echo -e "\n${COLOR_YELLOW}[5/6] Assembling macOS Application Bundle...${COLOR_RESET}"
APP_BUNDLE="APEX OS.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "mac_app/APEX OS" "$APP_BUNDLE/Contents/MacOS/APEX OS"
chmod +x "$APP_BUNDLE/Contents/MacOS/APEX OS"
cp "mac_app/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "mac_app/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp -R dist/ "$APP_BUNDLE/Contents/Resources/dist"

echo -e "  Applying Camera/Microphone Entitlements & Ad-hoc Signature..."
codesign --force --deep --sign - --entitlements mac_app/APEX_OS.entitlements "$APP_BUNDLE"
codesign -v "$APP_BUNDLE"
echo -e "${COLOR_GREEN}  ✓ $APP_BUNDLE assembled and codesigned successfully!${COLOR_RESET}"

# Package Standalone Complete App Archive (.zip)
echo -e "\n${COLOR_YELLOW}[6/7] Creating Standalone Complete App Archive (No Installer Required)...${COLOR_RESET}"
ZIP_NAME="APEX-OS-macOS-Standalone.zip"
rm -f "$ZIP_NAME"
zip -q -r -y "$ZIP_NAME" "$APP_BUNDLE"
ZIP_SIZE=$(ls -lh "$ZIP_NAME" | awk '{print $5}')
echo -e "${COLOR_GREEN}  ✓ Standalone App Archive created: $ZIP_NAME ($ZIP_SIZE)${COLOR_RESET}"

# Step 7: Create Production DMG Installer (if requested)
if [ "$BUILD_DMG" = true ]; then
    echo -e "\n${COLOR_YELLOW}[7/7] Generating macOS Disk Image (APEX-OS-Installer.dmg)...${COLOR_RESET}"
    DMG_NAME="APEX-OS-Installer.dmg"
    DMG_STAGING=".dmg_staging"

    rm -rf "$DMG_STAGING" "$DMG_NAME"
    mkdir -p "$DMG_STAGING"

    cp -R "$APP_BUNDLE" "$DMG_STAGING/"
    ln -s /Applications "$DMG_STAGING/Applications"

    hdiutil create \
        -volname "APEX OS" \
        -srcfolder "$DMG_STAGING" \
        -ov \
        -format UDZO \
        "$DMG_NAME" > /dev/null

    rm -rf "$DMG_STAGING"
    DMG_SIZE=$(ls -lh "$DMG_NAME" | awk '{print $5}')
    echo -e "${COLOR_GREEN}  ✓ Disk Image created: $DMG_NAME ($DMG_SIZE)${COLOR_RESET}"
else
    echo -e "\n${COLOR_YELLOW}[7/7] Skipping DMG creation (--no-dmg specified).${COLOR_RESET}"
fi

echo -e "\n${COLOR_GREEN}${COLOR_BOLD}======================================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}${COLOR_BOLD}   🎉 BUILD & COMPILATION COMPLETE!                                   ${COLOR_RESET}"
echo -e "${COLOR_GREEN}${COLOR_BOLD}======================================================================${COLOR_RESET}"
echo -e "• Complete App Bundle : ${COLOR_BOLD}$PROJECT_DIR/$APP_BUNDLE${COLOR_RESET} (Ready to run directly)"
echo -e "• Standalone Archive  : ${COLOR_BOLD}$PROJECT_DIR/$ZIP_NAME${COLOR_RESET} (Unzip & run anywhere)"
if [ "$BUILD_DMG" = true ]; then
    echo -e "• Optional DMG Disk   : ${COLOR_BOLD}$PROJECT_DIR/APEX-OS-Installer.dmg${COLOR_RESET}"
fi
echo -e "• Direct Launch       : ${COLOR_BOLD}open \"$APP_BUNDLE\"${COLOR_RESET}\n"
