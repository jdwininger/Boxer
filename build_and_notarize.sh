#!/bin/bash
# ==============================================================================
# Boxer Build, Sign, and Notarize Script
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# ==============================================================================
# CONFIGURATION
# ==============================================================================
# Your Developer ID Application certificate name in Keychain.
# "Developer ID Application" is required for Gatekeeper/Notarization outside the App Store.
DEVELOPER_ID="Developer ID Application: Jeremy Wininger (M6TW42W523)"
# If you only have a Development certificate right now, you can test with:
# DEVELOPER_ID="Apple Development: Jeremy Wininger (QJV54U8P49)"
# (Note: Apple will only notarize binaries signed with a Developer ID Application cert)

# Notarytool Keychain Profile
# To set this up, run this command once in your terminal:
# xcrun notarytool store-credentials "boxer-notary" --apple-id "YOUR_APPLE_ID" --team-id "M6TW42W523" --password "YOUR_APP_SPECIFIC_PASSWORD"
NOTARY_PROFILE="boxer-notary"

# Directories
SOURCE_DIR="$PWD"
# We move the output entirely out of the source tree
OUT_DIR="$PWD/../Boxer-Dist-Release"

# Target Apps to build
SCHEMES=("Boxer CI" "Boxer Standalone" "Boxer Bundler")
APP_NAMES=("Boxer.app" "Boxer Standalone.app" "Boxer Bundler.app")

# ==============================================================================
# PREPARATION
# ==============================================================================
echo "=========================================="
echo " Preparing Build Directory out of Source..."
echo " Output Directory: $OUT_DIR"
echo "=========================================="
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/build"
mkdir -p "$OUT_DIR/final"

# ==============================================================================
# BUILD LOOP
# ==============================================================================
for i in "${!SCHEMES[@]}"; do
    SCHEME="${SCHEMES[$i]}"
    APP_NAME="${APP_NAMES[$i]}"
    APP_BASENAME="${APP_NAME%.app}"
    
    echo ""
    echo "=========================================="
    echo " [1/5] Compiling: $SCHEME"
    echo "=========================================="
    
    # We specify CODE_SIGN_INJECT_BASE_ENTITLEMENTS to ensure the signature allows hardened runtime (usually required for notarization)
    xcodebuild -workspace Boxer.xcworkspace \
               -scheme "$SCHEME" \
               -configuration Release \
               -derivedDataPath "$OUT_DIR/DerivedData" \
               CONFIGURATION_BUILD_DIR="$OUT_DIR/build" \
               CODE_SIGN_STYLE="Manual" \
               CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
               CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
               OTHER_CODE_SIGN_FLAGS="--timestamp" \
               ENABLE_HARDENED_RUNTIME=YES \
               build
               
    APP_PATH="$OUT_DIR/build/$APP_NAME"
    
    echo ""
    echo "=========================================="
    echo " [1.5] Manual Deep Codesign: $APP_NAME"
    echo "=========================================="
    # Recursively sign frameworks and auto-updaters inside the app bundle
    if [ -d "$APP_PATH/Contents/Frameworks/Sparkle.framework" ]; then
        codesign --force --sign "$DEVELOPER_ID" --options=runtime --timestamp "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/A/Resources/Autoupdate.app/Contents/MacOS/fileop"
        codesign --force --sign "$DEVELOPER_ID" --options=runtime --timestamp "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/A/Resources/Autoupdate.app/Contents/MacOS/Autoupdate"
        codesign --force --sign "$DEVELOPER_ID" --options=runtime --timestamp "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/A/Resources/Autoupdate.app"
        codesign --force --sign "$DEVELOPER_ID" --options=runtime --timestamp "$APP_PATH/Contents/Frameworks/Sparkle.framework"
    fi
    
    # Finally, sign the app bundle itself
    codesign --force --sign "$DEVELOPER_ID" --options=runtime --timestamp --entitlements "Boxer/Boxer.entitlements" "$APP_PATH"
    
    echo ""
    echo "=========================================="
    echo " [2/5] Verifying Signature for: $APP_NAME"
    echo "=========================================="
    # Validate the signature. --strict ensures all constraints are met.
    codesign -dv --verbose=4 "$APP_PATH"
    codesign -vvv --deep --strict "$APP_PATH"
    
    echo ""
    echo "=========================================="
    echo " [3/5] Zipping for Notarization: $APP_NAME"
    echo "=========================================="
    ZIP_PATH="$OUT_DIR/build/$APP_BASENAME.zip"
    cd "$OUT_DIR/build"
    # Using ditto -c -k --keepParent to maintain exact file permissions and resource forks
    /usr/bin/ditto -c -k --keepParent "$APP_NAME" "$ZIP_PATH"
    cd "$SOURCE_DIR"
    
    echo ""
    echo "=========================================="
    echo " [4/5] Notarizing: $APP_NAME"
    echo "=========================================="
    # Submit to Apple and block until complete!
    # If using a Development profile instead of Developer ID Application, notarization will likely fail.
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    
    echo ""
    echo "=========================================="
    echo " [5/5] Stapling and Finalizing: $APP_NAME"
    echo "=========================================="
    # Staple the resulting notarization ticket directly to the original .app bundle
    xcrun stapler staple "$APP_PATH"
    
    # Re-zip the newly stapled app to give out to users
    FINAL_ZIP="$OUT_DIR/final/${APP_BASENAME}-Release.zip"
    cd "$OUT_DIR/build"
    /usr/bin/ditto -c -k --keepParent "$APP_NAME" "$FINAL_ZIP"
    cd "$SOURCE_DIR"
    
    echo "------------------------------------------"
    echo " Finished Processing $APP_NAME!"
    echo " Delivery Package: $FINAL_ZIP"
    echo "------------------------------------------"
done

echo ""
echo "======================================================================"
echo " Preparing DMG containing all three apps..."
echo "======================================================================"
DMG_ROOT="$OUT_DIR/dmg_root"
mkdir -p "$DMG_ROOT"

# Copy the fully stapled apps into the DMG folder
for APP_NAME in "${APP_NAMES[@]}"; do
    cp -R "$OUT_DIR/build/$APP_NAME" "$DMG_ROOT/"
done

# Create an Applications symlink for easy drag-and-drop installation
ln -s /Applications "$DMG_ROOT/Applications"

DMG_NAME="Boxer-Complete.dmg"
DMG_PATH="$OUT_DIR/build/$DMG_NAME"
FINAL_DMG_PATH="$OUT_DIR/final/$DMG_NAME"

echo "Building DMG using hdiutil..."
hdiutil create -volname "Boxer" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH"

echo ""
echo "======================================================================"
echo " Signing and Notarizing the DMG..."
echo "======================================================================"
# Apple requires the DMG itself to also be signed and notarized
codesign --force --sign "$DEVELOPER_ID" --timestamp "$DMG_PATH"

xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"

mv "$DMG_PATH" "$FINAL_DMG_PATH"

echo ""
echo "======================================================================"
echo " All Applications have been built, signed, notarized, and packaged!"
echo " Check $OUT_DIR/final for your individual ZIPs and the combined DMG."
echo " DMG Delivery Package: $FINAL_DMG_PATH"
echo "======================================================================"
