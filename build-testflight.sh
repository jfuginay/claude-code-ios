#!/bin/bash

# Claude Code iOS - TestFlight Build Script
# This script builds and archives the app for TestFlight distribution

echo "🚀 Claude Code iOS - TestFlight Build Process"
echo "============================================"

# Configuration
PROJECT_NAME="ClaudeCodeiOS"
SCHEME_NAME="ClaudeCodeiOS"
BUNDLE_ID="com.jfuginay.ClaudeCodeiOS"
BUILD_DIR="./build"
ARCHIVE_PATH="$BUILD_DIR/$PROJECT_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS_PLIST="./ExportOptions.plist"

# Clean build directory
echo "🧹 Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Increment build number
echo "📈 Incrementing build number..."
xcrun agvtool next-version -all

# Clean the project
echo "🧹 Cleaning project..."
xcodebuild clean -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME_NAME" -configuration Release

# Archive the project
echo "📦 Building and archiving..."
xcodebuild archive \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=iOS" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM=4HSANV485G

# Check if archive was successful
if [ ! -d "$ARCHIVE_PATH" ]; then
    echo "❌ Archive failed!"
    exit 1
fi

echo "✅ Archive created successfully!"

# Export the archive
echo "📤 Exporting for App Store..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
    -allowProvisioningUpdates

# Check if export was successful
if [ ! -d "$EXPORT_PATH" ]; then
    echo "❌ Export failed!"
    exit 1
fi

echo "✅ Export completed successfully!"
echo ""
echo "📱 Next Steps:"
echo "1. Open Xcode"
echo "2. Go to Window > Organizer"
echo "3. Select the archive and click 'Distribute App'"
echo "4. Choose 'App Store Connect' > 'Upload'"
echo "5. Follow the prompts to upload to TestFlight"
echo ""
echo "Or use Transporter app to upload the .ipa file from: $EXPORT_PATH"
echo ""
echo "🎉 Build complete!"