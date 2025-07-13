# TestFlight Deployment Guide for Claude Code iOS

## Prerequisites
- ✅ Apple Developer Account (Paid)
- ✅ Xcode installed
- ✅ Development Team configured (4HSANV485G)
- ✅ Bundle ID: com.jfuginay.ClaudeCodeiOS

## Method 1: Using Xcode (Recommended)

1. **Open the project in Xcode**
   ```bash
   cd /Users/jfuginay/Documents/dev/claude-code-ios/ClaudeCodeiOS
   open ClaudeCodeiOS.xcodeproj
   ```

2. **Select your device**
   - In Xcode, select "Any iOS Device (arm64)" from the device dropdown

3. **Archive the app**
   - Menu: Product > Archive
   - Wait for the build to complete

4. **Upload to App Store Connect**
   - The Organizer window will open automatically
   - Select your archive
   - Click "Distribute App"
   - Choose "App Store Connect" > "Upload"
   - Follow the prompts

## Method 2: Using the Build Script

1. **Run the build script**
   ```bash
   cd /Users/jfuginay/Documents/dev/claude-code-ios/ClaudeCodeiOS
   ./build-testflight.sh
   ```

2. **Upload using Transporter**
   - Download Transporter from the Mac App Store
   - Sign in with your Apple ID
   - Drag the .ipa file from `build/export/` to Transporter
   - Click "Deliver"

## App Store Connect Setup

1. **Create the app in App Store Connect** (if not already done)
   - Go to https://appstoreconnect.apple.com
   - Click "My Apps" > "+" > "New App"
   - Platform: iOS
   - Name: Claude Code
   - Primary Language: English
   - Bundle ID: com.jfuginay.ClaudeCodeiOS
   - SKU: claudecode-ios-001

2. **Configure TestFlight**
   - Go to your app in App Store Connect
   - Click "TestFlight" tab
   - Add internal testers (yourself)
   - Once build is processed (~5-30 minutes), it will appear

3. **Install TestFlight on your iPhone**
   - Download TestFlight from the App Store
   - Sign in with your Apple ID
   - Your app will appear once invited

## Build Numbers
The app uses automatic versioning:
- Version: 1.0
- Build: Auto-incremented with each archive

## Troubleshooting

### "No account for team" error
- Open Xcode > Preferences > Accounts
- Add your Apple ID
- Download certificates

### "No provisioning profile" error
- Xcode should handle this automatically
- If not: Xcode > Preferences > Accounts > Download Manual Profiles

### Build fails
- Clean build folder: Shift+Cmd+K in Xcode
- Restart Xcode
- Check that all Swift files are included in target

## Testing on Device (Direct Install)
For quick testing without TestFlight:
1. Connect iPhone via cable
2. Select your iPhone in Xcode device dropdown
3. Press Cmd+R to build and run
4. Trust the developer certificate on iPhone:
   Settings > General > Device Management > Developer App > Trust

---

Ready to build! The app is configured and ready for TestFlight deployment.